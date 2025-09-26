import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../core/ui/connection_indicator.dart';
import '../../auth/domain/auth_service.dart';
import '../../auth/domain/models/user_profile.dart';
import '../domain/models/request.dart';
import '../domain/requests_service.dart';
import '../realtime/requests_realtime.dart';
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
    
    return RequestsRealtimeHook(
      child: Scaffold(
      body: Column(
        children: [
          // Sticky Header
          _buildStickyHeader(context),
          
          // Main Content (expandable to fill remaining space)
          Expanded(
            child: _buildMainContent(authService),
          ),
          
          // Sticky Bottom Bar (for admins only)
          if (authService.isAdmin && _request != null) 
            _buildStickyBottomBar(context),
        ],
      ),
      ),
    );
  }

  /// Build sticky header with Request ID, Status chip, and Priority chip
  Widget _buildStickyHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + AppTheme.spacingM,
        left: AppTheme.spacingL,
        right: AppTheme.spacingL,
        bottom: AppTheme.spacingM,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back button
          IconButton(
            onPressed: () => context.go('/requests'),
            icon: const Icon(Icons.arrow_back),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          
          const SizedBox(width: AppTheme.spacingM),
          
          // Request ID
          Text(
            'Request #${widget.requestId.substring(0, 8)}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const Spacer(),
          
          // Status and Priority chips
          if (_request != null) ...[
            // Status chip
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingS,
                vertical: AppTheme.spacingXS,
              ),
              decoration: BoxDecoration(
                color: Color(int.parse('0xFF${_request!.status.colorHex.substring(1)}')).withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusS),
                border: Border.all(
                  color: Color(int.parse('0xFF${_request!.status.colorHex.substring(1)}')).withOpacity(0.3),
                ),
              ),
              child: Text(
                _request!.status.displayName.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Color(int.parse('0xFF${_request!.status.colorHex.substring(1)}')),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            
            const SizedBox(width: AppTheme.spacingS),
            
            // Priority chip
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingS,
                vertical: AppTheme.spacingXS,
              ),
              decoration: BoxDecoration(
                color: _request!.priority == RequestPriority.critical 
                    ? Colors.red.withOpacity(0.1)
                    : Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusS),
                border: Border.all(
                  color: _request!.priority == RequestPriority.critical 
                      ? Colors.red.withOpacity(0.3)
                      : Colors.blue.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_request!.priority == RequestPriority.critical) ...[
                    Icon(
                      Icons.priority_high,
                      size: 14,
                      color: Colors.red,
                    ),
                    const SizedBox(width: AppTheme.spacingXS),
                  ],
                  Text(
                    _request!.priority.displayName.toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: _request!.priority == RequestPriority.critical 
                          ? Colors.red
                          : Colors.blue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build main content area
  Widget _buildMainContent(AuthService authService) {
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
      child: Column(
        children: [
          // Top row: SLA Badge and Assignee Picker
          _buildTopRow(authService),
          
          // Scrollable sections
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1) Details Section
                  _buildDetailsSection(),
                  
                  const SizedBox(height: AppTheme.spacingL),
                  
                  // 2) Attachments Section
                  if (_request!.mediaUrls.isNotEmpty) ...[
                    _buildAttachmentsSection(),
                    const SizedBox(height: AppTheme.spacingL),
                  ],
                  
                  // 3) Timeline Section
                  _buildTimelineSection(),
                  
                  const SizedBox(height: AppTheme.spacingL),
                  
                  // 4) Notes Section (Optional)
                  _buildNotesSection(),
                  
                  // Add bottom padding for floating bottom bar
                  if (authService.isAdmin)
                    const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build top row with SLA Badge and Assignee Picker
  Widget _buildTopRow(AuthService authService) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // SLA Badge
          if (_request!.slaDueAt != null) ...[
            Expanded(
              child: SLABadge(
                slaDueAt: _request!.slaDueAt,
                showBreachAlert: SlaUtils.isOverdue(_request!.slaDueAt),
                size: SLABadgeSize.large,
              ),
            ),
          ] else ...[
            Expanded(
              child: Container(
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
                    Icon(Icons.schedule, color: Colors.blue, size: 16),
                    const SizedBox(width: AppTheme.spacingXS),
                    Text(
                      'Standard Priority',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Colors.blue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          
          const SizedBox(width: AppTheme.spacingL),
          
          // Assignee Picker (for admins only)
          if (authService.isAdmin) ...[
            Expanded(
              child: _buildCompactAssigneePicker(),
            ),
          ] else if (_request!.assignedEngineerName != null) ...[
            // Show assigned engineer for requesters
            Expanded(
              child: _buildAssignedEngineerDisplay(),
            ),
          ] else ...[
            const Expanded(child: SizedBox.shrink()),
          ],
        ],
      ),
    );
  }

  /// Build compact assignee picker for top row
  Widget _buildCompactAssigneePicker() {
    final hasAssignee = _request!.assignedEngineerName != null && _request!.assignedEngineerName!.isNotEmpty;
    
    return InkWell(
      onTap: _showAssigneePickerBottomSheet,
      borderRadius: BorderRadius.circular(AppTheme.radiusS),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingM,
          vertical: AppTheme.spacingS,
        ),
        decoration: BoxDecoration(
          color: hasAssignee
              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
              : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(AppTheme.radiusS),
          border: Border.all(
            color: hasAssignee
                ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
                : Theme.of(context).colorScheme.outline.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasAssignee ? Icons.person : Icons.person_add,
              color: hasAssignee
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              size: 16,
            ),
            const SizedBox(width: AppTheme.spacingXS),
            Expanded(
              child: Text(
                hasAssignee ? _request!.assignedEngineerName! : 'Assign Engineer',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: hasAssignee
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              color: hasAssignee
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  /// Build assigned engineer display for requesters
  Widget _buildAssignedEngineerDisplay() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingS,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.person,
            color: Theme.of(context).colorScheme.primary,
            size: 16,
          ),
          const SizedBox(width: AppTheme.spacingXS),
          Expanded(
            child: Text(
              _request!.assignedEngineerName!,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Build details section: facility, createdAt, createdBy, description
  Widget _buildDetailsSection() {
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
                  'Request Details',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: AppTheme.spacingL),
            
            // Description with better typography
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTheme.spacingM),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
              child: Text(
                _request!.description,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  height: 1.5,
                ),
              ),
            ),
            
            const SizedBox(height: AppTheme.spacingL),
            
            // Details grid
            _buildDetailRow('Facility', _request!.facilityName ?? 'Unknown Facility', Icons.location_city),
            _buildDetailRow('Created', DateFormat('MMM dd, yyyy HH:mm').format(_request!.createdAt ?? DateTime.now()), Icons.schedule),
            _buildDetailRow('Type', _request!.type.displayName, Icons.category),
            
            if (_request!.preferredWindow != null)
              _buildDetailRow(
                'Preferred Window',
                '${DateFormat('MMM dd, HH:mm').format(_request!.preferredWindow!.startTime)} - '
                '${DateFormat('HH:mm').format(_request!.preferredWindow!.endTime)}',
                Icons.access_time,
              ),
            
            if (_request!.eta != null)
              _buildDetailRow(
                'ETA',
                DateFormat('MMM dd, yyyy HH:mm').format(_request!.eta!),
                Icons.schedule_send,
              ),
          ],
        ),
      ),
    );
  }

  /// Build attachments section with gallery
  Widget _buildAttachmentsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: AttachmentGallery(
          attachmentPaths: _request!.mediaUrls,
          isReadOnly: true,
        ),
      ),
    );
  }

  /// Build timeline section showing status progression
  Widget _buildTimelineSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.timeline,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: AppTheme.spacingS),
                Text(
                  'Status Timeline',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: AppTheme.spacingM),
            
            StatusTimeline(currentStatus: _request!.status),
          ],
        ),
      ),
    );
  }

  /// Build notes section (optional admin notes from status changes)
  Widget _buildNotesSection() {
    // For now, this is a placeholder for future admin notes functionality
    // In a real implementation, you would fetch notes from the database
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.note_alt_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: AppTheme.spacingS),
                Text(
                  'Admin Notes',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: AppTheme.spacingM),
            
            // Placeholder for notes
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTheme.spacingL),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.note_add,
                    size: 48,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                  ),
                  const SizedBox(height: AppTheme.spacingS),
                  Text(
                    'No admin notes available',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      fontStyle: FontStyle.italic,
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

  /// Build enhanced detail row with icon
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

  /// Build sticky bottom bar with admin actions
  Widget _buildStickyBottomBar(BuildContext context) {
    final currentStatusIndex = RequestStatus.values.indexOf(_request!.status);
    final nextStatus = currentStatusIndex < RequestStatus.values.length - 1
        ? RequestStatus.values[currentStatusIndex + 1]
        : null;

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
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // Update Status button
          if (nextStatus != null) ...[
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: _isUpdating ? null : () => _updateStatus(nextStatus),
                child: _isUpdating
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text('Mark as ${nextStatus.displayName}'),
              ),
            ),
            
            const SizedBox(width: AppTheme.spacingM),
          ],
          
          // Assign Engineer button
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isUpdating ? null : _showAssigneePickerBottomSheet,
              icon: const Icon(Icons.person_add, size: 18),
              label: const Text('Assign Engineer'),
            ),
          ),
        ],
      ),
    );
  }

  /// Show assignee picker bottom sheet
  void _showAssigneePickerBottomSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => AssigneePicker(
        availableAssignees: _availableAssignees,
        currentAssignee: _request!.assignedEngineerName,
        onAssigneeSelected: _assignEngineer,
        isLoading: _isLoadingAssignees,
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