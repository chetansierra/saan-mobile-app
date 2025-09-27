import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../auth/domain/auth_service.dart';
import '../domain/billing_service.dart';
import '../domain/invoice.dart';
import '../domain/invoice_line.dart';
import '../domain/payment_attempt.dart';
import 'collect_payment_sheet.dart';

/// Invoice detail page with line items and payment options
class InvoiceDetailPage extends ConsumerStatefulWidget {
  const InvoiceDetailPage({
    super.key,
    required this.invoiceId,
  });

  final String invoiceId;

  @override
  ConsumerState<InvoiceDetailPage> createState() => _InvoiceDetailPageState();
}

class _InvoiceDetailPageState extends ConsumerState<InvoiceDetailPage> {
  InvoiceDetail? _invoiceDetail;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInvoiceDetail();
  }

  Future<void> _loadInvoiceDetail() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final detail = await ref.read(billingServiceProvider)
          .getInvoiceDetail(widget.invoiceId);

      setState(() {
        _invoiceDetail = detail;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = ref.watch(authServiceProvider);
    final isAdmin = authService.userProfile?.role == UserRole.admin;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Invoice')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _invoiceDetail == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Invoice')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.grey),
              const SizedBox(height: AppTheme.spacingM),
              Text(
                'Failed to load invoice',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppTheme.spacingS),
              Text(
                _error ?? 'Invoice not found',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spacingM),
              ElevatedButton(
                onPressed: _loadInvoiceDetail,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final invoice = _invoiceDetail!.invoice;
    final lineItems = _invoiceDetail!.lineItems;
    final paymentAttempts = _invoiceDetail!.paymentAttempts;

    return Scaffold(
      appBar: AppBar(
        title: Text(invoice.invoiceNumber),
        actions: [
          if (isAdmin)
            PopupMenuButton<String>(
              onSelected: (action) => _handleMenuAction(action, invoice),
              itemBuilder: (context) => [
                if (invoice.status == InvoiceStatus.draft)
                  const PopupMenuItem(
                    value: 'send',
                    child: Text('Send Invoice'),
                  ),
                if (invoice.status.canTransitionTo(InvoiceStatus.paid))
                  const PopupMenuItem(
                    value: 'mark_paid',
                    child: Text('Mark as Paid'),
                  ),
                if (invoice.status == InvoiceStatus.paid)
                  const PopupMenuItem(
                    value: 'refund',
                    child: Text('Process Refund'),
                  ),
                if (invoice.status == InvoiceStatus.draft)
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete Draft'),
                  ),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Invoice header
            _buildInvoiceHeader(invoice),
            
            const SizedBox(height: AppTheme.spacingL),
            
            // Customer info
            _buildCustomerInfo(invoice.customerInfo),
            
            const SizedBox(height: AppTheme.spacingL),
            
            // Line items
            _buildLineItems(lineItems),
            
            const SizedBox(height: AppTheme.spacingL),
            
            // Totals
            _buildTotals(invoice),
            
            const SizedBox(height: AppTheme.spacingL),
            
            // Payment attempts
            if (paymentAttempts.isNotEmpty)
              _buildPaymentAttempts(paymentAttempts),
            
            const SizedBox(height: AppTheme.spacingL),
            
            // Notes
            if (invoice.notes != null && invoice.notes!.isNotEmpty)
              _buildNotes(invoice.notes!),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomActions(invoice),
    );
  }

  Widget _buildInvoiceHeader(Invoice invoice) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invoice.invoiceNumber,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Issued: ${DateFormat('MMM dd, yyyy').format(invoice.issueDate)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(invoice.status),
              ],
            ),
            
            const SizedBox(height: AppTheme.spacingM),
            
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Due Date',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        DateFormat('MMM dd, yyyy').format(invoice.dueDate),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: invoice.isOverdue ? Colors.red : null,
                          fontWeight: invoice.isOverdue ? FontWeight.bold : null,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Amount',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        '₹${invoice.total.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            if (invoice.isOverdue)
              Padding(
                padding: const EdgeInsets.only(top: AppTheme.spacingM),
                child: Container(
                  padding: const EdgeInsets.all(AppTheme.spacingS),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.red, size: 20),
                      const SizedBox(width: AppTheme.spacingS),
                      Text(
                        'Overdue by ${-invoice.daysUntilDue} days',
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerInfo(CustomerInfo customer) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Customer Information',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            
            _buildInfoRow('Name', customer.name),
            _buildInfoRow('Email', customer.email),
            if (customer.phone != null)
              _buildInfoRow('Phone', customer.phone!),
            if (customer.address != null)
              _buildInfoRow('Address', customer.address!),
            if (customer.gstNumber != null)
              _buildInfoRow('GST Number', customer.gstNumber!),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingS),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineItems(List<InvoiceLine> lineItems) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Line Items',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            
            // Line items table
            Table(
              columnWidths: const {
                0: FlexColumnWidth(3),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(1.5),
                3: FlexColumnWidth(1.5),
              },
              children: [
                // Header
                TableRow(
                  children: [
                    _buildTableHeader('Description'),
                    _buildTableHeader('Qty'),
                    _buildTableHeader('Rate'),
                    _buildTableHeader('Amount'),
                  ],
                ),
                
                // Line items
                ...lineItems.map((line) => TableRow(
                  children: [
                    _buildTableCell(line.description),
                    _buildTableCell(line.quantity.toStringAsFixed(0)),
                    _buildTableCell('₹${line.unitPrice.toStringAsFixed(2)}'),
                    _buildTableCell('₹${line.lineTotal.toStringAsFixed(2)}'),
                  ],
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingS),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildTableCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingS),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }

  Widget _buildTotals(Invoice invoice) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Totals',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            
            _buildTotalRow('Subtotal', invoice.subtotal),
            _buildTotalRow('Tax', invoice.taxAmount),
            const Divider(),
            _buildTotalRow('Total', invoice.total, isTotal: true),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingS),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: isTotal ? FontWeight.bold : null,
            ),
          ),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: isTotal ? FontWeight.bold : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentAttempts(List<PaymentAttempt> attempts) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment Attempts',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            
            ...attempts.map((attempt) => _buildPaymentAttemptItem(attempt)),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentAttemptItem(PaymentAttempt attempt) {
    final color = Color(int.parse('0xFF${attempt.status.colorHex.substring(1)}'));
    
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingM),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingS,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Text(
              attempt.status.displayName,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spacingM),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${attempt.paymentMethod.displayName} - ₹${attempt.amount.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  DateFormat('MMM dd, yyyy HH:mm').format(attempt.attemptDate),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                if (attempt.errorMessage != null)
                  Text(
                    attempt.errorMessage!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.red,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotes(String notes) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notes',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            Text(
              notes,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(InvoiceStatus status) {
    final color = Color(int.parse('0xFF${status.colorHex.substring(1)}'));
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingS,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget? _buildBottomActions(Invoice invoice) {
    // Only show payment button for unpaid invoices
    if (!invoice.isUnpaid) {
      return null;
    }

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _showCollectPaymentSheet(invoice),
          icon: const Icon(Icons.payment),
          label: Text('Collect Payment - ₹${invoice.total.toStringAsFixed(2)}'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.all(AppTheme.spacingM),
          ),
        ),
      ),
    );
  }

  void _showCollectPaymentSheet(Invoice invoice) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => CollectPaymentSheet(
        invoice: invoice,
        onPaymentAttempt: () {
          // Reload invoice detail to show new payment attempt
          _loadInvoiceDetail();
        },
      ),
    );
  }

  void _handleMenuAction(String action, Invoice invoice) async {
    try {
      final billingService = ref.read(billingServiceProvider);
      
      switch (action) {
        case 'send':
          await billingService.sendInvoice(invoice.id!);
          _loadInvoiceDetail();
          _showSnackBar('Invoice sent successfully');
          break;
          
        case 'mark_paid':
          await billingService.markPaid(invoice.id!);
          _loadInvoiceDetail();
          _showSnackBar('Invoice marked as paid');
          break;
          
        case 'refund':
          final confirmed = await _showConfirmDialog(
            'Process Refund',
            'Are you sure you want to process a refund for this invoice?',
          );
          if (confirmed) {
            await billingService.markRefunded(invoice.id!);
            _loadInvoiceDetail();
            _showSnackBar('Refund processed');
          }
          break;
          
        case 'delete':
          final confirmed = await _showConfirmDialog(
            'Delete Invoice',
            'Are you sure you want to delete this draft invoice? This action cannot be undone.',
          );
          if (confirmed) {
            await billingService.deleteDraftInvoice(invoice.id!);
            if (mounted) {
              context.go('/billing');
            }
          }
          break;
      }
    } catch (e) {
      _showSnackBar('Failed to ${action.replaceAll('_', ' ')}: ${e.toString()}');
    }
  }

  Future<bool> _showConfirmDialog(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }
}