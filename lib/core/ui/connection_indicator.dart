import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../realtime/realtime_client.dart';

/// Connection status indicator widget
class ConnectionIndicator extends ConsumerWidget {
  const ConnectionIndicator({
    super.key,
    this.onRetry,
    this.showLabel = false,
  });

  final VoidCallback? onRetry;
  final bool showLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final realtimeClient = ref.watch(realtimeClientProvider);
    final connectionState = realtimeClient.connectionState;

    // Don't show indicator when connected (unless label is requested)
    if (connectionState == RealtimeConnectionState.connected && !showLabel) {
      return const SizedBox.shrink();
    }

    return AnimatedOpacity(
      opacity: _getOpacity(connectionState),
      duration: const Duration(milliseconds: 300),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _getBackgroundColor(connectionState),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _getBorderColor(connectionState),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status icon
            SizedBox(
              width: 12,
              height: 12,
              child: connectionState == RealtimeConnectionState.connecting ||
                      connectionState == RealtimeConnectionState.reconnecting
                  ? CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getIconColor(connectionState),
                      ),
                    )
                  : Icon(
                      _getIcon(connectionState),
                      size: 12,
                      color: _getIconColor(connectionState),
                    ),
            ),
            
            // Label (if requested or when disconnected)
            if (showLabel || connectionState != RealtimeConnectionState.connected) ...[
              const SizedBox(width: 6),
              Text(
                _getStatusText(connectionState),
                style: TextStyle(
                  color: _getTextColor(connectionState),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            
            // Retry button (when disconnected and callback provided)
            if (connectionState == RealtimeConnectionState.disconnected &&
                onRetry != null) ...[
              const SizedBox(width: 4),
              InkWell(
                onTap: onRetry,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    Icons.refresh,
                    size: 12,
                    color: _getIconColor(connectionState),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  double _getOpacity(RealtimeConnectionState state) {
    switch (state) {
      case RealtimeConnectionState.connected:
        return showLabel ? 1.0 : 0.0;
      case RealtimeConnectionState.connecting:
      case RealtimeConnectionState.reconnecting:
        return 0.8;
      case RealtimeConnectionState.disconnected:
        return 1.0;
    }
  }

  Color _getBackgroundColor(RealtimeConnectionState state) {
    switch (state) {
      case RealtimeConnectionState.connected:
        return Colors.green.withOpacity(0.1);
      case RealtimeConnectionState.connecting:
      case RealtimeConnectionState.reconnecting:
        return Colors.orange.withOpacity(0.1);
      case RealtimeConnectionState.disconnected:
        return Colors.red.withOpacity(0.1);
    }
  }

  Color _getBorderColor(RealtimeConnectionState state) {
    switch (state) {
      case RealtimeConnectionState.connected:
        return Colors.green.withOpacity(0.3);
      case RealtimeConnectionState.connecting:
      case RealtimeConnectionState.reconnecting:
        return Colors.orange.withOpacity(0.3);
      case RealtimeConnectionState.disconnected:
        return Colors.red.withOpacity(0.3);
    }
  }

  Color _getIconColor(RealtimeConnectionState state) {
    switch (state) {
      case RealtimeConnectionState.connected:
        return Colors.green;
      case RealtimeConnectionState.connecting:
      case RealtimeConnectionState.reconnecting:
        return Colors.orange;
      case RealtimeConnectionState.disconnected:
        return Colors.red;
    }
  }

  Color _getTextColor(RealtimeConnectionState state) {
    return _getIconColor(state);
  }

  IconData _getIcon(RealtimeConnectionState state) {
    switch (state) {
      case RealtimeConnectionState.connected:
        return Icons.wifi;
      case RealtimeConnectionState.connecting:
      case RealtimeConnectionState.reconnecting:
        return Icons.wifi_off;
      case RealtimeConnectionState.disconnected:
        return Icons.wifi_off;
    }
  }

  String _getStatusText(RealtimeConnectionState state) {
    switch (state) {
      case RealtimeConnectionState.connected:
        return 'Live';
      case RealtimeConnectionState.connecting:
        return 'Connecting...';
      case RealtimeConnectionState.reconnecting:
        return 'Reconnecting...';
      case RealtimeConnectionState.disconnected:
        return 'Offline';
    }
  }
}

/// Floating connection indicator for pages
class FloatingConnectionIndicator extends ConsumerWidget {
  const FloatingConnectionIndicator({
    super.key,
    this.onRetry,
    this.bottom = 16,
    this.right = 16,
  });

  final VoidCallback? onRetry;
  final double bottom;
  final double right;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final realtimeClient = ref.watch(realtimeClientProvider);
    final connectionState = realtimeClient.connectionState;

    // Only show when not connected
    if (connectionState == RealtimeConnectionState.connected) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: bottom,
      right: right,
      child: ConnectionIndicator(
        onRetry: onRetry ?? () => realtimeClient.reconnect(),
        showLabel: true,
      ),
    );
  }
}