import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../lib/features/auth/domain/auth_service.dart';
import '../../lib/features/auth/domain/models/user_profile.dart';

/// Test implementation of AuthService for testing router guards
class MockAuthService extends AuthService {
  AuthState _testState = const AuthState();

  @override
  AuthState get state => _testState;

  @override
  bool get isAuthenticated => _testState.isAuthenticated;

  @override
  bool get hasCompleteProfile => _testState.hasCompleteProfile;

  void setAuthState(AuthState newState) {
    _testState = newState;
    notifyListeners();
  }

  void setAuthenticated({bool authenticated = true, UserProfile? profile}) {
    _testState = AuthState(
      isAuthenticated: authenticated,
      profile: profile,
      user: authenticated ? 'mock-user' : null,
    );
    notifyListeners();
  }

  void setUnauthenticated() {
    _testState = const AuthState(
      isAuthenticated: false,
      profile: null,
      user: null,
    );
    notifyListeners();
  }
}

void main() {
  group('Router Tests', () {
    late MockAuthService mockAuthService;
    late GoRouter router;

    setUp(() {
      mockAuthService = MockAuthService();
      
      // Create router with mock auth service
      router = GoRouter(
        initialLocation: '/auth/sign-in',
        refreshListenable: mockAuthService,
        redirect: (context, state) {
          final isAuthenticated = mockAuthService.isAuthenticated;
          final hasProfile = mockAuthService.hasCompleteProfile;
          final location = state.matchedLocation;

          // If not authenticated and not on auth routes, redirect to sign in
          if (!isAuthenticated && !location.startsWith('/auth')) {
            return '/auth/sign-in';
          }

          // If authenticated but on auth routes, redirect based on profile status
          if (isAuthenticated && location.startsWith('/auth')) {
            if (hasProfile) {
              return '/home';
            } else {
              return '/onboarding/company';
            }
          }

          // If authenticated but no profile and not on onboarding, redirect to onboarding
          if (isAuthenticated && !hasProfile && !location.startsWith('/onboarding')) {
            return '/onboarding/company';
          }

          // If authenticated with profile but on onboarding, redirect to home
          if (isAuthenticated && hasProfile && location.startsWith('/onboarding')) {
            return '/home';
          }

          return null;
        },
        routes: [
          GoRoute(
            path: '/auth/sign-in',
            builder: (context, state) => const Scaffold(
              body: Center(child: Text('Sign In Page')),
            ),
          ),
          GoRoute(
            path: '/onboarding/company',
            builder: (context, state) => const Scaffold(
              body: Center(child: Text('Onboarding Page')),
            ),
          ),
          GoRoute(
            path: '/home',
            builder: (context, state) => const Scaffold(
              body: Center(child: Text('Home Page')),
            ),
          ),
        ],
      );
    });

    testWidgets('redirects to sign in when not authenticated', (tester) async {
      mockAuthService.setUnauthenticated();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWith((ref) => mockAuthService),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should redirect to sign in page
      expect(find.text('Sign In Page'), findsOneWidget);
    });

    testWidgets('redirects to onboarding when authenticated but no profile', (tester) async {
      mockAuthService.setAuthenticated(authenticated: true, profile: null);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWith((ref) => mockAuthService),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should redirect to onboarding page
      expect(find.text('Onboarding Page'), findsOneWidget);
    });

    testWidgets('redirects to home when authenticated with complete profile', (tester) async {
      final mockProfile = UserProfile(
        userId: 'user-id',
        tenantId: 'tenant-id',
        email: 'test@example.com',
        name: 'Test User',
        role: UserRole.admin,
        createdAt: DateTime.now(),
      );

      mockAuthService.setAuthenticated(authenticated: true, profile: mockProfile);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWith((ref) => mockAuthService),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should redirect to home page
      expect(find.text('Home Page'), findsOneWidget);
    });

    testWidgets('prevents access to protected routes when not authenticated', (tester) async {
      mockAuthService.setUnauthenticated();

      // Try to navigate to home route directly
      router.go('/home');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWith((ref) => mockAuthService),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should be redirected to sign in page
      expect(find.text('Sign In Page'), findsOneWidget);
      expect(find.text('Home Page'), findsNothing);
    });

    testWidgets('allows navigation between auth routes when not authenticated', (tester) async {
      mockAuthService.setUnauthenticated();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWith((ref) => mockAuthService),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should be on sign in page
      expect(find.text('Sign In Page'), findsOneWidget);

      // Navigation within auth routes should work (in a real implementation)
      expect(router.routerDelegate.currentConfiguration.fullPath, equals('/auth/sign-in'));
    });
  });

  group('Auth State Tests', () {
    testWidgets('AuthState properly tracks authentication status', (tester) async {
      // Test unauthenticated state
      const unauthenticatedState = AuthState();
      expect(unauthenticatedState.isAuthenticated, false);
      expect(unauthenticatedState.hasCompleteProfile, false);
      expect(unauthenticatedState.isAdmin, false);
      expect(unauthenticatedState.isRequester, false);
      expect(unauthenticatedState.tenantId, null);
    });

    testWidgets('AuthState properly tracks authenticated state with profile', (tester) async {
      final mockProfile = UserProfile(
        userId: 'user-id',
        tenantId: 'tenant-id',
        email: 'admin@example.com',
        name: 'Admin User',
        role: UserRole.admin,
        createdAt: DateTime.now(),
      );

      final authenticatedState = AuthState(
        isAuthenticated: true,
        user: 'mock-user',
        profile: mockProfile,
      );

      expect(authenticatedState.isAuthenticated, true);
      expect(authenticatedState.hasCompleteProfile, true);
      expect(authenticatedState.isAdmin, true);
      expect(authenticatedState.isRequester, false);
      expect(authenticatedState.tenantId, 'tenant-id');
    });

    testWidgets('AuthState properly handles requester role', (tester) async {
      final mockProfile = UserProfile(
        userId: 'user-id',
        tenantId: 'tenant-id',
        email: 'user@example.com',
        name: 'Regular User',
        role: UserRole.requester,
        createdAt: DateTime.now(),
      );

      final authenticatedState = AuthState(
        isAuthenticated: true,
        user: 'mock-user',
        profile: mockProfile,
      );

      expect(authenticatedState.isAdmin, false);
      expect(authenticatedState.isRequester, true);
    });
  });

  group('User Profile Tests', () {
    testWidgets('UserProfile creates correctly from JSON', (tester) async {
      final json = {
        'user_id': 'test-user-id',
        'tenant_id': 'test-tenant-id',
        'email': 'test@example.com',
        'name': 'Test User',
        'role': 'admin',
        'phone': '+1234567890',
        'created_at': '2025-01-25T12:00:00.000Z',
      };

      final profile = UserProfile.fromJson(json);

      expect(profile.userId, 'test-user-id');
      expect(profile.tenantId, 'test-tenant-id');
      expect(profile.email, 'test@example.com');
      expect(profile.name, 'Test User');
      expect(profile.role, UserRole.admin);
      expect(profile.phone, '+1234567890');
    });

    testWidgets('UserProfile converts correctly to JSON', (tester) async {
      final profile = UserProfile(
        userId: 'test-user-id',
        tenantId: 'test-tenant-id',
        email: 'test@example.com',
        name: 'Test User',
        role: UserRole.requester,
        phone: '+1234567890',
        createdAt: DateTime.parse('2025-01-25T12:00:00.000Z'),
      );

      final json = profile.toJson();

      expect(json['user_id'], 'test-user-id');
      expect(json['tenant_id'], 'test-tenant-id');
      expect(json['email'], 'test@example.com');
      expect(json['name'], 'Test User');
      expect(json['role'], 'requester');
      expect(json['phone'], '+1234567890');
      expect(json['created_at'], '2025-01-25T12:00:00.000Z');
    });

    testWidgets('UserRole enum works correctly', (tester) async {
      // Test admin role
      final adminRole = UserRole.fromString('admin');
      expect(adminRole, UserRole.admin);
      expect(adminRole.value, 'admin');
      expect(adminRole.displayName, 'Administrator');
      expect(adminRole.isAdmin, true);
      expect(adminRole.isRequester, false);

      // Test requester role
      final requesterRole = UserRole.fromString('requester');
      expect(requesterRole, UserRole.requester);
      expect(requesterRole.value, 'requester');
      expect(requesterRole.displayName, 'Requester');
      expect(requesterRole.isAdmin, false);
      expect(requesterRole.isRequester, true);

      // Test invalid role
      expect(() => UserRole.fromString('invalid'), throwsArgumentError);
    });
  });
}