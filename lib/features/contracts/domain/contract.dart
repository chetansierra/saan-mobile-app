import 'package:equatable/equatable.dart';

/// Contract model for AMC/CMC service agreements
class Contract extends Equatable {
  const Contract({
    this.id,
    required this.tenantId,
    required this.title,
    required this.contractType,
    required this.serviceType,
    required this.startDate,
    required this.endDate,
    required this.pmFrequency,
    this.criticalSlaDuration,
    this.standardSlaDuration,
    this.precedence = 0,
    this.isActive = true,
    this.description,
    this.facilityIds = const [],
    this.documentPaths = const [],
    this.createdAt,
    this.updatedAt,
  });

  /// Contract ID (auto-generated UUID)
  final String? id;

  /// Tenant ID for multi-tenant isolation
  final String tenantId;

  /// Contract title/name
  final String title;

  /// Contract type (AMC/CMC)
  final ContractType contractType;

  /// Service type for SLA matching
  final String serviceType;

  /// Contract start date
  final DateTime startDate;

  /// Contract end date
  final DateTime endDate;

  /// PM frequency schedule
  final PMFrequency pmFrequency;

  /// SLA duration for critical requests (overrides default 6h)
  final Duration? criticalSlaDuration;

  /// SLA duration for standard requests (overrides default none)
  final Duration? standardSlaDuration;

  /// Precedence for tie-breaking when multiple contracts cover same facility
  final int precedence;

  /// Whether contract is active
  final bool isActive;

  /// Optional contract description
  final String? description;

  /// List of facility IDs covered by this contract
  final List<String> facilityIds;

  /// Paths to contract documents in storage
  final List<String> documentPaths;

  /// Contract creation timestamp
  final DateTime? createdAt;

  /// Contract last updated timestamp
  final DateTime? updatedAt;

  /// Check if contract is currently active
  bool get isCurrentlyActive {
    final now = DateTime.now();
    return isActive && 
           now.isAfter(startDate) && 
           now.isBefore(endDate.add(const Duration(days: 1))); // Include end date
  }

  /// Get SLA duration for given priority
  Duration? getSlaForPriority(RequestPriority priority) {
    switch (priority) {
      case RequestPriority.critical:
        return criticalSlaDuration;
      case RequestPriority.standard:
        return standardSlaDuration;
    }
  }

  /// Check if contract covers a facility
  bool coversFacility(String facilityId) {
    return facilityIds.contains(facilityId);
  }

  /// Create Contract from JSON (Supabase response)
  factory Contract.fromJson(Map<String, dynamic> json) {
    return Contract(
      id: json['id'] as String?,
      tenantId: json['tenant_id'] as String,
      title: json['title'] as String,
      contractType: ContractType.fromString(json['contract_type'] as String),
      serviceType: json['service_type'] as String,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      pmFrequency: PMFrequency.fromString(json['pm_frequency'] as String),
      criticalSlaDuration: json['critical_sla_hours'] != null 
          ? Duration(hours: json['critical_sla_hours'] as int)
          : null,
      standardSlaDuration: json['standard_sla_hours'] != null 
          ? Duration(hours: json['standard_sla_hours'] as int)
          : null,
      precedence: json['precedence'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      description: json['description'] as String?,
      facilityIds: json['facility_ids'] != null 
          ? List<String>.from(json['facility_ids'] as List)
          : const [],
      documentPaths: json['document_paths'] != null 
          ? List<String>.from(json['document_paths'] as List)
          : const [],
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  /// Convert Contract to JSON (for Supabase operations)
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'tenant_id': tenantId,
      'title': title,
      'contract_type': contractType.value,
      'service_type': serviceType,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'pm_frequency': pmFrequency.value,
      'critical_sla_hours': criticalSlaDuration?.inHours,
      'standard_sla_hours': standardSlaDuration?.inHours,
      'precedence': precedence,
      'is_active': isActive,
      'description': description,
      'facility_ids': facilityIds,
      'document_paths': documentPaths,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  Contract copyWith({
    String? id,
    String? tenantId,
    String? title,
    ContractType? contractType,
    String? serviceType,
    DateTime? startDate,
    DateTime? endDate,
    PMFrequency? pmFrequency,
    Duration? criticalSlaDuration,
    Duration? standardSlaDuration,
    int? precedence,
    bool? isActive,
    String? description,
    List<String>? facilityIds,
    List<String>? documentPaths,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Contract(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      title: title ?? this.title,
      contractType: contractType ?? this.contractType,
      serviceType: serviceType ?? this.serviceType,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      pmFrequency: pmFrequency ?? this.pmFrequency,
      criticalSlaDuration: criticalSlaDuration ?? this.criticalSlaDuration,
      standardSlaDuration: standardSlaDuration ?? this.standardSlaDuration,
      precedence: precedence ?? this.precedence,
      isActive: isActive ?? this.isActive,
      description: description ?? this.description,
      facilityIds: facilityIds ?? this.facilityIds,
      documentPaths: documentPaths ?? this.documentPaths,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        tenantId,
        title,
        contractType,
        serviceType,
        startDate,
        endDate,
        pmFrequency,
        criticalSlaDuration,
        standardSlaDuration,
        precedence,
        isActive,
        description,
        facilityIds,
        documentPaths,
        createdAt,
        updatedAt,
      ];
}

/// Contract type enumeration
enum ContractType {
  amc('amc'),
  cmc('cmc');

  const ContractType(this.value);

  final String value;

  /// Create ContractType from string value
  static ContractType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'amc':
        return ContractType.amc;
      case 'cmc':
        return ContractType.cmc;
      default:
        throw ArgumentError('Invalid contract type: $value');
    }
  }

  /// Display name for the contract type
  String get displayName {
    switch (this) {
      case ContractType.amc:
        return 'AMC (Annual Maintenance Contract)';
      case ContractType.cmc:
        return 'CMC (Comprehensive Maintenance Contract)';
    }
  }

  /// Short display name
  String get shortName {
    switch (this) {
      case ContractType.amc:
        return 'AMC';
      case ContractType.cmc:
        return 'CMC';
    }
  }
}

/// PM frequency enumeration
enum PMFrequency {
  monthly('monthly'),
  quarterly('quarterly'),
  biannual('biannual');

  const PMFrequency(this.value);

  final String value;

  /// Create PMFrequency from string value
  static PMFrequency fromString(String value) {
    switch (value.toLowerCase()) {
      case 'monthly':
        return PMFrequency.monthly;
      case 'quarterly':
        return PMFrequency.quarterly;
      case 'biannual':
        return PMFrequency.biannual;
      default:
        throw ArgumentError('Invalid PM frequency: $value');
    }
  }

  /// Display name for the frequency
  String get displayName {
    switch (this) {
      case PMFrequency.monthly:
        return 'Monthly';
      case PMFrequency.quarterly:
        return 'Quarterly';
      case PMFrequency.biannual:
        return 'Bi-Annual';
    }
  }

  /// Get frequency in months
  int get monthsInterval {
    switch (this) {
      case PMFrequency.monthly:
        return 1;
      case PMFrequency.quarterly:
        return 3;
      case PMFrequency.biannual:
        return 6;
    }
  }
}

/// Request priority enumeration (referenced from existing request model)
enum RequestPriority {
  critical('critical'),
  standard('standard');

  const RequestPriority(this.value);

  final String value;

  /// Create RequestPriority from string value
  static RequestPriority fromString(String value) {
    switch (value.toLowerCase()) {
      case 'critical':
        return RequestPriority.critical;
      case 'standard':
        return RequestPriority.standard;
      default:
        throw ArgumentError('Invalid request priority: $value');
    }
  }

  /// Display name for the priority
  String get displayName {
    switch (this) {
      case RequestPriority.critical:
        return 'Critical';
      case RequestPriority.standard:
        return 'Standard';
    }
  }
}

/// Contract creation model for UI forms
class ContractInput extends Equatable {
  const ContractInput({
    required this.title,
    required this.contractType,
    required this.serviceType,
    required this.startDate,
    required this.endDate,
    required this.pmFrequency,
    this.criticalSlaDuration,
    this.standardSlaDuration,
    this.precedence = 0,
    this.description,
    this.facilityIds = const [],
  });

  final String title;
  final ContractType contractType;
  final String serviceType;
  final DateTime startDate;
  final DateTime endDate;
  final PMFrequency pmFrequency;
  final Duration? criticalSlaDuration;
  final Duration? standardSlaDuration;
  final int precedence;
  final String? description;
  final List<String> facilityIds;

  /// Convert to Contract model
  Contract toContract({required String tenantId}) {
    return Contract(
      tenantId: tenantId,
      title: title,
      contractType: contractType,
      serviceType: serviceType,
      startDate: startDate,
      endDate: endDate,
      pmFrequency: pmFrequency,
      criticalSlaDuration: criticalSlaDuration,
      standardSlaDuration: standardSlaDuration,
      precedence: precedence,
      description: description,
      facilityIds: facilityIds,
    );
  }

  @override
  List<Object?> get props => [
        title,
        contractType,
        serviceType,
        startDate,
        endDate,
        pmFrequency,
        criticalSlaDuration,
        standardSlaDuration,
        precedence,
        description,
        facilityIds,
      ];
}