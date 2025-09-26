import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../auth/domain/auth_service.dart';
import '../domain/contracts_service.dart';
import '../domain/contract.dart';

/// Contract list page showing all contracts for the tenant
class ContractListPage extends ConsumerStatefulWidget {
  const ContractListPage({super.key});

  @override
  ConsumerState<ContractListPage> createState() => _ContractListPageState();
}

class _ContractListPageState extends ConsumerState<ContractListPage> {
  @override
  void initState() {
    super.initState();
    // Initialize contracts service
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(contractsServiceProvider).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = ref.watch(authServiceProvider);
    final contractsService = ref.watch(contractsServiceProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contracts'),
        leading: IconButton(
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          if (authService.isAdmin)
            IconButton(
              onPressed: () => context.go('/contracts/create'),
              icon: const Icon(Icons.add),
            ),
        ],
      ),
      body: _buildBody(contractsService),
      floatingActionButton: authService.isAdmin
          ? FloatingActionButton(
              onPressed: () => context.go('/contracts/create'),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildBody(ContractsService contractsService) {
    if (contractsService.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (contractsService.error != null) {
      return _buildErrorState(contractsService);
    }

    if (contractsService.contracts.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () => contractsService.refreshContracts(),
      child: ListView.builder(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        itemCount: contractsService.contracts.length,
        itemBuilder: (context, index) {
          final contract = contractsService.contracts[index];
          return _buildContractCard(contract);
        },
      ),
    );
  }

  Widget _buildContractCard(Contract contract) {
    final isActive = contract.isCurrentlyActive;
    final daysUntilExpiry = contract.endDate.difference(DateTime.now()).inDays;
    final isExpiringSoon = daysUntilExpiry <= 30 && daysUntilExpiry >= 0;
    
    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
      child: InkWell(
        onTap: () => context.go('/contracts/${contract.id}'),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingL),
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
                          contract.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingXS),
                        Text(
                          '${contract.contractType.shortName} • ${contract.serviceType}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Status and expiry badges
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Active/Inactive status
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingS,
                          vertical: AppTheme.spacingXS,
                        ),
                        decoration: BoxDecoration(
                          color: isActive ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(AppTheme.radiusS),
                          border: Border.all(
                            color: isActive ? Colors.green.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          isActive ? 'ACTIVE' : 'INACTIVE',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: isActive ? Colors.green : Colors.grey,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      
                      // Expiry warning
                      if (isExpiringSoon) ...[
                        const SizedBox(height: AppTheme.spacingXS),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spacingS,
                            vertical: AppTheme.spacingXS,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(AppTheme.radiusS),
                            border: Border.all(color: Colors.orange.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.warning,
                                size: 12,
                                color: Colors.orange,
                              ),
                              const SizedBox(width: AppTheme.spacingXS),
                              Text(
                                'EXPIRES IN ${daysUntilExpiry}D',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: AppTheme.spacingM),
              
              // Contract details
              Row(
                children: [
                  Expanded(
                    child: _buildDetailColumn(
                      'Start Date',
                      DateFormat('MMM dd, yyyy').format(contract.startDate),
                      Icons.calendar_today,
                    ),
                  ),
                  Expanded(
                    child: _buildDetailColumn(
                      'End Date',
                      DateFormat('MMM dd, yyyy').format(contract.endDate),
                      Icons.event,
                    ),
                  ),
                  Expanded(
                    child: _buildDetailColumn(
                      'Facilities',
                      '${contract.facilityIds.length}',
                      Icons.location_city,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: AppTheme.spacingM),
              
              // SLA info
              if (contract.criticalSlaDuration != null || contract.standardSlaDuration != null) ...[
                Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: AppTheme.spacingS),
                    Text(
                      'SLA: ',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    if (contract.criticalSlaDuration != null) ...[
                      Text(
                        'Critical ${contract.criticalSlaDuration!.inHours}h',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (contract.standardSlaDuration != null) ...[
                        Text(
                          ', Standard ${contract.standardSlaDuration!.inHours}h',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ] else if (contract.standardSlaDuration != null) ...[
                      Text(
                        'Standard ${contract.standardSlaDuration!.inHours}h',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
                
                const SizedBox(height: AppTheme.spacingS),
              ],
              
              // PM frequency
              Row(
                children: [
                  Icon(
                    Icons.refresh,
                    size: 16,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  Text(
                    'PM Schedule: ${contract.pmFrequency.displayName}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailColumn(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
            const SizedBox(width: AppTheme.spacingXS),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingXS),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
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
            Icons.description_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          ),
          const SizedBox(height: AppTheme.spacingL),
          Text(
            'No Contracts',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            'Create your first contract to manage service agreements and PM schedules.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingL),
          if (ref.watch(authServiceProvider).isAdmin)
            FilledButton.icon(
              onPressed: () => context.go('/contracts/create'),
              icon: const Icon(Icons.add),
              label: const Text('Create Contract'),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ContractsService contractsService) {
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
            'Error Loading Contracts',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            contractsService.error!,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingL),
          FilledButton(
            onPressed: () => contractsService.refreshContracts(),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}