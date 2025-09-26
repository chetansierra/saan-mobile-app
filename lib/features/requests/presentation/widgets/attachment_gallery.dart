import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme.dart';
import '../../../../core/storage/storage_helper.dart';

/// Gallery widget for displaying request attachments with preview and download
class AttachmentGallery extends StatefulWidget {
  const AttachmentGallery({
    super.key,
    required this.attachmentPaths,
    this.onRemove,
    this.isReadOnly = false,
  });

  final List<String> attachmentPaths;
  final Function(String path)? onRemove;
  final bool isReadOnly;

  @override
  State<AttachmentGallery> createState() => _AttachmentGalleryState();
}

class _AttachmentGalleryState extends State<AttachmentGallery> {
  final Map<String, String> _signedUrls = {};
  final Map<String, bool> _loadingUrls = {};

  @override
  void initState() {
    super.initState();
    _loadSignedUrls();
  }

  @override
  void didUpdateWidget(AttachmentGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.attachmentPaths != oldWidget.attachmentPaths) {
      _loadSignedUrls();
    }
  }

  Future<void> _loadSignedUrls() async {
    for (final path in widget.attachmentPaths) {
      if (!_signedUrls.containsKey(path)) {
        setState(() => _loadingUrls[path] = true);
        
        try {
          final signedUrl = await StorageHelper.instance.getSignedUrl(
            path: path,
            expiresIn: 3600, // 1 hour
          );
          
          if (mounted) {
            setState(() {
              _signedUrls[path] = signedUrl;
              _loadingUrls[path] = false;
            });
          }
        } catch (e) {
          if (mounted) {
            setState(() => _loadingUrls[path] = false);
          }
          debugPrint('Failed to get signed URL for $path: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.attachmentPaths.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.attach_file,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: AppTheme.spacingS),
            Text(
              'Attachments (${widget.attachmentPaths.length})',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingM),
        
        _buildAttachmentGrid(),
      ],
    );
  }

  Widget _buildAttachmentGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppTheme.spacingM,
        mainAxisSpacing: AppTheme.spacingM,
        childAspectRatio: 1.2,
      ),
      itemCount: widget.attachmentPaths.length,
      itemBuilder: (context, index) {
        final path = widget.attachmentPaths[index];
        return _buildAttachmentCard(path);
      },
    );
  }

  Widget _buildAttachmentCard(String path) {
    final fileName = path.split('/').last;
    final fileType = StorageHelper.getFileType(fileName);
    final isLoading = _loadingUrls[path] ?? false;
    final signedUrl = _signedUrls[path];

    return Card(
      child: InkWell(
        onTap: () => _handleAttachmentTap(path, fileType, signedUrl),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        child: Stack(
          children: [
            // Content
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // File preview or icon
                  Expanded(
                    child: Center(
                      child: _buildFilePreview(path, fileType, signedUrl, isLoading),
                    ),
                  ),
                  
                  const SizedBox(height: AppTheme.spacingS),
                  
                  // File name
                  Text(
                    fileName,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  // File type
                  Text(
                    fileType.displayName,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            
            // Remove button (if not read-only)
            if (!widget.isReadOnly && widget.onRemove != null)
              Positioned(
                top: AppTheme.spacingXS,
                right: AppTheme.spacingXS,
                child: IconButton(
                  onPressed: () => widget.onRemove!(path),
                  icon: Container(
                    padding: const EdgeInsets.all(AppTheme.spacingXS),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    ),
                    child: Icon(
                      Icons.delete,
                      size: 16,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilePreview(String path, FileType fileType, String? signedUrl, bool isLoading) {
    if (isLoading) {
      return const CircularProgressIndicator();
    }

    switch (fileType) {
      case FileType.image:
        if (signedUrl != null) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusS),
            child: Image.network(
              signedUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const Center(child: CircularProgressIndicator());
              },
              errorBuilder: (context, error, stackTrace) {
                return _buildFileIcon(fileType);
              },
            ),
          );
        }
        return _buildFileIcon(fileType);
        
      case FileType.document:
      case FileType.video:
      case FileType.other:
        return _buildFileIcon(fileType);
    }
  }

  Widget _buildFileIcon(FileType fileType) {
    IconData iconData;
    Color iconColor;
    
    switch (fileType) {
      case FileType.image:
        iconData = Icons.image;
        iconColor = Colors.green;
        break;
      case FileType.document:
        iconData = Icons.description;
        iconColor = Colors.red;
        break;
      case FileType.video:
        iconData = Icons.videocam;
        iconColor = Colors.blue;
        break;
      case FileType.other:
        iconData = Icons.attach_file;
        iconColor = Colors.grey;
        break;
    }
    
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
      ),
      child: Icon(
        iconData,
        size: 32,
        color: iconColor,
      ),
    );
  }

  Future<void> _handleAttachmentTap(String path, FileType fileType, String? signedUrl) async {
    if (signedUrl == null) {
      _showErrorMessage('File not available for preview');
      return;
    }

    switch (fileType) {
      case FileType.image:
        _showImagePreview(signedUrl, path.split('/').last);
        break;
        
      case FileType.document:
      case FileType.video:
      case FileType.other:
        _downloadFile(signedUrl, path.split('/').last);
        break;
    }
  }

  void _showImagePreview(String imageUrl, String fileName) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: AppTheme.spacingM,
              right: AppTheme.spacingM,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Container(
                  padding: const EdgeInsets.all(AppTheme.spacingS),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: AppTheme.spacingM,
              left: AppTheme.spacingM,
              right: AppTheme.spacingM,
              child: Container(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
                child: Text(
                  fileName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadFile(String fileUrl, String fileName) async {
    try {
      final uri = Uri.parse(fileUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        _showSuccessMessage('Opening $fileName...');
      } else {
        _showErrorMessage('Cannot open file');
      }
    } catch (e) {
      _showErrorMessage('Failed to open file: ${e.toString()}');
    }
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
}