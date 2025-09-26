import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../core/storage/storage_helper.dart';
import '../../domain/pm_service.dart';

/// Digital signature pad widget for PM visit completion
class PMSignaturePad extends ConsumerStatefulWidget {
  const PMSignaturePad({
    super.key,
    required this.tenantId,
    required this.pmVisitId,
    this.signatureUrl,
    this.onSignatureChanged,
  });

  final String tenantId;
  final String pmVisitId;
  final String? signatureUrl;
  final ValueChanged<String?>? onSignatureChanged;

  @override
  ConsumerState<PMSignaturePad> createState() => _PMSignaturePadState();
}

class _PMSignaturePadState extends ConsumerState<PMSignaturePad> {
  final GlobalKey _signatureKey = GlobalKey();
  final List<Offset?> _points = <Offset?>[];
  bool _isUploading = false;
  bool _hasSignature = false;

  @override
  void initState() {
    super.initState();
    _hasSignature = widget.signatureUrl != null;
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = widget.onSignatureChanged != null;
    final hasExistingSignature = widget.signatureUrl != null;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Signature canvas or display
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
            child: hasExistingSignature && !canEdit
                ? _buildSignatureDisplay()
                : _buildSignaturePad(canEdit),
          ),
        ),
        
        const SizedBox(height: AppTheme.spacingM),
        
        // Actions row
        Row(
          children: [
            // Upload progress or status
            if (_isUploading) ...[
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: AppTheme.spacingS),
              Text(
                'Uploading signature...',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ] else if (_hasSignature) ...[
              Icon(
                Icons.check_circle,
                size: 16,
                color: Colors.green,
              ),
              const SizedBox(width: AppTheme.spacingS),
              Text(
                'Signature captured',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ] else if (canEdit) ...[
              Icon(
                Icons.touch_app,
                size: 16,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              const SizedBox(width: AppTheme.spacingS),
              Text(
                'Sign here with your finger or stylus',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
            
            const Spacer(),
            
            // Action buttons
            if (canEdit && !_isUploading) ...[
              if (_points.isNotEmpty) ...[
                TextButton.icon(
                  onPressed: _clearSignature,
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Clear'),
                ),
              ],
              
              if (_points.isNotEmpty) ...[
                const SizedBox(width: AppTheme.spacingS),
                FilledButton.icon(
                  onPressed: _saveSignature,
                  icon: const Icon(Icons.save, size: 16),
                  label: const Text('Save'),
                ),
              ],
            ],
          ],
        ),
        
        // Required indicator
        if (canEdit && !_hasSignature) ...[
          const SizedBox(height: AppTheme.spacingS),
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: Colors.orange,
              ),
              const SizedBox(width: AppTheme.spacingS),
              Text(
                'Engineer signature is required to complete this visit',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.orange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildSignatureDisplay() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.verified_user,
            size: 48,
            color: Colors.green,
          ),
          const SizedBox(height: AppTheme.spacingM),
          Text(
            'Signature Captured',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.green,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            'Digital signature is saved and verified',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignaturePad(bool canEdit) {
    if (!canEdit) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.1),
        child: Center(
          child: Text(
            'Signature view only',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ),
      );
    }

    return RepaintBoundary(
      key: _signatureKey,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.white,
        child: GestureDetector(
          onPanUpdate: (details) {
            setState(() {
              RenderBox? renderBox = _signatureKey.currentContext?.findRenderObject() as RenderBox?;
              if (renderBox != null) {
                Offset localPosition = renderBox.globalToLocal(details.globalPosition);
                _points.add(localPosition);
              }
            });
          },
          onPanEnd: (details) {
            setState(() {
              _points.add(null); // Add null to separate strokes
            });
          },
          child: CustomPaint(
            painter: _SignaturePainter(_points),
            size: Size.infinite,
            child: _points.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.edit,
                          size: 32,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                        ),
                        const SizedBox(height: AppTheme.spacingS),
                        Text(
                          'Tap and drag to sign',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }

  void _clearSignature() {
    setState(() {
      _points.clear();
    });
  }

  Future<void> _saveSignature() async {
    if (_points.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a signature first')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      // Capture signature as image
      RenderRepaintBoundary boundary = _signatureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData == null) {
        throw Exception('Failed to capture signature image');
      }

      Uint8List imageBytes = byteData.buffer.asUint8List();
      
      // Upload signature to storage
      final pmService = ref.read(pmServiceProvider);
      final storagePath = await pmService.uploadPMAttachment(
        pmVisitId: widget.pmVisitId,
        filename: 'signature.png',
        bytes: imageBytes,
      );
      
      // Get signed URL
      final signedUrl = await StorageHelper.instance.getSignedUrl(storagePath);
      
      setState(() {
        _hasSignature = true;
      });
      
      // Notify parent
      widget.onSignatureChanged?.call(signedUrl);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Signature saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save signature: $e'),
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
}

/// Custom painter for drawing signature strokes
class _SignaturePainter extends CustomPainter {
  _SignaturePainter(this.points);

  final List<Offset?> points;

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = Colors.black
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.0;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate != this;
  }
}