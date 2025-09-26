import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/features/auth/domain/models/user_profile.dart';
import '../../../lib/features/requests/presentation/widgets/assignee_picker.dart';

void main() {
  group('AssigneePicker Widget Tests', () {
    late List<UserProfile> testAssignees;
    
    setUp(() {
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
        UserProfile(
          userId: 'user-3',
          tenantId: 'tenant-456',
          email: 'bob.wilson@example.com',
          name: 'Bob Wilson',
          role: UserRole.admin,
          createdAt: DateTime.now(),
        ),
      ];
    });

    Widget createTestWidget({
      List<UserProfile> availableAssignees = const [],
      String? currentAssignee,
      Function(String?)? onAssigneeSelected,
      bool isLoading = false,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: AssigneePicker(
            availableAssignees: availableAssignees,
            currentAssignee: currentAssignee,
            onAssigneeSelected: onAssigneeSelected ?? (assignee) {},
            isLoading: isLoading,
          ),
        ),
      );
    }

    group('Empty State Tests', () {
      testWidgets('shows nothing when no assignees and not loading', (tester) async {
        await tester.pumpWidget(createTestWidget());

        // Should not show anything
        expect(find.text('Assigned Engineer'), findsNothing);
        expect(find.byType(Card), findsNothing);
      });

      testWidgets('shows loading indicator when loading', (tester) async {
        await tester.pumpWidget(createTestWidget(
          isLoading: true,
        ));

        expect(find.text('Assigned Engineer'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });

    group('Basic Rendering Tests', () {
      testWidgets('displays section header', (tester) async {
        await tester.pumpWidget(createTestWidget(
          availableAssignees: testAssignees,
        ));

        expect(find.text('Assigned Engineer'), findsOneWidget);
        expect(find.byIcon(Icons.person_outline), findsOneWidget);
      });

      testWidgets('displays assignee card when assignees available', (tester) async {
        await tester.pumpWidget(createTestWidget(
          availableAssignees: testAssignees,
        ));

        expect(find.byType(Card), findsOneWidget);
        expect(find.byType(InkWell), findsOneWidget);
      });
    });

    group('Unassigned State Tests', () {
      testWidgets('shows unassigned state when no current assignee', (tester) async {
        await tester.pumpWidget(createTestWidget(
          availableAssignees: testAssignees,
          currentAssignee: null,
        ));

        expect(find.text('Assign Engineer'), findsOneWidget);
        expect(find.text('No engineer assigned yet'), findsOneWidget);
        expect(find.byIcon(Icons.person_add), findsOneWidget);
      });

      testWidgets('uses correct styling for unassigned state', (tester) async {
        await tester.pumpWidget(createTestWidget(
          availableAssignees: testAssignees,
          currentAssignee: null,
        ));

        // Find the avatar
        final avatar = find.byType(CircleAvatar);
        expect(avatar, findsOneWidget);
        
        final avatarWidget = tester.widget<CircleAvatar>(avatar);
        expect(avatarWidget.child, isA<Icon>());
        
        final icon = avatarWidget.child as Icon;
        expect(icon.icon, Icons.person_add);
      });
    });

    group('Assigned State Tests', () {
      testWidgets('shows assigned engineer name', (tester) async {
        await tester.pumpWidget(createTestWidget(
          availableAssignees: testAssignees,
          currentAssignee: 'John Doe',
        ));

        expect(find.text('John Doe'), findsOneWidget);
        expect(find.text('Tap to reassign'), findsOneWidget);
        expect(find.byIcon(Icons.person), findsOneWidget);
      });

      testWidgets('uses correct styling for assigned state', (tester) async {
        await tester.pumpWidget(createTestWidget(
          availableAssignees: testAssignees,
          currentAssignee: 'John Doe',
        ));

        // Find the avatar
        final avatar = find.byType(CircleAvatar);
        expect(avatar, findsOneWidget);
        
        final avatarWidget = tester.widget<CircleAvatar>(avatar);
        expect(avatarWidget.child, isA<Icon>());
        
        final icon = avatarWidget.child as Icon;
        expect(icon.icon, Icons.person);
      });
    });

    group('Interaction Tests', () {
      testWidgets('tapping card opens bottom sheet', (tester) async {
        await tester.pumpWidget(createTestWidget(
          availableAssignees: testAssignees,
        ));

        // Tap the card
        await tester.tap(find.byType(Card));
        await tester.pumpAndSettle();

        // Should open bottom sheet
        expect(find.text('Assign Engineer'), findsNWidgets(2)); // One in main widget, one in bottom sheet
        expect(find.text('Cancel'), findsOneWidget);
      });

      testWidgets('bottom sheet shows all available assignees', (tester) async {
        await tester.pumpWidget(createTestWidget(
          availableAssignees: testAssignees,
        ));

        // Open bottom sheet
        await tester.tap(find.byType(Card));
        await tester.pumpAndSettle();

        // Should show all assignees
        expect(find.text('John Doe'), findsOneWidget);
        expect(find.text('jane.smith@example.com'), findsOneWidget);
        expect(find.text('Jane Smith'), findsOneWidget);
        expect(find.text('Bob Wilson'), findsOneWidget);
      });

      testWidgets('bottom sheet shows unassign option', (tester) async {
        await tester.pumpWidget(createTestWidget(
          availableAssignees: testAssignees,
          currentAssignee: 'John Doe',
        ));

        // Open bottom sheet
        await tester.tap(find.byType(Card));
        await tester.pumpAndSettle();

        // Should show unassign option
        expect(find.text('Unassigned'), findsOneWidget);
        expect(find.byIcon(Icons.person_remove), findsOneWidget);
      });
    });

    group('Bottom Sheet Tests', () {
      testWidgets('displays correct header', (tester) async {
        await tester.pumpWidget(createTestWidget(
          availableAssignees: testAssignees,
        ));

        await tester.tap(find.byType(Card));
        await tester.pumpAndSettle();

        expect(find.text('Assign Engineer'), findsAtLeastNWidget(1));
        expect(find.text('Cancel'), findsNWidgets(2)); // Header cancel and bottom cancel
      });

      testWidgets('shows handle bar', (tester) async {
        await tester.pumpWidget(createTestWidget(
          availableAssignees: testAssignees,
        ));

        await tester.tap(find.byType(Card));
        await tester.pumpAndSettle();

        // Find the handle bar (small container at top)
        final handleBar = find.byWidgetPredicate(
          (widget) => widget is Container && 
                      widget.constraints?.maxWidth == 40 &&
                      widget.constraints?.maxHeight == 4,
        );
        expect(handleBar, findsOneWidget);
      });

      testWidgets('highlights current selection', (tester) async {
        await tester.pumpWidget(createTestWidget(
          availableAssignees: testAssignees,
          currentAssignee: 'John Doe',
        ));

        await tester.tap(find.byType(Card));
        await tester.pumpAndSettle();

        // Should show check icon for current assignee
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
      });

      testWidgets('can select different assignee', (tester) async {
        String? selectedAssignee;
        
        await tester.pumpWidget(createTestWidget(
          availableAssignees: testAssignees,
          currentAssignee: 'John Doe',
          onAssigneeSelected: (assignee) {
            selectedAssignee = assignee;
          },
        ));

        await tester.tap(find.byType(Card));
        await tester.pumpAndSettle();

        // Tap on Jane Smith
        await tester.tap(find.text('Jane Smith'));
        await tester.pumpAndSettle();

        // Tap Assign button
        await tester.tap(find.text('Assign').last);
        await tester.pumpAndSettle();

        expect(selectedAssignee, 'Jane Smith');
      });

      testWidgets('can unassign engineer', (tester) async {
        String? selectedAssignee = 'initial';
        
        await tester.pumpWidget(createTestWidget(
          availableAssignees: testAssignees,
          currentAssignee: 'John Doe',
          onAssigneeSelected: (assignee) {
            selectedAssignee = assignee;
          },
        ));

        await tester.tap(find.byType(Card));
        await tester.pumpAndSettle();

        // Tap on Unassigned option
        await tester.tap(find.text('Unassigned'));
        await tester.pumpAndSettle();

        // Tap Assign button
        await tester.tap(find.text('Assign').last);
        await tester.pumpAndSettle();

        expect(selectedAssignee, null);
      });

      testWidgets('can cancel selection', (tester) async {
        String? selectedAssignee = 'initial';
        
        await tester.pumpWidget(createTestWidget(
          availableAssignees: testAssignees,
          currentAssignee: 'John Doe',
          onAssigneeSelected: (assignee) {
            selectedAssignee = assignee;
          },
        ));

        await tester.tap(find.byType(Card));
        await tester.pumpAndSettle();

        // Select different assignee
        await tester.tap(find.text('Jane Smith'));
        await tester.pumpAndSettle();

        // Cancel instead of assign
        await tester.tap(find.text('Cancel').first);
        await tester.pumpAndSettle();

        // Should not call onAssigneeSelected
        expect(selectedAssignee, 'initial');
      });
    });

    group('Assignee Option Rendering Tests', () {
      testWidgets('displays assignee information correctly', (tester) async {
        await tester.pumpWidget(createTestWidget(
          availableAssignees: testAssignees,
        ));

        await tester.tap(find.byType(Card));
        await tester.pumpAndSettle();

        // Check first assignee
        expect(find.text('John Doe'), findsOneWidget);
        expect(find.text('john.doe@example.com'), findsOneWidget);
        
        // Check avatar for assignee
        expect(find.byIcon(Icons.person), findsAtLeastNWidget(1));
      });

      testWidgets('displays unassign option correctly', (tester) async {
        await tester.pumpWidget(createTestWidget(
          availableAssignees: testAssignees,
        ));

        await tester.tap(find.byType(Card));
        await tester.pumpAndSettle();

        // Check unassign option
        expect(find.text('Unassigned'), findsOneWidget);
        expect(find.byIcon(Icons.person_remove), findsOneWidget);
      });

      testWidgets('shows selection state correctly', (tester) async {
        await tester.pumpWidget(createTestWidget(
          availableAssignees: testAssignees,
          currentAssignee: 'John Doe',
        ));

        await tester.tap(find.byType(Card));
        await tester.pumpAndSettle();

        // John Doe should be selected
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
        
        // Other assignees should not be selected
        final checkIcons = find.byIcon(Icons.check_circle);
        expect(checkIcons, findsOneWidget);
      });
    });

    group('State Management Tests', () {
      testWidgets('updates when currentAssignee changes', (tester) async {
        await tester.pumpWidget(createTestWidget(
          availableAssignees: testAssignees,
          currentAssignee: null,
        ));

        expect(find.text('Assign Engineer'), findsOneWidget);

        // Update with assigned engineer
        await tester.pumpWidget(createTestWidget(
          availableAssignees: testAssignees,
          currentAssignee: 'John Doe',
        ));

        expect(find.text('John Doe'), findsOneWidget);
        expect(find.text('Tap to reassign'), findsOneWidget);
      });

      testWidgets('updates when availableAssignees changes', (tester) async {
        await tester.pumpWidget(createTestWidget(
          availableAssignees: [testAssignees.first],
        ));

        await tester.tap(find.byType(Card));
        await tester.pumpAndSettle();

        // Should show only one assignee
        expect(find.text('John Doe'), findsOneWidget);
        expect(find.text('Jane Smith'), findsNothing);

        // Close bottom sheet
        await tester.tap(find.text('Cancel').first);
        await tester.pumpAndSettle();

        // Update with more assignees
        await tester.pumpWidget(createTestWidget(
          availableAssignees: testAssignees,
        ));

        await tester.tap(find.byType(Card));
        await tester.pumpAndSettle();

        // Should show all assignees
        expect(find.text('John Doe'), findsOneWidget);
        expect(find.text('Jane Smith'), findsOneWidget);
        expect(find.text('Bob Wilson'), findsOneWidget);
      });
    });
  });
}
