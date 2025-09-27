import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../core/obs/analytics.dart';
import '../../../core/ui/connection_indicator.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_skeleton.dart';
import '../domain/models/request.dart';
import '../domain/requests_service.dart';
import '../realtime/requests_realtime.dart';
import 'request_filters_sheet.dart';

/// Request list page showing all requests with filtering and pagination
class RequestListPage extends ConsumerStatefulWidget {
  const RequestListPage({super.key});

  @override
  ConsumerState<RequestListPage> createState() => _RequestListPageState();
}

class _RequestListPageState extends ConsumerState<RequestListPage> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Track screen view
      final analytics = ref.read(analyticsProvider);
      AnalyticsHelper.trackNavigation(analytics, 'requests_list');
      
      ref.read(requestsServiceProvider).initialize();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      ref.read(requestsServiceProvider).loadMoreRequests();
    }
  }

  void _onSearchChanged(String query) {
    // Debounce search to avoid excessive API calls
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      final analytics = ref.read(analyticsProvider);
      AnalyticsHelper.trackAction(analytics, 'search_requests', context: {
        'query_length': query.length,
        'has_query': query.isNotEmpty,
      });
      
      final currentFilters = ref.read(requestsServiceProvider).state.filters;
      final newFilters = currentFilters.copyWith(searchQuery: query.isEmpty ? null : query);
      ref.read(requestsServiceProvider).applyFilters(newFilters);
    });
  }

  void _showFilters() {
    final analytics = ref.read(analyticsProvider);
    AnalyticsHelper.trackAction(analytics, 'open_filter_sheet', context: {
      'screen': 'requests_list',
    });
    
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const RequestFiltersSheet(),
    );
  }

  Future<void> _onRefresh() async {
    await ref.read(requestsServiceProvider).refreshRequests();
  }

  @override
  Widget build(BuildContext context) {
    final requestsState = ref.watch(requestsServiceProvider).state;

    return AnalyticsPageView(
      screenName: 'requests_list',
      child: AppToastProvider(
        child: RequestsRealtimeHook(
          child: Scaffold(
      appBar: AppBar(
        title: const Text('Requests'),
        actions: [
          IconButton(
            onPressed: _showFilters,
            icon: Badge(
              isLabelVisible: requestsState.filters.hasActiveFilters,
              child: const Icon(Icons.filter_list),
            ),
            tooltip: 'Filter requests',
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Search bar
              _buildSearchBar(),
              
              // Filter chips
              if (requestsState.filters.hasActiveFilters)
                _buildFilterChips(requestsState.filters),
              
              // Request list
              Expanded(
                child: _buildRequestList(requestsState),
              ),
            ],
          ),
          
          // Floating connection indicator
          const FloatingConnectionIndicator(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/requests/new'),
        label: const Text('New Request'),
        icon: const Icon(Icons.add),
      ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search requests...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                  icon: const Icon(Icons.clear),
                )
              : null,
        ),
        onChanged: _onSearchChanged,
      ),
    );
  }

  Widget _buildFilterChips(RequestFilters filters) {
    final chips = <Widget>[];
    
    // Status chips
    for (final status in filters.statuses) {
      chips.add(_buildFilterChip(
        label: status.displayName,
        onDeleted: () {
          final updatedStatuses = filters.statuses.where((s) => s != status).toList();
          final updatedFilters = filters.copyWith(statuses: updatedStatuses);
          ref.read(requestsServiceProvider).applyFilters(updatedFilters);
        },
      ));
    }
    
    // Priority chips
    for (final priority in filters.priorities) {
      chips.add(_buildFilterChip(
        label: priority.displayName,
        onDeleted: () {
          final updatedPriorities = filters.priorities.where((p) => p != priority).toList();
          final updatedFilters = filters.copyWith(priorities: updatedPriorities);
          ref.read(requestsServiceProvider).applyFilters(updatedFilters);
        },
      ));
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
      child: Wrap(
        spacing: AppTheme.spacingS,
        children: [
          ...chips,
          ActionChip(
            label: const Text('Clear All'),
            onPressed: () => ref.read(requestsServiceProvider).clearFilters(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required VoidCallback onDeleted,
  }) {
    return FilterChip(
      label: Text(label),
      selected: true,
      onDeleted: onDeleted,
    );
  }

  Widget _buildRequestList(RequestsState state) {
    // Show skeleton loading for initial load
    if (state.isLoading && state.requests.isEmpty) {
      return SkeletonLayouts.listScreen(itemCount: 8);
    }

    // Show error state with retry
    if (state.error != null && state.requests.isEmpty) {
      final isNetworkError = state.error!.toLowerCase().contains('network');
      return isNetworkError 
          ? EmptyStates.networkError(
              onRetry: () {
                final analytics = ref.read(analyticsProvider);
                AnalyticsHelper.trackAction(analytics, 'retry_network_error', context: {
                  'screen': 'requests_list',
                });
                ref.read(requestsServiceProvider).refresh();
              },
            )
          : EmptyStates.serverError(
              onRetry: () {
                final analytics = ref.read(analyticsProvider);
                AnalyticsHelper.trackAction(analytics, 'retry_server_error', context: {
                  'screen': 'requests_list',
                });
                ref.read(requestsServiceProvider).refresh();
              },
            );
    }

    // Show appropriate empty state
    if (state.requests.isEmpty) {
      if (state.filters.hasActiveFilters) {
        if (state.filters.searchQuery != null && state.filters.searchQuery!.isNotEmpty) {
          return EmptyStates.noSearchResults(
            query: state.filters.searchQuery!,
            onClearSearch: () {
              _searchController.clear();
              _onSearchChanged('');
              final analytics = ref.read(analyticsProvider);
              AnalyticsHelper.trackAction(analytics, 'clear_search', context: {
                'screen': 'requests_list',
              });
            },
          );
        } else {
          return EmptyStates.noFilteredResults(
            onClearFilters: () {
              ref.read(requestsServiceProvider).clearFilters();
              final analytics = ref.read(analyticsProvider);
              AnalyticsHelper.trackAction(analytics, 'clear_filters', context: {
                'screen': 'requests_list',
              });
            },
          );
        }
      } else {
        return EmptyStates.noRequests(
          onCreateRequest: () {
            final analytics = ref.read(analyticsProvider);
            AnalyticsHelper.trackAction(analytics, 'create_first_request', context: {
              'from_empty_state': true,
            });
            context.go('/requests/new');
          },
        );
      }
    }

    // Show list with pull-to-refresh and pagination
    return RefreshIndicator(
      onRefresh: () async {
        final analytics = ref.read(analyticsProvider);
        AnalyticsHelper.trackAction(analytics, 'pull_to_refresh', context: {
          'screen': 'requests_list',
          'item_count': state.requests.length,
        });
        
        await ref.read(requestsServiceProvider).refresh();
        
        if (mounted) {
          context.showSuccessToast('Requests refreshed');
        }
      },
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(AppTheme.spacingM),
        itemCount: state.requests.length + (state.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= state.requests.length) {
            // Loading indicator for pagination
            return const Padding(
              padding: EdgeInsets.all(AppTheme.spacingL),
              child: Center(
                child: CircularProgressIndicator(
                  semanticsLabel: 'Loading more requests',
                ),
              ),
            );
          }

          final request = state.requests[index];
          return _RequestCard(
            key: ValueKey(request.id),
            request: request,
            onTap: () {
              final analytics = ref.read(analyticsProvider);
              AnalyticsHelper.trackAction(analytics, 'view_request_detail', context: {
                'request_id_length': request.id?.length ?? 0,
                'status': request.status.value,
                'priority': request.priority.value,
              });
              context.go('/requests/${request.id}');
            },
          );
        },
      ),
    );
  }

  Widget _buildRequestCard(ServiceRequest request) {
    final slaStatus = SlaUtils.getSlaStatus(request.slaDueAt);
    final timeLeft = SlaUtils.timeUntilSlaBreach(request.slaDueAt);
    
    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
      child: InkWell(
        onTap: () => context.go('/requests/${request.id}'),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  _buildStatusBadge(request.status),
                  const Spacer(),
                  if (request.priority == RequestPriority.critical)
                    _buildPriorityBadge(request.priority),
                  Text(
                    DateFormat('MMM dd, HH:mm').format(request.createdAt ?? DateTime.now()),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: AppTheme.spacingS),
              
              // Description
              Text(
                request.description,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: AppTheme.spacingS),
              
              // Facility info
              Row(
                children: [
                  Icon(
                    Icons.location_city,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                  const SizedBox(width: AppTheme.spacingXS),
                  Expanded(
                    child: Text(
                      request.facilityName ?? 'Unknown Facility',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ),
                ],
              ),
              
              // SLA countdown
              if (request.slaDueAt != null) ...[
                const SizedBox(height: AppTheme.spacingS),
                _buildSlaCountdown(slaStatus, timeLeft),
              ],
              
              // Engineer assignment
              if (request.assignedEngineerName != null) ...[
                const SizedBox(height: AppTheme.spacingS),
                Row(
                  children: [
                    Icon(
                      Icons.person,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                    const SizedBox(width: AppTheme.spacingXS),
                    Text(
                      'Assigned to ${request.assignedEngineerName}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
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

  Widget _buildStatusBadge(RequestStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingS,
        vertical: AppTheme.spacingXS,
      ),
      decoration: BoxDecoration(
        color: Color(int.parse('0xFF${status.colorHex.substring(1)}')).withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
        border: Border.all(
          color: Color(int.parse('0xFF${status.colorHex.substring(1)}')).withOpacity(0.3),
        ),
      ),
      child: Text(
        status.displayName,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Color(int.parse('0xFF${status.colorHex.substring(1)}')),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildPriorityBadge(RequestPriority priority) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingS,
        vertical: AppTheme.spacingXS,
      ),
      margin: const EdgeInsets.only(right: AppTheme.spacingS),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.priority_high,
            size: 12,
            color: Colors.red,
          ),
          const SizedBox(width: AppTheme.spacingXS),
          Text(
            priority.displayName,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.red,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlaCountdown(SlaStatus slaStatus, Duration? timeLeft) {
    final color = Color(int.parse('0xFF${slaStatus.colorHex.substring(1)}'));
    final timeText = SlaUtils.formatTimeRemaining(timeLeft);
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingS,
        vertical: AppTheme.spacingXS,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.schedule,
            size: 12,
            color: color,
          ),
          const SizedBox(width: AppTheme.spacingXS),
          Text(
            'SLA: $timeText',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(50),
            ),
            child: Icon(
              Icons.build,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppTheme.spacingL),
          Text(
            'No Requests Found',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            'Create your first service request to get started.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingL),
          FilledButton.icon(
            onPressed: () => context.go('/requests/new'),
            icon: const Icon(Icons.add),
            label: const Text('Create Request'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: AppTheme.spacingL),
          Text(
            'Error Loading Requests',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            error,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingL),
          FilledButton(
            onPressed: () {
              ref.read(requestsServiceProvider).clearError();
              ref.read(requestsServiceProvider).refreshRequests();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

/// Memoized request card component for better performance
class _RequestCard extends StatelessWidget {
  const _RequestCard({
    super.key,
    required this.request,
    required this.onTap,
  });

  final ServiceRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        child: Semantics(
          label: 'Request ${request.description}. Status: ${request.status.displayName}. Priority: ${request.priority.displayName}',
          button: true,
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row with status and priority
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        request.description,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingS),
                    _StatusBadge(status: request.status),
                  ],
                ),
                
                const SizedBox(height: AppTheme.spacingS),
                
                // Facility and date info
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (request.facilityName != null) ...[
                            Text(
                              request.facilityName!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 2),
                          ],
                          Text(
                            'Created ${DateFormat('MMM dd, yyyy').format(request.createdAt ?? DateTime.now())}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                    _PriorityChip(priority: request.priority),
                  ],
                ),
                
                // SLA indicator if exists
                if (request.slaDueAt != null) ...[
                  const SizedBox(height: AppTheme.spacingS),
                  _SLAIndicator(dueAt: request.slaDueAt!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Status badge component
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final RequestStatus status;

  @override
  Widget build(BuildContext context) {
    final color = Color(int.parse('0xFF${status.colorHex.substring(1)}'));
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
        semanticsLabel: 'Status: ${status.displayName}',
      ),
    );
  }
}

/// Priority chip component
class _PriorityChip extends StatelessWidget {
  const _PriorityChip({required this.priority});

  final RequestPriority priority;

  @override
  Widget build(BuildContext context) {
    // Define colors and icons for priorities
    final Color color;
    final IconData icon;
    
    switch (priority) {
      case RequestPriority.critical:
        color = Colors.red;
        icon = Icons.priority_high;
        break;
      case RequestPriority.standard:
        color = Colors.blue;
        icon = Icons.low_priority;
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            priority.displayName,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            semanticsLabel: 'Priority: ${priority.displayName}',
          ),
        ],
      ),
    );
  }
}

/// SLA indicator component
class _SLAIndicator extends StatelessWidget {
  const _SLAIndicator({required this.dueAt});

  final DateTime dueAt;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isOverdue = now.isAfter(dueAt);
    final timeRemaining = dueAt.difference(now);
    
    Color color;
    String text;
    IconData icon;
    
    if (isOverdue) {
      color = Colors.red;
      final overdueDuration = now.difference(dueAt);
      text = 'SLA breached ${_formatDuration(overdueDuration)} ago';
      icon = Icons.warning;
    } else if (timeRemaining.inHours <= 2) {
      color = Colors.orange;
      text = 'SLA due in ${_formatDuration(timeRemaining)}';
      icon = Icons.schedule;
    } else {
      color = Colors.green;
      text = 'SLA due in ${_formatDuration(timeRemaining)}';
      icon = Icons.check_circle_outline;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            semanticsLabel: text,
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h';
    } else {
      return '${duration.inMinutes}m';
    }
  }
}