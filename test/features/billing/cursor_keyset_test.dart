import 'package:flutter_test/flutter_test.dart';

// Minimal cursor struct mirroring app logic.
class InvoiceCursor {
  final DateTime issueDate; 
  final String id;
  const InvoiceCursor(this.issueDate, this.id);
  
  bool isAfter(InvoiceCursor other) =>
    issueDate.isBefore(other.issueDate) ||
    (issueDate.isAtSameMomentAs(other.issueDate) && id.compareTo(other.id) < 0);
}

void main() {
  group('Cursor-based Pagination Keyset Logic', () {
    test('next page uses keyset rule (issue_date desc, id desc)', () {
      final c1 = InvoiceCursor(DateTime(2025, 9, 27, 12, 00), 'B');
      final c2 = InvoiceCursor(DateTime(2025, 9, 27, 12, 00), 'A');
      final c3 = InvoiceCursor(DateTime(2025, 9, 27, 11, 59), 'Z');

      // Next page items must be "older" than cursor.
      expect(c2.isAfter(c1), true, reason: 'same ts, lower id');
      expect(c3.isAfter(c1), true, reason: 'older timestamp');
    });

    test('cursor ordering handles edge cases correctly', () {
      // Test same timestamp, different IDs
      final cursorSameTime1 = InvoiceCursor(DateTime(2025, 1, 1, 10, 0), 'inv-003');
      final cursorSameTime2 = InvoiceCursor(DateTime(2025, 1, 1, 10, 0), 'inv-001');
      final cursorSameTime3 = InvoiceCursor(DateTime(2025, 1, 1, 10, 0), 'inv-002');

      // With same timestamp, ID ordering should determine sequence
      expect(cursorSameTime2.isAfter(cursorSameTime1), true, 
          reason: 'inv-001 comes after inv-003 in DESC order');
      expect(cursorSameTime3.isAfter(cursorSameTime1), true,
          reason: 'inv-002 comes after inv-003 in DESC order');
      expect(cursorSameTime2.isAfter(cursorSameTime3), true,
          reason: 'inv-001 comes after inv-002 in DESC order');
    });

    test('different timestamps ignore ID comparison', () {
      final newerCursor = InvoiceCursor(DateTime(2025, 1, 2), 'inv-999');
      final olderCursor = InvoiceCursor(DateTime(2025, 1, 1), 'inv-001');

      // Older timestamp should always come after newer timestamp, regardless of ID
      expect(olderCursor.isAfter(newerCursor), true,
          reason: 'older timestamp should come after newer timestamp in DESC order');
      expect(newerCursor.isAfter(olderCursor), false,
          reason: 'newer timestamp should not come after older timestamp');
    });

    test('validates SQL WHERE clause logic for cursor pagination', () {
      // This test validates the SQL logic: 
      // WHERE (issue_date < cursor.issueDate OR (issue_date = cursor.issueDate AND id < cursor.id))
      
      final cursor = InvoiceCursor(DateTime(2025, 6, 15, 14, 30), 'inv-100');
      
      // Test cases that should be included in next page
      final olderDate = InvoiceCursor(DateTime(2025, 6, 14), 'inv-999'); // Older date
      final sameDateLowerId = InvoiceCursor(DateTime(2025, 6, 15, 14, 30), 'inv-050'); // Same date, lower ID
      
      // Test cases that should NOT be included in next page  
      final newerDate = InvoiceCursor(DateTime(2025, 6, 16), 'inv-001'); // Newer date
      final sameDateHigherId = InvoiceCursor(DateTime(2025, 6, 15, 14, 30), 'inv-200'); // Same date, higher ID
      final sameDateSameId = InvoiceCursor(DateTime(2025, 6, 15, 14, 30), 'inv-100'); // Exact match

      // Should be included (isAfter returns true)
      expect(olderDate.isAfter(cursor), true, reason: 'older date should be in next page');
      expect(sameDateLowerId.isAfter(cursor), true, reason: 'same date, lower ID should be in next page');
      
      // Should NOT be included (isAfter returns false)
      expect(newerDate.isAfter(cursor), false, reason: 'newer date should not be in next page');
      expect(sameDateHigherId.isAfter(cursor), false, reason: 'same date, higher ID should not be in next page');
      expect(sameDateSameId.isAfter(cursor), false, reason: 'exact match should not be in next page');
    });

    test('millisecond precision in timestamps works correctly', () {
      // Test with very close timestamps to ensure millisecond precision
      final cursor1 = InvoiceCursor(DateTime(2025, 1, 1, 12, 0, 0, 500), 'inv-A');
      final cursor2 = InvoiceCursor(DateTime(2025, 1, 1, 12, 0, 0, 499), 'inv-B');
      final cursor3 = InvoiceCursor(DateTime(2025, 1, 1, 12, 0, 0, 501), 'inv-C');

      expect(cursor2.isAfter(cursor1), true, 
          reason: 'earlier millisecond should come after in DESC order');
      expect(cursor3.isAfter(cursor1), false,
          reason: 'later millisecond should not come after in DESC order');
    });

    test('composite cursor ensures no pagination gaps or duplicates', () {
      // Create a series of cursors that represent a typical result set
      final cursors = [
        InvoiceCursor(DateTime(2025, 1, 3), 'inv-100'), // Page 1 last item
        InvoiceCursor(DateTime(2025, 1, 2), 'inv-095'), // Page 2 first item  
        InvoiceCursor(DateTime(2025, 1, 2), 'inv-090'), // Page 2 items
        InvoiceCursor(DateTime(2025, 1, 1), 'inv-085'), // Page 2 last item
        InvoiceCursor(DateTime(2025, 1, 1), 'inv-080'), // Page 3 first item
      ];

      // Verify ordering is strictly decreasing (no duplicates)
      for (int i = 0; i < cursors.length - 1; i++) {
        expect(cursors[i + 1].isAfter(cursors[i]), true,
            reason: 'cursor at index ${i + 1} should come after cursor at index $i');
      }

      // Verify no cursor equals another (no duplicates)
      for (int i = 0; i < cursors.length; i++) {
        for (int j = i + 1; j < cursors.length; j++) {
          final sameTimestamp = cursors[i].issueDate.isAtSameMomentAs(cursors[j].issueDate);
          final sameId = cursors[i].id == cursors[j].id;
          expect(sameTimestamp && sameId, false,
              reason: 'no two cursors should be identical');
        }
      }
    });

    test('boundary conditions are handled correctly', () {
      // Test edge cases
      final veryOldDate = InvoiceCursor(DateTime(1970, 1, 1), 'inv-000');
      final veryNewDate = InvoiceCursor(DateTime(2099, 12, 31), 'inv-999');
      final emptyId = InvoiceCursor(DateTime(2025, 1, 1), '');
      final longId = InvoiceCursor(DateTime(2025, 1, 1), 'very-long-invoice-id-that-might-cause-issues');

      // Very old date should always come after any newer date
      expect(veryOldDate.isAfter(veryNewDate), true);
      
      // Empty ID should work (comes first in string comparison)
      expect(emptyId.isAfter(InvoiceCursor(DateTime(2025, 1, 1), 'a')), true);
      
      // Long IDs should work fine
      expect(longId.isAfter(InvoiceCursor(DateTime(2025, 1, 1), 'short')), false);
    });
  });
}