import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase service for managing client initialization and configuration
class SupabaseService {
  SupabaseService._();

  /// Singleton Supabase client instance
  static SupabaseClient get client => Supabase.instance.client;

  /// Auth client for authentication operations
  static GoTrueClient get auth => client.auth;

  /// Database client for data operations
  static PostgrestClient get database => client.from('');

  /// Storage client for file operations
  static SupabaseStorageClient get storage => client.storage;

  /// Realtime client for live subscriptions
  static RealtimeClient get realtime => client.realtime;

  /// Initialize Supabase with environment configuration
  static Future<void> initialize() async {
    // In production, these should come from environment variables
    // For now, using placeholder values - update with actual Supabase project details
    const supabaseUrl = String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://your-project.supabase.co',
    );
    
    const supabaseAnonKey = String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: 'your-anon-key-here',
    );

    // Validate required configuration
    if (supabaseUrl == 'https://your-project.supabase.co' ||
        supabaseAnonKey == 'your-anon-key-here') {
      throw Exception(
        'Supabase configuration not found. Please provide SUPABASE_URL and '
        'SUPABASE_ANON_KEY environment variables or update the default values '
        'in SupabaseService.initialize()',
      );
    }

    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
          detectSessionInUri: true,
        ),
        realtimeClientOptions: const RealtimeClientOptions(
          logLevel: kDebugMode ? RealtimeLogLevel.info : RealtimeLogLevel.error,
          eventsPerSecond: 10,
        ),
        storageOptions: const StorageClientOptions(
          retryAttempts: 3,
        ),
        postgrestOptions: const PostgrestClientOptions(
          schema: 'public',
        ),
        debug: kDebugMode,
      );

      debugPrint('✅ Supabase initialized successfully');
    } catch (error) {
      debugPrint('❌ Supabase initialization failed: $error');
      rethrow;
    }
  }

  /// Check if Supabase is initialized and ready to use
  static bool get isInitialized {
    try {
      return Supabase.instance.client.auth.currentSession != null ||
             Supabase.instance.client.auth.currentUser == null;
    } catch (_) {
      return false;
    }
  }

  /// Get current authenticated user
  static User? get currentUser => auth.currentUser;

  /// Get current user session
  static Session? get currentSession => auth.currentSession;

  /// Stream of auth state changes
  static Stream<AuthState> get authStateStream => auth.onAuthStateChange;

  /// Sign out current user
  static Future<void> signOut() async {
    try {
      await auth.signOut();
      debugPrint('✅ User signed out successfully');
    } catch (error) {
      debugPrint('❌ Sign out failed: $error');
      rethrow;
    }
  }

  /// Get storage path for tenant-scoped file uploads
  static String getStoragePath({
    required String tenantId,
    required String entity,
    required String recordId,
    required String filename,
  }) {
    return '$tenantId/$entity/$recordId/$filename';
  }

  /// Get signed URL for private file access
  static Future<String> getSignedUrl({
    required String bucket,
    required String path,
    int expiresIn = 3600, // 1 hour default
  }) async {
    try {
      final response = await storage.from(bucket).createSignedUrl(path, expiresIn);
      return response;
    } catch (error) {
      debugPrint('❌ Failed to get signed URL: $error');
      rethrow;
    }
  }

  /// Upload file to tenant-scoped storage
  static Future<String> uploadFile({
    required String bucket,
    required String tenantId,
    required String entity,
    required String recordId,
    required String filename,
    required List<int> fileBytes,
    String? contentType,
  }) async {
    try {
      final path = getStoragePath(
        tenantId: tenantId,
        entity: entity,
        recordId: recordId,
        filename: filename,
      );

      await storage.from(bucket).uploadBinary(
        path,
        fileBytes,
        fileOptions: FileOptions(
          contentType: contentType,
          cacheControl: '3600',
          upsert: false,
        ),
      );

      debugPrint('✅ File uploaded successfully: $path');
      return path;
    } catch (error) {
      debugPrint('❌ File upload failed: $error');
      rethrow;
    }
  }

  /// Delete file from storage
  static Future<void> deleteFile({
    required String bucket,
    required String path,
  }) async {
    try {
      await storage.from(bucket).remove([path]);
      debugPrint('✅ File deleted successfully: $path');
    } catch (error) {
      debugPrint('❌ File deletion failed: $error');
      rethrow;
    }
  }

  /// Create a realtime subscription with tenant isolation
  static RealtimeChannel createTenantSubscription({
    required String table,
    required String tenantId,
    String? schema = 'public',
  }) {
    final channel = realtime.channel('$table:$tenantId');
    
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: schema ?? 'public',
      table: table,
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'tenant_id',
        value: tenantId,
      ),
      callback: (payload) {
        debugPrint('📡 Realtime update for $table: ${payload.eventType}');
      },
    );

    return channel;
  }
}

/// Extension to add convenience methods to SupabaseClient
extension SupabaseClientExtension on SupabaseClient {
  /// Get a table reference with automatic tenant filtering
  PostgrestFilterBuilder<Map<String, dynamic>> fromTenant(
    String table,
    String tenantId,
  ) {
    return from(table).eq('tenant_id', tenantId);
  }
}

/// Supabase table names constants
abstract class SupabaseTables {
  static const String tenants = 'tenants';
  static const String profiles = 'profiles';
  static const String facilities = 'facilities';
  static const String contracts = 'contracts';
  static const String contractFacilities = 'contract_facilities';
  static const String requests = 'requests';
  static const String pmVisits = 'pm_visits';
  static const String invoices = 'invoices';
  static const String invoiceLines = 'invoice_lines';
  static const String paymentAttempts = 'payment_attempts';
  static const String subscriptions = 'subscriptions';
  static const String auditLogs = 'audit_logs';
}

/// Supabase storage bucket names constants
abstract class SupabaseBuckets {
  static const String attachments = 'attachments';
}

/// Custom exceptions for Supabase operations
class SupabaseException implements Exception {
  const SupabaseException(this.message, [this.code]);

  final String message;
  final String? code;

  @override
  String toString() => 'SupabaseException: $message ${code != null ? '($code)' : ''}';
}

/// Extension to handle PostgrestException conversion
extension PostgrestExceptionExtension on PostgrestException {
  SupabaseException toSupabaseException() {
    return SupabaseException(message, code);
  }
}

/// Extension to handle AuthException conversion
extension AuthExceptionExtension on AuthException {
  SupabaseException toSupabaseException() {
    return SupabaseException(message, statusCode);
  }
}