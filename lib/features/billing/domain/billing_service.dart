import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/auth_service.dart';
import '../../requests/domain/requests_service.dart';
import '../../requests/domain/models/request.dart';
import '../data/billing_repository.dart';
import 'invoice.dart';
import 'invoice_line.dart';
import 'payment_attempt.dart';

/// Provider for BillingService
final billingServiceProvider = ChangeNotifierProvider<BillingService>((ref) {
  return BillingService(
    ref.watch(authServiceProvider),
    ref.watch(requestsServiceProvider),
  );
});

/// Service for billing operations and business logic
class BillingService extends ChangeNotifier {
  BillingService(this._authService, this._requestsService);

  final AuthService _authService;
  final RequestsService _requestsService;
  final BillingRepository _repository = BillingRepository.instance;

  BillingState _state = const BillingState();
  
  // Search debouncing
  Timer? _searchDebounceTimer;
  String? _pendingSearchQuery;
  
  // Request cancellation
  var _cancelToken = Object();

  /// Current billing state
  BillingState get state => _state;

  /// Current tenant ID
  String? get _tenantId => _authService.tenantId;

  /// Current user is admin
  bool get _isAdmin => _authService.userProfile?.role == UserRole.admin;

  /// Generate invoice from completed requests
  Future<Invoice> generateFromRequests({
    required String tenantId,
    required List<String> requestIds,
    CustomerInfo? customerInfo,
  }) async {
    try {
      debugPrint('💰 Generating invoice from ${requestIds.length} requests');

      _updateState(_state.copyWith(isLoading: true, error: null));

      // Validate tenant access
      if (_tenantId != tenantId) {
        throw Exception('Unauthorized: Cannot access tenant data');
      }

      // Validate requests exist and are completed
      final requestsData = await _validateAndFetchRequests(requestIds);
      
      // Extract customer info from first request if not provided
      final customerData = customerInfo ?? _extractCustomerInfo(requestsData.first);

      // Generate invoice number
      final invoiceNumber = await _repository.generateInvoiceNumber(tenantId);

      // Create line items from requests
      final lineItems = _generateLineItemsFromRequests(requestsData, '');

      // Calculate totals
      final totals = await _repository.computeTotals(lineItems);

      // Create invoice draft
      final invoiceDraft = Invoice(
        tenantId: tenantId,
        requestIds: requestIds,
        invoiceNumber: invoiceNumber,
        status: InvoiceStatus.draft,
        customerInfo: customerData,
        issueDate: DateTime.now(),
        dueDate: DateTime.now().add(const Duration(days: 30)), // Default 30 days
        subtotal: totals.subtotal,
        taxAmount: totals.taxAmount,
        total: totals.total,
        notes: 'Generated from ${requestIds.length} service request(s)',
      );

      // Create invoice with line items
      final createdInvoice = await _repository.createInvoice(invoiceDraft, lineItems);

      // Update state
      final updatedInvoices = List<Invoice>.from(_state.invoices);
      updatedInvoices.insert(0, createdInvoice);
      
      _updateState(_state.copyWith(
        invoices: updatedInvoices,
        totalCount: _state.totalCount + 1,
        isLoading: false,
      ));

      debugPrint('✅ Invoice generated: ${createdInvoice.invoiceNumber}');
      return createdInvoice;
    } catch (e) {
      debugPrint('❌ Failed to generate invoice: $e');
      _updateState(_state.copyWith(
        isLoading: false,
        error: 'Failed to generate invoice: ${e.toString()}',
      ));
      rethrow;
    }
  }

  /// Send invoice (draft → sent)
  Future<void> sendInvoice(String invoiceId) async {
    try {
      debugPrint('💰 Sending invoice: $invoiceId');

      if (!_isAdmin) {
        throw Exception('Unauthorized: Only admins can send invoices');
      }

      _updateState(_state.copyWith(isLoading: true, error: null));

      final updatedInvoice = await _repository.updateInvoiceStatus(
        invoiceId: invoiceId,
        nextStatus: InvoiceStatus.sent,
      );

      // Update state
      _updateInvoiceInState(updatedInvoice);
      _updateState(_state.copyWith(isLoading: false));

      debugPrint('✅ Invoice sent: ${updatedInvoice.invoiceNumber}');
    } catch (e) {
      debugPrint('❌ Failed to send invoice: $e');
      _updateState(_state.copyWith(
        isLoading: false,
        error: 'Failed to send invoice: ${e.toString()}',
      ));
      rethrow;
    }
  }

  /// Mark invoice as pending (sent → pending, when payment launcher opened)
  Future<void> markPending(String invoiceId) async {
    try {
      debugPrint('💰 Marking invoice as pending: $invoiceId');

      final updatedInvoice = await _repository.updateInvoiceStatus(
        invoiceId: invoiceId,
        nextStatus: InvoiceStatus.pending,
      );

      // Update state
      _updateInvoiceInState(updatedInvoice);

      debugPrint('✅ Invoice marked as pending: ${updatedInvoice.invoiceNumber}');
    } catch (e) {
      debugPrint('❌ Failed to mark invoice as pending: $e');
      rethrow;
    }
  }

  /// Mark invoice as paid
  Future<void> markPaid(String invoiceId) async {
    try {
      debugPrint('💰 Marking invoice as paid: $invoiceId');

      if (!_isAdmin) {
        throw Exception('Unauthorized: Only admins can mark invoices as paid');
      }

      final updatedInvoice = await _repository.updateInvoiceStatus(
        invoiceId: invoiceId,
        nextStatus: InvoiceStatus.paid,
      );

      // Update state
      _updateInvoiceInState(updatedInvoice);

      debugPrint('✅ Invoice marked as paid: ${updatedInvoice.invoiceNumber}');
    } catch (e) {
      debugPrint('❌ Failed to mark invoice as paid: $e');
      rethrow;
    }
  }

  /// Mark invoice as failed
  Future<void> markFailed(String invoiceId) async {
    try {
      debugPrint('💰 Marking invoice as failed: $invoiceId');

      final updatedInvoice = await _repository.updateInvoiceStatus(
        invoiceId: invoiceId,
        nextStatus: InvoiceStatus.failed,
      );

      // Update state
      _updateInvoiceInState(updatedInvoice);

      debugPrint('✅ Invoice marked as failed: ${updatedInvoice.invoiceNumber}');
    } catch (e) {
      debugPrint('❌ Failed to mark invoice as failed: $e');
      rethrow;
    }
  }

  /// Mark invoice as refunded
  Future<void> markRefunded(String invoiceId) async {
    try {
      debugPrint('💰 Marking invoice as refunded: $invoiceId');

      if (!_isAdmin) {
        throw Exception('Unauthorized: Only admins can process refunds');
      }

      final updatedInvoice = await _repository.updateInvoiceStatus(
        invoiceId: invoiceId,
        nextStatus: InvoiceStatus.refunded,
      );

      // Update state
      _updateInvoiceInState(updatedInvoice);

      debugPrint('✅ Invoice marked as refunded: ${updatedInvoice.invoiceNumber}');
    } catch (e) {
      debugPrint('❌ Failed to mark invoice as refunded: $e');
      rethrow;
    }
  }

  /// Record PhonePe payment attempt
  Future<PaymentAttempt> recordPhonePeAttempt({
    required String invoiceId,
    required num amount,
    required String referenceId,
    String? notes,
  }) async {
    try {
      debugPrint('💰 Recording PhonePe attempt: $referenceId');

      final attempt = PaymentAttempt.createPhonePeAttempt(
        invoiceId: invoiceId,
        amount: amount.toDouble(),
        referenceId: referenceId,
        notes: notes,
      );

      final loggedAttempt = await _repository.logPaymentAttempt(attempt);

      // Mark invoice as pending if it was sent
      final invoice = await _repository.getInvoice(invoiceId);
      if (invoice?.status == InvoiceStatus.sent) {
        await markPending(invoiceId);
      }

      debugPrint('✅ PhonePe attempt recorded: ${loggedAttempt.id}');
      return loggedAttempt;
    } catch (e) {
      debugPrint('❌ Failed to record PhonePe attempt: $e');
      rethrow;
    }
  }

  /// Load invoices with cursor-based pagination and filters
  Future<void> loadInvoices({
    int page = 1,
    int pageSize = 20,
    InvoiceFilters? filters,
    bool refresh = false,
    InvoiceCursor? cursor,
  }) async {
    final currentToken = _cancelToken;
    
    try {
      final tenantId = _tenantId;
      if (tenantId == null) {
        throw Exception('No tenant context');
      }

      debugPrint('💰 Loading invoices: page=$page, refresh=$refresh, cursor=${cursor != null}');

      if (refresh || page == 1 || cursor == null) {
        _updateState(_state.copyWith(isLoading: true, error: null));
      }

      final result = await _repository.listInvoices(
        tenantId: tenantId,
        page: page,
        pageSize: pageSize,
        filters: filters,
        cursor: cursor,
      );

      // Check if request was cancelled
      if (currentToken != _cancelToken) {
        debugPrint('🚫 Request cancelled, ignoring result');
        return;
      }

      List<Invoice> updatedInvoices;
      if (refresh || page == 1 || cursor == null) {
        updatedInvoices = result.invoices;
      } else {
        updatedInvoices = List.from(_state.invoices)..addAll(result.invoices);
      }

      _updateState(_state.copyWith(
        invoices: updatedInvoices,
        totalCount: result.total,
        currentPage: page,
        hasMore: result.hasMore,
        filters: filters ?? _state.filters,
        cursor: result.cursor,
        isLoading: false,
      ));

      debugPrint('✅ Loaded ${result.invoices.length} invoices');
    } catch (e) {
      // Check if request was cancelled
      if (currentToken != _cancelToken) {
        debugPrint('🚫 Request cancelled during error handling');
        return;
      }
      
      debugPrint('❌ Failed to load invoices: $e');
      _updateState(_state.copyWith(
        isLoading: false,
        error: 'Failed to load invoices: ${e.toString()}',
      ));
    }
  }

  /// Get invoice with line items
  Future<InvoiceDetail?> getInvoiceDetail(String invoiceId) async {
    try {
      debugPrint('💰 Getting invoice detail: $invoiceId');

      final invoice = await _repository.getInvoice(invoiceId);
      if (invoice == null) {
        return null;
      }

      final lineItems = await _repository.getInvoiceLines(invoiceId);
      final paymentAttempts = await _repository.getPaymentAttempts(invoiceId);

      return InvoiceDetail(
        invoice: invoice,
        lineItems: lineItems,
        paymentAttempts: paymentAttempts,
      );
    } catch (e) {
      debugPrint('❌ Failed to get invoice detail: $e');
      rethrow;
    }
  }

  /// Get billing KPIs for dashboard
  Future<BillingKPIs> getBillingKPIs() async {
    try {
      final tenantId = _tenantId;
      if (tenantId == null) {
        throw Exception('No tenant context');
      }

      debugPrint('💰 Getting billing KPIs');
      return await _repository.getBillingKPIs(tenantId);
    } catch (e) {
      debugPrint('❌ Failed to get billing KPIs: $e');
      rethrow;
    }
  }

  /// Apply filters to invoice list with debouncing for search
  Future<void> applyFilters(InvoiceFilters filters) async {
    // Cancel any pending requests
    _cancelToken = Object();
    
    // If search query changed, debounce it
    if (filters.searchQuery != _state.filters.searchQuery) {
      _pendingSearchQuery = filters.searchQuery;
      _searchDebounceTimer?.cancel();
      
      if (filters.searchQuery?.trim().isEmpty == true || filters.searchQuery == null) {
        // Empty search - apply immediately
        await loadInvoices(filters: filters.copyWith(searchQuery: null), refresh: true);
      } else {
        // Debounce search
        _searchDebounceTimer = Timer(const Duration(milliseconds: 320), () async {
          if (_pendingSearchQuery == filters.searchQuery) {
            await loadInvoices(filters: filters, refresh: true);
          }
        });
      }
    } else {
      // Non-search filters - apply immediately
      await loadInvoices(filters: filters, refresh: true);
    }
  }

  /// Clear filters
  Future<void> clearFilters() async {
    _cancelToken = Object();
    _searchDebounceTimer?.cancel();
    _pendingSearchQuery = null;
    await loadInvoices(filters: const InvoiceFilters(), refresh: true);
  }

  /// Load more invoices using cursor pagination
  Future<void> loadMore() async {
    if (_state.hasMore && !_state.isLoading && _state.cursor != null) {
      await loadInvoices(
        page: _state.currentPage + 1,
        filters: _state.filters,
        cursor: _state.cursor,
      );
    }
  }

  /// Delete draft invoice
  Future<void> deleteDraftInvoice(String invoiceId) async {
    try {
      debugPrint('💰 Deleting draft invoice: $invoiceId');

      if (!_isAdmin) {
        throw Exception('Unauthorized: Only admins can delete invoices');
      }

      await _repository.deleteInvoice(invoiceId);

      // Remove from state
      final updatedInvoices = _state.invoices.where((inv) => inv.id != invoiceId).toList();
      _updateState(_state.copyWith(
        invoices: updatedInvoices,
        totalCount: _state.totalCount - 1,
      ));

      debugPrint('✅ Draft invoice deleted');
    } catch (e) {
      debugPrint('❌ Failed to delete draft invoice: $e');
      rethrow;
    }
  }

  /// Validate and fetch requests for invoice generation
  Future<List<ServiceRequest>> _validateAndFetchRequests(List<String> requestIds) async {
    final requests = <ServiceRequest>[];

    for (final requestId in requestIds) {
      final request = await _requestsService.getRequest(requestId);
      if (request == null) {
        throw Exception('Request not found: $requestId');
      }

      if (!request.status.isClosed) {
        throw Exception('Request must be completed before invoicing: $requestId');
      }

      requests.add(request);
    }

    return requests;
  }

  /// Extract customer info from request
  CustomerInfo _extractCustomerInfo(ServiceRequest request) {
    // In a real app, you might have customer data in the request
    // For now, use facility information as customer
    return CustomerInfo(
      name: request.facilityName ?? 'Customer',
      email: 'customer@facility.com', // Placeholder
      phone: null,
      address: 'Facility Address', // Placeholder
    );
  }

  /// Generate line items from service requests
  List<InvoiceLine> _generateLineItemsFromRequests(
    List<ServiceRequest> requests,
    String invoiceId,
  ) {
    final lineItems = <InvoiceLine>[];

    for (final request in requests) {
      // Labor line item - base on request priority and estimated hours
      final hours = _estimateHoursFromRequest(request);
      final laborRate = _getLaborRate(request.priority);
      
      lineItems.add(LineItemTemplate.createLaborLine(
        invoiceId: invoiceId,
        technicianType: 'Technician',
        hours: hours,
        taxRate: 0.18, // 18% GST
      ));

      // Materials line item if applicable
      if (_requestRequiresMaterials(request)) {
        lineItems.add(LineItemTemplate.createMaterialLine(
          invoiceId: invoiceId,
          materialType: 'Basic Parts',
          quantity: 1,
          taxRate: 0.18,
        ));
      }
    }

    return lineItems;
  }

  /// Estimate hours from request (business logic placeholder)
  double _estimateHoursFromRequest(ServiceRequest request) {
    switch (request.priority) {
      case RequestPriority.critical:
        return 4.0; // Critical issues take longer
      case RequestPriority.high:
        return 3.0;
      case RequestPriority.medium:
        return 2.0;
      case RequestPriority.low:
        return 1.5;
    }
  }

  /// Get labor rate based on priority
  double _getLaborRate(RequestPriority priority) {
    switch (priority) {
      case RequestPriority.critical:
        return 1200.0; // Premium rate for critical
      case RequestPriority.high:
        return 800.0;
      case RequestPriority.medium:
      case RequestPriority.low:
        return 500.0;
    }
  }

  /// Check if request requires materials
  bool _requestRequiresMaterials(ServiceRequest request) {
    // Simple heuristic: high/critical priority requests usually need materials
    return [RequestPriority.high, RequestPriority.critical].contains(request.priority);
  }

  /// Update invoice in current state
  void _updateInvoiceInState(Invoice updatedInvoice) {
    final updatedInvoices = _state.invoices.map((invoice) {
      return invoice.id == updatedInvoice.id ? updatedInvoice : invoice;
    }).toList();

    _updateState(_state.copyWith(invoices: updatedInvoices));
  }

  /// Update internal state and notify listeners
  void _updateState(BillingState newState) {
    _state = newState;
    notifyListeners();
  }

  /// Initialize billing service
  Future<void> initialize() async {
    await loadInvoices(refresh: true);
  }

  /// Refresh billing data
  Future<void> refresh() async {
    _cancelToken = Object();
    _searchDebounceTimer?.cancel();
    await loadInvoices(refresh: true);
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    super.dispose();
  }
}

/// Billing service state
class BillingState {
  const BillingState({
    this.invoices = const [],
    this.totalCount = 0,
    this.currentPage = 1,
    this.hasMore = false,
    this.filters = const InvoiceFilters(),
    this.isLoading = false,
    this.error,
    this.cursor,
  });

  final List<Invoice> invoices;
  final int totalCount;
  final int currentPage;
  final bool hasMore;
  final InvoiceFilters filters;
  final bool isLoading;
  final String? error;
  final InvoiceCursor? cursor;

  /// Create copy with updated fields
  BillingState copyWith({
    List<Invoice>? invoices,
    int? totalCount,
    int? currentPage,
    bool? hasMore,
    InvoiceFilters? filters,
    bool? isLoading,
    String? error,
    InvoiceCursor? cursor,
  }) {
    return BillingState(
      invoices: invoices ?? this.invoices,
      totalCount: totalCount ?? this.totalCount,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      filters: filters ?? this.filters,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      cursor: cursor,
    );
  }
}

/// Invoice detail with line items and payment attempts
class InvoiceDetail {
  const InvoiceDetail({
    required this.invoice,
    required this.lineItems,
    required this.paymentAttempts,
  });

  final Invoice invoice;
  final List<InvoiceLine> lineItems;
  final List<PaymentAttempt> paymentAttempts;

  /// Get last payment attempt
  PaymentAttempt? get lastPaymentAttempt {
    return paymentAttempts.isNotEmpty ? paymentAttempts.first : null;
  }

  /// Get successful payment attempts
  List<PaymentAttempt> get successfulAttempts {
    return paymentAttempts.where((attempt) => attempt.isSuccessful).toList();
  }

  /// Get failed payment attempts
  List<PaymentAttempt> get failedAttempts {
    return paymentAttempts.where((attempt) => attempt.isFailed).toList();
  }
}