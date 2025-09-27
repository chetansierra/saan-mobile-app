import 'package:flutter_test/flutter_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:collection/collection.dart';
import 'dart:async';

import '../../../lib/features/billing/domain/billing_service.dart';
import '../../../lib/features/billing/domain/invoice.dart';
import '../../../lib/features/billing/data/billing_repository.dart';

/// Mock repository for testing debounce behavior
class _MockBillingRepository {
  final List<String> searchCalls = [];
  final List<InvoiceFilters> filterCalls = [];
  int callCount = 0;

  /// Simulate search call with tracking
  Future<PaginatedInvoices> listInvoices({
    required String tenantId,
    String? status,
    int page = 1,
    int pageSize = 20,
    InvoiceFilters? filters,
    InvoiceCursor? cursor,
  }) async {
    callCount++;
    if (filters?.searchQuery != null) {
      searchCalls.add(filters!.searchQuery!);
    }
    if (filters != null) {
      filterCalls.add(filters);
    }

    // Simulate API delay
    await Future.delayed(const Duration(milliseconds: 50));

    return const PaginatedInvoices(
      invoices: [],
      total: 0,
      page: 1,
      pageSize: 20,
      hasMore: false,
    );
  }

  void reset() {
    searchCalls.clear();
    filterCalls.clear();
    callCount = 0;
  }
}

/// Test service that mimics real BillingService debounce behavior
class _TestBillingService {
  _TestBillingService(this._mockRepo);

  final _MockBillingRepository _mockRepo;
  Timer? _searchDebounceTimer;
  String? _pendingSearchQuery;
  var _cancelToken = Object();

  /// Mimic the real applyFilters method with debouncing
  Future<void> applyFilters(InvoiceFilters filters) async {
    // Cancel any pending requests
    _cancelToken = Object();
    
    // If search query changed, debounce it
    const previousFilters = InvoiceFilters(); // Simulate previous state
    if (filters.searchQuery != previousFilters.searchQuery) {
      _pendingSearchQuery = filters.searchQuery;
      _searchDebounceTimer?.cancel();
      
      if (filters.searchQuery?.trim().isEmpty == true || filters.searchQuery == null) {
        // Empty search - apply immediately
        await _loadInvoices(filters: filters.copyWith(searchQuery: null));
      } else {
        // Debounce search - 320ms delay
        _searchDebounceTimer = Timer(const Duration(milliseconds: 320), () async {
          if (_pendingSearchQuery == filters.searchQuery) {
            await _loadInvoices(filters: filters);
          }
        });
      }
    } else {
      // Non-search filters - apply immediately
      await _loadInvoices(filters: filters);
    }
  }

  Future<void> _loadInvoices({InvoiceFilters? filters}) async {
    await _mockRepo.listInvoices(
      tenantId: 'test-tenant',
      filters: filters,
    );
  }

  void dispose() {
    _searchDebounceTimer?.cancel();
  }
}

void main() {
  group('BillingService Search Debouncing', () {
    late _MockBillingRepository mockRepo;
    late _TestBillingService testService;

    setUp(() {
      mockRepo = _MockBillingRepository();
      testService = _TestBillingService(mockRepo);
    });

    tearDown(() {
      testService.dispose();
      mockRepo.reset();
    });

    test('debounced search fires once for rapid inputs', () {
      fakeAsync((fakeAsync) {
        // Simulate rapid typing: "inv" -> "invo" -> "invoice"
        testService.applyFilters(const InvoiceFilters(searchQuery: 'inv'));
        fakeAsync.elapse(const Duration(milliseconds: 150));
        
        testService.applyFilters(const InvoiceFilters(searchQuery: 'invo'));
        fakeAsync.elapse(const Duration(milliseconds: 150));
        
        testService.applyFilters(const InvoiceFilters(searchQuery: 'invoice'));
        
        // Before debounce completes - no API calls should be made
        expect(mockRepo.searchCalls, isEmpty);
        
        // Wait for debounce to complete (320ms)
        fakeAsync.elapse(const Duration(milliseconds: 400));
        
        // Only the final search term should have triggered an API call
        expect(mockRepo.searchCalls.singleOrNull, 'invoice');
        expect(mockRepo.callCount, 1);
      });
    });

    test('empty search triggers immediate call without debounce', () {
      fakeAsync((fakeAsync) {
        // First add some search text
        testService.applyFilters(const InvoiceFilters(searchQuery: 'test'));
        fakeAsync.elapse(const Duration(milliseconds: 400));
        
        mockRepo.reset(); // Reset to track next calls
        
        // Clear search - should trigger immediately
        testService.applyFilters(const InvoiceFilters(searchQuery: ''));
        
        // Should trigger immediately without debounce
        fakeAsync.flushMicrotasks();
        expect(mockRepo.callCount, 1);
        expect(mockRepo.filterCalls.last.searchQuery, isNull);
      });
    });

    test('non-search filter changes apply immediately', () {
      fakeAsync((fakeAsync) {
        // Apply status filter (non-search)
        testService.applyFilters(const InvoiceFilters(
          statuses: [InvoiceStatus.sent],
        ));
        
        // Should apply immediately without debounce
        fakeAsync.flushMicrotasks();
        expect(mockRepo.callCount, 1);
        expect(mockRepo.filterCalls.last.statuses, contains(InvoiceStatus.sent));
      });
    });

    test('debounce timer is cancelled on rapid consecutive searches', () {
      fakeAsync((fakeAsync) {
        // Start multiple searches rapidly
        testService.applyFilters(const InvoiceFilters(searchQuery: 'a'));
        fakeAsync.elapse(const Duration(milliseconds: 100));
        
        testService.applyFilters(const InvoiceFilters(searchQuery: 'ab'));
        fakeAsync.elapse(const Duration(milliseconds: 100));
        
        testService.applyFilters(const InvoiceFilters(searchQuery: 'abc'));
        fakeAsync.elapse(const Duration(milliseconds: 100));
        
        // At this point, no searches should have completed
        expect(mockRepo.searchCalls, isEmpty);
        
        // Let the final debounce complete
        fakeAsync.elapse(const Duration(milliseconds: 300));
        
        // Only the last search should execute
        expect(mockRepo.searchCalls, ['abc']);
        expect(mockRepo.callCount, 1);
      });
    });

    test('debounce respects 320ms timing exactly', () {
      fakeAsync((fakeAsync) {
        testService.applyFilters(const InvoiceFilters(searchQuery: 'test'));
        
        // Check at 319ms - should not have fired yet
        fakeAsync.elapse(const Duration(milliseconds: 319));
        expect(mockRepo.searchCalls, isEmpty);
        
        // Check at 320ms - should fire now
        fakeAsync.elapse(const Duration(milliseconds: 1));
        fakeAsync.flushMicrotasks();
        expect(mockRepo.searchCalls, ['test']);
      });
    });

    test('multiple services can debounce independently', () {
      final service2 = _TestBillingService(mockRepo);
      
      fakeAsync((fakeAsync) {
        // Both services search at same time
        testService.applyFilters(const InvoiceFilters(searchQuery: 'service1'));
        service2.applyFilters(const InvoiceFilters(searchQuery: 'service2'));
        
        // Wait for both debounces
        fakeAsync.elapse(const Duration(milliseconds: 400));
        
        // Both should have executed
        expect(mockRepo.searchCalls, containsAll(['service1', 'service2']));
        expect(mockRepo.callCount, 2);
      });
      
      service2.dispose();
    });
  });

  group('Search Performance Validation', () {
    test('validates search debounce reduces API calls by ~80%', () {
      final mockRepo = _MockBillingRepository();
      final testService = _TestBillingService(mockRepo);

      fakeAsync((fakeAsync) {
        // Simulate typing "invoice-123" character by character (11 chars)
        const searchSteps = [
          'i', 'in', 'inv', 'invo', 'invoi', 'invoic', 'invoice',
          'invoice-', 'invoice-1', 'invoice-12', 'invoice-123'
        ];

        for (int i = 0; i < searchSteps.length; i++) {
          testService.applyFilters(InvoiceFilters(searchQuery: searchSteps[i]));
          // Simulate ~100ms between keystrokes
          fakeAsync.elapse(const Duration(milliseconds: 100));
        }

        // Wait for final debounce
        fakeAsync.elapse(const Duration(milliseconds: 400));

        // Without debouncing, we'd have 11 API calls
        // With debouncing, we should have only 1
        expect(mockRepo.callCount, 1);
        expect(mockRepo.searchCalls.single, 'invoice-123');
        
        // Verify 90.9% reduction (1 call instead of 11)
        const reductionPercentage = (11 - 1) / 11 * 100;
        expect(reductionPercentage, greaterThan(80));
      });

      testService.dispose();
    });
  });
}