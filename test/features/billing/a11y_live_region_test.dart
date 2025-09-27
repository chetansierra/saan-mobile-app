import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  group('Accessibility Live Region Tests', () {
    testWidgets('loading more announces to screen readers', (tester) async {
      final testService = _TestPaginationService();
      
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            _testServiceProvider.overrideWith((ref) => testService),
          ],
          child: const MaterialApp(
            home: _TestPaginationWidget(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the live region for pagination status
      final liveRegion = find.byType(Semantics).where((widget) {
        final semantics = widget.evaluate().first.widget as Semantics;
        return semantics.properties.liveRegion == true;
      });

      expect(liveRegion, findsWidgets, 
          reason: 'Should have live regions for screen reader announcements');

      // Trigger loading more
      testService.setLoadingMore(true);
      await tester.pump();

      // Find loading announcement
      final loadingAnnouncement = find.byWidgetPredicate((widget) {
        if (widget is Semantics) {
          return widget.properties.label?.contains('Loading more') == true &&
                 widget.properties.liveRegion == true;
        }
        return false;
      });

      expect(loadingAnnouncement, findsOneWidget,
          reason: 'Loading more should be announced via live region');
    });

    testWidgets('no more results announces completion', (tester) async {
      final testService = _TestPaginationService()
        ..setNoMoreResults();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            _testServiceProvider.overrideWith((ref) => testService),
          ],
          child: const MaterialApp(
            home: _TestPaginationWidget(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find "no more results" announcement
      final noMoreAnnouncement = find.byWidgetPredicate((widget) {
        if (widget is Semantics) {
          return widget.properties.label?.contains('No more') == true &&
                 widget.properties.liveRegion == true;
        }
        return false;
      });

      expect(noMoreAnnouncement, findsOneWidget,
          reason: 'No more results should be announced via live region');
    });

    testWidgets('error state announces to screen readers', (tester) async {
      final testService = _TestPaginationService()
        ..setError('Failed to load more invoices');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            _testServiceProvider.overrideWith((ref) => testService),
          ],
          child: const MaterialApp(
            home: _TestPaginationWidget(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find error announcement
      final errorAnnouncement = find.byWidgetPredicate((widget) {
        if (widget is Semantics) {
          return widget.properties.label?.contains('Failed to load') == true &&
                 widget.properties.liveRegion == true;
        }
        return false;
      });

      expect(errorAnnouncement, findsOneWidget,
          reason: 'Error should be announced via live region');
    });

    testWidgets('search results count announces changes', (tester) async {
      final testService = _TestPaginationService()
        ..setSearchResults(5);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            _testServiceProvider.overrideWith((ref) => testService),
          ],
          child: const MaterialApp(
            home: _TestPaginationWidget(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find search results announcement
      final searchAnnouncement = find.byWidgetPredicate((widget) {
        if (widget is Semantics) {
          return widget.properties.label?.contains('5 results found') == true &&
                 widget.properties.liveRegion == true;
        }
        return false;
      });

      expect(searchAnnouncement, findsOneWidget,
          reason: 'Search results count should be announced');

      // Update search results
      testService.setSearchResults(12);
      await tester.pump();

      // Find updated announcement
      final updatedAnnouncement = find.byWidgetPredicate((widget) {
        if (widget is Semantics) {
          return widget.properties.label?.contains('12 results found') == true &&
                 widget.properties.liveRegion == true;
        }
        return false;
      });

      expect(updatedAnnouncement, findsOneWidget,
          reason: 'Updated search results should be announced');
    });

    testWidgets('pagination status updates are polite announcements', (tester) async {
      final testService = _TestPaginationService()
        ..setPageInfo(2, 5, 50);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            _testServiceProvider.overrideWith((ref) => testService),
          ],
          child: const MaterialApp(
            home: _TestPaginationWidget(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find pagination status with polite announcements
      final pageStatus = find.byWidgetPredicate((widget) {
        if (widget is Semantics) {
          final props = widget.properties;
          return props.label?.contains('Page 2 of 5') == true &&
                 props.liveRegion == true &&
                 props.liveRegionPolite == true; // Should be polite, not assertive
        }
        return false;
      });

      expect(pageStatus, findsOneWidget,
          reason: 'Page status should use polite live region announcements');
    });

    testWidgets('loading states use assertive announcements for critical updates', (tester) async {
      final testService = _TestPaginationService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            _testServiceProvider.overrideWith((ref) => testService),
          ],
          child: const MaterialApp(
            home: _TestPaginationWidget(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Trigger error state (critical)
      testService.setError('Network connection lost');
      await tester.pump();

      // Find assertive error announcement
      final errorAnnouncement = find.byWidgetPredicate((widget) {
        if (widget is Semantics) {
          final props = widget.properties;
          return props.label?.contains('Network connection lost') == true &&
                 props.liveRegion == true &&
                 props.liveRegionPolite == false; // Should be assertive for errors
        }
        return false;
      });

      expect(errorAnnouncement, findsOneWidget,
          reason: 'Critical errors should use assertive live region announcements');
    });

    testWidgets('live regions have proper semantic markup', (tester) async {
      final testService = _TestPaginationService()
        ..setLoadingMore(true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            _testServiceProvider.overrideWith((ref) => testService),
          ],
          child: const MaterialApp(
            home: _TestPaginationWidget(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify live region semantics are properly configured
      final liveRegions = tester.widgetList<Semantics>(
        find.byWidgetPredicate((widget) {
          return widget is Semantics && widget.properties.liveRegion == true;
        }),
      );

      expect(liveRegions.length, greaterThan(0),
          reason: 'Should have live regions configured');

      for (final semantics in liveRegions) {
        final props = semantics.properties;
        
        // Live regions should have labels
        expect(props.label, isNotNull,
            reason: 'Live regions should have descriptive labels');
        
        // Should not be focusable (screen readers handle live regions automatically)
        expect(props.focusable, isFalse,
            reason: 'Live regions should not be focusable');
        
        // Should be enabled but not interactive
        expect(props.enabled, isTrue,
            reason: 'Live regions should be enabled for screen readers');
      }
    });

    testWidgets('multiple live regions do not conflict', (tester) async {
      final testService = _TestPaginationService()
        ..setLoadingMore(true)
        ..setSearchResults(8)
        ..setPageInfo(1, 3, 25);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            _testServiceProvider.overrideWith((ref) => testService),
          ],
          child: const MaterialApp(
            home: _TestPaginationWidget(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should have multiple live regions without conflicts
      final liveRegions = tester.widgetList<Semantics>(
        find.byWidgetPredicate((widget) {
          return widget is Semantics && widget.properties.liveRegion == true;
        }),
      );

      expect(liveRegions.length, greaterThanOrEqualTo(2),
          reason: 'Should support multiple simultaneous live regions');

      // Each should have unique content
      final labels = liveRegions.map((s) => s.properties.label).toSet();
      expect(labels.length, equals(liveRegions.length),
          reason: 'Each live region should have unique content');
    });

    testWidgets('live region content updates immediately', (tester) async {
      final testService = _TestPaginationService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            _testServiceProvider.overrideWith((ref) => testService),
          ],
          child: const MaterialApp(
            home: _TestPaginationWidget(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initial state
      testService.setSearchResults(3);
      await tester.pump();

      final initialAnnouncement = find.byWidgetPredicate((widget) {
        if (widget is Semantics) {
          return widget.properties.label?.contains('3 results') == true;
        }
        return false;
      });

      expect(initialAnnouncement, findsOneWidget);

      // Update immediately
      testService.setSearchResults(7);
      await tester.pump(); // Single pump - should update immediately

      final updatedAnnouncement = find.byWidgetPredicate((widget) {
        if (widget is Semantics) {
          return widget.properties.label?.contains('7 results') == true;
        }
        return false;
      });

      expect(updatedAnnouncement, findsOneWidget,
          reason: 'Live region should update immediately');
      expect(initialAnnouncement, findsNothing,
          reason: 'Old announcement should be replaced');
    });
  });
}

/// Test service for pagination states
class _TestPaginationService extends StateNotifier<_PaginationState> {
  _TestPaginationService() : super(const _PaginationState());

  void setLoadingMore(bool isLoading) {
    state = state.copyWith(isLoadingMore: isLoading);
  }

  void setNoMoreResults() {
    state = state.copyWith(hasMore: false, isLoadingMore: false);
  }

  void setError(String error) {
    state = state.copyWith(error: error, isLoadingMore: false);
  }

  void setSearchResults(int count) {
    state = state.copyWith(searchResultCount: count);
  }

  void setPageInfo(int currentPage, int totalPages, int totalItems) {
    state = state.copyWith(
      currentPage: currentPage,
      totalPages: totalPages,
      totalItems: totalItems,
    );
  }
}

final _testServiceProvider = StateNotifierProvider<_TestPaginationService, _PaginationState>((ref) {
  return _TestPaginationService();
});

/// Test state class
class _PaginationState {
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;
  final int? searchResultCount;
  final int currentPage;
  final int totalPages;
  final int totalItems;

  const _PaginationState({
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
    this.searchResultCount,
    this.currentPage = 1,
    this.totalPages = 1,
    this.totalItems = 0,
  });

  _PaginationState copyWith({
    bool? isLoadingMore,
    bool? hasMore,
    String? error,
    int? searchResultCount,
    int? currentPage,
    int? totalPages,
    int? totalItems,
  }) {
    return _PaginationState(
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: error ?? this.error,
      searchResultCount: searchResultCount ?? this.searchResultCount,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      totalItems: totalItems ?? this.totalItems,
    );
  }
}

/// Test widget with live region announcements
class _TestPaginationWidget extends ConsumerWidget {
  const _TestPaginationWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_testServiceProvider);

    return Scaffold(
      body: Column(
        children: [
          // Loading more live region
          if (state.isLoadingMore)
            Semantics(
              liveRegion: true,
              label: 'Loading more invoices...',
              child: const SizedBox.shrink(),
            ),

          // No more results live region
          if (!state.hasMore && !state.isLoadingMore)
            Semantics(
              liveRegion: true,
              label: 'No more invoices to load',
              child: const SizedBox.shrink(),
            ),

          // Error live region (assertive)
          if (state.error != null)
            Semantics(
              liveRegion: true,
              liveRegionPolite: false, // Assertive for errors
              label: state.error!,
              child: const SizedBox.shrink(),
            ),

          // Search results live region (polite)
          if (state.searchResultCount != null)
            Semantics(
              liveRegion: true,
              liveRegionPolite: true,
              label: '${state.searchResultCount} results found',
              child: const SizedBox.shrink(),
            ),

          // Page status live region (polite)
          if (state.totalPages > 1)
            Semantics(
              liveRegion: true,
              liveRegionPolite: true,
              label: 'Page ${state.currentPage} of ${state.totalPages}, ${state.totalItems} total items',
              child: const SizedBox.shrink(),
            ),

          // Main content
          const Expanded(
            child: Center(
              child: Text('Invoice List Content'),
            ),
          ),
        ],
      ),
    );
  }
}