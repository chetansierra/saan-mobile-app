import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme.dart';
import '../../../core/storage/storage_helper.dart';
import '../../auth/domain/auth_service.dart';
import '../../pm/domain/pm_service.dart';
import '../domain/contracts_service.dart';
import '../domain/contract.dart';
import '../data/contracts_repository.dart';

/// Contract detail page showing full contract information
class ContractDetailPage extends ConsumerStatefulWidget {
  const ContractDetailPage({
    super.key,
    required this.contractId,
  });

  final String contractId;

  @override
  ConsumerState<ContractDetailPage> createState() => _ContractDetailPageState();
}

class _ContractDetailPageState extends ConsumerState<ContractDetailPage> {
  ContractWithFacilities? _contractWithFacilities;
  bool _isLoading = true;
  String? _error;
  bool _isGeneratingPM = false;

  @override
  void initState() {
    super.initState();
    _loadContractDetails();
  }

  Future<void> _loadContractDetails() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final contractWithFacilities = await ref
          .read(contractsServiceProvider)
          .getContractWithFacilities(widget.contractId);

      setState(() {
        _contractWithFacilities = contractWithFacilities;
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
      body: _buildBody(authService),
      floatingActionButton: _buildFloatingActionButton(authService),
    );
  }

  Widget _buildBody(AuthService authService) {
    return CustomScrollView(
      slivers: [
        // App bar with contract title
        _buildSliverAppBar(),
        
        if (_isLoading) ...[
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          ),
        ] else if (_error != null) ...[
          SliverFillRemaining(
            child: _buildErrorState(),
          ),
        ] else if (_contractWithFacilities != null) ...[
          // Contract content
          SliverToBoxAdapter(
            child: _buildContractContent(authService),
          ),
        ],
      ],
    );
  }

  Widget _buildSliverAppBar() {
    final contract = _contractWithFacilities?.contract;
    
    return SliverAppBar(
      expandedHeight: 120,
      pinned: true,
      leading: IconButton(
        onPressed: () => context.go('/contracts'),
        icon: const Icon(Icons.arrow_back),
      ),
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          contract?.title ?? 'Contract Details',
          style: const TextStyle(fontSize: 16),
        ),
        titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
      ),
      actions: [
        if (ref.watch(authServiceProvider).isAdmin && contract != null) ...[
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit),
                    SizedBox(width: 8),
                    Text('Edit Contract'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'generate_pm',
                child: Row(
                  children: [
                    Icon(Icons.schedule),
                    SizedBox(width: 8),
                    Text('Generate PM Schedule'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: contract.isActive ? 'deactivate' : 'activate',
                child: Row(
                  children: [
                    Icon(contract.isActive ? Icons.pause : Icons.play_arrow),
                    const SizedBox(width: 8),
                    Text(contract.isActive ? 'Deactivate' : 'Activate'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete Contract', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildContractContent(AuthService authService) {
    final contract = _contractWithFacilities!.contract;
    final facilities = _contractWithFacilities!.facilities;
    
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status and expiry warning
          _buildStatusSection(contract),
          
          const SizedBox(height: AppTheme.spacingL),
          
          // Contract overview
          _buildOverviewSection(contract),
          
          const SizedBox(height: AppTheme.spacingL),
          
          // Facilities section
          _buildFacilitiesSection(facilities),
          
          const SizedBox(height: AppTheme.spacingL),
          
          // SLA section
          if (contract.criticalSlaDuration != null || contract.standardSlaDuration != null)
            _buildSLASection(contract),
          
          const SizedBox(height: AppTheme.spacingL),
          
          // Documents section
          if (contract.documentPaths.isNotEmpty)
            _buildDocumentsSection(contract),
          
          const SizedBox(height: AppTheme.spacingL),
          
          // PM Schedule section
          _buildPMScheduleSection(contract, authService),
          
          // Add bottom padding for FAB
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildStatusSection(Contract contract) {
    final isActive = contract.isCurrentlyActive;
    final daysUntilExpiry = contract.endDate.difference(DateTime.now()).inDays;
    final isExpiringSoon = daysUntilExpiry <= 30 && daysUntilExpiry >= 0;
    final isExpired = daysUntilExpiry < 0;
    
    return Row(
      children: [
        // Status badge
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingM,
            vertical: AppTheme.spacingS,
          ),
          decoration: BoxDecoration(
            color: isActive ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
            border: Border.all(
              color: isActive ? Colors.green.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? Colors.green : Colors.grey,
                ),
              ),
              const SizedBox(width: AppTheme.spacingS),
              Text(
                isActive ? 'ACTIVE' : 'INACTIVE',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: isActive ? Colors.green : Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(width: AppTheme.spacingM),
        
        // Expiry warning
        if (isExpired) ...[
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingM,
              vertical: AppTheme.spacingS,
            ),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error, size: 16, color: Colors.red),
                const SizedBox(width: AppTheme.spacingS),
                Text(
                  'EXPIRED',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ] else if (isExpiringSoon) ...[
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingM,
              vertical: AppTheme.spacingS,
            ),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning, size: 16, color: Colors.orange),
                const SizedBox(width: AppTheme.spacingS),
                Text(
                  'EXPIRES IN ${daysUntilExpiry}D',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOverviewSection(Contract contract) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: AppTheme.spacingS),
                Text(
                  'Contract Overview',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: AppTheme.spacingL),
            
            // Contract details grid
            _buildDetailRow('Type', contract.contractType.displayName, Icons.category),
            _buildDetailRow('Service Type', contract.serviceType, Icons.build),
            _buildDetailRow('Start Date', DateFormat('MMM dd, yyyy').format(contract.startDate), Icons.calendar_today),
            _buildDetailRow('End Date', DateFormat('MMM dd, yyyy').format(contract.endDate), Icons.event),
            _buildDetailRow('PM Frequency', contract.pmFrequency.displayName, Icons.refresh),
            
            if (contract.precedence > 0)
              _buildDetailRow('Precedence', contract.precedence.toString(), Icons.priority_high),
            
            if (contract.description != null && contract.description!.isNotEmpty) ...[
              const SizedBox(height: AppTheme.spacingM),
              Text(
                'Description',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppTheme.spacingS),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppTheme.spacingM),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
                child: Text(
                  contract.description!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFacilitiesSection(List<ContractFacilityInfo> facilities) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.location_city,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: AppTheme.spacingS),
                Text(
                  'Covered Facilities (${facilities.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: AppTheme.spacingM),
            
            ...facilities.map((facility) => Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.spacingS),
              child: Row(
                children: [
                  Icon(
                    Icons.business,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          facility.name,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (facility.address != null)
                          Text(
                            facility.address!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildSLASection(Contract contract) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: AppTheme.spacingS),
                Text(
                  'SLA Configuration',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: AppTheme.spacingM),
            
            if (contract.criticalSlaDuration != null)
              _buildSLAItem(
                'Critical Requests',
                '${contract.criticalSlaDuration!.inHours} hours',
                Colors.red,
                Icons.priority_high,
              ),
            
            if (contract.standardSlaDuration != null)
              _buildSLAItem(
                'Standard Requests',
                '${contract.standardSlaDuration!.inHours} hours',
                Colors.blue,
                Icons.schedule,
              ),
            
            const SizedBox(height: AppTheme.spacingM),
            
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  Expanded(
                    child: Text(
                      'These SLA hours override default values for requests at covered facilities.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSLAItem(String label, String value, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingS),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingS),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: AppTheme.spacingM),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsSection(Contract contract) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.description,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: AppTheme.spacingS),
                Text(
                  'Contract Documents (${contract.documentPaths.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: AppTheme.spacingM),
            
            ...contract.documentPaths.map((documentPath) {
              final filename = documentPath.split('/').last;
              return _buildDocumentItem(filename, documentPath);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentItem(String filename, String path) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
      child: InkWell(
        onTap: () => _downloadDocument(path),
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusS),
          ),
          child: Row(
            children: [
              Icon(
                _getDocumentIcon(filename),
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: Text(
                  filename,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              Icon(
                Icons.download,
                size: 16,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPMScheduleSection(Contract contract, AuthService authService) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: AppTheme.spacingS),
                Text(
                  'PM Schedule',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: AppTheme.spacingM),
            
            Text(
              'Preventive maintenance visits are scheduled ${contract.pmFrequency.displayName.toLowerCase()} for all covered facilities.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            
            const SizedBox(height: AppTheme.spacingL),
            
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.go('/pm'),
                    icon: const Icon(Icons.calendar_today),
                    label: const Text('View PM Schedule'),
                  ),
                ),
                
                if (authService.isAdmin) ...[
                  const SizedBox(width: AppTheme.spacingM),
                  FilledButton.icon(
                    onPressed: _isGeneratingPM ? null : _generatePMSchedule,
                    icon: _isGeneratingPM
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label: Text(_isGeneratingPM ? 'Generating...' : 'Generate'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingM),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
          const SizedBox(width: AppTheme.spacingS),
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton(AuthService authService) {
    if (!authService.isAdmin || _contractWithFacilities == null) {
      return const SizedBox.shrink();
    }
    
    return FloatingActionButton.extended(
      onPressed: () => _handleMenuAction('edit'),
      icon: const Icon(Icons.edit),
      label: const Text('Edit'),
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
            'Error Loading Contract',
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
            onPressed: _loadContractDetails,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  IconData _getDocumentIcon(String filename) {
    final extension = filename.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      default:
        return Icons.insert_drive_file;
    }
  }

  Future<void> _downloadDocument(String path) async {
    try {
      final signedUrl = await StorageHelper.instance.getSignedUrl(path);
      final uri = Uri.parse(signedUrl);
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to open document')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download document: $e')),
        );
      }
    }
  }

  Future<void> _generatePMSchedule() async {
    if (_contractWithFacilities?.contract.id == null) return;
    
    setState(() {
      _isGeneratingPM = true;
    });

    try {
      final pmService = ref.read(pmServiceProvider);
      final visits = await pmService.generateSchedule90d(
        contractId: _contractWithFacilities!.contract.id!,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Generated ${visits.length} PM visits for next 90 days'),
            action: SnackBarAction(
              label: 'View',
              onPressed: () => context.go('/pm'),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate PM schedule: $e')),
        );
      }
    } finally {
      setState(() {
        _isGeneratingPM = false;
      });
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'edit':
        // TODO: Navigate to edit contract page
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Edit contract feature coming soon')),
        );
        break;
      case 'generate_pm':
        _generatePMSchedule();
        break;
      case 'activate':
      case 'deactivate':
        _toggleContractStatus(action == 'activate');
        break;
      case 'delete':
        _showDeleteConfirmation();
        break;
    }
  }

  Future<void> _toggleContractStatus(bool activate) async {
    try {
      await ref.read(contractsServiceProvider).updateContractStatus(
        contractId: widget.contractId,
        isActive: activate,
      );
      
      // Reload contract details
      await _loadContractDetails();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Contract ${activate ? 'activated' : 'deactivated'} successfully'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update contract status: $e')),
        );
      }
    }
  }

  void _showDeleteConfirmation() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Contract'),
        content: const Text(
          'Are you sure you want to delete this contract? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteContract();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteContract() async {
    try {
      await ref.read(contractsServiceProvider).deleteContract(widget.contractId);
      
      if (mounted) {
        context.go('/contracts');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete contract: $e')),
        );
      }
    }
  }
}