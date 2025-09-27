import 'package:flutter_test/flutter_test.dart';
import '../../../lib/features/billing/domain/invoice.dart';

void main() {
  group('Cursor Boundary Edge Cases', () {
    test('equal-timestamp boundary prevents duplicates and skips', () {
      final sharedTimestamp = DateTime(2025, 6, 15, 14, 30, 0, 0);
      
      // Simulate page N ending with this cursor
      final pageNLastItem = Invoice(
        id: 'inv-100',
        tenantId: 'tenant-1',
        requestIds: ['req-100'],
        invoiceNumber: 'INV-2025-100',
        status: InvoiceStatus.sent,
        customerInfo: const CustomerInfo(
          name: 'Customer 100',
          email: 'customer100@example.com',
        ),
        issueDate: sharedTimestamp, // Same timestamp
        dueDate: sharedTimestamp.add(const Duration(days: 30)),
        subtotal: 1000.0,
        taxAmount: 180.0,
        total: 1180.0,
      );

      // Page N+1 should start with items that have same timestamp but lower ID
      final pageN1FirstItem = Invoice(
        id: 'inv-099', // Lower ID (comes after in DESC order)
        tenantId: 'tenant-1',
        requestIds: ['req-099'],
        invoiceNumber: 'INV-2025-099',
        status: InvoiceStatus.pending,
        customerInfo: const CustomerInfo(
          name: 'Customer 099',
          email: 'customer099@example.com',
        ),
        issueDate: sharedTimestamp, // Same timestamp
        dueDate: sharedTimestamp.add(const Duration(days: 30)),
        subtotal: 990.0,
        taxAmount: 178.2,
        total: 1168.2,
      );

      final pageNCursor = InvoiceCursor.fromInvoice(pageNLastItem);
      
      // Verify cursor logic correctly identifies next page items
      final shouldBeInNextPage = InvoiceCursor.fromInvoice(pageN1FirstItem);
      expect(shouldBeInNextPage.issueDate, equals(pageNCursor.issueDate));
      expect(shouldBeInNextPage.id.compareTo(pageNCursor.id), lessThan(0));
      
      // Test SQL WHERE clause logic:
      // WHERE (issue_date < cursor.issueDate OR (issue_date = cursor.issueDate AND id < cursor.id))
      final matchesWhereClause = pageN1FirstItem.issueDate.isBefore(pageNCursor.issueDate) ||
          (pageN1FirstItem.issueDate.isAtSameMomentAs(pageNCursor.issueDate) && 
           pageN1FirstItem.id!.compareTo(pageNCursor.id) < 0);
      
      expect(matchesWhereClause, isTrue, 
          reason: 'Page N+1 first item should match cursor WHERE clause');
    });

    test('multiple items with same timestamp maintain strict ordering', () {
      final sharedTimestamp = DateTime(2025, 1, 1, 12, 0);
      
      // Create multiple invoices with same timestamp but different IDs
      final invoicesWithSameTimestamp = [
        'inv-105', 'inv-104', 'inv-103', 'inv-102', 'inv-101'
      ].map((id) => Invoice(
        id: id,
        tenantId: 'tenant-1',
        requestIds: [id.replaceAll('inv', 'req')],
        invoiceNumber: id.toUpperCase(),
        status: InvoiceStatus.draft,
        customerInfo: CustomerInfo(
          name: 'Customer ${id.substring(4)}',
          email: '$id@example.com',
        ),
        issueDate: sharedTimestamp,
        dueDate: sharedTimestamp.add(const Duration(days: 30)),
        subtotal: 100.0,
        taxAmount: 18.0,
        total: 118.0,
      )).toList();

      // Sort by DESC order (higher ID first, then lower)
      invoicesWithSameTimestamp.sort((a, b) => b.id!.compareTo(a.id!));
      
      // Verify strict ordering: inv-105, inv-104, inv-103, inv-102, inv-101
      expect(invoicesWithSameTimestamp[0].id, 'inv-105');
      expect(invoicesWithSameTimestamp[1].id, 'inv-104');
      expect(invoicesWithSameTimestamp[2].id, 'inv-103');
      expect(invoicesWithSameTimestamp[3].id, 'inv-102');
      expect(invoicesWithSameTimestamp[4].id, 'inv-101');

      // Test pagination boundaries
      // If page size is 3, page 1 ends with inv-103, page 2 starts with inv-102
      final page1LastCursor = InvoiceCursor.fromInvoice(invoicesWithSameTimestamp[2]); // inv-103
      final page2FirstItem = invoicesWithSameTimestamp[3]; // inv-102
      
      // Verify page 2 first item correctly follows cursor logic
      final matchesCursor = page2FirstItem.issueDate.isBefore(page1LastCursor.issueDate) ||
          (page2FirstItem.issueDate.isAtSameMomentAs(page1LastCursor.issueDate) && 
           page2FirstItem.id!.compareTo(page1LastCursor.id) < 0);
      
      expect(matchesCursor, isTrue, 
          reason: 'Page 2 first item should correctly follow cursor from page 1');
    });

    test('cursor handles microsecond precision timestamps', () {
      // Test with very precise timestamps (microseconds)
      final baseTime = DateTime(2025, 1, 1, 12, 0, 0, 0, 500); // 500 microseconds
      
      final invoice1 = Invoice(
        id: 'inv-001',
        tenantId: 'tenant-1',
        requestIds: ['req-001'],
        invoiceNumber: 'INV-001',
        status: InvoiceStatus.sent,
        customerInfo: const CustomerInfo(
          name: 'Customer 1',
          email: 'customer1@example.com',
        ),
        issueDate: baseTime,
        dueDate: baseTime.add(const Duration(days: 30)),
        subtotal: 100.0,
        taxAmount: 18.0,
        total: 118.0,
      );

      final invoice2 = Invoice(
        id: 'inv-002',
        tenantId: 'tenant-1',
        requestIds: ['req-002'],
        invoiceNumber: 'INV-002',
        status: InvoiceStatus.sent,
        customerInfo: const CustomerInfo(
          name: 'Customer 2',
          email: 'customer2@example.com',
        ),
        issueDate: baseTime.add(const Duration(microseconds: 1)), // 1 microsecond later
        dueDate: baseTime.add(const Duration(days: 30)),
        subtotal: 200.0,
        taxAmount: 36.0,
        total: 236.0,
      );

      // In DESC order, invoice2 should come first (newer timestamp)
      final cursor1 = InvoiceCursor.fromInvoice(invoice1);
      final cursor2 = InvoiceCursor.fromInvoice(invoice2);
      
      expect(invoice2.issueDate.isAfter(invoice1.issueDate), isTrue);
      expect(cursor1.issueDate.isBefore(cursor2.issueDate), isTrue);
    });

    test('boundary at page transition maintains data integrity', () {
      // Simulate a real pagination scenario with mixed timestamps
      final now = DateTime.now();
      
      final invoiceSet = [
        // Page 1 (newest first)
        _createInvoice('inv-010', now, 1000),
        _createInvoice('inv-009', now.subtract(const Duration(hours: 1)), 900),
        _createInvoice('inv-008', now.subtract(const Duration(hours: 2)), 800),
        
        // Page boundary - same timestamp
        _createInvoice('inv-007', now.subtract(const Duration(hours: 3)), 700),
        _createInvoice('inv-006', now.subtract(const Duration(hours: 3)), 600), // Same hour
        
        // Page 2
        _createInvoice('inv-005', now.subtract(const Duration(hours: 3)), 500), // Same hour
        _createInvoice('inv-004', now.subtract(const Duration(hours: 4)), 400),
        _createInvoice('inv-003', now.subtract(const Duration(hours: 5)), 300),
      ];

      // Sort in DESC order (newest first)
      invoiceSet.sort((a, b) {
        final dateComp = b.issueDate.compareTo(a.issueDate);
        if (dateComp != 0) return dateComp;
        return b.id!.compareTo(a.id!);
      });

      // If page size is 4, page 1 ends with inv-007, page 2 starts with inv-006
      const pageSize = 4;
      final page1Items = invoiceSet.take(pageSize).toList();
      final page2Items = invoiceSet.skip(pageSize).take(pageSize).toList();
      
      expect(page1Items.length, pageSize);
      expect(page1Items.last.id, 'inv-007');
      expect(page2Items.first.id, 'inv-006');
      
      // Verify no gaps or duplicates at boundary
      final page1LastCursor = InvoiceCursor.fromInvoice(page1Items.last);
      final page2FirstCursor = InvoiceCursor.fromInvoice(page2Items.first);
      
      // Page 2 first item should correctly follow page 1 last item
      final isCorrectSequence = page2FirstCursor.issueDate.isBefore(page1LastCursor.issueDate) ||
          (page2FirstCursor.issueDate.isAtSameMomentAs(page1LastCursor.issueDate) && 
           page2FirstCursor.id.compareTo(page1LastCursor.id) < 0);
      
      expect(isCorrectSequence, isTrue, 
          reason: 'Page boundary should maintain correct sequence without gaps');
      
      // Verify all items are unique
      final allIds = [...page1Items, ...page2Items].map((inv) => inv.id).toSet();
      expect(allIds.length, equals(page1Items.length + page2Items.length),
          reason: 'No duplicate items across page boundary');
    });
  });
}

/// Helper function to create test invoices
Invoice _createInvoice(String id, DateTime issueDate, double amount) {
  return Invoice(
    id: id,
    tenantId: 'tenant-1',
    requestIds: [id.replaceAll('inv', 'req')],
    invoiceNumber: id.toUpperCase().replaceAll('-', '-'),
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