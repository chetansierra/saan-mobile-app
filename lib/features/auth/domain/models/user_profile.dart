import 'package:equatable/equatable.dart';

/// User profile model matching the database schema
class UserProfile extends Equatable {
  const UserProfile({
    required this.userId,
    required this.tenantId,
    required this.email,
    required this.name,
    required this.role,
    this.phone,
    required this.createdAt,
  });

  /// User ID (matches auth.users.id)
  final String userId;

  /// Tenant ID for multi-tenant isolation
  final String tenantId;

  /// User email address
  final String email;

  /// User display name
  final String name;

  /// User role within the tenant
  final UserRole role;

  /// Optional phone number
  final String? phone;

  /// Profile creation timestamp
  final DateTime createdAt;

  /// Create UserProfile from JSON (Supabase response)
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['user_id'] as String,
      tenantId: json['tenant_id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      role: UserRole.fromString(json['role'] as String),
      phone: json['phone'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Convert UserProfile to JSON (for Supabase operations)
  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'tenant_id': tenantId,
      'email': email,
      'name': name,
      'role': role.value,
      'phone': phone,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  UserProfile copyWith({
    String? userId,
    String? tenantId,
    String? email,
    String? name,
    UserRole? role,
    String? phone,
    DateTime? createdAt,
  }) {
    return UserProfile(
      userId: userId ?? this.userId,
      tenantId: tenantId ?? this.tenantId,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        userId,
        tenantId,
        email,
        name,
        role,
        phone,
        createdAt,
      ];
}

/// User role enumeration matching database schema
enum UserRole {
  admin('admin'),
  requester('requester');

  const UserRole(this.value);

  final String value;

  /// Create UserRole from string value
  static UserRole fromString(String value) {
    switch (value) {
      case 'admin':
        return UserRole.admin;
      case 'requester':
        return UserRole.requester;
      default:
        throw ArgumentError('Invalid user role: $value');
    }
  }

  /// Display name for the role
  String get displayName {
    switch (this) {
      case UserRole.admin:
        return 'Administrator';
      case UserRole.requester:
        return 'Requester';
    }
  }

  /// Check if user has admin privileges
  bool get isAdmin => this == UserRole.admin;

  /// Check if user is a requester
  bool get isRequester => this == UserRole.requester;
}

/// Authentication state model
class AuthState extends Equatable {
  const AuthState({
    this.isAuthenticated = false,
    this.user,
    this.profile,
    this.isLoading = false,
    this.error,
  });

  /// Whether user is authenticated
  final bool isAuthenticated;

  /// Supabase user object
  final dynamic user; // Using dynamic to avoid importing supabase_flutter here

  /// User profile with tenant information
  final UserProfile? profile;

  /// Loading state for auth operations
  final bool isLoading;

  /// Error message if auth operation failed
  final String? error;

  /// Whether user has a complete profile
  bool get hasCompleteProfile => profile != null;

  /// Whether user is admin
  bool get isAdmin => profile?.role.isAdmin ?? false;

  /// Whether user is requester
  bool get isRequester => profile?.role.isRequester ?? false;

  /// Get tenant ID from profile
  String? get tenantId => profile?.tenantId;

  /// Create copy with updated fields
  AuthState copyWith({
    bool? isAuthenticated,
    dynamic user,
    UserProfile? profile,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  /// Create loading state
  AuthState copyWithLoading(bool loading) {
    return copyWith(isLoading: loading, error: null);
  }

  /// Create error state
  AuthState copyWithError(String errorMessage) {
    return copyWith(isLoading: false, error: errorMessage);
  }

  /// Create authenticated state
  AuthState copyWithAuth({
    required dynamic user,
    UserProfile? profile,
  }) {
    return copyWith(
      isAuthenticated: true,
      user: user,
      profile: profile,
      isLoading: false,
      error: null,
    );
  }

  /// Create unauthenticated state
  AuthState copyWithSignOut() {
    return const AuthState(
      isAuthenticated: false,
      user: null,
      profile: null,
      isLoading: false,
      error: null,
    );
  }

  @override
  List<Object?> get props => [
        isAuthenticated,
        user,
        profile,
        isLoading,
        error,
      ];
}