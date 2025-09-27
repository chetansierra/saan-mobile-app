import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/domain/auth_service.dart';
import '../requests/data/requests_repository.dart';
import '../requests/domain/models/request.dart';
import '../billing/data/billing_repository.dart';

/// Provider for KpiService
final kpiServiceProvider = ChangeNotifierProvider<KpiService>((ref) {
  return KpiService._(ref.watch(authServiceProvider));
});

/// Service for managing dashboard KPIs
class KpiService extends ChangeNotifier {
  KpiService._(this._authService);

  final AuthService _authService;
  final RequestsRepository _repository = RequestsRepository.instance;
  final BillingRepository _billingRepository = BillingRepository.instance;

  KpiState _state = const KpiState();

  /// Current KPI state
  KpiState get state => _state;

  /// KPI data
  RequestKPIs? get kpis => _state.kpis;

  /// Recent requests
  List<ServiceRequest> get recentRequests => _state.recentRequests;

  /// Whether loading
  bool get isLoading => _state.isLoading;

  /// Error message
  String? get error => _state.error;

  /// Load KPIs and recent requests
  Future<void> loadDashboardData() async {
    try {
      final tenantId = _authService.tenantId;
      if (tenantId == null) {
        throw Exception('No tenant context available');
      }

      _updateState(_state.copyWith(isLoading: true));

      // Load KPIs and recent requests concurrently
      final futures = await Future.wait([
        _repository.getKPIs(tenantId),
        _repository.getRecentRequests(tenantId: tenantId, limit: 5),
      ]);

      final kpis = futures[0] as RequestKPIs;
      final recentRequests = futures[1] as List<ServiceRequest>;

      _updateState(_state.copyWith(
        kpis: kpis,
        recentRequests: recentRequests,
        isLoading: false,
        error: null,
      ));

      debugPrint('✅ Dashboard data loaded successfully');
    } catch (e) {
      debugPrint('❌ Failed to load dashboard data: $e');
      _updateState(_state.copyWith(
        isLoading: false,
        error: e.toString(),
      ));
    }
  }

  /// Refresh dashboard data
  Future<void> refresh() async {
    await loadDashboardData();
  }

  /// Update internal state and notify listeners
  void _updateState(KpiState newState) {
    _state = newState;
    notifyListeners();
  }
}

/// KPI state model
class KpiState {
  const KpiState({
    this.kpis,
    this.recentRequests = const [],
    this.isLoading = false,
    this.error,
  });

  final RequestKPIs? kpis;
  final List<ServiceRequest> recentRequests;
  final bool isLoading;
  final String? error;

  /// Create copy with updated fields
  KpiState copyWith({
    RequestKPIs? kpis,
    List<ServiceRequest>? recentRequests,
    bool? isLoading,
    String? error,
  }) {
    return KpiState(
      kpis: kpis ?? this.kpis,
      recentRequests: recentRequests ?? this.recentRequests,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}