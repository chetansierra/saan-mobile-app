import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/realtime/realtime_client.dart';
import '../../../core/ui/snackbar_notifier.dart';
import '../../auth/domain/auth_service.dart';
import '../domain/requests_service.dart';
import '../domain/models/request.dart';

/// Provider for RequestsRealtimeManager
final requestsRealtimeProvider = Provider<RequestsRealtimeManager>((ref) {
  return RequestsRealtimeManager(
    ref.watch(realtimeClientProvider),
    ref.watch(requestsServiceProvider),
    ref.watch(snackbarNotifierProvider),
    ref.watch(authServiceProvider),
  );
});

/// Realtime manager for requests with event processing and notifications
class RequestsRealtimeManager {
  RequestsRealtimeManager(
    this._realtimeClient,
    this._requestsService,
    this._snackbarNotifier,
    this._authService,
  );

  final RealtimeClient _realtimeClient;
  final RequestsService _requestsService;
  final SnackbarNotifier _snackbarNotifier;
  final AuthService _authService;

  StreamSubscription<EventBatch>? _subscription;
  final Set<String> _processedEventIds = {};
  final Map<String, DateTime> _lastNotificationTimes = {};
  final Map<String, ServiceRequest> _lastKnownStates = {};
  
  static const Duration _notificationCooldown = Duration(seconds: 10);

  /// Subscribe to requests realtime updates
  void subscribe() {
    if (_subscription != null) {
      debugPrint('🔴 Already subscribed to requests realtime');
      return;
    }

    try {
      debugPrint('🔴 Subscribing to requests realtime updates');
      
      final stream = _realtimeClient.subscribeToTable(
        'requests',
        events: ['INSERT', 'UPDATE'],
      );

      _subscription = stream.listen(
        _handleEventBatch,
        onError: (error) {
          debugPrint('❌ Requests realtime error: $error');
        },
        onDone: () {
          debugPrint('🔴 Requests realtime stream closed');
        },
      );

      debugPrint('✅ Subscribed to requests realtime updates');
    } catch (e) {
      debugPrint('❌ Failed to subscribe to requests realtime: $e');
    }
  }

  /// Unsubscribe from requests realtime updates
  void unsubscribe() {
    if (_subscription == null) {
      debugPrint('🔴 No requests realtime subscription to cancel');
      return;
    }

    debugPrint('🔴 Unsubscribing from requests realtime updates');
    _subscription?.cancel();
    _subscription = null;
    _processedEventIds.clear();
    
    _realtimeClient.unsubscribeFromTable('requests');
    debugPrint('✅ Unsubscribed from requests realtime updates');
  }

  /// Handle batch of realtime events
  void _handleEventBatch(EventBatch batch) {
    debugPrint('🔴 Processing ${batch.events.length} request events');

    bool shouldRefreshService = false;
    final criticalEvents = <RealtimeEvent>[];

    for (final event in batch.events) {
      // Prevent duplicate processing
      final eventId = _generateEventId(event);
      if (_processedEventIds.contains(eventId)) {
        continue;
      }
      _processedEventIds.add(eventId);

      // Process event
      final processed = _processEvent(event);
      if (processed.shouldRefresh) {
        shouldRefreshService = true;
      }

      if (processed.isCritical) {
        criticalEvents.add(event);
      }
    }

    // Refresh service state if needed
    if (shouldRefreshService) {
      debugPrint('🔴 Triggering requests service refresh');
      _requestsService.refreshRequests();
    }

    // Process critical events for notifications
    for (final event in criticalEvents) {
      _handleCriticalEvent(event);
    }

    // Cleanup old processed event IDs to prevent memory leak
    if (_processedEventIds.length > 1000) {
      final toRemove = _processedEventIds.take(500).toList();
      _processedEventIds.removeAll(toRemove);
    }
  }

  /// Process individual event and determine actions
  EventProcessingResult _processEvent(RealtimeEvent event) {
    try {
      final record = event.record;
      final oldRecord = event.oldRecord;
      
      if (record == null) {
        return EventProcessingResult.ignored;
      }

      final requestId = record['id'] as String?;
      if (requestId == null) {
        return EventProcessingResult.ignored;
      }

      if (event.isInsert) {
        debugPrint('🔴 New request created: $requestId');
        return EventProcessingResult.refresh;
      }

      if (event.isUpdate && oldRecord != null) {
        return _processUpdateEvent(record, oldRecord);
      }

      return EventProcessingResult.ignored;
    } catch (e) {
      debugPrint('❌ Error processing request event: $e');
      return EventProcessingResult.ignored;
    }
  }

  /// Process request update event
  EventProcessingResult _processUpdateEvent(
    Map<String, dynamic> newRecord,
    Map<String, dynamic> oldRecord,
  ) {
    final requestId = newRecord['id'] as String?;
    if (requestId == null) return EventProcessingResult.ignored;

    bool shouldRefresh = false;
    bool isCritical = false;

    // Check for status changes
    final oldStatus = oldRecord['status'] as String?;
    final newStatus = newRecord['status'] as String?;
    
    if (oldStatus != newStatus && newStatus != null) {
      debugPrint('🔴 Request $requestId status changed: $oldStatus → $newStatus');
      shouldRefresh = true;
      
      // Critical status: on_site
      if (newStatus.toLowerCase() == 'on_site') {
        isCritical = true;
      }
    }

    // Check for assignee changes
    final oldAssignee = oldRecord['assigned_engineer_name'] as String?;
    final newAssignee = newRecord['assigned_engineer_name'] as String?;
    
    if (oldAssignee != newAssignee) {
      debugPrint('🔴 Request $requestId assignee changed: $oldAssignee → $newAssignee');
      shouldRefresh = true;
    }

    // Check for SLA breach (sla_due_at in the past and status not completed)
    final slaDueAtStr = newRecord['sla_due_at'] as String?;
    final status = newRecord['status'] as String?;
    
    if (slaDueAtStr != null && status != null) {
      try {
        final slaDueAt = DateTime.parse(slaDueAtStr);
        final isOverdue = DateTime.now().isAfter(slaDueAt);
        final isCompleted = _isCompletedStatus(status);
        
        if (isOverdue && !isCompleted) {
          // Check if this is a new breach (wasn't overdue before)
          final oldSlaDueAtStr = oldRecord['sla_due_at'] as String?;
          if (oldSlaDueAtStr != null) {
            final oldSlaDueAt = DateTime.parse(oldSlaDueAtStr);
            final wasOverdue = DateTime.now().isAfter(oldSlaDueAt);
            
            if (!wasOverdue) {
              debugPrint('🔴 Request $requestId SLA breach detected');
              isCritical = true;
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ Error parsing SLA dates: $e');
      }
    }

    return EventProcessingResult(
      shouldRefresh: shouldRefresh,
      isCritical: isCritical,
    );
  }

  /// Handle critical events with notifications
  void _handleCriticalEvent(RealtimeEvent event) {
    final record = event.record;
    if (record == null) return;

    final requestId = record['id'] as String?;
    final status = record['status'] as String?;
    
    if (requestId == null) return;

    // Get context for navigation
    final context = _snackbarNotifier._context;
    if (context == null || !context.mounted) {
      debugPrint('⚠️ No context for critical event notification');
      return;
    }

    if (event.isUpdate && event.oldRecord != null) {
      final oldStatus = event.oldRecord!['status'] as String?;
      
      // Status change to on_site
      if (status?.toLowerCase() == 'on_site' && oldStatus != status) {
        _snackbarNotifier.showRequestStatusChange(
          requestId: requestId,
          oldStatus: oldStatus ?? 'unknown',
          newStatus: status!,
          context: context,
        );
        return;
      }

      // SLA breach
      final slaDueAtStr = record['sla_due_at'] as String?;
      if (slaDueAtStr != null && status != null) {
        try {
          final slaDueAt = DateTime.parse(slaDueAtStr);
          final isOverdue = DateTime.now().isAfter(slaDueAt);
          final isCompleted = _isCompletedStatus(status);
          
          if (isOverdue && !isCompleted) {
            _snackbarNotifier.showSLABreach(
              requestId: requestId,
              status: status,
              context: context,
            );
          }
        } catch (e) {
          debugPrint('⚠️ Error processing SLA breach notification: $e');
        }
      }
    }
  }

  /// Check if status represents a completed request
  bool _isCompletedStatus(String status) {
    final completedStatuses = ['completed', 'verified', 'closed'];
    return completedStatuses.contains(status.toLowerCase());
  }

  /// Generate unique event ID for deduplication
  String _generateEventId(RealtimeEvent event) {
    final record = event.record;
    final recordId = record?['id'] ?? 'unknown';
    final updatedAt = record?['updated_at'] ?? DateTime.now().toIso8601String();
    return '${event.table}_${event.eventType}_${recordId}_$updatedAt';
  }

  /// Dispose of resources
  void dispose() {
    debugPrint('🔴 Disposing RequestsRealtimeManager');
    unsubscribe();
  }
}

/// Result of event processing
class EventProcessingResult {
  const EventProcessingResult({
    required this.shouldRefresh,
    required this.isCritical,
  });

  final bool shouldRefresh;
  final bool isCritical;

  static const ignored = EventProcessingResult(
    shouldRefresh: false,
    isCritical: false,
  );

  static const refresh = EventProcessingResult(
    shouldRefresh: true,
    isCritical: false,
  );

  static const critical = EventProcessingResult(
    shouldRefresh: true,
    isCritical: true,
  );
}

/// Hook for automatic requests realtime subscription management
class RequestsRealtimeHook extends ConsumerStatefulWidget {
  const RequestsRealtimeHook({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  ConsumerState<RequestsRealtimeHook> createState() => _RequestsRealtimeHookState();
}

class _RequestsRealtimeHookState extends ConsumerState<RequestsRealtimeHook> {
  @override
  void initState() {
    super.initState();
    // Subscribe on next frame to ensure providers are ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(requestsRealtimeProvider).subscribe();
    });
  }

  @override
  void dispose() {
    ref.read(requestsRealtimeProvider).unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Set snackbar context
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(snackbarNotifierProvider).setContext(context);
    });

    return widget.child;
  }
}