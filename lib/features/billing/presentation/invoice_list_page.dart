import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../core/obs/analytics.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_skeleton.dart';
import '../../auth/domain/auth_service.dart';
import '../domain/billing_service.dart';
import '../domain/invoice.dart';

/// Invoice list page with filtering and pagination
class InvoiceListPage extends ConsumerStatefulWidget {
  const InvoiceListPage({super.key});

  @override
  ConsumerState<InvoiceListPage> createState() => _InvoiceListPageState();
}

class _InvoiceListPageState extends ConsumerState<InvoiceListPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  late final DateTime _pageLoadTime;

  @override
  void initState() {
    super.initState();
    _pageLoadTime = DateTime.now();
    _scrollController.addListener(_onScroll);
    
    // Initialize billing service and track analytics
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _trackScreenView();
      ref.read(billingServiceProvider).initialize().then(_trackListLoad);
    });
  }

  void _trackScreenView() {
    final analytics = ref.read(analyticsProvider);
    analytics.trackEvent('screen_view', {
      'name': 'invoice_list',
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  void _trackListLoad(dynamic _) {
    final analytics = ref.read(analyticsProvider);
    final billingState = ref.read(billingServiceProvider).state;
    final duration = DateTime.now().difference(_pageLoadTime);

    analytics.trackEvent('list_load', {
      'duration_ms': duration.inMilliseconds,
      'item_count': billingState.invoices.length,
      'page_size': 20,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreInvoices();
    }
  }

  void _loadMoreInvoices() {
    final billingService = ref.read(billingServiceProvider);
    final state = billingService.state;
    
    if (state.hasMore && !state.isLoading) {
      // Track pagination
      final analytics = ref.read(analyticsProvider);
      analytics.trackEvent('paginate_next', {
        'from_page': state.currentPage,
        'item_count': state.invoices.length,
        'timestamp': DateTime.now().toIso8601String(),
      });

      billingService.loadMore();
    }
  }

  void _onSearchChanged(String query) {
    final currentFilters = ref.read(billingServiceProvider).state.filters;
    final newFilters = currentFilters.copyWith(searchQuery: query.isEmpty ? null : query);
    
    // Track search
    if (query.trim().isNotEmpty && currentFilters.searchQuery != query) {
      final analytics = ref.read(analyticsProvider);
      final startTime = DateTime.now();
      
      analytics.trackEvent('search_commit', {
        'query_len': query.length,
        'timestamp': startTime.toIso8601String(),
      });
    }

    ref.read(billingServiceProvider).applyFilters(newFilters);
  }

  @override
  Widget build(BuildContext context) {
    final authService = ref.watch(authServiceProvider);
    final billingState = ref.watch(billingServiceProvider).state;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoices'),
        actions: [
          if (authService.userProfile?.role == UserRole.admin)
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: _showFilterSheet,
            ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          _buildSearchBar(),
          
          // Filter chips
          if (billingState.filters.hasActiveFilters)
            _buildFilterChips(billingState.filters),
          
          // Invoice list
          Expanded(
            child: _buildInvoiceList(billingState),
          ),
        ],
      ),
      floatingActionButton: authService.userProfile?.role == UserRole.admin
          ? FloatingActionButton.extended(
              onPressed: _showCreateInvoiceSheet,
              label: const Text('New Invoice'),
              icon: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          labelText: 'Search invoices',
          hintText: 'Invoice number, customer name...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
          border: const OutlineInputBorder(),
        ),
        onChanged: _onSearchChanged,
      ),
    );
  }

  Widget _buildFilterChips(InvoiceFilters filters) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Status filter chips
          ...filters.statuses.map((status) => Padding(
            padding: const EdgeInsets.only(right: AppTheme.spacingS),
            child: FilterChip(
              label: Text(status.displayName),
              selected: true,
              onSelected: (_) => _removeStatusFilter(status),
              deleteIcon: const Icon(Icons.close, size: 16),
              onDeleted: () => _removeStatusFilter(status),
            ),
          )),
          
          // Overdue filter chip
          if (filters.isOverdue == true)
            Padding(
              padding: const EdgeInsets.only(right: AppTheme.spacingS),
              child: FilterChip(
                label: const Text('Overdue'),
                selected: true,
                onSelected: (_) => _removeOverdueFilter(),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: _removeOverdueFilter,
              ),
            ),
          
          // Clear all filters
          Padding(
            padding: const EdgeInsets.only(left: AppTheme.spacingS),
            child: ActionChip(
              label: const Text('Clear All'),
              onPressed: () {
                ref.read(billingServiceProvider).clearFilters();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceList(BillingState state) {
    // Loading skeleton for initial load
    if (state.isLoading && state.invoices.isEmpty) {
      return SkeletonLayouts.listScreen(itemCount: 8);
    }

    // Error state with retry functionality  
    if (state.error != null && state.invoices.isEmpty) {
      final analytics = ref.read(analyticsProvider);
      analytics.trackEvent('error_surface', {
        'category': 'list_load_error',
        'timestamp': DateTime.now().toIso8601String(),
      });

      return EmptyStates.serverError(
        onRetry: () {
          analytics.trackEvent('retry_after_error', {
            'context': 'invoice_list',
            'timestamp': DateTime.now().toIso8601String(),
          });
          ref.read(billingServiceProvider).refresh();
        },
      );
    }

    // Empty state based on filters
    if (state.invoices.isEmpty) {
      if (state.filters.hasActiveFilters) {
        return EmptyStates.noFilteredResults(
          onClearFilters: () {
            _searchController.clear();
            ref.read(billingServiceProvider).clearFilters();
          },
        );
      } else {
        return EmptyStates.noInvoices(
          onCreateInvoice: () => context.go('/requests?status=closed'),
        );
      }
    }

    // Optimized list with refresh and load more
    return RefreshIndicator(
      onRefresh: () async {
        final analytics = ref.read(analyticsProvider);
        analytics.trackEvent('pull_to_refresh', {
          'screen': 'invoice_list',
          'timestamp': DateTime.now().toIso8601String(),
        });
        await ref.read(billingServiceProvider).refresh();
      },
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
        // Use itemExtent for better performance if items have consistent height
        // itemExtent: 140, // Uncomment if all cards have same height
        itemCount: state.invoices.length + (state.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= state.invoices.length) {
            // Load more footer
            return Container(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: AppTheme.spacingM),
                  Text(
                    'Loading more invoices...',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          final invoice = state.invoices[index];
          return _InvoiceCard(
            key: ValueKey(invoice.id),
            invoice: invoice,
            onTap: () => _onInvoiceCardTap(invoice),
          );
        },
      ),
    );
  }

  void _onInvoiceCardTap(Invoice invoice) {
    final analytics = ref.read(analyticsProvider);
    analytics.trackEvent('row_open', {
      'status': invoice.status.value,
      'has_balance': invoice.total > 0,
      'timestamp': DateTime.now().toIso8601String(),
    });

    context.go('/billing/${invoice.id}');
  }

  Widget _buildInvoiceCard(Invoice invoice) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
      child: InkWell(
        onTap: () => context.go('/billing/${invoice.id}'),
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          invoice.invoiceNumber,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          invoice.customerInfo.name,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(invoice.status),
                ],
              ),
              
              const SizedBox(height: AppTheme.spacingM),
              
              // Amount and dates row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Amount',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          '₹${invoice.total.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: invoice.isOverdue ? Colors.red : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Due Date',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          DateFormat('MMM dd, yyyy').format(invoice.dueDate),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: invoice.isOverdue ? Colors.red : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              // Overdue indicator
              if (invoice.isOverdue)
                Padding(
                  padding: const EdgeInsets.only(top: AppTheme.spacingS),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.red, size: 16),
                      const SizedBox(width: AppTheme.spacingXS),
                      Text(
                        'Overdue by ${-invoice.daysUntilDue} days',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(InvoiceStatus status) {
    final color = Color(int.parse('0xFF${status.colorHex.substring(1)}'));
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingS,
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
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => _InvoiceFiltersSheet(
        currentFilters: ref.read(billingServiceProvider).state.filters,
        onFiltersChanged: (filters) {
          ref.read(billingServiceProvider).applyFilters(filters);
        },
      ),
    );
  }

  void _showCreateInvoiceSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _CreateInvoiceSheet(),
    );
  }

  void _removeStatusFilter(InvoiceStatus status) {
    final currentFilters = ref.read(billingServiceProvider).state.filters;
    final newStatuses = List<InvoiceStatus>.from(currentFilters.statuses)
      ..remove(status);
    
    final newFilters = currentFilters.copyWith(statuses: newStatuses);
    ref.read(billingServiceProvider).applyFilters(newFilters);
  }

  void _removeOverdueFilter() {
    final currentFilters = ref.read(billingServiceProvider).state.filters;
    final newFilters = currentFilters.copyWith(isOverdue: null);
    ref.read(billingServiceProvider).applyFilters(newFilters);
  }
}

/// Invoice filters sheet
class _InvoiceFiltersSheet extends StatefulWidget {
  const _InvoiceFiltersSheet({
    required this.currentFilters,
    required this.onFiltersChanged,
  });

  final InvoiceFilters currentFilters;
  final ValueChanged<InvoiceFilters> onFiltersChanged;

  @override
  State<_InvoiceFiltersSheet> createState() => _InvoiceFiltersSheetState();
}

class _InvoiceFiltersSheetState extends State<_InvoiceFiltersSheet> {
  late List<InvoiceStatus> _selectedStatuses;
  bool? _isOverdue;
  DateRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _selectedStatuses = List.from(widget.currentFilters.statuses);
    _isOverdue = widget.currentFilters.isOverdue;
    _dateRange = widget.currentFilters.dateRange;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filter Invoices',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppTheme.spacingL),
          
          // Status filters
          Text(
            'Status',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppTheme.spacingS),
          Wrap(
            spacing: AppTheme.spacingS,
            children: InvoiceStatus.values.map((status) {
              final isSelected = _selectedStatuses.contains(status);
              return FilterChip(
                label: Text(status.displayName),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedStatuses.add(status);
                    } else {
                      _selectedStatuses.remove(status);
                    }
                  });
                },
              );
            }).toList(),
          ),
          
          const SizedBox(height: AppTheme.spacingL),
          
          // Overdue filter
          CheckboxListTile(
            title: const Text('Show only overdue'),
            value: _isOverdue == true,
            onChanged: (value) {
              setState(() {
                _isOverdue = value == true ? true : null;
              });
            },
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          
          const SizedBox(height: AppTheme.spacingL),
          
          // Apply filters button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final newFilters = InvoiceFilters(
                  statuses: _selectedStatuses,
                  isOverdue: _isOverdue,
                  dateRange: _dateRange,
                  searchQuery: widget.currentFilters.searchQuery,
                );
                
                widget.onFiltersChanged(newFilters);
                Navigator.of(context).pop();
              },
              child: const Text('Apply Filters'),
            ),
          ),
          
          // Clear filters button
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () {
                widget.onFiltersChanged(const InvoiceFilters());
                Navigator.of(context).pop();
              },
              child: const Text('Clear Filters'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Create invoice sheet (simplified for MVP)
class _CreateInvoiceSheet extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: EdgeInsets.only(
        left: AppTheme.spacingL,
        right: AppTheme.spacingL,
        top: AppTheme.spacingL,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppTheme.spacingL,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create Invoice',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppTheme.spacingL),
          
          const Text(
            'Select completed requests to generate an invoice from:',
            style: TextStyle(color: Colors.grey),
          ),
          
          const SizedBox(height: AppTheme.spacingL),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.go('/requests?status=closed');
              },
              child: const Text('Select Requests'),
            ),
          ),
        ],
      ),
    );
  }
}