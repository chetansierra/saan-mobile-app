import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../domain/models/company.dart';
import '../domain/onboarding_service.dart';

/// Review and complete onboarding page (step 3)
class OnboardingReviewPage extends ConsumerStatefulWidget {
  const OnboardingReviewPage({super.key});

  @override
  ConsumerState<OnboardingReviewPage> createState() => _OnboardingReviewPageState();
}

class _OnboardingReviewPageState extends ConsumerState<OnboardingReviewPage> {
  bool _isCompleting = false;

  Future<void> _handleComplete() async {
    setState(() => _isCompleting = true);
    
    try {
      final onboardingService = ref.read(onboardingServiceProvider);
      await onboardingService.completeOnboarding();
      
      // Navigation will be handled automatically by router guards
      if (mounted) {
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error completing onboarding: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCompleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final onboardingState = ref.watch(onboardingServiceProvider).state;
    
    if (!onboardingState.isOnboardingCompleted) {
      // Redirect back if requirements not met
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/onboarding/company');
      });
      
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review & Complete'),
        leading: IconButton(
          onPressed: () => context.go('/onboarding/facility-new'),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Column(
        children: [
          // Progress indicator
          _buildProgressIndicator(),
          
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  _buildHeader(),
                  
                  const SizedBox(height: AppTheme.spacingL),
                  
                  // Company summary
                  _buildCompanySummary(onboardingState.company!),
                  
                  const SizedBox(height: AppTheme.spacingL),
                  
                  // Facilities summary
                  _buildFacilitiesSummary(onboardingState.facilities),
                  
                  const SizedBox(height: AppTheme.spacingL),
                  
                  // Next steps
                  _buildNextSteps(),
                ],
              ),
            ),
          ),
          
          // Bottom navigation
          _buildBottomNavigation(),
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
                'Step 3 of 3',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              Text(
                '100%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingS),
          LinearProgressIndicator(
            value: OnboardingStep.review.progress,
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
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
              child: Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                size: 32,
              ),
            ),
            const SizedBox(width: AppTheme.spacingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Almost Done!',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingXS),
                  Text(
                    'Review your information and complete your setup.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompanySummary(Company company) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.business,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppTheme.spacingS),
                Text(
                  'Company Information',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => context.go('/onboarding/company'),
                  child: const Text('Edit'),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingM),
            _buildInfoRow('Company Name', company.name),
            _buildInfoRow('Business Type', company.businessType),
            if (company.domain != null)
              _buildInfoRow('Domain', company.domain!),
            if (company.gst != null)
              _buildInfoRow('GST Number', company.gst!),
            if (company.cin != null)
              _buildInfoRow('CIN Number', company.cin!),
          ],
        ),
      ),
    );
  }

  Widget _buildFacilitiesSummary(List<Facility> facilities) {
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
                ),
                const SizedBox(width: AppTheme.spacingS),
                Text(
                  'Facilities (${facilities.length})',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => context.go('/onboarding/facility-new'),
                  child: const Text('Edit'),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingM),
            ...facilities.map((facility) => _buildFacilityItem(facility)),
          ],
        ),
      ),
    );
  }

  Widget _buildFacilityItem(Facility facility) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingM),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  facility.name,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingXS),
                Text(
                  facility.address,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                if (facility.pocName != null) ...[
                  const SizedBox(height: AppTheme.spacingXS),
                  Text(
                    'Contact: ${facility.pocName}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingS),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextSteps() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.checklist,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppTheme.spacingS),
                Text(
                  'What\'s Next?',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingM),
            _buildNextStepItem(
              Icons.dashboard,
              'Access Your Dashboard',
              'View KPIs, open requests, and upcoming maintenance schedules',
            ),
            _buildNextStepItem(
              Icons.build,
              'Submit Service Requests',
              'Create on-demand requests for your HVAC/R systems',
            ),
            _buildNextStepItem(
              Icons.description,
              'Explore Contracts',
              'Browse AMC/CMC packages for ongoing maintenance',
            ),
            _buildNextStepItem(
              Icons.people,
              'Invite Team Members',
              'Add more users to your organization (coming soon)',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNextStepItem(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingM),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingS),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(AppTheme.radiusS),
            ),
            child: Icon(
              icon,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: AppTheme.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingXS),
                Text(
                  description,
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

  Widget _buildBottomNavigation() {
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
              onPressed: () => context.go('/onboarding/facility-new'),
              child: const Text('Back'),
            ),
          ),
          const SizedBox(width: AppTheme.spacingM),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: _isCompleting ? null : _handleComplete,
              icon: _isCompleting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(_isCompleting ? 'Setting up...' : 'Complete Setup'),
            ),
          ),
        ],
      ),
    );
  }
}