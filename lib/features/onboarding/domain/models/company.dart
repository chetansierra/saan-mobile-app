import 'package:equatable/equatable.dart';

/// Company model for tenant creation during onboarding
class Company extends Equatable {
  const Company({
    required this.name,
    required this.businessType,
    this.domain,
    this.gst,
    this.cin,
  });

  /// Company name
  final String name;

  /// Business domain (optional)
  final String? domain;

  /// GST number (optional)
  final String? gst;

  /// CIN number (optional) 
  final String? cin;

  /// Business type (e.g., Manufacturing, Pharmaceuticals, etc.)
  final String businessType;

  /// Create Company from JSON (Supabase response)
  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      name: json['name'] as String,
      domain: json['domain'] as String?,
      gst: json['gst'] as String?,
      cin: json['cin'] as String?,
      businessType: json['business_type'] as String,
    );
  }

  /// Convert Company to JSON (for Supabase operations)
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'domain': domain,
      'gst': gst,
      'cin': cin,
      'business_type': businessType,
    };
  }

  /// Create a copy with updated fields
  Company copyWith({
    String? name,
    String? domain,
    String? gst,
    String? cin,
    String? businessType,
  }) {
    return Company(
      name: name ?? this.name,
      domain: domain ?? this.domain,
      gst: gst ?? this.gst,
      cin: cin ?? this.cin,
      businessType: businessType ?? this.businessType,
    );
  }

  /// Validate GST format (basic validation)
  static bool isValidGST(String? gst) {
    if (gst == null || gst.trim().isEmpty) return true; // Optional
    
    // Basic GST format: 15 characters, starts with 2 digits (state code)
    final gstPattern = RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}[Z]{1}[0-9A-Z]{1}$');
    return gstPattern.hasMatch(gst.trim().toUpperCase());
  }

  /// Validate CIN format (basic validation)
  static bool isValidCIN(String? cin) {
    if (cin == null || cin.trim().isEmpty) return true; // Optional
    
    // Basic CIN format: 21 characters
    final cinPattern = RegExp(r'^[LUF][0-9]{5}[A-Z]{2}[0-9]{4}[A-Z]{3}[0-9]{6}$');
    return cinPattern.hasMatch(cin.trim().toUpperCase());
  }

  @override
  List<Object?> get props => [name, domain, gst, cin, businessType];
}

/// Facility model for location management
class Facility extends Equatable {
  const Facility({
    this.id,
    required this.name,
    required this.address,
    this.lat,
    this.lng,
    this.pocName,
    this.pocPhone,
    this.pocEmail,
    this.createdAt,
  });

  /// Facility ID (null for new facilities)
  final String? id;

  /// Facility name
  final String name;

  /// Physical address
  final String address;

  /// Latitude coordinate (optional)
  final double? lat;

  /// Longitude coordinate (optional)
  final double? lng;

  /// Point of contact name (optional)
  final String? pocName;

  /// Point of contact phone (optional)
  final String? pocPhone;

  /// Point of contact email (optional)
  final String? pocEmail;

  /// Creation timestamp
  final DateTime? createdAt;

  /// Create Facility from JSON (Supabase response)
  factory Facility.fromJson(Map<String, dynamic> json) {
    return Facility(
      id: json['id'] as String?,
      name: json['name'] as String,
      address: json['address'] as String,
      lat: json['lat'] as double?,
      lng: json['lng'] as double?,
      pocName: json['poc_name'] as String?,
      pocPhone: json['poc_phone'] as String?,
      pocEmail: json['poc_email'] as String?,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  /// Convert Facility to JSON (for Supabase operations)
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'address': address,
      'lat': lat,
      'lng': lng,
      'poc_name': pocName,
      'poc_phone': pocPhone,
      'poc_email': pocEmail,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  Facility copyWith({
    String? id,
    String? name,
    String? address,
    double? lat,
    double? lng,
    String? pocName,
    String? pocPhone,
    String? pocEmail,
    DateTime? createdAt,
  }) {
    return Facility(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      pocName: pocName ?? this.pocName,
      pocPhone: pocPhone ?? this.pocPhone,
      pocEmail: pocEmail ?? this.pocEmail,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Validate email format
  static bool isValidEmail(String? email) {
    if (email == null || email.trim().isEmpty) return true; // Optional
    
    final emailPattern = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    return emailPattern.hasMatch(email.trim());
  }

  /// Validate phone format (basic validation)
  static bool isValidPhone(String? phone) {
    if (phone == null || phone.trim().isEmpty) return true; // Optional
    
    // Allow various phone formats: +91-9876543210, 9876543210, etc.
    final phonePattern = RegExp(r'^[\+]?[0-9\-\s]{10,15}$');
    return phonePattern.hasMatch(phone.trim());
  }

  @override
  List<Object?> get props => [
        id,
        name,
        address,
        lat,
        lng,
        pocName,
        pocPhone,
        pocEmail,
        createdAt,
      ];
}

/// Onboarding state model
class OnboardingState extends Equatable {
  const OnboardingState({
    this.currentStep = OnboardingStep.company,
    this.company,
    this.facilities = const [],
    this.isLoading = false,
    this.error,
  });

  /// Current onboarding step
  final OnboardingStep currentStep;

  /// Company data
  final Company? company;

  /// List of facilities
  final List<Facility> facilities;

  /// Loading state
  final bool isLoading;

  /// Error message
  final String? error;

  /// Whether company step is completed
  bool get isCompanyCompleted => company != null;

  /// Whether facility step is completed (at least one facility)
  bool get isFacilitiesCompleted => facilities.isNotEmpty;

  /// Whether onboarding is completed
  bool get isOnboardingCompleted => isCompanyCompleted && isFacilitiesCompleted;

  /// Can proceed to next step
  bool get canProceedToNext {
    switch (currentStep) {
      case OnboardingStep.company:
        return isCompanyCompleted;
      case OnboardingStep.facility:
        return isFacilitiesCompleted;
      case OnboardingStep.review:
        return isOnboardingCompleted;
    }
  }

  /// Create copy with updated fields
  OnboardingState copyWith({
    OnboardingStep? currentStep,
    Company? company,
    List<Facility>? facilities,
    bool? isLoading,
    String? error,
  }) {
    return OnboardingState(
      currentStep: currentStep ?? this.currentStep,
      company: company ?? this.company,
      facilities: facilities ?? this.facilities,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  /// Create loading state
  OnboardingState copyWithLoading(bool loading) {
    return copyWith(isLoading: loading, error: null);
  }

  /// Create error state
  OnboardingState copyWithError(String errorMessage) {
    return copyWith(isLoading: false, error: errorMessage);
  }

  @override
  List<Object?> get props => [
        currentStep,
        company,
        facilities,
        isLoading,
        error,
      ];
}

/// Onboarding steps enumeration
enum OnboardingStep {
  company,
  facility,
  review;

  /// Display name for the step
  String get displayName {
    switch (this) {
      case OnboardingStep.company:
        return 'Company Setup';
      case OnboardingStep.facility:
        return 'Facility Setup';
      case OnboardingStep.review:
        return 'Review & Complete';
    }
  }

  /// Step index (0-based)
  int get index {
    switch (this) {
      case OnboardingStep.company:
        return 0;
      case OnboardingStep.facility:
        return 1;
      case OnboardingStep.review:
        return 2;
    }
  }

  /// Total number of steps
  static int get totalSteps => 3;

  /// Progress percentage (0.0 to 1.0)
  double get progress => (index + 1) / totalSteps;

  /// Next step (if available)
  OnboardingStep? get next {
    switch (this) {
      case OnboardingStep.company:
        return OnboardingStep.facility;
      case OnboardingStep.facility:
        return OnboardingStep.review;
      case OnboardingStep.review:
        return null; // No next step
    }
  }

  /// Previous step (if available)
  OnboardingStep? get previous {
    switch (this) {
      case OnboardingStep.company:
        return null; // No previous step
      case OnboardingStep.facility:
        return OnboardingStep.company;
      case OnboardingStep.review:
        return OnboardingStep.facility;
    }
  }
}

/// Business type constants
abstract class BusinessTypes {
  static const String manufacturing = 'Manufacturing';
  static const String pharmaceuticals = 'Pharmaceuticals';
  static const String dataCenter = 'Data Center';
  static const String foodProcessing = 'Food Processing';
  static const String healthcare = 'Healthcare';
  static const String hospitality = 'Hospitality';
  static const String retail = 'Retail';
  static const String logistics = 'Logistics';
  static const String other = 'Other';

  /// List of all available business types
  static const List<String> all = [
    manufacturing,
    pharmaceuticals,
    dataCenter,
    foodProcessing,
    healthcare,
    hospitality,
    retail,
    logistics,
    other,
  ];
}