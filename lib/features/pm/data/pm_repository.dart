import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/client.dart';
import '../domain/pm_visit.dart';
import '../domain/pm_checklist.dart';
import '../../contracts/domain/contract.dart';
import '../../contracts/data/contracts_repository.dart';

/// Repository for PM (Preventive Maintenance) related database operations
class PMRepository {
  PMRepository._();

  /// Singleton instance
  static final PMRepository _instance = PMRepository._();
  static PMRepository get instance => _instance;

  /// Supabase client reference
  SupabaseClient get _client => SupabaseService.client;

  /// Generate 90-day PM schedule for a contract
  Future<List<PMVisit>> generateSchedule90d({required String contractId}) async {
    try {
      debugPrint('📅 Generating 90-day PM schedule for contract: $contractId');
      
      // Get contract details
      final contract = await ContractsRepository.instance.getContract(contractId);
      
      final now = DateTime.now();
      final endDate = now.add(const Duration(days: 90));
      
      // Generate visits based on PM frequency
      final visits = <PMVisit>[];
      
      for (final facilityId in contract.facilityIds) {
        final facilityVisits = _generateVisitsForFacility(
          contract: contract,
          facilityId: facilityId,
          startDate: now,
          endDate: endDate,
        );
        visits.addAll(facilityVisits);
      }
      
      // Insert generated visits into database
      if (visits.isNotEmpty) {
        final visitData = visits.map((visit) => visit.toJson()).toList();
        
        await _client
            .from(SupabaseTables.pmVisits)
            .insert(visitData);
      }
      
      debugPrint('✅ Generated ${visits.length} PM visits for 90 days');
      return visits;
      
    } on PostgrestException catch (e) {
      debugPrint('❌ Failed to generate PM schedule: ${e.message}');
      throw e.toSupabaseException();
    } catch (e) {
      debugPrint('❌ Unexpected error generating PM schedule: $e');
      throw SupabaseException('Failed to generate PM schedule: ${e.toString()}');
    }
  }

  /// Generate visits for a specific facility within date range
  List<PMVisit> _generateVisitsForFacility({
    required Contract contract,
    required String facilityId,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final visits = <PMVisit>[];
    final frequency = contract.pmFrequency;
    final intervalMonths = frequency.monthsInterval;
    
    // Find the next scheduled date based on contract start date
    DateTime current = _findNextScheduledDate(
      contractStart: contract.startDate,
      fromDate: startDate,
      intervalMonths: intervalMonths,
    );
    
    // Generate visits until end date
    while (current.isBefore(endDate) || _isSameDay(current, endDate)) {
      final visit = PMVisit(
        tenantId: contract.tenantId,
        contractId: contract.id!,
        facilityId: facilityId,
        scheduledDate: current,
        status: PMVisitStatus.scheduled,
      );
      
      visits.add(visit);
      
      // Move to next scheduled date
      current = DateTime(
        current.year,
        current.month + intervalMonths,
        current.day,
      );
    }
    
    return visits;
  }

  /// Find next scheduled date aligned with contract start date
  DateTime _findNextScheduledDate({
    required DateTime contractStart,
    required DateTime fromDate,
    required int intervalMonths,
  }) {
    DateTime candidate = contractStart;
    
    // Fast-forward to get close to fromDate
    while (candidate.isBefore(fromDate)) {
      candidate = DateTime(
        candidate.year,
        candidate.month + intervalMonths,
        candidate.day,
      );
    }
    
    return candidate;
  }

  /// Check if two dates are the same day
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  /// List upcoming PM visits for tenant
  Future<List<PMVisit>> listUpcomingPM({
    required String tenantId,
    DateTime? until,
  }) async {
    try {
      final cutoffDate = until ?? DateTime.now().add(const Duration(days: 30));
      debugPrint('📋 Fetching upcoming PM visits until: ${cutoffDate.toIso8601String()}');
      
      final response = await _client
          .from(SupabaseTables.pmVisits)
          .select('''
            *,
            contracts!inner(title),
            facilities!inner(name)
          ''')
          .eq('tenant_id', tenantId)
          .lte('scheduled_date', cutoffDate.toIso8601String())
          .gte('scheduled_date', DateTime.now().toIso8601String())
          .inFilter('status', ['scheduled', 'in_progress'])
          .order('scheduled_date', ascending: true);

      final visits = (response as List).map((json) {
        return PMVisit.fromJson(json as Map<String, dynamic>);
      }).toList();

      debugPrint('✅ Fetched ${visits.length} upcoming PM visits');
      return visits;
    } on PostgrestException catch (e) {
      debugPrint('❌ Failed to fetch upcoming PM visits: ${e.message}');
      throw e.toSupabaseException();
    } catch (e) {
      debugPrint('❌ Unexpected error fetching upcoming PM visits: $e');
      throw SupabaseException('Failed to fetch upcoming PM visits: ${e.toString()}');
    }
  }

  /// Complete PM visit with checklist
  Future<PMVisit> completePMVisit({
    required String pmVisitId,
    required PMChecklist checklist,
  }) async {
    try {
      debugPrint('✅ Completing PM visit: $pmVisitId');
      
      // Insert checklist first
      final checklistResponse = await _client
          .from('pm_checklists')
          .insert(checklist.toJson())
          .select()
          .single();
      
      final savedChecklist = PMChecklist.fromJson(checklistResponse);
      
      // Update PM visit status and link checklist
      final visitResponse = await _client
          .from(SupabaseTables.pmVisits)
          .update({
            'status': PMVisitStatus.completed.value,
            'completed_date': DateTime.now().toIso8601String(),
            'checklist_id': savedChecklist.id,
            'engineer_name': checklist.completedBy,
            'notes': checklist.overallNotes,
          })
          .eq('id', pmVisitId)
          .select()
          .single();

      final completedVisit = PMVisit.fromJson(visitResponse);
      
      debugPrint('✅ PM visit completed successfully');
      return completedVisit;
      
    } on PostgrestException catch (e) {
      debugPrint('❌ Failed to complete PM visit: ${e.message}');
      throw e.toSupabaseException();
    } catch (e) {
      debugPrint('❌ Unexpected error completing PM visit: $e');
      throw SupabaseException('Failed to complete PM visit: ${e.toString()}');
    }
  }

  /// Get PM visit by ID
  Future<PMVisit?> getPMVisit(String pmVisitId) async {
    try {
      debugPrint('📄 Fetching PM visit: $pmVisitId');
      
      final response = await _client
          .from(SupabaseTables.pmVisits)
          .select('''
            *,
            contracts!inner(title, service_type),
            facilities!inner(name, address)
          ''')
          .eq('id', pmVisitId)
          .maybeSingle();

      if (response == null) {
        debugPrint('⚠️ No PM visit found with ID: $pmVisitId');
        return null;
      }

      final visit = PMVisit.fromJson(response);
      
      debugPrint('✅ PM visit fetched successfully');
      return visit;
    } on PostgrestException catch (e) {
      debugPrint('❌ Failed to fetch PM visit: ${e.message}');
      throw e.toSupabaseException();
    } catch (e) {
      debugPrint('❌ Unexpected error fetching PM visit: $e');
      throw SupabaseException('Failed to fetch PM visit: ${e.toString()}');
    }
  }

  /// Update PM visit status
  Future<PMVisit> updatePMVisitStatus({
    required String pmVisitId,
    required PMVisitStatus status,
    String? engineerName,
    String? notes,
  }) async {
    try {
      debugPrint('📝 Updating PM visit status: $pmVisitId -> ${status.displayName}');
      
      final updates = <String, dynamic>{
        'status': status.value,
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      if (engineerName != null) {
        updates['engineer_name'] = engineerName;
      }
      
      if (notes != null) {
        updates['notes'] = notes;
      }
      
      if (status == PMVisitStatus.completed && !updates.containsKey('completed_date')) {
        updates['completed_date'] = DateTime.now().toIso8601String();
      }
      
      final response = await _client
          .from(SupabaseTables.pmVisits)
          .update(updates)
          .eq('id', pmVisitId)
          .select()
          .single();

      final updatedVisit = PMVisit.fromJson(response);
      
      debugPrint('✅ PM visit status updated successfully');
      return updatedVisit;
    } on PostgrestException catch (e) {
      debugPrint('❌ Failed to update PM visit status: ${e.message}');
      throw e.toSupabaseException();
    } catch (e) {
      debugPrint('❌ Unexpected error updating PM visit status: $e');
      throw SupabaseException('Failed to update PM visit status: ${e.toString()}');
    }
  }

  /// Get PM visits for a facility
  Future<List<PMVisit>> getPMVisitsForFacility({
    required String facilityId,
    PMVisitStatus? status,
    int limit = 20,
  }) async {
    try {
      debugPrint('📋 Fetching PM visits for facility: $facilityId');
      
      var query = _client
          .from(SupabaseTables.pmVisits)
          .select('''
            *,
            contracts!inner(title, service_type)
          ''')
          .eq('facility_id', facilityId);
      
      if (status != null) {
        query = query.eq('status', status.value);
      }
      
      final response = await query
          .order('scheduled_date', ascending: false)
          .limit(limit);

      final visits = (response as List).map((json) {
        return PMVisit.fromJson(json as Map<String, dynamic>);
      }).toList();

      debugPrint('✅ Fetched ${visits.length} PM visits for facility');
      return visits;
    } on PostgrestException catch (e) {
      debugPrint('❌ Failed to fetch facility PM visits: ${e.message}');
      throw e.toSupabaseException();
    } catch (e) {
      debugPrint('❌ Unexpected error fetching facility PM visits: $e');
      throw SupabaseException('Failed to fetch facility PM visits: ${e.toString()}');
    }
  }

  /// Get PM visits summary for dashboard
  Future<PMVisitSummary> getPMVisitsSummary({required String tenantId}) async {
    try {
      debugPrint('📊 Fetching PM visits summary for tenant: $tenantId');
      
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));
      
      // Get all scheduled/in-progress visits
      final scheduledResponse = await _client
          .from(SupabaseTables.pmVisits)
          .select('id, scheduled_date, status')
          .eq('tenant_id', tenantId)
          .inFilter('status', ['scheduled', 'in_progress']);
      
      final scheduledVisits = scheduledResponse as List;
      
      // Calculate metrics
      int totalScheduled = scheduledVisits.length;
      int dueToday = 0;
      int overdue = 0;
      
      for (final visit in scheduledVisits) {
        final scheduledDate = DateTime.parse(visit['scheduled_date'] as String);
        if (scheduledDate.isBefore(today)) {
          overdue++;
        } else if (scheduledDate.isBefore(tomorrow)) {
          dueToday++;
        }
      }
      
      // Get completed visits count
      final completedResponse = await _client
          .from(SupabaseTables.pmVisits)
          .select('id', const FetchOptions(count: CountOption.exact, head: true))
          .eq('tenant_id', tenantId)
          .eq('status', 'completed');
      
      final completed = completedResponse.count ?? 0;
      
      // Get upcoming visits for display
      final upcomingResponse = await _client
          .from(SupabaseTables.pmVisits)
          .select('''
            *,
            contracts!inner(title),
            facilities!inner(name)
          ''')
          .eq('tenant_id', tenantId)
          .inFilter('status', ['scheduled', 'in_progress'])
          .gte('scheduled_date', today.toIso8601String())
          .order('scheduled_date', ascending: true)
          .limit(5);
      
      final upcomingVisits = (upcomingResponse as List).map((json) {
        return PMVisit.fromJson(json as Map<String, dynamic>);
      }).toList();
      
      final summary = PMVisitSummary(
        totalScheduled: totalScheduled,
        dueToday: dueToday,
        overdue: overdue,
        completed: completed,
        upcomingVisits: upcomingVisits,
      );
      
      debugPrint('✅ PM visits summary calculated: ${summary.totalScheduled} scheduled, ${summary.overdue} overdue');
      return summary;
      
    } on PostgrestException catch (e) {
      debugPrint('❌ Failed to fetch PM visits summary: ${e.message}');
      throw e.toSupabaseException();
    } catch (e) {
      debugPrint('❌ Unexpected error fetching PM visits summary: $e');
      throw SupabaseException('Failed to fetch PM visits summary: ${e.toString()}');
    }
  }

  /// Get checklist for PM visit
  Future<PMChecklist?> getPMChecklist(String pmVisitId) async {
    try {
      debugPrint('📋 Fetching checklist for PM visit: $pmVisitId');
      
      final response = await _client
          .from('pm_checklists')
          .select()
          .eq('pm_visit_id', pmVisitId)
          .maybeSingle();

      if (response == null) {
        debugPrint('⚠️ No checklist found for PM visit: $pmVisitId');
        return null;
      }

      final checklist = PMChecklist.fromJson(response);
      
      debugPrint('✅ PM checklist fetched successfully');
      return checklist;
    } on PostgrestException catch (e) {
      debugPrint('❌ Failed to fetch PM checklist: ${e.message}');
      throw e.toSupabaseException();
    } catch (e) {
      debugPrint('❌ Unexpected error fetching PM checklist: $e');
      throw SupabaseException('Failed to fetch PM checklist: ${e.toString()}');
    }
  }

  /// Upload PM visit attachment
  Future<String> uploadPMAttachment({
    required String tenantId,
    required String pmVisitId,
    required String filename,
    required List<int> bytes,
  }) async {
    try {
      debugPrint('📤 Uploading PM visit attachment: $filename');
      
      // Generate storage path: pm/{tenant_id}/{pm_visit_id}/{filename}
      final storagePath = 'pm/$tenantId/$pmVisitId/$filename';
      
      // Upload file to Supabase Storage
      await _client.storage
          .from(SupabaseBuckets.attachments)
          .uploadBinary(storagePath, bytes);
      
      debugPrint('✅ PM attachment uploaded: $storagePath');
      return storagePath;
      
    } on StorageException catch (e) {
      debugPrint('❌ Failed to upload PM attachment: ${e.message}');
      throw SupabaseException('Failed to upload attachment: ${e.message}');
    } catch (e) {
      debugPrint('❌ Unexpected error uploading PM attachment: $e');
      throw SupabaseException('Failed to upload PM attachment: ${e.toString()}');
    }
  }

  /// Delete PM visit (soft delete by setting status to cancelled) 
  Future<void> cancelPMVisit(String pmVisitId) async {
    try {
      debugPrint('❌ Cancelling PM visit: $pmVisitId');
      
      await _client
          .from(SupabaseTables.pmVisits)
          .update({
            'status': PMVisitStatus.cancelled.value,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', pmVisitId);
      
      debugPrint('✅ PM visit cancelled successfully');
    } on PostgrestException catch (e) {
      debugPrint('❌ Failed to cancel PM visit: ${e.message}');
      throw e.toSupabaseException();
    } catch (e) {
      debugPrint('❌ Unexpected error cancelling PM visit: $e');
      throw SupabaseException('Failed to cancel PM visit: ${e.toString()}');
    }
  }
}