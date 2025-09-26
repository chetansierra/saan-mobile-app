import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/features/requests/domain/models/request.dart';
import '../../../lib/features/requests/presentation/widgets/status_timeline.dart';

void main() {
  group('StatusTimeline Widget Tests', () {
    Widget createTestWidget({
      required RequestStatus currentStatus,
      bool isCompact = false,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: StatusTimeline(
            currentStatus: currentStatus,
            isCompact: isCompact,
          ),
        ),
      );
    }

    group('Basic Rendering Tests', () {
      testWidgets('displays all status steps', (tester) async {
        await tester.pumpWidget(createTestWidget(
          currentStatus: RequestStatus.assigned,
        ));

        // Should display all status steps
        expect(find.text('New'), findsOneWidget);
        expect(find.text('Triaged'), findsOneWidget);
        expect(find.text('Assigned'), findsOneWidget);
        expect(find.text('En Route'), findsOneWidget);
        expect(find.text('On Site'), findsOneWidget);
        expect(find.text('Completed'), findsOneWidget);
        expect(find.text('Verified'), findsOneWidget);
      });

      testWidgets('displays title in full mode', (tester) async {
        await tester.pumpWidget(createTestWidget(
          currentStatus: RequestStatus.newRequest,
          isCompact: false,
        ));

        expect(find.text('Status Progress'), findsOneWidget);
      });

      testWidgets('hides title in compact mode', (tester) async {
        await tester.pumpWidget(createTestWidget(
          currentStatus: RequestStatus.newRequest,
          isCompact: true,
        ));

        expect(find.text('Status Progress'), findsNothing);
      });
    });

    group('Status Progression Tests', () {
      testWidgets('shows correct completed states for new request', (tester) async {
        await tester.pumpWidget(createTestWidget(
          currentStatus: RequestStatus.newRequest,
        ));

        // Only first step should be completed/current
        expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
        expect(find.byIcon(Icons.check), findsNothing);
      });

      testWidgets('shows correct completed states for assigned request', (tester) async {
        await tester.pumpWidget(createTestWidget(
          currentStatus: RequestStatus.assigned,
        ));

        // First three steps should be completed
        // Current step shows radio_button_checked, previous show check
        expect(find.byIcon(Icons.check), findsNWidgets(2)); // New and Triaged
        expect(find.byIcon(Icons.radio_button_checked), findsOneWidget); // Assigned (current)
      });

      testWidgets('shows correct completed states for completed request', (tester) async {
        await tester.pumpWidget(createTestWidget(
          currentStatus: RequestStatus.completed,
        ));

        // All steps except verified should be completed
        expect(find.byIcon(Icons.check), findsNWidgets(5)); // All previous steps
        expect(find.byIcon(Icons.radio_button_checked), findsOneWidget); // Completed (current)
      });
    });

    group('Visual Styling Tests', () {
      testWidgets('applies correct colors to completed steps', (tester) async {
        await tester.pumpWidget(createTestWidget(
          currentStatus: RequestStatus.assigned,
        ));

        // Find timeline indicators
        final completedIndicators = find.byWidgetPredicate(
          (widget) => widget is Container && 
                      widget.decoration is BoxDecoration &&
                      (widget.decoration as BoxDecoration).color != Colors.transparent,
        );
        
        // Should have 3 completed indicators (new, triaged, assigned)
        expect(completedIndicators, findsNWidgets(3));
      });

      testWidgets('shows connecting lines between steps', (tester) async {
        await tester.pumpWidget(createTestWidget(
          currentStatus: RequestStatus.assigned,
        ));

        // Find connecting lines (containers with height and small width)
        final connectingLines = find.byWidgetPredicate(
          (widget) => widget is Container && 
                      widget.constraints?.maxHeight != null &&
                      widget.constraints?.maxWidth == 2,
        );
        
        // Should have connecting lines between steps (6 lines for 7 steps)
        expect(connectingLines, findsNWidgets(6));
      });
    });

    group('Status Descriptions Tests', () {
      testWidgets('shows status descriptions in full mode', (tester) async {
        await tester.pumpWidget(createTestWidget(
          currentStatus: RequestStatus.newRequest,
          isCompact: false,
        ));

        // Should show description for new request
        expect(find.text('Request submitted and awaiting review'), findsOneWidget);
      });

      testWidgets('hides status descriptions in compact mode', (tester) async {
        await tester.pumpWidget(createTestWidget(
          currentStatus: RequestStatus.newRequest,
          isCompact: true,
        ));

        // Should not show descriptions in compact mode
        expect(find.text('Request submitted and awaiting review'), findsNothing);
      });

      testWidgets('shows correct descriptions for different statuses', (tester) async {
        // Test triaged status
        await tester.pumpWidget(createTestWidget(
          currentStatus: RequestStatus.triaged,
          isCompact: false,
        ));

        expect(find.text('Request reviewed and prioritized'), findsOneWidget);
        
        // Test assigned status
        await tester.pumpWidget(createTestWidget(
          currentStatus: RequestStatus.assigned,
          isCompact: false,
        ));

        expect(find.text('Engineer assigned to handle request'), findsOneWidget);
        
        // Test en route status
        await tester.pumpWidget(createTestWidget(
          currentStatus: RequestStatus.enRoute,
          isCompact: false,
        ));

        expect(find.text('Engineer traveling to location'), findsOneWidget);
      });
    });

    group('Current Status Highlighting Tests', () {
      testWidgets('highlights current status with bold text', (tester) async {
        await tester.pumpWidget(createTestWidget(
          currentStatus: RequestStatus.assigned,
        ));

        // Find the assigned status text widget
        final assignedTextFinder = find.text('Assigned');
        expect(assignedTextFinder, findsOneWidget);
        
        // Get the Text widget
        final assignedText = tester.widget<Text>(assignedTextFinder);
        
        // Should have bold font weight for current status
        expect(assignedText.style?.fontWeight, FontWeight.w600);
      });

      testWidgets('shows normal text weight for non-current statuses', (tester) async {
        await tester.pumpWidget(createTestWidget(
          currentStatus: RequestStatus.assigned,
        ));

        // Find a non-current status (e.g., En Route)
        final enRouteTextFinder = find.text('En Route');
        expect(enRouteTextFinder, findsOneWidget);
        
        // Get the Text widget
        final enRouteText = tester.widget<Text>(enRouteTextFinder);
        
        // Should have normal font weight for non-current status
        expect(enRouteText.style?.fontWeight, FontWeight.normal);
      });
    });

    group('Compact vs Full Mode Tests', () {
      testWidgets('compact mode has smaller spacing', (tester) async {
        await tester.pumpWidget(createTestWidget(
          currentStatus: RequestStatus.assigned,
          isCompact: true,
        ));

        // Find connecting lines in compact mode
        final connectingLines = find.byWidgetPredicate(
          (widget) => widget is Container && 
                      widget.constraints?.maxHeight == 20, // Compact height
        );
        
        expect(connectingLines, findsAtLeastNWidgets(1));
      });

      testWidgets('full mode has larger spacing', (tester) async {
        await tester.pumpWidget(createTestWidget(
          currentStatus: RequestStatus.assigned,
          isCompact: false,
        ));

        // Find connecting lines in full mode
        final connectingLines = find.byWidgetPredicate(
          (widget) => widget is Container && 
                      widget.constraints?.maxHeight == 32, // Full height
        );
        
        expect(connectingLines, findsAtLeastNWidgets(1));
      });
    });
  });

  group('CompactStatusTimeline Widget Tests', () {
    Widget createCompactTestWidget({
      required RequestStatus currentStatus,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: CompactStatusTimeline(
            currentStatus: currentStatus,
          ),
        ),
      );
    }

    testWidgets('displays current status name', (tester) async {
      await tester.pumpWidget(createCompactTestWidget(
        currentStatus: RequestStatus.assigned,
      ));

      expect(find.text('Assigned'), findsOneWidget);
    });

    testWidgets('displays progress counter', (tester) async {
      await tester.pumpWidget(createCompactTestWidget(
        currentStatus: RequestStatus.assigned, // 3rd status (index 2)
      ));

      expect(find.text('3/7'), findsOneWidget);
    });

    testWidgets('shows progress bar with correct value', (tester) async {
      await tester.pumpWidget(createCompactTestWidget(
        currentStatus: RequestStatus.assigned, // 3rd status
      ));

      // Find the LinearProgressIndicator
      final progressIndicator = find.byType(LinearProgressIndicator);
      expect(progressIndicator, findsOneWidget);
      
      final progressWidget = tester.widget<LinearProgressIndicator>(progressIndicator);
      
      // Should show 3/7 progress (0.428...)
      expect(progressWidget.value, closeTo(3/7, 0.01));
    });

    testWidgets('shows correct progress for different statuses', (tester) async {
      // Test first status
      await tester.pumpWidget(createCompactTestWidget(
        currentStatus: RequestStatus.newRequest,
      ));
      
      expect(find.text('1/7'), findsOneWidget);
      
      // Test last status
      await tester.pumpWidget(createCompactTestWidget(
        currentStatus: RequestStatus.verified,
      ));
      
      expect(find.text('7/7'), findsOneWidget);
    });
  });
}
