import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/auth_service.dart';
import '../../auth/domain/models/user_profile.dart';
import '../../onboarding/domain/models/company.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../data/requests_repository.dart';
import 'models/request.dart';

/// Provider for RequestsService
final requestsServiceProvider = ChangeNotifierProvider<RequestsService>((ref) {
  return RequestsService._(ref.watch(authServiceProvider));
});

/// Service for managing requests state and operations
class RequestsService extends ChangeNotifier {
  RequestsService._(this._authService);

  final AuthService _authService;
  final RequestsRepository _repository = RequestsRepository.instance;
  final OnboardingRepository _onboardingRepository = OnboardingRepository.instance;

  RequestsState _state = const RequestsState();

  /// Current requests state
  RequestsState get state => _state;

  /// Current filters
  RequestFilters get filters => _state.filters;

  /// Current requests list
  List<ServiceRequest> get requests => _state.requests;

  /// Whether currently loading
  bool get isLoading => _state.isLoading;

  /// Whether has more pages
  bool get hasMore => _state.hasMore;

  /// Current page
  int get currentPage => _state.currentPage;

  /// Total requests count
  int get totalCount => _state.totalCount;

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

    await refreshRequests();
  }

  /// Refresh requests (first page)
  Future<void> refreshRequests() async {
    try {
      _updateState(_state.copyWithLoading(true));
      await _loadRequests(page: 1, clearExisting: true);
    } catch (e) {
      debugPrint('❌ Failed to refresh requests: $e');
      _updateState(_state.copyWithError(e.toString()));
    }
  }

  /// Load more requests (pagination)
  Future<void> loadMoreRequests() async {
    if (_state.isLoading || !_state.hasMore) return;

    try {
      _updateState(_state.copyWith(isLoadingMore: true));
      await _loadRequests(page: _state.currentPage + 1, clearExisting: false);
    } catch (e) {
      debugPrint('❌ Failed to load more requests: $e');
      _updateState(_state.copyWithError(e.toString()));
    }
  }

  /// Load requests from repository
  Future<void> _loadRequests({
    required int page,
    required bool clearExisting,
  }) async {
    final tenantId = _tenantId;
    if (tenantId == null) {
      throw Exception('No tenant context available');
    }

    final response = await _repository.getRequests(
      tenantId: tenantId,
      filters: _state.filters,
      page: page,
      pageSize: 20,
      orderBy: 'created_at',
      ascending: false,
    );

    final newRequests = clearExisting
        ? response.requests
        : [..._state.requests, ...response.requests];

    _updateState(_state.copyWith(
      requests: newRequests,
      currentPage: page,
      totalCount: response.total,
      hasMore: response.hasMore,
      isLoading: false,
      isLoadingMore: false,
      error: null,
    ));

    debugPrint('✅ Loaded ${response.requests.length} requests (page: $page, total: ${response.total})');
  }

  /// Apply filters and refresh
  Future<void> applyFilters(RequestFilters filters) async {
    debugPrint('🔍 Applying filters: ${filters.hasActiveFilters}');
    
    _updateState(_state.copyWith(filters: filters));
    await refreshRequests();
  }

  /// Clear filters and refresh
  Future<void> clearFilters() async {
    debugPrint('🧹 Clearing filters');
    
    _updateState(_state.copyWith(filters: const RequestFilters()));
    await refreshRequests();
  }

  /// Search requests
  Future<void> searchRequests(String query) async {
    debugPrint('🔍 Searching requests: $query');
    
    final filters = _state.filters.copyWith(searchQuery: query);
    await applyFilters(filters);
  }

  /// Create new request
  Future<ServiceRequest> createRequest({
    required String facilityId,
    required RequestType type,
    required RequestPriority priority,
    required String description,
    TimeWindow? preferredWindow,
    List<String>? mediaUrls,
  }) async {
    try {
      final tenantId = _tenantId;
      if (tenantId == null) {
        throw Exception('No tenant context available');
      }

      debugPrint('📝 Creating new request');
      _updateState(_state.copyWithLoading(true));

      final request = ServiceRequest(
        tenantId: tenantId,
        facilityId: facilityId,
        type: type,
        priority: priority,
        description: description,
        preferredWindow: preferredWindow,
        mediaUrls: mediaUrls ?? [],
      );

      final createdRequest = await _repository.createRequest(
        tenantId: tenantId,
        request: request,
      );

      // Add to current list if no filters or matches current filters
      if (!_state.filters.hasActiveFilters || _matchesFilters(createdRequest)) {
        final updatedRequests = [createdRequest, ..._state.requests];
        _updateState(_state.copyWith(
          requests: updatedRequests,
          totalCount: _state.totalCount + 1,
          isLoading: false,
          error: null,
        ));
      } else {
        _updateState(_state.copyWith(
          isLoading: false,
          error: null,
        ));
      }

      debugPrint('✅ Request created successfully');
      return createdRequest;
    } catch (e) {
      debugPrint('❌ Failed to create request: $e');
      _updateState(_state.copyWithError(e.toString()));
      rethrow;
    }
  }

  /// Update request status
  Future<ServiceRequest> updateRequestStatus({
    required String requestId,
    required RequestStatus status,
    String? assignedEngineerName,
    DateTime? eta,
  }) async {
    try {
      final tenantId = _tenantId;
      if (tenantId == null) {
        throw Exception('No tenant context available');
      }

      debugPrint('📝 Updating request status: $requestId -> ${status.displayName}');

      final updatedRequest = await _repository.updateRequest(
        requestId: requestId,
        tenantId: tenantId,
        status: status,
        assignedEngineerName: assignedEngineerName,
        eta: eta,
      );

      // Update in current list
      final updatedRequests = _state.requests.map((request) {
        return request.id == requestId ? updatedRequest : request;
      }).toList();

      _updateState(_state.copyWith(requests: updatedRequests));

      debugPrint('✅ Request status updated successfully');
      return updatedRequest;
    } catch (e) {
      debugPrint('❌ Failed to update request status: $e');
      rethrow;
    }
  }

  /// Get single request
  Future<ServiceRequest?> getRequest(String requestId) async {
    try {
      final tenantId = _tenantId;
      if (tenantId == null) {
        throw Exception('No tenant context available');
      }

      return await _repository.getRequest(requestId, tenantId);
    } catch (e) {
      debugPrint('❌ Failed to get request: $e');
      rethrow;
    }
  }

  /// Get available facilities for request creation
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

  /// Get available assignees (admin users) for the tenant
  Future<List<UserProfile>> getAvailableAssignees() async {
    try {
      final tenantId = _tenantId;
      if (tenantId == null) {
        throw Exception('No tenant context available');
      }

      return await _repository.getAvailableAssignees(tenantId);
    } catch (e) {
      debugPrint('❌ Failed to get available assignees: $e');
      rethrow;
    }
  }

  /// Check if request matches current filters
  bool _matchesFilters(ServiceRequest request) {
    final filters = _state.filters;

    // Status filter
    if (filters.statuses.isNotEmpty && !filters.statuses.contains(request.status)) {
      return false;
    }

    // Facility filter
    if (filters.facilities.isNotEmpty && !filters.facilities.contains(request.facilityId)) {
      return false;
    }

    // Priority filter
    if (filters.priorities.isNotEmpty && !filters.priorities.contains(request.priority)) {
      return false;
    }

    // Search filter
    if (filters.searchQuery != null && filters.searchQuery!.trim().isNotEmpty) {
      final query = filters.searchQuery!.toLowerCase().trim();
      final description = request.description.toLowerCase();
      final facilityName = (request.facilityName ?? '').toLowerCase();
      
      if (!description.contains(query) && !facilityName.contains(query)) {
        return false;
      }
    }

    return true;
  }

  /// Clear error state
  void clearError() {
    if (_state.error != null) {
      _updateState(_state.copyWith(error: null));
    }
  }

  /// Update internal state and notify listeners
  void _updateState(RequestsState newState) {
    _state = newState;
    notifyListeners();
  }
}

/// Requests state model
class RequestsState extends Equatable {
  const RequestsState({
    this.requests = const [],
    this.filters = const RequestFilters(),
    this.currentPage = 1,
    this.totalCount = 0,
    this.hasMore = false,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
  });

  final List<ServiceRequest> requests;
  final RequestFilters filters;
  final int currentPage;
  final int totalCount;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;

  /// Create copy with updated fields
  RequestsState copyWith({
    List<ServiceRequest>? requests,
    RequestFilters? filters,
    int? currentPage,
    int? totalCount,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
  }) {
    return RequestsState(
      requests: requests ?? this.requests,
      filters: filters ?? this.filters,
      currentPage: currentPage ?? this.currentPage,
      totalCount: totalCount ?? this.totalCount,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error ?? this.error,
    );
  }

  /// Create loading state
  RequestsState copyWithLoading(bool loading) {
    return copyWith(isLoading: loading, error: null);
  }

  /// Create error state
  RequestsState copyWithError(String errorMessage) {
    return copyWith(
      isLoading: false,
      isLoadingMore: false,
      error: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        requests,
        filters,
        currentPage,
        totalCount,
        hasMore,
        isLoading,
        isLoadingMore,
        error,
      ];
}