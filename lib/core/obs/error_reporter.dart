import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../supabase/client.dart';
import 'analytics.dart';

/// Provider for ErrorReporter
final errorReporterProvider = Provider<ErrorReporter>((ref) {
  return ErrorReporter._(ref.watch(analyticsProvider));
});

/// Centralized error reporting with privacy-first context capture
class ErrorReporter {
  ErrorReporter._(this._analytics) {
    _initialize();
  }

  final Analytics _analytics;
  bool _isInitialized = false;

  /// Initialize error reporting
  void _initialize() {
    if (_isInitialized) return;

    // Capture Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      _handleFlutterError(details);
    };

    // Capture errors in async code
    PlatformDispatcher.instance.onError = (error, stack) {
      _handlePlatformError(error, stack);
      return true; // Mark as handled
    };

    // Capture isolate errors
    Isolate.current.addErrorListener(RawReceivePort((pair) async {
      final List<dynamic> errorAndStacktrace = pair;
      final error = errorAndStacktrace.first;
      final stack = errorAndStacktrace.last;
      _handleIsolateError(error, stack);
    }).sendPort);

    _isInitialized = true;
    debugPrint('✅ ErrorReporter initialized');
  }

  /// Handle Flutter framework errors
  void _handleFlutterError(FlutterErrorDetails details) {
    // Log to console in debug mode
    if (kDebugMode) {
      FlutterError.presentError(details);
    }

    // Extract privacy-safe error context
    final errorContext = _extractErrorContext(
      error: details.exception,
      stackTrace: details.stack,
      library: details.library,
      context: details.context,
    );

    // Report error without PII
    _reportError(
      type: 'flutter_error',
      error: details.exception.toString(),
      context: errorContext,
    );
  }

  /// Handle platform dispatcher errors (async)
  bool _handlePlatformError(Object error, StackTrace stackTrace) {
    // Log to console in debug mode
    if (kDebugMode) {
      debugPrint('Platform Error: $error\n$stackTrace');
    }

    // Extract privacy-safe error context
    final errorContext = _extractErrorContext(
      error: error,
      stackTrace: stackTrace,
    );

    // Report error without PII
    _reportError(
      type: 'platform_error',
      error: error.toString(),
      context: errorContext,
    );

    return true;
  }

  /// Handle isolate errors
  void _handleIsolateError(dynamic error, dynamic stackTrace) {
    // Log to console in debug mode
    if (kDebugMode) {
      debugPrint('Isolate Error: $error\n$stackTrace');
    }

    // Extract privacy-safe error context
    final errorContext = _extractErrorContext(
      error: error,
      stackTrace: stackTrace is StackTrace ? stackTrace : null,
    );

    // Report error without PII
    _reportError(
      type: 'isolate_error',
      error: error.toString(),
      context: errorContext,
    );
  }

  /// Manually report an error with optional context
  void reportError(
    Object error, {
    StackTrace? stackTrace,
    String? context,
    Map<String, dynamic>? extras,
  }) {
    try {
      // Log to console in debug mode
      if (kDebugMode) {
        debugPrint('Manual Error Report: $error');
        if (stackTrace != null) {
          debugPrint('Stack Trace: $stackTrace');
        }
        if (context != null) {
          debugPrint('Context: $context');
        }
      }

      // Extract privacy-safe error context
      final errorContext = _extractErrorContext(
        error: error,
        stackTrace: stackTrace,
        manualContext: context,
        extras: extras,
      );

      // Report error without PII
      _reportError(
        type: 'manual_error',
        error: error.toString(),
        context: errorContext,
      );
    } catch (e) {
      // Prevent recursive error reporting
      debugPrint('Failed to report error: $e');
    }
  }

  /// Report a non-fatal issue for monitoring
  void reportIssue(
    String message, {
    String? category,
    Map<String, dynamic>? data,
  }) {
    try {
      if (kDebugMode) {
        debugPrint('Issue Report: $message');
      }

      final sanitizedData = _sanitizeData(data ?? {});

      _analytics.trackEvent('app_issue', {
        'message': _sanitizeString(message),
        'category': category ?? 'general',
        'data': sanitizedData,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Failed to report issue: $e');
    }
  }

  /// Extract privacy-safe context from error details
  Map<String, dynamic> _extractErrorContext({
    required Object error,
    StackTrace? stackTrace,
    String? library,
    String? context,
    String? manualContext,
    Map<String, dynamic>? extras,
  }) {
    final errorContext = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'error_type': error.runtimeType.toString(),
      'is_debug': kDebugMode,
      'platform': defaultTargetPlatform.name,
    };

    // Add library information if available
    if (library != null) {
      errorContext['library'] = _sanitizeString(library);
    }

    // Add context if available (sanitized)
    if (context != null) {
      errorContext['context'] = _sanitizeString(context);
    }

    if (manualContext != null) {
      errorContext['manual_context'] = _sanitizeString(manualContext);
    }

    // Add stack trace information (first few frames only, sanitized)
    if (stackTrace != null) {
      errorContext['stack_info'] = _extractStackInfo(stackTrace);
    }

    // Add sanitized extras
    if (extras != null) {
      errorContext['extras'] = _sanitizeData(extras);
    }

    // Add app state information (non-PII)
    errorContext['app_state'] = _getAppStateInfo();

    return errorContext;
  }

  /// Extract non-PII stack trace information
  Map<String, dynamic> _extractStackInfo(StackTrace stackTrace) {
    try {
      final stackLines = stackTrace.toString().split('\n');
      return {
        'frames_count': stackLines.length,
        'first_frame': _sanitizeStackFrame(stackLines.isNotEmpty ? stackLines.first : ''),
        'has_flutter_frames': stackLines.any((line) => line.contains('package:flutter/')),
        'has_app_frames': stackLines.any((line) => line.contains('package:maintpulse/')),
      };
    } catch (e) {
      return {'extraction_error': true};
    }
  }

  /// Sanitize a stack frame to remove PII
  String _sanitizeStackFrame(String frame) {
    // Remove file paths and keep only method names and line numbers
    final sanitized = frame
        .replaceAll(RegExp(r'/[^/\s]+/'), '/.../') // Replace paths
        .replaceAll(RegExp(r'file:///[^\s]+'), 'file:///.../') // Replace file URIs
        .replaceAll(RegExp(r'[a-zA-Z]:\\[^\s]+'), 'C:\\...\\'); // Replace Windows paths
    
    return sanitized.length > 200 ? '${sanitized.substring(0, 200)}...' : sanitized;
  }

  /// Get non-PII app state information
  Map<String, dynamic> _getAppStateInfo() {
    return {
      'supabase_initialized': SupabaseService.isInitialized,
      'debug_mode': kDebugMode,
      'platform': defaultTargetPlatform.name,
      'locale': PlatformDispatcher.instance.locale.toString(),
    };
  }

  /// Sanitize string data to remove potential PII
  String _sanitizeString(String input) {
    if (input.length > 500) {
      input = '${input.substring(0, 500)}...';
    }

    // Remove potential emails
    input = input.replaceAll(RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'), '[EMAIL]');
    
    // Remove potential phone numbers
    input = input.replaceAll(RegExp(r'\b\d{10,15}\b'), '[PHONE]');
    
    // Remove potential IDs (UUIDs, long numbers)
    input = input.replaceAll(RegExp(r'\b[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}\b'), '[UUID]');
    
    return input;
  }

  /// Sanitize data map to remove potential PII
  Map<String, dynamic> _sanitizeData(Map<String, dynamic> data) {
    final sanitized = <String, dynamic>{};
    
    for (final entry in data.entries) {
      final key = entry.key;
      final value = entry.value;
      
      // Skip keys that might contain PII
      if (_isPIIKey(key)) {
        sanitized[key] = '[REDACTED]';
        continue;
      }
      
      if (value is String) {
        sanitized[key] = _sanitizeString(value);
      } else if (value is Map<String, dynamic>) {
        sanitized[key] = _sanitizeData(value);
      } else if (value is List) {
        sanitized[key] = value.map((item) {
          if (item is String) return _sanitizeString(item);
          if (item is Map<String, dynamic>) return _sanitizeData(item);
          return item;
        }).toList();
      } else {
        sanitized[key] = value;
      }
    }
    
    return sanitized;
  }

  /// Check if a key might contain PII
  bool _isPIIKey(String key) {
    final lowerKey = key.toLowerCase();
    const piiKeys = [
      'email', 'phone', 'name', 'address', 'password', 'token', 'key',
      'user', 'customer', 'tenant', 'facility', 'contact', 'personal',
    ];
    
    return piiKeys.any((piiKey) => lowerKey.contains(piiKey));
  }

  /// Report the processed error to analytics
  void _reportError(
    String type,
    String error,
    Map<String, dynamic> context,
  ) {
    try {
      _analytics.trackEvent('app_error', {
        'error_type': type,
        'error_message': _sanitizeString(error),
        'context': context,
      });
    } catch (e) {
      // Prevent recursive error reporting
      debugPrint('Failed to track error event: $e');
    }
  }

  /// Test error reporting (development only)
  void testErrorReporting() {
    if (!kDebugMode) return;
    
    debugPrint('🧪 Testing error reporting...');
    
    // Test manual error report
    reportError(
      Exception('Test error for validation'),
      context: 'Error reporting test',
      extras: {'test': true, 'timestamp': DateTime.now().toIso8601String()},
    );
    
    // Test issue report
    reportIssue(
      'Test issue report',
      category: 'testing',
      data: {'test_data': 'sample'},
    );
    
    debugPrint('✅ Error reporting test completed');
  }
}

/// Error boundary widget for catching widget build errors
class ErrorBoundary extends StatefulWidget {
  const ErrorBoundary({
    super.key,
    required this.child,
    this.onError,
    this.fallback,
  });

  final Widget child;
  final void Function(Object error, StackTrace stackTrace)? onError;
  final Widget Function(Object error)? fallback;

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return widget.fallback?.call(_error!) ?? 
        const Center(
          child: Text(
            'Something went wrong',
            style: TextStyle(color: Colors.red),
          ),
        );
    }

    return widget.child;
  }

  @override
  void initState() {
    super.initState();
    
    // Set up error handler for this widget tree
    FlutterError.onError = (details) {
      if (mounted) {
        setState(() {
          _error = details.exception;
        });
        
        widget.onError?.call(details.exception, details.stack ?? StackTrace.current);
      }
    };
  }
}