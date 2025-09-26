import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/theme.dart';
import '../../../../core/storage/storage_helper.dart';
import '../../domain/pm_service.dart';

/// Photo strip widget for capturing and displaying PM evidence photos
class PMPhotoStrip extends ConsumerStatefulWidget {
  const PMPhotoStrip({
    super.key,
    required this.photoUrls,
    required this.tenantId,
    required this.pmVisitId,
    this.onPhotosChanged,
  });

  final List<String> photoUrls;
  final String tenantId;
  final String pmVisitId;
  final ValueChanged<List<String>>? onPhotosChanged;

  @override
  ConsumerState<PMPhotoStrip> createState() => _PMPhotoStripState();
}

class _PMPhotoStripState extends ConsumerState<PMPhotoStrip> {
  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploading = false;

  @override
  Widget build(BuildContext context) {
    final canEdit = widget.onPhotosChanged != null;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Photo grid
        if (widget.photoUrls.isEmpty) ...[
          _buildEmptyState(canEdit),
        ] else ...[
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: widget.photoUrls.length + (canEdit ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == widget.photoUrls.length && canEdit) {
                  return _buildAddPhotoCard();
                }
                
                final photoUrl = widget.photoUrls[index];
                return _buildPhotoCard(photoUrl, index, canEdit);
              },
            ),
          ),
        ],
        
        // Upload progress
        if (_isUploading) ...[
          const SizedBox(height: AppTheme.spacingM),
          Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: AppTheme.spacingS),
              Text(
                'Uploading photo...',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyState(bool canEdit) {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_camera_outlined,
            size: 32,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            'No photos attached',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          if (canEdit) ...[
            const SizedBox(height: AppTheme.spacingS),
            TextButton.icon(
              onPressed: _showPhotoSourceDialog,
              icon: const Icon(Icons.add_a_photo, size: 16),
              label: const Text('Add Photo'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAddPhotoCard() {
    return Container(
      width: 120,
      height: 120,
      margin: const EdgeInsets.only(right: AppTheme.spacingM),
      child: InkWell(
        onTap: _showPhotoSourceDialog,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
              style: BorderStyle.solid,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_a_photo,
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: AppTheme.spacingS),
              Text(
                'Add Photo',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoCard(String photoUrl, int index, bool canEdit) {
    return Container(
      width: 120,
      height: 120,
      margin: EdgeInsets.only(
        right: index < widget.photoUrls.length - 1 ? AppTheme.spacingM : 0,
      ),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Photo placeholder (TODO: Load actual image from signed URL)
            Container(
              width: double.infinity,
              height: double.infinity,
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.image,
                    size: 32,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
                  const SizedBox(height: AppTheme.spacingXS),
                  Text(
                    'Photo ${index + 1}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            
            // Overlay actions
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _viewPhoto(photoUrl, index),
                  child: Container(),
                ),
              ),
            ),
            
            // Remove button
            if (canEdit) ...[
              Positioned(
                top: 4,
                right: 4,
                child: InkWell(
                  onTap: () => _removePhoto(index),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
            
            // View indicator
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.zoom_in,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPhotoSourceDialog() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.of(context).pop();
                _capturePhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.of(context).pop();
                _capturePhoto(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel),
              title: const Text('Cancel'),
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _capturePhoto(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _isUploading = true;
        });

        // Read image bytes
        final Uint8List imageBytes = await image.readAsBytes();
        
        // Generate filename
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final filename = 'photo_${timestamp}.jpg';
        
        // Upload to storage
        final pmService = ref.read(pmServiceProvider);
        final storagePath = await pmService.uploadPMAttachment(
          pmVisitId: widget.pmVisitId,
          filename: filename,
          bytes: imageBytes,
        );
        
        // Get signed URL for preview
        final signedUrl = await StorageHelper.instance.getSignedUrl(storagePath);
        
        // Update photo list
        final updatedUrls = [...widget.photoUrls, signedUrl];
        widget.onPhotosChanged?.call(updatedUrls);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photo uploaded successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload photo: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _removePhoto(int index) {
    showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Photo'),
        content: const Text('Are you sure you want to remove this photo? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) {
        final updatedUrls = [...widget.photoUrls];
        updatedUrls.removeAt(index);
        widget.onPhotosChanged?.call(updatedUrls);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo removed'),
          ),
        );
      }
    });
  }

  void _viewPhoto(String photoUrl, int index) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            // Full screen photo viewer
            Center(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                child: Card(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Photo placeholder (TODO: Load actual image)
                      Container(
                        height: 300,
                        width: double.infinity,
                        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.image,
                              size: 64,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                            ),
                            const SizedBox(height: AppTheme.spacingM),
                            Text(
                              'Photo ${index + 1}',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Photo actions
                      Padding(
                        padding: const EdgeInsets.all(AppTheme.spacingM),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                Navigator.of(context).pop();
                                // TODO: Implement download functionality
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Download feature coming soon')),
                                );
                              },
                              icon: const Icon(Icons.download),
                              label: const Text('Download'),
                            ),
                            TextButton.icon(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close),
                              label: const Text('Close'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Close button
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 32,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withOpacity(0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}