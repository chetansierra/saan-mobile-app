import 'package:equatable/equatable.dart';

/// PM Checklist model for tracking preventive maintenance tasks
class PMChecklist extends Equatable {
  const PMChecklist({
    this.id,
    required this.tenantId,
    required this.pmVisitId,
    required this.templateName,
    required this.items,
    this.overallNotes,
    this.completedAt,
    this.completedBy,
    this.createdAt,
    this.updatedAt,
  });

  /// Checklist ID (auto-generated UUID)
  final String? id;

  /// Tenant ID for multi-tenant isolation
  final String tenantId;

  /// PM Visit ID this checklist belongs to
  final String pmVisitId;

  /// Template name/type for the checklist
  final String templateName;

  /// List of checklist items
  final List<PMChecklistItem> items;

  /// Overall notes for the entire checklist
  final String? overallNotes;

  /// When checklist was completed
  final DateTime? completedAt;

  /// Who completed the checklist
  final String? completedBy;

  /// Checklist creation timestamp
  final DateTime? createdAt;

  /// Checklist last updated timestamp
  final DateTime? updatedAt;

  /// Check if all items are completed
  bool get isComplete {
    return items.every((item) => item.isCompleted);
  }

  /// Get completion percentage
  double get completionPercentage {
    if (items.isEmpty) return 0.0;
    final completedCount = items.where((item) => item.isCompleted).length;
    return completedCount / items.length;
  }

  /// Get total items count
  int get totalItems => items.length;

  /// Get completed items count
  int get completedItems => items.where((item) => item.isCompleted).length;

  /// Get pending items count
  int get pendingItems => items.where((item) => !item.isCompleted).length;

  /// Create PMChecklist from JSON (Supabase response)
  factory PMChecklist.fromJson(Map<String, dynamic> json) {
    return PMChecklist(
      id: json['id'] as String?,
      tenantId: json['tenant_id'] as String,
      pmVisitId: json['pm_visit_id'] as String,
      templateName: json['template_name'] as String,
      items: json['items'] != null 
          ? (json['items'] as List)
              .map((item) => PMChecklistItem.fromJson(item as Map<String, dynamic>))
              .toList()
          : const [],
      overallNotes: json['overall_notes'] as String?,
      completedAt: json['completed_at'] != null 
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      completedBy: json['completed_by'] as String?,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  /// Convert PMChecklist to JSON (for Supabase operations)
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'tenant_id': tenantId,
      'pm_visit_id': pmVisitId,
      'template_name': templateName,
      'items': items.map((item) => item.toJson()).toList(),
      'overall_notes': overallNotes,
      'completed_at': completedAt?.toIso8601String(),
      'completed_by': completedBy,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  PMChecklist copyWith({
    String? id,
    String? tenantId,
    String? pmVisitId,
    String? templateName,
    List<PMChecklistItem>? items,
    String? overallNotes,
    DateTime? completedAt,
    String? completedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PMChecklist(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      pmVisitId: pmVisitId ?? this.pmVisitId,
      templateName: templateName ?? this.templateName,
      items: items ?? this.items,
      overallNotes: overallNotes ?? this.overallNotes,
      completedAt: completedAt ?? this.completedAt,
      completedBy: completedBy ?? this.completedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        tenantId,
        pmVisitId,
        templateName,
        items,
        overallNotes,
        completedAt,
        completedBy,
        createdAt,
        updatedAt,
      ];
}

/// Individual PM checklist item
class PMChecklistItem extends Equatable {
  const PMChecklistItem({
    required this.id,
    required this.title,
    required this.description,
    this.isCompleted = false,
    this.notes,
    this.photoPaths = const [],
    this.priority = ChecklistItemPriority.normal,
    this.completedAt,
  });

  /// Unique ID for the checklist item
  final String id;

  /// Title/name of the checklist item
  final String title;

  /// Detailed description of what needs to be checked
  final String description;

  /// Whether this item has been completed
  final bool isCompleted;

  /// Optional notes for this specific item
  final String? notes;

  /// Paths to photos taken as evidence for this item
  final List<String> photoPaths;

  /// Priority level of this checklist item
  final ChecklistItemPriority priority;

  /// When this item was completed
  final DateTime? completedAt;

  /// Create PMChecklistItem from JSON
  factory PMChecklistItem.fromJson(Map<String, dynamic> json) {
    return PMChecklistItem(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      isCompleted: json['is_completed'] as bool? ?? false,
      notes: json['notes'] as String?,
      photoPaths: json['photo_paths'] != null 
          ? List<String>.from(json['photo_paths'] as List)
          : const [],
      priority: json['priority'] != null 
          ? ChecklistItemPriority.fromString(json['priority'] as String)
          : ChecklistItemPriority.normal,
      completedAt: json['completed_at'] != null 
          ? DateTime.parse(json['completed_at'] as String)
          : null,
    );
  }

  /// Convert PMChecklistItem to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'is_completed': isCompleted,
      'notes': notes,
      'photo_paths': photoPaths,
      'priority': priority.value,
      'completed_at': completedAt?.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  PMChecklistItem copyWith({
    String? id,
    String? title,
    String? description,
    bool? isCompleted,
    String? notes,
    List<String>? photoPaths,
    ChecklistItemPriority? priority,
    DateTime? completedAt,
  }) {
    return PMChecklistItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      notes: notes ?? this.notes,
      photoPaths: photoPaths ?? this.photoPaths,
      priority: priority ?? this.priority,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        isCompleted,
        notes,
        photoPaths,
        priority,
        completedAt,
      ];
}

/// Checklist item priority enumeration
enum ChecklistItemPriority {
  low('low'),
  normal('normal'),
  high('high'),
  critical('critical');

  const ChecklistItemPriority(this.value);

  final String value;

  /// Create ChecklistItemPriority from string value
  static ChecklistItemPriority fromString(String value) {
    switch (value.toLowerCase()) {
      case 'low':
        return ChecklistItemPriority.low;
      case 'normal':
        return ChecklistItemPriority.normal;
      case 'high':
        return ChecklistItemPriority.high;
      case 'critical':
        return ChecklistItemPriority.critical;
      default:
        throw ArgumentError('Invalid checklist item priority: $value');
    }
  }

  /// Display name for the priority
  String get displayName {
    switch (this) {
      case ChecklistItemPriority.low:
        return 'Low';
      case ChecklistItemPriority.normal:
        return 'Normal';
      case ChecklistItemPriority.high:
        return 'High';
      case ChecklistItemPriority.critical:
        return 'Critical';
    }
  }

  /// Color hex code for priority display
  String get colorHex {
    switch (this) {
      case ChecklistItemPriority.low:
        return '#4CAF50'; // Green
      case ChecklistItemPriority.normal:
        return '#2196F3'; // Blue
      case ChecklistItemPriority.high:
        return '#FF9800'; // Orange
      case ChecklistItemPriority.critical:
        return '#F44336'; // Red
    }
  }
}

/// Predefined checklist templates
class PMChecklistTemplate {
  /// Get default HVAC maintenance checklist template
  static List<PMChecklistItem> getHVACTemplate() {
    return [
      const PMChecklistItem(
        id: 'hvac_1',
        title: 'Filter Inspection',
        description: 'Check and replace air filters if necessary',
        priority: ChecklistItemPriority.high,
      ),
      const PMChecklistItem(
        id: 'hvac_2',
        title: 'Thermostat Calibration',
        description: 'Verify thermostat accuracy and calibrate if needed',
        priority: ChecklistItemPriority.normal,
      ),
      const PMChecklistItem(
        id: 'hvac_3',
        title: 'Refrigerant Levels',
        description: 'Check refrigerant levels and top up if required',
        priority: ChecklistItemPriority.high,
      ),
      const PMChecklistItem(
        id: 'hvac_4',
        title: 'Electrical Connections',
        description: 'Inspect all electrical connections for wear or damage',
        priority: ChecklistItemPriority.critical,
      ),
      const PMChecklistItem(
        id: 'hvac_5',
        title: 'Ductwork Inspection',
        description: 'Check ductwork for leaks, damage, or blockages',
        priority: ChecklistItemPriority.normal,
      ),
      const PMChecklistItem(
        id: 'hvac_6',
        title: 'System Performance Test',
        description: 'Run complete system test and verify performance metrics',
        priority: ChecklistItemPriority.high,
      ),
    ];
  }

  /// Get default electrical maintenance checklist template
  static List<PMChecklistItem> getElectricalTemplate() {
    return [
      const PMChecklistItem(
        id: 'elec_1',
        title: 'Panel Board Inspection',
        description: 'Check main electrical panel for damage, corrosion, or loose connections',
        priority: ChecklistItemPriority.critical,
      ),
      const PMChecklistItem(
        id: 'elec_2',
        title: 'Circuit Breaker Test',
        description: 'Test all circuit breakers for proper operation',
        priority: ChecklistItemPriority.high,
      ),
      const PMChecklistItem(
        id: 'elec_3',
        title: 'Grounding System Check',
        description: 'Verify grounding system integrity and resistance',
        priority: ChecklistItemPriority.critical,
      ),
      const PMChecklistItem(
        id: 'elec_4',
        title: 'Lighting System Audit',
        description: 'Check all lighting fixtures and replace faulty bulbs',
        priority: ChecklistItemPriority.normal,
      ),
      const PMChecklistItem(
        id: 'elec_5',
        title: 'Emergency Systems Test',
        description: 'Test emergency lighting and backup power systems',
        priority: ChecklistItemPriority.high,
      ),
    ];
  }

  /// Get default plumbing maintenance checklist template
  static List<PMChecklistItem> getPlumbingTemplate() {
    return [
      const PMChecklistItem(
        id: 'plumb_1',
        title: 'Water Pressure Check',
        description: 'Test water pressure at all fixtures and outlets',
        priority: ChecklistItemPriority.normal,
      ),
      const PMChecklistItem(
        id: 'plumb_2',
        title: 'Leak Detection',
        description: 'Inspect all pipes, joints, and fixtures for leaks',
        priority: ChecklistItemPriority.high,
      ),
      const PMChecklistItem(
        id: 'plumb_3',
        title: 'Drain System Test',
        description: 'Check all drains for proper flow and clear any blockages',
        priority: ChecklistItemPriority.normal,
      ),
      const PMChecklistItem(
        id: 'plumb_4',
        title: 'Water Heater Inspection',
        description: 'Check water heater temperature, pressure relief valve, and efficiency',
        priority: ChecklistItemPriority.high,
      ),
      const PMChecklistItem(
        id: 'plumb_5',
        title: 'Shut-off Valve Test',
        description: 'Test all main and emergency shut-off valves',
        priority: ChecklistItemPriority.critical,
      ),
    ];
  }

  /// Get template based on service type
  static List<PMChecklistItem> getTemplateByType(String serviceType) {
    switch (serviceType.toLowerCase()) {
      case 'hvac':
        return getHVACTemplate();
      case 'electrical':
        return getElectricalTemplate();
      case 'plumbing':
        return getPlumbingTemplate();
      default:
        return getHVACTemplate(); // Default fallback
    }
  }
}