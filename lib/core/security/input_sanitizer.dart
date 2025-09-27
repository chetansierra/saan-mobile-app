import 'dart:convert';

/// Input sanitization utilities for security hardening
class InputSanitizer {
  const InputSanitizer._();

  /// Sanitize string input to prevent XSS and injection attacks
  static String sanitizeString(String input, {int? maxLength}) {
    String sanitized = input.trim();
    
    // Apply max length if specified
    if (maxLength != null && sanitized.length > maxLength) {
      sanitized = sanitized.substring(0, maxLength);
    }
    
    // Remove potentially dangerous characters
    sanitized = sanitized
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;')
        .replaceAll('&', '&amp;')
        .replaceAll('/', '&#x2F;');
    
    // Remove null bytes and control characters
    sanitized = sanitized.replaceAll(RegExp(r'[\x00-\x1f\x7f]'), '');
    
    return sanitized;
  }

  /// Sanitize email input
  static String sanitizeEmail(String email) {
    final sanitized = email.toLowerCase().trim();
    
    // Basic email format validation
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(sanitized)) {
      throw ArgumentError('Invalid email format');
    }
    
    return sanitized;
  }

  /// Sanitize phone number input
  static String sanitizePhoneNumber(String phone) {
    // Remove all non-digit characters
    final digitsOnly = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    // Validate length (assuming international format)
    if (digitsOnly.length < 10 || digitsOnly.length > 15) {
      throw ArgumentError('Invalid phone number length');
    }
    
    return digitsOnly;
  }

  /// Sanitize URL input
  static String sanitizeUrl(String url) {
    final sanitized = url.trim();
    
    // Allow only http and https protocols
    final urlRegex = RegExp(r'^https?:\/\/[^\s/$.?#].[^\s]*$');
    if (!urlRegex.hasMatch(sanitized)) {
      throw ArgumentError('Invalid URL format');
    }
    
    return sanitized;
  }

  /// Sanitize file path to prevent directory traversal
  static String sanitizeFilePath(String path) {
    String sanitized = path.trim();
    
    // Remove directory traversal attempts
    sanitized = sanitized.replaceAll('../', '');
    sanitized = sanitized.replaceAll('..\\', '');
    
    // Remove absolute path indicators
    sanitized = sanitized.replaceAll(RegExp(r'^[/\\]'), '');
    
    // Remove potentially dangerous characters
    sanitized = sanitized.replaceAll(RegExp(r'[<>:"|?*]'), '_');
    
    // Limit to alphanumeric, dots, dashes, underscores, and forward slashes
    sanitized = sanitized.replaceAll(RegExp(r'[^a-zA-Z0-9.\-_/]'), '_');
    
    return sanitized;
  }

  /// Sanitize JSON input
  static Map<String, dynamic> sanitizeJson(String jsonString, {int maxDepth = 10}) {
    try {
      final decoded = jsonDecode(jsonString);
      return _sanitizeJsonObject(decoded, maxDepth);
    } catch (e) {
      throw ArgumentError('Invalid JSON format: $e');
    }
  }

  /// Recursively sanitize JSON object
  static Map<String, dynamic> _sanitizeJsonObject(
    dynamic obj, 
    int remainingDepth,
  ) {
    if (remainingDepth <= 0) {
      throw ArgumentError('JSON object too deeply nested');
    }

    if (obj is Map<String, dynamic>) {
      final sanitized = <String, dynamic>{};
      
      for (final entry in obj.entries) {
        final key = sanitizeString(entry.key, maxLength: 100);
        final value = entry.value;
        
        if (value is String) {
          sanitized[key] = sanitizeString(value, maxLength: 1000);
        } else if (value is Map<String, dynamic>) {
          sanitized[key] = _sanitizeJsonObject(value, remainingDepth - 1);
        } else if (value is List) {
          sanitized[key] = _sanitizeJsonList(value, remainingDepth - 1);
        } else if (value is num || value is bool || value == null) {
          sanitized[key] = value;
        } else {
          // Skip unsupported types
          continue;
        }
      }
      
      return sanitized;
    } else {
      throw ArgumentError('Expected JSON object');
    }
  }

  /// Sanitize JSON list
  static List<dynamic> _sanitizeJsonList(List<dynamic> list, int remainingDepth) {
    if (remainingDepth <= 0) {
      throw ArgumentError('JSON array too deeply nested');
    }

    final sanitized = <dynamic>[];
    
    for (final item in list) {
      if (item is String) {
        sanitized.add(sanitizeString(item, maxLength: 1000));
      } else if (item is Map<String, dynamic>) {
        sanitized.add(_sanitizeJsonObject(item, remainingDepth - 1));
      } else if (item is List) {
        sanitized.add(_sanitizeJsonList(item, remainingDepth - 1));
      } else if (item is num || item is bool || item == null) {
        sanitized.add(item);
      }
      // Skip unsupported types
    }
    
    return sanitized;
  }

  /// Validate and sanitize search query
  static String sanitizeSearchQuery(String query) {
    String sanitized = query.trim();
    
    // Limit length
    if (sanitized.length > 100) {
      sanitized = sanitized.substring(0, 100);
    }
    
    // Remove special SQL/NoSQL injection characters
    sanitized = sanitized.replaceAll(RegExp(r'[;\'"`\$]'), '');
    
    // Remove excessive whitespace
    sanitized = sanitized.replaceAll(RegExp(r'\s+'), ' ');
    
    return sanitized;
  }

  /// Validate and sanitize user input for forms
  static String sanitizeFormInput(
    String input, {
    int maxLength = 500,
    bool allowHtml = false,
    bool allowNewlines = true,
  }) {
    String sanitized = input.trim();
    
    // Apply max length
    if (sanitized.length > maxLength) {
      sanitized = sanitized.substring(0, maxLength);
    }
    
    // Handle HTML based on allowHtml flag
    if (!allowHtml) {
      sanitized = sanitizeString(sanitized);
    }
    
    // Handle newlines based on allowNewlines flag
    if (!allowNewlines) {
      sanitized = sanitized.replaceAll(RegExp(r'[\r\n]'), ' ');
      sanitized = sanitized.replaceAll(RegExp(r'\s+'), ' ');
    }
    
    return sanitized;
  }

  /// Validate UUID format
  static bool isValidUuid(String uuid) {
    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
    );
    return uuidRegex.hasMatch(uuid);
  }

  /// Validate tenant ID format (assumes UUID format)
  static String validateTenantId(String tenantId) {
    if (!isValidUuid(tenantId)) {
      throw ArgumentError('Invalid tenant ID format');
    }
    return tenantId;
  }

  /// Sanitize and validate storage path
  static String sanitizeStoragePath(String path, String tenantId) {
    // Validate tenant ID first
    validateTenantId(tenantId);
    
    // Sanitize the path
    String sanitized = sanitizeFilePath(path);
    
    // Ensure path starts with tenant ID for isolation
    if (!sanitized.startsWith('$tenantId/')) {
      sanitized = '$tenantId/$sanitized';
    }
    
    // Validate path doesn't try to escape tenant directory
    final pathParts = sanitized.split('/');
    if (pathParts.first != tenantId) {
      throw ArgumentError('Storage path must be within tenant directory');
    }
    
    return sanitized;
  }

  /// Rate limiting key sanitization
  static String sanitizeRateLimitKey(String key) {
    return key
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]'), '_')
        .substring(0, key.length > 50 ? 50 : key.length);
  }

  /// Sanitize payment reference ID
  static String sanitizePaymentReference(String reference) {
    String sanitized = reference.trim().toUpperCase();
    
    // Only allow alphanumeric and underscores
    sanitized = sanitized.replaceAll(RegExp(r'[^A-Z0-9_]'), '');
    
    // Validate length
    if (sanitized.length < 5 || sanitized.length > 35) {
      throw ArgumentError('Payment reference must be between 5 and 35 characters');
    }
    
    return sanitized;
  }
}