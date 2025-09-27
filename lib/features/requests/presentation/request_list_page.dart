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

    return RequestsRealtimeHook(
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
    if (state.isLoading && state.requests.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return _buildErrorState(state.error!);
    }

    if (state.requests.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(AppTheme.spacingM),
        itemCount: state.requests.length + (state.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == state.requests.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AppTheme.spacingM),
                child: CircularProgressIndicator(),
              ),
            );
          }
          
          final request = state.requests[index];
          return _buildRequestCard(request);
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