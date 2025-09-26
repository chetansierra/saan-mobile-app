import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../auth/domain/auth_service.dart';
import '../../auth/domain/models/user_profile.dart';
import '../domain/models/request.dart';
import '../domain/requests_service.dart';
import 'widgets/assignee_picker.dart';
import 'widgets/attachment_gallery.dart';
import 'widgets/sla_badge.dart';
import 'widgets/status_timeline.dart';

/// Request detail page showing full request information and actions
/// Layout: Sticky Header | Top Row (SLA + Assignee) | Scrollable Sections | Sticky Bottom Bar
class RequestDetailPage extends ConsumerStatefulWidget {
  const RequestDetailPage({
    super.key,
    required this.requestId,
  });

  final String requestId;

  @override
  ConsumerState<RequestDetailPage> createState() => _RequestDetailPageState();
}

class _RequestDetailPageState extends ConsumerState<RequestDetailPage> {
  ServiceRequest? _request;
  List<UserProfile> _availableAssignees = [];
  bool _isLoading = true;
  bool _isUpdating = false;
  bool _isLoadingAssignees = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRequestData();
  }

  Future<void> _loadRequestData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final requestsService = ref.read(requestsServiceProvider);
      final request = await requestsService.getRequest(widget.requestId);
      
      if (request != null && mounted) {
        setState(() {
          _request = request;
          _isLoading = false;
        });
        
        // Load available assignees if user is admin
        final authService = ref.read(authServiceProvider);
        if (authService.isAdmin) {
          _loadAvailableAssignees();
        }
      } else {
        setState(() {
          _error = 'Request not found';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadAvailableAssignees() async {
    try {
      setState(() => _isLoadingAssignees = true);
      
      final requestsService = ref.read(requestsServiceProvider);
      final assignees = await requestsService.getAvailableAssignees();
      
      if (mounted) {
        setState(() {
          _availableAssignees = assignees;
          _isLoadingAssignees = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingAssignees = false);
      }
      debugPrint('Failed to load assignees: $e');
    }
  }

  Future<void> _onRefresh() async {
    await _loadRequestData();
  }

  Future<void> _updateStatus(RequestStatus newStatus) async {
    if (_request == null || _isUpdating) return;

    final authService = ref.read(authServiceProvider);
    if (!authService.isAdmin) {
      _showErrorMessage('Only administrators can update request status');
      return;
    }

    // Show confirmation dialog
    final confirmed = await _showStatusUpdateDialog(newStatus);
    if (!confirmed) return;

    try {
      setState(() => _isUpdating = true);

      String? eta;
      if (newStatus == RequestStatus.enRoute) {
        eta = await _showETADialog();
        if (eta == null) {
          setState(() => _isUpdating = false);
          return;
        }
      }

      final requestsService = ref.read(requestsServiceProvider);
      final updatedRequest = await requestsService.updateRequestStatus(
        requestId: widget.requestId,
        status: newStatus,
        eta: eta != null ? DateTime.tryParse(eta) : null,
      );

      if (mounted) {
        setState(() {
          _request = updatedRequest;
          _isUpdating = false;
        });
        _showSuccessMessage('Status updated to ${newStatus.displayName}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdating = false);
        _showErrorMessage('Failed to update status: ${e.toString()}');
      }
    }
  }

  Future<void> _assignEngineer(String? engineerName) async {
    if (_request == null || _isUpdating) return;

    final authService = ref.read(authServiceProvider);
    if (!authService.isAdmin) {
      _showErrorMessage('Only administrators can assign engineers');
      return;
    }

    try {
      setState(() => _isUpdating = true);

      final requestsService = ref.read(requestsServiceProvider);
      final updatedRequest = await requestsService.updateRequestStatus(
        requestId: widget.requestId,
        status: _request!.status,
        assignedEngineerName: engineerName,
      );

      if (mounted) {
        setState(() {
          _request = updatedRequest;
          _isUpdating = false;
        });
        
        final message = engineerName != null
            ? 'Assigned to $engineerName'
            : 'Engineer unassigned';
        _showSuccessMessage(message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdating = false);
        _showErrorMessage('Failed to assign engineer: ${e.toString()}');
      }
    }
  }

  Future<bool> _showStatusUpdateDialog(RequestStatus newStatus) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Change status from "${_request!.status.displayName}" to "${newStatus.displayName}"?'),
            const SizedBox(height: AppTheme.spacingM),
            if (newStatus == RequestStatus.enRoute)
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(AppTheme.radiusS),
                ),
                child: const Text(
                  'You will be prompted to set an estimated arrival time (ETA).',
                  style: TextStyle(fontSize: 12),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Update'),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }

  Future<String?> _showETADialog() async {
    final now = DateTime.now();
    final initialETA = now.add(const Duration(hours: 2));
    
    final date = await showDatePicker(
      context: context,
      initialDate: initialETA,
      firstDate: now,
      lastDate: now.add(const Duration(days: 7)),
    );
    
    if (date == null || !mounted) return null;
    
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialETA),
    );
    
    if (time == null) return null;
    
    final etaDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    
    return etaDateTime.toIso8601String();
  }

  void _showSuccessMessage(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
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
    final authService = ref.watch(authServiceProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Request #${widget.requestId.substring(0, 8)}'),
        leading: IconButton(
          onPressed: () => context.go('/requests'),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: _buildBody(authService),
    );
  }

  Widget _buildBody(AuthService authService) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_request == null) {
      return _buildNotFoundState();
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card with priority and SLA
            _buildHeaderCard(),
            
            const SizedBox(height: AppTheme.spacingL),
            
            // Status timeline
            _buildStatusSection(),
            
            const SizedBox(height: AppTheme.spacingL),
            
            // Request details
            _buildDetailsSection(),
            
            const SizedBox(height: AppTheme.spacingL),
            
            // Assignee section (admin only)
            if (authService.isAdmin) ...[
              AssigneePicker(
                availableAssignees: _availableAssignees,
                currentAssignee: _request!.assignedEngineerName,
                onAssigneeSelected: _assignEngineer,
                isLoading: _isLoadingAssignees,
              ),
              
              const SizedBox(height: AppTheme.spacingL),
            ],
            
            // Attachments
            if (_request!.mediaUrls.isNotEmpty) ...[
              AttachmentGallery(
                attachmentPaths: _request!.mediaUrls,
                isReadOnly: true,
              ),
              
              const SizedBox(height: AppTheme.spacingL),
            ],
            
            // Admin actions
            if (authService.isAdmin) ...[
              _buildActionSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _request!.description,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingS),
                      Row(
                        children: [
                          Icon(
                            Icons.location_city,
                            size: 16,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          ),
                          const SizedBox(width: AppTheme.spacingXS),
                          Expanded(
                            child: Text(
                              _request!.facilityName ?? 'Unknown Facility',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Priority badge
                if (_request!.priority == RequestPriority.critical)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingS,
                      vertical: AppTheme.spacingXS,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusS),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.priority_high,
                          size: 16,
                          color: Colors.red,
                        ),
                        const SizedBox(width: AppTheme.spacingXS),
                        Text(
                          'CRITICAL',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.red,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: AppTheme.spacingM),
            
            // SLA badge and timestamps
            Row(
              children: [
                if (_request!.slaDueAt != null) ...[
                  SLABadge(
                    slaDueAt: _request!.slaDueAt,
                    showBreachAlert: false,
                    size: SLABadgeSize.large,
                  ),
                ] else ...[
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
                    child: Text(
                      'Standard Priority',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Colors.blue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                
                const Spacer(),
                
                Text(
                  'Created ${DateFormat('MMM dd, yyyy HH:mm').format(_request!.createdAt ?? DateTime.now())}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
            
            // SLA breach alert
            if (_request!.slaDueAt != null && SlaUtils.isOverdue(_request!.slaDueAt)) ...[
              const SizedBox(height: AppTheme.spacingM),
              SLABadge(
                slaDueAt: _request!.slaDueAt,
                showBreachAlert: true,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: StatusTimeline(currentStatus: _request!.status),
      ),
    );
  }

  Widget _buildDetailsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Request Details',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            
            _buildDetailRow('Type', _request!.type.displayName),
            _buildDetailRow('Priority', _request!.priority.displayName),
            _buildDetailRow('Status', _request!.status.displayName),
            
            if (_request!.assignedEngineerName != null)
              _buildDetailRow('Assigned To', _request!.assignedEngineerName!),
            
            if (_request!.eta != null)
              _buildDetailRow(
                'ETA',
                DateFormat('MMM dd, yyyy HH:mm').format(_request!.eta!),
              ),
            
            if (_request!.preferredWindow != null)
              _buildDetailRow(
                'Preferred Window',
                '${DateFormat('MMM dd, HH:mm').format(_request!.preferredWindow!.startTime)} - '
                '${DateFormat('HH:mm').format(_request!.preferredWindow!.endTime)}',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
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

  Widget _buildActionSection() {
    final currentStatusIndex = RequestStatus.values.indexOf(_request!.status);
    final nextStatus = currentStatusIndex < RequestStatus.values.length - 1
        ? RequestStatus.values[currentStatusIndex + 1]
        : null;

    if (nextStatus == null) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Admin Actions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            
            FilledButton(
              onPressed: _isUpdating ? null : () => _updateStatus(nextStatus),
              child: _isUpdating
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('Mark as ${nextStatus.displayName}'),
            ),
          ],
        ),
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
            'Error Loading Request',
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
            onPressed: _loadRequestData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotFoundState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          ),
          const SizedBox(height: AppTheme.spacingL),
          Text(
            'Request Not Found',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            'The request you are looking for does not exist or has been removed.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingL),
          FilledButton(
            onPressed: () => context.go('/requests'),
            child: const Text('Back to Requests'),
          ),
        ],
      ),
    );
  }
}