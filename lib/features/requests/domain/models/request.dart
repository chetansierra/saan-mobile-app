import 'package:equatable/equatable.dart';

/// Service request model matching the database schema
class ServiceRequest extends Equatable {
  const ServiceRequest({
    this.id,
    required this.tenantId,
    required this.facilityId,
    required this.type,
    required this.priority,
    required this.description,
    this.mediaUrls = const [],
    this.preferredWindow,
    this.status = RequestStatus.newRequest,
    this.assignedEngineerName,
    this.eta,
    this.slaDueAt,
    this.createdAt,
    this.facilityName,
  });

  /// Request ID (null for new requests)
  final String? id;

  /// Tenant ID for multi-tenant isolation
  final String tenantId;

  /// Facility ID where service is needed
  final String facilityId;

  /// Request type (on_demand or contract)
  final RequestType type;

  /// Request priority (critical or standard)
  final RequestPriority priority;

  /// Service description
  final String description;

  /// List of media file URLs
  final List<String> mediaUrls;

  /// Preferred time window (optional)
  final TimeWindow? preferredWindow;

  /// Current status
  final RequestStatus status;

  /// Assigned engineer name (optional)
  final String? assignedEngineerName;

  /// Estimated arrival time (optional)
  final DateTime? eta;

  /// SLA due date/time (auto-calculated for critical requests)
  final DateTime? slaDueAt;

  /// Request creation timestamp
  final DateTime? createdAt;

  /// Facility name (for display purposes - joined from facilities table)
  final String? facilityName;

  /// Create ServiceRequest from JSON (Supabase response)
  factory ServiceRequest.fromJson(Map<String, dynamic> json) {
    return ServiceRequest(
      id: json['id'] as String?,
      tenantId: json['tenant_id'] as String,
      facilityId: json['facility_id'] as String,
      type: RequestType.fromString(json['type'] as String),
      priority: RequestPriority.fromString(json['priority'] as String),
      description: json['description'] as String,
      mediaUrls: (json['media_urls'] as List? ?? [])
          .map((url) => url.toString())
          .toList(),
      preferredWindow: json['preferred_window'] != null
          ? TimeWindow.fromString(json['preferred_window'] as String)
          : null,
      status: RequestStatus.fromString(json['status'] as String),
      assignedEngineerName: json['assigned_engineer_name'] as String?,
      eta: json['eta'] != null ? DateTime.parse(json['eta'] as String) : null,
      slaDueAt: json['sla_due_at'] != null
          ? DateTime.parse(json['sla_due_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      facilityName: json['facility_name'] as String?, // From JOIN query
    );
  }

  /// Convert ServiceRequest to JSON (for Supabase operations)
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'tenant_id': tenantId,
      'facility_id': facilityId,
      'type': type.value,
      'priority': priority.value,
      'description': description,
      'media_urls': mediaUrls,
      'preferred_window': preferredWindow?.toPostgresRange(),
      'status': status.value,
      'assigned_engineer_name': assignedEngineerName,
      'eta': eta?.toIso8601String(),
      'sla_due_at': slaDueAt?.toIso8601String(),
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  ServiceRequest copyWith({
    String? id,
    String? tenantId,
    String? facilityId,
    RequestType? type,
    RequestPriority? priority,
    String? description,
    List<String>? mediaUrls,
    TimeWindow? preferredWindow,
    RequestStatus? status,
    String? assignedEngineerName,
    DateTime? eta,
    DateTime? slaDueAt,
    DateTime? createdAt,
    String? facilityName,
  }) {
    return ServiceRequest(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      facilityId: facilityId ?? this.facilityId,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      description: description ?? this.description,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      preferredWindow: preferredWindow ?? this.preferredWindow,
      status: status ?? this.status,
      assignedEngineerName: assignedEngineerName ?? this.assignedEngineerName,
      eta: eta ?? this.eta,
      slaDueAt: slaDueAt ?? this.slaDueAt,
      createdAt: createdAt ?? this.createdAt,
      facilityName: facilityName ?? this.facilityName,
    );
  }

  @override
  List<Object?> get props => [
        id,
        tenantId,
        facilityId,
        type,
        priority,
        description,
        mediaUrls,
        preferredWindow,
        status,
        assignedEngineerName,
        eta,
        slaDueAt,
        createdAt,
        facilityName,
      ];
}

/// Request type enumeration
enum RequestType {
  onDemand('on_demand'),
  contract('contract');

  const RequestType(this.value);

  final String value;

  static RequestType fromString(String value) {
    switch (value) {
      case 'on_demand':
        return RequestType.onDemand;
      case 'contract':
        return RequestType.contract;
      default:
        throw ArgumentError('Invalid request type: $value');
    }
  }

  String get displayName {
    switch (this) {
      case RequestType.onDemand:
        return 'On-Demand';
      case RequestType.contract:
        return 'Contract';
    }
  }
}

/// Request priority enumeration
enum RequestPriority {
  critical('critical'),
  standard('standard');

  const RequestPriority(this.value);

  final String value;

  static RequestPriority fromString(String value) {
    switch (value) {
      case 'critical':
        return RequestPriority.critical;
      case 'standard':
        return RequestPriority.standard;
      default:
        throw ArgumentError('Invalid request priority: $value');
    }
  }

  String get displayName {
    switch (this) {
      case RequestPriority.critical:
        return 'Critical';
      case RequestPriority.standard:
        return 'Standard';
    }
  }

  /// Whether this priority has SLA requirements
  bool get hasSla => this == RequestPriority.critical;

  /// SLA duration in hours (6 hours for critical)
  int get slaHours => hasSla ? 6 : 0;
}

/// Request status enumeration (matches database enum)
enum RequestStatus {
  newRequest('new'),
  triaged('triaged'),
  assigned('assigned'),
  enRoute('en_route'),
  onSite('on_site'),
  completed('completed'),
  verified('verified');

  const RequestStatus(this.value);

  final String value;

  static RequestStatus fromString(String value) {
    switch (value) {
      case 'new':
        return RequestStatus.newRequest;
      case 'triaged':
        return RequestStatus.triaged;
      case 'assigned':
        return RequestStatus.assigned;
      case 'en_route':
        return RequestStatus.enRoute;
      case 'on_site':
        return RequestStatus.onSite;
      case 'completed':
        return RequestStatus.completed;
      case 'verified':
        return RequestStatus.verified;
      default:
        throw ArgumentError('Invalid request status: $value');
    }
  }

  String get displayName {
    switch (this) {
      case RequestStatus.newRequest:
        return 'New';
      case RequestStatus.triaged:
        return 'Triaged';
      case RequestStatus.assigned:
        return 'Assigned';
      case RequestStatus.enRoute:
        return 'En Route';
      case RequestStatus.onSite:
        return 'On Site';
      case RequestStatus.completed:
        return 'Completed';
      case RequestStatus.verified:
        return 'Verified';
    }
  }

  /// Whether this status indicates the request is active/open
  bool get isOpen {
    return ![RequestStatus.completed, RequestStatus.verified].contains(this);
  }

  /// Whether this status indicates the request is closed
  bool get isClosed => !isOpen;

  /// Status color for UI display
  String get colorHex {
    switch (this) {
      case RequestStatus.newRequest:
        return '#2196F3'; // Blue
      case RequestStatus.triaged:
        return '#FF9800'; // Orange
      case RequestStatus.assigned:
        return '#9C27B0'; // Purple
      case RequestStatus.enRoute:
        return '#FF5722'; // Deep Orange
      case RequestStatus.onSite:
        return '#607D8B'; // Blue Grey
      case RequestStatus.completed:
        return '#4CAF50'; // Green
      case RequestStatus.verified:
        return '#388E3C'; // Dark Green
    }
  }
}

/// Time window for preferred service time
class TimeWindow extends Equatable {
  const TimeWindow({
    required this.startTime,
    required this.endTime,
  });

  final DateTime startTime;
  final DateTime endTime;

  /// Create from PostgreSQL tstzrange format
  factory TimeWindow.fromString(String rangeString) {
    // Parse PostgreSQL range format: ["2025-01-26 09:00:00+00","2025-01-26 12:00:00+00")
    final cleanRange = rangeString.replaceAll('[', '').replaceAll(')', '').replaceAll('"', '');
    final parts = cleanRange.split(',');
    
    if (parts.length != 2) {
      throw ArgumentError('Invalid time window format: $rangeString');
    }

    return TimeWindow(
      startTime: DateTime.parse(parts[0].trim()),
      endTime: DateTime.parse(parts[1].trim()),
    );
  }

  /// Convert to PostgreSQL tstzrange format
  String toPostgresRange() {
    return '["${startTime.toIso8601String()}","${endTime.toIso8601String()}")';
  }

  /// Duration of the time window
  Duration get duration => endTime.difference(startTime);

  /// Whether the time window is valid (end after start)
  bool get isValid => endTime.isAfter(startTime);

  @override
  List<Object?> get props => [startTime, endTime];
}

/// SLA utilities for request management
class SlaUtils {
  SlaUtils._();

  /// Calculate SLA due date for a request
  static DateTime? calculateSlaDue(RequestPriority priority, DateTime createdAt) {
    if (!priority.hasSla) return null;
    
    return createdAt.add(Duration(hours: priority.slaHours));
  }

  /// Calculate time remaining until SLA breach
  static Duration? timeUntilSlaBreach(DateTime? slaDueAt) {
    if (slaDueAt == null) return null;
    
    final now = DateTime.now();
    if (slaDueAt.isBefore(now)) return Duration.zero;
    
    return slaDueAt.difference(now);
  }

  /// Check if request is overdue (SLA breached)
  static bool isOverdue(DateTime? slaDueAt) {
    if (slaDueAt == null) return false;
    return DateTime.now().isAfter(slaDueAt);
  }

  /// Check if request is due today
  static bool isDueToday(DateTime? slaDueAt) {
    if (slaDueAt == null) return false;
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    
    return slaDueAt.isAfter(today) && slaDueAt.isBefore(tomorrow);
  }

  /// Get SLA status color (green/amber/red)
  static SlaStatus getSlaStatus(DateTime? slaDueAt) {
    if (slaDueAt == null) return SlaStatus.none;
    
    final timeLeft = timeUntilSlaBreach(slaDueAt);
    if (timeLeft == null || timeLeft <= Duration.zero) {
      return SlaStatus.critical; // Overdue - Red
    }
    
    if (timeLeft.inHours <= 2) {
      return SlaStatus.warning; // Less than 2 hours - Amber
    }
    
    return SlaStatus.good; // More than 2 hours - Green
  }

  /// Format time remaining for display
  static String formatTimeRemaining(Duration? timeLeft) {
    if (timeLeft == null || timeLeft <= Duration.zero) {
      return 'Overdue';
    }
    
    if (timeLeft.inDays > 0) {
      return '${timeLeft.inDays}d ${timeLeft.inHours % 24}h';
    }
    
    if (timeLeft.inHours > 0) {
      return '${timeLeft.inHours}h ${timeLeft.inMinutes % 60}m';
    }
    
    return '${timeLeft.inMinutes}m';
  }
}

/// SLA status for color coding
enum SlaStatus {
  none, // No SLA
  good, // Green - plenty of time
  warning, // Amber - approaching deadline
  critical; // Red - overdue

  String get colorHex {
    switch (this) {
      case SlaStatus.none:
        return '#9E9E9E'; // Grey
      case SlaStatus.good:
        return '#4CAF50'; // Green
      case SlaStatus.warning:
        return '#FF9800'; // Amber
      case SlaStatus.critical:
        return '#F44336'; // Red
    }
  }
}

/// Request filters model
class RequestFilters extends Equatable {
  const RequestFilters({
    this.statuses = const [],
    this.facilities = const [],
    this.priorities = const [],
    this.searchQuery,
  });

  final List<RequestStatus> statuses;
  final List<String> facilities; // Facility IDs
  final List<RequestPriority> priorities;
  final String? searchQuery;

  /// Whether any filters are active
  bool get hasActiveFilters {
    return statuses.isNotEmpty ||
           facilities.isNotEmpty ||
           priorities.isNotEmpty ||
           (searchQuery != null && searchQuery!.trim().isNotEmpty);
  }

  /// Clear all filters
  RequestFilters clear() {
    return const RequestFilters();
  }

  /// Create copy with updated filters
  RequestFilters copyWith({
    List<RequestStatus>? statuses,
    List<String>? facilities,
    List<RequestPriority>? priorities,
    String? searchQuery,
  }) {
    return RequestFilters(
      statuses: statuses ?? this.statuses,
      facilities: facilities ?? this.facilities,
      priorities: priorities ?? this.priorities,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  @override
  List<Object?> get props => [statuses, facilities, priorities, searchQuery];
}

/// Paginated request list response
class PaginatedRequests extends Equatable {
  const PaginatedRequests({
    required this.requests,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.hasMore,
  });

  final List<ServiceRequest> requests;
  final int total;
  final int page;
  final int pageSize;
  final bool hasMore;

  @override
  List<Object?> get props => [requests, total, page, pageSize, hasMore];
}