import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme.dart';
import '../../auth/domain/auth_service.dart';
import '../domain/billing_service.dart';
import '../domain/invoice.dart';
import '../domain/payment_attempt.dart';

/// Sheet for collecting payment with PhonePe launcher and manual status update
class CollectPaymentSheet extends ConsumerStatefulWidget {
  const CollectPaymentSheet({
    super.key,
    required this.invoice,
    required this.onPaymentAttempt,
  });

  final Invoice invoice;
  final VoidCallback onPaymentAttempt;

  @override
  ConsumerState<CollectPaymentSheet> createState() => _CollectPaymentSheetState();
}

class _CollectPaymentSheetState extends ConsumerState<CollectPaymentSheet> {
  PaymentAttempt? _currentAttempt;
  bool _isProcessing = false;
  String? _error;

  // PhonePe configuration (in production, these would come from env/config)
  static const String _merchantId = 'MAINTPULSE001';
  static const String _merchantVpa = 'maintpulse@ybl';
  static const String _merchantName = 'MaintPulse';

  @override
  Widget build(BuildContext context) {
    final authService = ref.watch(authServiceProvider);
    final isAdmin = authService.userProfile?.role == UserRole.admin;

    return Container(
      padding: EdgeInsets.only(
        left: AppTheme.spacingL,
        right: AppTheme.spacingL,
        top: AppTheme.spacingL,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppTheme.spacingL,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Text(
                  'Collect Payment',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          
          const SizedBox(height: AppTheme.spacingM),
          
          // Invoice info
          _buildInvoiceInfo(),
          
          const SizedBox(height: AppTheme.spacingL),
          
          // Payment attempt status
          if (_currentAttempt != null)
            _buildPaymentAttemptStatus(),
          
          // Error display
          if (_error != null)
            _buildErrorDisplay(),
          
          const SizedBox(height: AppTheme.spacingL),
          
          // PhonePe payment button
          if (_currentAttempt == null)
            _buildPhonePeButton()
          else
            _buildStatusUpdateButtons(isAdmin),
        ],
      ),
    );
  }

  Widget _buildInvoiceInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.invoice.invoiceNumber,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '₹${widget.invoice.total.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: AppTheme.spacingS),
            
            Text(
              'Customer: ${widget.invoice.customerInfo.name}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            
            if (widget.invoice.isOverdue)
              Padding(
                padding: const EdgeInsets.only(top: AppTheme.spacingS),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.red, size: 16),
                    const SizedBox(width: AppTheme.spacingXS),
                    Text(
                      'Overdue by ${-widget.invoice.daysUntilDue} days',
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentAttemptStatus() {
    final attempt = _currentAttempt!;
    final color = Color(int.parse('0xFF${attempt.status.colorHex.substring(1)}'));
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment Attempt',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: AppTheme.spacingM),
            
            Row(
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
                        'Reference: ${attempt.referenceId}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                      Text(
                        '₹${attempt.amount.toStringAsFixed(2)} via ${attempt.paymentMethod.displayName}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: AppTheme.spacingM),
            
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingS),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue, size: 16),
                  const SizedBox(width: AppTheme.spacingS),
                  Expanded(
                    child: Text(
                      'Check your payment app and update the status below',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.blue[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorDisplay() {
    return Card(
      color: Colors.red.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: AppTheme.spacingM),
            Expanded(
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhonePeButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isProcessing ? null : _launchPhonePePayment,
        icon: _isProcessing 
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Image.asset(
                'assets/images/phonepe_logo.png', // You would add this asset
                width: 24,
                height: 24,
                errorBuilder: (context, error, stackTrace) => 
                    const Icon(Icons.smartphone),
              ),
        label: Text(_isProcessing ? 'Opening PhonePe...' : 'Pay with PhonePe'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF5F2D91), // PhonePe purple
          foregroundColor: Colors.white,
          padding: const EdgeInsets.all(AppTheme.spacingM),
        ),
      ),
    );
  }

  Widget _buildStatusUpdateButtons(bool isAdmin) {
    return Column(
      children: [
        // Payment successful button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _updatePaymentStatus(PaymentAttemptStatus.success),
            icon: const Icon(Icons.check_circle),
            label: const Text('Payment Successful'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(AppTheme.spacingM),
            ),
          ),
        ),
        
        const SizedBox(height: AppTheme.spacingS),
        
        // Payment failed button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _updatePaymentStatus(PaymentAttemptStatus.failed),
            icon: const Icon(Icons.error_outline),
            label: const Text('Payment Failed'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.all(AppTheme.spacingM),
            ),
          ),
        ),
        
        const SizedBox(height: AppTheme.spacingS),
        
        // Cancel button
        TextButton(
          onPressed: () {
            setState(() {
              _currentAttempt = null;
              _error = null;
            });
          },
          child: const Text('Try Different Payment Method'),
        ),
      ],
    );
  }

  Future<void> _launchPhonePePayment() async {
    try {
      setState(() {
        _isProcessing = true;
        _error = null;
      });

      // Generate reference ID
      final referenceId = PhonePeUtils.generateReferenceId(prefix: 'MP');

      // Record payment attempt
      final attempt = await ref.read(billingServiceProvider).recordPhonePeAttempt(
        invoiceId: widget.invoice.id!,
        amount: widget.invoice.total,
        referenceId: referenceId,
        notes: 'PhonePe payment attempt from mobile app',
      );

      setState(() {
        _currentAttempt = attempt;
        _isProcessing = false;
      });

      // Generate PhonePe deeplink
      final deeplink = PhonePeUtils.generateDeeplink(
        merchantId: _merchantId,
        transactionId: referenceId,
        amount: widget.invoice.total,
        merchantUserId: 'USER_${widget.invoice.customerInfo.name.replaceAll(' ', '_')}',
      );

      // Try to launch PhonePe app
      bool launched = false;
      
      try {
        final uri = Uri.parse(deeplink);
        launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } catch (e) {
        debugPrint('PhonePe deeplink failed: $e');
      }

      // Fallback to UPI intent
      if (!launched) {
        final upiIntent = PhonePeUtils.generateUpiIntent(
          merchantVpa: _merchantVpa,
          transactionId: referenceId,
          amount: widget.invoice.total,
          merchantName: _merchantName,
          note: 'Payment for ${widget.invoice.invoiceNumber}',
        );

        try {
          final uri = Uri.parse(upiIntent);
          launched = await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
        } catch (e) {
          debugPrint('UPI intent failed: $e');
        }
      }

      if (!launched) {
        // Show manual payment instructions
        _showManualPaymentInstructions(referenceId);
      } else {
        // Show success message
        _showSnackBar('PhonePe launched successfully. Complete payment and update status below.');
      }

    } catch (e) {
      setState(() {
        _isProcessing = false;
        _error = 'Failed to initiate payment: ${e.toString()}';
      });
    }
  }

  void _showManualPaymentInstructions(String referenceId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manual Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('PhonePe app could not be opened. Please make payment manually:'),
            const SizedBox(height: AppTheme.spacingM),
            
            Text('Amount: ₹${widget.invoice.total.toStringAsFixed(2)}'),
            const SizedBox(height: AppTheme.spacingS),
            
            Row(
              children: [
                const Text('UPI ID: '),
                Expanded(
                  child: Text(
                    _merchantVpa,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 16),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _merchantVpa));
                    _showSnackBar('UPI ID copied to clipboard');
                  },
                ),
              ],
            ),
            
            Row(
              children: [
                const Text('Reference: '),
                Expanded(
                  child: Text(
                    referenceId,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 16),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: referenceId));
                    _showSnackBar('Reference ID copied to clipboard');
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _updatePaymentStatus(PaymentAttemptStatus status) async {
    if (_currentAttempt == null) return;

    try {
      setState(() {
        _isProcessing = true;
        _error = null;
      });

      // Update payment attempt status (this would be done in the repository)
      // For MVP, we'll just update the invoice status directly
      final billingService = ref.read(billingServiceProvider);
      
      if (status == PaymentAttemptStatus.success) {
        await billingService.markPaid(widget.invoice.id!);
        _showSnackBar('Payment marked as successful!');
        widget.onPaymentAttempt();
        Navigator.of(context).pop();
      } else if (status == PaymentAttemptStatus.failed) {
        await billingService.markFailed(widget.invoice.id!);
        _showSnackBar('Payment marked as failed');
        widget.onPaymentAttempt();
        Navigator.of(context).pop();
      }

    } catch (e) {
      setState(() {
        _error = 'Failed to update payment status: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}