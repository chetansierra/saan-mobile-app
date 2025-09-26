import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../auth/domain/models/user_profile.dart';

/// Picker for selecting an assignee from available admins
class AssigneePicker extends StatefulWidget {
  const AssigneePicker({
    super.key,
    required this.availableAssignees,
    required this.currentAssignee,
    required this.onAssigneeSelected,
    this.isLoading = false,
  });

  final List<UserProfile> availableAssignees;
  final String? currentAssignee;
  final Function(String? assigneeName) onAssigneeSelected;
  final bool isLoading;

  @override
  State<AssigneePicker> createState() => _AssigneePickerState();
}

class _AssigneePickerState extends State<AssigneePicker> {
  String? _selectedAssignee;

  @override
  void initState() {
    super.initState();
    _selectedAssignee = widget.currentAssignee;
  }

  @override
  void didUpdateWidget(AssigneePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentAssignee != oldWidget.currentAssignee) {
      _selectedAssignee = widget.currentAssignee;
    }
  }

  void _showAssigneePicker() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AssigneeBottomSheet(
        availableAssignees: widget.availableAssignees,
        currentAssignee: _selectedAssignee,
        onAssigneeSelected: (assignee) {
          setState(() => _selectedAssignee = assignee);
          widget.onAssigneeSelected(assignee);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.availableAssignees.isEmpty && !widget.isLoading) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.person_outline,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: AppTheme.spacingS),
            Text(
              'Assigned Engineer',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingM),
        
        if (widget.isLoading) ...[
          const Center(child: CircularProgressIndicator()),
        ] else ...[
          _buildAssigneeCard(),
        ],
      ],
    );
  }

  Widget _buildAssigneeCard() {
    final hasAssignee = _selectedAssignee != null && _selectedAssignee!.isNotEmpty;
    
    return Card(
      child: InkWell(
        onTap: _showAssigneePicker,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 20,
                backgroundColor: hasAssignee
                    ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                    : Theme.of(context).colorScheme.surfaceVariant,
                child: Icon(
                  hasAssignee ? Icons.person : Icons.person_add,
                  color: hasAssignee
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              
              const SizedBox(width: AppTheme.spacingM),
              
              // Assignee info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasAssignee ? _selectedAssignee! : 'Assign Engineer',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: hasAssignee
                            ? Theme.of(context).colorScheme.onSurface
                            : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingXS),
                    Text(
                      hasAssignee 
                          ? 'Tap to reassign'
                          : 'No engineer assigned yet',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Action icon
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet for selecting assignee
class _AssigneeBottomSheet extends StatefulWidget {
  const _AssigneeBottomSheet({
    required this.availableAssignees,
    required this.currentAssignee,
    required this.onAssigneeSelected,
  });

  final List<UserProfile> availableAssignees;
  final String? currentAssignee;
  final Function(String? assigneeName) onAssigneeSelected;

  @override
  State<_AssigneeBottomSheet> createState() => _AssigneeBottomSheetState();
}

class _AssigneeBottomSheetState extends State<_AssigneeBottomSheet> {
  String? _tempSelection;

  @override
  void initState() {
    super.initState();
    _tempSelection = widget.currentAssignee;
  }

  void _handleSelection(String? assigneeName) {
    setState(() => _tempSelection = assigneeName);
  }

  void _confirmSelection() {
    widget.onAssigneeSelected(_tempSelection);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
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
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingL),
            child: Row(
              children: [
                Text(
                  'Assign Engineer',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),
          
          // Assignee list
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              children: [
                // Unassign option
                _buildAssigneeOption(
                  name: null,
                  email: null,
                  isSelected: _tempSelection == null,
                  onTap: () => _handleSelection(null),
                ),
                
                const SizedBox(height: AppTheme.spacingM),
                
                // Available assignees
                ...widget.availableAssignees.map((assignee) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppTheme.spacingM),
                    child: _buildAssigneeOption(
                      name: assignee.name,
                      email: assignee.email,
                      isSelected: _tempSelection == assignee.name,
                      onTap: () => _handleSelection(assignee.name),
                    ),
                  );
                }),
              ],
            ),
          ),
          
          const Divider(height: 1),
          
          // Actions
          Padding(
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
                    onPressed: _confirmSelection,
                    child: const Text('Assign'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssigneeOption({
    required String? name,
    required String? email,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isUnassign = name == null;
    
    return Card(
      elevation: isSelected ? 2 : 0,
      color: isSelected
          ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
          : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 20,
                backgroundColor: isUnassign
                    ? Theme.of(context).colorScheme.surfaceVariant
                    : Theme.of(context).colorScheme.primary.withOpacity(0.1),
                child: Icon(
                  isUnassign ? Icons.person_remove : Icons.person,
                  color: isUnassign
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
              
              const SizedBox(width: AppTheme.spacingM),
              
              // User info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isUnassign ? 'Unassigned' : name!,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (!isUnassign) ...[
                      const SizedBox(height: AppTheme.spacingXS),
                      Text(
                        email!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              // Selection indicator
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}