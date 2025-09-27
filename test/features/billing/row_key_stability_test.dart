import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../lib/features/billing/domain/invoice.dart';

void main() {
  group('Row Key Stability Tests', () {
    testWidgets('invoice rows maintain stable keys during reorder', (tester) async {
      final testService = _TestInvoiceService();
      final buildTracker = _BuildTracker();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            _invoiceServiceProvider.overrideWith((ref) => testService),
            _buildTrackerProvider.overrideWith((ref) => buildTracker),
          ],
          child: const MaterialApp(
            home: _TestInvoiceListWidget(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initial state: 3 invoices
      expect(testService.state.invoices.length, 3);
      buildTracker.reset();

      // Reorder by date filter (newest first)
      testService.applySort(InvoiceSortOrder.dateDesc);
      await tester.pump();

      // With stable keys, existing widgets should not rebuild
      expect(buildTracker.totalBuilds, 0,
          reason: 'No invoice rows should rebuild with stable keys during reorder');

      // Verify order changed but widgets preserved
      final reorderedInvoices = testService.state.invoices;
      expect(reorderedInvoices.first.id, 'inv-003', 
          reason: 'Newest invoice should be first');
      expect(reorderedInvoices.last.id, 'inv-001',
          reason: 'Oldest invoice should be last');
    });

    testWidgets('filter changes maintain key stability for matching items', (tester) async {
      final testService = _TestInvoiceService();
      final buildTracker = _BuildTracker();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            _invoiceServiceProvider.overrideWith((ref) => testService),
            _buildTrackerProvider.overrideWith((ref) => buildTracker),
          ],
          child: const MaterialApp(
            home: _TestInvoiceListWidget(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      buildTracker.reset();

      // Apply status filter - only 'sent' status invoices
      testService.applyFilter(InvoiceStatus.sent);
      await tester.pump();

      // Items that match the filter should not rebuild
      final sentInvoiceBuilds = buildTracker.getBuildCountForInvoice('inv-001'); // sent status
      expect(sentInvoiceBuilds, 0,
          reason: 'Matching invoice should not rebuild when filter applied');

      // Verify filtered results
      final filteredInvoices = testService.state.invoices;
      expect(filteredInvoices.length, 2, 
          reason: 'Should have 2 sent invoices');
      expect(filteredInvoices.every((inv) => inv.status == InvoiceStatus.sent), isTrue);
    });

    testWidgets('adding new item preserves existing keys', (tester) async {
      final testService = _TestInvoiceService();
      final buildTracker = _BuildTracker();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            _invoiceServiceProvider.overrideWith((ref) => testService),
            _buildTrackerProvider.overrideWith((ref) => buildTracker),
          ],
          child: const MaterialApp(
            home: _TestInvoiceListWidget(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      buildTracker.reset();

      // Add new invoice
      testService.addInvoice(_createInvoice('inv-004', DateTime.now(), InvoiceStatus.draft));
      await tester.pump();

      // Existing items should not rebuild
      expect(buildTracker.getBuildCountForInvoice('inv-001'), 0);
      expect(buildTracker.getBuildCountForInvoice('inv-002'), 0);
      expect(buildTracker.getBuildCountForInvoice('inv-003'), 0);

      // Only new item should build
      expect(buildTracker.getBuildCountForInvoice('inv-004'), 1,
          reason: 'New invoice should build once');

      // Verify list length
      expect(testService.state.invoices.length, 4);
    });

    testWidgets('removing item does not affect other keys', (tester) async {
      final testService = _TestInvoiceService();
      final buildTracker = _BuildTracker();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            _invoiceServiceProvider.overrideWith((ref) => testService),
            _buildTrackerProvider.overrideWith((ref) => buildTracker),
          ],
          child: const MaterialApp(
            home: _TestInvoiceListWidget(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      buildTracker.reset();

      // Remove middle item
      testService.removeInvoice('inv-002');
      await tester.pump();

      // Remaining items should not rebuild
      expect(buildTracker.getBuildCountForInvoice('inv-001'), 0,
          reason: 'Remaining items should not rebuild when item removed');
      expect(buildTracker.getBuildCountForInvoice('inv-003'), 0,
          reason: 'Remaining items should not rebuild when item removed');

      // Verify list length
      expect(testService.state.invoices.length, 2);
      expect(testService.state.invoices.any((inv) => inv.id == 'inv-002'), isFalse);
    });

    testWidgets('updating single item only rebuilds that item', (tester) async {
      final testService = _TestInvoiceService();
      final buildTracker = _BuildTracker();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            _invoiceServiceProvider.overrideWith((ref) => testService),
            _buildTrackerProvider.overrideWith((ref) => buildTracker),
          ],
          child: const MaterialApp(
            home: _TestInvoiceListWidget(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      buildTracker.reset();

      // Update single invoice status
      testService.updateInvoiceStatus('inv-002', InvoiceStatus.paid);
      await tester.pump();

      // Only updated item should rebuild
      expect(buildTracker.getBuildCountForInvoice('inv-002'), 1,
          reason: 'Updated invoice should rebuild once');
      
      // Other items should not rebuild
      expect(buildTracker.getBuildCountForInvoice('inv-001'), 0);
      expect(buildTracker.getBuildCountForInvoice('inv-003'), 0);

      // Verify update applied
      final updatedInvoice = testService.state.invoices.firstWhere((inv) => inv.id == 'inv-002');
      expect(updatedInvoice.status, InvoiceStatus.paid);
    });

    testWidgets('complex state changes with stable keys perform well', (tester) async {
      final testService = _TestInvoiceService();
      final buildTracker = _BuildTracker();

      // Start with larger dataset
      for (int i = 4; i <= 20; i++) {
        testService.addInvoice(_createInvoice('inv-${i.toString().padLeft(3, '0')}', 
            DateTime.now().subtract(Duration(days: i)), InvoiceStatus.sent));
      }

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            _invoiceServiceProvider.overrideWith((ref) => testService),
            _buildTrackerProvider.overrideWith((ref) => buildTracker),
          ],
          child: const MaterialApp(
            home: _TestInvoiceListWidget(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      buildTracker.reset();

      // Perform multiple operations
      testService.applySort(InvoiceSortOrder.amountDesc);
      await tester.pump();
      
      testService.applyFilter(InvoiceStatus.sent);
      await tester.pump();
      
      testService.updateInvoiceStatus('inv-010', InvoiceStatus.paid);
      await tester.pump();

      // Measure total rebuilds
      final totalRebuilds = buildTracker.totalBuilds;
      
      // Should be minimal rebuilds with stable keys
      expect(totalRebuilds, lessThan(5),
          reason: 'Complex operations should cause minimal rebuilds with stable keys');
    });

    testWidgets('key uniqueness prevents widget confusion', (tester) async {
      final testService = _TestInvoiceService();

      // Add invoices with similar data but different IDs
      testService.addInvoice(_createInvoice('inv-duplicate-1', DateTime.now(), InvoiceStatus.sent));
      testService.addInvoice(_createInvoice('inv-duplicate-2', DateTime.now(), InvoiceStatus.sent));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            _invoiceServiceProvider.overrideWith((ref) => testService),
          ],
          child: const MaterialApp(
            home: _TestInvoiceListWidget(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find both cards
      final card1 = find.byKey(const ValueKey('inv-duplicate-1'));
      final card2 = find.byKey(const ValueKey('inv-duplicate-2'));

      expect(card1, findsOneWidget, reason: 'Each invoice should have unique key');
      expect(card2, findsOneWidget, reason: 'Each invoice should have unique key');

      // Verify keys are different
      final widget1 = tester.widget<Widget>(card1);
      final widget2 = tester.widget<Widget>(card2);
      expect(widget1.key, isNot(equals(widget2.key)),
          reason: 'Keys should be unique even for similar data');
    });

    testWidgets('scroll position maintained during key-stable operations', (tester) async {
      final testService = _TestInvoiceService();
      final scrollController = ScrollController();

      // Large dataset
      for (int i = 4; i <= 50; i++) {
        testService.addInvoice(_createInvoice('inv-${i.toString().padLeft(3, '0')}', 
            DateTime.now().subtract(Duration(days: i)), InvoiceStatus.sent));
      }

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            _invoiceServiceProvider.overrideWith((ref) => testService),
          ],
          child: MaterialApp(
            home: _TestInvoiceListWidget(scrollController: scrollController),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to middle
      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pumpAndSettle();

      final scrollPositionBefore = scrollController.position.pixels;
      expect(scrollPositionBefore, greaterThan(1000));

      // Perform operation that maintains keys
      testService.applySort(InvoiceSortOrder.amountAsc);
      await tester.pump();

      // Scroll position should be preserved with stable keys
      final scrollPositionAfter = scrollController.position.pixels;
      expect((scrollPositionAfter - scrollPositionBefore).abs(), lessThan(100),
          reason: 'Scroll position should be approximately maintained with stable keys');
    });
  });
}

/// Test invoice service
class _TestInvoiceService extends StateNotifier<_InvoiceState> {
  _TestInvoiceService() : super(_InvoiceState(invoices: [
    _createInvoice('inv-001', DateTime(2025, 1, 1), InvoiceStatus.sent),
    _createInvoice('inv-002', DateTime(2025, 1, 2), InvoiceStatus.pending),
    _createInvoice('inv-003', DateTime(2025, 1, 3), InvoiceStatus.sent),
  ]));

  void applySort(InvoiceSortOrder sortOrder) {
    final sortedInvoices = List<Invoice>.from(state.invoices);
    
    switch (sortOrder) {
      case InvoiceSortOrder.dateDesc:
        sortedInvoices.sort((a, b) => b.issueDate.compareTo(a.issueDate));
        break;
      case InvoiceSortOrder.dateAsc:
        sortedInvoices.sort((a, b) => a.issueDate.compareTo(b.issueDate));
        break;
      case InvoiceSortOrder.amountDesc:
        sortedInvoices.sort((a, b) => b.total.compareTo(a.total));
        break;
      case InvoiceSortOrder.amountAsc:
        sortedInvoices.sort((a, b) => a.total.compareTo(b.total));
        break;
    }
    
    state = state.copyWith(invoices: sortedInvoices, sortOrder: sortOrder);
  }

  void applyFilter(InvoiceStatus status) {
    final filteredInvoices = state.invoices.where((inv) => inv.status == status).toList();
    state = state.copyWith(invoices: filteredInvoices, filterStatus: status);
  }

  void addInvoice(Invoice invoice) {
    state = state.copyWith(invoices: [...state.invoices, invoice]);
  }

  void removeInvoice(String invoiceId) {
    final updatedInvoices = state.invoices.where((inv) => inv.id != invoiceId).toList();
    state = state.copyWith(invoices: updatedInvoices);
  }

  void updateInvoiceStatus(String invoiceId, InvoiceStatus newStatus) {
    final updatedInvoices = state.invoices.map((inv) {
      if (inv.id == invoiceId) {
        return Invoice(
          id: inv.id,
          tenantId: inv.tenantId,
          requestIds: inv.requestIds,
          invoiceNumber: inv.invoiceNumber,
          status: newStatus,
          customerInfo: inv.customerInfo,
          issueDate: inv.issueDate,
          dueDate: inv.dueDate,
          subtotal: inv.subtotal,
          taxAmount: inv.taxAmount,
          total: inv.total,
        );
      }
      return inv;
    }).toList();
    
    state = state.copyWith(invoices: updatedInvoices);
  }
}

final _invoiceServiceProvider = StateNotifierProvider<_TestInvoiceService, _InvoiceState>((ref) {
  return _TestInvoiceService();
});

/// Build tracking service
class _BuildTracker extends StateNotifier<Map<String, int>> {
  _BuildTracker() : super({});

  void recordBuild(String invoiceId) {
    state = {...state, invoiceId: (state[invoiceId] ?? 0) + 1};
  }

  int getBuildCountForInvoice(String invoiceId) {
    return state[invoiceId] ?? 0;
  }

  int get totalBuilds => state.values.fold(0, (sum, count) => sum + count);

  void reset() {
    state = {};
  }
}

final _buildTrackerProvider = StateNotifierProvider<_BuildTracker, Map<String, int>>((ref) {
  return _BuildTracker();
});

/// Test widget
class _TestInvoiceListWidget extends ConsumerWidget {
  const _TestInvoiceListWidget({this.scrollController});
  
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoiceState = ref.watch(_invoiceServiceProvider);

    return Scaffold(
      body: ListView.builder(
        controller: scrollController,
        itemCount: invoiceState.invoices.length,
        itemBuilder: (context, index) {
          final invoice = invoiceState.invoices[index];
          return _TestInvoiceCard(
            key: ValueKey(invoice.id), // Stable key based on ID
            invoice: invoice,
          );
        },
      ),
    );
  }
}

/// Test invoice card that tracks builds
class _TestInvoiceCard extends ConsumerWidget {
  const _TestInvoiceCard({required this.invoice, super.key});
  
  final Invoice invoice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Record build for tracking
    ref.read(_buildTrackerProvider.notifier).recordBuild(invoice.id!);
    
    return Card(
      child: ListTile(
        title: Text(invoice.invoiceNumber),
        subtitle: Text(invoice.customerInfo.name),
        trailing: Chip(
          label: Text(invoice.status.displayName),
          backgroundColor: Color(int.parse('0xFF${invoice.status.colorHex.substring(1)}')),
        ),
      ),
    );
  }
}

/// Helper classes
enum InvoiceSortOrder { dateDesc, dateAsc, amountDesc, amountAsc }

class _InvoiceState {
  final List<Invoice> invoices;
  final InvoiceSortOrder? sortOrder;
  final InvoiceStatus? filterStatus;

  const _InvoiceState({
    required this.invoices,
    this.sortOrder,
    this.filterStatus,
  });

  _InvoiceState copyWith({
    List<Invoice>? invoices,
    InvoiceSortOrder? sortOrder,
    InvoiceStatus? filterStatus,
  }) {
    return _InvoiceState(
      invoices: invoices ?? this.invoices,
      sortOrder: sortOrder ?? this.sortOrder,
      filterStatus: filterStatus ?? this.filterStatus,
    );
  }
}

/// Helper function
Invoice _createInvoice(String id, DateTime issueDate, InvoiceStatus status) {
  return Invoice(
    id: id,
    tenantId: 'tenant-1',
    requestIds: [id.replaceAll('inv', 'req')],
    invoiceNumber: id.toUpperCase().replaceAll('INV-', 'INV-2025-'),
    status: status,
    customerInfo: CustomerInfo(
      name: 'Customer ${id.substring(4)}',
      email: '$id@example.com',
    ),
    issueDate: issueDate,
    dueDate: issueDate.add(const Duration(days: 30)),
    subtotal: 100.0 + (id.hashCode % 1000),
    taxAmount: 18.0 + (id.hashCode % 180),
    total: 118.0 + (id.hashCode % 1180),
  );
}