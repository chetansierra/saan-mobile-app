import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/client.dart';

/// Storage helper for handling file uploads to Supabase Storage
class StorageHelper {
  StorageHelper._();

  /// Singleton instance
  static final StorageHelper _instance = StorageHelper._();
  static StorageHelper get instance => _instance;

  /// Upload file for request
  Future<String> uploadRequestFile({
    required String tenantId,
    required String requestId,
    required String fileName,
    required Uint8List fileBytes,
    String? contentType,
    Function(double)? onProgress,
  }) async {
    try {
      debugPrint('📤 Uploading file for request: $requestId');
      
      // Generate tenant-scoped path: attachments/{tenant_id}/requests/{request_id}/{filename}
      final path = _generateRequestFilePath(
        tenantId: tenantId,
        requestId: requestId,
        fileName: fileName,
      );

      await SupabaseService.uploadFile(
        bucket: SupabaseBuckets.attachments,
        tenantId: tenantId,
        entity: 'requests',
        recordId: requestId,
        filename: fileName,
        fileBytes: fileBytes,
        contentType: contentType,
      );

      debugPrint('✅ File uploaded successfully: $path');
      return path;
    } catch (e) {
      debugPrint('❌ File upload failed: $e');
      rethrow;
    }
  }

  /// Upload multiple files for request
  Future<List<String>> uploadRequestFiles({
    required String tenantId,
    required String requestId,
    required List<FileUpload> files,
    Function(int, double)? onProgress,
  }) async {
    try {
      debugPrint('📤 Uploading ${files.length} files for request: $requestId');
      
      final uploadedPaths = <String>[];
      
      for (int i = 0; i < files.length; i++) {
        final file = files[i];
        
        final path = await uploadRequestFile(
          tenantId: tenantId,
          requestId: requestId,
          fileName: file.fileName,
          fileBytes: file.bytes,
          contentType: file.contentType,
          onProgress: (progress) {
            onProgress?.call(i, progress);
          },
        );
        
        uploadedPaths.add(path);
      }
      
      debugPrint('✅ All files uploaded successfully');
      return uploadedPaths;
    } catch (e) {
      debugPrint('❌ Batch file upload failed: $e');
      rethrow;
    }
  }

  /// Get signed URL for file access
  Future<String> getSignedUrl({
    required String path,
    int expiresIn = 3600, // 1 hour default
  }) async {
    try {
      debugPrint('🔗 Getting signed URL for: $path');
      
      final signedUrl = await SupabaseService.getSignedUrl(
        bucket: SupabaseBuckets.attachments,
        path: path,
        expiresIn: expiresIn,
      );
      
      debugPrint('✅ Signed URL generated');
      return signedUrl;
    } catch (e) {
      debugPrint('❌ Failed to get signed URL: $e');
      rethrow;
    }
  }

  /// Get signed URLs for multiple files
  Future<List<String>> getSignedUrls({
    required List<String> paths,
    int expiresIn = 3600,
  }) async {
    try {
      debugPrint('🔗 Getting signed URLs for ${paths.length} files');
      
      final signedUrls = <String>[];
      
      for (final path in paths) {
        final signedUrl = await getSignedUrl(
          path: path,
          expiresIn: expiresIn,
        );
        signedUrls.add(signedUrl);
      }
      
      debugPrint('✅ All signed URLs generated');
      return signedUrls;
    } catch (e) {
      debugPrint('❌ Failed to get signed URLs: $e');
      rethrow;
    }
  }

  /// Delete file from storage
  Future<void> deleteFile(String path) async {
    try {
      debugPrint('🗑️ Deleting file: $path');
      
      await SupabaseService.deleteFile(
        bucket: SupabaseBuckets.attachments,
        path: path,
      );
      
      debugPrint('✅ File deleted successfully');
    } catch (e) {
      debugPrint('❌ Failed to delete file: $e');
      rethrow;
    }
  }

  /// Delete multiple files from storage
  Future<void> deleteFiles(List<String> paths) async {
    try {
      debugPrint('🗑️ Deleting ${paths.length} files');
      
      for (final path in paths) {
        await deleteFile(path);
      }
      
      debugPrint('✅ All files deleted successfully');
    } catch (e) {
      debugPrint('❌ Failed to delete files: $e');
      rethrow;
    }
  }

  /// Validate file before upload
  static bool validateFile({
    required String fileName,
    required int fileSize,
    String? contentType,
  }) {
    // Check file size (10MB limit)
    if (fileSize > 10 * 1024 * 1024) {
      debugPrint('❌ File too large: ${fileSize} bytes');
      return false;
    }

    // Check file extension
    final extension = fileName.toLowerCase().split('.').last;
    if (!_allowedExtensions.contains(extension)) {
      debugPrint('❌ Invalid file extension: $extension');
      return false;
    }

    // Check MIME type if provided
    if (contentType != null && !_allowedMimeTypes.contains(contentType)) {
      debugPrint('❌ Invalid MIME type: $contentType');
      return false;
    }

    return true;
  }

  /// Get file type from extension
  static FileType getFileType(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    
    if (_imageExtensions.contains(extension)) {
      return FileType.image;
    } else if (_documentExtensions.contains(extension)) {
      return FileType.document;
    } else if (_videoExtensions.contains(extension)) {
      return FileType.video;
    } else {
      return FileType.other;
    }
  }

  /// Generate storage path for request file
  String _generateRequestFilePath({
    required String tenantId,
    required String requestId,
    required String fileName,
  }) {
    return '$tenantId/requests/$requestId/$fileName';
  }

  /// Allowed file extensions
  static const List<String> _allowedExtensions = [
    // Images
    'jpg', 'jpeg', 'png', 'webp', 'heic', 'heif',
    // Documents
    'pdf', 'doc', 'docx',
    // Videos
    'mp4', 'mov', 'avi', 'mkv',
  ];

  /// Allowed MIME types
  static const List<String> _allowedMimeTypes = [
    // Images
    'image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif',
    // Documents
    'application/pdf', 'application/msword', 
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    // Videos
    'video/mp4', 'video/quicktime', 'video/x-msvideo', 'video/x-matroska',
  ];

  /// Image extensions
  static const List<String> _imageExtensions = [
    'jpg', 'jpeg', 'png', 'webp', 'heic', 'heif',
  ];

  /// Document extensions
  static const List<String> _documentExtensions = [
    'pdf', 'doc', 'docx',
  ];

  /// Video extensions
  static const List<String> _videoExtensions = [
    'mp4', 'mov', 'avi', 'mkv',
  ];
}

/// File upload model
class FileUpload {
  const FileUpload({
    required this.fileName,
    required this.bytes,
    this.contentType,
  });

  final String fileName;
  final Uint8List bytes;
  final String? contentType;

  /// File size in bytes
  int get size => bytes.length;

  /// File type based on extension
  FileType get type => StorageHelper.getFileType(fileName);

  /// Whether the file is valid for upload
  bool get isValid => StorageHelper.validateFile(
        fileName: fileName,
        fileSize: size,
        contentType: contentType,
      );
}

/// File type enumeration
enum FileType {
  image,
  document,
  video,
  other;

  /// Display name for file type
  String get displayName {
    switch (this) {
      case FileType.image:
        return 'Image';
      case FileType.document:
        return 'Document';
      case FileType.video:
        return 'Video';
      case FileType.other:
        return 'File';
    }
  }

  /// Icon name for file type
  String get iconName {
    switch (this) {
      case FileType.image:
        return 'image';
      case FileType.document:
        return 'description';
      case FileType.video:
        return 'videocam';
      case FileType.other:
        return 'attach_file';
    }
  }
}

/// Upload progress callback
typedef UploadProgressCallback = void Function(double progress);

/// Batch upload progress callback
typedef BatchUploadProgressCallback = void Function(int fileIndex, double progress);

/// Storage exceptions
class StorageException implements Exception {
  const StorageException(this.message);

  final String message;

  @override
  String toString() => 'StorageException: $message';
}