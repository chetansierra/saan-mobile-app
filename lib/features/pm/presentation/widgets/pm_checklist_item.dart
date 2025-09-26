import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../domain/pm_checklist.dart';

/// Interactive PM checklist item widget with expandable details
class PMChecklistItemWidget extends StatefulWidget {
  const PMChecklistItemWidget({
    super.key,
    required this.item,
    this.onToggleCompletion,
    this.onNotesChanged,
    this.onPhotosChanged,
  });

  final PMChecklistItem item;
  final ValueChanged<bool>? onToggleCompletion;
  final ValueChanged<String>? onNotesChanged;
  final ValueChanged<List<String>>? onPhotosChanged;

  @override
  State<PMChecklistItemWidget> createState() => _PMChecklistItemWidgetState();
}

class _PMChecklistItemWidgetState extends State<PMChecklistItemWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;
  bool _isExpanded = false;
  
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    
    // Initialize notes controller
    _notesController.text = widget.item.notes ?? '';
    _notesController.addListener(_onNotesChanged);
    
    // Auto-expand if item has content or is incomplete critical item
    if (widget.item.notes?.isNotEmpty == true || 
        widget.item.photoPaths.isNotEmpty ||
        (widget.item.priority == ChecklistItemPriority.critical && !widget.item.isCompleted)) {
      _isExpanded = true;
      _animationController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _notesController.removeListener(_onNotesChanged);
    _notesController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(PMChecklistItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.notes != widget.item.notes) {
      _notesController.text = widget.item.notes ?? '';
    }
  }

  void _onNotesChanged() {
    if (widget.onNotesChanged != null) {
      widget.onNotesChanged!(_notesController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = widget.onToggleCompletion != null;
    
    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
      child: Column(
        children: [
          // Main item row
          InkWell(
            onTap: () => _toggleExpanded(),
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Priority indicator
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Color(int.parse('0xFF${widget.item.priority.colorHex.substring(1)}')),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  
                  const SizedBox(width: AppTheme.spacingM),
                  
                  // Checkbox
                  Checkbox(
                    value: widget.item.isCompleted,
                    onChanged: canEdit ? (value) {
                      if (value != null) {
                        widget.onToggleCompletion!(value);
                      }
                    } : null,
                  ),
                  
                  const SizedBox(width: AppTheme.spacingM),
                  
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          widget.item.title,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            decoration: widget.item.isCompleted 
                                ? TextDecoration.lineThrough
                                : null,
                            color: widget.item.isCompleted
                                ? Theme.of(context).colorScheme.onSurface.withOpacity(0.6)
                                : null,
                          ),
                        ),
                        
                        const SizedBox(height: AppTheme.spacingXS),
                        
                        // Description
                        Text(
                          widget.item.description,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            decoration: widget.item.isCompleted 
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        
                        // Status indicators
                        if (widget.item.isCompleted || widget.item.notes?.isNotEmpty == true || widget.item.photoPaths.isNotEmpty) ...[
                          const SizedBox(height: AppTheme.spacingS),
                          Wrap(
                            spacing: AppTheme.spacingS,
                            children: [
                              // Completion indicator
                              if (widget.item.isCompleted)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppTheme.spacingS,
                                    vertical: AppTheme.spacingXS,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.check_circle,
                                        size: 12,
                                        color: Colors.green,
                                      ),
                                      const SizedBox(width: AppTheme.spacingXS),
                                      Text(
                                        'Completed',
                                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                          color: Colors.green,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              
                              // Notes indicator
                              if (widget.item.notes?.isNotEmpty == true)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppTheme.spacingS,
                                    vertical: AppTheme.spacingXS,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.note,
                                        size: 12,
                                        color: Colors.blue,
                                      ),
                                      const SizedBox(width: AppTheme.spacingXS),
                                      Text(
                                        'Notes',
                                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                          color: Colors.blue,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              
                              // Photos indicator
                              if (widget.item.photoPaths.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppTheme.spacingS,
                                    vertical: AppTheme.spacingXS,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.photo_camera,
                                        size: 12,
                                        color: Colors.orange,
                                      ),
                                      const SizedBox(width: AppTheme.spacingXS),
                                      Text(
                                        '${widget.item.photoPaths.length}',
                                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                          color: Colors.orange,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  // Expand/collapse indicator
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Expandable content
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.only(
                left: AppTheme.spacingL + 4 + AppTheme.spacingM + 24 + AppTheme.spacingM,
                right: AppTheme.spacingL,
                bottom: AppTheme.spacingL,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: AppTheme.spacingM),
                  
                  // Notes section
                  Text(
                    'Notes',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingS),
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      hintText: 'Add notes for this item...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    maxLines: 3,
                    enabled: canEdit,
                  ),
                  
                  const SizedBox(height: AppTheme.spacingM),
                  
                  // Photos section
                  Row(
                    children: [
                      Text(
                        'Photos',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      if (canEdit) ...[
                        IconButton(
                          onPressed: _addPhoto,
                          icon: const Icon(Icons.add_a_photo),
                          iconSize: 20,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingS),
                  
                  // Photo grid
                  if (widget.item.photoPaths.isEmpty) ...[
                    Container(
                      height: 80,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(AppTheme.radiusS),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'No photos attached',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    SizedBox(
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: widget.item.photoPaths.length,
                        itemBuilder: (context, index) {
                          final photoPath = widget.item.photoPaths[index];
                          return _buildPhotoThumbnail(photoPath, index);
                        },
                      ),
                    ),
                  ],
                  
                  // Completion timestamp
                  if (widget.item.isCompleted && widget.item.completedAt != null) ...[
                    const SizedBox(height: AppTheme.spacingM),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                        const SizedBox(width: AppTheme.spacingS),
                        Text(
                          'Completed: ${_formatDateTime(widget.item.completedAt!)}',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoThumbnail(String photoPath, int index) {
    return Container(
      width: 80,
      height: 80,
      margin: EdgeInsets.only(
        right: index < widget.item.photoPaths.length - 1 ? AppTheme.spacingS : 0,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
        child: Stack(
          children: [
            // TODO: Load actual image from signed URL
            Container(
              width: double.infinity,
              height: double.infinity,
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
              child: const Icon(Icons.image),
            ),
            
            // Remove button
            if (widget.onPhotosChanged != null) ...[
              Positioned(
                top: 4,
                right: 4,
                child: InkWell(
                  onTap: () => _removePhoto(index),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  void _addPhoto() {
    // TODO: Implement photo capture/selection
    // For now, add a placeholder
    final newPhotos = [...widget.item.photoPaths, 'photo_${DateTime.now().millisecondsSinceEpoch}'];
    widget.onPhotosChanged?.call(newPhotos);
  }

  void _removePhoto(int index) {
    final newPhotos = [...widget.item.photoPaths];
    newPhotos.removeAt(index);
    widget.onPhotosChanged?.call(newPhotos);
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

/// Extension to add color to ChecklistItemPriority
extension ChecklistItemPriorityColor on ChecklistItemPriority {
  String get colorHex {
    switch (this) {
      case ChecklistItemPriority.low:
        return '#4CAF50'; // Green
      case ChecklistItemPriority.normal:
        return '#2196F3'; // Blue
      case ChecklistItemPriority.high:
        return '#FF9800'; // Orange
      case ChecklistItemPriority.critical:
        return '#F44336'; // Red
    }
  }
}