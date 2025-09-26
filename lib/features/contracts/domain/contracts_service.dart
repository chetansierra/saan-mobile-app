import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/auth_service.dart';
import '../../onboarding/domain/models/company.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../data/contracts_repository.dart';
import 'contract.dart';

/// Provider for ContractsService
final contractsServiceProvider = ChangeNotifierProvider<ContractsService>((ref) {
  return ContractsService._(ref.watch(authServiceProvider));
});

/// Service for managing contracts state and operations
class ContractsService extends ChangeNotifier {
  ContractsService._(this._authService);

  final AuthService _authService;
  final ContractsRepository _repository = ContractsRepository.instance;
  final OnboardingRepository _onboardingRepository = OnboardingRepository.instance;

  ContractsState _state = const ContractsState();

  /// Current contracts state
  ContractsState get state => _state;

  /// Current contracts list
  List<Contract> get contracts => _state.contracts;

  /// Whether currently loading
  bool get isLoading => _state.isLoading;

  /// Error message
  String? get error => _state.error;

  /// Current tenant ID
  String? get _tenantId => _authService.tenantId;

  /// Initialize service
  Future<void> initialize() async {
    if (_tenantId == null) {
      _updateState(_state.copyWithError('No tenant context available'));
      return;
    }

    await refreshContracts();
  }

  /// Refresh contracts list
  Future<void> refreshContracts() async {
    try {
      _updateState(_state.copyWithLoading(true));
      
      final tenantId = _tenantId;
      if (tenantId == null) {
        throw Exception('No tenant context available');
      }

      final contracts = await _repository.listContracts(tenantId: tenantId);
      
      _updateState(_state.copyWith(
        contracts: contracts,
        isLoading: false,
        error: null,
      ));

      debugPrint('✅ Contracts refreshed: ${contracts.length} found');
    } catch (e) {
      debugPrint('❌ Failed to refresh contracts: $e');
      _updateState(_state.copyWithError(e.toString()));
    }
  }

  /// Create new contract
  Future<Contract> createContract(ContractInput input) async {
    try {
      final tenantId = _tenantId;
      if (tenantId == null) {
        throw Exception('No tenant context available');
      }

      debugPrint('📝 Creating new contract: ${input.title}');
      _updateState(_state.copyWithLoading(true));

      final contract = input.toContract(tenantId: tenantId);
      final createdContract = await _repository.createContract(contract);

      // Map facilities to contract
      if (input.facilityIds.isNotEmpty) {
        await _repository.mapFacilities(
          contractId: createdContract.id!,
          facilityIds: input.facilityIds,
        );
      }

      // Add to current list
      final updatedContracts = [createdContract, ..._state.contracts];
      _updateState(_state.copyWith(
        contracts: updatedContracts,
        isLoading: false,
        error: null,
      ));

      debugPrint('✅ Contract created successfully');
      return createdContract;
    } catch (e) {
      debugPrint('❌ Failed to create contract: $e');
      _updateState(_state.copyWithError(e.toString()));
      rethrow;
    }
  }

  /// Get single contract with details
  Future<Contract> getContract(String contractId) async {
    try {
      return await _repository.getContract(contractId);
    } catch (e) {
      debugPrint('❌ Failed to get contract: $e');
      rethrow;
    }
  }

  /// Get contract with facility details
  Future<ContractWithFacilities> getContractWithFacilities(String contractId) async {
    try {
      return await _repository.getContractWithFacilities(contractId);
    } catch (e) {
      debugPrint('❌ Failed to get contract with facilities: $e');
      rethrow;
    }
  }

  /// Update contract facilities mapping
  Future<void> updateContractFacilities({
    required String contractId,
    required List<String> facilityIds,
  }) async {
    try {
      debugPrint('🔗 Updating contract facilities mapping');
      
      await _repository.mapFacilities(
        contractId: contractId,
        facilityIds: facilityIds,
      );

      // Update contract in current list
      final updatedContracts = _state.contracts.map((contract) {
        if (contract.id == contractId) {
          return contract.copyWith(facilityIds: facilityIds);
        }
        return contract;
      }).toList();

      _updateState(_state.copyWith(contracts: updatedContracts));
      
      debugPrint('✅ Contract facilities updated successfully');
    } catch (e) {
      debugPrint('❌ Failed to update contract facilities: $e');
      rethrow;
    }
  }

  /// Upload contract document
  Future<Uri> uploadContractDocument({
    required String contractId,
    required String filename,
    required List<int> bytes,
  }) async {
    try {
      debugPrint('📤 Uploading contract document: $filename');
      
      final uri = await _repository.uploadContractDoc(
        contractId: contractId,
        filename: filename,
        bytes: bytes,
      );

      // Refresh to get updated document paths
      await refreshContracts();
      
      debugPrint('✅ Contract document uploaded successfully');
      return uri;
    } catch (e) {
      debugPrint('❌ Failed to upload contract document: $e');
      rethrow;
    }
  }

  /// Get available facilities for contract creation
  Future<List<Facility>> getFacilities() async {
    try {
      final tenantId = _tenantId;
      if (tenantId == null) {
        throw Exception('No tenant context available');
      }

      return await _onboardingRepository.getFacilities(tenantId);
    } catch (e) {
      debugPrint('❌ Failed to get facilities: $e');
      rethrow;
    }
  }

  /// Update contract status (activate/deactivate)
  Future<void> updateContractStatus({
    required String contractId,
    required bool isActive,
  }) async {
    try {
      debugPrint('📝 Updating contract status: $contractId -> ${isActive ? 'active' : 'inactive'}');
      
      await _repository.updateContract(
        contractId: contractId,
        updates: {'is_active': isActive},
      );

      // Update in current list
      final updatedContracts = _state.contracts.map((contract) {
        if (contract.id == contractId) {
          return contract.copyWith(isActive: isActive);
        }
        return contract;
      }).toList();

      _updateState(_state.copyWith(contracts: updatedContracts));
      
      debugPrint('✅ Contract status updated successfully');
    } catch (e) {
      debugPrint('❌ Failed to update contract status: $e');
      rethrow;
    }
  }

  /// Get expiring contracts
  Future<List<Contract>> getExpiringContracts({int daysAhead = 30}) async {
    try {
      final tenantId = _tenantId;
      if (tenantId == null) {
        throw Exception('No tenant context available');
      }

      return await _repository.getExpiringContracts(
        tenantId: tenantId,
        daysAhead: daysAhead,
      );
    } catch (e) {
      debugPrint('❌ Failed to get expiring contracts: $e');
      rethrow;
    }
  }

  /// Get active contracts for facility (for SLA derivation)
  Future<List<Contract>> getActiveContractsForFacility({
    required String facilityId,
    DateTime? asOf,
  }) async {
    try {
      return await _repository.activeContractsForFacility(
        facilityId: facilityId,
        asOf: asOf,
      );
    } catch (e) {
      debugPrint('❌ Failed to get active contracts for facility: $e');
      rethrow;
    }
  }

  /// Delete contract (soft delete)
  Future<void> deleteContract(String contractId) async {
    try {
      debugPrint('🗑️ Deleting contract: $contractId');
      
      await _repository.deleteContract(contractId);

      // Remove from current list
      final updatedContracts = _state.contracts
          .where((contract) => contract.id != contractId)
          .toList();

      _updateState(_state.copyWith(contracts: updatedContracts));
      
      debugPrint('✅ Contract deleted successfully');
    } catch (e) {
      debugPrint('❌ Failed to delete contract: $e');
      rethrow;
    }
  }

  /// Get contracts summary for dashboard
  Future<ContractsSummary> getContractsSummary() async {
    try {
      final tenantId = _tenantId;
      if (tenantId == null) {
        throw Exception('No tenant context available');
      }

      final allContracts = await _repository.listContracts(tenantId: tenantId);
      final expiringContracts = await _repository.getExpiringContracts(
        tenantId: tenantId,
        daysAhead: 30,
      );

      final activeContracts = allContracts.where((c) => c.isCurrentlyActive).length;
      final inactiveContracts = allContracts.where((c) => !c.isCurrentlyActive).length;

      return ContractsSummary(
        totalContracts: allContracts.length,
        activeContracts: activeContracts,
        inactiveContracts: inactiveContracts,
        expiringContracts: expiringContracts.length,
        expiringContractsList: expiringContracts,
      );
    } catch (e) {
      debugPrint('❌ Failed to get contracts summary: $e');
      rethrow;
    }
  }

  /// Validate contract input
  List<String> validateContractInput(ContractInput input) {
    final errors = <String>[];

    // Basic validation
    if (input.title.trim().isEmpty) {
      errors.add('Contract title is required');
    }

    if (input.serviceType.trim().isEmpty) {
      errors.add('Service type is required');
    }

    if (input.endDate.isBefore(input.startDate)) {
      errors.add('End date must be after start date');
    }

    if (input.startDate.isBefore(DateTime.now().subtract(const Duration(days: 1)))) {
      errors.add('Start date cannot be in the past');
    }

    // Validate contract duration (should be reasonable)
    final duration = input.endDate.difference(input.startDate);
    if (duration.inDays < 30) {
      errors.add('Contract duration should be at least 30 days');
    } else if (duration.inDays > 365 * 5) {
      errors.add('Contract duration should not exceed 5 years');
    }

    // Validate SLA durations
    if (input.criticalSlaDuration != null) {
      final hours = input.criticalSlaDuration!.inHours;
      if (hours < 1) {
        errors.add('Critical SLA must be at least 1 hour');
      } else if (hours > 72) {
        errors.add('Critical SLA should not exceed 72 hours');
      }
    }

    if (input.standardSlaDuration != null) {
      final hours = input.standardSlaDuration!.inHours;
      if (hours < 1) {
        errors.add('Standard SLA must be at least 1 hour');
      } else if (hours > 168) {
        errors.add('Standard SLA should not exceed 168 hours');
      }

      // Standard should be longer than critical
      if (input.criticalSlaDuration != null &&
          input.standardSlaDuration!.inHours <= input.criticalSlaDuration!.inHours) {
        errors.add('Standard SLA should be longer than Critical SLA');
      }
    }

    // Validate facilities
    if (input.facilityIds.isEmpty) {
      errors.add('At least one facility must be selected');
    }

    return errors;
  }

  /// Clear error state
  void clearError() {
    if (_state.error != null) {
      _updateState(_state.copyWith(error: null));
    }
  }

  /// Update internal state and notify listeners
  void _updateState(ContractsState newState) {
    _state = newState;
    notifyListeners();
  }
}

/// Contracts state model
class ContractsState {
  const ContractsState({
    this.contracts = const [],
    this.isLoading = false,
    this.error,
  });

  final List<Contract> contracts;
  final bool isLoading;
  final String? error;

  /// Create copy with updated fields
  ContractsState copyWith({
    List<Contract>? contracts,
    bool? isLoading,
    String? error,
  }) {
    return ContractsState(
      contracts: contracts ?? this.contracts,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  /// Create loading state
  ContractsState copyWithLoading(bool loading) {
    return copyWith(isLoading: loading, error: null);
  }

  /// Create error state
  ContractsState copyWithError(String errorMessage) {
    return copyWith(isLoading: false, error: errorMessage);
  }
}

/// Contracts summary model for dashboard
class ContractsSummary {
  const ContractsSummary({
    required this.totalContracts,
    required this.activeContracts,
    required this.inactiveContracts,
    required this.expiringContracts,
    required this.expiringContractsList,
  });

  final int totalContracts;
  final int activeContracts;
  final int inactiveContracts;
  final int expiringContracts;
  final List<Contract> expiringContractsList;
}