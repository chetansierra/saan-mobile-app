import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/client.dart';
import '../domain/models/company.dart';

/// Repository for onboarding-related database operations
class OnboardingRepository {
  OnboardingRepository._();

  /// Singleton instance
  static final OnboardingRepository _instance = OnboardingRepository._();
  static OnboardingRepository get instance => _instance;

  /// Supabase client reference
  SupabaseClient get _client => SupabaseService.client;

  /// Create tenant (company) in database
  Future<String> createTenant(Company company) async {
    try {
      debugPrint('📝 Creating tenant: ${company.name}');
      
      final response = await _client
          .from(SupabaseTables.tenants)
          .insert(company.toJson())
          .select('id')
          .single();

      final tenantId = response['id'] as String;
      debugPrint('✅ Tenant created with ID: $tenantId');
      
      return tenantId;
    } on PostgrestException catch (e) {
      debugPrint('❌ Failed to create tenant: ${e.message}');
      throw e.toSupabaseException();
    } catch (e) {
      debugPrint('❌ Unexpected error creating tenant: $e');
      throw SupabaseException('Failed to create company: ${e.toString()}');
    }
  }

  /// Update tenant information
  Future<void> updateTenant(String tenantId, Company company) async {
    try {
      debugPrint('📝 Updating tenant: $tenantId');
      
      await _client
          .from(SupabaseTables.tenants)
          .update(company.toJson())
          .eq('id', tenantId);

      debugPrint('✅ Tenant updated successfully');
    } on PostgrestException catch (e) {
      debugPrint('❌ Failed to update tenant: ${e.message}');
      throw e.toSupabaseException();
    } catch (e) {
      debugPrint('❌ Unexpected error updating tenant: $e');
      throw SupabaseException('Failed to update company: ${e.toString()}');
    }
  }

  /// Get tenant by ID
  Future<Company?> getTenant(String tenantId) async {
    try {
      debugPrint('👤 Fetching tenant: $tenantId');
      
      final response = await _client
          .from(SupabaseTables.tenants)
          .select()
          .eq('id', tenantId)
          .maybeSingle();

      if (response == null) {
        debugPrint('⚠️ No tenant found with ID: $tenantId');
        return null;
      }

      final company = Company.fromJson(response);
      debugPrint('✅ Tenant fetched successfully: ${company.name}');
      
      return company;
    } on PostgrestException catch (e) {
      debugPrint('❌ Failed to fetch tenant: ${e.message}');
      throw e.toSupabaseException();
    } catch (e) {
      debugPrint('❌ Unexpected error fetching tenant: $e');
      throw SupabaseException('Failed to fetch company: ${e.toString()}');
    }
  }

  /// Create facility in database
  Future<String> createFacility(String tenantId, Facility facility) async {
    try {
      debugPrint('📝 Creating facility: ${facility.name}');
      
      final facilityData = facility.toJson()..['tenant_id'] = tenantId;
      
      final response = await _client
          .from(SupabaseTables.facilities)
          .insert(facilityData)
          .select('id')
          .single();

      final facilityId = response['id'] as String;
      debugPrint('✅ Facility created with ID: $facilityId');
      
      return facilityId;
    } on PostgrestException catch (e) {
      debugPrint('❌ Failed to create facility: ${e.message}');
      throw e.toSupabaseException();
    } catch (e) {
      debugPrint('❌ Unexpected error creating facility: $e');
      throw SupabaseException('Failed to create facility: ${e.toString()}');
    }
  }

  /// Update facility in database
  Future<void> updateFacility(String facilityId, Facility facility) async {
    try {
      debugPrint('📝 Updating facility: $facilityId');
      
      await _client
          .from(SupabaseTables.facilities)
          .update(facility.toJson())
          .eq('id', facilityId);

      debugPrint('✅ Facility updated successfully');
    } on PostgrestException catch (e) {
      debugPrint('❌ Failed to update facility: ${e.message}');
      throw e.toSupabaseException();
    } catch (e) {
      debugPrint('❌ Unexpected error updating facility: $e');
      throw SupabaseException('Failed to update facility: ${e.toString()}');
    }
  }

  /// Delete facility from database
  Future<void> deleteFacility(String facilityId) async {
    try {
      debugPrint('🗑️ Deleting facility: $facilityId');
      
      await _client
          .from(SupabaseTables.facilities)
          .delete()
          .eq('id', facilityId);

      debugPrint('✅ Facility deleted successfully');
    } on PostgrestException catch (e) {
      debugPrint('❌ Failed to delete facility: ${e.message}');
      throw e.toSupabaseException();
    } catch (e) {
      debugPrint('❌ Unexpected error deleting facility: $e');
      throw SupabaseException('Failed to delete facility: ${e.toString()}');
    }
  }

  /// Get all facilities for a tenant
  Future<List<Facility>> getFacilities(String tenantId) async {
    try {
      debugPrint('📋 Fetching facilities for tenant: $tenantId');
      
      final response = await _client
          .from(SupabaseTables.facilities)
          .select()
          .eq('tenant_id', tenantId)
          .order('created_at', ascending: true);

      final facilities = (response as List)
          .map((json) => Facility.fromJson(json as Map<String, dynamic>))
          .toList();

      debugPrint('✅ Fetched ${facilities.length} facilities');
      return facilities;
    } on PostgrestException catch (e) {
      debugPrint('❌ Failed to fetch facilities: ${e.message}');
      throw e.toSupabaseException();
    } catch (e) {
      debugPrint('❌ Unexpected error fetching facilities: $e');
      throw SupabaseException('Failed to fetch facilities: ${e.toString()}');
    }
  }

  /// Get facility by ID
  Future<Facility?> getFacility(String facilityId) async {
    try {
      debugPrint('🏢 Fetching facility: $facilityId');
      
      final response = await _client
          .from(SupabaseTables.facilities)
          .select()
          .eq('id', facilityId)
          .maybeSingle();

      if (response == null) {
        debugPrint('⚠️ No facility found with ID: $facilityId');
        return null;
      }

      final facility = Facility.fromJson(response);
      debugPrint('✅ Facility fetched successfully: ${facility.name}');
      
      return facility;
    } on PostgrestException catch (e) {
      debugPrint('❌ Failed to fetch facility: ${e.message}');
      throw e.toSupabaseException();
    } catch (e) {
      debugPrint('❌ Unexpected error fetching facility: $e');
      throw SupabaseException('Failed to fetch facility: ${e.toString()}');
    }
  }

  /// Check if tenant has any facilities
  Future<bool> hasFacilities(String tenantId) async {
    try {
      debugPrint('🔍 Checking if tenant has facilities: $tenantId');
      
      final response = await _client
          .from(SupabaseTables.facilities)
          .select('id')
          .eq('tenant_id', tenantId)
          .limit(1);

      final hasFacilities = (response as List).isNotEmpty;
      debugPrint('✅ Tenant has facilities: $hasFacilities');
      
      return hasFacilities;
    } on PostgrestException catch (e) {
      debugPrint('❌ Failed to check facilities: ${e.message}');
      throw e.toSupabaseException();
    } catch (e) {
      debugPrint('❌ Unexpected error checking facilities: $e');
      throw SupabaseException('Failed to check facilities: ${e.toString()}');
    }
  }

  /// Validate company name uniqueness (optional check)
  Future<bool> isCompanyNameAvailable(String name) async {
    try {
      debugPrint('🔍 Checking company name availability: $name');
      
      final response = await _client
          .from(SupabaseTables.tenants)
          .select('name')
          .ilike('name', name.trim())
          .maybeSingle();

      final isAvailable = response == null;
      debugPrint('✅ Company name availability: $isAvailable');
      
      return isAvailable;
    } on PostgrestException catch (e) {
      debugPrint('❌ Failed to check company name: ${e.message}');
      throw e.toSupabaseException();
    } catch (e) {
      debugPrint('❌ Unexpected error checking company name: $e');
      throw SupabaseException('Failed to check company name: ${e.toString()}');
    }
  }

  /// Complete onboarding by updating user profile
  Future<void> completeOnboarding({
    required String userId,
    required String tenantId,
    required String email,
    required String name,
    String? phone,
  }) async {
    try {
      debugPrint('✅ Completing onboarding for user: $userId');
      
      // This will be handled by auth service - just validate data here
      if (tenantId.isEmpty || email.isEmpty || name.isEmpty) {
        throw const SupabaseException('Missing required profile data');
      }
      
      debugPrint('✅ Onboarding validation completed');
    } catch (e) {
      debugPrint('❌ Onboarding validation failed: $e');
      rethrow;
    }
  }
}