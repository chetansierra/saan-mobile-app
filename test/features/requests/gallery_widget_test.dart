import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../../lib/core/storage/storage_helper.dart';
import '../../../lib/features/requests/presentation/widgets/attachment_gallery.dart';

// Generate mocks
@GenerateMocks([StorageHelper])
import 'gallery_widget_test.mocks.dart';

void main() {
  group('AttachmentGallery Widget Tests', () {
    late MockStorageHelper mockStorageHelper;
    
    setUp(() {
      mockStorageHelper = MockStorageHelper();
      
      // Mock StorageHelper.instance
      when(mockStorageHelper.getSignedUrl(
        path: anyNamed('path'),
        expiresIn: anyNamed('expiresIn'),
      )).thenAnswer((_) async => 'https://signed-url.com/file');
    });

    Widget createTestWidget({
      List<String> attachmentPaths = const [],
      Function(String)? onRemove,
      bool isReadOnly = false,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: AttachmentGallery(
            attachmentPaths: attachmentPaths,
            onRemove: onRemove,
            isReadOnly: isReadOnly,
          ),
        ),
      );
    }

    group('Empty State Tests', () {
      testWidgets('shows nothing when no attachments', (tester) async {
        await tester.pumpWidget(createTestWidget());

        // Should not show anything for empty attachments
        expect(find.text('Attachments'), findsNothing);
        expect(find.byType(GridView), findsNothing);
      });
    });

    group('Basic Rendering Tests', () {
      testWidgets('displays attachment count in header', (tester) async {
        await tester.pumpWidget(createTestWidget(
          attachmentPaths: ['path/to/image1.jpg', 'path/to/document.pdf'],
        ));

        expect(find.text('Attachments (2)'), findsOneWidget);
        expect(find.byIcon(Icons.attach_file), findsOneWidget);
      });

      testWidgets('displays grid with correct number of items', (tester) async {
        await tester.pumpWidget(createTestWidget(
          attachmentPaths: ['image1.jpg', 'document.pdf', 'video.mp4'],
        ));
        await tester.pumpAndSettle();

        // Should show grid with 3 items
        expect(find.byType(GridView), findsOneWidget);
        expect(find.byType(Card), findsNWidgets(3));
      });

      testWidgets('displays file names correctly', (tester) async {
        await tester.pumpWidget(createTestWidget(
          attachmentPaths: ['path/to/test-image.jpg', 'documents/report.pdf'],
        ));
        await tester.pumpAndSettle();

        expect(find.text('test-image.jpg'), findsOneWidget);
        expect(find.text('report.pdf'), findsOneWidget);
      });
    });

    group('File Type Display Tests', () {
      testWidgets('displays correct icons for different file types', (tester) async {
        await tester.pumpWidget(createTestWidget(
          attachmentPaths: [
            'image.jpg',
            'document.pdf', 
            'video.mp4',
            'unknown.xyz'
          ],
        ));
        await tester.pumpAndSettle();

        // Should show appropriate icons for each file type
        expect(find.byIcon(Icons.image), findsOneWidget);
        expect(find.byIcon(Icons.description), findsOneWidget);
        expect(find.byIcon(Icons.videocam), findsOneWidget);
        expect(find.byIcon(Icons.attach_file), findsOneWidget);
      });

      testWidgets('displays correct file type labels', (tester) async {
        await tester.pumpWidget(createTestWidget(
          attachmentPaths: [
            'photo.png',
            'report.pdf',
            'demo.mp4',
            'data.txt'
          ],
        ));
        await tester.pumpAndSettle();

        expect(find.text('Image'), findsOneWidget);
        expect(find.text('Document'), findsOneWidget);
        expect(find.text('Video'), findsOneWidget);
        expect(find.text('File'), findsOneWidget);
      });
    });

    group('Loading States Tests', () {
      testWidgets('shows loading indicator while fetching signed URLs', (tester) async {
        // Mock delayed response
        when(mockStorageHelper.getSignedUrl(
          path: anyNamed('path'),
          expiresIn: anyNamed('expiresIn'),
        )).thenAnswer((_) async {
          await Future.delayed(const Duration(milliseconds: 100));
          return 'https://signed-url.com/file';
        });

        await tester.pumpWidget(createTestWidget(
          attachmentPaths: ['image.jpg'],
        ));

        // Should show loading indicator initially
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        await tester.pumpAndSettle();

        // Should hide loading indicator after loading
        expect(find.byType(CircularProgressIndicator), findsNothing);
      });
    });

    group('Image Preview Tests', () {
      testWidgets('displays network image for image files with signed URL', (tester) async {
        when(mockStorageHelper.getSignedUrl(
          path: anyNamed('path'),
          expiresIn: anyNamed('expiresIn'),
        )).thenAnswer((_) async => 'https://example.com/image.jpg');

        await tester.pumpWidget(createTestWidget(
          attachmentPaths: ['image.jpg'],
        ));
        await tester.pumpAndSettle();

        // Should show network image
        expect(find.byType(Image), findsOneWidget);
      });

      testWidgets('shows file icon when image fails to load', (tester) async {
        await tester.pumpWidget(createTestWidget(
          attachmentPaths: ['broken-image.jpg'],
        ));
        await tester.pumpAndSettle();

        // Should fallback to file icon
        expect(find.byIcon(Icons.image), findsOneWidget);
      });
    });

    group('Interaction Tests', () {
      testWidgets('tapping image opens preview dialog', (tester) async {
        when(mockStorageHelper.getSignedUrl(
          path: anyNamed('path'),
          expiresIn: anyNamed('expiresIn'),
        )).thenAnswer((_) async => 'https://example.com/image.jpg');

        await tester.pumpWidget(createTestWidget(
          attachmentPaths: ['image.jpg'],
        ));
        await tester.pumpAndSettle();

        // Tap on the image card
        await tester.tap(find.byType(Card).first);
        await tester.pumpAndSettle();

        // Should open preview dialog
        expect(find.byType(Dialog), findsOneWidget);
        expect(find.byType(InteractiveViewer), findsOneWidget);
        expect(find.byIcon(Icons.close), findsOneWidget);
      });

      testWidgets('can close image preview dialog', (tester) async {
        when(mockStorageHelper.getSignedUrl(
          path: anyNamed('path'),
          expiresIn: anyNamed('expiresIn'),
        )).thenAnswer((_) async => 'https://example.com/image.jpg');

        await tester.pumpWidget(createTestWidget(
          attachmentPaths: ['image.jpg'],
        ));
        await tester.pumpAndSettle();

        // Open preview
        await tester.tap(find.byType(Card).first);
        await tester.pumpAndSettle();

        // Close preview
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();

        // Dialog should be closed
        expect(find.byType(Dialog), findsNothing);
      });
    });

    group('Read-Only vs Editable Mode Tests', () {
      testWidgets('hides remove buttons in read-only mode', (tester) async {
        await tester.pumpWidget(createTestWidget(
          attachmentPaths: ['image.jpg', 'document.pdf'],
          isReadOnly: true,
        ));
        await tester.pumpAndSettle();

        // Should not show delete buttons
        expect(find.byIcon(Icons.delete), findsNothing);
      });

      testWidgets('shows remove buttons in editable mode', (tester) async {
        await tester.pumpWidget(createTestWidget(
          attachmentPaths: ['image.jpg', 'document.pdf'],
          isReadOnly: false,
          onRemove: (path) {},
        ));
        await tester.pumpAndSettle();

        // Should show delete buttons
        expect(find.byIcon(Icons.delete), findsNWidgets(2));
      });

      testWidgets('calls onRemove when delete button tapped', (tester) async {
        String? removedPath;
        
        await tester.pumpWidget(createTestWidget(
          attachmentPaths: ['image.jpg'],
          isReadOnly: false,
          onRemove: (path) {
            removedPath = path;
          },
        ));
        await tester.pumpAndSettle();

        // Tap delete button
        await tester.tap(find.byIcon(Icons.delete));
        await tester.pumpAndSettle();

        // Should call onRemove with correct path
        expect(removedPath, 'image.jpg');
      });
    });

    group('Error Handling Tests', () {
      testWidgets('handles signed URL fetch errors gracefully', (tester) async {
        when(mockStorageHelper.getSignedUrl(
          path: anyNamed('path'),
          expiresIn: anyNamed('expiresIn'),
        )).thenThrow(Exception('Network error'));

        await tester.pumpWidget(createTestWidget(
          attachmentPaths: ['image.jpg'],
        ));
        await tester.pumpAndSettle();

        // Should show file icon as fallback
        expect(find.byIcon(Icons.image), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      });

      testWidgets('shows error message when file not available for preview', (tester) async {
        when(mockStorageHelper.getSignedUrl(
          path: anyNamed('path'),
          expiresIn: anyNamed('expiresIn'),
        )).thenThrow(Exception('File not found'));

        await tester.pumpWidget(createTestWidget(
          attachmentPaths: ['image.jpg'],
        ));
        await tester.pumpAndSettle();

        // Tap on the card to try to preview
        await tester.tap(find.byType(Card).first);
        await tester.pumpAndSettle();

        // Should show error snackbar
        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.text('File not available for preview'), findsOneWidget);
      });
    });

    group('Grid Layout Tests', () {
      testWidgets('uses correct grid configuration', (tester) async {
        await tester.pumpWidget(createTestWidget(
          attachmentPaths: ['file1.jpg', 'file2.pdf', 'file3.mp4', 'file4.doc'],
        ));
        await tester.pumpAndSettle();

        // Find the GridView
        final gridView = find.byType(GridView);
        expect(gridView, findsOneWidget);
        
        final gridWidget = tester.widget<GridView>(gridView);
        final delegate = gridWidget.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
        
        // Should have 2 columns
        expect(delegate.crossAxisCount, 2);
        expect(delegate.childAspectRatio, 1.2);
      });

      testWidgets('grid is non-scrollable when embedded', (tester) async {
        await tester.pumpWidget(createTestWidget(
          attachmentPaths: ['file1.jpg', 'file2.pdf'],
        ));
        await tester.pumpAndSettle();

        final gridView = tester.widget<GridView>(find.byType(GridView));
        
        // Should be non-scrollable (shrinkWrap: true, physics: NeverScrollableScrollPhysics)
        expect(gridView.shrinkWrap, true);
        expect(gridView.physics, isA<NeverScrollableScrollPhysics>());
      });
    });
  });
}
