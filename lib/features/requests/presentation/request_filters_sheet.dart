import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../onboarding/domain/models/company.dart';
import '../domain/models/request.dart';
import '../domain/requests_service.dart';

/// Bottom sheet for filtering requests
class RequestFiltersSheet extends ConsumerStatefulWidget {
  const RequestFiltersSheet({super.key});

  @override
  ConsumerState<RequestFiltersSheet> createState() => _RequestFiltersSheetState();
}

class _RequestFiltersSheetState extends ConsumerState<RequestFiltersSheet> {
  late RequestFilters _filters;
  List<Facility> _facilities = [];
  bool _facilitiesLoaded = false;

  @override
  void initState() {
    super.initState();
    _filters = ref.read(requestsServiceProvider).filters;
    _loadFacilities();
  }

  Future<void> _loadFacilities() async {
    try {
      final facilities = await ref.read(requestsServiceProvider).getFacilities();
      if (mounted) {
        setState(() {
          _facilities = facilities;
          _facilitiesLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _facilitiesLoaded = true;
        });
      }
    }
  }

  void _toggleStatus(RequestStatus status) {
    final statuses = List<RequestStatus>.from(_filters.statuses);
    if (statuses.contains(status)) {
      statuses.remove(status);
    } else {
      statuses.add(status);
    }
    
    setState(() {
      _filters = _filters.copyWith(statuses: statuses);
    });
  }

  void _toggleFacility(String facilityId) {
    final facilities = List<String>.from(_filters.facilities);
    if (facilities.contains(facilityId)) {
      facilities.remove(facilityId);
    } else {
      facilities.add(facilityId);
    }
    
    setState(() {
      _filters = _filters.copyWith(facilities: facilities);
    });
  }

  void _togglePriority(RequestPriority priority) {
    final priorities = List<RequestPriority>.from(_filters.priorities);
    if (priorities.contains(priority)) {
      priorities.remove(priority);
    } else {
      priorities.add(priority);
    }
    
    setState(() {
      _filters = _filters.copyWith(priorities: priorities);
    });
  }

  void _clearAllFilters() {
    setState(() {
      _filters = const RequestFilters();
    });
  }

  void _applyFilters() {
    ref.read(requestsServiceProvider).applyFilters(_filters);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppTheme.radiusL),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: AppTheme.spacingS),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              _buildHeader(),
              
              const Divider(height: 1),
              
              // Filter content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(AppTheme.spacingL),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status filters
                      _buildStatusFilters(),
                      
                      const SizedBox(height: AppTheme.spacingL),
                      
                      // Priority filters
                      _buildPriorityFilters(),
                      
                      const SizedBox(height: AppTheme.spacingL),
                      
                      // Facility filters
                      _buildFacilityFilters(),
                    ],
                  ),
                ),
              ),
              
              const Divider(height: 1),
              
              // Action buttons
              _buildActionButtons(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Row(
        children: [
          Text(
            'Filter Requests',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          if (_filters.hasActiveFilters)
            TextButton(
              onPressed: _clearAllFilters,
              child: const Text('Clear All'),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Status',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppTheme.spacingM),
        Wrap(
          spacing: AppTheme.spacingS,
          runSpacing: AppTheme.spacingS,
          children: RequestStatus.values.map((status) {
            final isSelected = _filters.statuses.contains(status);
            return FilterChip(
              label: Text(status.displayName),
              selected: isSelected,
              onSelected: (_) => _toggleStatus(status),
              avatar: isSelected
                  ? null
                  : Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Color(int.parse('0xFF${status.colorHex.substring(1)}')),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPriorityFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Priority',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppTheme.spacingM),
        Wrap(
          spacing: AppTheme.spacingS,
          runSpacing: AppTheme.spacingS,
          children: RequestPriority.values.map((priority) {
            final isSelected = _filters.priorities.contains(priority);
            return FilterChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (priority == RequestPriority.critical) ...[
                    Icon(
                      Icons.priority_high,
                      size: 16,
                      color: isSelected 
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Colors.red,
                    ),
                    const SizedBox(width: AppTheme.spacingXS),
                  ],
                  Text(priority.displayName),
                ],
              ),
              selected: isSelected,
              onSelected: (_) => _togglePriority(priority),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFacilityFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Facilities',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppTheme.spacingM),
        
        if (!_facilitiesLoaded) ...[
          const Center(child: CircularProgressIndicator()),
        ] else if (_facilities.isEmpty) ...[
          Text(
            'No facilities available',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ] else ...[
          Wrap(
            spacing: AppTheme.spacingS,
            runSpacing: AppTheme.spacingS,
            children: _facilities.map((facility) {
              final isSelected = _filters.facilities.contains(facility.id);
              return FilterChip(
                label: Text(facility.name),
                selected: isSelected,
                onSelected: (_) => _toggleFacility(facility.id!),
                avatar: isSelected
                    ? null
                    : const Icon(Icons.location_city, size: 16),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: AppTheme.spacingM),
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: _applyFilters,
              child: Text(
                _filters.hasActiveFilters
                    ? 'Apply Filters'
                    : 'Show All',
              ),
            ),
          ),
        ],
      ),
    );
  }
}