import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/auth_service.dart';
import '../../auth/domain/models/user_profile.dart';
import '../data/onboarding_repository.dart';
import 'models/company.dart';

/// Provider for OnboardingService
final onboardingServiceProvider = ChangeNotifierProvider<OnboardingService>((ref) {
  return OnboardingService._(ref.watch(authServiceProvider));
});

/// Onboarding service that manages the company and facility setup flow
class OnboardingService extends ChangeNotifier {
  OnboardingService._(this._authService);

  final AuthService _authService;
  final OnboardingRepository _repository = OnboardingRepository.instance;
  
  OnboardingState _state = const OnboardingState();

  /// Current onboarding state
  OnboardingState get state => _state;

  /// Current step
  OnboardingStep get currentStep => _state.currentStep;

  /// Company data
  Company? get company => _state.company;

  /// Facilities list
  List<Facility> get facilities => _state.facilities;

  /// Whether onboarding is completed
  bool get isCompleted => _state.isOnboardingCompleted;

  /// Whether loading
  bool get isLoading => _state.isLoading;

  /// Error message
  String? get error => _state.error;

  /// Initialize onboarding (load existing data if available)
  Future<void> initialize() async {
    try {
      debugPrint('🔄 Initializing onboarding service');
      
      final currentUser = _authService.currentUser;
      final currentProfile = _authService.currentProfile;
      
      if (currentUser == null) {
        throw const SupabaseException('No authenticated user found');
      }

      // If user has complete profile, load existing data
      if (currentProfile != null) {
        debugPrint('👤 Loading existing company and facilities data');
        
        _updateState(_state.copyWithLoading(true));
        
        // Load company data
        final company = await _repository.getTenant(currentProfile.tenantId);
        
        // Load facilities
        final facilities = await _repository.getFacilities(currentProfile.tenantId);
        
        _updateState(_state.copyWith(
          company: company,
          facilities: facilities,
          isLoading: false,
        ));
        
        debugPrint('✅ Existing data loaded successfully');
      } else {
        debugPrint('👤 New user - starting fresh onboarding');
        _updateState(const OnboardingState());
      }
    } catch (e) {
      debugPrint('❌ Failed to initialize onboarding: $e');
      _updateState(_state.copyWithError(e.toString()));
    }
  }

  /// Set company data (step 1)
  void setCompany(Company company) {
    debugPrint('🏢 Setting company data: ${company.name}');
    _updateState(_state.copyWith(company: company));
  }

  /// Save company data to database
  Future<void> saveCompany(Company company) async {
    try {
      debugPrint('💾 Saving company data: ${company.name}');
      _updateState(_state.copyWithLoading(true));
      
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        throw const SupabaseException('No authenticated user found');
      }

      // Create tenant in database
      final tenantId = await _repository.createTenant(company);
      
      // Create user profile with tenant association
      await _authService.createUserProfile(
        tenantId: tenantId,
        email: currentUser.email!,
        name: currentUser.userMetadata?['name'] ?? 'User',
        role: UserRole.admin, // First user becomes admin
        phone: null,
      );
      
      _updateState(_state.copyWith(
        company: company,
        isLoading: false,
      ));
      
      debugPrint('✅ Company data saved successfully');
    } catch (e) {
      debugPrint('❌ Failed to save company: $e');
      _updateState(_state.copyWithError(e.toString()));
      rethrow;
    }
  }

  /// Add facility to the list (step 2)
  void addFacility(Facility facility) {
    debugPrint('🏭 Adding facility: ${facility.name}');
    
    final updatedFacilities = List<Facility>.from(_state.facilities)
      ..add(facility);
      
    _updateState(_state.copyWith(facilities: updatedFacilities));
  }

  /// Save facility to database
  Future<void> saveFacility(Facility facility) async {
    try {
      debugPrint('💾 Saving facility: ${facility.name}');
      _updateState(_state.copyWithLoading(true));
      
      final currentProfile = _authService.currentProfile;
      if (currentProfile == null) {
        throw const SupabaseException('No user profile found');
      }

      // Create facility in database
      final facilityId = await _repository.createFacility(
        currentProfile.tenantId,
        facility,
      );
      
      // Update facility with ID and add to list
      final savedFacility = facility.copyWith(
        id: facilityId,
        createdAt: DateTime.now(),
      );
      
      final updatedFacilities = List<Facility>.from(_state.facilities)
        ..add(savedFacility);
      
      _updateState(_state.copyWith(
        facilities: updatedFacilities,
        isLoading: false,
      ));
      
      debugPrint('✅ Facility saved successfully');
    } catch (e) {
      debugPrint('❌ Failed to save facility: $e');
      _updateState(_state.copyWithError(e.toString()));
      rethrow;
    }
  }

  /// Update existing facility
  Future<void> updateFacility(String facilityId, Facility updatedFacility) async {
    try {
      debugPrint('📝 Updating facility: $facilityId');
      _updateState(_state.copyWithLoading(true));
      
      // Update in database
      await _repository.updateFacility(facilityId, updatedFacility);
      
      // Update in local state
      final facilities = _state.facilities.map((facility) {
        if (facility.id == facilityId) {
          return updatedFacility.copyWith(id: facilityId);
        }
        return facility;
      }).toList();
      
      _updateState(_state.copyWith(
        facilities: facilities,
        isLoading: false,
      ));
      
      debugPrint('✅ Facility updated successfully');
    } catch (e) {
      debugPrint('❌ Failed to update facility: $e');
      _updateState(_state.copyWithError(e.toString()));
      rethrow;
    }
  }

  /// Remove facility from the list
  Future<void> removeFacility(String facilityId) async {
    try {
      debugPrint('🗑️ Removing facility: $facilityId');
      _updateState(_state.copyWithLoading(true));
      
      // Delete from database
      await _repository.deleteFacility(facilityId);
      
      // Remove from local state
      final updatedFacilities = _state.facilities
          .where((facility) => facility.id != facilityId)
          .toList();
      
      _updateState(_state.copyWith(
        facilities: updatedFacilities,
        isLoading: false,
      ));
      
      debugPrint('✅ Facility removed successfully');
    } catch (e) {
      debugPrint('❌ Failed to remove facility: $e');
      _updateState(_state.copyWithError(e.toString()));
      rethrow;
    }
  }

  /// Navigate to specific step
  void goToStep(OnboardingStep step) {
    debugPrint('📍 Navigating to step: ${step.displayName}');
    _updateState(_state.copyWith(currentStep: step));
  }

  /// Navigate to next step
  bool goToNextStep() {
    if (!_state.canProceedToNext) {
      debugPrint('⚠️ Cannot proceed to next step - requirements not met');
      return false;
    }
    
    final nextStep = _state.currentStep.next;
    if (nextStep != null) {
      debugPrint('➡️ Moving to next step: ${nextStep.displayName}');
      _updateState(_state.copyWith(currentStep: nextStep));
      return true;
    }
    
    debugPrint('⚠️ Already at final step');
    return false;
  }

  /// Navigate to previous step
  bool goToPreviousStep() {
    final previousStep = _state.currentStep.previous;
    if (previousStep != null) {
      debugPrint('⬅️ Moving to previous step: ${previousStep.displayName}');
      _updateState(_state.copyWith(currentStep: previousStep));
      return true;
    }
    
    debugPrint('⚠️ Already at first step');
    return false;
  }

  /// Complete onboarding process
  Future<void> completeOnboarding() async {
    try {
      debugPrint('🎉 Completing onboarding process');
      
      if (!_state.isOnboardingCompleted) {
        throw const SupabaseException('Onboarding requirements not met');
      }
      
      _updateState(_state.copyWithLoading(true));
      
      final currentUser = _authService.currentUser;
      final currentProfile = _authService.currentProfile;
      
      if (currentUser == null || currentProfile == null) {
        throw const SupabaseException('Missing user or profile data');
      }
      
      // Validate onboarding completion
      await _repository.completeOnboarding(
        userId: currentUser.id,
        tenantId: currentProfile.tenantId,
        email: currentProfile.email,
        name: currentProfile.name,
        phone: currentProfile.phone,
      );
      
      // Refresh auth service to update navigation
      await _authService.initialize();
      
      debugPrint('✅ Onboarding completed successfully');
    } catch (e) {
      debugPrint('❌ Failed to complete onboarding: $e');
      _updateState(_state.copyWithError(e.toString()));
      rethrow;
    }
  }

  /// Clear error state
  void clearError() {
    if (_state.error != null) {
      _updateState(_state.copyWith(error: null));
    }
  }

  /// Reset onboarding state
  void reset() {
    debugPrint('🔄 Resetting onboarding state');
    _updateState(const OnboardingState());
  }

  /// Update internal state and notify listeners
  void _updateState(OnboardingState newState) {
    _state = newState;
    notifyListeners();
    
    debugPrint('🔄 Onboarding state updated: '
        'step=${newState.currentStep.displayName}, '
        'hasCompany=${newState.isCompanyCompleted}, '
        'facilitiesCount=${newState.facilities.length}, '
        'loading=${newState.isLoading}, '
        'error=${newState.error}');
  }
}

/// Extension to provide convenience methods for onboarding flow
extension OnboardingServiceExtensions on OnboardingService {
  /// Check if user can proceed to facility setup
  bool canProceedToFacilities() {
    return state.isCompanyCompleted;
  }

  /// Check if user can proceed to review
  bool canProceedToReview() {
    return state.isCompanyCompleted && state.isFacilitiesCompleted;
  }

  /// Get onboarding progress percentage (0.0 to 1.0)
  double getProgress() {
    return state.currentStep.progress;
  }

  /// Get step completion status
  bool isStepCompleted(OnboardingStep step) {
    switch (step) {
      case OnboardingStep.company:
        return state.isCompanyCompleted;
      case OnboardingStep.facility:
        return state.isFacilitiesCompleted;
      case OnboardingStep.review:
        return state.isOnboardingCompleted;
    }
  }
}