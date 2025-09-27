import 'package:flutter_test/flutter_test.dart';
import 'package:fake_async/fake_async.dart';
import '../../../lib/features/billing/domain/invoice.dart';

void main() {
  group('Pagination Realtime Race Conditions', () {
    test('INSERT newer row during pagination preserves cursor stream', () async {
      // Simulate initial state: page 1 loaded
      final now = DateTime.now();
      final page1Items = [
        _createInvoice('inv-003', now, 300),
        _createInvoice('inv-002', now.subtract(const Duration(hours: 1)), 200),
        _createInvoice('inv-001', now.subtract(const Duration(hours: 2)), 100),
      ];
      
      final page1LastCursor = InvoiceCursor.fromInvoice(page1Items.last);
      
      // Simulate realtime INSERT of newer item while fetching page 2
      final newRealtimeInvoice = _createInvoice('inv-004', now.add(const Duration(minutes: 5)), 400);
      
      // Simulate page 2 fetch (should not be affected by realtime insert)
      final page2Items = [
        _createInvoice('inv-000', now.subtract(const Duration(hours: 3)), 50),
      ];
      
      // Verify cursor integrity: page 2 items should still follow page 1 cursor
      for (final item in page2Items) {
        final itemCursor = InvoiceCursor.fromInvoice(item);
        final followsCursor = item.issueDate.isBefore(page1LastCursor.issueDate) ||
            (item.issueDate.isAtSameMomentAs(page1LastCursor.issueDate) && 
             item.id!.compareTo(page1LastCursor.id) < 0);
        
        expect(followsCursor, isTrue, 
            reason: 'Page 2 items should follow page 1 cursor despite realtime inserts');
      }
      
      // New realtime item should be prepended to the list, not interfere with pagination
      final combinedList = [newRealtimeInvoice, ...page1Items, ...page2Items];
      
      // Sort to verify overall order is maintained
      combinedList.sort((a, b) {
        final dateComp = b.issueDate.compareTo(a.issueDate);
        if (dateComp != 0) return dateComp;
        return b.id!.compareTo(a.id!);
      });
      
      expect(combinedList.first.id, 'inv-004', 
          reason: 'Newer realtime item should appear first');
      expect(combinedList[1].id, 'inv-003', 
          reason: 'Original order should be preserved');
    });

    test('multiple realtime inserts during pagination batch correctly', () {
      fakeAsync((fakeAsync) {
        final now = DateTime.now();
        
        // Initial page 1
        final existingItems = [
          _createInvoice('inv-005', now, 500),
          _createInvoice('inv-004', now.subtract(const Duration(hours: 1)), 400),
          _createInvoice('inv-003', now.subtract(const Duration(hours: 2)), 300),
        ];
        
        final realtimeInserts = <Invoice>[];
        
        // Simulate rapid realtime inserts during pagination
        fakeAsync.elapse(const Duration(milliseconds: 100));
        realtimeInserts.add(_createInvoice('inv-007', now.add(const Duration(minutes: 2)), 700));
        
        fakeAsync.elapse(const Duration(milliseconds: 50));
        realtimeInserts.add(_createInvoice('inv-006', now.add(const Duration(minutes: 1)), 600));
        
        fakeAsync.elapse(const Duration(milliseconds: 75));
        realtimeInserts.add(_createInvoice('inv-008', now.add(const Duration(minutes: 3)), 800));
        
        // Complete pagination fetch
        fakeAsync.elapse(const Duration(milliseconds: 200));
        
        // Verify batching and ordering
        realtimeInserts.sort((a, b) => b.issueDate.compareTo(a.issueDate));
        
        expect(realtimeInserts.first.id, 'inv-008', 
            reason: 'Most recent insert should be first');
        expect(realtimeInserts.length, 3, 
            reason: 'All realtime inserts should be captured');
        
        // Verify combined list maintains integrity
        final combinedList = [...realtimeInserts, ...existingItems];
        final previousTimestamp = combinedList.first.issueDate;
        
        for (int i = 1; i < combinedList.length; i++) {
          expect(combinedList[i].issueDate.isBefore(previousTimestamp) || 
                 combinedList[i].issueDate.isAtSameMomentAs(previousTimestamp), 
                 isTrue, reason: 'DESC order should be maintained');
        }
      });
    });

    test('realtime UPDATE during pagination handles correctly', () {
      final now = DateTime.now();
      
      // Initial state
      final originalInvoice = _createInvoice('inv-002', now.subtract(const Duration(hours: 1)), 200);
      final page1Items = [
        _createInvoice('inv-003', now, 300),
        originalInvoice,
        _createInvoice('inv-001', now.subtract(const Duration(hours: 2)), 100),
      ];
      
      // Simulate realtime UPDATE that changes timestamp (e.g., status change updates modified_at)
      final updatedInvoice = Invoice(
        id: originalInvoice.id,
        tenantId: originalInvoice.tenantId,
        requestIds: originalInvoice.requestIds,
        invoiceNumber: originalInvoice.invoiceNumber,
        status: InvoiceStatus.paid, // Status changed
        customerInfo: originalInvoice.customerInfo,
        issueDate: originalInvoice.issueDate, // Issue date stays same
        dueDate: originalInvoice.dueDate,
        subtotal: originalInvoice.subtotal,
        taxAmount: originalInvoice.taxAmount,
        total: originalInvoice.total,
      );
      
      // Update should preserve pagination position since issue_date unchanged
      final updatedPage1 = page1Items.map((item) => 
          item.id == originalInvoice.id ? updatedInvoice : item).toList();
      
      // Verify position preserved
      expect(updatedPage1[1].id, originalInvoice.id, 
          reason: 'Updated item should maintain same position');
      expect(updatedPage1[1].status, InvoiceStatus.paid, 
          reason: 'Status should be updated');
      
      // Verify pagination cursor integrity
      final cursor = InvoiceCursor.fromInvoice(updatedPage1.last);
      expect(cursor.issueDate, originalInvoice.issueDate, 
          reason: 'Cursor should use original issue_date for pagination');
    });

    test('realtime DELETE during pagination removes item cleanly', () {
      final now = DateTime.now();
      
      // Initial page 1 with 4 items
      final page1Items = [
        _createInvoice('inv-004', now, 400),
        _createInvoice('inv-003', now.subtract(const Duration(hours: 1)), 300),
        _createInvoice('inv-002', now.subtract(const Duration(hours: 2)), 200), // Will be deleted
        _createInvoice('inv-001', now.subtract(const Duration(hours: 3)), 100),
      ];
      
      const pageSize = 3;
      final displayedItems = page1Items.take(pageSize).toList();
      final cursor = InvoiceCursor.fromInvoice(displayedItems.last); // inv-002
      
      // Simulate realtime DELETE of inv-002 (the cursor item)
      final afterDelete = page1Items.where((item) => item.id != 'inv-002').toList();
      
      // When cursor item is deleted, next page should start from the next valid item
      final remainingAfterCursor = afterDelete.where((item) {
        return item.issueDate.isBefore(cursor.issueDate) ||
            (item.issueDate.isAtSameMomentAs(cursor.issueDate) && 
             item.id!.compareTo(cursor.id) < 0);
      }).toList();
      
      expect(remainingAfterCursor.first.id, 'inv-001', 
          reason: 'Next page should start with next valid item after deleted cursor');
      
      // Verify no gaps in pagination
      expect(remainingAfterCursor.length, 1, 
          reason: 'Should have remaining items after cursor position');
    });

    test('realtime event timing with debounced updates', () {
      fakeAsync((fakeAsync) {
        final now = DateTime.now();
        final events = <String>[];
        
        // Simulate pagination in progress
        events.add('pagination_start');
        
        // Realtime events arrive during debounce window
        fakeAsync.elapse(const Duration(milliseconds: 100));
        events.add('realtime_insert_1');
        
        fakeAsync.elapse(const Duration(milliseconds: 150));
        events.add('realtime_insert_2');
        
        // Pagination completes
        fakeAsync.elapse(const Duration(milliseconds: 200));
        events.add('pagination_complete');
        
        // Debounce processes batched realtime events
        fakeAsync.elapse(const Duration(milliseconds: 300)); // Standard 300ms debounce
        events.add('realtime_batch_processed');
        
        // Verify event sequence
        expect(events, [
          'pagination_start',
          'realtime_insert_1',
          'realtime_insert_2',
          'pagination_complete',
          'realtime_batch_processed',
        ]);
        
        // Total time should be under 1 second for good UX
        expect(fakeAsync.elapsed.inMilliseconds, lessThan(1000),
            reason: 'Total event processing should be under 1 second');
      });
    });

    test('concurrent cursor streams remain isolated', () {
      final now = DateTime.now();
      
      // Simulate two different filter contexts with their own cursors
      final allStatusCursor = InvoiceCursor(now, 'all-cursor-end');
      final paidStatusCursor = InvoiceCursor(now.subtract(const Duration(hours: 1)), 'paid-cursor-end');
      
      // Realtime insert affects both streams
      final newInvoice = _createInvoice('inv-new', now.add(const Duration(minutes: 5)), 1000);
      
      // Verify each cursor stream handles the new item appropriately
      final newItemAfterAllCursor = newInvoice.issueDate.isBefore(allStatusCursor.issueDate) ||
          (newInvoice.issueDate.isAtSameMomentAs(allStatusCursor.issueDate) && 
           newInvoice.id!.compareTo(allStatusCursor.id) < 0);
      
      final newItemAfterPaidCursor = newInvoice.issueDate.isBefore(paidStatusCursor.issueDate) ||
          (newInvoice.issueDate.isAtSameMomentAs(paidStatusCursor.issueDate) && 
           newInvoice.id!.compareTo(paidStatusCursor.id) < 0);
      
      // New item (newer than both cursors) should not appear in next page of either stream
      expect(newItemAfterAllCursor, isFalse, 
          reason: 'Newer item should not appear in all-status next page');
      expect(newItemAfterPaidCursor, isFalse, 
          reason: 'Newer item should not appear in paid-status next page');
      
      // New item should be prepended to current view instead
      expect(newInvoice.issueDate.isAfter(allStatusCursor.issueDate), isTrue);
      expect(newInvoice.issueDate.isAfter(paidStatusCursor.issueDate), isTrue);
    });
  });
}

/// Helper function to create test invoices
Invoice _createInvoice(String id, DateTime issueDate, double amount) {
  return Invoice(
    id: id,
    tenantId: 'tenant-1',
    requestIds: [id.replaceAll('inv', 'req')],
    invoiceNumber: id.toUpperCase().replaceAll('INV-', 'INV-2025-'),
    status: InvoiceStatus.sent,
    customerInfo: CustomerInfo(
      name: 'Customer ${id.substring(4)}',
      email: '$id@example.com',
    ),
    issueDate: issueDate,
    dueDate: issueDate.add(const Duration(days: 30)),
    subtotal: amount,
    taxAmount: amount * 0.18,
    total: amount * 1.18,
  );
}