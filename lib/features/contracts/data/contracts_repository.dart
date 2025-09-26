import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/client.dart';
import '../domain/contract.dart';

/// Repository for contract-related database operations
class ContractsRepository {
  ContractsRepository._();

  /// Singleton instance
  static final ContractsRepository _instance = ContractsRepository._();
  static ContractsRepository get instance => _instance;

  /// Supabase client reference
  SupabaseClient get _client => SupabaseService.client;

  /// Create contract in database
  Future<Contract> createContract(Contract input) async {
    try {
      debugPrint('📝 Creating contract: ${input.title}');
      
      final contractData = input.toJson();
      
      final response = await _client
          .from(SupabaseTables.contracts)
          .insert(contractData)
          .select()
          .single();

      final createdContract = Contract.fromJson(response);
      
      debugPrint('✅ Contract created with ID: ${createdContract.id}');
      return createdContract;
    } on PostgrestException catch (e) {
      debugPrint('❌ Failed to create contract: ${e.message}');
      throw e.toSupabaseException();
    } catch (e) {
      debugPrint('❌ Unexpected error creating contract: $e');
      throw SupabaseException('Failed to create contract: ${e.toString()}');
    }
  }

  /// Get single contract by ID
  Future<Contract> getContract(String contractId) async {
    try {
      debugPrint('📄 Fetching contract: $contractId');
      
      final response = await _client
          .from(SupabaseTables.contracts)
          .select()
          .eq('id', contractId)
          .single();

      final contract = Contract.fromJson(response);
      
      debugPrint('✅ Contract fetched successfully: ${contract.title}');
      return contract;
    } on PostgrestException catch (e) {
      debugPrint('❌ Failed to fetch contract: ${e.message}');
      throw e.toSupabaseException();
    } catch (e) {
      debugPrint('❌ Unexpected error fetching contract: $e');
      throw SupabaseException('Failed to fetch contract: ${e.toString()}');
    }
  }

  /// List all contracts for a tenant
  Future<List<Contract>> listContracts({required String tenantId}) async {
    try {
      debugPrint('📋 Fetching contracts for tenant: $tenantId');
      
      final response = await _client
          .from(SupabaseTables.contracts)
          .select()
          .eq('tenant_id', tenantId)
          .order('created_at', ascending: false);

      final contracts = (response as List).map((json) {
        return Contract.fromJson(json as Map<String, dynamic>);
      }).toList();

      debugPrint('✅ Fetched ${contracts.length} contracts');
      return contracts;
    } on PostgrestException catch (e) {
      debugPrint('❌ Failed to fetch contracts: ${e.message}');
      throw e.toSupabaseException();
    } catch (e) {
      debugPrint('❌ Unexpected error fetching contracts: $e');
      throw SupabaseException('Failed to fetch contracts: ${e.toString()}');
    }
  }

  /// Map facilities to a contract
  Future<void> mapFacilities({
    required String contractId,
    required List<String> facilityIds,
  }) async {
    try {
      debugPrint('🔗 Mapping ${facilityIds.length} facilities to contract: $contractId');
      
      // First, remove existing mappings for this contract
      await _client
          .from(SupabaseTables.contractFacilities)
          .delete()
          .eq('contract_id', contractId);
      
      // Then, insert new mappings
      if (facilityIds.isNotEmpty) {
        final mappings = facilityIds.map((facilityId) => {
          'contract_id': contractId,
          'facility_id': facilityId,
        }).toList();
        
        await _client
            .from(SupabaseTables.contractFacilities)
            .insert(mappings);
      }
      
      // Update the contract's facility_ids array for easy access
      await _client
          .from(SupabaseTables.contracts)
          .update({'facility_ids': facilityIds})
          .eq('id', contractId);
      
      debugPrint('✅ Contract facilities mapped successfully');
    } on PostgrestException catch (e) {
      debugPrint('❌ Failed to map contract facilities: ${e.message}');
      throw e.toSupabaseException();
    } catch (e) {
      debugPrint('❌ Unexpected error mapping contract facilities: $e');
      throw SupabaseException('Failed to map contract facilities: ${e.toString()}');
    }
  }

  /// Upload contract document
  Future<Uri> uploadContractDoc({
    required String contractId,
    required String filename,
    required List<int> bytes,
  }) async {
    try {
      debugPrint('📤 Uploading contract document: $filename');
      
      // Get contract to determine tenant_id for storage path
      final contract = await getContract(contractId);
      
      // Generate storage path: contracts/{tenant_id}/{contract_id}/docs/{filename}
      final storagePath = 'contracts/${contract.tenantId}/$contractId/docs/$filename';
      
      // Upload file to Supabase Storage
      await _client.storage
          .from(SupabaseBuckets.attachments)
          .uploadBinary(storagePath, bytes);
      
      // Update contract document_paths
      final updatedPaths = [...contract.documentPaths, storagePath];
      await _client
          .from(SupabaseTables.contracts)
          .update({'document_paths': updatedPaths})
          .eq('id', contractId);
      
      // Return the storage path as URI
      final uri = Uri.parse(storagePath);
      debugPrint('✅ Contract document uploaded: $storagePath');
      return uri;
      
    } on StorageException catch (e) {
      debugPrint('❌ Failed to upload contract document: ${e.message}');
      throw SupabaseException('Failed to upload document: ${e.message}');
    } on PostgrestException catch (e) {
      debugPrint('❌ Failed to update contract: ${e.message}');
      throw e.toSupabaseException();
    } catch (e) {
      debugPrint('❌ Unexpected error uploading contract document: $e');
      throw SupabaseException('Failed to upload contract document: ${e.toString()}');
    }
  }

  /// Get active contracts for a facility
  Future<List<Contract>> activeContractsForFacility({
    required String facilityId,
    DateTime? asOf,
  }) async {
    try {
      final effectiveDate = asOf ?? DateTime.now();
      debugPrint('🔍 Finding active contracts for facility: $facilityId at ${effectiveDate.toIso8601String()}');
      
      final response = await _client
          .from(SupabaseTables.contracts)
          .select()
          .contains('facility_ids', [facilityId])
          .eq('is_active', true)
          .lte('start_date', effectiveDate.toIso8601String())
          .gte('end_date', effectiveDate.toIso8601String())
          .order('precedence', ascending: false)
          .order('start_date', ascending: false)
          .order('id', ascending: true);

      final contracts = (response as List).map((json) {
        return Contract.fromJson(json as Map<String, dynamic>);
      }).toList();

      debugPrint('✅ Found ${contracts.length} active contracts for facility');
      return contracts;
    } on PostgrestException catch (e) {
      debugPrint('❌ Failed to fetch active contracts: ${e.message}');
      throw e.toSupabaseException();
    } catch (e) {
      debugPrint('❌ Unexpected error fetching active contracts: $e');
      throw SupabaseException('Failed to fetch active contracts: ${e.toString()}');
    }
  }

  /// Update contract
  Future<Contract> updateContract({
    required String contractId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      debugPrint('📝 Updating contract: $contractId');
      
      final response = await _client
          .from(SupabaseTables.contracts)
          .update(updates)
          .eq('id', contractId)
          .select()
          .single();

      final updatedContract = Contract.fromJson(response);
      
      debugPrint('✅ Contract updated successfully');
      return updatedContract;
    } on PostgrestException catch (e) {
      debugPrint('❌ Failed to update contract: ${e.message}');
      throw e.toSupabaseException();
    } catch (e) {
      debugPrint('❌ Unexpected error updating contract: $e');
      throw SupabaseException('Failed to update contract: ${e.toString()}');
    }
  }

  /// Delete contract (soft delete by setting is_active = false)
  Future<void> deleteContract(String contractId) async {
    try {
      debugPrint('🗑️ Soft deleting contract: $contractId');
      
      await _client
          .from(SupabaseTables.contracts)
          .update({'is_active': false})
          .eq('id', contractId);
      
      debugPrint('✅ Contract soft deleted successfully');
    } on PostgrestException catch (e) {
      debugPrint('❌ Failed to delete contract: ${e.message}');
      throw e.toSupabaseException();
    } catch (e) {
      debugPrint('❌ Unexpected error deleting contract: $e');
      throw SupabaseException('Failed to delete contract: ${e.toString()}');
    }
  }

  /// Get contract with facility details
  Future<ContractWithFacilities> getContractWithFacilities(String contractId) async {
    try {
      debugPrint('📄 Fetching contract with facilities: $contractId');
      
      final response = await _client
          .from(SupabaseTables.contracts)
          .select('''
            *,
            contract_facilities!inner(
              facility_id,
              facilities!inner(
                id,
                name,
                address
              )
            )
          ''')
          .eq('id', contractId)
          .single();

      final contract = Contract.fromJson(response);
      
      // Extract facility details
      final facilityMappings = response['contract_facilities'] as List;
      final facilities = facilityMappings.map((mapping) {
        final facilityData = mapping['facilities'] as Map<String, dynamic>;
        return ContractFacilityInfo(
          id: facilityData['id'] as String,
          name: facilityData['name'] as String,
          address: facilityData['address'] as String?,
        );
      }).toList();
      
      debugPrint('✅ Contract with ${facilities.length} facilities fetched');
      return ContractWithFacilities(
        contract: contract,
        facilities: facilities,
      );
    } on PostgrestException catch (e) {
      debugPrint('❌ Failed to fetch contract with facilities: ${e.message}');
      throw e.toSupabaseException();
    } catch (e) {
      debugPrint('❌ Unexpected error fetching contract with facilities: $e');
      throw SupabaseException('Failed to fetch contract with facilities: ${e.toString()}');
    }
  }

  /// Get contracts expiring soon (within next 30 days)
  Future<List<Contract>> getExpiringContracts({
    required String tenantId,
    int daysAhead = 30,
  }) async {
    try {
      final cutoffDate = DateTime.now().add(Duration(days: daysAhead));
      debugPrint('🔔 Finding contracts expiring before: ${cutoffDate.toIso8601String()}');
      
      final response = await _client
          .from(SupabaseTables.contracts)
          .select()
          .eq('tenant_id', tenantId)
          .eq('is_active', true)
          .lte('end_date', cutoffDate.toIso8601String())
          .gte('end_date', DateTime.now().toIso8601String())
          .order('end_date', ascending: true);

      final contracts = (response as List).map((json) {
        return Contract.fromJson(json as Map<String, dynamic>);
      }).toList();

      debugPrint('✅ Found ${contracts.length} contracts expiring within $daysAhead days');
      return contracts;
    } on PostgrestException catch (e) {
      debugPrint('❌ Failed to fetch expiring contracts: ${e.message}');
      throw e.toSupabaseException();
    } catch (e) {
      debugPrint('❌ Unexpected error fetching expiring contracts: $e');
      throw SupabaseException('Failed to fetch expiring contracts: ${e.toString()}');
    }
  }
}

/// Contract with facility details model
class ContractWithFacilities {
  const ContractWithFacilities({
    required this.contract,
    required this.facilities,
  });

  final Contract contract;
  final List<ContractFacilityInfo> facilities;
}

/// Contract facility info model
class ContractFacilityInfo {
  const ContractFacilityInfo({
    required this.id,
    required this.name,
    required this.address,
  });

  final String id;
  final String name;
  final String? address;
}