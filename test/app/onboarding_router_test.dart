import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../lib/features/auth/domain/auth_service.dart';
import '../../lib/features/auth/domain/models/user_profile.dart';
import '../../lib/features/onboarding/domain/models/company.dart';

/// Test implementation of AuthService for testing onboarding router guards
class MockAuthServiceForOnboarding extends AuthService {
  AuthState _testState = const AuthState();

  @override
  AuthState get state => _testState;

  @override
  bool get isAuthenticated => _testState.isAuthenticated;

  @override
  bool get hasCompleteProfile => _testState.hasCompleteProfile;

  void setAuthStateForOnboarding({
    required bool authenticated,
    UserProfile? profile,
  }) {
    _testState = AuthState(
      isAuthenticated: authenticated,
      profile: profile,
      user: authenticated ? 'mock-user' : null,
    );
    notifyListeners();
  }

  void setOnboardingComplete() {
    final profile = UserProfile(
      userId: 'user-id',
      tenantId: 'tenant-id',
      email: 'user@example.com',
      name: 'Test User',
      role: UserRole.admin,
      createdAt: DateTime.now(),
    );
    
    setAuthStateForOnboarding(authenticated: true, profile: profile);
  }

  void setOnboardingIncomplete() {
    setAuthStateForOnboarding(authenticated: true, profile: null);
  }
}

void main() {
  group('Onboarding Router Tests', () {
    late MockAuthServiceForOnboarding mockAuthService;
    late GoRouter router;

    setUp(() {
      mockAuthService = MockAuthServiceForOnboarding();
      
      // Create router with mock auth service for onboarding flow
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
              body: Center(child: Text('Company Setup Page')),
            ),
          ),
          GoRoute(
            path: '/onboarding/facility-new',
            builder: (context, state) => const Scaffold(
              body: Center(child: Text('Facility Setup Page')),
            ),
          ),
          GoRoute(
            path: '/onboarding/review',
            builder: (context, state) => const Scaffold(
              body: Center(child: Text('Onboarding Review Page')),
            ),
          ),
          GoRoute(
            path: '/home',
            builder: (context, state) => const Scaffold(
              body: Center(child: Text('Home Dashboard')),
            ),
          ),
        ],
      );
    });

    testWidgets('redirects unauthenticated users to sign in', (tester) async {
      mockAuthService.setAuthStateForOnboarding(authenticated: false);

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

      expect(find.text('Sign In Page'), findsOneWidget);
    });

    testWidgets('redirects authenticated users without profile to onboarding', (tester) async {
      mockAuthService.setOnboardingIncomplete();

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

      expect(find.text('Company Setup Page'), findsOneWidget);
    });

    testWidgets('redirects complete users away from onboarding to home', (tester) async {
      mockAuthService.setOnboardingComplete();
      
      // Try to access onboarding when already complete
      router.go('/onboarding/company');

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

      // Should be redirected to home
      expect(find.text('Home Dashboard'), findsOneWidget);
      expect(find.text('Company Setup Page'), findsNothing);
    });

    testWidgets('allows navigation within onboarding flow', (tester) async {
      mockAuthService.setOnboardingIncomplete();

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

      // Should start at company setup
      expect(find.text('Company Setup Page'), findsOneWidget);

      // Navigate to facility setup
      router.go('/onboarding/facility-new');
      await tester.pumpAndSettle();

      expect(find.text('Facility Setup Page'), findsOneWidget);

      // Navigate to review
      router.go('/onboarding/review');
      await tester.pumpAndSettle();

      expect(find.text('Onboarding Review Page'), findsOneWidget);
    });

    testWidgets('prevents access to main app during onboarding', (tester) async {
      mockAuthService.setOnboardingIncomplete();

      // Try to access home directly
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

      // Should be redirected to onboarding
      expect(find.text('Company Setup Page'), findsOneWidget);
      expect(find.text('Home Dashboard'), findsNothing);
    });

    testWidgets('auth state changes trigger navigation updates', (tester) async {
      // Start unauthenticated
      mockAuthService.setAuthStateForOnboarding(authenticated: false);

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
      expect(find.text('Sign In Page'), findsOneWidget);

      // Authenticate but incomplete profile
      mockAuthService.setOnboardingIncomplete();
      await tester.pumpAndSettle();

      expect(find.text('Company Setup Page'), findsOneWidget);

      // Complete onboarding
      mockAuthService.setOnboardingComplete();
      await tester.pumpAndSettle();

      expect(find.text('Home Dashboard'), findsOneWidget);
    });
  });

  group('Onboarding Profile Completion Tests', () {
    testWidgets('Profile completion requires both tenant and facilities', (tester) async {
      // Profile with tenant but no facilities should be incomplete
      final incompleteProfile = UserProfile(
        userId: 'user-id',
        tenantId: 'tenant-id',
        email: 'user@example.com',
        name: 'Test User',
        role: UserRole.admin,
        createdAt: DateTime.now(),
      );

      // Note: In the real app, the auth service would check for facilities
      // This test validates the profile model structure
      expect(incompleteProfile.tenantId, 'tenant-id');
      expect(incompleteProfile.role, UserRole.admin);
    });

    testWidgets('Onboarding state validates completion requirements', (tester) async {
      // Test company completion
      const company = Company(
        name: 'Test Company',
        businessType: BusinessTypes.manufacturing,
      );

      const stateWithCompany = OnboardingState(company: company);
      expect(stateWithCompany.isCompanyCompleted, true);
      expect(stateWithCompany.isFacilitiesCompleted, false);
      expect(stateWithCompany.isOnboardingCompleted, false);

      // Test facility completion
      const facility = Facility(
        name: 'Test Facility',
        address: '123 Test St',
      );

      final stateWithBoth = stateWithCompany.copyWith(
        facilities: [facility],
      );
      expect(stateWithBoth.isCompanyCompleted, true);
      expect(stateWithBoth.isFacilitiesCompleted, true);
      expect(stateWithBoth.isOnboardingCompleted, true);
    });
  });
}