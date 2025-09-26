import 'package:flutter_test/flutter_test.dart';

import '../../../lib/features/onboarding/domain/models/company.dart';
import '../../../lib/features/onboarding/domain/onboarding_service.dart';

void main() {
  group('Onboarding Flow Tests', () {
    testWidgets('OnboardingState tracks completion correctly', (tester) async {
      // Test empty state
      const emptyState = OnboardingState();
      expect(emptyState.isOnboardingCompleted, false);
      expect(emptyState.canProceedToNext, false);

      // Test with company only
      const company = Company(
        name: 'Test Company',
        businessType: BusinessTypes.manufacturing,
      );
      final withCompanyState = emptyState.copyWith(company: company);
      expect(withCompanyState.isCompanyCompleted, true);
      expect(withCompanyState.isFacilitiesCompleted, false);
      expect(withCompanyState.isOnboardingCompleted, false);
      expect(withCompanyState.canProceedToNext, true);

      // Test with company and facilities
      const facility = Facility(
        id: 'facility-1',
        name: 'Test Facility',
        address: '123 Test St',
      );
      final completedState = withCompanyState.copyWith(facilities: [facility]);
      expect(completedState.isCompanyCompleted, true);
      expect(completedState.isFacilitiesCompleted, true);
      expect(completedState.isOnboardingCompleted, true);
    });

    testWidgets('OnboardingStep progression works correctly', (tester) async {
      // Test step progression
      expect(OnboardingStep.company.index, 0);
      expect(OnboardingStep.facility.index, 1);
      expect(OnboardingStep.review.index, 2);

      // Test next/previous navigation
      expect(OnboardingStep.company.next, OnboardingStep.facility);
      expect(OnboardingStep.facility.next, OnboardingStep.review);
      expect(OnboardingStep.review.next, null);

      expect(OnboardingStep.company.previous, null);
      expect(OnboardingStep.facility.previous, OnboardingStep.company);
      expect(OnboardingStep.review.previous, OnboardingStep.facility);

      // Test progress calculation
      expect(OnboardingStep.company.progress, 1.0 / 3.0);
      expect(OnboardingStep.facility.progress, 2.0 / 3.0);
      expect(OnboardingStep.review.progress, 3.0 / 3.0);
    });

    testWidgets('Company model validation works correctly', (tester) async {
      // Test valid company creation
      const validCompany = Company(
        name: 'Valid Company Ltd',
        businessType: BusinessTypes.manufacturing,
        domain: 'company.com',
        gst: '22AAAAA0000A1Z5',
        cin: 'L74899DL2019PLC123456',
      );

      expect(validCompany.name, 'Valid Company Ltd');
      expect(validCompany.businessType, BusinessTypes.manufacturing);

      // Test JSON serialization
      final json = validCompany.toJson();
      expect(json['name'], 'Valid Company Ltd');
      expect(json['business_type'], BusinessTypes.manufacturing);

      final fromJson = Company.fromJson(json);
      expect(fromJson, validCompany);
    });

    testWidgets('Company GST validation works correctly', (tester) async {
      // Valid GST numbers
      expect(Company.isValidGST('22AAAAA0000A1Z5'), true);
      expect(Company.isValidGST('07AABCU9603R1ZX'), true);
      expect(Company.isValidGST(null), true); // Optional
      expect(Company.isValidGST(''), true); // Optional

      // Invalid GST numbers
      expect(Company.isValidGST('invalid'), false);
      expect(Company.isValidGST('22AAAAA0000A1'), false); // Too short
      expect(Company.isValidGST('22AAAAA0000A1Z5X'), false); // Too long
    });

    testWidgets('Company CIN validation works correctly', (tester) async {
      // Valid CIN numbers
      expect(Company.isValidCIN('L74899DL2019PLC123456'), true);
      expect(Company.isValidCIN('U12345MH2020PTC654321'), true);
      expect(Company.isValidCIN(null), true); // Optional
      expect(Company.isValidCIN(''), true); // Optional

      // Invalid CIN numbers
      expect(Company.isValidCIN('invalid'), false);
      expect(Company.isValidCIN('L74899DL2019PLC12345'), false); // Too short
      expect(Company.isValidCIN('L74899DL2019PLC1234567'), false); // Too long
    });

    testWidgets('Facility model validation works correctly', (tester) async {
      // Test valid facility creation
      const validFacility = Facility(
        id: 'facility-123',
        name: 'Main Plant',
        address: '123 Industrial Ave, City, State 12345',
        lat: 28.7041,
        lng: 77.1025,
        pocName: 'John Manager',
        pocPhone: '+91-9876543210',
        pocEmail: 'john@facility.com',
      );

      expect(validFacility.name, 'Main Plant');
      expect(validFacility.lat, 28.7041);
      expect(validFacility.lng, 77.1025);

      // Test JSON serialization
      final json = validFacility.toJson();
      expect(json['name'], 'Main Plant');
      expect(json['lat'], 28.7041);

      final fromJson = Facility.fromJson(json);
      expect(fromJson, validFacility);
    });

    testWidgets('Facility email validation works correctly', (tester) async {
      // Valid emails
      expect(Facility.isValidEmail('test@example.com'), true);
      expect(Facility.isValidEmail('user.name@company.co.uk'), true);
      expect(Facility.isValidEmail(null), true); // Optional
      expect(Facility.isValidEmail(''), true); // Optional

      // Invalid emails
      expect(Facility.isValidEmail('invalid'), false);
      expect(Facility.isValidEmail('@domain.com'), false);
      expect(Facility.isValidEmail('user@'), false);
    });

    testWidgets('Facility phone validation works correctly', (tester) async {
      // Valid phone numbers
      expect(Facility.isValidPhone('+91-9876543210'), true);
      expect(Facility.isValidPhone('9876543210'), true);
      expect(Facility.isValidPhone('+1 555 123 4567'), true);
      expect(Facility.isValidPhone(null), true); // Optional
      expect(Facility.isValidPhone(''), true); // Optional

      // Invalid phone numbers
      expect(Facility.isValidPhone('invalid'), false);
      expect(Facility.isValidPhone('123'), false); // Too short
      expect(Facility.isValidPhone('12345678901234567890'), false); // Too long
    });

    testWidgets('BusinessTypes contains expected values', (tester) async {
      expect(BusinessTypes.all.contains(BusinessTypes.manufacturing), true);
      expect(BusinessTypes.all.contains(BusinessTypes.pharmaceuticals), true);
      expect(BusinessTypes.all.contains(BusinessTypes.dataCenter), true);
      expect(BusinessTypes.all.contains(BusinessTypes.foodProcessing), true);
      expect(BusinessTypes.all.contains(BusinessTypes.healthcare), true);
      expect(BusinessTypes.all.contains(BusinessTypes.other), true);
      
      // Should have reasonable number of options
      expect(BusinessTypes.all.length, greaterThan(5));
      expect(BusinessTypes.all.length, lessThan(15));
    });
  });

  group('OnboardingService Extensions Tests', () {
    late _MockOnboardingService mockService;

    setUp(() {
      mockService = _MockOnboardingService();
    });

    testWidgets('canProceedToFacilities returns correct values', (tester) async {
      // No company
      mockService.setState(const OnboardingState());
      expect(mockService.canProceedToFacilities(), false);

      // With company
      const company = Company(
        name: 'Test Company',
        businessType: BusinessTypes.manufacturing,
      );
      mockService.setState(const OnboardingState(company: company));
      expect(mockService.canProceedToFacilities(), true);
    });

    testWidgets('canProceedToReview returns correct values', (tester) async {
      // Empty state
      mockService.setState(const OnboardingState());
      expect(mockService.canProceedToReview(), false);

      // With company only
      const company = Company(
        name: 'Test Company',
        businessType: BusinessTypes.manufacturing,
      );
      mockService.setState(const OnboardingState(company: company));
      expect(mockService.canProceedToReview(), false);

      // With company and facilities
      const facility = Facility(
        name: 'Test Facility',
        address: '123 Test St',
      );
      mockService.setState(const OnboardingState(
        company: company,
        facilities: [facility],
      ));
      expect(mockService.canProceedToReview(), true);
    });

    testWidgets('getProgress returns correct values', (tester) async {
      // Company step
      mockService.setState(const OnboardingState(
        currentStep: OnboardingStep.company,
      ));
      expect(mockService.getProgress(), OnboardingStep.company.progress);

      // Facility step
      mockService.setState(const OnboardingState(
        currentStep: OnboardingStep.facility,
      ));
      expect(mockService.getProgress(), OnboardingStep.facility.progress);

      // Review step
      mockService.setState(const OnboardingState(
        currentStep: OnboardingStep.review,
      ));
      expect(mockService.getProgress(), OnboardingStep.review.progress);
    });

    testWidgets('isStepCompleted returns correct values', (tester) async {
      const company = Company(
        name: 'Test Company',
        businessType: BusinessTypes.manufacturing,
      );
      const facility = Facility(
        name: 'Test Facility',
        address: '123 Test St',
      );

      // Complete state
      mockService.setState(const OnboardingState(
        company: company,
        facilities: [facility],
      ));

      expect(mockService.isStepCompleted(OnboardingStep.company), true);
      expect(mockService.isStepCompleted(OnboardingStep.facility), true);
      expect(mockService.isStepCompleted(OnboardingStep.review), true);

      // Partial state
      mockService.setState(const OnboardingState(company: company));

      expect(mockService.isStepCompleted(OnboardingStep.company), true);
      expect(mockService.isStepCompleted(OnboardingStep.facility), false);
      expect(mockService.isStepCompleted(OnboardingStep.review), false);
    });
  });
}

/// Mock implementation of OnboardingService for testing
class _MockOnboardingService extends OnboardingService {
  _MockOnboardingService() : super._(null as dynamic);

  OnboardingState _mockState = const OnboardingState();

  void setState(OnboardingState state) {
    _mockState = state;
  }

  @override
  OnboardingState get state => _mockState;
}