import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../../lib/features/auth/domain/auth_service.dart';
import '../../../lib/features/auth/domain/models/user_profile.dart';
import '../../../lib/features/requests/domain/models/request.dart';
import '../../../lib/features/requests/domain/requests_service.dart';
import '../../../lib/features/requests/presentation/request_detail_page.dart';
import '../../../lib/core/storage/storage_helper.dart';

// Generate mocks
@GenerateMocks([
  AuthService,
  RequestsService,
  StorageHelper,
])
import 'detail_page_widget_test.mocks.dart';

void main() {
  group('RequestDetailPage Widget Tests', () {
    late MockAuthService mockAuthService;
    late MockRequestsService mockRequestsService;
    late MockStorageHelper mockStorageHelper;
    late ServiceRequest testRequest;
    late List<UserProfile> testAssignees;

    setUp(() {
      mockAuthService = MockAuthService();
      mockRequestsService = MockRequestsService();
      mockStorageHelper = MockStorageHelper();

      // Create test request
      testRequest = ServiceRequest(
        id: 'test-request-123',
        tenantId: 'tenant-456',
        facilityId: 'facility-789',
        type: RequestType.onDemand,
        priority: RequestPriority.critical,
        description: 'HVAC system failure in main building',
        status: RequestStatus.newRequest,
        mediaUrls: ['path/to/image1.jpg', 'path/to/document.pdf'],
        createdAt: DateTime(2025, 1, 26, 10, 0, 0),
        slaDueAt: DateTime(2025, 1, 26, 16, 0, 0),
        facilityName: 'Main Building',
        assignedEngineerName: null,
      );

      // Create test assignees
      testAssignees = [
        UserProfile(
          userId: 'user-1',
          tenantId: 'tenant-456',
          email: 'john.doe@example.com',
          name: 'John Doe',
          role: UserRole.admin,
          createdAt: DateTime.now(),
        ),
        UserProfile(
          userId: 'user-2',
          tenantId: 'tenant-456',
          email: 'jane.smith@example.com',
          name: 'Jane Smith',
          role: UserRole.admin,
          createdAt: DateTime.now(),
        ),
      ];
    });

    Widget createTestWidget({
      bool isAdmin = true,
      ServiceRequest? request,
    }) {
      return ProviderScope(
        overrides: [
          authServiceProvider.overrideWith((ref) {
            when(mockAuthService.isAdmin).thenReturn(isAdmin);
            when(mockAuthService.isAuthenticated).thenReturn(true);
            when(mockAuthService.hasCompleteProfile).thenReturn(true);
            return mockAuthService;
          }),
          requestsServiceProvider.overrideWith((ref) {
            when(mockRequestsService.getRequest(any))
                .thenAnswer((_) async => request ?? testRequest);
            when(mockRequestsService.getAvailableAssignees())
                .thenAnswer((_) async => testAssignees);
            return mockRequestsService;
          }),
        ],
        child: MaterialApp(
          home: RequestDetailPage(requestId: 'test-request-123'),
        ),
      );
    }

    group('Layout Structure Tests', () {
      testWidgets('displays sticky header with correct elements', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Check sticky header exists
        expect(find.text('Request #test-req'), findsOneWidget);
        
        // Check status chip
        expect(find.text('NEW'), findsOneWidget);
        
        // Check priority chip
        expect(find.text('CRITICAL'), findsOneWidget);
        expect(find.byIcon(Icons.priority_high), findsOneWidget);
        
        // Check back button
        expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      });

      testWidgets('displays top row with SLA badge and assignee picker for admin', (tester) async {
        await tester.pumpWidget(createTestWidget(isAdmin: true));
        await tester.pumpAndSettle();

        // Check SLA badge
        expect(find.textContaining('SLA:'), findsOneWidget);
        expect(find.byIcon(Icons.schedule), findsOneWidget);
        
        // Check assignee picker for admin
        expect(find.text('Assign Engineer'), findsOneWidget);
        expect(find.byIcon(Icons.person_add), findsOneWidget);
      });

      testWidgets('displays assigned engineer for requester', (tester) async {
        final requestWithAssignee = testRequest.copyWith(
          assignedEngineerName: 'John Doe',
        );
        
        await tester.pumpWidget(createTestWidget(
          isAdmin: false,
          request: requestWithAssignee,
        ));
        await tester.pumpAndSettle();

        // Check assigned engineer display for requester
        expect(find.text('John Doe'), findsOneWidget);
        expect(find.byIcon(Icons.person), findsOneWidget);
        
        // Should not show assignee picker
        expect(find.text('Assign Engineer'), findsNothing);
      });

      testWidgets('displays scrollable sections in correct order', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Check Details section
        expect(find.text('Request Details'), findsOneWidget);
        expect(find.text('HVAC system failure in main building'), findsOneWidget);
        expect(find.text('Main Building'), findsOneWidget);
        
        // Check Attachments section
        expect(find.text('Attachments (2)'), findsOneWidget);
        
        // Check Timeline section
        expect(find.text('Status Timeline'), findsOneWidget);
        
        // Check Notes section
        expect(find.text('Admin Notes'), findsOneWidget);
        expect(find.text('No admin notes available'), findsOneWidget);
      });

      testWidgets('displays sticky bottom bar for admin only', (tester) async {
        await tester.pumpWidget(createTestWidget(isAdmin: true));
        await tester.pumpAndSettle();

        // Check admin bottom bar
        expect(find.text('Mark as Triaged'), findsOneWidget);
        expect(find.text('Assign Engineer'), findsAtLeastNWidget(1));
      });

      testWidgets('hides sticky bottom bar for requester', (tester) async {
        await tester.pumpWidget(createTestWidget(isAdmin: false));
        await tester.pumpAndSettle();

        // Should not show admin bottom bar
        expect(find.text('Mark as Triaged'), findsNothing);
      });
    });

    group('Loading and Error States', () {
      testWidgets('displays loading indicator while fetching request', (tester) async {
        when(mockRequestsService.getRequest(any))
            .thenAnswer((_) async {
          await Future.delayed(const Duration(seconds: 1));
          return testRequest;
        });

        await tester.pumpWidget(createTestWidget());
        
        // Should show loading indicator
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        
        await tester.pumpAndSettle();
        
        // Should show content after loading
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text('Request Details'), findsOneWidget);
      });

      testWidgets('displays error state when request fetch fails', (tester) async {
        when(mockRequestsService.getRequest(any))
            .thenThrow(Exception('Network error'));

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Should show error state
        expect(find.text('Error Loading Request'), findsOneWidget);
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
      });

      testWidgets('displays not found state when request is null', (tester) async {
        when(mockRequestsService.getRequest(any))
            .thenAnswer((_) async => null);

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Should show not found state
        expect(find.text('Request Not Found'), findsOneWidget);
        expect(find.byIcon(Icons.search_off), findsOneWidget);
        expect(find.text('Back to Requests'), findsOneWidget);
      });
    });

    group('Admin vs Requester Role Tests', () {
      testWidgets('admin sees all admin features', (tester) async {
        await tester.pumpWidget(createTestWidget(isAdmin: true));
        await tester.pumpAndSettle();

        // Admin should see assignee picker
        expect(find.text('Assign Engineer'), findsAtLeastNWidget(1));
        
        // Admin should see status update button
        expect(find.text('Mark as Triaged'), findsOneWidget);
        
        // Admin should see bottom action bar
        expect(find.byType(FilledButton), findsAtLeastNWidget(1));
        expect(find.byType(OutlinedButton), findsAtLeastNWidget(1));
      });

      testWidgets('requester sees limited features', (tester) async {
        await tester.pumpWidget(createTestWidget(isAdmin: false));
        await tester.pumpAndSettle();

        // Requester should not see assignee picker
        expect(find.text('Assign Engineer'), findsNothing);
        
        // Requester should not see status update button
        expect(find.text('Mark as Triaged'), findsNothing);
        
        // Requester should not see bottom action bar
        expect(find.byType(FilledButton), findsNothing);
      });
    });

    group('Interaction Tests', () {
      testWidgets('tapping back button navigates back', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Tap back button
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();

        // Note: In a real app, this would test navigation
        // Here we just verify the button is tappable
      });

      testWidgets('tapping assignee picker opens bottom sheet', (tester) async {
        await tester.pumpWidget(createTestWidget(isAdmin: true));
        await tester.pumpAndSettle();

        // Tap assignee picker
        await tester.tap(find.text('Assign Engineer').first);
        await tester.pumpAndSettle();

        // Should open assignee picker bottom sheet
        expect(find.text('Assign Engineer'), findsAtLeastNWidget(2)); // One in page, one in bottom sheet
      });

      testWidgets('refresh indicator works', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Find the RefreshIndicator and trigger refresh
        await tester.drag(find.byType(RefreshIndicator), const Offset(0, 300));
        await tester.pumpAndSettle();

        // Verify service was called again
        verify(mockRequestsService.getRequest('test-request-123')).called(greaterThan(1));
      });
    });

    group('Status Update Tests', () {
      testWidgets('status update button shows correct next status', (tester) async {
        await tester.pumpWidget(createTestWidget(isAdmin: true));
        await tester.pumpAndSettle();

        // Should show next status in sequence
        expect(find.text('Mark as Triaged'), findsOneWidget);
      });

      testWidgets('completed request hides status update button', (tester) async {
        final completedRequest = testRequest.copyWith(
          status: RequestStatus.completed,
        );
        
        await tester.pumpWidget(createTestWidget(
          isAdmin: true,
          request: completedRequest,
        ));
        await tester.pumpAndSettle();

        // Should not show status update button for completed request
        expect(find.textContaining('Mark as'), findsNothing);
      });
    });

    group('SLA Display Tests', () {
      testWidgets('displays SLA badge for critical requests', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Should show SLA badge
        expect(find.textContaining('SLA:'), findsOneWidget);
        expect(find.byIcon(Icons.schedule), findsOneWidget);
      });

      testWidgets('displays standard priority message for non-critical requests', (tester) async {
        final standardRequest = testRequest.copyWith(
          priority: RequestPriority.standard,
          slaDueAt: null,
        );
        
        await tester.pumpWidget(createTestWidget(request: standardRequest));
        await tester.pumpAndSettle();

        // Should show standard priority message
        expect(find.text('Standard Priority'), findsOneWidget);
      });
    });

    group('Details Section Tests', () {
      testWidgets('displays all request details correctly', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Check facility
        expect(find.text('Main Building'), findsOneWidget);
        
        // Check description
        expect(find.text('HVAC system failure in main building'), findsOneWidget);
        
        // Check type
        expect(find.text('On-Demand'), findsOneWidget);
        
        // Check created date (formatted)
        expect(find.textContaining('Jan 26, 2025'), findsOneWidget);
      });

      testWidgets('displays ETA when available', (tester) async {
        final requestWithETA = testRequest.copyWith(
          eta: DateTime(2025, 1, 26, 14, 30, 0),
        );
        
        await tester.pumpWidget(createTestWidget(request: requestWithETA));
        await tester.pumpAndSettle();

        // Should show ETA
        expect(find.textContaining('ETA'), findsOneWidget);
        expect(find.textContaining('Jan 26, 2025 14:30'), findsOneWidget);
      });
    });
  });
}
