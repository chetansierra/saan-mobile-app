import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../core/ui/connection_indicator.dart';
import '../../auth/domain/auth_service.dart';
import '../domain/pm_service.dart';
import '../domain/pm_visit.dart';
import '../realtime/pm_realtime.dart';

/// PM Schedule page showing upcoming visits with calendar/list view
class PMSchedulePage extends ConsumerStatefulWidget {
  const PMSchedulePage({super.key});

  @override
  ConsumerState<PMSchedulePage> createState() => _PMSchedulePageState();
}

class _PMSchedulePageState extends ConsumerState<PMSchedulePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  PMVisitStatus? _statusFilter;
  bool _showOverdueOnly = false;
  List<PMVisit> _visits = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPMVisits();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPMVisits() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      await ref.read(pmServiceProvider).initialize();
      final visits = ref.read(pmServiceProvider).visits;

      setState(() {
        _visits = visits;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = ref.watch(authServiceProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('PM Schedule'),
        leading: IconButton(
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          IconButton(
            onPressed: _showFilterBottomSheet,
            icon: Badge(
              isLabelVisible: _statusFilter != null || _showOverdueOnly,
              child: const Icon(Icons.filter_list),
            ),
          ),
          if (authService.isAdmin)
            PopupMenuButton<String>(
              onSelected: _handleMenuAction,
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'generate_all',
                  child: Row(
                    children: [
                      Icon(Icons.refresh),
                      SizedBox(width: 8),
                      Text('Generate All Schedules'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'contracts',
                  child: Row(
                    children: [
                      Icon(Icons.description),
                      SizedBox(width: 8),
                      Text('View Contracts'),
                    ],
                  ),
                ),
              ],
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'List View', icon: Icon(Icons.list)),
            Tab(text: 'Calendar', icon: Icon(Icons.calendar_month)),
          ],
        ),
      ),
      body: _buildBody(),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildErrorState();
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildListView(),
        _buildCalendarView(),
      ],
    );
  }

  Widget _buildListView() {
    final filteredVisits = _getFilteredVisits();
    
    if (filteredVisits.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadPMVisits,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        itemCount: filteredVisits.length,
        itemBuilder: (context, index) {
          final visit = filteredVisits[index];
          return _buildVisitCard(visit);
        },
      ),
    );
  }

  Widget _buildCalendarView() {
    // For now, show a placeholder - a full calendar implementation would be complex
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_month,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          ),
          const SizedBox(height: AppTheme.spacingL),
          Text(
            'Calendar View',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            'Interactive calendar view coming soon.\nFor now, use the List View tab.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingL),
          OutlinedButton(
            onPressed: () => _tabController.animateTo(0),
            child: const Text('Switch to List View'),
          ),
        ],
      ),
    );
  }

  Widget _buildVisitCard(PMVisit visit) {
    final isOverdue = visit.isOverdue;
    final isDueToday = visit.isDueToday;
    final isDueSoon = visit.isDueSoon;
    
    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
      child: InkWell(
        onTap: () => context.go('/pm/${visit.id}'),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
            border: isOverdue 
                ? Border.all(color: Colors.red, width: 2)
                : isDueToday
                    ? Border.all(color: Colors.orange, width: 2)
                    : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingL),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    // Status indicator
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(int.parse('0xFF${visit.status.colorHex.substring(1)}')),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingS),
                    
                    // Facility info (would need to join with facilities table)
                    Expanded(
                      child: Text(
                        'Facility Visit', // TODO: Replace with actual facility name
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingS,
                        vertical: AppTheme.spacingXS,
                      ),
                      decoration: BoxDecoration(
                        color: Color(int.parse('0xFF${visit.status.colorHex.substring(1)}')).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusS),
                        border: Border.all(
                          color: Color(int.parse('0xFF${visit.status.colorHex.substring(1)}')).withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        visit.status.displayName.toUpperCase(),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Color(int.parse('0xFF${visit.status.colorHex.substring(1)}')),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: AppTheme.spacingM),
                
                // Schedule details
                Row(
                  children: [
                    Expanded(
                      child: _buildDetailColumn(
                        'Scheduled Date',
                        DateFormat('MMM dd, yyyy').format(visit.scheduledDate),
                        Icons.calendar_today,
                        isOverdue ? Colors.red : isDueToday ? Colors.orange : null,
                      ),
                    ),
                    Expanded(
                      child: _buildDetailColumn(
                        'Time',
                        DateFormat('HH:mm').format(visit.scheduledDate),
                        Icons.access_time,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: AppTheme.spacingM),
                
                // Additional info
                if (visit.engineerName != null)
                  Row(
                    children: [
                      Icon(
                        Icons.person,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                      const SizedBox(width: AppTheme.spacingS),
                      Text(
                        'Engineer: ${visit.engineerName}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                
                // Due status indicators
                if (isOverdue) ...[
                  const SizedBox(height: AppTheme.spacingM),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingM,
                      vertical: AppTheme.spacingS,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusS),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error, size: 16, color: Colors.red),
                        const SizedBox(width: AppTheme.spacingS),
                        Text(
                          'OVERDUE by ${(-visit.daysUntilScheduled)} day(s)',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (isDueToday) ...[
                  const SizedBox(height: AppTheme.spacingM),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingM,
                      vertical: AppTheme.spacingS,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusS),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.today, size: 16, color: Colors.orange),
                        const SizedBox(width: AppTheme.spacingS),
                        Text(
                          'DUE TODAY',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Colors.orange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (isDueSoon) ...[
                  const SizedBox(height: AppTheme.spacingM),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingM,
                      vertical: AppTheme.spacingS,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusS),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.schedule, size: 16, color: Colors.blue),
                        const SizedBox(width: AppTheme.spacingS),
                        Text(
                          'Due in ${visit.daysUntilScheduled} day(s)',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Colors.blue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                // Notes preview
                if (visit.notes != null && visit.notes!.isNotEmpty) ...[
                  const SizedBox(height: AppTheme.spacingM),
                  Text(
                    'Notes: ${visit.notes}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailColumn(String label, String value, IconData icon, [Color? color]) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: color ?? Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
            const SizedBox(width: AppTheme.spacingXS),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color ?? Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingXS),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.schedule_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          ),
          const SizedBox(height: AppTheme.spacingL),
          Text(
            _statusFilter != null || _showOverdueOnly 
                ? 'No Matching Visits'
                : 'No PM Visits Scheduled',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            _statusFilter != null || _showOverdueOnly
                ? 'Try adjusting your filters to see more visits.'
                : 'PM visits will appear here once generated from active contracts.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingL),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_statusFilter != null || _showOverdueOnly) ...[
                OutlinedButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear Filters'),
                ),
                const SizedBox(width: AppTheme.spacingM),
              ],
              if (ref.watch(authServiceProvider).isAdmin) ...[
                FilledButton.icon(
                  onPressed: () => _handleMenuAction('generate_all'),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Generate Schedules'),
                ),
              ] else ...[
                OutlinedButton.icon(
                  onPressed: () => context.go('/contracts'),
                  icon: const Icon(Icons.description),
                  label: const Text('View Contracts'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
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
            'Error Loading PM Schedule',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            _error!,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingL),
          FilledButton(
            onPressed: _loadPMVisits,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget? _buildFloatingActionButton() {
    final authService = ref.watch(authServiceProvider);
    if (!authService.isAdmin) return null;
    
    return FloatingActionButton.extended(
      onPressed: () => _handleMenuAction('generate_all'),
      icon: const Icon(Icons.refresh),
      label: const Text('Generate'),
    );
  }

  List<PMVisit> _getFilteredVisits() {
    var filteredVisits = _visits;

    // Filter by status
    if (_statusFilter != null) {
      filteredVisits = filteredVisits.where((visit) => visit.status == _statusFilter).toList();
    }

    // Filter overdue only
    if (_showOverdueOnly) {
      filteredVisits = filteredVisits.where((visit) => visit.isOverdue).toList();
    }

    // Sort by scheduled date (overdue first, then by date)
    filteredVisits.sort((a, b) {
      // Overdue visits first
      if (a.isOverdue && !b.isOverdue) return -1;
      if (!a.isOverdue && b.isOverdue) return 1;
      
      // Then by scheduled date
      return a.scheduledDate.compareTo(b.scheduledDate);
    });

    return filteredVisits;
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _buildFilterBottomSheet(),
    );
  }

  Widget _buildFilterBottomSheet() {
    return Container(
      padding: EdgeInsets.only(
        top: AppTheme.spacingL,
        left: AppTheme.spacingL,
        right: AppTheme.spacingL,
        bottom: MediaQuery.of(context).padding.bottom + AppTheme.spacingL,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filter PM Visits',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppTheme.spacingL),
          
          // Status filter
          Text(
            'Status',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: AppTheme.spacingS),
          Wrap(
            spacing: AppTheme.spacingS,
            children: [
              FilterChip(
                label: const Text('All'),
                selected: _statusFilter == null,
                onSelected: (selected) {
                  setState(() {
                    _statusFilter = selected ? null : _statusFilter;
                  });
                  Navigator.of(context).pop();
                },
              ),
              ...PMVisitStatus.values.map((status) {
                return FilterChip(
                  label: Text(status.displayName),
                  selected: _statusFilter == status,
                  onSelected: (selected) {
                    setState(() {
                      _statusFilter = selected ? status : null;
                    });
                    Navigator.of(context).pop();
                  },
                );
              }),
            ],
          ),
          
          const SizedBox(height: AppTheme.spacingL),
          
          // Overdue filter
          SwitchListTile(
            title: const Text('Show Overdue Only'),
            value: _showOverdueOnly,
            onChanged: (value) {
              setState(() {
                _showOverdueOnly = value;
              });
              Navigator.of(context).pop();
            },
          ),
          
          const SizedBox(height: AppTheme.spacingL),
          
          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    _clearFilters();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Clear All'),
                ),
              ),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _clearFilters() {
    setState(() {
      _statusFilter = null;
      _showOverdueOnly = false;
    });
  }

  Future<void> _handleMenuAction(String action) async {
    switch (action) {
      case 'generate_all':
        await _generateAllSchedules();
        break;
      case 'contracts':
        context.go('/contracts');
        break;
    }
  }

  Future<void> _generateAllSchedules() async {
    try {
      final pmService = ref.read(pmServiceProvider);
      
      // Show loading dialog
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Generating PM schedules...'),
            ],
          ),
        ),
      );
      
      final totalVisits = await pmService.generateSchedulesForAllContracts();
      
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Generated $totalVisits PM visits for all active contracts'),
          ),
        );
        
        // Refresh the list
        await _loadPMVisits();
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate PM schedules: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}