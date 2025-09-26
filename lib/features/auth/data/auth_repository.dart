import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/client.dart';
import '../domain/models/user_profile.dart';

/// Repository for authentication and user profile operations
class AuthRepository {
  AuthRepository._();

  /// Singleton instance
  static final AuthRepository _instance = AuthRepository._();
  static AuthRepository get instance => _instance;

  /// Supabase client reference
  SupabaseClient get _client => SupabaseService.client;

  /// Auth client reference
  GoTrueClient get _auth => SupabaseService.auth;

  /// Sign in with email and password
  Future<AuthResponse> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('🔐 Attempting sign in for: $email');
      
      final response = await _auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      if (response.user != null) {
        debugPrint('✅ Sign in successful for: $email');
      }

      return response;
    } on AuthException catch (e) {
      debugPrint('❌ Sign in failed: ${e.message}');
      throw e.toSupabaseException();
    } catch (e) {
      debugPrint('❌ Unexpected sign in error: $e');
      throw SupabaseException('Sign in failed: ${e.toString()}');
    }
  }

  /// Sign up with email and password
  Future<AuthResponse> signUpWithEmailPassword({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      debugPrint('📝 Attempting sign up for: $email');
      
      final response = await _auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'name': name.trim(),
        },
      );

      if (response.user != null) {
        debugPrint('✅ Sign up successful for: $email');
      }

      return response;
    } on AuthException catch (e) {
      debugPrint('❌ Sign up failed: ${e.message}');
      throw e.toSupabaseException();
    } catch (e) {
      debugPrint('❌ Unexpected sign up error: $e');
      throw SupabaseException('Sign up failed: ${e.toString()}');
    }
  }

  /// Sign out current user
  Future<void> signOut() async {
    try {
      debugPrint('🚪 Signing out user');
      await _auth.signOut();
      debugPrint('✅ Sign out successful');
    } on AuthException catch (e) {
      debugPrint('❌ Sign out failed: ${e.message}');
      throw e.toSupabaseException();
    } catch (e) {
      debugPrint('❌ Unexpected sign out error: $e');
      throw SupabaseException('Sign out failed: ${e.toString()}');
    }
  }

  /// Resend email confirmation
  Future<void> resendEmailConfirmation({required String email}) async {
    try {
      debugPrint('📧 Resending email confirmation for: $email');
      
      await _auth.resend(
        type: OtpType.signup,
        email: email.trim(),
      );
      
      debugPrint('✅ Email confirmation resent successfully');
    } on AuthException catch (e) {
      debugPrint('❌ Resend email failed: ${e.message}');
      throw e.toSupabaseException();
    } catch (e) {
      debugPrint('❌ Unexpected resend email error: $e');
      throw SupabaseException('Resend email failed: ${e.toString()}');
    }
  }

  /// Reset password
  Future<void> resetPassword({required String email}) async {
    try {
      debugPrint('🔑 Sending password reset for: $email');
      
      await _auth.resetPasswordForEmail(email.trim());
      
      debugPrint('✅ Password reset email sent successfully');
    } on AuthException catch (e) {
      debugPrint('❌ Password reset failed: ${e.message}');
      throw e.toSupabaseException();
    } catch (e) {
      debugPrint('❌ Unexpected password reset error: $e');
      throw SupabaseException('Password reset failed: ${e.toString()}');
    }
  }

  /// Get current user
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  /// Get current session
  Session? getCurrentSession() {
    return _auth.currentSession;
  }

  /// Stream of auth state changes
  Stream<AuthState> get authStateStream {
    return _auth.onAuthStateChange.map((state) {
      debugPrint('🔄 Auth state changed: ${state.event}');
      
      return AuthState(
        isAuthenticated: state.session != null,
        user: state.session?.user,
      );
    });
  }

  /// Fetch user profile from database
  Future<UserProfile?> fetchUserProfile(String userId) async {
    try {
      debugPrint('👤 Fetching profile for user: $userId');
      
      final response = await _client
          .from(SupabaseTables.profiles)
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        debugPrint('⚠️ No profile found for user: $userId');
        return null;
      }

      final profile = UserProfile.fromJson(response);
      debugPrint('✅ Profile fetched successfully: ${profile.name} (${profile.role.displayName})');
      
      return profile;
    } on PostgrestException catch (e) {
      debugPrint('❌ Failed to fetch profile: ${e.message}');
      throw e.toSupabaseException();
    } catch (e) {
      debugPrint('❌ Unexpected error fetching profile: $e');
      throw SupabaseException('Failed to fetch profile: ${e.toString()}');
    }
  }

  /// Create user profile in database
  Future<UserProfile> createUserProfile({
    required String userId,
    required String tenantId,
    required String email,
    required String name,
    required UserRole role,
    String? phone,
  }) async {
    try {
      debugPrint('📝 Creating profile for user: $userId');
      
      final profileData = {
        'user_id': userId,
        'tenant_id': tenantId,
        'email': email.trim(),
        'name': name.trim(),
        'role': role.value,
        'phone': phone?.trim(),
        'created_at': DateTime.now().toIso8601String(),
      };

      final response = await _client
          .from(SupabaseTables.profiles)
          .insert(profileData)
          .select()
          .single();

      final profile = UserProfile.fromJson(response);
      debugPrint('✅ Profile created successfully: ${profile.name}');
      
      return profile;
    } on PostgrestException catch (e) {
      debugPrint('❌ Failed to create profile: ${e.message}');
      throw e.toSupabaseException();
    } catch (e) {
      debugPrint('❌ Unexpected error creating profile: $e');
      throw SupabaseException('Failed to create profile: ${e.toString()}');
    }
  }

  /// Update user profile
  Future<UserProfile> updateUserProfile({
    required String userId,
    String? name,
    String? phone,
  }) async {
    try {
      debugPrint('📝 Updating profile for user: $userId');
      
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name.trim();
      if (phone != null) updates['phone'] = phone.trim();

      if (updates.isEmpty) {
        throw const SupabaseException('No updates provided');
      }

      final response = await _client
          .from(SupabaseTables.profiles)
          .update(updates)
          .eq('user_id', userId)
          .select()
          .single();

      final profile = UserProfile.fromJson(response);
      debugPrint('✅ Profile updated successfully: ${profile.name}');
      
      return profile;
    } on PostgrestException catch (e) {
      debugPrint('❌ Failed to update profile: ${e.message}');
      throw e.toSupabaseException();
    } catch (e) {
      debugPrint('❌ Unexpected error updating profile: $e');
      throw SupabaseException('Failed to update profile: ${e.toString()}');
    }
  }

  /// Delete user profile (for cleanup)
  Future<void> deleteUserProfile(String userId) async {
    try {
      debugPrint('🗑️ Deleting profile for user: $userId');
      
      await _client
          .from(SupabaseTables.profiles)
          .delete()
          .eq('user_id', userId);

      debugPrint('✅ Profile deleted successfully');
    } on PostgrestException catch (e) {
      debugPrint('❌ Failed to delete profile: ${e.message}');
      throw e.toSupabaseException();
    } catch (e) {
      debugPrint('❌ Unexpected error deleting profile: $e');
      throw SupabaseException('Failed to delete profile: ${e.toString()}');
    }
  }

  /// Check if email is available for registration
  Future<bool> isEmailAvailable(String email) async {
    try {
      debugPrint('📧 Checking email availability: $email');
      
      final response = await _client
          .from(SupabaseTables.profiles)
          .select('email')
          .eq('email', email.trim())
          .maybeSingle();

      final isAvailable = response == null;
      debugPrint('✅ Email availability check: $isAvailable');
      
      return isAvailable;
    } on PostgrestException catch (e) {
      debugPrint('❌ Failed to check email availability: ${e.message}');
      throw e.toSupabaseException();
    } catch (e) {
      debugPrint('❌ Unexpected error checking email: $e');
      throw SupabaseException('Failed to check email availability: ${e.toString()}');
    }
  }
}