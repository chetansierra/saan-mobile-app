import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/realtime/realtime_client.dart';
import '../../../core/ui/snackbar_notifier.dart';
import '../../auth/domain/auth_service.dart';
import '../domain/pm_service.dart';
import '../domain/pm_visit.dart';

/// Provider for PMRealtimeManager
final pmRealtimeProvider = Provider<PMRealtimeManager>((ref) {
  return PMRealtimeManager(
    ref.watch(realtimeClientProvider),
    ref.watch(pmServiceProvider),
    ref.watch(snackbarNotifierProvider),
    ref.watch(authServiceProvider),
  );
});

/// Realtime manager for PM visits with event processing and notifications
class PMRealtimeManager {
  PMRealtimeManager(
    this._realtimeClient,
    this._pmService,
    this._snackbarNotifier,
    this._authService,
  );

  final RealtimeClient _realtimeClient;
  final PMService _pmService;
  final SnackbarNotifier _snackbarNotifier;
  final AuthService _authService;

  StreamSubscription<EventBatch>? _subscription;
  final Set<String> _processedEventIds = {};
  final Map<String, DateTime> _lastNotificationTimes = {};
  final Map<String, PMVisit> _lastKnownStates = {};
  
  static const Duration _notificationCooldown = Duration(seconds: 10);
  static const String _tableName = 'pm_visits';

  /// Current tenant ID
  String? get _tenantId => _authService.tenantId;

  /// Subscribe to PM visits realtime updates
  void subscribe() {
    if (_subscription != null) {
      debugPrint('🔴 [PMRT] Already subscribed to PM visits realtime');
      return;
    }

    final tenantId = _tenantId;
    if (tenantId == null) {
      debugPrint('⚠️ [PMRT] No tenant context, skipping subscription');
      return;
    }

    try {
      debugPrint('🔴 [PMRT] Subscribing to PM visits realtime updates for tenant: $tenantId');
      
      final stream = _realtimeClient.subscribeToTable(
        _tableName,
        events: ['INSERT', 'UPDATE'],
      );

      _subscription = stream.listen(
        _handleEventBatch,
        onError: (error) {
          debugPrint('❌ [PMRT] PM visits realtime error: $error');
        },
        onDone: () {
          debugPrint('🔴 [PMRT] PM visits realtime stream closed');
        },
      );

      debugPrint('✅ [PMRT] Subscribed to PM visits realtime updates');
    } catch (e) {
      debugPrint('❌ [PMRT] Failed to subscribe to PM visits realtime: $e');
    }
  }

  /// Unsubscribe from PM visits realtime updates
  void unsubscribe() {
    if (_subscription == null) {
      debugPrint('🔴 [PMRT] No PM visits realtime subscription to cancel');
      return;
    }

    debugPrint('🔴 [PMRT] Unsubscribing from PM visits realtime updates');
    _subscription?.cancel();
    _subscription = null;
    _processedEventIds.clear();
    _lastNotificationTimes.clear();
    _lastKnownStates.clear();
    
    _realtimeClient.unsubscribeFromTable(_tableName);
    debugPrint('✅ [PMRT] Unsubscribed from PM visits realtime updates');
  }

  /// Handle batch of realtime events
  void _handleEventBatch(EventBatch batch) {
    debugPrint('🔴 [PMRT] Processing ${batch.events.length} PM visit events');

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

    // Selective refresh: only refresh service if needed
    if (shouldRefreshService) {
      debugPrint('🔴 [PMRT] Triggering PM service refresh (selective)');
      _refreshPMServiceSelectively(batch.events);
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
      if (record == null) {
        return EventProcessingResult.ignored;
      }

      final pmVisitId = record['id'] as String?;
      if (pmVisitId == null) {
        return EventProcessingResult.ignored;
      }

      if (event.isInsert) {
        debugPrint('🔴 [PMRT] New PM visit created: $pmVisitId');
        return EventProcessingResult.refresh;
      }

      if (event.isUpdate && event.oldRecord != null) {
        return _processUpdateEvent(record, event.oldRecord!);
      }

      return EventProcessingResult.ignored;
    } catch (e) {
      debugPrint('❌ [PMRT] Error processing PM visit event: $e');
      return EventProcessingResult.ignored;
    }
  }

  /// Process PM visit update event
  EventProcessingResult _processUpdateEvent(
    Map<String, dynamic> newRecord,
    Map<String, dynamic> oldRecord,
  ) {
    final pmVisitId = newRecord['id'] as String?;
    if (pmVisitId == null) return EventProcessingResult.ignored;

    bool shouldRefresh = false;
    bool isCritical = false;

    // Check for status changes
    final oldStatus = oldRecord['status'] as String?;
    final newStatus = newRecord['status'] as String?;
    
    if (oldStatus != newStatus && newStatus != null) {
      debugPrint('🔴 [PMRT] PM visit $pmVisitId status changed: $oldStatus → $newStatus');
      shouldRefresh = true;
      
      // Critical status: completed
      if (newStatus.toLowerCase() == 'completed') {
        isCritical = true;
      }
    }

    // Check for completion date changes
    final oldCompletedDate = oldRecord['completed_date'] as String?;
    final newCompletedDate = newRecord['completed_date'] as String?;
    
    if (oldCompletedDate != newCompletedDate && newCompletedDate != null) {
      debugPrint('🔴 [PMRT] PM visit $pmVisitId completed at: $newCompletedDate');
      shouldRefresh = true;
      isCritical = true;
    }

    // Check for engineer assignment
    final oldEngineer = oldRecord['engineer_name'] as String?;
    final newEngineer = newRecord['engineer_name'] as String?;
    
    if (oldEngineer != newEngineer && newEngineer != null) {
      debugPrint('🔴 [PMRT] PM visit $pmVisitId engineer changed: $oldEngineer → $newEngineer');
      shouldRefresh = true;
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

    final pmVisitId = record['id'] as String?;
    if (pmVisitId == null) return;

    try {
      final pmVisit = PMVisit.fromJson(record);
      final previousVisit = _lastKnownStates[pmVisitId];
      _lastKnownStates[pmVisitId] = pmVisit;

      // Priority 3: PM visit → completed (success)
      if (event.isUpdate && 
          previousVisit != null && 
          previousVisit.status != PMVisitStatus.completed && 
          pmVisit.status == PMVisitStatus.completed) {
        
        // Get facility name from record or use ID
        final facilityName = record['facility_name'] as String? ?? 'Facility';
        
        _showNotificationWithCooldown(
          key: 'pm_completed_$pmVisitId',
          priority: SnackbarPriority.success,
          message: 'PM Visit completed at $facilityName',
          actionRoute: '/pm/$pmVisitId',
        );
      }

      // Additional: PM visit overdue notification
      if (pmVisit.isOverdue && pmVisit.status != PMVisitStatus.completed) {
        final facilityName = record['facility_name'] as String? ?? 'Facility';
        
        _showNotificationWithCooldown(
          key: 'pm_overdue_$pmVisitId',
          priority: SnackbarPriority.warning,
          message: 'PM Visit overdue at $facilityName',
          actionRoute: '/pm/$pmVisitId',
        );
      }

    } catch (e) {
      debugPrint('❌ [PMRT] Error handling PM critical event: $e');
    }
  }

  /// Show notification with cooldown and coalescing
  void _showNotificationWithCooldown({
    required String key,
    required SnackbarPriority priority,
    required String message,
    required String actionRoute,
  }) {
    final now = DateTime.now();
    final lastNotification = _lastNotificationTimes[key];
    
    // Coalesce duplicates within 10s
    if (lastNotification != null && 
        now.difference(lastNotification) < _notificationCooldown) {
      debugPrint('🔕 [PMRT] Notification cooldown: $key');
      return;
    }

    _lastNotificationTimes[key] = now;

    // Get context for navigation
    final context = _snackbarNotifier._context;
    if (context == null || !context.mounted) {
      debugPrint('⚠️ [PMRT] No context for critical event notification');
      return;
    }

    _snackbarNotifier.show(SnackbarNotification(
      message: message,
      priority: priority,
      actionLabel: 'View',
      onAction: () => context.go(actionRoute),
      duration: _getNotificationDuration(priority),
    ));

    debugPrint('📱 [PMRT] Showed ${priority.name} notification: $message');
  }

  /// Get notification duration based on priority
  Duration _getNotificationDuration(SnackbarPriority priority) {
    switch (priority) {
      case SnackbarPriority.critical:
        return const Duration(seconds: 6); // Red emphasis
      case SnackbarPriority.warning:
        return const Duration(seconds: 6); // Amber, auto-dismiss 6s  
      case SnackbarPriority.success:
        return const Duration(seconds: 4); // Green, auto-dismiss 4s
      case SnackbarPriority.info:
        return const Duration(seconds: 3); // Default
    }
  }

  /// Refresh PM service selectively based on events
  void _refreshPMServiceSelectively(List<RealtimeEvent> events) {
    try {
      // Get current visits from service
      final currentVisits = List<PMVisit>.from(_pmService.visits);
      bool hasChanges = false;

      for (final event in events) {
        final record = event.record;
        if (record == null) continue;

        final pmVisit = PMVisit.fromJson(record);
        final pmVisitId = pmVisit.id;
        if (pmVisitId == null) continue;

        if (event.isInsert) {
          // Add new PM visit
          final existsInList = currentVisits.any((v) => v.id == pmVisitId);
          if (!existsInList) {
            currentVisits.insert(0, pmVisit); // Add to top
            hasChanges = true;
            debugPrint('🆕 [PMRT] Added new PM visit: $pmVisitId');
          }
        } else if (event.isUpdate) {
          // Update existing PM visit
          for (int i = 0; i < currentVisits.length; i++) {
            if (currentVisits[i].id == pmVisitId) {
              currentVisits[i] = pmVisit;
              hasChanges = true;
              debugPrint('🔄 [PMRT] Updated existing PM visit: $pmVisitId');
              break;
            }
          }
        }
      }

      // Apply changes to service if any
      if (hasChanges) {
        final newState = _pmService.state.copyWith(visits: currentVisits);
        // Update service state directly (bypassing normal methods)
        _pmService._updateState(newState);
        
        debugPrint('✅ [PMRT] Applied selective updates to PM service');
      }
    } catch (e) {
      debugPrint('❌ [PMRT] Error in selective refresh: $e');
      // Fall back to full refresh
      _pmService.refreshPMVisits();
    }
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
    debugPrint('🔴 [PMRT] Disposing PMRealtimeManager');
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

/// Hook for automatic PM realtime subscription management
class PMRealtimeHook extends ConsumerStatefulWidget {
  const PMRealtimeHook({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  ConsumerState<PMRealtimeHook> createState() => _PMRealtimeHookState();
}

class _PMRealtimeHookState extends ConsumerState<PMRealtimeHook> {
  @override
  void initState() {
    super.initState();
    // Subscribe on next frame to ensure providers are ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(pmRealtimeProvider).subscribe();
    });
  }

  @override
  void dispose() {
    ref.read(pmRealtimeProvider).unsubscribe();
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