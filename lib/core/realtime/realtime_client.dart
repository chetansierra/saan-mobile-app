import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/client.dart';
import '../../features/auth/domain/auth_service.dart';

/// Provider for RealtimeClient
final realtimeClientProvider = Provider<RealtimeClient>((ref) {
  final authService = ref.watch(authServiceProvider);
  return RealtimeClient._(authService);
});

/// Realtime connection state
enum RealtimeConnectionState {
  connecting,
  connected,
  disconnected,
  reconnecting,
}

/// Realtime event data
class RealtimeEvent {
  const RealtimeEvent({
    required this.table,
    required this.eventType,
    required this.record,
    required this.oldRecord,
  });

  final String table;
  final String eventType; // INSERT, UPDATE, DELETE
  final Map<String, dynamic>? record; // new record
  final Map<String, dynamic>? oldRecord; // old record (for UPDATE)

  bool get isInsert => eventType == 'INSERT';
  bool get isUpdate => eventType == 'UPDATE';
  bool get isDelete => eventType == 'DELETE';
}

/// Debounced event batch
class EventBatch {
  const EventBatch({
    required this.table,
    required this.events,
    required this.timestamp,
  });

  final String table;
  final List<RealtimeEvent> events;
  final DateTime timestamp;
}

/// Core realtime client for Supabase channels with tenant filtering and debouncing
class RealtimeClient extends ChangeNotifier {
  RealtimeClient._(this._authService) {
    _connectionState = RealtimeConnectionState.disconnected;
    _init();
  }

  final AuthService _authService;
  final SupabaseClient _client = SupabaseService.client;
  
  final Map<String, RealtimeChannel> _channels = {};
  final Map<String, StreamController<EventBatch>> _eventControllers = {};
  final Map<String, Timer?> _debounceTimers = {};
  final Map<String, List<RealtimeEvent>> _pendingEvents = {};
  
  RealtimeConnectionState _connectionState = RealtimeConnectionState.disconnected;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _debounceDelay = Duration(milliseconds: 300);
  static const Duration _reconnectDelay = Duration(seconds: 2);

  /// Current connection state
  RealtimeConnectionState get connectionState => _connectionState;

  /// Current tenant ID
  String? get _tenantId => _authService.tenantId;

  /// Initialize realtime connection
  void _init() {
    debugPrint('🔴 Initializing RealtimeClient');
    _updateConnectionState(RealtimeConnectionState.connecting);
    
    // Listen to auth changes to handle tenant switching
    _authService.addListener(_onAuthChanged);
  }

  /// Handle auth state changes
  void _onAuthChanged() {
    final tenantId = _tenantId;
    if (tenantId != null) {
      debugPrint('🔴 Auth changed, refreshing realtime subscriptions for tenant: $tenantId');
      _refreshSubscriptions();
    } else {
      debugPrint('🔴 No tenant, unsubscribing from all channels');
      _unsubscribeAll();
    }
  }

  /// Subscribe to a table with tenant filtering
  Stream<EventBatch> subscribeToTable(String table, {
    List<String>? events,
    Map<String, String>? filters,
  }) {
    final tenantId = _tenantId;
    if (tenantId == null) {
      throw Exception('No tenant context available for realtime subscription');
    }

    final channelKey = '${table}_$tenantId';
    debugPrint('🔴 Subscribing to table: $table for tenant: $tenantId');

    // Create event stream if not exists
    if (!_eventControllers.containsKey(channelKey)) {
      _eventControllers[channelKey] = StreamController<EventBatch>.broadcast();
    }

    // Create channel if not exists
    if (!_channels.containsKey(channelKey)) {
      _createChannel(table, tenantId, events: events, filters: filters);
    }

    return _eventControllers[channelKey]!.stream;
  }

  /// Create and configure a realtime channel
  void _createChannel(String table, String tenantId, {
    List<String>? events,
    Map<String, String>? filters,
  }) {
    final channelKey = '${table}_$tenantId';
    
    try {
      // Create channel with tenant-specific name
      final channel = _client.channel(channelKey);
      
      // Add tenant filter to all operations
      final tenantFilters = {
        'tenant_id': 'eq.$tenantId',
        ...?filters,
      };

      // Subscribe to postgres changes
      final subscription = channel.on(
        RealtimeListenTypes.postgresChanges,
        ChannelFilter(
          event: '*', // Listen to all events, filter client-side
          schema: 'public',
          table: table,
          filter: tenantFilters.entries
              .map((e) => '${e.key}=${e.value}')
              .join(','),
        ),
        (payload, [ref]) => _handleChannelEvent(table, payload),
      );

      // Handle channel state changes
      channel.onError((error) {
        debugPrint('🔴 Channel error for $table: $error');
        _updateConnectionState(RealtimeConnectionState.disconnected);
        _scheduleReconnect();
      });

      channel.onClose(() {
        debugPrint('🔴 Channel closed for $table');
        _updateConnectionState(RealtimeConnectionState.disconnected);
      });

      // Subscribe to channel
      channel.subscribe((status, [error]) {
        debugPrint('🔴 Channel subscription status for $table: $status');
        if (status == 'SUBSCRIBED') {
          _updateConnectionState(RealtimeConnectionState.connected);
          _reconnectAttempts = 0; // Reset reconnect attempts on successful connection
        } else if (status == 'CHANNEL_ERROR' || status == 'TIMED_OUT') {
          _updateConnectionState(RealtimeConnectionState.disconnected);
          _scheduleReconnect();
        }
      });

      _channels[channelKey] = channel;
      debugPrint('✅ Channel created for $table with tenant filter: $tenantId');
      
    } catch (e) {
      debugPrint('❌ Failed to create channel for $table: $e');
      _updateConnectionState(RealtimeConnectionState.disconnected);
      _scheduleReconnect();
    }
  }

  /// Handle incoming channel events
  void _handleChannelEvent(String table, Map<String, dynamic> payload) {
    try {
      final eventType = payload['eventType'] as String?;
      final record = payload['new'] as Map<String, dynamic>?;
      final oldRecord = payload['old'] as Map<String, dynamic>?;

      if (eventType == null) {
        debugPrint('⚠️ Received event without eventType for table: $table');
        return;
      }

      // Filter events - only process INSERT and UPDATE
      if (!['INSERT', 'UPDATE'].contains(eventType)) {
        debugPrint('🔴 Ignoring $eventType event for table: $table');
        return;
      }

      // Additional tenant validation for security
      final recordTenantId = record?['tenant_id'] as String?;
      final currentTenantId = _tenantId;
      
      if (recordTenantId != currentTenantId) {
        debugPrint('⚠️ Ignoring cross-tenant event: record tenant $recordTenantId vs current $currentTenantId');
        return;
      }

      final event = RealtimeEvent(
        table: table,
        eventType: eventType,
        record: record,
        oldRecord: oldRecord,
      );

      debugPrint('🔴 Processing $eventType event for $table: ${record?['id']}');
      _addEventToBuffer(table, event);
      
    } catch (e) {
      debugPrint('❌ Error handling channel event: $e');
    }
  }

  /// Add event to debounce buffer
  void _addEventToBuffer(String table, RealtimeEvent event) {
    final tenantId = _tenantId;
    if (tenantId == null) return;

    final channelKey = '${table}_$tenantId';
    
    // Initialize pending events list if needed
    _pendingEvents[channelKey] ??= [];
    _pendingEvents[channelKey]!.add(event);

    // Cancel existing timer
    _debounceTimers[channelKey]?.cancel();

    // Start new debounce timer
    _debounceTimers[channelKey] = Timer(_debounceDelay, () {
      _flushEvents(channelKey, table);
    });
  }

  /// Flush buffered events as a batch
  void _flushEvents(String channelKey, String table) {
    final events = _pendingEvents[channelKey];
    if (events == null || events.isEmpty) return;

    final batch = EventBatch(
      table: table,
      events: List.from(events), // Create copy
      timestamp: DateTime.now(),
    );

    // Clear pending events
    _pendingEvents[channelKey]?.clear();

    // Emit batch to subscribers
    final controller = _eventControllers[channelKey];
    if (controller != null && !controller.isClosed) {
      controller.add(batch);
      debugPrint('✅ Flushed ${events.length} events for $table');
    }
  }

  /// Unsubscribe from a table
  void unsubscribeFromTable(String table) {
    final tenantId = _tenantId;
    if (tenantId == null) return;

    final channelKey = '${table}_$tenantId';
    debugPrint('🔴 Unsubscribing from table: $table');

    _cleanupChannel(channelKey);
  }

  /// Cleanup a specific channel
  void _cleanupChannel(String channelKey) {
    // Cancel debounce timer
    _debounceTimers[channelKey]?.cancel();
    _debounceTimers.remove(channelKey);

    // Clear pending events
    _pendingEvents.remove(channelKey);

    // Unsubscribe and remove channel
    final channel = _channels[channelKey];
    if (channel != null) {
      channel.unsubscribe();
      _channels.remove(channelKey);
    }

    // Close event controller
    final controller = _eventControllers[channelKey];
    if (controller != null && !controller.isClosed) {
      controller.close();
      _eventControllers.remove(channelKey);
    }

    debugPrint('✅ Cleaned up channel: $channelKey');
  }

  /// Unsubscribe from all tables
  void _unsubscribeAll() {
    debugPrint('🔴 Unsubscribing from all channels');
    
    final channelKeys = List<String>.from(_channels.keys);
    for (final key in channelKeys) {
      _cleanupChannel(key);
    }
    
    _updateConnectionState(RealtimeConnectionState.disconnected);
  }

  /// Refresh all subscriptions (e.g., after tenant change)
  void _refreshSubscriptions() {
    _unsubscribeAll();
    // Note: Subscribers will need to re-subscribe after auth changes
    _updateConnectionState(RealtimeConnectionState.connecting);
  }

  /// Update connection state and notify listeners
  void _updateConnectionState(RealtimeConnectionState newState) {
    if (_connectionState != newState) {
      _connectionState = newState;
      debugPrint('🔴 Connection state changed: $newState');
      notifyListeners();
    }
  }

  /// Schedule reconnection attempt
  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('🔴 Max reconnect attempts reached, giving up');
      return;
    }

    if (_reconnectTimer?.isActive == true) {
      return; // Already scheduled
    }

    _reconnectAttempts++;
    _updateConnectionState(RealtimeConnectionState.reconnecting);
    
    final delay = _reconnectDelay * _reconnectAttempts;
    debugPrint('🔴 Scheduling reconnect attempt $_reconnectAttempts in ${delay.inSeconds}s');

    _reconnectTimer = Timer(delay, () {
      debugPrint('🔴 Attempting reconnect...');
      _refreshSubscriptions();
    });
  }

  /// Manually trigger reconnection
  void reconnect() {
    debugPrint('🔴 Manual reconnection triggered');
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
    _refreshSubscriptions();
  }

  /// Check if currently connected
  bool get isConnected => _connectionState == RealtimeConnectionState.connected;

  /// Check if currently connecting
  bool get isConnecting => _connectionState == RealtimeConnectionState.connecting;

  /// Check if disconnected
  bool get isDisconnected => _connectionState == RealtimeConnectionState.disconnected;

  @override
  void dispose() {
    debugPrint('🔴 Disposing RealtimeClient');
    
    _authService.removeListener(_onAuthChanged);
    _reconnectTimer?.cancel();
    _unsubscribeAll();
    
    // Cancel all debounce timers
    for (final timer in _debounceTimers.values) {
      timer?.cancel();
    }
    _debounceTimers.clear();
    
    super.dispose();
  }
}