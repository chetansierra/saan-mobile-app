import 'package:flutter/foundation.dart';

import '../../contracts/domain/contract.dart';
import '../../requests/domain/models/request.dart';
import '../data/pm_repository.dart';
import '../../contracts/data/contracts_repository.dart';

/// SLA derivation utilities for request priority handling
class SlaRules {
  SlaRules._();

  /// Static instance for utility methods
  static final SlaRules _instance = SlaRules._();
  static SlaRules get instance => _instance;

  /// Default SLA durations when no contract coverage
  static const Duration _defaultCriticalSla = Duration(hours: 6);
  static const Duration? _defaultStandardSla = null; // No SLA for standard

  /// Derive SLA duration for a request based on contracts and priority
  /// 
  /// Resolution logic:
  /// 1. Find all active contracts covering the facility
  /// 2. Filter by service_type if request has a matching category
  /// 3. Apply tie-breaking rules:
  ///    - Highest precedence (int)
  ///    - Latest start_date (most recent)
  ///    - Lowest id (final tie-break)
  /// 4. Return contract SLA or fallback to default
  static Future<Duration?> deriveSlaForRequest({
    required String facilityId,
    required RequestPriority priority,
    String? serviceType,
    DateTime? asOf,
  }) async {
    try {
      debugPrint('🔍 Deriving SLA for facility: $facilityId, priority: ${priority.displayName}');
      
      final effectiveDate = asOf ?? DateTime.now();
      
      // Get all active contracts for the facility
      final contracts = await ContractsRepository.instance.activeContractsForFacility(
        facilityId: facilityId,
        asOf: effectiveDate,
      );
      
      if (contracts.isEmpty) {
        debugPrint('📋 No active contracts found, using default SLA');
        return _getDefaultSla(priority);
      }
      
      debugPrint('📋 Found ${contracts.length} active contracts for facility');
      
      // Filter by service type if provided and matching
      List<Contract> candidateContracts = contracts;
      if (serviceType != null && serviceType.isNotEmpty) {
        final matchingServiceContracts = contracts
            .where((contract) => contract.serviceType.toLowerCase() == serviceType.toLowerCase())
            .toList();
        
        if (matchingServiceContracts.isNotEmpty) {
          candidateContracts = matchingServiceContracts;
          debugPrint('📋 Filtered to ${candidateContracts.length} contracts matching service type: $serviceType');
        }
      }
      
      // Apply tie-breaking rules to select the winning contract
      final selectedContract = _selectWinningContract(candidateContracts);
      
      if (selectedContract != null) {
        final contractSla = selectedContract.getSlaForPriority(priority);
        if (contractSla != null) {
          debugPrint('✅ Using contract SLA: ${contractSla.inHours}h from contract: ${selectedContract.title}');
          return contractSla;
        }
      }
      
      debugPrint('📋 No matching contract SLA found, using default');
      return _getDefaultSla(priority);
      
    } catch (e) {
      debugPrint('❌ Error deriving SLA: $e');
      // Fallback to default SLA on any error
      return _getDefaultSla(priority);
    }
  }

  /// Select winning contract based on tie-breaking rules
  static Contract? _selectWinningContract(List<Contract> contracts) {
    if (contracts.isEmpty) return null;
    if (contracts.length == 1) return contracts.first;
    
    // Sort by tie-breaking criteria:
    // 1. Highest precedence (descending)
    // 2. Latest start_date (descending) 
    // 3. Lowest id (ascending) - final tie-break
    contracts.sort((a, b) {
      // 1. Compare precedence (higher wins)
      final precedenceComparison = b.precedence.compareTo(a.precedence);
      if (precedenceComparison != 0) return precedenceComparison;
      
      // 2. Compare start_date (later wins)
      final dateComparison = b.startDate.compareTo(a.startDate);
      if (dateComparison != 0) return dateComparison;
      
      // 3. Compare id (lower wins) - final tie-break
      final aId = a.id ?? '';
      final bId = b.id ?? '';
      return aId.compareTo(bId);
    });
    
    final winner = contracts.first;
    debugPrint('🏆 Contract selection winner: ${winner.title} (precedence: ${winner.precedence}, start: ${winner.startDate})');
    
    return winner;
  }

  /// Get default SLA duration based on priority
  static Duration? _getDefaultSla(RequestPriority priority) {
    switch (priority) {
      case RequestPriority.critical:
        return _defaultCriticalSla;
      case RequestPriority.standard:
        return _defaultStandardSla;
    }
  }

  /// Check if a request would have SLA coverage
  static Future<bool> hasSlaOverride({
    required String facilityId,
    required RequestPriority priority,
    String? serviceType,
    DateTime? asOf,
  }) async {
    final sla = await deriveSlaForRequest(
      facilityId: facilityId,
      priority: priority,
      serviceType: serviceType,
      asOf: asOf,
    );
    
    final defaultSla = _getDefaultSla(priority);
    
    // Has override if derived SLA differs from default
    return sla != defaultSla;
  }

  /// Get SLA summary for a facility
  static Future<FacilitySlaInfo> getFacilitySlaInfo({
    required String facilityId,
    DateTime? asOf,
  }) async {
    try {
      final effectiveDate = asOf ?? DateTime.now();
      
      final contracts = await ContractsRepository.instance.activeContractsForFacility(
        facilityId: facilityId,
        asOf: effectiveDate,
      );
      
      Duration? criticalSla;
      Duration? standardSla;
      String? coveringContractTitle;
      
      if (contracts.isNotEmpty) {
        final selectedContract = _selectWinningContract(contracts);
        if (selectedContract != null) {
          criticalSla = selectedContract.getSlaForPriority(RequestPriority.critical);
          standardSla = selectedContract.getSlaForPriority(RequestPriority.standard);
          coveringContractTitle = selectedContract.title;
        }
      }
      
      // Use defaults if no contract coverage
      criticalSla ??= _defaultCriticalSla;
      standardSla ??= _defaultStandardSla;
      
      return FacilitySlaInfo(
        facilityId: facilityId,
        criticalSla: criticalSla,
        standardSla: standardSla,
        hasContractCoverage: contracts.isNotEmpty,
        coveringContractTitle: coveringContractTitle,
        activeContractsCount: contracts.length,
      );
      
    } catch (e) {
      debugPrint('❌ Error getting facility SLA info: $e');
      return FacilitySlaInfo(
        facilityId: facilityId,
        criticalSla: _defaultCriticalSla,
        standardSla: _defaultStandardSla,
        hasContractCoverage: false,
        coveringContractTitle: null,
        activeContractsCount: 0,
      );
    }
  }

  /// Validate contract SLA configuration
  static List<String> validateContractSla(Contract contract) {
    final errors = <String>[];
    
    // Check if contract has any SLA defined
    if (contract.criticalSlaDuration == null && contract.standardSlaDuration == null) {
      errors.add('Contract has no SLA durations defined');
    }
    
    // Validate critical SLA (should be reasonable range)
    if (contract.criticalSlaDuration != null) {
      final hours = contract.criticalSlaDuration!.inHours;
      if (hours < 1) {
        errors.add('Critical SLA must be at least 1 hour');
      } else if (hours > 72) {
        errors.add('Critical SLA should not exceed 72 hours');
      }
    }
    
    // Validate standard SLA if defined
    if (contract.standardSlaDuration != null) {
      final hours = contract.standardSlaDuration!.inHours;
      if (hours < 1) {
        errors.add('Standard SLA must be at least 1 hour');
      } else if (hours > 168) { // 1 week
        errors.add('Standard SLA should not exceed 168 hours (1 week)');
      }
    }
    
    // Check if standard SLA is longer than critical (should be)
    if (contract.criticalSlaDuration != null && contract.standardSlaDuration != null) {
      if (contract.standardSlaDuration!.inHours <= contract.criticalSlaDuration!.inHours) {
        errors.add('Standard SLA should be longer than Critical SLA');
      }
    }
    
    return errors;
  }
}

/// Facility SLA information summary
class FacilitySlaInfo {
  const FacilitySlaInfo({
    required this.facilityId,
    required this.criticalSla,
    required this.standardSla,
    required this.hasContractCoverage,
    required this.coveringContractTitle,
    required this.activeContractsCount,
  });

  final String facilityId;
  final Duration? criticalSla;
  final Duration? standardSla;
  final bool hasContractCoverage;
  final String? coveringContractTitle;
  final int activeContractsCount;

  /// Get SLA display text for UI
  String getSlaDisplayText(RequestPriority priority) {
    final sla = priority == RequestPriority.critical ? criticalSla : standardSla;
    
    if (sla == null) {
      return 'No SLA';
    }
    
    final hours = sla.inHours;
    if (hours < 24) {
      return '${hours}h';
    } else {
      final days = (hours / 24).floor();
      final remainingHours = hours % 24;
      if (remainingHours == 0) {
        return '${days}d';
      } else {
        return '${days}d ${remainingHours}h';
      }
    }
  }

  /// Get coverage status text
  String get coverageStatusText {
    if (!hasContractCoverage) {
      return 'Default SLA (No Contract)';
    } else if (coveringContractTitle != null) {
      return 'Contract: $coveringContractTitle';
    } else {
      return 'Contract Coverage ($activeContractsCount active)';
    }
  }
}