import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Reusable empty state widget for consistent UX
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
    this.illustration,
    this.backgroundColor,
    this.maxWidth = 320,
  });

  /// Icon to display
  final IconData icon;

  /// Main title text
  final String title;

  /// Description text
  final String description;

  /// Optional action button label
  final String? actionLabel;

  /// Optional action button callback
  final VoidCallback? onAction;

  /// Optional custom illustration widget
  final Widget? illustration;

  /// Optional background color
  final Color? backgroundColor;

  /// Maximum width for the content
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      width: double.infinity,
      color: backgroundColor,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Illustration or Icon
                if (illustration != null)
                  illustration!
                else
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: 64,
                      color: theme.colorScheme.primary.withOpacity(0.7),
                      semanticLabel: 'Empty state icon',
                    ),
                  ),
                
                const SizedBox(height: AppTheme.spacingL),
                
                // Title
                Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                  semanticsLabel: 'Empty state title: $title',
                ),
                
                const SizedBox(height: AppTheme.spacingM),
                
                // Description
                Text(
                  description,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                  semanticsLabel: 'Empty state description: $description',
                ),
                
                // Action button
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: AppTheme.spacingXL),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onAction,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppTheme.spacingM,
                          horizontal: AppTheme.spacingL,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusM),
                        ),
                      ),
                      child: Text(
                        actionLabel!,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        semanticsLabel: 'Action button: $actionLabel',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Predefined empty states for common scenarios
class EmptyStates {
  const EmptyStates._();

  /// Empty state for no search results
  static EmptyState noSearchResults({
    required String query,
    VoidCallback? onClearSearch,
  }) {
    return EmptyState(
      icon: Icons.search_off,
      title: 'No results found',
      description: 'No items match your search for "$query".\nTry adjusting your search terms.',
      actionLabel: 'Clear Search',
      onAction: onClearSearch,
    );
  }

  /// Empty state for filtered lists with no results
  static EmptyState noFilteredResults({
    VoidCallback? onClearFilters,
  }) {
    return EmptyState(
      icon: Icons.filter_alt_off,
      title: 'No matching items',
      description: 'No items match your current filters.\nTry adjusting or clearing your filters.',
      actionLabel: 'Clear Filters',
      onAction: onClearFilters,
    );
  }

  /// Empty state for requests list
  static EmptyState noRequests({
    VoidCallback? onCreateRequest,
  }) {
    return EmptyState(
      icon: Icons.assignment_outlined,
      title: 'No service requests',
      description: 'You haven\'t created any service requests yet.\nCreate your first request to get started.',
      actionLabel: 'Create Request',
      onAction: onCreateRequest,
    );
  }

  /// Empty state for invoices list
  static EmptyState noInvoices({
    VoidCallback? onCreateInvoice,
  }) {
    return EmptyState(
      icon: Icons.receipt_long_outlined,
      title: 'No invoices',
      description: 'No invoices have been created yet.\nInvoices will appear here once you generate them from completed requests.',
      actionLabel: 'View Requests',
      onAction: onCreateInvoice,
    );
  }

  /// Empty state for PM schedule
  static EmptyState noPMVisits({
    VoidCallback? onGeneratePM,
  }) {
    return EmptyState(
      icon: Icons.schedule_outlined,
      title: 'No PM visits scheduled',
      description: 'No preventive maintenance visits are scheduled.\nGenerate PM schedules from your contracts to get started.',
      actionLabel: 'Generate PM Schedule',
      onAction: onGeneratePM,
    );
  }

  /// Empty state for contracts list
  static EmptyState noContracts({
    VoidCallback? onCreateContract,
  }) {
    return EmptyState(
      icon: Icons.description_outlined,
      title: 'No contracts',
      description: 'You haven\'t created any contracts yet.\nCreate contracts to manage AMC/CMC agreements.',
      actionLabel: 'Create Contract',
      onAction: onCreateContract,
    );
  }

  /// Empty state for facilities
  static EmptyState noFacilities({
    VoidCallback? onAddFacility,
  }) {
    return EmptyState(
      icon: Icons.business_outlined,
      title: 'No facilities',
      description: 'You haven\'t added any facilities yet.\nAdd facilities to start managing your locations.',
      actionLabel: 'Add Facility',
      onAction: onAddFacility,
    );
  }

  /// Empty state for new tenants
  static EmptyState welcomeNewTenant({
    VoidCallback? onGetStarted,
  }) {
    return EmptyState(
      icon: Icons.rocket_launch_outlined,
      title: 'Welcome to MaintPulse!',
      description: 'Get started by setting up your company profile and adding your first facility.',
      actionLabel: 'Get Started',
      onAction: onGetStarted,
    );
  }

  /// Empty state for network errors
  static EmptyState networkError({
    VoidCallback? onRetry,
  }) {
    return EmptyState(
      icon: Icons.wifi_off_outlined,
      title: 'Connection problem',
      description: 'Unable to connect to the server.\nCheck your internet connection and try again.',
      actionLabel: 'Retry',
      onAction: onRetry,
    );
  }

  /// Empty state for server errors
  static EmptyState serverError({
    VoidCallback? onRetry,
  }) {
    return EmptyState(
      icon: Icons.error_outline,
      title: 'Something went wrong',
      description: 'We\'re having trouble loading your data.\nPlease try again in a few moments.',
      actionLabel: 'Retry',
      onAction: onRetry,
    );
  }

  /// Empty state for unauthorized access
  static EmptyState unauthorized({
    VoidCallback? onSignIn,
  }) {
    return EmptyState(
      icon: Icons.lock_outline,
      title: 'Access denied',
      description: 'You don\'t have permission to view this content.\nPlease sign in with the appropriate account.',
      actionLabel: 'Sign In',
      onAction: onSignIn,
    );
  }

  /// Empty state for maintenance mode
  static EmptyState maintenance() {
    return const EmptyState(
      icon: Icons.build_outlined,
      title: 'Under maintenance',
      description: 'We\'re performing some maintenance to improve your experience.\nPlease check back in a few minutes.',
    );
  }

  /// Custom empty state builder
  static EmptyState custom({
    required IconData icon,
    required String title,
    required String description,
    String? actionLabel,
    VoidCallback? onAction,
    Widget? illustration,
    Color? backgroundColor,
  }) {
    return EmptyState(
      icon: icon,
      title: title,
      description: description,
      actionLabel: actionLabel,
      onAction: onAction,
      illustration: illustration,
      backgroundColor: backgroundColor,
    );
  }
}

/// Empty state wrapper for lists
class EmptyStateWrapper extends StatelessWidget {
  const EmptyStateWrapper({
    super.key,
    required this.isEmpty,
    required this.child,
    required this.emptyState,
  });

  /// Whether the list is empty
  final bool isEmpty;

  /// The child widget (usually a list)
  final Widget child;

  /// The empty state to show when list is empty
  final Widget emptyState;

  @override
  Widget build(BuildContext context) {
    return isEmpty ? emptyState : child;
  }
}

/// Animated empty state for smoother transitions
class AnimatedEmptyState extends StatelessWidget {
  const AnimatedEmptyState({
    super.key,
    required this.isEmpty,
    required this.child,
    required this.emptyState,
    this.duration = const Duration(milliseconds: 300),
  });

  final bool isEmpty;
  final Widget child;
  final Widget emptyState;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      child: isEmpty 
          ? KeyedSubtree(
              key: const ValueKey('empty'),
              child: emptyState,
            )
          : KeyedSubtree(
              key: const ValueKey('content'),
              child: child,
            ),
    );
  }
}