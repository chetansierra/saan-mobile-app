import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/auth_service.dart';
import '../../contracts/domain/contracts_service.dart';
import '../data/pm_repository.dart';
import 'pm_visit.dart';
import 'pm_checklist.dart';

/// Provider for PMService
final pmServiceProvider = ChangeNotifierProvider<PMService>((ref) {
  return PMService._(
    ref.watch(authServiceProvider),
    ref.watch(contractsServiceProvider),
  );
});

/// Service for managing PM (Preventive Maintenance) operations
class PMService extends ChangeNotifier {
  PMService._(this._authService, this._contractsService);

  final AuthService _authService;
  final ContractsService _contractsService;
  final PMRepository _repository = PMRepository.instance;

  PMState _state = const PMState();

  /// Current PM state
  PMState get state => _state;

  /// Current PM visits list
  List<PMVisit> get visits => _state.visits;

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

    await refreshPMVisits();
  }

  /// Refresh PM visits list
  Future<void> refreshPMVisits() async {
    try {
      _updateState(_state.copyWithLoading(true));
      
      final tenantId = _tenantId;
      if (tenantId == null) {
        throw Exception('No tenant context available');
      }

      final visits = await _repository.listUpcomingPM(tenantId: tenantId);
      
      _updateState(_state.copyWith(
        visits: visits,
        isLoading: false,
        error: null,
      ));

      debugPrint('✅ PM visits refreshed: ${visits.length} found');
    } catch (e) {
      debugPrint('❌ Failed to refresh PM visits: $e');
      _updateState(_state.copyWithError(e.toString()));
    }
  }

  /// Generate 90-day PM schedule for a contract
  Future<List<PMVisit>> generateSchedule90d({required String contractId}) async {
    try {
      debugPrint('📅 Generating 90-day PM schedule for contract: $contractId');
      
      final visits = await _repository.generateSchedule90d(contractId: contractId);
      
      // Refresh visits list to include new ones
      await refreshPMVisits();
      
      debugPrint('✅ Generated ${visits.length} PM visits for next 90 days');
      return visits;
    } catch (e) {
      debugPrint('❌ Failed to generate PM schedule: $e');
      rethrow;
    }
  }

  /// Generate PM schedules for all active contracts
  Future<int> generateSchedulesForAllContracts() async {
    try {
      debugPrint('📅 Generating PM schedules for all active contracts');
      
      final tenantId = _tenantId;
      if (tenantId == null) {
        throw Exception('No tenant context available');
      }

      // Get all active contracts
      final contracts = await _contractsService.refreshContracts().then((_) => 
          _contractsService.contracts.where((c) => c.isCurrentlyActive).toList());
      
      int totalVisitsGenerated = 0;
      
      for (final contract in contracts) {
        if (contract.id != null) {
          final visits = await _repository.generateSchedule90d(contractId: contract.id!);
          totalVisitsGenerated += visits.length;
        }
      }
      
      // Refresh visits list
      await refreshPMVisits();
      
      debugPrint('✅ Generated $totalVisitsGenerated PM visits for ${contracts.length} contracts');
      return totalVisitsGenerated;
    } catch (e) {
      debugPrint('❌ Failed to generate schedules for all contracts: $e');
      rethrow;
    }
  }

  /// Get PM visit by ID
  Future<PMVisit?> getPMVisit(String pmVisitId) async {
    try {
      return await _repository.getPMVisit(pmVisitId);
    } catch (e) {
      debugPrint('❌ Failed to get PM visit: $e');
      rethrow;
    }
  }

  /// Update PM visit status
  Future<PMVisit> updatePMVisitStatus({
    required String pmVisitId,
    required PMVisitStatus status,
    String? engineerName,
    String? notes,
  }) async {
    try {
      debugPrint('📝 Updating PM visit status: $pmVisitId -> ${status.displayName}');
      
      final updatedVisit = await _repository.updatePMVisitStatus(
        pmVisitId: pmVisitId,
        status: status,
        engineerName: engineerName,
        notes: notes,
      );

      // Update in current list
      final updatedVisits = _state.visits.map((visit) {
        return visit.id == pmVisitId ? updatedVisit : visit;
      }).toList();

      _updateState(_state.copyWith(visits: updatedVisits));
      
      debugPrint('✅ PM visit status updated successfully');
      return updatedVisit;
    } catch (e) {
      debugPrint('❌ Failed to update PM visit status: $e');
      rethrow;
    }
  }

  /// Complete PM visit with checklist
  Future<PMVisit> completePMVisit({
    required String pmVisitId,
    required String engineerName,
    required List<PMChecklistItem> checklistItems,
    String? overallNotes,
    String? templateName,
  }) async {
    try {
      debugPrint('✅ Completing PM visit: $pmVisitId');
      
      final tenantId = _tenantId;
      if (tenantId == null) {
        throw Exception('No tenant context available');
      }

      // Create checklist
      final checklist = PMChecklist(
        tenantId: tenantId,
        pmVisitId: pmVisitId,
        templateName: templateName ?? 'Default',
        items: checklistItems,
        overallNotes: overallNotes,
        completedAt: DateTime.now(),
        completedBy: engineerName,
      );

      final completedVisit = await _repository.completePMVisit(
        pmVisitId: pmVisitId,
        checklist: checklist,
      );

      // Update in current list
      final updatedVisits = _state.visits.map((visit) {
        return visit.id == pmVisitId ? completedVisit : visit;
      }).toList();

      _updateState(_state.copyWith(visits: updatedVisits));
      
      debugPrint('✅ PM visit completed successfully');
      return completedVisit;
    } catch (e) {
      debugPrint('❌ Failed to complete PM visit: $e');
      rethrow;
    }
  }

  /// Get PM visits for a facility
  Future<List<PMVisit>> getPMVisitsForFacility({
    required String facilityId,
    PMVisitStatus? status,
    int limit = 20,
  }) async {
    try {
      return await _repository.getPMVisitsForFacility(
        facilityId: facilityId,
        status: status,
        limit: limit,
      );
    } catch (e) {
      debugPrint('❌ Failed to get PM visits for facility: $e');
      rethrow;
    }
  }

  /// Get PM visits summary for dashboard
  Future<PMVisitSummary> getPMVisitsSummary() async {
    try {
      final tenantId = _tenantId;
      if (tenantId == null) {
        throw Exception('No tenant context available');
      }

      return await _repository.getPMVisitsSummary(tenantId: tenantId);
    } catch (e) {
      debugPrint('❌ Failed to get PM visits summary: $e');
      rethrow;
    }
  }

  /// Get checklist for PM visit
  Future<PMChecklist?> getPMChecklist(String pmVisitId) async {
    try {
      return await _repository.getPMChecklist(pmVisitId);
    } catch (e) {
      debugPrint('❌ Failed to get PM checklist: $e');
      rethrow;
    }
  }

  /// Create checklist template for PM visit
  Future<PMChecklist> createChecklistForVisit({
    required String pmVisitId,
    required String serviceType,
    String? templateName,
  }) async {
    try {
      final tenantId = _tenantId;
      if (tenantId == null) {
        throw Exception('No tenant context available');
      }

      // Get template items based on service type
      final templateItems = PMChecklistTemplate.getTemplateByType(serviceType);
      
      final checklist = PMChecklist(
        tenantId: tenantId,
        pmVisitId: pmVisitId,
        templateName: templateName ?? '${serviceType.toUpperCase()} Maintenance',
        items: templateItems,
      );

      debugPrint('✅ Created checklist template with ${templateItems.length} items');
      return checklist;
    } catch (e) {
      debugPrint('❌ Failed to create checklist template: $e');
      rethrow;
    }
  }

  /// Upload PM visit attachment
  Future<String> uploadPMAttachment({
    required String pmVisitId,
    required String filename,
    required List<int> bytes,
  }) async {
    try {
      final tenantId = _tenantId;
      if (tenantId == null) {
        throw Exception('No tenant context available');
      }

      return await _repository.uploadPMAttachment(
        tenantId: tenantId,
        pmVisitId: pmVisitId,
        filename: filename,
        bytes: bytes,
      );
    } catch (e) {
      debugPrint('❌ Failed to upload PM attachment: $e');
      rethrow;
    }
  }

  /// Cancel PM visit
  Future<void> cancelPMVisit(String pmVisitId) async {
    try {
      debugPrint('❌ Cancelling PM visit: $pmVisitId');
      
      await _repository.cancelPMVisit(pmVisitId);

      // Update in current list
      final updatedVisits = _state.visits.map((visit) {
        if (visit.id == pmVisitId) {
          return visit.copyWith(status: PMVisitStatus.cancelled);
        }
        return visit;
      }).toList();

      _updateState(_state.copyWith(visits: updatedVisits));
      
      debugPrint('✅ PM visit cancelled successfully');
    } catch (e) {
      debugPrint('❌ Failed to cancel PM visit: $e');
      rethrow;
    }
  }

  /// Get overdue PM visits
  Future<List<PMVisit>> getOverduePMVisits() async {
    try {
      final tenantId = _tenantId;
      if (tenantId == null) {
        throw Exception('No tenant context available');
      }

      final allVisits = await _repository.listUpcomingPM(
        tenantId: tenantId,
        until: DateTime.now(),
      );

      return allVisits.where((visit) => visit.isOverdue).toList();
    } catch (e) {
      debugPrint('❌ Failed to get overdue PM visits: $e');
      rethrow;
    }
  }

  /// Get PM visits due today
  Future<List<PMVisit>> getPMVisitsDueToday() async {
    try {
      final tenantId = _tenantId;
      if (tenantId == null) {
        throw Exception('No tenant context available');
      }

      final today = DateTime.now();
      final tomorrow = today.add(const Duration(days: 1));

      final todayVisits = await _repository.listUpcomingPM(
        tenantId: tenantId,
        until: tomorrow,
      );

      return todayVisits.where((visit) => visit.isDueToday).toList();
    } catch (e) {
      debugPrint('❌ Failed to get PM visits due today: $e');
      rethrow;
    }
  }

  /// Validate PM visit completion
  List<String> validatePMCompletion({
    required List<PMChecklistItem> checklistItems,
    required String engineerName,
  }) {
    final errors = <String>[];

    // Validate engineer name
    if (engineerName.trim().isEmpty) {
      errors.add('Engineer name is required');
    }

    // Validate checklist completion
    if (checklistItems.isEmpty) {
      errors.add('Checklist cannot be empty');
    }

    final incompleteItems = checklistItems.where((item) => !item.isCompleted).toList();
    if (incompleteItems.isNotEmpty) {
      errors.add('${incompleteItems.length} checklist items are not completed');
    }

    // Validate critical items are completed
    final incompleteCriticalItems = checklistItems
        .where((item) => item.priority == ChecklistItemPriority.critical && !item.isCompleted)
        .toList();
    
    if (incompleteCriticalItems.isNotEmpty) {
      errors.add('Critical checklist items must be completed');
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
  void _updateState(PMState newState) {
    _state = newState;
    notifyListeners();
  }
}

/// PM state model
class PMState {
  const PMState({
    this.visits = const [],
    this.isLoading = false,
    this.error,
  });

  final List<PMVisit> visits;
  final bool isLoading;
  final String? error;

  /// Create copy with updated fields
  PMState copyWith({
    List<PMVisit>? visits,
    bool? isLoading,
    String? error,
  }) {
    return PMState(
      visits: visits ?? this.visits,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  /// Create loading state
  PMState copyWithLoading(bool loading) {
    return copyWith(isLoading: loading, error: null);
  }

  /// Create error state
  PMState copyWithError(String errorMessage) {
    return copyWith(isLoading: false, error: errorMessage);
  }
}