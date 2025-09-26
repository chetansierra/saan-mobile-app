#!/usr/bin/env python3
"""
Flutter Realtime Implementation Testing Suite

This test suite validates the Flutter realtime implementation for:
1. RealtimeClient - Supabase channel management, tenant-scoped subscriptions, event processing, debouncing
2. SnackbarNotifier - Priority-styled notifications with correct styling and durations
3. ConnectionIndicator - Subtle connection status display
4. RequestsRealtimeManager - Tenant-scoped event processing for priority notifications
5. PMRealtimeManager - PM visit updates and completion notifications
6. Event filtering, debouncing, selective updates, and integration testing

Focus: Realtime event processing logic, notification priorities, tenant isolation, debouncing patterns
"""

import json
import sys
import traceback
from datetime import datetime
from typing import Dict, List, Any, Optional

class FlutterRealtimeBackendTester:
    """Test suite for Flutter realtime implementation"""
    
    def __init__(self):
        self.test_results = []
        self.errors = []
        self.warnings = []
        
    def log_result(self, test_name: str, status: str, message: str, details: Optional[Dict] = None):
        """Log test result"""
        result = {
            'test': test_name,
            'status': status,  # 'PASS', 'FAIL', 'SKIP', 'WARNING'
            'message': message,
            'timestamp': datetime.now().isoformat(),
            'details': details or {}
        }
        self.test_results.append(result)
        
        status_emoji = {
            'PASS': '✅',
            'FAIL': '❌', 
            'SKIP': '⏭️',
            'WARNING': '⚠️'
        }
        
        print(f"{status_emoji.get(status, '❓')} {test_name}: {message}")
        if details:
            print(f"   Details: {json.dumps(details, indent=2)}")
    
    def test_realtime_client_structure(self):
        """Test RealtimeClient structure and core functionality"""
        test_name = "RealtimeClient Structure & Core Functionality"
        
        try:
            with open('/app/lib/core/realtime/realtime_client.dart', 'r') as f:
                content = f.read()
            
            # Check core realtime client patterns
            checks = {
                'provider_definition': 'final realtimeClientProvider = Provider<RealtimeClient>',
                'connection_states': 'enum RealtimeConnectionState',
                'connection_states_values': 'connecting,\n  connected,\n  disconnected,\n  reconnecting',
                'realtime_event_class': 'class RealtimeEvent',
                'event_batch_class': 'class EventBatch',
                'supabase_client': 'final SupabaseClient _client = SupabaseService.client',
                'tenant_filtering': 'String? get _tenantId => _authService.tenantId',
                'debounce_delay': 'static const Duration _debounceDelay = Duration(milliseconds: 300)',
                'subscribe_to_table': 'Stream<EventBatch> subscribeToTable',
                'channel_management': 'final Map<String, RealtimeChannel> _channels',
                'event_controllers': 'final Map<String, StreamController<EventBatch>> _eventControllers',
                'debounce_timers': 'final Map<String, Timer?> _debounceTimers',
                'pending_events': 'final Map<String, List<RealtimeEvent>> _pendingEvents',
                'tenant_scoped_channels': 'final channelKey = \'${table}_$tenantId\'',
                'tenant_filters': 'final tenantFilters = {\n        \'tenant_id\': \'eq.$tenantId\'',
                'event_filtering': "if (!['INSERT', 'UPDATE'].contains(eventType))",
                'cross_tenant_validation': 'if (recordTenantId != currentTenantId)',
                'reconnection_logic': 'void _scheduleReconnect()',
                'max_reconnect_attempts': 'static const int _maxReconnectAttempts = 5',
                'exponential_backoff': 'final delay = _reconnectDelay * _reconnectAttempts'
            }
            
            passed_checks = []
            failed_checks = []
            
            for check_name, pattern in checks.items():
                if pattern in content:
                    passed_checks.append(check_name)
                else:
                    failed_checks.append(check_name)
            
            if failed_checks:
                self.log_result(test_name, 'FAIL', 
                    f'Missing RealtimeClient patterns: {", ".join(failed_checks)}',
                    {'passed': passed_checks, 'failed': failed_checks})
            else:
                self.log_result(test_name, 'PASS', 
                    'RealtimeClient properly implemented with all required patterns',
                    {'validated_patterns': passed_checks})
                
        except Exception as e:
            self.log_result(test_name, 'FAIL', f'Error reading RealtimeClient file: {str(e)}')
    
    def test_snackbar_notifier_structure(self):
        """Test SnackbarNotifier structure and priority styling"""
        test_name = "SnackbarNotifier Structure & Priority Styling"
        
        try:
            with open('/app/lib/core/ui/snackbar_notifier.dart', 'r') as f:
                content = f.read()
            
            # Check snackbar notifier patterns
            checks = {
                'priority_enum': 'enum SnackbarPriority',
                'priority_values': 'info,\n  warning,\n  critical,\n  success',
                'notification_class': 'class SnackbarNotification',
                'provider_definition': 'final snackbarNotifierProvider = ChangeNotifierProvider<SnackbarNotifier>',
                'context_management': 'BuildContext? _context',
                'set_context_method': 'void setContext(BuildContext context)',
                'show_method': 'void show(SnackbarNotification notification)',
                'priority_colors': 'Color _getPriorityColor(SnackbarPriority priority)',
                'priority_icons': 'IconData _getPriorityIcon(SnackbarPriority priority)',
                'default_durations': 'Duration _getDefaultDuration(SnackbarPriority priority)',
                'critical_duration': 'return const Duration(seconds: 6)',
                'warning_duration': 'return const Duration(seconds: 4)',
                'success_duration': 'return const Duration(seconds: 3)',
                'info_duration': 'return const Duration(seconds: 3)',
                'critical_color': 'return Colors.red',
                'warning_color': 'return Colors.orange',
                'success_color': 'return Colors.green',
                'info_color': 'return Colors.blue',
                'floating_behavior': 'behavior: SnackBarBehavior.floating',
                'rounded_corners': 'shape: RoundedRectangleBorder',
                'action_support': 'action: notification.actionLabel != null'
            }
            
            passed_checks = []
            failed_checks = []
            
            for check_name, pattern in checks.items():
                if pattern in content:
                    passed_checks.append(check_name)
                else:
                    failed_checks.append(check_name)
            
            # Check specific duration requirements
            duration_checks = {
                'critical_6s': 'critical:\n        return const Duration(seconds: 6)',
                'warning_4s': 'warning:\n        return const Duration(seconds: 4)', 
                'success_3s': 'success:\n        return const Duration(seconds: 3)',
                'info_3s': 'info:\n        return const Duration(seconds: 3)'
            }
            
            duration_passed = []
            duration_failed = []
            
            for check_name, pattern in duration_checks.items():
                if pattern in content:
                    duration_passed.append(check_name)
                else:
                    duration_failed.append(check_name)
            
            if failed_checks or duration_failed:
                self.log_result(test_name, 'FAIL', 
                    f'Missing SnackbarNotifier patterns',
                    {
                        'passed': passed_checks, 
                        'failed': failed_checks,
                        'duration_passed': duration_passed,
                        'duration_failed': duration_failed
                    })
            else:
                self.log_result(test_name, 'PASS', 
                    'SnackbarNotifier properly implemented with correct priority styling and durations',
                    {'validated_patterns': passed_checks, 'duration_patterns': duration_passed})
                
        except Exception as e:
            self.log_result(test_name, 'FAIL', f'Error reading SnackbarNotifier file: {str(e)}')
    
    def test_connection_indicator_structure(self):
        """Test ConnectionIndicator structure and states"""
        test_name = "ConnectionIndicator Structure & Connection States"
        
        try:
            with open('/app/lib/core/ui/connection_indicator.dart', 'r') as f:
                content = f.read()
            
            # Check connection indicator patterns
            checks = {
                'connection_indicator_class': 'class ConnectionIndicator extends ConsumerWidget',
                'floating_indicator_class': 'class FloatingConnectionIndicator extends ConsumerWidget',
                'realtime_client_watch': 'final realtimeClient = ref.watch(realtimeClientProvider)',
                'connection_state_access': 'final connectionState = realtimeClient.connectionState',
                'hide_when_connected': 'if (connectionState == RealtimeConnectionState.connected && !showLabel)',
                'animated_opacity': 'AnimatedOpacity',
                'opacity_method': 'double _getOpacity(RealtimeConnectionState state)',
                'background_color_method': 'Color _getBackgroundColor(RealtimeConnectionState state)',
                'border_color_method': 'Color _getBorderColor(RealtimeConnectionState state)',
                'icon_color_method': 'Color _getIconColor(RealtimeConnectionState state)',
                'text_color_method': 'Color _getTextColor(RealtimeConnectionState state)',
                'icon_method': 'IconData _getIcon(RealtimeConnectionState state)',
                'status_text_method': 'String _getStatusText(RealtimeConnectionState state)',
                'loading_indicator': 'CircularProgressIndicator',
                'retry_button': 'onTap: onRetry',
                'refresh_icon': 'Icons.refresh',
                'wifi_icons': 'Icons.wifi',
                'offline_state': 'return \'Offline\'',
                'connecting_state': 'return \'Connecting...\'',
                'reconnecting_state': 'return \'Reconnecting...\'',
                'live_state': 'return \'Live\'',
                'positioned_floating': 'Positioned'
            }
            
            passed_checks = []
            failed_checks = []
            
            for check_name, pattern in checks.items():
                if pattern in content:
                    passed_checks.append(check_name)
                else:
                    failed_checks.append(check_name)
            
            if failed_checks:
                self.log_result(test_name, 'FAIL', 
                    f'Missing ConnectionIndicator patterns: {", ".join(failed_checks)}',
                    {'passed': passed_checks, 'failed': failed_checks})
            else:
                self.log_result(test_name, 'PASS', 
                    'ConnectionIndicator properly implemented with all connection states',
                    {'validated_patterns': passed_checks})
                
        except Exception as e:
            self.log_result(test_name, 'FAIL', f'Error reading ConnectionIndicator file: {str(e)}')
    
    def test_requests_realtime_manager(self):
        """Test RequestsRealtimeManager structure and priority notifications"""
        test_name = "RequestsRealtimeManager Structure & Priority Notifications"
        
        try:
            with open('/app/lib/features/requests/realtime/requests_realtime.dart', 'r') as f:
                content = f.read()
            
            # Check requests realtime manager patterns
            checks = {
                'provider_definition': 'final requestsRealtimeProvider = Provider<RequestsRealtimeManager>',
                'realtime_manager_class': 'class RequestsRealtimeManager',
                'dependencies': 'final RealtimeClient _realtimeClient',
                'requests_service': 'final RequestsService _requestsService',
                'snackbar_notifier': 'final SnackbarNotifier _snackbarNotifier',
                'auth_service': 'final AuthService _authService',
                'subscription_management': 'StreamSubscription<EventBatch>? _subscription',
                'processed_event_ids': 'final Set<String> _processedEventIds',
                'notification_cooldown': 'final Map<String, DateTime> _lastNotificationTimes',
                'last_known_states': 'final Map<String, ServiceRequest> _lastKnownStates',
                'cooldown_duration': 'static const Duration _notificationCooldown = Duration(seconds: 10)',
                'subscribe_method': 'void subscribe()',
                'unsubscribe_method': 'void unsubscribe()',
                'handle_event_batch': 'void _handleEventBatch(EventBatch batch)',
                'process_event': 'EventProcessingResult _processEvent(RealtimeEvent event)',
                'process_update_event': 'EventProcessingResult _processUpdateEvent',
                'handle_critical_event': 'void _handleCriticalEvent(RealtimeEvent event)',
                'notification_cooldown_method': 'void _showNotificationWithCooldown',
                'table_subscription': '_realtimeClient.subscribeToTable(\n        \'requests\'',
                'insert_update_events': 'events: [\'INSERT\', \'UPDATE\']',
                'duplicate_prevention': 'if (_processedEventIds.contains(eventId))',
                'service_refresh': '_requestsService.refreshRequests()',
                'memory_cleanup': 'if (_processedEventIds.length > 1000)'
            }
            
            # Check priority notification patterns
            priority_checks = {
                'priority_1_onsite': '// Priority 1: Request status → on_site (critical)',
                'onsite_status_check': 'if (newStatus.toLowerCase() == \'on_site\')',
                'priority_2_sla_breach': '// Priority 2: SLA breach + ≤15m warning',
                'sla_breach_notification': 'SLA BREACH: Request #$shortId is overdue!',
                'sla_warning_notification': 'SLA Warning: Request #$shortId due in ${timeUntilBreach.inMinutes}m',
                'priority_4_new_critical': '// Priority 4: New critical request created',
                'critical_request_check': 'if (event.isInsert && request.priority == RequestPriority.critical)',
                'priority_5_assignee_changed': '// Priority 5: Assignee changed',
                'assignee_notification': 'You have been assigned to Request #$shortId',
                'current_user_check': 'if (currentUserName == request.assignedEngineerName)',
                'critical_priority': 'priority: SnackbarPriority.critical',
                'warning_priority': 'priority: SnackbarPriority.warning',
                'info_priority': 'priority: SnackbarPriority.info',
                'action_route': 'actionRoute: \'/requests/$requestId\'',
                'notification_durations': '_getNotificationDuration(priority)'
            }
            
            passed_checks = []
            failed_checks = []
            priority_passed = []
            priority_failed = []
            
            for check_name, pattern in checks.items():
                if pattern in content:
                    passed_checks.append(check_name)
                else:
                    failed_checks.append(check_name)
            
            for check_name, pattern in priority_checks.items():
                if pattern in content:
                    priority_passed.append(check_name)
                else:
                    priority_failed.append(check_name)
            
            if failed_checks or priority_failed:
                self.log_result(test_name, 'FAIL', 
                    f'Missing RequestsRealtimeManager patterns',
                    {
                        'core_passed': passed_checks, 
                        'core_failed': failed_checks,
                        'priority_passed': priority_passed,
                        'priority_failed': priority_failed
                    })
            else:
                self.log_result(test_name, 'PASS', 
                    'RequestsRealtimeManager properly implemented with all priority notifications',
                    {'core_patterns': passed_checks, 'priority_patterns': priority_passed})
                
        except Exception as e:
            self.log_result(test_name, 'FAIL', f'Error reading RequestsRealtimeManager file: {str(e)}')
    
    def test_pm_realtime_manager(self):
        """Test PMRealtimeManager structure and completion notifications"""
        test_name = "PMRealtimeManager Structure & Completion Notifications"
        
        try:
            with open('/app/lib/features/pm/realtime/pm_realtime.dart', 'r') as f:
                content = f.read()
            
            # Check PM realtime manager patterns
            checks = {
                'provider_definition': 'final pmRealtimeProvider = Provider<PMRealtimeManager>',
                'pm_realtime_manager_class': 'class PMRealtimeManager',
                'dependencies': 'final RealtimeClient _realtimeClient',
                'pm_service': 'final PMService _pmService',
                'snackbar_notifier': 'final SnackbarNotifier _snackbarNotifier',
                'auth_service': 'final AuthService _authService',
                'subscription_management': 'StreamSubscription<EventBatch>? _subscription',
                'processed_event_ids': 'final Set<String> _processedEventIds',
                'notification_cooldown': 'final Map<String, DateTime> _lastNotificationTimes',
                'last_known_states': 'final Map<String, PMVisit> _lastKnownStates',
                'cooldown_duration': 'static const Duration _notificationCooldown = Duration(seconds: 10)',
                'table_name': 'static const String _tableName = \'pm_visits\'',
                'subscribe_method': 'void subscribe()',
                'unsubscribe_method': 'void unsubscribe()',
                'handle_event_batch': 'void _handleEventBatch(EventBatch batch)',
                'process_event': 'EventProcessingResult _processEvent(RealtimeEvent event)',
                'process_update_event': 'EventProcessingResult _processUpdateEvent',
                'handle_critical_event': 'void _handleCriticalEvent(RealtimeEvent event)',
                'selective_refresh': 'void _refreshPMServiceSelectively(List<RealtimeEvent> events)',
                'update_state_directly': '_pmService.updateStateDirectly(newState)',
                'table_subscription': '_realtimeClient.subscribeToTable(\n        _tableName',
                'insert_update_events': 'events: [\'INSERT\', \'UPDATE\']',
                'tenant_validation': 'if (tenantId == null)',
                'completion_status_check': 'if (newStatus.toLowerCase() == \'completed\')',
                'completion_date_check': 'if (oldCompletedDate != newCompletedDate && newCompletedDate != null)'
            }
            
            # Check PM notification patterns
            notification_checks = {
                'priority_3_completion': '// Priority 3: PM visit → completed (success)',
                'completion_notification': 'PM Visit completed at $facilityName',
                'overdue_notification': 'PM Visit overdue at $facilityName',
                'success_priority': 'priority: SnackbarPriority.success',
                'warning_priority': 'priority: SnackbarPriority.warning',
                'pm_action_route': 'actionRoute: \'/pm/$pmVisitId\'',
                'facility_name_fallback': 'final facilityName = record[\'facility_name\'] as String? ?? \'Facility\'',
                'completion_status_comparison': 'previousVisit.status != PMVisitStatus.completed && \n          pmVisit.status == PMVisitStatus.completed',
                'overdue_check': 'if (pmVisit.isOverdue && pmVisit.status != PMVisitStatus.completed)'
            }
            
            passed_checks = []
            failed_checks = []
            notification_passed = []
            notification_failed = []
            
            for check_name, pattern in checks.items():
                if pattern in content:
                    passed_checks.append(check_name)
                else:
                    failed_checks.append(check_name)
            
            for check_name, pattern in notification_checks.items():
                if pattern in content:
                    notification_passed.append(check_name)
                else:
                    notification_failed.append(check_name)
            
            if failed_checks or notification_failed:
                self.log_result(test_name, 'FAIL', 
                    f'Missing PMRealtimeManager patterns',
                    {
                        'core_passed': passed_checks, 
                        'core_failed': failed_checks,
                        'notification_passed': notification_passed,
                        'notification_failed': notification_failed
                    })
            else:
                self.log_result(test_name, 'PASS', 
                    'PMRealtimeManager properly implemented with completion notifications',
                    {'core_patterns': passed_checks, 'notification_patterns': notification_passed})
                
        except Exception as e:
            self.log_result(test_name, 'FAIL', f'Error reading PMRealtimeManager file: {str(e)}')
    
    def test_realtime_hooks_integration(self):
        """Test realtime hooks and UI integration"""
        test_name = "Realtime Hooks & UI Integration"
        
        try:
            # Check requests realtime hook
            with open('/app/lib/features/requests/realtime/requests_realtime.dart', 'r') as f:
                requests_content = f.read()
            
            # Check PM realtime hook
            with open('/app/lib/features/pm/realtime/pm_realtime.dart', 'r') as f:
                pm_content = f.read()
            
            # Check hook patterns
            hook_checks = {
                'requests_hook_class': 'class RequestsRealtimeHook extends ConsumerStatefulWidget',
                'requests_hook_state': 'class _RequestsRealtimeHookState extends ConsumerState<RequestsRealtimeHook>',
                'requests_auto_subscribe': 'ref.read(requestsRealtimeProvider).subscribe()',
                'requests_auto_unsubscribe': 'ref.read(requestsRealtimeProvider).unsubscribe()',
                'requests_context_setting': 'ref.read(snackbarNotifierProvider).setContext(context)',
                'requests_post_frame_callback': 'WidgetsBinding.instance.addPostFrameCallback',
                'pm_hook_class': 'class PMRealtimeHook extends ConsumerStatefulWidget',
                'pm_hook_state': 'class _PMRealtimeHookState extends ConsumerState<PMRealtimeHook>',
                'pm_auto_subscribe': 'ref.read(pmRealtimeProvider).subscribe()',
                'pm_auto_unsubscribe': 'ref.read(pmRealtimeProvider).unsubscribe()',
                'pm_context_setting': 'ref.read(snackbarNotifierProvider).setContext(context)',
                'pm_post_frame_callback': 'WidgetsBinding.instance.addPostFrameCallback'
            }
            
            passed_checks = []
            failed_checks = []
            
            for check_name, pattern in hook_checks.items():
                if 'requests' in check_name:
                    content = requests_content
                else:
                    content = pm_content
                    
                if pattern in content:
                    passed_checks.append(check_name)
                else:
                    failed_checks.append(check_name)
            
            if failed_checks:
                self.log_result(test_name, 'FAIL', 
                    f'Missing realtime hook patterns: {", ".join(failed_checks)}',
                    {'passed': passed_checks, 'failed': failed_checks})
            else:
                self.log_result(test_name, 'PASS', 
                    'Realtime hooks properly implemented with auto-subscribe/unsubscribe',
                    {'validated_patterns': passed_checks})
                
        except Exception as e:
            self.log_result(test_name, 'FAIL', f'Error reading realtime hook files: {str(e)}')
    
    def test_event_processing_logic(self):
        """Test event processing and filtering logic"""
        test_name = "Event Processing & Filtering Logic"
        
        try:
            with open('/app/lib/core/realtime/realtime_client.dart', 'r') as f:
                realtime_content = f.read()
            
            with open('/app/lib/features/requests/realtime/requests_realtime.dart', 'r') as f:
                requests_content = f.read()
            
            # Check event processing patterns
            processing_checks = {
                'event_type_filtering': "if (!['INSERT', 'UPDATE'].contains(eventType))",
                'tenant_validation': 'if (recordTenantId != currentTenantId)',
                'duplicate_prevention': 'if (_processedEventIds.contains(eventId))',
                'event_id_generation': 'String _generateEventId(RealtimeEvent event)',
                'memory_cleanup': 'if (_processedEventIds.length > 1000)',
                'debounce_buffer': 'void _addEventToBuffer(String table, RealtimeEvent event)',
                'flush_events': 'void _flushEvents(String channelKey, String table)',
                'batch_processing': 'void _handleEventBatch(EventBatch batch)',
                'event_coalescing': 'now.difference(lastNotification) < _notificationCooldown',
                'selective_refresh': 'bool shouldRefreshService = false',
                'critical_event_detection': 'final criticalEvents = <RealtimeEvent>[]',
                'status_change_detection': 'if (oldStatus != newStatus && newStatus != null)',
                'assignee_change_detection': 'if (oldAssignee != newAssignee)',
                'sla_breach_detection': 'final isOverdue = DateTime.now().isAfter(slaDueAt)',
                'completion_detection': 'if (newStatus.toLowerCase() == \'completed\')',
                'insert_detection': 'if (event.isInsert)',
                'update_detection': 'if (event.isUpdate && oldRecord != null)'
            }
            
            passed_checks = []
            failed_checks = []
            
            for check_name, pattern in processing_checks.items():
                found_in_realtime = pattern in realtime_content
                found_in_requests = pattern in requests_content
                
                if found_in_realtime or found_in_requests:
                    passed_checks.append(check_name)
                else:
                    failed_checks.append(check_name)
            
            if failed_checks:
                self.log_result(test_name, 'FAIL', 
                    f'Missing event processing patterns: {", ".join(failed_checks)}',
                    {'passed': passed_checks, 'failed': failed_checks})
            else:
                self.log_result(test_name, 'PASS', 
                    'Event processing and filtering logic properly implemented',
                    {'validated_patterns': passed_checks})
                
        except Exception as e:
            self.log_result(test_name, 'FAIL', f'Error reading event processing files: {str(e)}')
    
    def test_debouncing_and_batching(self):
        """Test debouncing and batching implementation"""
        test_name = "Debouncing & Batching Implementation"
        
        try:
            with open('/app/lib/core/realtime/realtime_client.dart', 'r') as f:
                content = f.read()
            
            # Check debouncing patterns
            debounce_checks = {
                'debounce_delay': 'static const Duration _debounceDelay = Duration(milliseconds: 300)',
                'debounce_timers': 'final Map<String, Timer?> _debounceTimers',
                'pending_events': 'final Map<String, List<RealtimeEvent>> _pendingEvents',
                'timer_cancellation': '_debounceTimers[channelKey]?.cancel()',
                'timer_creation': '_debounceTimers[channelKey] = Timer(_debounceDelay',
                'event_buffering': '_pendingEvents[channelKey] ??= []',
                'buffer_addition': '_pendingEvents[channelKey]!.add(event)',
                'batch_creation': 'final batch = EventBatch',
                'batch_emission': 'controller.add(batch)',
                'buffer_clearing': '_pendingEvents[channelKey]?.clear()',
                'flush_trigger': '_flushEvents(channelKey, table)',
                'batch_timestamp': 'timestamp: DateTime.now()',
                'event_copy': 'events: List.from(events)',
                'controller_check': 'if (controller != null && !controller.isClosed)'
            }
            
            passed_checks = []
            failed_checks = []
            
            for check_name, pattern in debounce_checks.items():
                if pattern in content:
                    passed_checks.append(check_name)
                else:
                    failed_checks.append(check_name)
            
            if failed_checks:
                self.log_result(test_name, 'FAIL', 
                    f'Missing debouncing patterns: {", ".join(failed_checks)}',
                    {'passed': passed_checks, 'failed': failed_checks})
            else:
                self.log_result(test_name, 'PASS', 
                    'Debouncing and batching properly implemented with 300ms delay',
                    {'validated_patterns': passed_checks})
                
        except Exception as e:
            self.log_result(test_name, 'FAIL', f'Error reading debouncing implementation: {str(e)}')
    
    def test_notification_priorities_and_durations(self):
        """Test notification priorities and durations match specification"""
        test_name = "Notification Priorities & Durations"
        
        try:
            with open('/app/lib/features/requests/realtime/requests_realtime.dart', 'r') as f:
                requests_content = f.read()
            
            with open('/app/lib/features/pm/realtime/pm_realtime.dart', 'r') as f:
                pm_content = f.read()
            
            # Check priority specifications
            priority_checks = {
                'critical_6s_duration': 'return const Duration(seconds: 6); // Red emphasis',
                'warning_6s_duration': 'return const Duration(seconds: 6); // Amber, auto-dismiss 6s',
                'success_4s_duration': 'return const Duration(seconds: 4); // Green, auto-dismiss 4s',
                'info_3s_duration': 'return const Duration(seconds: 3); // Default',
                'onsite_critical': 'priority: SnackbarPriority.critical,\n          message: \'Engineer on-site for Request',
                'sla_breach_critical': 'priority: SnackbarPriority.critical,\n          message: \'SLA BREACH: Request',
                'sla_warning_warning': 'priority: SnackbarPriority.warning,\n          message: \'SLA Warning: Request',
                'new_critical_critical': 'priority: SnackbarPriority.critical,\n          message: \'New Critical Request',
                'assignee_info': 'priority: SnackbarPriority.info,\n          message: \'You have been assigned',
                'pm_completion_success': 'priority: SnackbarPriority.success,\n          message: \'PM Visit completed',
                'pm_overdue_warning': 'priority: SnackbarPriority.warning,\n          message: \'PM Visit overdue',
                'notification_cooldown_10s': 'now.difference(lastNotification) < _notificationCooldown',
                'cooldown_duration': 'static const Duration _notificationCooldown = Duration(seconds: 10)'
            }
            
            passed_checks = []
            failed_checks = []
            
            for check_name, pattern in priority_checks.items():
                found_in_requests = pattern in requests_content
                found_in_pm = pattern in pm_content
                
                if found_in_requests or found_in_pm:
                    passed_checks.append(check_name)
                else:
                    failed_checks.append(check_name)
            
            if failed_checks:
                self.log_result(test_name, 'FAIL', 
                    f'Missing notification priority patterns: {", ".join(failed_checks)}',
                    {'passed': passed_checks, 'failed': failed_checks})
            else:
                self.log_result(test_name, 'PASS', 
                    'Notification priorities and durations match specification',
                    {'validated_patterns': passed_checks})
                
        except Exception as e:
            self.log_result(test_name, 'FAIL', f'Error reading notification priority files: {str(e)}')
    
    def test_tenant_isolation_and_security(self):
        """Test tenant isolation and security validation"""
        test_name = "Tenant Isolation & Security Validation"
        
        try:
            with open('/app/lib/core/realtime/realtime_client.dart', 'r') as f:
                realtime_content = f.read()
            
            with open('/app/lib/features/requests/realtime/requests_realtime.dart', 'r') as f:
                requests_content = f.read()
            
            with open('/app/lib/features/pm/realtime/pm_realtime.dart', 'r') as f:
                pm_content = f.read()
            
            # Check tenant isolation patterns
            isolation_checks = {
                'tenant_id_access': 'String? get _tenantId => _authService.tenantId',
                'tenant_scoped_channels': 'final channelKey = \'${table}_$tenantId\'',
                'tenant_filters': 'final tenantFilters = {\n        \'tenant_id\': \'eq.$tenantId\'',
                'cross_tenant_validation': 'if (recordTenantId != currentTenantId)',
                'cross_tenant_ignore': 'debugPrint(\'⚠️ Ignoring cross-tenant event',
                'tenant_context_check': 'if (tenantId == null)',
                'no_tenant_exception': 'throw Exception(\'No tenant context available',
                'tenant_subscription_refresh': 'refreshing realtime subscriptions for tenant',
                'tenant_unsubscribe': 'No tenant, unsubscribing from all channels',
                'auth_change_listener': '_authService.addListener(_onAuthChanged)',
                'tenant_validation_requests': 'if (tenantId == null) {\n      debugPrint(\'⚠️ [PMRT] No tenant context',
                'tenant_logging': 'for tenant: $tenantId',
                'security_filter': 'filter: tenantFilters.entries'
            }
            
            passed_checks = []
            failed_checks = []
            
            for check_name, pattern in isolation_checks.items():
                found_in_realtime = pattern in realtime_content
                found_in_requests = pattern in requests_content
                found_in_pm = pattern in pm_content
                
                if found_in_realtime or found_in_requests or found_in_pm:
                    passed_checks.append(check_name)
                else:
                    failed_checks.append(check_name)
            
            if failed_checks:
                self.log_result(test_name, 'FAIL', 
                    f'Missing tenant isolation patterns: {", ".join(failed_checks)}',
                    {'passed': passed_checks, 'failed': failed_checks})
            else:
                self.log_result(test_name, 'PASS', 
                    'Tenant isolation and security validation properly implemented',
                    {'validated_patterns': passed_checks})
                
        except Exception as e:
            self.log_result(test_name, 'FAIL', f'Error reading tenant isolation files: {str(e)}')
    
    def test_error_handling_and_reconnection(self):
        """Test error handling and reconnection logic"""
        test_name = "Error Handling & Reconnection Logic"
        
        try:
            with open('/app/lib/core/realtime/realtime_client.dart', 'r') as f:
                content = f.read()
            
            # Check error handling patterns
            error_checks = {
                'channel_error_handling': 'channel.onError((error) =>',
                'channel_close_handling': 'channel.onClose(() =>',
                'subscription_error_handling': 'onError: (error) =>',
                'try_catch_blocks': 'try {\n      debugPrint',
                'error_logging': 'debugPrint(\'❌',
                'reconnection_scheduling': 'void _scheduleReconnect()',
                'max_reconnect_attempts': 'static const int _maxReconnectAttempts = 5',
                'reconnect_attempts_counter': 'int _reconnectAttempts = 0',
                'exponential_backoff': 'final delay = _reconnectDelay * _reconnectAttempts',
                'reconnect_timer': 'Timer? _reconnectTimer',
                'reconnect_delay': 'static const Duration _reconnectDelay = Duration(seconds: 2)',
                'connection_state_updates': '_updateConnectionState(RealtimeConnectionState.disconnected)',
                'reconnecting_state': '_updateConnectionState(RealtimeConnectionState.reconnecting)',
                'manual_reconnect': 'void reconnect()',
                'reconnect_reset': '_reconnectAttempts = 0',
                'timer_cancellation': '_reconnectTimer?.cancel()',
                'max_attempts_check': 'if (_reconnectAttempts >= _maxReconnectAttempts)',
                'giving_up_log': 'debugPrint(\'🔴 Max reconnect attempts reached, giving up\')',
                'already_scheduled_check': 'if (_reconnectTimer?.isActive == true)',
                'connection_state_notification': 'notifyListeners()'
            }
            
            passed_checks = []
            failed_checks = []
            
            for check_name, pattern in error_checks.items():
                if pattern in content:
                    passed_checks.append(check_name)
                else:
                    failed_checks.append(check_name)
            
            if failed_checks:
                self.log_result(test_name, 'FAIL', 
                    f'Missing error handling patterns: {", ".join(failed_checks)}',
                    {'passed': passed_checks, 'failed': failed_checks})
            else:
                self.log_result(test_name, 'PASS', 
                    'Error handling and reconnection logic properly implemented',
                    {'validated_patterns': passed_checks})
                
        except Exception as e:
            self.log_result(test_name, 'FAIL', f'Error reading error handling implementation: {str(e)}')
    
    def test_service_state_updates(self):
        """Test service state update methods"""
        test_name = "Service State Update Methods"
        
        try:
            # Check if services have updateStateDirectly methods
            files_to_check = [
                '/app/lib/features/requests/domain/requests_service.dart',
                '/app/lib/features/pm/domain/pm_service.dart'
            ]
            
            update_patterns = {
                'update_state_directly': 'updateStateDirectly',
                'state_management': '_state =',
                'notify_listeners': 'notifyListeners()',
                'state_copy_with': '.copyWith(',
                'selective_updates': 'selective'
            }
            
            file_results = {}
            
            for file_path in files_to_check:
                try:
                    with open(file_path, 'r') as f:
                        content = f.read()
                    
                    file_name = file_path.split('/')[-1]
                    file_results[file_name] = {
                        'passed': [],
                        'failed': [],
                        'exists': True
                    }
                    
                    for pattern_name, pattern in update_patterns.items():
                        if pattern in content:
                            file_results[file_name]['passed'].append(pattern_name)
                        else:
                            file_results[file_name]['failed'].append(pattern_name)
                            
                except FileNotFoundError:
                    file_name = file_path.split('/')[-1]
                    file_results[file_name] = {
                        'passed': [],
                        'failed': list(update_patterns.keys()),
                        'exists': False
                    }
            
            # Evaluate results
            total_failed = sum(len(result['failed']) for result in file_results.values())
            missing_files = [name for name, result in file_results.items() if not result['exists']]
            
            if total_failed > 0 or missing_files:
                self.log_result(test_name, 'WARNING', 
                    f'Some service state update patterns missing or files not found: {missing_files}',
                    file_results)
            else:
                self.log_result(test_name, 'PASS', 
                    'Service state update methods properly implemented',
                    file_results)
                
        except Exception as e:
            self.log_result(test_name, 'FAIL', f'Error checking service state updates: {str(e)}')
    
    def run_all_tests(self):
        """Run all realtime tests"""
        print("🧪 Starting Flutter Realtime Implementation Tests")
        print("=" * 60)
        
        # Run all test methods
        test_methods = [
            self.test_realtime_client_structure,
            self.test_snackbar_notifier_structure,
            self.test_connection_indicator_structure,
            self.test_requests_realtime_manager,
            self.test_pm_realtime_manager,
            self.test_realtime_hooks_integration,
            self.test_event_processing_logic,
            self.test_debouncing_and_batching,
            self.test_notification_priorities_and_durations,
            self.test_tenant_isolation_and_security,
            self.test_error_handling_and_reconnection,
            self.test_service_state_updates
        ]
        
        for test_method in test_methods:
            try:
                test_method()
            except Exception as e:
                self.log_result(test_method.__name__, 'FAIL', 
                    f'Test execution failed: {str(e)}')
                traceback.print_exc()
        
        # Print summary
        self.print_summary()
    
    def print_summary(self):
        """Print test summary"""
        print("\n" + "=" * 60)
        print("🧪 FLUTTER REALTIME TEST SUMMARY")
        print("=" * 60)
        
        passed = len([r for r in self.test_results if r['status'] == 'PASS'])
        failed = len([r for r in self.test_results if r['status'] == 'FAIL'])
        warnings = len([r for r in self.test_results if r['status'] == 'WARNING'])
        skipped = len([r for r in self.test_results if r['status'] == 'SKIP'])
        
        print(f"✅ PASSED: {passed}")
        print(f"❌ FAILED: {failed}")
        print(f"⚠️  WARNINGS: {warnings}")
        print(f"⏭️  SKIPPED: {skipped}")
        print(f"📊 TOTAL: {len(self.test_results)}")
        
        if failed > 0:
            print("\n❌ FAILED TESTS:")
            for result in self.test_results:
                if result['status'] == 'FAIL':
                    print(f"  • {result['test']}: {result['message']}")
        
        if warnings > 0:
            print("\n⚠️  WARNINGS:")
            for result in self.test_results:
                if result['status'] == 'WARNING':
                    print(f"  • {result['test']}: {result['message']}")
        
        print("\n" + "=" * 60)
        
        # Return overall status
        return failed == 0

def main():
    """Main test execution"""
    tester = FlutterRealtimeBackendTester()
    success = tester.run_all_tests()
    
    # Exit with appropriate code
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()