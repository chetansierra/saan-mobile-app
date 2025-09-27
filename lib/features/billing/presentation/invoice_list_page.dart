import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
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

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    
    // Initialize billing service
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(billingServiceProvider).initialize();
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
      billingService.loadInvoices(page: state.currentPage + 1);
    }
  }

  void _onSearchChanged(String query) {
    final currentFilters = ref.read(billingServiceProvider).state.filters;
    final newFilters = currentFilters.copyWith(searchQuery: query.isEmpty ? null : query);
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
    if (state.isLoading && state.invoices.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.invoices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: AppTheme.spacingM),
            Text(
              'Failed to load invoices',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              state.error!,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingM),
            ElevatedButton(
              onPressed: () => ref.read(billingServiceProvider).refresh(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.invoices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt_long, size: 64, color: Colors.grey),
            const SizedBox(height: AppTheme.spacingM),
            Text(
              'No invoices found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppTheme.spacingS),
            const Text('Invoices will appear here when created'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(billingServiceProvider).refresh(),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(AppTheme.spacingM),
        itemCount: state.invoices.length + (state.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= state.invoices.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AppTheme.spacingM),
                child: CircularProgressIndicator(),
              ),
            );
          }

          final invoice = state.invoices[index];
          return _buildInvoiceCard(invoice);
        },
      ),
    );
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