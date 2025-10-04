import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../auth/domain/auth_service.dart';
import '../requests/domain/models/request.dart';
import '../requests/data/requests_repository.dart';
import 'kpi_service.dart';

/// Home dashboard page showing KPIs and recent activity
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(kpiServiceProvider).loadDashboardData();
    });
  }

  Future<void> _onRefresh() async {
    await ref.read(kpiServiceProvider).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final kpiState = ref.watch(kpiServiceProvider).state;
    final authService = ref.watch(authServiceProvider);
    final userName = authService.currentProfile?.name ?? 'User';

    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, ${userName.split(' ').first}'),
        actions: [
          IconButton(
            onPressed: () => context.go('/profile'),
            icon: const Icon(Icons.account_circle),
            tooltip: 'Profile',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // KPI Cards
              _buildKpiSection(kpiState),
              
              const SizedBox(height: AppTheme.spacingL),
              
              // Quick Actions
              _buildQuickActions(),
              
              const SizedBox(height: AppTheme.spacingL),
              
              // Recent Requests
              _buildRecentRequestsSection(kpiState),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiSection(KpiState state) {
    if (state.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppTheme.spacingXL),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (state.error != null) {
      return _buildErrorCard(state.error!);
    }

    final kpis = state.kpis;
    if (kpis == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppTheme.spacingM),
        
        // KPI Cards Grid
        _buildKpiGrid(kpis),
      ],
    );
  }

  Widget _buildKpiGrid(RequestKPIs kpis) {
    return Column(
      children: [
        // Main request KPIs
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: AppTheme.spacingM,
          mainAxisSpacing: AppTheme.spacingM,
          childAspectRatio: 1.2,
          children: [
            _buildKpiCard(
              title: 'Open Requests',
              value: kpis.openRequests.toString(),
              icon: Icons.pending_actions,
              color: Colors.blue,
              onTap: () => context.go('/requests'),
            ),
            _buildKpiCard(
              title: 'Overdue',
              value: kpis.overdueRequests.toString(),
              icon: Icons.warning,
              color: Colors.red,
              onTap: () => context.go('/requests'),
            ),
            _buildKpiCard(
              title: 'Due Today',
              value: kpis.dueTodayRequests.toString(),
              icon: Icons.today,
              color: Colors.orange,
              onTap: () => context.go('/requests'),
            ),
            _buildKpiCard(
              title: 'Avg. TTR',
              value: '${kpis.avgTtrHours.toStringAsFixed(1)}h',
              icon: Icons.timer,
              color: Colors.green,
              subtitle: '7 days',
            ),
          ],
        ),
        
        const SizedBox(height: AppTheme.spacingL),
        
        // Contract expiry alerts (if any expiring contracts)
        if (kpis.expiringContracts > 0) ...[
          _buildExpiryAlertCard(kpis.expiringContracts),
          const SizedBox(height: AppTheme.spacingM),
        ],
        
        // PM counters
        _buildPMCountersGrid(kpis),
        
        const SizedBox(height: AppTheme.spacingL),
        
        // Unpaid invoices alert (if any unpaid invoices)
        if (kpis.unpaidInvoices > 0) ...[
          _buildUnpaidInvoicesCard(kpis.unpaidInvoices, kpis.outstandingAmount),
          const SizedBox(height: AppTheme.spacingM),
        ],
      ],
    );
  }

  Widget _buildExpiryAlertCard(int expiringCount) {
    return Card(
      child: InkWell(
        onTap: () => context.go('/contracts'),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
            border: Border.all(
              color: Colors.orange.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning,
                  color: Colors.orange,
                  size: 24,
                ),
              ),
              
              const SizedBox(width: AppTheme.spacingM),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Contract Expiry Alert',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingXS),
                    Text(
                      '$expiringCount contract${expiringCount > 1 ? 's' : ''} expiring within 30 days',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.orange,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPMCountersGrid(RequestKPIs kpis) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      crossAxisSpacing: AppTheme.spacingM,
      mainAxisSpacing: AppTheme.spacingM,
      childAspectRatio: 1.0,
      children: [
        _buildPMCard(
          title: 'PM Upcoming',
          value: kpis.pmUpcoming.toString(),
          icon: Icons.schedule,
          color: Colors.blue,
          onTap: () => context.go('/pm'),
        ),
        _buildPMCard(
          title: 'Due Today',
          value: kpis.pmDueToday.toString(),
          icon: Icons.today,
          color: Colors.orange,
          onTap: () => context.go('/pm'),
          isUrgent: kpis.pmDueToday > 0,
        ),
        _buildPMCard(
          title: 'Overdue',
          value: kpis.pmOverdue.toString(),
          icon: Icons.error,
          color: Colors.red,
          onTap: () => context.go('/pm'),
          isUrgent: kpis.pmOverdue > 0,
        ),
      ],
    );
  }

  Widget _buildPMCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
    bool isUrgent = false,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
            border: isUrgent 
                ? Border.all(color: color, width: 2)
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingS),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              
              const SizedBox(height: AppTheme.spacingS),
              
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isUrgent ? color : null,
                ),
              ),
              
              const SizedBox(height: AppTheme.spacingXS),
              
              Text(
                title,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingS),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size: 20,
                    ),
                  ),
                  if (onTap != null)
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: AppTheme.spacingXS),
              Text(
                title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppTheme.spacingM),
        
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                title: 'New Request',
                subtitle: 'Create service request',
                icon: Icons.add,
                color: Theme.of(context).colorScheme.primary,
                onTap: () => context.go('/requests/new'),
              ),
            ),
            const SizedBox(width: AppTheme.spacingM),
            Expanded(
              child: _buildActionCard(
                title: 'View All',
                subtitle: 'See all requests',
                icon: Icons.list,
                color: Theme.of(context).colorScheme.secondary,
                onTap: () => context.go('/requests'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusL),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(height: AppTheme.spacingS),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentRequestsSection(KpiState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Requests',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () => context.go('/requests'),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingM),
        
        if (state.isLoading) ...[
          const Center(child: CircularProgressIndicator()),
        ] else if (state.recentRequests.isEmpty) ...[
          _buildEmptyRequestsCard(),
        ] else ...[
          ...state.recentRequests.map((request) => _buildRequestItem(request)),
        ],
      ],
    );
  }

  Widget _buildRequestItem(ServiceRequest request) {
    final slaStatus = SlaUtils.getSlaStatus(request.slaDueAt);
    
    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
      child: InkWell(
        onTap: () => context.go('/requests/${request.id}'),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Row(
            children: [
              // Status indicator
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: Color(int.parse('0xFF${request.status.colorHex.substring(1)}')),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: AppTheme.spacingM),
              
              // Request details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppTheme.spacingXS),
                    Text(
                      request.facilityName ?? 'Unknown Facility',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              
              // SLA indicator or timestamp
              if (request.slaDueAt != null && slaStatus != SlaStatus.none) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingS,
                    vertical: AppTheme.spacingXS,
                  ),
                  decoration: BoxDecoration(
                    color: Color(int.parse('0xFF${slaStatus.colorHex.substring(1)}')).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                  ),
                  child: Text(
                    SlaUtils.formatTimeRemaining(SlaUtils.timeUntilSlaBreach(request.slaDueAt)),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Color(int.parse('0xFF${slaStatus.colorHex.substring(1)}')),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ] else ...[
                Text(
                  DateFormat('MMM dd').format(request.createdAt ?? DateTime.now()),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyRequestsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          children: [
            Icon(
              Icons.inbox,
              size: 48,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
            const SizedBox(height: AppTheme.spacingM),
            Text(
              'No recent requests',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: AppTheme.spacingS),
            TextButton(
              onPressed: () => context.go('/requests/new'),
              child: const Text('Create First Request'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnpaidInvoicesCard(int unpaidCount, double outstandingAmount) {
    return Card(
      child: InkWell(
        onTap: () => context.go('/billing'),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          decoration: BoxDecoration(
            color: Colors.purple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
            border: Border.all(
              color: Colors.purple.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.receipt_long,
                  color: Colors.purple,
                  size: 24,
                ),
              ),
              
              const SizedBox(width: AppTheme.spacingM),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Unpaid Invoices',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                      ),
                    ),
                    
                    const SizedBox(height: AppTheme.spacingXS),
                    
                    Text(
                      '$unpaidCount invoices • ₹${outstandingAmount.toStringAsFixed(2)} outstanding',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.purple[700],
                      ),
                    ),
                  ],
                ),
              ),
              
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.purple,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: AppTheme.spacingM),
            Text(
              'Failed to load dashboard data',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              error,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingM),
            FilledButton(
              onPressed: () => ref.read(kpiServiceProvider).refresh(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}