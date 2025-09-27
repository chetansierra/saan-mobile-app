import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/domain/auth_service.dart';
import '../features/auth/presentation/sign_in_page.dart';
import '../features/auth/presentation/verify_email_page.dart';
import '../features/onboarding/presentation/company_setup_page.dart';
import '../features/onboarding/presentation/facility_setup_page.dart';
import '../features/onboarding/presentation/onboarding_review_page.dart';
import '../features/home/home_page.dart';
import '../features/requests/presentation/create_request_page.dart';
import '../features/requests/presentation/request_list_page.dart';
import '../features/requests/presentation/request_detail_page.dart';
import '../features/contracts/presentation/contract_list_page.dart';
import '../features/contracts/presentation/create_contract_page.dart';
import '../features/contracts/presentation/contract_detail_page.dart';
import '../features/pm/presentation/pm_schedule_page.dart';
import '../features/pm/presentation/pm_visit_detail_page.dart';

/// Router configuration provider for the app
final appRouterProvider = Provider<GoRouter>((ref) {
  final authService = ref.watch(authServiceProvider);
  
  return GoRouter(
    initialLocation: '/auth/sign-in',
    refreshListenable: authService,
    redirect: (context, state) {
      final isAuthenticated = authService.isAuthenticated;
      final hasProfile = authService.hasCompleteProfile;
      final location = state.matchedLocation;

      // Debug logging
      debugPrint('Router redirect: location=$location, '
          'isAuthenticated=$isAuthenticated, hasProfile=$hasProfile');

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

      // Allow access to current route
      return null;
    },
    routes: [
      // Auth routes
      GoRoute(
        path: '/auth/sign-in',
        name: 'signIn',
        builder: (context, state) => const SignInPage(),
      ),
      GoRoute(
        path: '/auth/verify-email',
        name: 'verifyEmail',
        builder: (context, state) => const VerifyEmailPage(),
      ),

      // Onboarding routes
      GoRoute(
        path: '/onboarding/company',
        name: 'onboardingCompany',
        builder: (context, state) => const CompanySetupPage(),
      ),
      GoRoute(
        path: '/onboarding/facility-new',
        name: 'onboardingFacility',
        builder: (context, state) => const FacilitySetupPage(),
      ),
      GoRoute(
        path: '/onboarding/review',
        name: 'onboardingReview',
        builder: (context, state) => const OnboardingReviewPage(),
      ),

      // Main app routes
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const HomePage(),
      ),

      // Requests routes
      GoRoute(
        path: '/requests',
        name: 'requests',
        builder: (context, state) => const RequestListPage(),
      ),
      GoRoute(
        path: '/requests/new',
        name: 'newRequest',
        builder: (context, state) => const CreateRequestPage(),
      ),
      GoRoute(
        path: '/requests/:id',
        name: 'requestDetail',
        builder: (context, state) {
          final requestId = state.pathParameters['id']!;
          return _PlaceholderPage(
            title: 'Request Details',
            message: 'Request detail page for ID: $requestId\nWill be implemented with full details view.',
            showAppBar: true,
          );
        },
      ),

      // Contracts routes
      GoRoute(
        path: '/contracts',
        builder: (context, state) => const ContractListPage(),
      ),
      GoRoute(
        path: '/contracts/create',
        builder: (context, state) => const CreateContractPage(),
      ),
      GoRoute(
        path: '/contracts/:contractId',
        builder: (context, state) {
          final contractId = state.pathParameters['contractId']!;
          return ContractDetailPage(contractId: contractId);
        },
      ),

      // PM routes
      GoRoute(
        path: '/pm',
        builder: (context, state) => const PMSchedulePage(),
      ),
      GoRoute(
        path: '/pm/:pmVisitId',
        builder: (context, state) {
          final pmVisitId = state.pathParameters['pmVisitId']!;
          return PMVisitDetailPage(pmVisitId: pmVisitId);
        },
      ),

      // Billing routes
      GoRoute(
        path: '/billing',
        name: 'billing',
        builder: (context, state) => const InvoiceListPage(),
      ),
      GoRoute(
        path: '/billing/:invoiceId',
        name: 'invoiceDetail',
        builder: (context, state) {
          final invoiceId = state.pathParameters['invoiceId']!;
          return InvoiceDetailPage(invoiceId: invoiceId);
        },
      ),

      // Profile routes (placeholder)
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const _PlaceholderPage(
          title: 'Profile',
          message: 'Profile management will be implemented in future rounds',
          showAppBar: true,
        ),
      ),
    ],
    errorBuilder: (context, state) => _ErrorPage(error: state.error.toString()),
  );
});

/// Placeholder page for routes not yet implemented
class _PlaceholderPage extends ConsumerWidget {
  const _PlaceholderPage({
    required this.title,
    required this.message,
    this.showAppBar = false,
  });

  final String title;
  final String message;
  final bool showAppBar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.watch(authServiceProvider);

    return Scaffold(
      appBar: showAppBar
          ? AppBar(
              title: Text(title),
              actions: [
                IconButton(
                  onPressed: () async {
                    await authService.signOut();
                  },
                  icon: const Icon(Icons.logout),
                  tooltip: 'Sign Out',
                ),
              ],
            )
          : null,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                title == 'Dashboard' ? Icons.dashboard : Icons.construction,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              if (showAppBar && title != 'Dashboard') ...[
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: () => context.go('/home'),
                  child: const Text('Go to Dashboard'),
                ),
              ],
              if (title == 'Dashboard') ...[
                const SizedBox(height: 32),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: () => context.go('/requests'),
                      icon: const Icon(Icons.build),
                      label: const Text('Requests'),
                    ),
                    FilledButton.icon(
                      onPressed: () => context.go('/contracts'),
                      icon: const Icon(Icons.description),
                      label: const Text('Contracts'),
                    ),
                    FilledButton.icon(
                      onPressed: () => context.go('/profile'),
                      icon: const Icon(Icons.person),
                      label: const Text('Profile'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Error page for router navigation errors
class _ErrorPage extends StatelessWidget {
  const _ErrorPage({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Navigation Error'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 24),
              Text(
                'Navigation Error',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              Text(
                error,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () => context.go('/auth/sign-in'),
                child: const Text('Go to Sign In'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}