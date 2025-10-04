import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../../core/supabase/client.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../data/auth_repository.dart';
import 'models/user_profile.dart';

/// Provider for AuthService singleton
final authServiceProvider = ChangeNotifierProvider<AuthService>((ref) {
  return AuthService._();
});

/// Authentication service that manages user authentication state and profile bootstrap
class AuthService extends ChangeNotifier {
  AuthService._() {
    _initializeAuthListener();
  }

  final AuthRepository _repository = AuthRepository.instance;
  final OnboardingRepository _onboardingRepository = OnboardingRepository.instance;
  
  AuthState _state = const AuthState();
  StreamSubscription<AuthState>? _authSubscription;

  /// Current authentication state
  AuthState get state => _state;

  /// Whether user is authenticated
  bool get isAuthenticated => _state.isAuthenticated;

  /// Whether user has complete profile with tenant information
  bool get hasCompleteProfile => _state.hasCompleteProfile;

  /// Current user profile
  UserProfile? get currentProfile => _state.profile;

  /// Alias for currentProfile (for consistency with other components)
  UserProfile? get userProfile => _state.profile;

  /// Current user
  User? get currentUser => _state.user;

  /// Tenant ID from current profile
  String? get tenantId => _state.tenantId;

  /// Whether current user is admin
  bool get isAdmin => _state.isAdmin;

  /// Whether current user is requester
  bool get isRequester => _state.isRequester;

  /// Initialize auth state listener
  void _initializeAuthListener() {
    debugPrint('🔄 Initializing auth state listener');
    
    // Check current session on startup
    _checkCurrentSession();
    
    // Listen to auth state changes
    _authSubscription = _repository.authStateStream.listen(
      _handleAuthStateChange,
      onError: (error) {
        debugPrint('❌ Auth stream error: $error');
        _updateState(_state.copyWithError(error.toString()));
      },
    );
  }

  /// Check current session and bootstrap profile if needed
  Future<void> _checkCurrentSession() async {
    final user = _repository.getCurrentUser();
    
    if (user != null) {
      debugPrint('👤 Found existing session for: ${user.email}');
      await _bootstrapUserProfile(user);
    } else {
      debugPrint('🔓 No existing session found');
      _updateState(const AuthState());
    }
  }

  /// Handle auth state changes from Supabase
  void _handleAuthStateChange(AuthState authState) async {
    debugPrint('🔄 Auth state change: authenticated=${authState.isAuthenticated}');
    
    if (authState.isAuthenticated && authState.user != null) {
      // User signed in, bootstrap profile
      await _bootstrapUserProfile(authState.user);
    } else {
      // User signed out
      _updateState(const AuthState());
    }
  }

  /// Bootstrap user profile after authentication
  Future<void> _bootstrapUserProfile(User user) async {
    try {
      _updateState(_state.copyWithLoading(true));
      
      debugPrint('🔄 Bootstrapping profile for user: ${user.id}');
      
      // Fetch existing profile
      final profile = await _repository.fetchUserProfile(user.id);
      
      if (profile != null) {
        debugPrint('✅ Profile found: ${profile.name} (${profile.role.displayName})');
        
        // Check if user has facilities (required for complete profile)
        final hasFacilities = await _onboardingRepository.hasFacilities(profile.tenantId);
        
        if (hasFacilities) {
          debugPrint('✅ Profile complete with facilities');
          _updateState(_state.copyWithAuth(
            user: user,
            profile: profile,
          ));
        } else {
          debugPrint('⚠️ Profile exists but no facilities found - incomplete onboarding');
          _updateState(_state.copyWithAuth(
            user: user,
            profile: null, // Set to null to trigger onboarding
          ));
        }
      } else {
        debugPrint('⚠️ No profile found, user needs onboarding');
        
        _updateState(_state.copyWithAuth(
          user: user,
          profile: null,
        ));
      }
    } catch (error) {
      debugPrint('❌ Profile bootstrap failed: $error');
      _updateState(_state.copyWithError('Failed to load profile: ${error.toString()}'));
    }
  }

  /// Sign in with email and password
  Future<void> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      _updateState(_state.copyWithLoading(true));
      
      final response = await _repository.signInWithEmailPassword(
        email: email,
        password: password,
      );
      
      if (response.user != null) {
        // Profile bootstrap will be handled by auth state listener
        debugPrint('✅ Sign in successful, waiting for profile bootstrap');
      } else {
        throw const SupabaseException('Sign in failed: No user returned');
      }
    } on SupabaseException catch (e) {
      debugPrint('❌ Sign in error: ${e.message}');
      _updateState(_state.copyWithError(e.message));
      rethrow;
    } catch (e) {
      debugPrint('❌ Unexpected sign in error: $e');
      final errorMessage = 'Sign in failed: ${e.toString()}';
      _updateState(_state.copyWithError(errorMessage));
      throw SupabaseException(errorMessage);
    }
  }

  /// Sign up with email and password
  Future<void> signUpWithEmailPassword({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      _updateState(_state.copyWithLoading(true));
      
      final response = await _repository.signUpWithEmailPassword(
        email: email,
        password: password,
        name: name,
      );
      
      if (response.user != null) {
        if (response.session != null) {
          // User is immediately signed in (email confirmation disabled)
          debugPrint('✅ Sign up successful, user signed in immediately');
        } else {
          // User needs to confirm email
          debugPrint('📧 Sign up successful, email confirmation required');
          _updateState(_state.copyWith(
            isLoading: false,
            error: null,
          ));
        }
      } else {
        throw const SupabaseException('Sign up failed: No user returned');
      }
    } on SupabaseException catch (e) {
      debugPrint('❌ Sign up error: ${e.message}');
      _updateState(_state.copyWithError(e.message));
      rethrow;
    } catch (e) {
      debugPrint('❌ Unexpected sign up error: $e');
      final errorMessage = 'Sign up failed: ${e.toString()}';
      _updateState(_state.copyWithError(errorMessage));
      throw SupabaseException(errorMessage);
    }
  }

  /// Sign out current user
  Future<void> signOut() async {
    try {
      debugPrint('🚪 Signing out user');
      _updateState(_state.copyWithLoading(true));
      
      await _repository.signOut();
      
      // State will be updated by auth state listener
      debugPrint('✅ Sign out completed');
    } on SupabaseException catch (e) {
      debugPrint('❌ Sign out error: ${e.message}');
      _updateState(_state.copyWithError(e.message));
      rethrow;
    } catch (e) {
      debugPrint('❌ Unexpected sign out error: $e');
      final errorMessage = 'Sign out failed: ${e.toString()}';
      _updateState(_state.copyWithError(errorMessage));
      throw SupabaseException(errorMessage);
    }
  }

  /// Resend email confirmation
  Future<void> resendEmailConfirmation(String email) async {
    try {
      _updateState(_state.copyWithLoading(true));
      
      await _repository.resendEmailConfirmation(email: email);
      
      _updateState(_state.copyWith(
        isLoading: false,
        error: null,
      ));
      
      debugPrint('✅ Email confirmation resent');
    } on SupabaseException catch (e) {
      debugPrint('❌ Resend email error: ${e.message}');
      _updateState(_state.copyWithError(e.message));
      rethrow;
    } catch (e) {
      debugPrint('❌ Unexpected resend email error: $e');
      final errorMessage = 'Failed to resend email: ${e.toString()}';
      _updateState(_state.copyWithError(errorMessage));
      throw SupabaseException(errorMessage);
    }
  }

  /// Reset password
  Future<void> resetPassword(String email) async {
    try {
      _updateState(_state.copyWithLoading(true));
      
      await _repository.resetPassword(email: email);
      
      _updateState(_state.copyWith(
        isLoading: false,
        error: null,
      ));
      
      debugPrint('✅ Password reset email sent');
    } on SupabaseException catch (e) {
      debugPrint('❌ Password reset error: ${e.message}');
      _updateState(_state.copyWithError(e.message));
      rethrow;
    } catch (e) {
      debugPrint('❌ Unexpected password reset error: $e');
      final errorMessage = 'Password reset failed: ${e.toString()}';
      _updateState(_state.copyWithError(errorMessage));
      throw SupabaseException(errorMessage);
    }
  }

  /// Create user profile (called during onboarding)
  Future<void> createUserProfile({
    required String tenantId,
    required String email,
    required String name,
    required UserRole role,
    String? phone,
  }) async {
    try {
      _updateState(_state.copyWithLoading(true));
      
      final user = currentUser;
      if (user == null) {
        throw const SupabaseException('No authenticated user found');
      }
      
      final profile = await _repository.createUserProfile(
        userId: user.id,
        tenantId: tenantId,
        email: email,
        name: name,
        role: role,
        phone: phone,
      );
      
      _updateState(_state.copyWithAuth(
        user: user,
        profile: profile,
      ));
      
      debugPrint('✅ User profile created successfully');
    } on SupabaseException catch (e) {
      debugPrint('❌ Profile creation error: ${e.message}');
      _updateState(_state.copyWithError(e.message));
      rethrow;
    } catch (e) {
      debugPrint('❌ Unexpected profile creation error: $e');
      final errorMessage = 'Profile creation failed: ${e.toString()}';
      _updateState(_state.copyWithError(errorMessage));
      throw SupabaseException(errorMessage);
    }
  }

  /// Update user profile
  Future<void> updateUserProfile({
    String? name,
    String? phone,
  }) async {
    try {
      _updateState(_state.copyWithLoading(true));
      
      final user = currentUser;
      if (user == null) {
        throw const SupabaseException('No authenticated user found');
      }
      
      final profile = await _repository.updateUserProfile(
        userId: user.id,
        name: name,
        phone: phone,
      );
      
      _updateState(_state.copyWithAuth(
        user: user,
        profile: profile,
      ));
      
      debugPrint('✅ User profile updated successfully');
    } on SupabaseException catch (e) {
      debugPrint('❌ Profile update error: ${e.message}');
      _updateState(_state.copyWithError(e.message));
      rethrow;
    } catch (e) {
      debugPrint('❌ Unexpected profile update error: $e');
      final errorMessage = 'Profile update failed: ${e.toString()}';
      _updateState(_state.copyWithError(errorMessage));
      throw SupabaseException(errorMessage);
    }
  }

  /// Clear error state
  void clearError() {
    if (_state.error != null) {
      _updateState(_state.copyWith(error: null));
    }
  }

  /// Refresh/reinitialize auth service (used after onboarding completion)
  Future<void> initialize() async {
    final user = _repository.getCurrentUser();
    if (user != null) {
      await _bootstrapUserProfile(user);
    }
  }

  /// Update internal state and notify listeners
  void _updateState(AuthState newState) {
    _state = newState;
    notifyListeners();
    
    debugPrint('🔄 Auth state updated: '
        'authenticated=${newState.isAuthenticated}, '
        'hasProfile=${newState.hasCompleteProfile}, '
        'loading=${newState.isLoading}, '
        'error=${newState.error}');
  }

  @override
  void dispose() {
    debugPrint('🔄 Disposing auth service');
    _authSubscription?.cancel();
    super.dispose();
  }
}

/// Extension to provide convenience methods for auth state checks
extension AuthServiceExtensions on AuthService {
  /// Check if user can access admin features
  bool canAccessAdminFeatures() {
    return isAuthenticated && hasCompleteProfile && isAdmin;
  }

  /// Check if user can create requests
  bool canCreateRequests() {
    return isAuthenticated && hasCompleteProfile;
  }

  /// Check if user can manage facilities
  bool canManageFacilities() {
    return isAuthenticated && hasCompleteProfile && isAdmin;
  }

  /// Check if user can manage contracts
  bool canManageContracts() {
    return isAuthenticated && hasCompleteProfile && isAdmin;
  }

  /// Check if user can view invoices
  bool canViewInvoices() {
    return isAuthenticated && hasCompleteProfile;
  }

  /// Check if user can manage invoices
  bool canManageInvoices() {
    return isAuthenticated && hasCompleteProfile && isAdmin;
  }
}