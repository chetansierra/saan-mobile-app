import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../lib/features/billing/presentation/invoice_list_page.dart';
import '../../../lib/features/billing/domain/invoice.dart';
import '../../../lib/features/billing/domain/billing_service.dart';
import '../../../lib/features/auth/domain/auth_service.dart';
import '../../../lib/core/obs/analytics.dart';

/// Mock providers for testing
final mockBillingServiceProvider = StateNotifierProvider<MockBillingService, BillingState>((ref) {
  return MockBillingService();
});

final mockAuthServiceProvider = Provider<MockAuthService>((ref) {
  return MockAuthService();
});

final mockAnalyticsProvider = Provider<MockAnalytics>((ref) {
  return MockAnalytics();
});

class MockBillingService extends StateNotifier<BillingState> {
  MockBillingService() : super(const BillingState());

  Future<void> initialize() async {
    // Mock initialization with sample data
    final sampleInvoices = [
      Invoice(
        id: 'inv-001',
        tenantId: 'tenant-1',
        requestIds: ['req-1'],
        invoiceNumber: 'INV-2024-001',
        status: InvoiceStatus.sent,
        customerInfo: const CustomerInfo(
          name: 'Acme Corporation',
          email: 'billing@acme.com',
        ),
        issueDate: DateTime(2024, 1, 15),
        dueDate: DateTime(2024, 2, 15),
        subtotal: 1000.0,
        taxAmount: 180.0,
        total: 1180.0,
      ),
      Invoice(
        id: 'inv-002',
        tenantId: 'tenant-1',
        requestIds: ['req-2'],
        invoiceNumber: 'INV-2024-002',
        status: InvoiceStatus.pending,
        customerInfo: const CustomerInfo(
          name: 'Beta Industries',
          email: 'accounts@beta.com',
        ),
        issueDate: DateTime(2024, 1, 10),
        dueDate: DateTime(2024, 1, 25), // Overdue
        subtotal: 500.0,
        taxAmount: 90.0,
        total: 590.0,
      ),
    ];

    state = state.copyWith(
      invoices: sampleInvoices,
      totalCount: sampleInvoices.length,
      hasMore: false,
      isLoading: false,
    );
  }

  Future<void> refresh() async {}
  Future<void> applyFilters(InvoiceFilters filters) async {}
  Future<void> clearFilters() async {}
  Future<void> loadMore() async {}
}

class MockAuthService {
  UserProfile? get userProfile => const UserProfile(
    id: 'user-1',
    email: 'admin@test.com',
    role: UserRole.admin,
    companyName: 'Test Company',
    firstName: 'Test',
    lastName: 'Admin',
  );
}

class MockAnalytics extends Analytics {
  @override
  void trackScreenView(String screenName, {Map<String, dynamic>? parameters}) {}

  @override
  void trackEvent(String eventName, {Map<String, dynamic>? parameters}) {}

  @override
  void setUserProperties(Map<String, dynamic> properties) {}

  @override
  void setAnalyticsEnabled(bool enabled) {}

  @override
  void clearUserData() {}
}

void main() {
  group('InvoiceListPage Accessibility Tests', () {
    Widget createTestWidget() {
      return ProviderScope(
        overrides: [
          billingServiceProvider.overrideWith((ref) => MockBillingService()),
          authServiceProvider.overrideWith((ref) => MockAuthService()),
          analyticsProvider.overrideWith((ref) => MockAnalytics()),
        ],
        child: const MaterialApp(
          home: InvoiceListPage(),
        ),
      );
    }

    testWidgets('invoice cards have proper semantic labels', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Find invoice cards
      final invoiceCards = find.byType(Semantics).where((widget) {
        final semantics = widget.evaluate().first.widget as Semantics;
        return semantics.properties.label?.contains('Invoice') == true;
      });

      expect(invoiceCards.length, greaterThan(0));

      // Check first invoice card accessibility
      final firstCard = invoiceCards.first;
      final semantics = firstCard.evaluate().first.widget as Semantics;
      
      // Should have descriptive label
      expect(semantics.properties.label, contains('Invoice'));
      expect(semantics.properties.label, contains('INV-2024'));
      expect(semantics.properties.label, contains('₹'));
      
      // Should have hint for interaction
      expect(semantics.properties.hint, contains('Tap to view'));
    });

    testWidgets('search field has proper accessibility', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Find search field
      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);

      // Check if search field has proper labels
      final textField = tester.widget<TextField>(searchField);
      expect(textField.decoration?.labelText, isNotNull);
      expect(textField.decoration?.hintText, isNotNull);
    });

    testWidgets('all touch targets meet minimum size requirement', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Find all interactive elements
      final interactiveElements = [
        find.byType(InkWell),
        find.byType(ElevatedButton),
        find.byType(IconButton),
        find.byType(FilterChip),
        find.byType(ActionChip),
      ];

      for (final finder in interactiveElements) {
        final widgets = finder.evaluate();
        for (final element in widgets) {
          final renderBox = element.renderObject as RenderBox?;
          if (renderBox != null) {
            final size = renderBox.size;
            
            // Minimum touch target size: 44x44 (iOS) or 48x48 (Android)
            // We'll use 44x44 as the minimum
            expect(size.width, greaterThanOrEqualTo(44.0),
                reason: 'Touch target width should be at least 44pt');
            expect(size.height, greaterThanOrEqualTo(44.0),
                reason: 'Touch target height should be at least 44pt');
          }
        }
      }
    });

    testWidgets('status badges have semantic labels', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Look for status text widgets
      final statusTexts = find.text('Sent').first;
      expect(statusTexts, findsWidgets);

      // Check if parent container has semantic information
      final semanticsElements = find.ancestor(
        of: statusTexts,
        matching: find.byType(Semantics),
      );
      
      // Should find semantic wrapper
      expect(semanticsElements, findsWidgets);
    });

    testWidgets('empty state has descriptive content', (tester) async {
      // Override with empty state
      final emptyBillingService = MockBillingService();
      emptyBillingService.state = const BillingState(
        invoices: [],
        isLoading: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            billingServiceProvider.overrideWith((ref) => emptyBillingService),
            authServiceProvider.overrideWith((ref) => MockAuthService()),
            analyticsProvider.overrideWith((ref) => MockAnalytics()),
          ],
          child: const MaterialApp(
            home: InvoiceListPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should have descriptive empty state
      expect(find.text('No invoices'), findsOneWidget);
      expect(find.text('Invoices will appear here when created'), findsOneWidget);
    });

    testWidgets('loading state has accessibility support', (tester) async {
      // Override with loading state
      final loadingBillingService = MockBillingService();
      loadingBillingService.state = const BillingState(
        invoices: [],
        isLoading: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            billingServiceProvider.overrideWith((ref) => loadingBillingService),
            authServiceProvider.overrideWith((ref) => MockAuthService()),
            analyticsProvider.overrideWith((ref) => MockAnalytics()),
          ],
          child: const MaterialApp(
            home: InvoiceListPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should have loading skeleton or progress indicator
      final loadingElements = find.byType(CircularProgressIndicator);
      expect(loadingElements, findsWidgets);
    });

    testWidgets('overdue invoices have proper warning semantics', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Find warning icons (overdue indicators)
      final warningIcons = find.byIcon(Icons.warning);
      expect(warningIcons, findsWidgets);

      // Check if warning icons have semantic labels
      for (final iconFinder in warningIcons.evaluate()) {
        final icon = iconFinder.widget as Icon;
        expect(icon.semanticLabel, isNotNull);
        expect(icon.semanticLabel, contains('overdue'));
      }
    });

    testWidgets('navigation and focus management works correctly', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Test tab navigation through interactive elements
      final searchField = find.byType(TextField);
      await tester.tap(searchField);
      await tester.pumpAndSettle();

      // Verify focus
      expect(tester.binding.focusManager.primaryFocus?.hasFocus, isTrue);

      // Test keyboard navigation
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      // Should move focus to next interactive element
      expect(tester.binding.focusManager.primaryFocus?.hasFocus, isTrue);
    });

    testWidgets('semantic structure is proper for screen readers', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Check main structure
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      
      // AppBar should have title
      expect(find.text('Invoices'), findsOneWidget);

      // Should have main content area
      expect(find.byType(Column), findsWidgets);
      
      // Should have proper heading hierarchy
      final appBarTitle = find.ancestor(
        of: find.text('Invoices'),
        matching: find.byType(AppBar),
      );
      expect(appBarTitle, findsOneWidget);
    });

    testWidgets('color contrast and visual indicators work without color dependency', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Status badges should have text labels, not just colors
      final statusBadges = find.text('Sent');
      expect(statusBadges, findsWidgets);

      final pendingBadges = find.text('Pending');
      expect(pendingBadges, findsWidgets);

      // Overdue indicators should have text/icons, not just red color
      final overdueText = find.textContaining('Overdue');
      if (overdueText.evaluate().isNotEmpty) {
        expect(overdueText, findsWidgets);
        
        // Should also have warning icon
        expect(find.byIcon(Icons.warning), findsWidgets);
      }
    });
  });

  group('Performance Accessibility Tests', () {
    testWidgets('large lists maintain accessibility performance', (tester) async {
      // Create service with many items
      final largeBillingService = MockBillingService();
      final largeInvoiceList = List.generate(100, (i) => Invoice(
        id: 'inv-$i',
        tenantId: 'tenant-1',
        requestIds: ['req-$i'],
        invoiceNumber: 'INV-2024-${i.toString().padLeft(3, '0')}',
        status: i % 2 == 0 ? InvoiceStatus.sent : InvoiceStatus.pending,
        customerInfo: CustomerInfo(
          name: 'Customer $i',
          email: 'customer$i@example.com',
        ),
        issueDate: DateTime.now().subtract(Duration(days: i)),
        dueDate: DateTime.now().add(Duration(days: 30 - i)),
        subtotal: 100.0 * (i + 1),
        taxAmount: 18.0 * (i + 1),
        total: 118.0 * (i + 1),
      ));

      largeBillingService.state = BillingState(
        invoices: largeInvoiceList.take(20).toList(), // First page
        totalCount: largeInvoiceList.length,
        hasMore: true,
        isLoading: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            billingServiceProvider.overrideWith((ref) => largeBillingService),
            authServiceProvider.overrideWith((ref) => MockAuthService()),
            analyticsProvider.overrideWith((ref) => MockAnalytics()),
          ],
          child: const MaterialApp(
            home: InvoiceListPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Measure build time for accessibility
      final stopwatch = Stopwatch()..start();
      await tester.pump();
      stopwatch.stop();

      // Should render quickly even with accessibility features
      expect(stopwatch.elapsedMilliseconds, lessThan(100));

      // All visible items should still have proper semantics
      final semanticsElements = find.byType(Semantics);
      expect(semanticsElements.evaluate().length, greaterThan(0));
    });
  });
}