import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Snackbar priority levels
enum SnackbarPriority {
  info,
  warning,
  critical,
  success,
}

/// Snackbar notification data
class SnackbarNotification {
  const SnackbarNotification({
    required this.message,
    required this.priority,
    this.actionLabel,
    this.onAction,
    this.duration,
  });

  final String message;
  final SnackbarPriority priority;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Duration? duration;
}

/// Provider for SnackbarNotifier
final snackbarNotifierProvider = ChangeNotifierProvider<SnackbarNotifier>((ref) {
  return SnackbarNotifier();
});

/// Snackbar notification manager for critical events
class SnackbarNotifier extends ChangeNotifier {
  BuildContext? _context;
  
  /// Set the current context for showing snackbars
  void setContext(BuildContext context) {
    _context = context;
  }

  /// Show a snackbar notification
  void show(SnackbarNotification notification) {
    final context = _context;
    if (context == null || !context.mounted) {
      debugPrint('⚠️ Cannot show snackbar: no context available');
      return;
    }

    final priority = notification.priority;
    final snackBar = SnackBar(
      content: Row(
        children: [
          Icon(
            _getPriorityIcon(priority),
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              notification.message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: _getPriorityColor(priority),
      duration: notification.duration ?? _getDefaultDuration(priority),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      action: notification.actionLabel != null && notification.onAction != null
          ? SnackBarAction(
              label: notification.actionLabel!,
              textColor: Colors.white,
              onPressed: notification.onAction!,
            )
          : null,
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
    
    debugPrint('📱 Showed ${priority.name} snackbar: ${notification.message}');
  }

  /// Show info notification
  void showInfo(String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(SnackbarNotification(
      message: message,
      priority: SnackbarPriority.info,
      actionLabel: actionLabel,
      onAction: onAction,
    ));
  }

  /// Show warning notification
  void showWarning(String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(SnackbarNotification(
      message: message,
      priority: SnackbarPriority.warning,
      actionLabel: actionLabel,
      onAction: onAction,
    ));
  }

  /// Show critical notification
  void showCritical(String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(SnackbarNotification(
      message: message,
      priority: SnackbarPriority.critical,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: const Duration(seconds: 6), // Longer duration for critical
    ));
  }

  /// Show success notification
  void showSuccess(String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(SnackbarNotification(
      message: message,
      priority: SnackbarPriority.success,
      actionLabel: actionLabel,
      onAction: onAction,
    ));
  }

  /// Show request status change notification
  void showRequestStatusChange({
    required String requestId,
    required String oldStatus,
    required String newStatus,
    required BuildContext context,
  }) {
    final shortId = requestId.substring(0, 8);
    final message = 'Request #$shortId: $oldStatus → $newStatus';
    
    // Determine priority based on status
    SnackbarPriority priority;
    if (newStatus.toLowerCase() == 'on_site') {
      priority = SnackbarPriority.critical;
    } else if (['completed', 'verified'].contains(newStatus.toLowerCase())) {
      priority = SnackbarPriority.success;
    } else {
      priority = SnackbarPriority.info;
    }

    show(SnackbarNotification(
      message: message,
      priority: priority,
      actionLabel: 'View',
      onAction: () => context.go('/requests/$requestId'),
    ));
  }

  /// Show SLA breach notification
  void showSLABreach({
    required String requestId,
    required String status,
    required BuildContext context,
  }) {
    final shortId = requestId.substring(0, 8);
    final message = 'SLA BREACH: Request #$shortId is overdue!';
    
    show(SnackbarNotification(
      message: message,
      priority: SnackbarPriority.critical,
      actionLabel: 'View',
      onAction: () => context.go('/requests/$requestId'),
      duration: const Duration(seconds: 8), // Extra long for breaches
    ));
  }

  /// Show PM visit completion notification
  void showPMVisitCompleted({
    required String pmVisitId,
    required String facilityName,
    required BuildContext context,
  }) {
    final message = 'PM Visit completed at $facilityName';
    
    show(SnackbarNotification(
      message: message,
      priority: SnackbarPriority.success,
      actionLabel: 'View',
      onAction: () => context.go('/pm/$pmVisitId'),
    ));
  }

  /// Show PM visit overdue notification
  void showPMVisitOverdue({
    required String pmVisitId,
    required String facilityName,
    required BuildContext context,
  }) {
    final message = 'PM Visit overdue at $facilityName';
    
    show(SnackbarNotification(
      message: message,
      priority: SnackbarPriority.warning,
      actionLabel: 'View',
      onAction: () => context.go('/pm/$pmVisitId'),
    ));
  }

  /// Show connection status notification
  void showConnectionStatus({
    required bool isConnected,
    VoidCallback? onRetry,
  }) {
    if (isConnected) {
      showSuccess('Realtime connection restored');
    } else {
      showWarning(
        'Connection lost, updates may be delayed',
        actionLabel: onRetry != null ? 'Retry' : null,
        onAction: onRetry,
      );
    }
  }

  /// Get priority icon
  IconData _getPriorityIcon(SnackbarPriority priority) {
    switch (priority) {
      case SnackbarPriority.info:
        return Icons.info;
      case SnackbarPriority.warning:
        return Icons.warning;
      case SnackbarPriority.critical:
        return Icons.error;
      case SnackbarPriority.success:
        return Icons.check_circle;
    }
  }

  /// Get priority color
  Color _getPriorityColor(SnackbarPriority priority) {
    switch (priority) {
      case SnackbarPriority.info:
        return Colors.blue;
      case SnackbarPriority.warning:
        return Colors.orange;
      case SnackbarPriority.critical:
        return Colors.red;
      case SnackbarPriority.success:
        return Colors.green;
    }
  }

  /// Get default duration for priority
  Duration _getDefaultDuration(SnackbarPriority priority) {
    switch (priority) {
      case SnackbarPriority.info:
        return const Duration(seconds: 3);
      case SnackbarPriority.warning:
        return const Duration(seconds: 4);
      case SnackbarPriority.critical:
        return const Duration(seconds: 6);
      case SnackbarPriority.success:
        return const Duration(seconds: 3);
    }
  }
}