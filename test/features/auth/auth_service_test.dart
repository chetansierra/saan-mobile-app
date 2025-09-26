import 'package:flutter_test/flutter_test.dart';

import '../../../lib/features/auth/domain/auth_service.dart';
import '../../../lib/features/auth/domain/models/user_profile.dart';

void main() {
  group('AuthService Extensions Tests', () {
    late AuthService mockAuthService;

    setUp(() {
      // Create a mock auth service for testing
      mockAuthService = _MockAuthService();
    });

    testWidgets('canAccessAdminFeatures returns correct values', (tester) async {
      final mockService = mockAuthService as _MockAuthService;

      // Unauthenticated user
      mockService.setMockState(const AuthState());
      expect(mockService.canAccessAdminFeatures(), false);

      // Authenticated but no profile
      mockService.setMockState(const AuthState(
        isAuthenticated: true,
        user: 'mock-user',
      ));
      expect(mockService.canAccessAdminFeatures(), false);

      // Authenticated with requester profile
      final requesterProfile = UserProfile(
        userId: 'user-id',
        tenantId: 'tenant-id',
        email: 'user@example.com',
        name: 'Regular User',
        role: UserRole.requester,
        createdAt: DateTime.now(),
      );
      mockService.setMockState(AuthState(
        isAuthenticated: true,
        user: 'mock-user',
        profile: requesterProfile,
      ));
      expect(mockService.canAccessAdminFeatures(), false);

      // Authenticated with admin profile
      final adminProfile = UserProfile(
        userId: 'user-id',
        tenantId: 'tenant-id',
        email: 'admin@example.com',
        name: 'Admin User',
        role: UserRole.admin,
        createdAt: DateTime.now(),
      );
      mockService.setMockState(AuthState(
        isAuthenticated: true,
        user: 'mock-user',
        profile: adminProfile,
      ));
      expect(mockService.canAccessAdminFeatures(), true);
    });

    testWidgets('canCreateRequests returns correct values', (tester) async {
      final mockService = mockAuthService as _MockAuthService;

      // Unauthenticated user
      mockService.setMockState(const AuthState());
      expect(mockService.canCreateRequests(), false);

      // Authenticated but no profile
      mockService.setMockState(const AuthState(
        isAuthenticated: true,
        user: 'mock-user',
      ));
      expect(mockService.canCreateRequests(), false);

      // Authenticated with complete profile (both roles should work)
      final profile = UserProfile(
        userId: 'user-id',
        tenantId: 'tenant-id',
        email: 'user@example.com',
        name: 'User',
        role: UserRole.requester,
        createdAt: DateTime.now(),
      );
      mockService.setMockState(AuthState(
        isAuthenticated: true,
        user: 'mock-user',
        profile: profile,
      ));
      expect(mockService.canCreateRequests(), true);
    });

    testWidgets('canManageFacilities returns correct values', (tester) async {
      final mockService = mockAuthService as _MockAuthService;

      // Only admin should be able to manage facilities
      final requesterProfile = UserProfile(
        userId: 'user-id',
        tenantId: 'tenant-id',
        email: 'user@example.com',
        name: 'Regular User',
        role: UserRole.requester,
        createdAt: DateTime.now(),
      );
      mockService.setMockState(AuthState(
        isAuthenticated: true,
        user: 'mock-user',
        profile: requesterProfile,
      ));
      expect(mockService.canManageFacilities(), false);

      final adminProfile = UserProfile(
        userId: 'user-id',
        tenantId: 'tenant-id',
        email: 'admin@example.com',
        name: 'Admin User',
        role: UserRole.admin,
        createdAt: DateTime.now(),
      );
      mockService.setMockState(AuthState(
        isAuthenticated: true,
        user: 'mock-user',
        profile: adminProfile,
      ));
      expect(mockService.canManageFacilities(), true);
    });

    testWidgets('canManageContracts returns correct values', (tester) async {
      final mockService = mockAuthService as _MockAuthService;

      // Only admin should be able to manage contracts
      final requesterProfile = UserProfile(
        userId: 'user-id',
        tenantId: 'tenant-id',
        email: 'user@example.com',
        name: 'Regular User',
        role: UserRole.requester,
        createdAt: DateTime.now(),
      );
      mockService.setMockState(AuthState(
        isAuthenticated: true,
        user: 'mock-user',
        profile: requesterProfile,
      ));
      expect(mockService.canManageContracts(), false);

      final adminProfile = UserProfile(
        userId: 'user-id',
        tenantId: 'tenant-id',
        email: 'admin@example.com',
        name: 'Admin User',
        role: UserRole.admin,
        createdAt: DateTime.now(),
      );
      mockService.setMockState(AuthState(
        isAuthenticated: true,
        user: 'mock-user',
        profile: adminProfile,
      ));
      expect(mockService.canManageContracts(), true);
    });

    testWidgets('canViewInvoices and canManageInvoices return correct values', (tester) async {
      final mockService = mockAuthService as _MockAuthService;

      // Both roles can view invoices, only admin can manage
      final requesterProfile = UserProfile(
        userId: 'user-id',
        tenantId: 'tenant-id',
        email: 'user@example.com',
        name: 'Regular User',
        role: UserRole.requester,
        createdAt: DateTime.now(),
      );
      mockService.setMockState(AuthState(
        isAuthenticated: true,
        user: 'mock-user',
        profile: requesterProfile,
      ));
      expect(mockService.canViewInvoices(), true);
      expect(mockService.canManageInvoices(), false);

      final adminProfile = UserProfile(
        userId: 'user-id',
        tenantId: 'tenant-id',
        email: 'admin@example.com',
        name: 'Admin User',
        role: UserRole.admin,
        createdAt: DateTime.now(),
      );
      mockService.setMockState(AuthState(
        isAuthenticated: true,
        user: 'mock-user',
        profile: adminProfile,
      ));
      expect(mockService.canViewInvoices(), true);
      expect(mockService.canManageInvoices(), true);
    });
  });
}

/// Mock implementation of AuthService for testing
class _MockAuthService extends AuthService {
  _MockAuthService() : super._();

  AuthState _mockState = const AuthState();

  void setMockState(AuthState state) {
    _mockState = state;
  }

  @override
  AuthState get state => _mockState;

  @override
  bool get isAuthenticated => _mockState.isAuthenticated;

  @override
  bool get hasCompleteProfile => _mockState.hasCompleteProfile;

  @override
  UserProfile? get currentProfile => _mockState.profile;

  @override
  dynamic get currentUser => _mockState.user;

  @override
  String? get tenantId => _mockState.tenantId;

  @override
  bool get isAdmin => _mockState.isAdmin;

  @override
  bool get isRequester => _mockState.isRequester;
}