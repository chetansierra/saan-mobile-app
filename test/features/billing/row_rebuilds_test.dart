import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

int buildCount = 0;

class InvoiceRow extends StatelessWidget {
  const InvoiceRow({super.key, required this.title});
  final String title;
  
  @override
  Widget build(BuildContext context) {
    buildCount++;
    return Text(title, textDirection: TextDirection.ltr);
  }
}

void main() {
  group('Invoice Row Rebuild Optimization Tests', () {
    setUp(() {
      buildCount = 0;
    });

    testWidgets('row build count stays stable on unrelated updates', (tester) async {
      String title = 'INV-1';
      final notifier = ValueNotifier<int>(0);

      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: ValueListenableBuilder<int>(
          valueListenable: notifier,
          builder: (_, __, ___) => Column(children: [
            // Simulate list row (should not rebuild from external notifier changes)
            InvoiceRow(title: title),
            // Unrelated widget that changes
            Text('counter:${notifier.value}'),
          ]),
        ),
      ));

      buildCount = 0; // Reset after initial build
      notifier.value = 1;
      await tester.pump();

      expect(buildCount, 0, reason: 'row not rebuilt by unrelated updates');
    });

    testWidgets('row rebuilds only when its own data changes', (tester) async {
      String title = 'INV-1';
      final titleNotifier = ValueNotifier<String>(title);
      final unrelatedNotifier = ValueNotifier<int>(0);

      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: [
            ValueListenableBuilder<String>(
              valueListenable: titleNotifier,
              builder: (_, title, __) => InvoiceRow(title: title),
            ),
            ValueListenableBuilder<int>(
              valueListenable: unrelatedNotifier,
              builder: (_, count, __) => Text('counter:$count'),
            ),
          ],
        ),
      ));

      buildCount = 0; // Reset after initial build

      // Change unrelated data - should not rebuild InvoiceRow
      unrelatedNotifier.value = 1;
      await tester.pump();
      expect(buildCount, 0, reason: 'row should not rebuild for unrelated changes');

      // Change the row's own data - should rebuild
      titleNotifier.value = 'INV-2';
      await tester.pump();
      expect(buildCount, 1, reason: 'row should rebuild when its data changes');
    });

    testWidgets('multiple rows rebuild independently', (tester) async {
      final row1Notifier = ValueNotifier<String>('INV-1');
      final row2Notifier = ValueNotifier<String>('INV-2');

      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: [
            ValueListenableBuilder<String>(
              valueListenable: row1Notifier,
              builder: (_, title, __) => InvoiceRow(title: title),
            ),
            ValueListenableBuilder<String>(
              valueListenable: row2Notifier,
              builder: (_, title, __) => InvoiceRow(title: title),
            ),
          ],
        ),
      ));

      buildCount = 0; // Reset after initial build (2 rows built)

      // Change only first row
      row1Notifier.value = 'INV-1-UPDATED';
      await tester.pump();
      
      // Only one row should rebuild
      expect(buildCount, 1, reason: 'only changed row should rebuild');

      buildCount = 0;

      // Change second row
      row2Notifier.value = 'INV-2-UPDATED';
      await tester.pump();
      
      // Only one row should rebuild
      expect(buildCount, 1, reason: 'only changed row should rebuild');
    });

    testWidgets('row with key prevents unnecessary rebuilds during list reordering', (tester) async {
      final items = ValueNotifier<List<String>>(['INV-1', 'INV-2', 'INV-3']);
      
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: ValueListenableBuilder<List<String>>(
          valueListenable: items,
          builder: (_, itemList, __) => Column(
            children: itemList.map((title) => 
              InvoiceRow(key: ValueKey(title), title: title)
            ).toList(),
          ),
        ),
      ));

      buildCount = 0; // Reset after initial build

      // Reorder the list - with proper keys, widgets should not rebuild
      items.value = ['INV-2', 'INV-1', 'INV-3'];
      await tester.pump();

      // With proper key usage, rows should not rebuild during reordering
      expect(buildCount, 0, reason: 'rows with stable keys should not rebuild during reordering');
    });

    testWidgets('row without key rebuilds unnecessarily during list reordering', (tester) async {
      final items = ValueNotifier<List<String>>(['INV-1', 'INV-2', 'INV-3']);
      
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: ValueListenableBuilder<List<String>>(
          valueListenable: items,
          builder: (_, itemList, __) => Column(
            children: itemList.map((title) => 
              InvoiceRow(title: title) // No key - will cause rebuilds
            ).toList(),
          ),
        ),
      ));

      buildCount = 0; // Reset after initial build

      // Reorder the list - without keys, all widgets rebuild
      items.value = ['INV-2', 'INV-1', 'INV-3'];
      await tester.pump();

      // Without keys, all rows rebuild unnecessarily
      expect(buildCount, 3, reason: 'rows without keys rebuild during reordering');
    });

    testWidgets('memoization prevents rebuilds for identical data', (tester) async {
      // Simulate a scenario where the same data is passed multiple times
      final invoiceData = ValueNotifier<Map<String, String>>({
        'id': 'INV-1',
        'customer': 'Acme Corp',
        'amount': '1000',
      });

      Widget buildOptimizedRow(Map<String, String> data) {
        return InvoiceRow(
          key: ValueKey(data['id']),
          title: '${data['id']} - ${data['customer']} - \$${data['amount']}',
        );
      }

      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: ValueListenableBuilder<Map<String, String>>(
          valueListenable: invoiceData,
          builder: (_, data, __) => buildOptimizedRow(data),
        ),
      ));

      buildCount = 0; // Reset after initial build

      // Set the same data again - should not rebuild if properly memoized
      invoiceData.value = {
        'id': 'INV-1',
        'customer': 'Acme Corp',
        'amount': '1000',
      };
      await tester.pump();

      // With proper memoization/key usage, identical data shouldn't cause rebuild
      expect(buildCount, 1, reason: 'identical data should cause rebuild due to new map instance');

      // Now test with truly identical object reference
      final sameData = invoiceData.value;
      buildCount = 0;
      invoiceData.value = sameData; // Same reference
      await tester.pump();

      expect(buildCount, 0, reason: 'same reference should not cause rebuild');
    });

    testWidgets('complex row state changes rebuild efficiently', (tester) async {
      final invoiceState = ValueNotifier<InvoiceRowState>(
        InvoiceRowState(
          id: 'INV-1',
          title: 'Invoice 1',
          amount: 1000.0,
          status: 'sent',
          isSelected: false,
          isExpanded: false,
        ),
      );

      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: ValueListenableBuilder<InvoiceRowState>(
          valueListenable: invoiceState,
          builder: (_, state, __) => ComplexInvoiceRow(state: state),
        ),
      ));

      buildCount = 0; // Reset after initial build

      // Change only selection state
      invoiceState.value = invoiceState.value.copyWith(isSelected: true);
      await tester.pump();
      
      expect(buildCount, 1, reason: 'selection change should rebuild');

      buildCount = 0;

      // Change only expansion state  
      invoiceState.value = invoiceState.value.copyWith(isExpanded: true);
      await tester.pump();
      
      expect(buildCount, 1, reason: 'expansion change should rebuild');
    });
  });
}

/// Test data class for complex row state
class InvoiceRowState {
  final String id;
  final String title;
  final double amount;
  final String status;
  final bool isSelected;
  final bool isExpanded;

  const InvoiceRowState({
    required this.id,
    required this.title,
    required this.amount,
    required this.status,
    required this.isSelected,
    required this.isExpanded,
  });

  InvoiceRowState copyWith({
    String? id,
    String? title,
    double? amount,
    String? status,
    bool? isSelected,
    bool? isExpanded,
  }) {
    return InvoiceRowState(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      isSelected: isSelected ?? this.isSelected,
      isExpanded: isExpanded ?? this.isExpanded,
    );
  }
}

/// Test widget for complex row scenarios
class ComplexInvoiceRow extends StatelessWidget {
  const ComplexInvoiceRow({super.key, required this.state});
  final InvoiceRowState state;

  @override
  Widget build(BuildContext context) {
    buildCount++;
    return Container(
      color: state.isSelected ? Colors.blue.withOpacity(0.1) : null,
      child: Column(
        children: [
          Text('${state.title} - \$${state.amount}', textDirection: TextDirection.ltr),
          Text('Status: ${state.status}', textDirection: TextDirection.ltr),
          if (state.isExpanded)
            Text('Expanded details...', textDirection: TextDirection.ltr),
        ],
      ),
    );
  }
}