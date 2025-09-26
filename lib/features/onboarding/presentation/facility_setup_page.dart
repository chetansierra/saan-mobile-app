import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../domain/models/company.dart';
import '../domain/onboarding_service.dart';

/// Facility setup page for onboarding (step 2)
class FacilitySetupPage extends ConsumerStatefulWidget {
  const FacilitySetupPage({super.key});

  @override
  ConsumerState<FacilitySetupPage> createState() => _FacilitySetupPageState();
}

class _FacilitySetupPageState extends ConsumerState<FacilitySetupPage> {
  @override
  Widget build(BuildContext context) {
    final onboardingState = ref.watch(onboardingServiceProvider).state;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Facility Setup'),
        leading: IconButton(
          onPressed: () => context.go('/onboarding/company'),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Column(
        children: [
          // Progress indicator
          _buildProgressIndicator(),
          
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  _buildHeader(),
                  
                  const SizedBox(height: AppTheme.spacingL),
                  
                  // Facilities list or empty state
                  Expanded(
                    child: onboardingState.facilities.isEmpty
                        ? _buildEmptyState()
                        : _buildFacilitiesList(onboardingState.facilities),
                  ),
                ],
              ),
            ),
          ),
          
          // Bottom navigation
          _buildBottomNavigation(onboardingState),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddFacilityDialog(),
        label: const Text('Add Facility'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Step 2 of 3',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              Text(
                '67%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingS),
          LinearProgressIndicator(
            value: OnboardingStep.facility.progress,
            backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Add Your Facilities',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppTheme.spacingS),
        Text(
          'Add the locations where CUERON SAAN will provide HVAC/R services. You need at least one facility to continue.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
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
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(50),
            ),
            child: Icon(
              Icons.location_city,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppTheme.spacingL),
          Text(
            'No Facilities Added',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            'Add your first facility to continue with the setup process.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingL),
          FilledButton.icon(
            onPressed: () => _showAddFacilityDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Add First Facility'),
          ),
        ],
      ),
    );
  }

  Widget _buildFacilitiesList(List<Facility> facilities) {
    return ListView.separated(
      itemCount: facilities.length,
      separatorBuilder: (context, index) => const SizedBox(height: AppTheme.spacingM),
      itemBuilder: (context, index) {
        final facility = facilities[index];
        return _buildFacilityCard(facility);
      },
    );
  }

  Widget _buildFacilityCard(Facility facility) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.location_city,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppTheme.spacingS),
                Expanded(
                  child: Text(
                    facility.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (action) {
                    switch (action) {
                      case 'edit':
                        _showEditFacilityDialog(facility);
                        break;
                      case 'delete':
                        _showDeleteConfirmation(facility);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit),
                        title: Text('Edit'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete),
                        title: Text('Delete'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingS),
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
                const SizedBox(width: AppTheme.spacingXS),
                Expanded(
                  child: Text(
                    facility.address,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ),
              ],
            ),
            if (facility.pocName != null) ...[
              const SizedBox(height: AppTheme.spacingXS),
              Row(
                children: [
                  Icon(
                    Icons.person,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                  const SizedBox(width: AppTheme.spacingXS),
                  Text(
                    facility.pocName!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  if (facility.pocPhone != null) ...[
                    Text(
                      ' • ${facility.pocPhone}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigation(OnboardingState state) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => context.go('/onboarding/company'),
              child: const Text('Back'),
            ),
          ),
          const SizedBox(width: AppTheme.spacingM),
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: state.isFacilitiesCompleted
                  ? () => context.go('/onboarding/review')
                  : null,
              child: Text(
                state.facilities.isEmpty
                    ? 'Add Facility to Continue'
                    : 'Next: Review & Complete',
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddFacilityDialog() {
    showDialog(
      context: context,
      builder: (context) => _FacilityDialog(
        title: 'Add Facility',
        onSave: (facility) async {
          final onboardingService = ref.read(onboardingServiceProvider);
          await onboardingService.saveFacility(facility);
        },
      ),
    );
  }

  void _showEditFacilityDialog(Facility facility) {
    showDialog(
      context: context,
      builder: (context) => _FacilityDialog(
        title: 'Edit Facility',
        facility: facility,
        onSave: (updatedFacility) async {
          final onboardingService = ref.read(onboardingServiceProvider);
          await onboardingService.updateFacility(facility.id!, updatedFacility);
        },
      ),
    );
  }

  void _showDeleteConfirmation(Facility facility) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Facility'),
        content: Text(
          'Are you sure you want to delete "${facility.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final onboardingService = ref.read(onboardingServiceProvider);
              await onboardingService.removeFacility(facility.id!);
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
}

/// Dialog for adding/editing facilities
class _FacilityDialog extends StatefulWidget {
  const _FacilityDialog({
    required this.title,
    required this.onSave,
    this.facility,
  });

  final String title;
  final Facility? facility;
  final Future<void> Function(Facility facility) onSave;

  @override
  State<_FacilityDialog> createState() => _FacilityDialogState();
}

class _FacilityDialogState extends State<_FacilityDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _pocNameController = TextEditingController();
  final _pocPhoneController = TextEditingController();
  final _pocEmailController = TextEditingController();
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    
    // Pre-fill form if editing
    if (widget.facility != null) {
      final facility = widget.facility!;
      _nameController.text = facility.name;
      _addressController.text = facility.address;
      _pocNameController.text = facility.pocName ?? '';
      _pocPhoneController.text = facility.pocPhone ?? '';
      _pocEmailController.text = facility.pocEmail ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _pocNameController.dispose();
    _pocPhoneController.dispose();
    _pocEmailController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final facility = Facility(
        id: widget.facility?.id,
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        pocName: _pocNameController.text.trim().isEmpty ? null : _pocNameController.text.trim(),
        pocPhone: _pocPhoneController.text.trim().isEmpty ? null : _pocPhoneController.text.trim(),
        pocEmail: _pocEmailController.text.trim().isEmpty ? null : _pocEmailController.text.trim(),
      );

      await widget.onSave(facility);
      
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Facility Name *',
                  hintText: 'e.g., Main Plant',
                ),
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter facility name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spacingM),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Address *',
                  hintText: 'Enter complete address',
                ),
                textInputAction: TextInputAction.next,
                maxLines: 2,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter facility address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spacingM),
              TextFormField(
                controller: _pocNameController,
                decoration: const InputDecoration(
                  labelText: 'Point of Contact (Optional)',
                  hintText: 'Contact person name',
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppTheme.spacingM),
              TextFormField(
                controller: _pocPhoneController,
                decoration: const InputDecoration(
                  labelText: 'Contact Phone (Optional)',
                  hintText: '+91-9876543210',
                ),
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (!Facility.isValidPhone(value)) {
                    return 'Please enter a valid phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spacingM),
              TextFormField(
                controller: _pocEmailController,
                decoration: const InputDecoration(
                  labelText: 'Contact Email (Optional)',
                  hintText: 'contact@facility.com',
                ),
                textInputAction: TextInputAction.done,
                keyboardType: TextInputType.emailAddress,
                onFieldSubmitted: (_) => _handleSave(),
                validator: (value) {
                  if (!Facility.isValidEmail(value)) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _handleSave,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.facility == null ? 'Add Facility' : 'Save Changes'),
        ),
      ],
    );
  }
}