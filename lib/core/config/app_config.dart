import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../obs/analytics.dart';
import '../obs/error_reporter.dart';

/// Application configuration and environment validation
class AppConfig {
  static AppConfig? _instance;
  static AppConfig get instance => _instance ??= AppConfig._();
  AppConfig._();

  bool _isInitialized = false;
  late final Map<String, String> _config;
  late final List<String> _validationErrors;

  /// Required environment variables
  static const List<String> _requiredEnvVars = [
    'SUPABASE_URL',
    'SUPABASE_ANON_KEY',
  ];

  /// Optional environment variables with defaults
  static const Map<String, String> _optionalEnvVars = {
    'APP_NAME': 'MaintPulse',
    'APP_VERSION': '1.0.0',
    'MAX_FILE_SIZE_MB': '10',
    'MAX_IMAGE_SIZE_MB': '5',
    'ANALYTICS_ENABLED': 'true',
    'ERROR_REPORTING_ENABLED': 'true',
  };

  /// Initialize application configuration
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('🔧 Initializing AppConfig...');
      
      _config = <String, String>{};
      _validationErrors = <String>[];

      // Load environment variables
      await _loadEnvironmentVariables();

      // Validate configuration
      _validateConfiguration();

      // Log validation results
      _logValidationResults();

      _isInitialized = true;
      debugPrint('✅ AppConfig initialized successfully');
    } catch (e) {
      debugPrint('❌ Failed to initialize AppConfig: $e');
      _validationErrors.add('Failed to initialize configuration: $e');
    }
  }

  /// Load environment variables from various sources
  Future<void> _loadEnvironmentVariables() async {
    // In Flutter, environment variables are typically accessed via
    // const String.fromEnvironment() or through platform channels
    
    // Load required environment variables
    for (final envVar in _requiredEnvVars) {
      final value = _getEnvironmentVariable(envVar);
      if (value != null && value.isNotEmpty) {
        _config[envVar] = value;
      }
    }

    // Load optional environment variables with defaults
    for (final entry in _optionalEnvVars.entries) {
      final key = entry.key;
      final defaultValue = entry.value;
      final value = _getEnvironmentVariable(key) ?? defaultValue;
      _config[key] = value;
    }

    debugPrint('📊 Loaded ${_config.length} configuration values');
  }

  /// Get environment variable from various sources
  String? _getEnvironmentVariable(String key) {
    // Try compile-time environment variables first
    const String? compileTimeValue = String.fromEnvironment('');
    if (compileTimeValue != null && compileTimeValue.isNotEmpty) {
      return compileTimeValue;
    }

    // For Flutter, environment variables are typically handled differently
    // This is a placeholder for actual implementation
    switch (key) {
      case 'SUPABASE_URL':
        return const String.fromEnvironment('SUPABASE_URL');
      case 'SUPABASE_ANON_KEY':
        return const String.fromEnvironment('SUPABASE_ANON_KEY');
      default:
        return const String.fromEnvironment(key);
    }
  }

  /// Validate configuration values
  void _validateConfiguration() {
    // Validate required environment variables
    for (final envVar in _requiredEnvVars) {
      if (!_config.containsKey(envVar) || _config[envVar]!.isEmpty) {
        _validationErrors.add('Missing required environment variable: $envVar');
      }
    }

    // Validate Supabase URL format
    final supabaseUrl = _config['SUPABASE_URL'];
    if (supabaseUrl != null && supabaseUrl.isNotEmpty) {
      if (!_isValidUrl(supabaseUrl)) {
        _validationErrors.add('Invalid SUPABASE_URL format: $supabaseUrl');
      }
    }

    // Validate Supabase anon key format
    final supabaseKey = _config['SUPABASE_ANON_KEY'];
    if (supabaseKey != null && supabaseKey.isNotEmpty) {
      if (supabaseKey.length < 20) {
        _validationErrors.add('SUPABASE_ANON_KEY appears to be too short');
      }
    }

    // Validate numeric configuration values
    _validateNumericConfig('MAX_FILE_SIZE_MB', min: 1, max: 100);
    _validateNumericConfig('MAX_IMAGE_SIZE_MB', min: 1, max: 50);

    // Validate boolean configuration values
    _validateBooleanConfig('ANALYTICS_ENABLED');
    _validateBooleanConfig('ERROR_REPORTING_ENABLED');
  }

  /// Validate URL format
  bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  /// Validate numeric configuration value
  void _validateNumericConfig(String key, {int? min, int? max}) {
    final value = _config[key];
    if (value == null) return;

    final numValue = int.tryParse(value);
    if (numValue == null) {
      _validationErrors.add('Invalid numeric value for $key: $value');
      return;
    }

    if (min != null && numValue < min) {
      _validationErrors.add('$key value $numValue is below minimum $min');
    }

    if (max != null && numValue > max) {
      _validationErrors.add('$key value $numValue is above maximum $max');
    }
  }

  /// Validate boolean configuration value
  void _validateBooleanConfig(String key) {
    final value = _config[key]?.toLowerCase();
    if (value == null) return;

    if (!['true', 'false', '1', '0', 'yes', 'no'].contains(value)) {
      _validationErrors.add('Invalid boolean value for $key: $value');
    }
  }

  /// Log validation results
  void _logValidationResults() {
    if (_validationErrors.isNotEmpty) {
      debugPrint('⚠️ Configuration validation errors:');
      for (final error in _validationErrors) {
        debugPrint('  - $error');
      }
    } else {
      debugPrint('✅ Configuration validation passed');
    }

    if (kDebugMode) {
      debugPrint('📋 Configuration summary:');
      for (final entry in _config.entries) {
        final key = entry.key;
        final value = _shouldMaskValue(key) ? _maskValue(entry.value) : entry.value;
        debugPrint('  $key: $value');
      }
    }
  }

  /// Check if a configuration key should be masked in logs
  bool _shouldMaskValue(String key) {
    const sensitiveKeys = [
      'SUPABASE_ANON_KEY',
      'API_KEY',
      'SECRET',
      'PASSWORD',
      'TOKEN',
    ];
    
    return sensitiveKeys.any((sensitiveKey) => 
        key.toUpperCase().contains(sensitiveKey));
  }

  /// Mask sensitive configuration values
  String _maskValue(String value) {
    if (value.length <= 8) return '***';
    return '${value.substring(0, 4)}...${value.substring(value.length - 4)}';
  }

  /// Get configuration value
  String? getString(String key) {
    _ensureInitialized();
    return _config[key];
  }

  /// Get required configuration value
  String getRequiredString(String key) {
    final value = getString(key);
    if (value == null || value.isEmpty) {
      throw StateError('Required configuration key not found: $key');
    }
    return value;
  }

  /// Get integer configuration value
  int? getInt(String key) {
    final value = getString(key);
    if (value == null) return null;
    return int.tryParse(value);
  }

  /// Get required integer configuration value
  int getRequiredInt(String key) {
    final value = getInt(key);
    if (value == null) {
      throw StateError('Required integer configuration key not found: $key');
    }
    return value;
  }

  /// Get boolean configuration value
  bool getBool(String key, {bool defaultValue = false}) {
    final value = getString(key)?.toLowerCase();
    if (value == null) return defaultValue;
    
    switch (value) {
      case 'true':
      case '1':
      case 'yes':
        return true;
      case 'false':
      case '0':
      case 'no':
        return false;
      default:
        return defaultValue;
    }
  }

  /// Get double configuration value
  double? getDouble(String key) {
    final value = getString(key);
    if (value == null) return null;
    return double.tryParse(value);
  }

  /// Check if configuration is valid
  bool get isValid => _validationErrors.isEmpty;

  /// Get validation errors
  List<String> get validationErrors => List.unmodifiable(_validationErrors);

  /// Get app name
  String get appName => getString('APP_NAME') ?? 'MaintPulse';

  /// Get app version
  String get appVersion => getString('APP_VERSION') ?? '1.0.0';

  /// Get Supabase URL
  String get supabaseUrl => getRequiredString('SUPABASE_URL');

  /// Get Supabase anon key
  String get supabaseAnonKey => getRequiredString('SUPABASE_ANON_KEY');

  /// Get maximum file size in bytes
  int get maxFileSizeBytes => (getInt('MAX_FILE_SIZE_MB') ?? 10) * 1024 * 1024;

  /// Get maximum image size in bytes
  int get maxImageSizeBytes => (getInt('MAX_IMAGE_SIZE_MB') ?? 5) * 1024 * 1024;

  /// Check if analytics is enabled
  bool get analyticsEnabled => getBool('ANALYTICS_ENABLED', defaultValue: true);

  /// Check if error reporting is enabled
  bool get errorReportingEnabled => getBool('ERROR_REPORTING_ENABLED', defaultValue: true);

  /// Check if running in development mode
  bool get isDevelopment => kDebugMode;

  /// Check if running in production mode
  bool get isProduction => kReleaseMode;

  /// Ensure configuration is initialized
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError('AppConfig not initialized. Call initialize() first.');
    }
  }

  /// Validate configuration at runtime
  Future<void> validateRuntime() async {
    _ensureInitialized();
    
    if (!isValid) {
      final errorMessage = 'Configuration validation failed:\n${validationErrors.join('\n')}';
      
      if (errorReportingEnabled) {
        // Report configuration errors
        debugPrint('📊 Reporting configuration errors');
      }
      
      throw StateError(errorMessage);
    }
  }

  /// Get build information
  Map<String, dynamic> getBuildInfo() {
    return {
      'app_name': appName,
      'app_version': appVersion,
      'build_mode': isDevelopment ? 'debug' : 'release',
      'platform': defaultTargetPlatform.name,
      'analytics_enabled': analyticsEnabled,
      'error_reporting_enabled': errorReportingEnabled,
      'config_valid': isValid,
      'config_errors_count': validationErrors.length,
    };
  }

  /// Export configuration for debugging (non-sensitive values only)
  Map<String, dynamic> exportForDebug() {
    _ensureInitialized();
    
    final debugConfig = <String, dynamic>{};
    
    for (final entry in _config.entries) {
      final key = entry.key;
      final value = entry.value;
      
      if (_shouldMaskValue(key)) {
        debugConfig[key] = _maskValue(value);
      } else {
        debugConfig[key] = value;
      }
    }
    
    return debugConfig;
  }
}