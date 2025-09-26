import 'package:equatable/equatable.dart';

/// PM Visit model for scheduled preventive maintenance visits
class PMVisit extends Equatable {
  const PMVisit({
    this.id,
    required this.tenantId,
    required this.contractId,
    required this.facilityId,
    required this.scheduledDate,
    this.completedDate,
    this.status = PMVisitStatus.scheduled,
    this.engineerName,
    this.notes,
    this.checklistId,
    this.attachmentPaths = const [],
    this.createdAt,
    this.updatedAt,
  });

  /// PM Visit ID (auto-generated UUID)
  final String? id;

  /// Tenant ID for multi-tenant isolation
  final String tenantId;

  /// Contract ID this visit belongs to
  final String contractId;

  /// Facility ID where visit is scheduled
  final String facilityId;

  /// Scheduled date for the PM visit
  final DateTime scheduledDate;

  /// Date when visit was completed (null if not completed)
  final DateTime? completedDate;

  /// Current status of the PM visit
  final PMVisitStatus status;

  /// Name of engineer assigned to/who completed the visit
  final String? engineerName;

  /// Optional notes from the engineer
  final String? notes;

  /// ID of associated checklist (if completed)
  final String? checklistId;

  /// Paths to attachments/photos from the visit
  final List<String> attachmentPaths;

  /// Visit creation timestamp
  final DateTime? createdAt;

  /// Visit last updated timestamp
  final DateTime? updatedAt;

  /// Check if visit is overdue
  bool get isOverdue {
    if (status == PMVisitStatus.completed) return false;
    return DateTime.now().isAfter(scheduledDate.add(const Duration(days: 1)));
  }

  /// Check if visit is due today
  bool get isDueToday {
    if (status == PMVisitStatus.completed) return false;
    final today = DateTime.now();
    final scheduled = scheduledDate;
    return today.year == scheduled.year && 
           today.month == scheduled.month && 
           today.day == scheduled.day;
  }

  /// Check if visit is due within next 7 days
  bool get isDueSoon {
    if (status == PMVisitStatus.completed) return false;
    final now = DateTime.now();
    final weekFromNow = now.add(const Duration(days: 7));
    return scheduledDate.isBefore(weekFromNow);
  }

  /// Get days until scheduled date (negative if overdue)
  int get daysUntilScheduled {
    final now = DateTime.now();
    final scheduledStart = DateTime(scheduledDate.year, scheduledDate.month, scheduledDate.day);
    final todayStart = DateTime(now.year, now.month, now.day);
    return scheduledStart.difference(todayStart).inDays;
  }

  /// Create PMVisit from JSON (Supabase response)
  factory PMVisit.fromJson(Map<String, dynamic> json) {
    return PMVisit(
      id: json['id'] as String?,
      tenantId: json['tenant_id'] as String,
      contractId: json['contract_id'] as String,
      facilityId: json['facility_id'] as String,
      scheduledDate: DateTime.parse(json['scheduled_date'] as String),
      completedDate: json['completed_date'] != null 
          ? DateTime.parse(json['completed_date'] as String)
          : null,
      status: PMVisitStatus.fromString(json['status'] as String),
      engineerName: json['engineer_name'] as String?,
      notes: json['notes'] as String?,
      checklistId: json['checklist_id'] as String?,
      attachmentPaths: json['attachment_paths'] != null 
          ? List<String>.from(json['attachment_paths'] as List)
          : const [],
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  /// Convert PMVisit to JSON (for Supabase operations)
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'tenant_id': tenantId,
      'contract_id': contractId,
      'facility_id': facilityId,
      'scheduled_date': scheduledDate.toIso8601String(),
      'completed_date': completedDate?.toIso8601String(),
      'status': status.value,
      'engineer_name': engineerName,
      'notes': notes,
      'checklist_id': checklistId,
      'attachment_paths': attachmentPaths,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  PMVisit copyWith({
    String? id,
    String? tenantId,
    String? contractId,
    String? facilityId,
    DateTime? scheduledDate,
    DateTime? completedDate,
    PMVisitStatus? status,
    String? engineerName,
    String? notes,
    String? checklistId,
    List<String>? attachmentPaths,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PMVisit(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      contractId: contractId ?? this.contractId,
      facilityId: facilityId ?? this.facilityId,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      completedDate: completedDate ?? this.completedDate,
      status: status ?? this.status,
      engineerName: engineerName ?? this.engineerName,
      notes: notes ?? this.notes,
      checklistId: checklistId ?? this.checklistId,
      attachmentPaths: attachmentPaths ?? this.attachmentPaths,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        tenantId,
        contractId,
        facilityId,
        scheduledDate,
        completedDate,
        status,
        engineerName,
        notes,
        checklistId,
        attachmentPaths,
        createdAt,
        updatedAt,
      ];
}

/// PM Visit status enumeration
enum PMVisitStatus {
  scheduled('scheduled'),
  inProgress('in_progress'),
  completed('completed'),
  cancelled('cancelled');

  const PMVisitStatus(this.value);

  final String value;

  /// Create PMVisitStatus from string value
  static PMVisitStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'scheduled':
        return PMVisitStatus.scheduled;
      case 'in_progress':
        return PMVisitStatus.inProgress;
      case 'completed':
        return PMVisitStatus.completed;
      case 'cancelled':
        return PMVisitStatus.cancelled;
      default:
        throw ArgumentError('Invalid PM visit status: $value');
    }
  }

  /// Display name for the status
  String get displayName {
    switch (this) {
      case PMVisitStatus.scheduled:
        return 'Scheduled';
      case PMVisitStatus.inProgress:
        return 'In Progress';
      case PMVisitStatus.completed:
        return 'Completed';
      case PMVisitStatus.cancelled:
        return 'Cancelled';
    }
  }

  /// Color hex code for status display
  String get colorHex {
    switch (this) {
      case PMVisitStatus.scheduled:
        return '#2196F3'; // Blue
      case PMVisitStatus.inProgress:
        return '#FF9800'; // Orange
      case PMVisitStatus.completed:
        return '#4CAF50'; // Green
      case PMVisitStatus.cancelled:
        return '#757575'; // Grey
    }
  }

  /// Icon name for status display
  String get iconName {
    switch (this) {
      case PMVisitStatus.scheduled:
        return 'schedule';
      case PMVisitStatus.inProgress:
        return 'hourglass_empty';
      case PMVisitStatus.completed:
        return 'check_circle';
      case PMVisitStatus.cancelled:
        return 'cancel';
    }
  }
}

/// PM Visit completion model for UI forms
class PMVisitCompletion extends Equatable {
  const PMVisitCompletion({
    required this.pmVisitId,
    required this.engineerName,
    required this.checklist,
    this.notes,
    this.attachmentPaths = const [],
  });

  final String pmVisitId;
  final String engineerName;
  final PMChecklist checklist;
  final String? notes;
  final List<String> attachmentPaths;

  @override
  List<Object?> get props => [
        pmVisitId,
        engineerName,
        checklist,
        notes,
        attachmentPaths,
      ];
}

/// PM Visit list model for dashboard display
class PMVisitSummary extends Equatable {
  const PMVisitSummary({
    required this.totalScheduled,
    required this.dueToday,
    required this.overdue,
    required this.completed,
    required this.upcomingVisits,
  });

  final int totalScheduled;
  final int dueToday;
  final int overdue;
  final int completed;
  final List<PMVisit> upcomingVisits;

  @override
  List<Object?> get props => [
        totalScheduled,
        dueToday,
        overdue,
        completed,
        upcomingVisits,
      ];
}