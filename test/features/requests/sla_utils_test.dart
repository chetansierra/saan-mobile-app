import 'package:flutter_test/flutter_test.dart';

import '../../../lib/features/requests/domain/models/request.dart';

void main() {
  group('SLA Utils Tests', () {
    testWidgets('calculateSlaDue works correctly', (tester) async {
      final createdAt = DateTime(2025, 1, 26, 10, 0, 0);
      
      // Critical priority should get 6-hour SLA
      final criticalSla = SlaUtils.calculateSlaDue(RequestPriority.critical, createdAt);
      expect(criticalSla, DateTime(2025, 1, 26, 16, 0, 0));
      
      // Standard priority should get no SLA
      final standardSla = SlaUtils.calculateSlaDue(RequestPriority.standard, createdAt);
      expect(standardSla, null);
    });

    testWidgets('timeUntilSlaBreach calculates correctly', (tester) async {
      final futureDate = DateTime.now().add(const Duration(hours: 2, minutes: 30));
      final pastDate = DateTime.now().subtract(const Duration(hours: 1));
      
      final futureTime = SlaUtils.timeUntilSlaBreach(futureDate);
      final pastTime = SlaUtils.timeUntilSlaBreach(pastDate);
      
      expect(futureTime?.inHours, 2);
      expect(futureTime?.inMinutes, greaterThan(149)); // ~2.5 hours
      expect(pastTime, Duration.zero);
    });

    testWidgets('isOverdue works correctly', (tester) async {
      final futureDate = DateTime.now().add(const Duration(hours: 1));
      final pastDate = DateTime.now().subtract(const Duration(hours: 1));
      
      expect(SlaUtils.isOverdue(futureDate), false);
      expect(SlaUtils.isOverdue(pastDate), true);
      expect(SlaUtils.isOverdue(null), false);
    });

    testWidgets('getSlaStatus returns correct status', (tester) async {
      final now = DateTime.now();
      final longTime = now.add(const Duration(hours: 5));
      final shortTime = now.add(const Duration(hours: 1));
      final overdue = now.subtract(const Duration(minutes: 30));
      
      expect(SlaUtils.getSlaStatus(null), SlaStatus.none);
      expect(SlaUtils.getSlaStatus(longTime), SlaStatus.good);
      expect(SlaUtils.getSlaStatus(shortTime), SlaStatus.warning);
      expect(SlaUtils.getSlaStatus(overdue), SlaStatus.critical);
    });

    testWidgets('formatTimeRemaining formats correctly', (tester) async {
      expect(SlaUtils.formatTimeRemaining(null), 'Overdue');
      expect(SlaUtils.formatTimeRemaining(Duration.zero), 'Overdue');
      expect(SlaUtils.formatTimeRemaining(const Duration(minutes: 45)), '45m');
      expect(SlaUtils.formatTimeRemaining(const Duration(hours: 2, minutes: 30)), '2h 30m');
      expect(SlaUtils.formatTimeRemaining(const Duration(days: 1, hours: 3)), '1d 3h');
    });
  });

  group('Request Model Tests', () {
    testWidgets('ServiceRequest creates correctly from JSON', (tester) async {
      final json = {
        'id': 'req-123',
        'tenant_id': 'tenant-456',
        'facility_id': 'facility-789',
        'type': 'on_demand',
        'priority': 'critical',
        'description': 'HVAC system failure',
        'status': 'new',
        'created_at': '2025-01-26T10:00:00.000Z',
        'sla_due_at': '2025-01-26T16:00:00.000Z',
        'media_urls': ['url1', 'url2'],
      };

      final request = ServiceRequest.fromJson(json);

      expect(request.id, 'req-123');
      expect(request.tenantId, 'tenant-456');
      expect(request.facilityId, 'facility-789');
      expect(request.type, RequestType.onDemand);
      expect(request.priority, RequestPriority.critical);
      expect(request.description, 'HVAC system failure');
      expect(request.status, RequestStatus.newRequest);
      expect(request.mediaUrls, ['url1', 'url2']);
    });

    testWidgets('Request enums work correctly', (tester) async {
      // Test RequestStatus
      expect(RequestStatus.fromString('new'), RequestStatus.newRequest);
      expect(RequestStatus.newRequest.displayName, 'New');
      expect(RequestStatus.newRequest.isOpen, true);
      expect(RequestStatus.completed.isClosed, true);

      // Test RequestPriority
      expect(RequestPriority.fromString('critical'), RequestPriority.critical);
      expect(RequestPriority.critical.hasSla, true);
      expect(RequestPriority.standard.hasSla, false);
      expect(RequestPriority.critical.slaHours, 6);

      // Test RequestType
      expect(RequestType.fromString('on_demand'), RequestType.onDemand);
      expect(RequestType.onDemand.displayName, 'On-Demand');
    });

    testWidgets('RequestFilters work correctly', (tester) async {
      const emptyFilters = RequestFilters();
      expect(emptyFilters.hasActiveFilters, false);

      final filtersWithStatus = emptyFilters.copyWith(
        statuses: [RequestStatus.newRequest, RequestStatus.assigned],
      );
      expect(filtersWithStatus.hasActiveFilters, true);

      final filtersWithSearch = emptyFilters.copyWith(searchQuery: 'HVAC');
      expect(filtersWithSearch.hasActiveFilters, true);

      final clearedFilters = filtersWithSearch.clear();
      expect(clearedFilters.hasActiveFilters, false);
    });
  });
}