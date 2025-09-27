import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../supabase/client.dart';

/// Provider for Analytics
final analyticsProvider = Provider<Analytics>((ref) {
  if (kDebugMode) {
    return DebugAnalytics();
  } else {
    return NoOpAnalytics();
  }
});

/// Privacy-first analytics interface
abstract class Analytics {
  /// Track a screen view
  void trackScreenView(String screenName, {Map<String, dynamic>? parameters});

  /// Track a user action/event
  void trackEvent(String eventName, {Map<String, dynamic>? parameters});

  /// Set user properties (non-PII only)
  void setUserProperties(Map<String, dynamic> properties);

  /// Enable/disable analytics
  void setAnalyticsEnabled(bool enabled);

  /// Clear all user data
  void clearUserData();
}

/// Debug implementation that logs to console
class DebugAnalytics implements Analytics {
  bool _enabled = true;

  @override
  void trackScreenView(String screenName, {Map<String, dynamic>? parameters}) {
    if (!_enabled) return;
    
    debugPrint('📊 [Analytics] Screen: $screenName');
    if (parameters != null && parameters.isNotEmpty) {
      debugPrint('📊 [Analytics] Parameters: $parameters');
    }
  }

  @override
  void trackEvent(String eventName, {Map<String, dynamic>? parameters}) {
    if (!_enabled) return;
    
    debugPrint('📊 [Analytics] Event: $eventName');
    if (parameters != null && parameters.isNotEmpty) {
      debugPrint('📊 [Analytics] Parameters: $parameters');
    }
  }

  @override
  void setUserProperties(Map<String, dynamic> properties) {
    if (!_enabled) return;
    
    debugPrint('📊 [Analytics] User Properties: $properties');
  }

  @override
  void setAnalyticsEnabled(bool enabled) {
    _enabled = enabled;
    debugPrint('📊 [Analytics] Enabled: $enabled');
  }

  @override
  void clearUserData() {
    debugPrint('📊 [Analytics] User data cleared');
  }
}

/// No-op implementation for production (can be replaced with real analytics)
class NoOpAnalytics implements Analytics {
  @override
  void trackScreenView(String screenName, {Map<String, dynamic>? parameters}) {
    // No-op in production until real analytics is configured
  }

  @override
  void trackEvent(String eventName, {Map<String, dynamic>? parameters}) {
    // No-op in production until real analytics is configured
  }

  @override
  void setUserProperties(Map<String, dynamic> properties) {
    // No-op in production until real analytics is configured
  }

  @override
  void setAnalyticsEnabled(bool enabled) {
    // No-op in production until real analytics is configured
  }

  @override
  void clearUserData() {
    // No-op in production until real analytics is configured
  }
}

/// Supabase-based analytics implementation (optional)
class SupabaseAnalytics implements Analytics {
  bool _enabled = true;
  final SupabaseClient _client = SupabaseService.client;

  @override
  void trackScreenView(String screenName, {Map<String, dynamic>? parameters}) {
    if (!_enabled) return;
    
    _trackEvent('screen_view', {
      'screen_name': screenName,
      ...?parameters,
    });
  }

  @override
  void trackEvent(String eventName, {Map<String, dynamic>? parameters}) {
    if (!_enabled) return;
    
    _trackEvent(eventName, parameters);
  }

  @override
  void setUserProperties(Map<String, dynamic> properties) {
    if (!_enabled) return;
    
    // Store user properties in a privacy-safe way
    _trackEvent('user_properties', {
      'properties': _sanitizeProperties(properties),
    });
  }

  @override
  void setAnalyticsEnabled(bool enabled) {
    _enabled = enabled;
    
    if (enabled) {
      _trackEvent('analytics_enabled', {});
    }
  }

  @override
  void clearUserData() {
    _trackEvent('user_data_cleared', {});
  }

  /// Internal method to track events to Supabase
  void _trackEvent(String eventName, Map<String, dynamic>? parameters) {
    try {
      // In a real implementation, you might store events in a Supabase table
      // For now, we'll just log structured events
      final eventData = {
        'event_name': eventName,
        'timestamp': DateTime.now().toIso8601String(),
        'platform': defaultTargetPlatform.name,
        'debug_mode': kDebugMode,
        'parameters': _sanitizeParameters(parameters ?? {}),
      };

      // Store in analytics table (would need to be created)
      // _client.from('analytics_events').insert(eventData);
      
      if (kDebugMode) {
        debugPrint('📊 [Supabase Analytics] $eventData');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to track analytics event: $e');
      }
    }
  }

  /// Sanitize parameters to ensure no PII is tracked
  Map<String, dynamic> _sanitizeParameters(Map<String, dynamic> parameters) {
    final sanitized = <String, dynamic>{};
    
    for (final entry in parameters.entries) {
      final key = entry.key;
      final value = entry.value;
      
      // Skip PII keys
      if (_isPIIKey(key)) {
        continue;
      }
      
      // Sanitize string values
      if (value is String) {
        sanitized[key] = _sanitizeStringValue(value);
      } else if (value is Map<String, dynamic>) {
        sanitized[key] = _sanitizeParameters(value);
      } else if (value is List) {
        sanitized[key] = value.map((item) {
          if (item is String) return _sanitizeStringValue(item);
          if (item is Map<String, dynamic>) return _sanitizeParameters(item);
          return item;
        }).toList();
      } else {
        sanitized[key] = value;
      }
    }
    
    return sanitized;
  }

  /// Sanitize user properties
  Map<String, dynamic> _sanitizeProperties(Map<String, dynamic> properties) {
    final sanitized = <String, dynamic>{};
    
    // Only allow specific non-PII properties
    const allowedKeys = [
      'user_type', 'subscription_type', 'feature_flags', 'preferences',
      'app_version', 'platform', 'locale', 'timezone',
    ];
    
    for (final key in allowedKeys) {
      if (properties.containsKey(key)) {
        final value = properties[key];
        if (value is String) {
          sanitized[key] = _sanitizeStringValue(value);
        } else {
          sanitized[key] = value;
        }
      }
    }
    
    return sanitized;
  }

  /// Check if a key contains PII
  bool _isPIIKey(String key) {
    final lowerKey = key.toLowerCase();
    const piiKeys = [
      'email', 'phone', 'name', 'address', 'password', 'token', 'key',
      'user_id', 'customer', 'tenant', 'facility', 'contact', 'personal',
      'id', 'uuid', 'identifier',
    ];
    
    return piiKeys.any((piiKey) => lowerKey.contains(piiKey));
  }

  /// Sanitize string values
  String _sanitizeStringValue(String value) {
    // Limit length
    if (value.length > 200) {
      value = '${value.substring(0, 200)}...';
    }
    
    // Remove potential PII patterns
    value = value.replaceAll(RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'), '[EMAIL]');
    value = value.replaceAll(RegExp(r'\b\d{10,15}\b'), '[PHONE]');
    value = value.replaceAll(RegExp(r'\b[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}\b'), '[UUID]');
    
    return value;
  }
}

/// Analytics helper methods for common tracking patterns
class AnalyticsHelper {
  const AnalyticsHelper._();

  /// Track screen navigation
  static void trackNavigation(Analytics analytics, String screenName, {String? previousScreen}) {
    analytics.trackScreenView(screenName, {
      if (previousScreen != null) 'previous_screen': previousScreen,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Track user action
  static void trackAction(Analytics analytics, String action, {String? screen, Map<String, dynamic>? context}) {
    analytics.trackEvent('user_action', {
      'action': action,
      if (screen != null) 'screen': screen,
      if (context != null) 'context': context,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Track feature usage
  static void trackFeatureUsage(Analytics analytics, String feature, {String? outcome}) {
    analytics.trackEvent('feature_usage', {
      'feature': feature,
      if (outcome != null) 'outcome': outcome,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Track performance metrics
  static void trackPerformance(Analytics analytics, String operation, Duration duration, {bool? success}) {
    analytics.trackEvent('performance', {
      'operation': operation,
      'duration_ms': duration.inMilliseconds,
      if (success != null) 'success': success,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Track error occurrences (non-PII)
  static void trackError(Analytics analytics, String errorType, {String? screen, String? category}) {
    analytics.trackEvent('error_occurrence', {
      'error_type': errorType,
      if (screen != null) 'screen': screen,
      if (category != null) 'category': category,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Track user engagement
  static void trackEngagement(Analytics analytics, String engagementType, {dynamic value}) {
    analytics.trackEvent('user_engagement', {
      'engagement_type': engagementType,
      if (value != null) 'value': value,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
}

/// Analytics page view tracker widget
class AnalyticsPageView extends ConsumerWidget {
  const AnalyticsPageView({
    super.key,
    required this.screenName,
    required this.child,
    this.parameters,
  });

  final String screenName;
  final Widget child;
  final Map<String, dynamic>? parameters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.watch(analyticsProvider);
    
    // Track screen view when widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AnalyticsHelper.trackNavigation(analytics, screenName);
      
      if (parameters != null) {
        analytics.trackEvent('screen_parameters', {
          'screen_name': screenName,
          'parameters': parameters,
        });
      }
    });

    return child;
  }
}