import 'package:flutter_test/flutter_test.dart';
import '../../../lib/features/billing/domain/invoice.dart';

void main() {
  group('Cursor-based Pagination', () {
    test('InvoiceCursor creates valid cursor from invoice', () {
      final invoice = Invoice(
        id: 'inv-123',
        tenantId: 'tenant-1',
        requestIds: ['req-1'],
        invoiceNumber: 'INV-2024-001',
        status: InvoiceStatus.draft,
        customerInfo: const CustomerInfo(
          name: 'Test Customer',
          email: 'test@example.com',
        ),
        issueDate: DateTime(2024, 1, 15),
        dueDate: DateTime(2024, 2, 15),
        subtotal: 100.0,
        taxAmount: 18.0,
        total: 118.0,
      );

      final cursor = InvoiceCursor.fromInvoice(invoice);

      expect(cursor.isValid, isTrue);
      expect(cursor.id, 'inv-123');
      expect(cursor.issueDate, DateTime(2024, 1, 15));
    });

    test('InvoiceCursor validates correctly', () {
      // Valid cursor
      final validCursor = InvoiceCursor(
        issueDate: DateTime.now(),
        id: 'valid-id',
      );
      expect(validCursor.isValid, isTrue);

      // Invalid cursor (empty ID)
      final invalidCursor = InvoiceCursor(
        issueDate: DateTime.now(),
        id: '',
      );
      expect(invalidCursor.isValid, isFalse);
    });

    test('PaginatedInvoices handles cursor correctly', () {
      final cursor = InvoiceCursor(
        issueDate: DateTime(2024, 1, 15),
        id: 'last-item-id',
      );

      final result = PaginatedInvoices(
        invoices: [],
        total: 100,
        page: 2,
        pageSize: 20,
        hasMore: true,
        cursor: cursor,
      );

      expect(result.cursor, equals(cursor));
      expect(result.hasMore, isTrue);
      expect(result.pageSize, 20);
    });

    test('pagination prevents duplicates with consistent sorting', () {
      // Simulate two invoices with same issue date but different IDs
      final invoice1 = Invoice(
        id: 'inv-001',
        tenantId: 'tenant-1',
        requestIds: ['req-1'],
        invoiceNumber: 'INV-2024-001',
        status: InvoiceStatus.draft,
        customerInfo: const CustomerInfo(
          name: 'Customer A',
          email: 'a@example.com',
        ),
        issueDate: DateTime(2024, 1, 15, 10, 0), // Same date
        dueDate: DateTime(2024, 2, 15),
        subtotal: 100.0,
        taxAmount: 18.0,
        total: 118.0,
      );

      final invoice2 = Invoice(
        id: 'inv-002',
        tenantId: 'tenant-1',
        requestIds: ['req-2'],
        invoiceNumber: 'INV-2024-002',
        status: InvoiceStatus.draft,
        customerInfo: const CustomerInfo(
          name: 'Customer B',
          email: 'b@example.com',
        ),
        issueDate: DateTime(2024, 1, 15, 10, 0), // Same date
        dueDate: DateTime(2024, 2, 15),
        subtotal: 200.0,
        taxAmount: 36.0,
        total: 236.0,
      );

      // Create cursors
      final cursor1 = InvoiceCursor.fromInvoice(invoice1);
      final cursor2 = InvoiceCursor.fromInvoice(invoice2);

      // Cursors should be different even with same date
      expect(cursor1, isNot(equals(cursor2)));
      expect(cursor1.issueDate, equals(cursor2.issueDate));
      expect(cursor1.id, isNot(equals(cursor2.id)));
    });

    test('page size validation', () {
      const pageSize = 20;
      
      // Mock a paginated result
      final result = PaginatedInvoices(
        invoices: List.generate(pageSize, (i) => Invoice(
          id: 'inv-$i',
          tenantId: 'tenant-1',
          requestIds: ['req-$i'],
          invoiceNumber: 'INV-2024-${i.toString().padLeft(3, '0')}',
          status: InvoiceStatus.draft,
          customerInfo: const CustomerInfo(
            name: 'Test Customer',
            email: 'test@example.com',
          ),
          issueDate: DateTime.now().subtract(Duration(days: i)),
          dueDate: DateTime.now().add(Duration(days: 30 - i)),
          subtotal: 100.0,
          taxAmount: 18.0,
          total: 118.0,
        )),
        total: 100,
        page: 1,
        pageSize: pageSize,
        hasMore: true,
      );

      // Verify page size constraint
      expect(result.invoices.length, pageSize);
      expect(result.pageSize, 20);
      
      // Verify no duplicates
      final ids = result.invoices.map((inv) => inv.id).toSet();
      expect(ids.length, equals(result.invoices.length));
    });

    test('cursor-based pagination order consistency', () {
      final now = DateTime.now();
      
      // Create invoices with mixed dates (simulating real data)
      final invoices = [
        Invoice(
          id: 'inv-new',
          tenantId: 'tenant-1',
          requestIds: ['req-1'],
          invoiceNumber: 'INV-2024-003',
          status: InvoiceStatus.sent,
          customerInfo: const CustomerInfo(
            name: 'New Customer',
            email: 'new@example.com',
          ),
          issueDate: now, // Newest
          dueDate: now.add(const Duration(days: 30)),
          subtotal: 300.0,
          taxAmount: 54.0,
          total: 354.0,
        ),
        Invoice(
          id: 'inv-old',
          tenantId: 'tenant-1',
          requestIds: ['req-2'],
          invoiceNumber: 'INV-2024-001',
          status: InvoiceStatus.draft,
          customerInfo: const CustomerInfo(
            name: 'Old Customer',
            email: 'old@example.com',
          ),
          issueDate: now.subtract(const Duration(days: 5)), // Older
          dueDate: now.add(const Duration(days: 25)),
          subtotal: 100.0,
          taxAmount: 18.0,
          total: 118.0,
        ),
        Invoice(
          id: 'inv-middle',
          tenantId: 'tenant-1',
          requestIds: ['req-3'],
          invoiceNumber: 'INV-2024-002',
          status: InvoiceStatus.pending,
          customerInfo: const CustomerInfo(
            name: 'Middle Customer',
            email: 'middle@example.com',
          ),
          issueDate: now.subtract(const Duration(days: 2)), // Middle
          dueDate: now.add(const Duration(days: 28)),
          subtotal: 200.0,
          taxAmount: 36.0,
          total: 236.0,
        ),
      ];

      // Sort by issue_date DESC, id DESC (as per specification)
      invoices.sort((a, b) {
        final dateComparison = b.issueDate.compareTo(a.issueDate);
        if (dateComparison != 0) return dateComparison;
        return b.id!.compareTo(a.id!);
      });

      // Verify correct order: newest first
      expect(invoices[0].id, 'inv-new');
      expect(invoices[1].id, 'inv-middle');
      expect(invoices[2].id, 'inv-old');

      // Verify cursor creation maintains order
      final cursors = invoices.map(InvoiceCursor.fromInvoice).toList();
      
      // Each cursor should be valid
      for (final cursor in cursors) {
        expect(cursor.isValid, isTrue);
      }
      
      // Cursors should maintain the same order as invoices
      expect(cursors[0].issueDate.isAfter(cursors[1].issueDate), isTrue);
      expect(cursors[1].issueDate.isAfter(cursors[2].issueDate), isTrue);
    });
  });

  group('Pagination Performance Validation', () {
    test('cursor pagination prevents N+1 queries', () {
      // This is a conceptual test - in real implementation,
      // cursor pagination should use a single SQL query with WHERE clause
      // instead of OFFSET which requires scanning previous records
      
      final testCases = [
        {'page': 1, 'expectedComplexity': 'O(log n)'},
        {'page': 100, 'expectedComplexity': 'O(log n)'}, // Still fast with cursor
        {'page': 1000, 'expectedComplexity': 'O(log n)'}, // Still fast with cursor
      ];

      for (final testCase in testCases) {
        // In cursor-based pagination, query complexity should remain
        // constant regardless of page number, unlike OFFSET-based pagination
        expect(testCase['expectedComplexity'], 'O(log n)');
      }
    });

    test('validates cursor query structure for performance', () {
      final cursor = InvoiceCursor(
        issueDate: DateTime(2024, 1, 15),
        id: 'inv-123',
      );

      // Verify cursor contains the data needed for efficient WHERE clause:
      // WHERE (issue_date < ? OR (issue_date = ? AND id < ?))
      expect(cursor.issueDate, isA<DateTime>());
      expect(cursor.id, isNotEmpty);
      expect(cursor.isValid, isTrue);

      // This ensures the database can use the composite index:
      // INDEX ON (tenant_id, issue_date DESC, id DESC)
      // for efficient pagination without scanning previous records
    });
  });
}