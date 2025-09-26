import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../domain/models/company.dart';
import '../domain/onboarding_service.dart';

/// Company setup page for onboarding (step 1)
class CompanySetupPage extends ConsumerStatefulWidget {
  const CompanySetupPage({super.key});

  @override
  ConsumerState<CompanySetupPage> createState() => _CompanySetupPageState();
}

class _CompanySetupPageState extends ConsumerState<CompanySetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _domainController = TextEditingController();
  final _gstController = TextEditingController();
  final _cinController = TextEditingController();
  
  String _selectedBusinessType = BusinessTypes.manufacturing;

  @override
  void initState() {
    super.initState();
    
    // Initialize onboarding service
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(onboardingServiceProvider).initialize();
      
      // Pre-fill form if company data exists
      final company = ref.read(onboardingServiceProvider).company;
      if (company != null) {
        _nameController.text = company.name;
        _domainController.text = company.domain ?? '';
        _gstController.text = company.gst ?? '';
        _cinController.text = company.cin ?? '';
        _selectedBusinessType = company.businessType;
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _domainController.dispose();
    _gstController.dispose();
    _cinController.dispose();
    super.dispose();
  }

  Future<void> _handleNext() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final company = Company(
      name: _nameController.text.trim(),
      domain: _domainController.text.trim().isEmpty ? null : _domainController.text.trim(),
      gst: _gstController.text.trim().isEmpty ? null : _gstController.text.trim(),
      cin: _cinController.text.trim().isEmpty ? null : _cinController.text.trim(),
      businessType: _selectedBusinessType,
    );

    final onboardingService = ref.read(onboardingServiceProvider);
    
    try {
      await onboardingService.saveCompany(company);
      
      if (mounted) {
        context.go('/onboarding/facility-new');
      }
    } catch (e) {
      // Error is handled by the service and shown in UI
    }
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onboardingState = ref.watch(onboardingServiceProvider).state;
    
    // Show error message if present
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (onboardingState.error != null) {
        _showErrorMessage(onboardingState.error!);
        ref.read(onboardingServiceProvider).clearError();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Company Setup'),
        leading: IconButton(
          onPressed: () => context.go('/auth/sign-in'),
          icon: const Icon(Icons.logout),
          tooltip: 'Sign Out',
        ),
      ),
      body: Column(
        children: [
          // Progress indicator
          _buildProgressIndicator(),
          
          // Form content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              child: _buildForm(),
            ),
          ),
          
          // Bottom navigation
          _buildBottomNavigation(onboardingState.isLoading),
        ],
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
                'Step 1 of 3',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              Text(
                '33%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingS),
          LinearProgressIndicator(
            value: OnboardingStep.company.progress,
            backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          _buildHeader(),
          
          const SizedBox(height: AppTheme.spacingXL),
          
          // Company name
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Company Name *',
              hintText: 'Enter your company name',
              prefixIcon: Icon(Icons.business),
            ),
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your company name';
              }
              if (value.trim().length < 2) {
                return 'Company name must be at least 2 characters';
              }
              return null;
            },
          ),
          
          const SizedBox(height: AppTheme.spacingM),
          
          // Business type dropdown
          DropdownButtonFormField<String>(
            value: _selectedBusinessType,
            decoration: const InputDecoration(
              labelText: 'Business Type *',
              prefixIcon: Icon(Icons.category),
            ),
            items: BusinessTypes.all.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(type),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedBusinessType = value);
              }
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select a business type';
              }
              return null;
            },
          ),
          
          const SizedBox(height: AppTheme.spacingM),
          
          // Domain (optional)
          TextFormField(
            controller: _domainController,
            decoration: const InputDecoration(
              labelText: 'Website Domain (Optional)',
              hintText: 'e.g., company.com',
              prefixIcon: Icon(Icons.language),
            ),
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.url,
            validator: (value) {
              if (value != null && value.trim().isNotEmpty) {
                // Basic domain validation
                final domainPattern = RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$');
                if (!domainPattern.hasMatch(value.trim())) {
                  return 'Please enter a valid domain (e.g., company.com)';
                }
              }
              return null;
            },
          ),
          
          const SizedBox(height: AppTheme.spacingM),
          
          // GST number (optional)
          TextFormField(
            controller: _gstController,
            decoration: const InputDecoration(
              labelText: 'GST Number (Optional)',
              hintText: 'e.g., 22AAAAA0000A1Z5',
              prefixIcon: Icon(Icons.receipt),
            ),
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.characters,
            validator: (value) {
              if (!Company.isValidGST(value)) {
                return 'Please enter a valid GST number (15 characters)';
              }
              return null;
            },
          ),
          
          const SizedBox(height: AppTheme.spacingM),
          
          // CIN number (optional)
          TextFormField(
            controller: _cinController,
            decoration: const InputDecoration(
              labelText: 'CIN Number (Optional)',
              hintText: 'e.g., L74899DL2019PLC123456',
              prefixIcon: Icon(Icons.badge),
            ),
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.characters,
            onFieldSubmitted: (_) => _handleNext(),
            validator: (value) {
              if (!Company.isValidCIN(value)) {
                return 'Please enter a valid CIN number (21 characters)';
              }
              return null;
            },
          ),
          
          const SizedBox(height: AppTheme.spacingL),
          
          // Info card
          _buildInfoCard(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Company Information',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppTheme.spacingS),
        Text(
          'Tell us about your company to get started with CUERON SAAN. This information will be used to set up your account and manage your HVAC/R services.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Required Information',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingXS),
                Text(
                  'Only company name and business type are required. GST and CIN can be added later from your profile settings.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation(bool isLoading) {
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
              onPressed: () => context.go('/auth/sign-in'),
              child: const Text('Sign Out'),
            ),
          ),
          const SizedBox(width: AppTheme.spacingM),
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: isLoading ? null : _handleNext,
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Next: Add Facilities'),
            ),
          ),
        ],
      ),
    );
  }
}