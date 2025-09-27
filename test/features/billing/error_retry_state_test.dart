import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../lib/features/billing/domain/invoice.dart';
import '../../../lib/features/billing/domain/billing_service.dart';

void main() {
  group('Error Retry State Preservation', () {
    testWidgets('network error on load more preserves scroll position and cursor', (tester) async {
      final testService = _TestBillingServiceWithErrors()
        ..setInitialData()
        ..setErrorOnLoadMore(true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            billingServiceProvider.overrideWith((ref) => testService),
          ],
          child: const MaterialApp(
            home: _TestInvoiceListWidget(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initial state: 20 items loaded
      expect(testService.state.invoices.length, 20);
      expect(testService.state.hasMore, isTrue);
      final initialCursor = testService.state.cursor;
      expect(initialCursor, isNotNull);

      // Scroll to bottom to trigger load more
      final listView = find.byType(ListView);
      await tester.dragUntilVisible(
        find.text('Loading more...'),
        listView,
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();

      // Should show error state
      expect(testService.state.error, contains('Failed to load more'));
      expect(testService.state.isLoading, isFalse);
      
      // Verify scroll position preserved (approximate)
      final scrollController = _getScrollController(tester);
      final scrollPositionAfterError = scrollController?.position.pixels ?? 0;
      expect(scrollPositionAfterError, greaterThan(1000), // Should be scrolled down
          reason: 'Scroll position should be preserved after error');

      // Verify cursor and state preserved
      expect(testService.state.cursor, equals(initialCursor),
          reason: 'Cursor should be preserved after error');
      expect(testService.state.invoices.length, 20,
          reason: 'Existing items should be preserved');
      expect(testService.state.hasMore, isTrue,
          reason: 'hasMore should remain true for retry');
    });

    testWidgets('retry after error restores loading state and preserves context', (tester) async {
      final testService = _TestBillingServiceWithErrors()
        ..setInitialData()
        ..setErrorOnLoadMore(true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            billingServiceProvider.overrideWith((ref) => testService),
          ],
          child: const MaterialApp(
            home: _TestInvoiceListWidget(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Trigger error
      await testService.loadMore();
      await tester.pump();

      expect(testService.state.error, isNotNull);
      final preRetryState = testService.state;

      // Clear error and retry
      testService.setErrorOnLoadMore(false);
      await testService.loadMore();
      await tester.pump();

      // Verify retry success
      expect(testService.state.error, isNull);
      expect(testService.state.invoices.length, greaterThan(preRetryState.invoices.length),
          reason: 'More items should be loaded after successful retry');
      
      // Context should be preserved
      expect(testService.state.filters, equals(preRetryState.filters),
          reason: 'Filters should be preserved during retry');
    });

    testWidgets('multiple consecutive errors maintain state integrity', (tester) async {
      final testService = _TestBillingServiceWithErrors()
        ..setInitialData();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            billingServiceProvider.overrideWith((ref) => testService),
          ],
          child: const MaterialApp(
            home: _TestInvoiceListWidget(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final initialState = testService.state;

      // Trigger multiple errors
      for (int i = 0; i < 3; i++) {
        testService.setErrorOnLoadMore(true);
        await testService.loadMore();
        await tester.pump();

        expect(testService.state.error, isNotNull);
        expect(testService.state.invoices.length, equals(initialState.invoices.length),
            reason: 'Invoice count should remain stable through errors');
        expect(testService.state.cursor, equals(initialState.cursor),
            reason: 'Cursor should remain stable through errors');
      }

      // Final retry succeeds
      testService.setErrorOnLoadMore(false);
      await testService.loadMore();
      await tester.pump();

      expect(testService.state.error, isNull);
      expect(testService.state.invoices.length, greaterThan(initialState.invoices.length));
    });

    testWidgets('error during search preserves search query and results', (tester) async {
      final testService = _TestBillingServiceWithErrors()
        ..setInitialData();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            billingServiceProvider.overrideWith((ref) => testService),
          ],
          child: const MaterialApp(
            home: _TestInvoiceListWidget(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Apply search filter
      const searchQuery = 'test search';
      final searchFilters = InvoiceFilters(searchQuery: searchQuery);
      await testService.applyFilters(searchFilters);
      await tester.pump();

      expect(testService.state.filters.searchQuery, searchQuery);
      final searchResults = testService.state.invoices;

      // Trigger error on next operation
      testService.setErrorOnLoadMore(true);
      await testService.loadMore();
      await tester.pump();

      // Search context should be preserved
      expect(testService.state.filters.searchQuery, searchQuery,
          reason: 'Search query should be preserved during error');
      expect(testService.state.invoices, equals(searchResults),
          reason: 'Search results should be preserved during error');
    });

    testWidgets('error toast displays and dismisses correctly', (tester) async {
      final testService = _TestBillingServiceWithErrors()
        ..setInitialData()
        ..setErrorOnLoadMore(true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            billingServiceProvider.overrideWith((ref) => testService),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: _TestInvoiceListWidget(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Trigger error
      await testService.loadMore();
      await tester.pump();

      // Error should be displayed (in real implementation, this would be a toast/snackbar)
      expect(testService.state.error, isNotNull);
      expect(find.text('Failed to load more'), findsOneWidget);

      // Clear error manually (simulating toast dismissal)
      testService.clearError();
      await tester.pump();

      expect(testService.state.error, isNull);
      expect(find.text('Failed to load more'), findsNothing);
    });

    testWidgets('error state persists across widget rebuilds', (tester) async {
      final testService = _TestBillingServiceWithErrors()
        ..setInitialData()
        ..setErrorOnLoadMore(true);

      final key = GlobalKey();
      
      Widget buildTestWidget(bool rebuildTrigger) {
        return ProviderScope(
          overrides: [
            billingServiceProvider.overrideWith((ref) => testService),
          ],
          child: MaterialApp(
            key: rebuildTrigger ? key : null,
            home: const _TestInvoiceListWidget(),
          ),
        );
      }

      await tester.pumpWidget(buildTestWidget(false));
      await tester.pumpAndSettle();

      // Trigger error
      await testService.loadMore();  
      await tester.pump();

      expect(testService.state.error, isNotNull);
      final errorState = testService.state;

      // Rebuild widget tree
      await tester.pumpWidget(buildTestWidget(true));
      await tester.pumpAndSettle();

      // Error state should persist
      expect(testService.state.error, equals(errorState.error));
      expect(testService.state.invoices.length, equals(errorState.invoices.length));
      expect(testService.state.cursor, equals(errorState.cursor));
    });

    testWidgets('retry button appears and functions correctly', (tester) async {
      final testService = _TestBillingServiceWithErrors()
        ..setInitialData()
        ..setErrorOnLoadMore(true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            billingServiceProvider.overrideWith((ref) => testService),
          ],
          child: const MaterialApp(
            home: _TestInvoiceListWidget(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Trigger error
      await testService.loadMore();
      await tester.pump();

      // Retry button should appear
      expect(find.text('Retry'), findsOneWidget);
      expect(testService.state.error, isNotNull);

      // Tap retry button
      testService.setErrorOnLoadMore(false); // Allow retry to succeed
      await tester.tap(find.text('Retry'));
      await tester.pump();

      // Error should be cleared and more items loaded
      expect(testService.state.error, isNull);
      expect(find.text('Retry'), findsNothing);
      expect(testService.state.invoices.length, greaterThan(20));
    });
  });
}

/// Test service that can simulate errors
class _TestBillingServiceWithErrors extends StateNotifier<BillingState> {
  _TestBillingServiceWithErrors() : super(const BillingState());

  bool _errorOnLoadMore = false;
  int _loadMoreCallCount = 0;

  void setInitialData() {
    final invoices = List.generate(20, (i) => Invoice(
      id: 'inv-${i.toString().padLeft(3, '0')}',
      tenantId: 'tenant-1',
      requestIds: ['req-$i'],
      invoiceNumber: 'INV-2025-${i.toString().padLeft(3, '0')}',
      status: InvoiceStatus.sent,
      customerInfo: CustomerInfo(
        name: 'Customer $i',
        email: 'customer$i@example.com',
      ),
      issueDate: DateTime.now().subtract(Duration(hours: i)),
      dueDate: DateTime.now().add(Duration(days: 30 - i)),
      subtotal: 100.0 * (i + 1),
      taxAmount: 18.0 * (i + 1),
      total: 118.0 * (i + 1),
    ));

    state = state.copyWith(
      invoices: invoices,
      totalCount: 50,
      hasMore: true,
      cursor: InvoiceCursor.fromInvoice(invoices.last),
      isLoading: false,
    );
  }

  void setErrorOnLoadMore(bool shouldError) {
    _errorOnLoadMore = shouldError;
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading) return;

    _loadMoreCallCount++;

    if (_errorOnLoadMore) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load more invoices (attempt $_loadMoreCallCount)',
      );
      return;
    }

    // Simulate successful load more
    final currentCount = state.invoices.length;
    final nextBatch = List.generate(10, (i) => Invoice(
      id: 'inv-${(currentCount + i).toString().padLeft(3, '0')}',
      tenantId: 'tenant-1',
      requestIds: ['req-${currentCount + i}'],
      invoiceNumber: 'INV-2025-${(currentCount + i).toString().padLeft(3, '0')}',
      status: InvoiceStatus.pending,
      customerInfo: CustomerInfo(
        name: 'Customer ${currentCount + i}',
        email: 'customer${currentCount + i}@example.com',
      ),
      issueDate: DateTime.now().subtract(Duration(hours: currentCount + i)),
      dueDate: DateTime.now().add(Duration(days: 30 - (currentCount + i))),
      subtotal: 100.0 * (currentCount + i + 1),
      taxAmount: 18.0 * (currentCount + i + 1),
      total: 118.0 * (currentCount + i + 1),
    ));

    state = state.copyWith(
      invoices: [...state.invoices, ...nextBatch],
      hasMore: (currentCount + nextBatch.length) < 50,
      cursor: nextBatch.isNotEmpty ? InvoiceCursor.fromInvoice(nextBatch.last) : state.cursor,
      isLoading: false,
      error: null,
    );
  }

  Future<void> applyFilters(InvoiceFilters filters) async {
    state = state.copyWith(filters: filters);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Test widget that displays invoice list with error handling
class _TestInvoiceListWidget extends ConsumerWidget {
  const _TestInvoiceListWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billingState = ref.watch(billingServiceProvider);

    return Column(
      children: [
        if (billingState.error != null)
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.red.withOpacity(0.1),
            child: Row(
              children: [
                Expanded(child: Text(billingState.error!)),
                ElevatedButton(
                  onPressed: () => ref.read(billingServiceProvider.notifier).loadMore(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: billingState.invoices.length + (billingState.hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= billingState.invoices.length) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Loading more...'),
                  ),
                );
              }
              
              final invoice = billingState.invoices[index];
              return ListTile(
                key: ValueKey(invoice.id),
                title: Text(invoice.invoiceNumber),
                subtitle: Text(invoice.customerInfo.name),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Helper to get scroll controller from widget tree
ScrollController? _getScrollController(WidgetTester tester) {
  try {
    final scrollView = tester.widget<ListView>(find.byType(ListView));
    return scrollView.controller;
  } catch (e) {
    return null;
  }
}