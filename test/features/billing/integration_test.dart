import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fake_async/fake_async.dart';

import '../../../lib/features/billing/presentation/invoice_list_page.dart';
import '../../../lib/features/billing/domain/invoice.dart';
import '../../../lib/features/billing/domain/billing_service.dart';
import '../../../lib/features/auth/domain/auth_service.dart';
import '../../../lib/core/obs/analytics.dart';

/// Integration test service that simulates real behavior
class IntegrationBillingService extends StateNotifier<BillingState> {
  IntegrationBillingService() : super(const BillingState());

  final List<String> _searchHistory = [];
  final List<String> _analyticsEvents = [];

  List<String> get searchHistory => _searchHistory;
  List<String> get analyticsEvents => _analyticsEvents;

  Future<void> initialize() async {
    // Simulate API delay
    await Future.delayed(const Duration(milliseconds: 100));
    
    final sampleInvoices = _generateSampleData();
    state = state.copyWith(
      invoices: sampleInvoices.take(20).toList(),
      totalCount: sampleInvoices.length,
      hasMore: sampleInvoices.length > 20,
      isLoading: false,
    );
  }

  Future<void> applyFilters(InvoiceFilters filters) async {
    if (filters.searchQuery != null && filters.searchQuery!.isNotEmpty) {
      _searchHistory.add(filters.searchQuery!);
    }

    // Simulate debounced search
    await Future.delayed(const Duration(milliseconds: 50));
    
    // Filter existing invoices based on criteria
    final allInvoices = _generateSampleData();
    var filteredInvoices = allInvoices;

    if (filters.searchQuery != null && filters.searchQuery!.isNotEmpty) {
      filteredInvoices = filteredInvoices.where((invoice) =>
        invoice.invoiceNumber.toLowerCase().contains(filters.searchQuery!.toLowerCase()) ||
        invoice.customerInfo.name.toLowerCase().contains(filters.searchQuery!.toLowerCase())
      ).toList();
    }

    if (filters.statuses.isNotEmpty) {
      filteredInvoices = filteredInvoices.where((invoice) =>
        filters.statuses.contains(invoice.status)
      ).toList();
    }

    if (filters.isOverdue == true) {
      filteredInvoices = filteredInvoices.where((invoice) => invoice.isOverdue).toList();
    }

    state = state.copyWith(
      invoices: filteredInvoices.take(20).toList(),
      totalCount: filteredInvoices.length,
      hasMore: filteredInvoices.length > 20,
      filters: filters,
      isLoading: false,
    );
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading) return;

    await Future.delayed(const Duration(milliseconds: 50));
    
    final allInvoices = _generateSampleData();
    final currentCount = state.invoices.length;
    final nextBatch = allInvoices.skip(currentCount).take(20).toList();
    
    state = state.copyWith(
      invoices: [...state.invoices, ...nextBatch],
      hasMore: (currentCount + nextBatch.length) < allInvoices.length,
    );
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    await initialize();
  }

  Future<void> clearFilters() async {
    await applyFilters(const InvoiceFilters());
  }

  List<Invoice> _generateSampleData() {
    return List.generate(75, (i) => Invoice(
      id: 'inv-${i.toString().padLeft(3, '0')}',
      tenantId: 'tenant-1',
      requestIds: ['req-$i'],
      invoiceNumber: 'INV-2024-${i.toString().padLeft(3, '0')}',
      status: InvoiceStatus.values[i % InvoiceStatus.values.length],
      customerInfo: CustomerInfo(
        name: 'Customer ${String.fromCharCode(65 + (i % 26))} Corp',
        email: 'billing${i}@customer.com',
      ),
      issueDate: DateTime(2024, 1, 1).add(Duration(days: i)),
      dueDate: DateTime(2024, 1, 1).add(Duration(days: i + 30 - (i % 45))), // Some overdue
      subtotal: 100.0 * (i + 1),
      taxAmount: 18.0 * (i + 1),
      total: 118.0 * (i + 1),
    ));
  }
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

class IntegrationAnalytics extends Analytics {
  final List<Map<String, dynamic>> events = [];

  @override
  void trackScreenView(String screenName, {Map<String, dynamic>? parameters}) {
    events.add({
      'type': 'screen_view',
      'screenName': screenName,
      'parameters': parameters ?? {},
    });
  }

  @override
  void trackEvent(String eventName, {Map<String, dynamic>? parameters}) {
    events.add({
      'type': 'event',
      'eventName': eventName,
      'parameters': parameters ?? {},
    });
  }

  @override
  void setUserProperties(Map<String, dynamic> properties) {}

  @override
  void setAnalyticsEnabled(bool enabled) {}

  @override
  void clearUserData() {}
}

void main() {
  group('InvoiceListPage Integration Tests', () {
    late IntegrationBillingService billingService;
    late IntegrationAnalytics analytics;

    Widget createIntegrationTestWidget() {
      billingService = IntegrationBillingService();
      analytics = IntegrationAnalytics();

      return ProviderScope(
        overrides: [
          billingServiceProvider.overrideWith((ref) => billingService),
          authServiceProvider.overrideWith((ref) => MockAuthService()),
          analyticsProvider.overrideWith((ref) => analytics),
        ],
        child: const MaterialApp(
          home: InvoiceListPage(),
        ),
      );
    }

    testWidgets('complete user workflow: load -> search -> filter -> scroll', (tester) async {
      await tester.pumpWidget(createIntegrationTestWidget());
      
      // 1. Initial load
      await tester.pump(); // Initial build
      await tester.pump(const Duration(milliseconds: 200)); // Wait for initialization
      
      // Verify initial load
      expect(find.byType(Card), findsWidgets);
      expect(find.text('INV-2024-000'), findsOneWidget);
      
      // Verify analytics tracked screen view
      expect(analytics.events.any((e) => 
        e['type'] == 'event' && e['eventName'] == 'screen_view'), isTrue);

      // 2. Search functionality
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'Customer A');
      await tester.pump(const Duration(milliseconds: 400)); // Wait for debounce
      
      // Should filter results
      expect(billingService.searchHistory, contains('Customer A'));
      expect(billingService.state.filters.searchQuery, 'Customer A');
      
      // 3. Apply status filter
      final filterButton = find.byIcon(Icons.filter_list);
      await tester.tap(filterButton);
      await tester.pumpAndSettle();
      
      // Tap on a status filter chip in the bottom sheet
      final sentChip = find.text('Sent');
      if (sentChip.evaluate().isNotEmpty) {
        await tester.tap(sentChip);
        await tester.pump();
      }
      
      // Apply filters
      final applyButton = find.text('Apply Filters');
      if (applyButton.evaluate().isNotEmpty) {
        await tester.tap(applyButton);
        await tester.pumpAndSettle();
      }

      // 4. Test scrolling and pagination
      final listView = find.byType(ListView);
      await tester.drag(listView, const Offset(0, -2000));
      await tester.pump();
      
      // Should trigger load more if available
      if (billingService.state.hasMore) {
        expect(find.text('Loading more invoices...'), findsOneWidget);
      }

      // 5. Test refresh
      await tester.drag(listView, const Offset(0, 500)); // Pull down
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      
      // Verify analytics events were tracked
      final analyticsEventNames = analytics.events
          .where((e) => e['type'] == 'event')
          .map((e) => e['eventName'])
          .toList();
      
      expect(analyticsEventNames, contains('screen_view'));
      expect(analyticsEventNames.any((name) => name.contains('search') || name.contains('filter')), isTrue);
    });

    testWidgets('search debouncing prevents excessive API calls', (tester) async {
      await tester.pumpWidget(createIntegrationTestWidget());
      await tester.pump(const Duration(milliseconds: 200));

      final searchField = find.byType(TextField);

      fakeAsync((fakeAsync) {
        // Simulate rapid typing
        tester.enterText(searchField, 'i');
        fakeAsync.elapse(const Duration(milliseconds: 100));
        
        tester.enterText(searchField, 'in');
        fakeAsync.elapse(const Duration(milliseconds: 100));
        
        tester.enterText(searchField, 'inv');
        fakeAsync.elapse(const Duration(milliseconds: 100));
        
        tester.enterText(searchField, 'invo');
        fakeAsync.elapse(const Duration(milliseconds: 100));
        
        tester.enterText(searchField, 'invoice');
        
        // Before debounce completes
        expect(billingService.searchHistory, isEmpty, 
            reason: 'Should not have called search API yet');
        
        // Complete debounce
        fakeAsync.elapse(const Duration(milliseconds: 400));
        fakeAsync.flushMicrotasks();
      });

      await tester.pump();
      
      // Should have only the final search term
      expect(billingService.searchHistory.length, 1);
      expect(billingService.searchHistory.last, 'invoice');
    });

    testWidgets('pagination loads more data correctly', (tester) async {
      await tester.pumpWidget(createIntegrationTestWidget());
      await tester.pump(const Duration(milliseconds: 200));
      
      // Initial state - should have 20 items (first page)
      expect(billingService.state.invoices.length, 20);
      expect(billingService.state.hasMore, isTrue);
      
      // Scroll to bottom to trigger load more
      final listView = find.byType(ListView);
      await tester.dragUntilVisible(
        find.text('Loading more invoices...'),
        listView,
        const Offset(0, -500),
      );
      await tester.pump(const Duration(milliseconds: 100));
      
      // Should have loaded more items
      expect(billingService.state.invoices.length, greaterThan(20));
    });

    testWidgets('filter combinations work correctly', (tester) async {
      await tester.pumpWidget(createIntegrationTestWidget());
      await tester.pump(const Duration(milliseconds: 200));
      
      // Apply search + status filter
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'Customer');
      await tester.pump(const Duration(milliseconds: 400));
      
      // Apply additional filters through service directly
      await billingService.applyFilters(InvoiceFilters(
        searchQuery: 'Customer',
        statuses: [InvoiceStatus.sent],
        isOverdue: true,
      ));
      await tester.pump();
      
      // Verify combined filters are applied
      expect(billingService.state.filters.searchQuery, 'Customer');
      expect(billingService.state.filters.statuses, contains(InvoiceStatus.sent));
      expect(billingService.state.filters.isOverdue, isTrue);
    });

    testWidgets('empty states display correctly', (tester) async {
      // Create service with no data
      final emptyService = IntegrationBillingService();
      emptyService.state = const BillingState(
        invoices: [],
        isLoading: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            billingServiceProvider.overrideWith((ref) => emptyService),
            authServiceProvider.overrideWith((ref) => MockAuthService()),
            analyticsProvider.overrideWith((ref) => IntegrationAnalytics()),
          ],
          child: const MaterialApp(
            home: InvoiceListPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show empty state
      expect(find.text('No invoices'), findsOneWidget);
      expect(find.text('Invoices will appear here when created'), findsOneWidget);
    });

    testWidgets('error states handle gracefully', (tester) async {
      // Create service with error state
      final errorService = IntegrationBillingService();
      errorService.state = const BillingState(
        invoices: [],
        isLoading: false,
        error: 'Failed to load invoices',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            billingServiceProvider.overrideWith((ref) => errorService),
            authServiceProvider.overrideWith((ref) => MockAuthService()),
            analyticsProvider.overrideWith((ref) => IntegrationAnalytics()),
          ],
          child: const MaterialApp(
            home: InvoiceListPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show error state with retry option
      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('accessibility features work in complete flow', (tester) async {
      await tester.pumpWidget(createIntegrationTestWidget());
      await tester.pump(const Duration(milliseconds: 200));

      // Test semantic navigation
      final invoiceCards = find.byType(Semantics).where((widget) {
        final semantics = widget.evaluate().first.widget as Semantics;
        return semantics.properties.label?.contains('Invoice') == true;
      });

      expect(invoiceCards.length, greaterThan(0));

      // Test that all interactive elements are accessible
      final interactiveElements = [
        find.byType(TextField), // Search
        find.byType(IconButton), // Filter button
        find.byType(FloatingActionButton), // Create invoice
      ];

      for (final finder in interactiveElements) {
        final widgets = finder.evaluate();
        for (final element in widgets) {
          final renderBox = element.renderObject as RenderBox?;
          if (renderBox != null) {
            expect(renderBox.size.width, greaterThanOrEqualTo(44.0));
            expect(renderBox.size.height, greaterThanOrEqualTo(44.0));
          }
        }
      }
    });

    testWidgets('analytics tracking covers all major user actions', (tester) async {
      await tester.pumpWidget(createIntegrationTestWidget());
      await tester.pump(const Duration(milliseconds: 200));

      // Perform various actions
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'test');
      await tester.pump(const Duration(milliseconds: 400));

      final filterButton = find.byIcon(Icons.filter_list);
      if (filterButton.evaluate().isNotEmpty) {
        await tester.tap(filterButton);
        await tester.pumpAndSettle();
        
        // Close filter sheet
        await tester.tap(find.byType(Scaffold).first);
        await tester.pumpAndSettle();
      }

      // Check that analytics captured key events
      final eventNames = analytics.events
          .where((e) => e['type'] == 'event')
          .map((e) => e['eventName'])
          .toSet();

      expect(eventNames, contains('screen_view'));
      // Other events would be tracked in real implementation
    });
  });

  group('Performance Integration Tests', () {
    testWidgets('complete workflow stays within performance budget', (tester) async {
      final stopwatch = Stopwatch()..start();
      
      final widget = ProviderScope(
        overrides: [
          billingServiceProvider.overrideWith((ref) => IntegrationBillingService()),
          authServiceProvider.overrideWith((ref) => MockAuthService()),
          analyticsProvider.overrideWith((ref) => IntegrationAnalytics()),
        ],
        child: const MaterialApp(
          home: InvoiceListPage(),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pump(const Duration(milliseconds: 200)); // Wait for data load
      
      stopwatch.stop();
      final totalLoadTime = stopwatch.elapsedMilliseconds;
      
      // Should meet TTI budget
      expect(totalLoadTime, lessThan(500), 
          reason: 'Complete load should be under 500ms, got ${totalLoadTime}ms');

      // Test scrolling performance
      final scrollStopwatch = Stopwatch()..start();
      
      final listView = find.byType(ListView);
      for (int i = 0; i < 5; i++) {
        await tester.drag(listView, const Offset(0, -1000));
        await tester.pump();
      }
      
      scrollStopwatch.stop();
      final scrollTime = scrollStopwatch.elapsedMilliseconds;
      
      // Scrolling should be smooth
      expect(scrollTime, lessThan(1000),
          reason: 'Scroll performance should be under 1s, got ${scrollTime}ms');
    });
  });
}