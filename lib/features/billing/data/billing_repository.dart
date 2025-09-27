import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/client.dart';
import '../domain/invoice.dart';
import '../domain/invoice_line.dart';
import '../domain/payment_attempt.dart';

/// Repository for billing operations with Supabase backend
class BillingRepository {
  static final BillingRepository _instance = BillingRepository._internal();
  factory BillingRepository() => _instance;
  static BillingRepository get instance => _instance;
  BillingRepository._internal();

  final SupabaseClient _client = SupabaseService.client;

  /// Create invoice with line items in a transaction
  Future<Invoice> createInvoice(Invoice draft, List<InvoiceLine> lines) async {
    try {
      debugPrint('💰 Creating invoice with ${lines.length} line items');

      // Validate invoice data
      final validationErrors = _validateInvoiceCreation(draft, lines);
      if (validationErrors.isNotEmpty) {
        throw Exception('Validation failed: ${validationErrors.join(', ')}');
      }

      // Create invoice first
      final invoiceResponse = await _client
          .from(SupabaseTables.invoices)
          .insert(draft.toJson())
          .select()
          .single();

      final createdInvoice = Invoice.fromJson(invoiceResponse);
      debugPrint('✅ Invoice created: ${createdInvoice.id}');

      // Create line items
      final lineItemsData = lines.map((line) => 
          line.copyWith(invoiceId: createdInvoice.id!).toJson()).toList();

      await _client
          .from(SupabaseTables.invoiceLines)
          .insert(lineItemsData);

      debugPrint('✅ Line items created: ${lines.length}');

      return createdInvoice;
    } catch (e) {
      debugPrint('❌ Failed to create invoice: $e');
      rethrow;
    }
  }

  /// Get invoice by ID with line items
  Future<Invoice?> getInvoice(String invoiceId) async {
    try {
      debugPrint('💰 Fetching invoice: $invoiceId');

      final response = await _client
          .from(SupabaseTables.invoices)
          .select()
          .eq('id', invoiceId)
          .maybeSingle();

      if (response == null) {
        debugPrint('❌ Invoice not found: $invoiceId');
        return null;
      }

      final invoice = Invoice.fromJson(response);
      debugPrint('✅ Invoice found: ${invoice.invoiceNumber}');
      return invoice;
    } catch (e) {
      debugPrint('❌ Failed to get invoice: $e');
      rethrow;
    }
  }

  /// Get line items for an invoice
  Future<List<InvoiceLine>> getInvoiceLines(String invoiceId) async {
    try {
      debugPrint('💰 Fetching line items for invoice: $invoiceId');

      final response = await _client
          .from(SupabaseTables.invoiceLines)
          .select()
          .eq('invoice_id', invoiceId)
          .order('created_at', ascending: true);

      final lines = (response as List)
          .map((json) => InvoiceLine.fromJson(json))
          .toList();

      debugPrint('✅ Found ${lines.length} line items');
      return lines;
    } catch (e) {
      debugPrint('❌ Failed to get invoice lines: $e');
      rethrow;
    }
  }

  /// List invoices with cursor-based pagination and filtering
  Future<PaginatedInvoices> listInvoices({
    required String tenantId,
    String? status,
    int page = 1,
    int pageSize = 20,
    InvoiceFilters? filters,
    InvoiceCursor? cursor,
  }) async {
    try {
      debugPrint('💰 Listing invoices for tenant: $tenantId (page: $page, cursor: ${cursor != null})');

      var query = _client
          .from(SupabaseTables.invoices)
          .select('*', const FetchOptions(count: CountOption.exact))
          .eq('tenant_id', tenantId);

      // Apply filters
      if (status != null) {
        query = query.eq('status', status);
      }

      if (filters != null) {
        query = _applyInvoiceFilters(query, filters);
      }

      // Apply cursor-based pagination (preferred for performance)
      if (cursor != null && cursor.isValid) {
        query = query
            .or('issue_date.lt.${cursor.issueDate.toIso8601String()},and(issue_date.eq.${cursor.issueDate.toIso8601String()},id.lt.${cursor.id})')
            .order('issue_date', ascending: false)
            .order('id', ascending: false)
            .limit(pageSize + 1); // +1 to check if there are more records
      } else {
        // Fallback to offset-based pagination for first page or complex searches
        final offset = (page - 1) * pageSize;
        query = query
            .order('issue_date', ascending: false)
            .order('id', ascending: false)
            .range(offset, offset + pageSize - 1);
      }

      final response = await query;
      final total = response.count ?? 0;

      var invoices = (response.data as List)
          .map((json) => Invoice.fromJson(json))
          .toList();

      bool hasMore;
      InvoiceCursor? nextCursor;

      if (cursor != null && cursor.isValid) {
        // Cursor-based pagination
        hasMore = invoices.length > pageSize;
        if (hasMore) {
          invoices = invoices.take(pageSize).toList(); // Remove the extra record
          final lastInvoice = invoices.last;
          nextCursor = InvoiceCursor(
            issueDate: lastInvoice.issueDate,
            id: lastInvoice.id!,
          );
        }
      } else {
        // Offset-based pagination
        final offset = (page - 1) * pageSize;
        hasMore = (offset + invoices.length) < total;
        if (hasMore && invoices.isNotEmpty) {
          final lastInvoice = invoices.last;
          nextCursor = InvoiceCursor(
            issueDate: lastInvoice.issueDate,
            id: lastInvoice.id!,
          );
        }
      }

      debugPrint('✅ Found ${invoices.length} invoices (total: $total, hasMore: $hasMore)');

      return PaginatedInvoices(
        invoices: invoices,
        total: total,
        page: page,
        pageSize: pageSize,
        hasMore: hasMore,
        cursor: nextCursor,
      );
    } catch (e) {
      debugPrint('❌ Failed to list invoices: $e');
      rethrow;
    }
  }

  /// Update invoice status
  Future<Invoice> updateInvoiceStatus({
    required String invoiceId,
    required InvoiceStatus nextStatus,
    String? notes,
  }) async {
    try {
      debugPrint('💰 Updating invoice status: $invoiceId -> ${nextStatus.value}');

      // Get current invoice to validate transition
      final currentInvoice = await getInvoice(invoiceId);
      if (currentInvoice == null) {
        throw Exception('Invoice not found: $invoiceId');
      }

      // Validate status transition
      if (!currentInvoice.status.canTransitionTo(nextStatus)) {
        throw Exception(
          'Invalid status transition: ${currentInvoice.status.value} -> ${nextStatus.value}'
        );
      }

      final updateData = {
        'status': nextStatus.value,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (notes != null) {
        updateData['notes'] = notes;
      }

      final response = await _client
          .from(SupabaseTables.invoices)
          .update(updateData)
          .eq('id', invoiceId)
          .select()
          .single();

      final updatedInvoice = Invoice.fromJson(response);
      debugPrint('✅ Invoice status updated: ${updatedInvoice.status.displayName}');
      return updatedInvoice;
    } catch (e) {
      debugPrint('❌ Failed to update invoice status: $e');
      rethrow;
    }
  }

  /// Log payment attempt
  Future<PaymentAttempt> logPaymentAttempt(PaymentAttempt attempt) async {
    try {
      debugPrint('💰 Logging payment attempt: ${attempt.referenceId}');

      final response = await _client
          .from(SupabaseTables.paymentAttempts)
          .insert(attempt.toJson())
          .select()
          .single();

      final loggedAttempt = PaymentAttempt.fromJson(response);
      debugPrint('✅ Payment attempt logged: ${loggedAttempt.id}');
      return loggedAttempt;
    } catch (e) {
      debugPrint('❌ Failed to log payment attempt: $e');
      rethrow;
    }
  }

  /// Get payment attempts for an invoice
  Future<List<PaymentAttempt>> getPaymentAttempts(String invoiceId) async {
    try {
      debugPrint('💰 Fetching payment attempts for invoice: $invoiceId');

      final response = await _client
          .from(SupabaseTables.paymentAttempts)
          .select()
          .eq('invoice_id', invoiceId)
          .order('attempt_date', ascending: false);

      final attempts = (response as List)
          .map((json) => PaymentAttempt.fromJson(json))
          .toList();

      debugPrint('✅ Found ${attempts.length} payment attempts');
      return attempts;
    } catch (e) {
      debugPrint('❌ Failed to get payment attempts: $e');
      rethrow;
    }
  }

  /// Update payment attempt status
  Future<PaymentAttempt> updatePaymentAttemptStatus({
    required String attemptId,
    required PaymentAttemptStatus status,
    String? errorMessage,
    String? providerTransactionId,
    String? notes,
  }) async {
    try {
      debugPrint('💰 Updating payment attempt status: $attemptId -> ${status.value}');

      final updateData = <String, dynamic>{
        'status': status.value,
      };

      if (errorMessage != null) {
        updateData['error_message'] = errorMessage;
      }

      if (providerTransactionId != null) {
        updateData['provider_transaction_id'] = providerTransactionId;
      }

      if (notes != null) {
        updateData['notes'] = notes;
      }

      final response = await _client
          .from(SupabaseTables.paymentAttempts)
          .update(updateData)
          .eq('id', attemptId)
          .select()
          .single();

      final updatedAttempt = PaymentAttempt.fromJson(response);
      debugPrint('✅ Payment attempt status updated: ${updatedAttempt.status.displayName}');
      return updatedAttempt;
    } catch (e) {
      debugPrint('❌ Failed to update payment attempt status: $e');
      rethrow;
    }
  }

  /// Compute invoice totals from line items
  Future<InvoiceTotals> computeTotals(List<InvoiceLine> lines) async {
    try {
      debugPrint('💰 Computing totals for ${lines.length} line items');

      final totals = InvoiceTotals.fromLineItems(lines);

      debugPrint('✅ Totals computed: subtotal=₹${totals.subtotal}, tax=₹${totals.taxAmount}, total=₹${totals.total}');
      return totals;
    } catch (e) {
      debugPrint('❌ Failed to compute totals: $e');
      rethrow;
    }
  }

  /// Get billing KPIs for dashboard
  Future<BillingKPIs> getBillingKPIs(String tenantId) async {
    try {
      debugPrint('💰 Fetching billing KPIs for tenant: $tenantId');

      // Get unpaid invoices count (sent + pending)
      final unpaidResponse = await _client
          .from(SupabaseTables.invoices)
          .select('id', const FetchOptions(count: CountOption.exact, head: true))
          .eq('tenant_id', tenantId)
          .inFilter('status', ['sent', 'pending']);

      final unpaidCount = unpaidResponse.count ?? 0;

      // Get overdue invoices count
      final now = DateTime.now();
      final overdueResponse = await _client
          .from(SupabaseTables.invoices)
          .select('id', const FetchOptions(count: CountOption.exact, head: true))
          .eq('tenant_id', tenantId)
          .inFilter('status', ['sent', 'pending'])
          .lt('due_date', now.toIso8601String());

      final overdueCount = overdueResponse.count ?? 0;

      // Get total outstanding amount
      final outstandingResponse = await _client
          .from(SupabaseTables.invoices)
          .select('total')
          .eq('tenant_id', tenantId)
          .inFilter('status', ['sent', 'pending']);

      double outstandingAmount = 0.0;
      for (final invoice in outstandingResponse) {
        outstandingAmount += (invoice['total'] as num).toDouble();
      }

      // Get this month's revenue (paid invoices)
      final monthStart = DateTime(now.year, now.month, 1);
      final monthEnd = DateTime(now.year, now.month + 1, 1);

      final revenueResponse = await _client
          .from(SupabaseTables.invoices)
          .select('total')
          .eq('tenant_id', tenantId)
          .eq('status', 'paid')
          .gte('updated_at', monthStart.toIso8601String())
          .lt('updated_at', monthEnd.toIso8601String());

      double monthlyRevenue = 0.0;
      for (final invoice in revenueResponse) {
        monthlyRevenue += (invoice['total'] as num).toDouble();
      }

      final kpis = BillingKPIs(
        unpaidInvoices: unpaidCount,
        overdueInvoices: overdueCount,
        outstandingAmount: outstandingAmount,
        monthlyRevenue: monthlyRevenue,
      );

      debugPrint('✅ Billing KPIs fetched: unpaid=$unpaidCount, overdue=$overdueCount');
      return kpis;
    } catch (e) {
      debugPrint('❌ Failed to get billing KPIs: $e');
      rethrow;
    }
  }

  /// Generate invoice number
  Future<String> generateInvoiceNumber(String tenantId) async {
    try {
      debugPrint('💰 Generating invoice number for tenant: $tenantId');

      final now = DateTime.now();
      final year = now.year;
      final month = now.month.toString().padLeft(2, '0');

      // Get count of invoices for this month
      final monthStart = DateTime(year, now.month, 1);
      final monthEnd = DateTime(year, now.month + 1, 1);

      final countResponse = await _client
          .from(SupabaseTables.invoices)
          .select('id', const FetchOptions(count: CountOption.exact, head: true))
          .eq('tenant_id', tenantId)
          .gte('created_at', monthStart.toIso8601String())
          .lt('created_at', monthEnd.toIso8601String());

      final count = (countResponse.count ?? 0) + 1;
      final sequence = count.toString().padLeft(3, '0');

      final invoiceNumber = 'INV-$year$month-$sequence';
      debugPrint('✅ Generated invoice number: $invoiceNumber');
      return invoiceNumber;
    } catch (e) {
      debugPrint('❌ Failed to generate invoice number: $e');
      rethrow;
    }
  }

  /// Delete invoice (admin only, for draft invoices)
  Future<void> deleteInvoice(String invoiceId) async {
    try {
      debugPrint('💰 Deleting invoice: $invoiceId');

      // Verify invoice is in draft status
      final invoice = await getInvoice(invoiceId);
      if (invoice == null) {
        throw Exception('Invoice not found: $invoiceId');
      }

      if (invoice.status != InvoiceStatus.draft) {
        throw Exception('Only draft invoices can be deleted');
      }

      // Delete line items first
      await _client
          .from(SupabaseTables.invoiceLines)
          .delete()
          .eq('invoice_id', invoiceId);

      // Delete invoice
      await _client
          .from(SupabaseTables.invoices)
          .delete()
          .eq('id', invoiceId);

      debugPrint('✅ Invoice deleted: $invoiceId');
    } catch (e) {
      debugPrint('❌ Failed to delete invoice: $e');
      rethrow;
    }
  }

  /// Apply filters to invoice query
  PostgrestFilterBuilder _applyInvoiceFilters(
    PostgrestFilterBuilder query,
    InvoiceFilters filters,
  ) {
    // Status filter
    if (filters.statuses.isNotEmpty) {
      final statusValues = filters.statuses.map((s) => s.value).toList();
      query = query.inFilter('status', statusValues);
    }

    // Overdue filter
    if (filters.isOverdue == true) {
      final now = DateTime.now();
      query = query
          .inFilter('status', ['sent', 'pending'])
          .lt('due_date', now.toIso8601String());
    } else if (filters.isOverdue == false) {
      final now = DateTime.now();
      query = query.gte('due_date', now.toIso8601String());
    }

    // Date range filter
    if (filters.dateRange != null) {
      query = query
          .gte('issue_date', filters.dateRange!.start.toIso8601String())
          .lte('issue_date', filters.dateRange!.end.toIso8601String());
    }

    // Search query filter (invoice number or customer name)
    if (filters.searchQuery != null && filters.searchQuery!.trim().isNotEmpty) {
      final searchTerm = filters.searchQuery!.trim().toLowerCase();
      
      // Note: This is a simplified search. In production, you might want to use
      // full-text search or search in customer_info JSON field
      query = query.or('invoice_number.ilike.%$searchTerm%');
    }

    return query;
  }

  /// Validate invoice creation data
  List<String> _validateInvoiceCreation(Invoice invoice, List<InvoiceLine> lines) {
    final errors = <String>[];

    // Validate invoice
    if (invoice.tenantId.isEmpty) {
      errors.add('Tenant ID is required');
    }

    if (invoice.requestIds.isEmpty) {
      errors.add('At least one request ID is required');
    }

    if (invoice.invoiceNumber.isEmpty) {
      errors.add('Invoice number is required');
    }

    if (invoice.customerInfo.name.isEmpty) {
      errors.add('Customer name is required');
    }

    if (invoice.customerInfo.email.isEmpty) {
      errors.add('Customer email is required');
    }

    if (invoice.issueDate.isAfter(invoice.dueDate)) {
      errors.add('Due date must be after issue date');
    }

    // Validate line items
    if (lines.isEmpty) {
      errors.add('At least one line item is required');
    }

    final lineErrors = LineItemValidator.validateLineItems(lines);
    errors.addAll(lineErrors);

    // Validate totals match line items
    final calculatedTotals = InvoiceTotals.fromLineItems(lines);
    if ((invoice.subtotal - calculatedTotals.subtotal).abs() > 0.01) {
      errors.add('Invoice subtotal does not match line items total');
    }

    if ((invoice.taxAmount - calculatedTotals.taxAmount).abs() > 0.01) {
      errors.add('Invoice tax amount does not match line items tax total');
    }

    if ((invoice.total - calculatedTotals.total).abs() > 0.01) {
      errors.add('Invoice total does not match calculated total');
    }

    return errors;
  }
}

/// Billing KPIs for dashboard
class BillingKPIs {
  const BillingKPIs({
    required this.unpaidInvoices,
    required this.overdueInvoices,
    required this.outstandingAmount,
    required this.monthlyRevenue,
  });

  final int unpaidInvoices;
  final int overdueInvoices;
  final double outstandingAmount;
  final double monthlyRevenue;
}