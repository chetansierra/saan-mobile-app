import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../auth/domain/auth_service.dart';
import '../domain/pm_service.dart';
import '../domain/pm_visit.dart';
import '../domain/pm_checklist.dart';
import 'widgets/pm_checklist_item.dart';
import 'widgets/pm_photo_strip.dart';
import 'widgets/pm_signature_pad.dart';

/// PM Visit detail page with interactive checklist and completion workflow
class PMVisitDetailPage extends ConsumerStatefulWidget {
  const PMVisitDetailPage({
    super.key,
    required this.pmVisitId,
  });

  final String pmVisitId;

  @override
  ConsumerState<PMVisitDetailPage> createState() => _PMVisitDetailPageState();
}

class _PMVisitDetailPageState extends ConsumerState<PMVisitDetailPage> {
  PMVisit? _visit;
  PMChecklist? _checklist;
  List<String> _photoUrls = [];
  String? _signatureUrl;
  bool _isLoading = true;
  bool _isCompleting = false;
  String? _error;

  final TextEditingController _engineerNameController = TextEditingController();
  final TextEditingController _overallNotesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadVisitDetails();
  }

  @override
  void dispose() {
    _engineerNameController.dispose();
    _overallNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadVisitDetails() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final pmService = ref.read(pmServiceProvider);
      
      // Load visit details
      final visit = await pmService.getPMVisit(widget.pmVisitId);
      if (visit == null) {
        throw Exception('PM visit not found');
      }

      // Load or create checklist
      PMChecklist? checklist = await pmService.getPMChecklist(widget.pmVisitId);
      if (checklist == null) {
        // Create checklist template based on contract service type
        checklist = await pmService.createChecklistForVisit(
          pmVisitId: widget.pmVisitId,
          serviceType: 'HVAC', // TODO: Get from contract
          templateName: 'Standard PM Checklist',
        );
      }

      // Load photos and signature if visit is in progress or completed
      List<String> photoUrls = [];
      String? signatureUrl;
      
      if (visit.status != PMVisitStatus.scheduled) {
        // Load photos from storage
        photoUrls = await _loadPhotosFromStorage();
        
        // Load signature if exists
        signatureUrl = await _loadSignatureFromStorage();
      }

      setState(() {
        _visit = visit;
        _checklist = checklist;
        _photoUrls = photoUrls;
        _signatureUrl = signatureUrl;
        _isLoading = false;
        
        // Pre-populate engineer name if available
        if (visit.engineerName != null) {
          _engineerNameController.text = visit.engineerName!;
        }
        
        // Pre-populate notes if available
        if (visit.notes != null) {
          _overallNotesController.text = visit.notes!;
        }
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<List<String>> _loadPhotosFromStorage() async {
    try {
      // TODO: Implement photo listing from storage
      // For now, return empty list
      return [];
    } catch (e) {
      debugPrint('Failed to load photos: $e');
      return [];
    }
  }

  Future<String?> _loadSignatureFromStorage() async {
    try {
      // TODO: Check if signature exists and return signed URL
      return null;
    } catch (e) {
      debugPrint('Failed to load signature: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = ref.watch(authServiceProvider);
    
    return Scaffold(
      body: _buildBody(authService),
      bottomNavigationBar: _buildBottomActions(authService),
    );
  }

  Widget _buildBody(AuthService authService) {
    return CustomScrollView(
      slivers: [
        // App bar with visit info
        _buildSliverAppBar(),
        
        if (_isLoading) ...[
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          ),
        ] else if (_error != null) ...[
          SliverFillRemaining(
            child: _buildErrorState(),
          ),
        ] else if (_visit != null && _checklist != null) ...[
          // Visit content
          SliverToBoxAdapter(
            child: _buildVisitContent(authService),
          ),
        ],
      ],
    );
  }

  Widget _buildSliverAppBar() {
    final visit = _visit;
    
    return SliverAppBar(
      expandedHeight: 140,
      pinned: true,
      leading: IconButton(
        onPressed: () => context.go('/pm'),
        icon: const Icon(Icons.arrow_back),
      ),
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          visit?.id?.substring(0, 8) ?? 'PM Visit',
          style: const TextStyle(fontSize: 16),
        ),
        subtitle: visit != null 
            ? Text(
                DateFormat('MMM dd, yyyy HH:mm').format(visit.scheduledDate),
                style: const TextStyle(fontSize: 12),
              )
            : null,
        titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
      ),
      actions: [
        if (ref.watch(authServiceProvider).isAdmin && visit != null) ...[
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              if (visit.status == PMVisitStatus.scheduled) ...[
                const PopupMenuItem(
                  value: 'start',
                  child: Row(
                    children: [
                      Icon(Icons.play_arrow),
                      SizedBox(width: 8),
                      Text('Start Visit'),
                    ],
                  ),
                ),
              ],
              if (visit.status != PMVisitStatus.completed) ...[
                const PopupMenuItem(
                  value: 'cancel',
                  child: Row(
                    children: [
                      Icon(Icons.cancel, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Cancel Visit', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildVisitContent(AuthService authService) {
    final visit = _visit!;
    final checklist = _checklist!;
    
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Visit status and progress
          _buildStatusSection(visit),
          
          const SizedBox(height: AppTheme.spacingL),
          
          // Visit details
          _buildVisitDetailsSection(visit),
          
          const SizedBox(height: AppTheme.spacingL),
          
          // Engineer information (for in-progress/completed visits)
          if (visit.status != PMVisitStatus.scheduled)
            _buildEngineerSection(authService),
          
          const SizedBox(height: AppTheme.spacingL),
          
          // Checklist section
          _buildChecklistSection(checklist, authService),
          
          const SizedBox(height: AppTheme.spacingL),
          
          // Photo evidence section
          if (visit.status != PMVisitStatus.scheduled)
            _buildPhotoEvidenceSection(authService),
          
          const SizedBox(height: AppTheme.spacingL),
          
          // Signature section
          if (visit.status != PMVisitStatus.scheduled)
            _buildSignatureSection(authService),
          
          const SizedBox(height: AppTheme.spacingL),
          
          // Overall notes section
          if (visit.status != PMVisitStatus.scheduled)
            _buildOverallNotesSection(authService),
          
          // Add bottom padding for bottom bar
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildStatusSection(PMVisit visit) {
    final completionPercentage = _getCompletionPercentage();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status and progress
            Row(
              children: [
                // Status indicator
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingM,
                    vertical: AppTheme.spacingS,
                  ),
                  decoration: BoxDecoration(
                    color: Color(int.parse('0xFF${visit.status.colorHex.substring(1)}')).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                    border: Border.all(
                      color: Color(int.parse('0xFF${visit.status.colorHex.substring(1)}')).withOpacity(0.3),
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
                          color: Color(int.parse('0xFF${visit.status.colorHex.substring(1)}')),
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacingS),
                      Text(
                        visit.status.displayName.toUpperCase(),
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Color(int.parse('0xFF${visit.status.colorHex.substring(1)}')),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Spacer(),
                
                // Progress indicator
                if (visit.status == PMVisitStatus.inProgress) ...[
                  Text(
                    '${(completionPercentage * 100).round()}% Complete',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
            
            // Progress bar
            if (visit.status == PMVisitStatus.inProgress) ...[
              const SizedBox(height: AppTheme.spacingM),
              LinearProgressIndicator(
                value: completionPercentage,
                backgroundColor: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
            
            // Due status
            if (visit.isOverdue && visit.status != PMVisitStatus.completed) ...[
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
            ] else if (visit.isDueToday && visit.status != PMVisitStatus.completed) ...[
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
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVisitDetailsSection(PMVisit visit) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Visit Details',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            
            const SizedBox(height: AppTheme.spacingM),
            
            _buildDetailRow('Scheduled', DateFormat('MMM dd, yyyy HH:mm').format(visit.scheduledDate), Icons.schedule),
            if (visit.completedDate != null)
              _buildDetailRow('Completed', DateFormat('MMM dd, yyyy HH:mm').format(visit.completedDate!), Icons.check_circle),
            
            // TODO: Add facility and contract details when joins are available
            _buildDetailRow('Facility', 'Facility Name', Icons.location_city),
            _buildDetailRow('Contract', 'Contract Name', Icons.description),
          ],
        ),
      ),
    );
  }

  Widget _buildEngineerSection(AuthService authService) {
    final canEdit = authService.isAdmin && _visit!.status != PMVisitStatus.completed;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Engineer Information',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            
            const SizedBox(height: AppTheme.spacingM),
            
            TextFormField(
              controller: _engineerNameController,
              decoration: const InputDecoration(
                labelText: 'Engineer Name *',
                hintText: 'Enter your name',
              ),
              enabled: canEdit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChecklistSection(PMChecklist checklist, AuthService authService) {
    final canEdit = authService.isAdmin && _visit!.status != PMVisitStatus.completed;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Maintenance Checklist',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '${checklist.completedItems}/${checklist.totalItems}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: AppTheme.spacingM),
            
            // Progress indicator
            LinearProgressIndicator(
              value: checklist.completionPercentage,
              backgroundColor: Theme.of(context).colorScheme.outline.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                checklist.isComplete 
                    ? Colors.green
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
            
            const SizedBox(height: AppTheme.spacingL),
            
            // Checklist items
            ...checklist.items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              
              return PMChecklistItemWidget(
                item: item,
                onToggleCompletion: canEdit ? (completed) => _toggleChecklistItem(index, completed) : null,
                onNotesChanged: canEdit ? (notes) => _updateChecklistItemNotes(index, notes) : null,
                onPhotosChanged: canEdit ? (photos) => _updateChecklistItemPhotos(index, photos) : null,
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoEvidenceSection(AuthService authService) {
    final canEdit = authService.isAdmin && _visit!.status != PMVisitStatus.completed;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Photo Evidence',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            
            const SizedBox(height: AppTheme.spacingM),
            
            PMPhotoStrip(
              photoUrls: _photoUrls,
              onPhotosChanged: canEdit ? _updatePhotoEvidence : null,
              tenantId: ref.watch(authServiceProvider).tenantId!,
              pmVisitId: widget.pmVisitId,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignatureSection(AuthService authService) {
    final canEdit = authService.isAdmin && _visit!.status != PMVisitStatus.completed;
    final hasSignature = _signatureUrl != null;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Engineer Signature',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingS),
                if (hasSignature)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingS,
                      vertical: AppTheme.spacingXS,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    ),
                    child: Text(
                      'SIGNED',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.green,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: AppTheme.spacingM),
            
            PMSignaturePad(
              signatureUrl: _signatureUrl,
              onSignatureChanged: canEdit ? _updateSignature : null,
              tenantId: ref.watch(authServiceProvider).tenantId!,
              pmVisitId: widget.pmVisitId,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverallNotesSection(AuthService authService) {
    final canEdit = authService.isAdmin && _visit!.status != PMVisitStatus.completed;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Overall Notes',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            
            const SizedBox(height: AppTheme.spacingM),
            
            TextFormField(
              controller: _overallNotesController,
              decoration: const InputDecoration(
                hintText: 'Add any additional notes about this visit...',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
              enabled: canEdit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions(AuthService authService) {
    if (!authService.isAdmin || _visit == null) {
      return const SizedBox.shrink();
    }

    final visit = _visit!;
    final canComplete = _canCompleteVisit();
    
    return Container(
      padding: EdgeInsets.only(
        left: AppTheme.spacingL,
        right: AppTheme.spacingL,
        top: AppTheme.spacingM,
        bottom: MediaQuery.of(context).padding.bottom + AppTheme.spacingM,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (visit.status == PMVisitStatus.scheduled) ...[
            Expanded(
              child: FilledButton.icon(
                onPressed: _startVisit,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Visit'),
              ),
            ),
          ] else if (visit.status == PMVisitStatus.inProgress) ...[
            Expanded(
              child: FilledButton.icon(
                onPressed: canComplete && !_isCompleting ? _completeVisit : null,
                style: FilledButton.styleFrom(
                  backgroundColor: canComplete 
                      ? Colors.green
                      : Theme.of(context).disabledColor,
                ),
                icon: _isCompleting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle),
                label: Text(_isCompleting ? 'Completing...' : 'Complete Visit'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingM),
      child: Row(
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
            'Error Loading PM Visit',
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
            onPressed: _loadVisitDetails,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  double _getCompletionPercentage() {
    if (_checklist == null) return 0.0;
    return _checklist!.completionPercentage;
  }

  bool _canCompleteVisit() {
    return _checklist?.isComplete == true && 
           _signatureUrl != null && 
           _engineerNameController.text.trim().isNotEmpty;
  }

  void _toggleChecklistItem(int index, bool completed) {
    if (_checklist == null) return;
    
    setState(() {
      final updatedItems = List<PMChecklistItem>.from(_checklist!.items);
      updatedItems[index] = updatedItems[index].copyWith(
        isCompleted: completed,
        completedAt: completed ? DateTime.now() : null,
      );
      
      _checklist = _checklist!.copyWith(items: updatedItems);
    });
  }

  void _updateChecklistItemNotes(int index, String notes) {
    if (_checklist == null) return;
    
    setState(() {
      final updatedItems = List<PMChecklistItem>.from(_checklist!.items);
      updatedItems[index] = updatedItems[index].copyWith(notes: notes);
      
      _checklist = _checklist!.copyWith(items: updatedItems);
    });
  }

  void _updateChecklistItemPhotos(int index, List<String> photos) {
    if (_checklist == null) return;
    
    setState(() {
      final updatedItems = List<PMChecklistItem>.from(_checklist!.items);
      updatedItems[index] = updatedItems[index].copyWith(photoPaths: photos);
      
      _checklist = _checklist!.copyWith(items: updatedItems);
    });
  }

  void _updatePhotoEvidence(List<String> photoUrls) {
    setState(() {
      _photoUrls = photoUrls;
    });
  }

  void _updateSignature(String? signatureUrl) {
    setState(() {
      _signatureUrl = signatureUrl;
    });
  }

  Future<void> _startVisit() async {
    try {
      final pmService = ref.read(pmServiceProvider);
      await pmService.updatePMVisitStatus(
        pmVisitId: widget.pmVisitId,
        status: PMVisitStatus.inProgress,
        engineerName: _engineerNameController.text.trim(),
      );
      
      await _loadVisitDetails();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start visit: $e')),
        );
      }
    }
  }

  Future<void> _completeVisit() async {
    if (!_canCompleteVisit()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete all checklist items and provide signature'),
        ),
      );
      return;
    }

    setState(() {
      _isCompleting = true;
    });

    try {
      final pmService = ref.read(pmServiceProvider);
      
      await pmService.completePMVisit(
        pmVisitId: widget.pmVisitId,
        engineerName: _engineerNameController.text.trim(),
        checklistItems: _checklist!.items,
        overallNotes: _overallNotesController.text.trim().isNotEmpty 
            ? _overallNotesController.text.trim()
            : null,
        templateName: _checklist!.templateName,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PM visit completed successfully'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Navigate back to PM schedule
        context.go('/pm');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to complete visit: $e')),
        );
      }
    } finally {
      setState(() {
        _isCompleting = false;
      });
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'start':
        _startVisit();
        break;
      case 'cancel':
        _showCancelConfirmation();
        break;
    }
  }

  void _showCancelConfirmation() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel PM Visit'),
        content: const Text(
          'Are you sure you want to cancel this PM visit? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('No, Keep Visit'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _cancelVisit();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelVisit() async {
    try {
      final pmService = ref.read(pmServiceProvider);
      await pmService.cancelPMVisit(widget.pmVisitId);
      
      if (mounted) {
        context.go('/pm');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel visit: $e')),
        );
      }
    }
  }
}