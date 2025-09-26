import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/client.dart';
import '../domain/models/request.dart';

/// Repository for request-related database operations
class RequestsRepository {
  RequestsRepository._();

  /// Singleton instance
  static final RequestsRepository _instance = RequestsRepository._();
  static RequestsRepository get instance => _instance;

  /// Supabase client reference
  SupabaseClient get _client => SupabaseService.client;

  /// Create request in database
  Future<ServiceRequest> createRequest({
    required String tenantId,
    required ServiceRequest request,
  }) async {
    try {
      debugPrint('📝 Creating request: ${request.description}');
      
      final requestData = request.toJson()
        ..['tenant_id'] = tenantId;
      
      // Calculate SLA due date for critical requests
      if (request.priority.hasSla) {
        final createdAt = DateTime.now();
        final slaDueAt = SlaUtils.calculateSlaDue(request.priority, createdAt);
        requestData['sla_due_at'] = slaDueAt?.toIso8601String();
        requestData['created_at'] = createdAt.toIso8601String();
      }
      
      final response = await _client
          .from(SupabaseTables.requests)
          .insert(requestData)
          .select('''
            *,
            facilities!inner(name)
          ''')
          .single();

      final createdRequest = ServiceRequest.fromJson(response)
          .copyWith(facilityName: response['facilities']['name'] as String?);
      
      debugPrint('✅ Request created with ID: ${createdRequest.id}');
      return createdRequest;
    } on PostgrestException catch (e) {
      debugPrint('❌ Failed to create request: ${e.message}');
      throw e.toSupabaseException();
    } catch (e) {
      debugPrint('❌ Unexpected error creating request: $e');
      throw SupabaseException('Failed to create request: ${e.toString()}');
    }
  }

  /// Get paginated requests with filters
  Future<PaginatedRequests> getRequests({
    required String tenantId,
    RequestFilters filters = const RequestFilters(),
    int page = 1,
    int pageSize = 20,
    String orderBy = 'created_at',
    bool ascending = false,
  }) async {
    try {
      debugPrint('📋 Fetching requests for tenant: $tenantId (page: $page)');
      
      // Build base query with JOIN to get facility names
      var query = _client
          .from(SupabaseTables.requests)
          .select('''
            *,
            facilities!inner(name)
          ''', const FetchOptions(count: CountOption.exact))
          .eq('tenant_id', tenantId);

      // Apply filters
      query = _applyFilters(query, filters);
      
      // Apply ordering
      query = query.order(orderBy, ascending: ascending);
      
      // Apply pagination
      final offset = (page - 1) * pageSize;
      query = query.range(offset, offset + pageSize - 1);

      final response = await query;
      final data = response.data as List;
      final total = response.count ?? 0;

      final requests = data.map((json) {
        return ServiceRequest.fromJson(json as Map<String, dynamic>)
            .copyWith(facilityName: json['facilities']['name'] as String?);
      }).toList();

      debugPrint('✅ Fetched ${requests.length} requests (total: $total)');
      
      return PaginatedRequests(
        requests: requests,
        total: total,
        page: page,
        pageSize: pageSize,
        hasMore: offset + requests.length < total,
      );
    } on PostgrestException catch (e) {
      debugPrint('❌ Failed to fetch requests: ${e.message}');
      throw e.toSupabaseException();
    } catch (e) {
      debugPrint('❌ Unexpected error fetching requests: $e');
      throw SupabaseException('Failed to fetch requests: ${e.toString()}');
    }
  }

  /// Apply filters to query
  PostgrestFilterBuilder _applyFilters(
    PostgrestFilterBuilder query,
    RequestFilters filters,
  ) {
    // Status filter
    if (filters.statuses.isNotEmpty) {
      final statusValues = filters.statuses.map((s) => s.value).toList();
      query = query.inFilter('status', statusValues);
    }

    // Facility filter
    if (filters.facilities.isNotEmpty) {
      query = query.inFilter('facility_id', filters.facilities);
    }

    // Priority filter
    if (filters.priorities.isNotEmpty) {
      final priorityValues = filters.priorities.map((p) => p.value).toList();
      query = query.inFilter('priority', priorityValues);
    }

    // Search filter (description and facility name)
    if (filters.searchQuery != null && filters.searchQuery!.trim().isNotEmpty) {
      final searchTerm = filters.searchQuery!.trim();
      // Use OR condition to search both description and facility name
      query = query.or('description.ilike.%$searchTerm%,facilities.name.ilike.%$searchTerm%');
    }

    return query;
  }

  /// Get single request by ID
  Future<ServiceRequest?> getRequest(String requestId, String tenantId) async {
    try {
      debugPrint('📄 Fetching request: $requestId');
      
      final response = await _client
          .from(SupabaseTables.requests)
          .select('''
            *,
            facilities!inner(name, address, poc_name, poc_phone)
          ''')
          .eq('id', requestId)
          .eq('tenant_id', tenantId)
          .maybeSingle();

      if (response == null) {
        debugPrint('⚠️ No request found with ID: $requestId');
        return null;
      }

      final request = ServiceRequest.fromJson(response)
          .copyWith(facilityName: response['facilities']['name'] as String?);
      
      debugPrint('✅ Request fetched successfully: ${request.description}');
      return request;
    } on PostgrestException catch (e) {
      debugPrint('❌ Failed to fetch request: ${e.message}');
      throw e.toSupabaseException();
    } catch (e) {
      debugPrint('❌ Unexpected error fetching request: $e');
      throw SupabaseException('Failed to fetch request: ${e.toString()}');
    }
  }

  /// Update request status and related fields
  Future<ServiceRequest> updateRequest({
    required String requestId,
    required String tenantId,
    RequestStatus? status,
    String? assignedEngineerName,
    DateTime? eta,
  }) async {
    try {
      debugPrint('📝 Updating request: $requestId');
      
      final updates = <String, dynamic>{};
      
      if (status != null) {
        updates['status'] = status.value;
      }
      
      if (assignedEngineerName != null) {
        updates['assigned_engineer_name'] = assignedEngineerName;
      }
      
      if (eta != null) {
        updates['eta'] = eta.toIso8601String();
      }

      if (updates.isEmpty) {
        throw const SupabaseException('No updates provided');
      }

      final response = await _client
          .from(SupabaseTables.requests)
          .update(updates)
          .eq('id', requestId)
          .eq('tenant_id', tenantId)
          .select('''
            *,
            facilities!inner(name)
          ''')
          .single();

      final updatedRequest = ServiceRequest.fromJson(response)
          .copyWith(facilityName: response['facilities']['name'] as String?);
      
      debugPrint('✅ Request updated successfully');
      return updatedRequest;
    } on PostgrestException catch (e) {
      debugPrint('❌ Failed to update request: ${e.message}');
      throw e.toSupabaseException();
    } catch (e) {
      debugPrint('❌ Unexpected error updating request: $e');
      throw SupabaseException('Failed to update request: ${e.toString()}');
    }
  }

  /// Update request media URLs after file upload
  Future<ServiceRequest> updateRequestMedia({
    required String requestId,
    required String tenantId,
    required List<String> mediaUrls,
  }) async {
    try {
      debugPrint('📝 Updating request media: $requestId');
      
      final response = await _client
          .from(SupabaseTables.requests)
          .update({'media_urls': mediaUrls})
          .eq('id', requestId)
          .eq('tenant_id', tenantId)
          .select('''
            *,
            facilities!inner(name)
          ''')
          .single();

      final updatedRequest = ServiceRequest.fromJson(response)
          .copyWith(facilityName: response['facilities']['name'] as String?);
      
      debugPrint('✅ Request media updated successfully');
      return updatedRequest;
    } on PostgrestException catch (e) {
      debugPrint('❌ Failed to update request media: ${e.message}');
      throw e.toSupabaseException();
    } catch (e) {
      debugPrint('❌ Unexpected error updating request media: $e');
      throw SupabaseException('Failed to update request media: ${e.toString()}');
    }
  }

  /// Get KPI data for dashboard
  Future<RequestKPIs> getKPIs(String tenantId) async {
    try {
      debugPrint('📊 Fetching KPIs for tenant: $tenantId');
      
      final now = DateTime.now();
      final sevenDaysAgo = now.subtract(const Duration(days: 7));
      
      // Get open requests count
      final openResponse = await _client
          .from(SupabaseTables.requests)
          .select('id', const FetchOptions(count: CountOption.exact, head: true))
          .eq('tenant_id', tenantId)
          .inFilter('status', ['new', 'triaged', 'assigned', 'en_route', 'on_site']);
      
      final openCount = openResponse.count ?? 0;

      // Get overdue requests count (critical requests with SLA breach)
      final overdueResponse = await _client
          .from(SupabaseTables.requests)
          .select('id', const FetchOptions(count: CountOption.exact, head: true))
          .eq('tenant_id', tenantId)
          .eq('priority', 'critical')
          .lt('sla_due_at', now.toIso8601String())
          .inFilter('status', ['new', 'triaged', 'assigned', 'en_route', 'on_site']);
      
      final overdueCount = overdueResponse.count ?? 0;

      // Get due today requests count
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));
      
      final dueTodayResponse = await _client
          .from(SupabaseTables.requests)
          .select('id', const FetchOptions(count: CountOption.exact, head: true))
          .eq('tenant_id', tenantId)
          .gte('sla_due_at', today.toIso8601String())
          .lt('sla_due_at', tomorrow.toIso8601String())
          .inFilter('status', ['new', 'triaged', 'assigned', 'en_route', 'on_site']);
      
      final dueTodayCount = dueTodayResponse.count ?? 0;

      // Get completed requests in last 7 days for TTR calculation
      final completedResponse = await _client
          .from(SupabaseTables.requests)
          .select('created_at, updated_at')
          .eq('tenant_id', tenantId)
          .eq('status', 'completed')
          .gte('updated_at', sevenDaysAgo.toIso8601String());

      // Calculate average TTR (Time to Resolution)
      double avgTtrHours = 0.0;
      if (completedResponse.isNotEmpty) {
        double totalHours = 0.0;
        int validCount = 0;
        
        for (final record in completedResponse) {
          final createdAt = DateTime.parse(record['created_at'] as String);
          final completedAt = DateTime.parse(record['updated_at'] as String);
          final ttrHours = completedAt.difference(createdAt).inHours;
          
          if (ttrHours > 0) {
            totalHours += ttrHours;
            validCount++;
          }
        }
        
        if (validCount > 0) {
          avgTtrHours = totalHours / validCount;
        }
      }

      final kpis = RequestKPIs(
        openRequests: openCount,
        overdueRequests: overdueCount,
        dueTodayRequests: dueTodayCount,
        avgTtrHours: avgTtrHours,
      );
      
      debugPrint('✅ KPIs fetched successfully: $kpis');
      return kpis;
    } on PostgrestException catch (e) {
      debugPrint('❌ Failed to fetch KPIs: ${e.message}');
      throw e.toSupabaseException();
    } catch (e) {
      debugPrint('❌ Unexpected error fetching KPIs: $e');
      throw SupabaseException('Failed to fetch KPIs: ${e.toString()}');
    }
  }

  /// Get recent requests for dashboard
  Future<List<ServiceRequest>> getRecentRequests({
    required String tenantId,
    int limit = 5,
  }) async {
    try {
      debugPrint('📋 Fetching recent requests for tenant: $tenantId');
      
      final response = await _client
          .from(SupabaseTables.requests)
          .select('''
            *,
            facilities!inner(name)
          ''')
          .eq('tenant_id', tenantId)
          .order('created_at', ascending: false)
          .limit(limit);

      final requests = (response as List).map((json) {
        return ServiceRequest.fromJson(json as Map<String, dynamic>)
            .copyWith(facilityName: json['facilities']['name'] as String?);
      }).toList();

      debugPrint('✅ Fetched ${requests.length} recent requests');
      return requests;
    } on PostgrestException catch (e) {
      debugPrint('❌ Failed to fetch recent requests: ${e.message}');
      throw e.toSupabaseException();
    } catch (e) {
      debugPrint('❌ Unexpected error fetching recent requests: $e');
      throw SupabaseException('Failed to fetch recent requests: ${e.toString()}');
    }
  }

  /// Get available assignees (admin users) for the tenant
  Future<List<UserProfile>> getAvailableAssignees(String tenantId) async {
    try {
      debugPrint('👥 Fetching available assignees for tenant: $tenantId');
      
      final response = await _client
          .from(SupabaseTables.profiles)
          .select('*')
          .eq('tenant_id', tenantId)
          .eq('role', 'admin')
          .order('name', ascending: true);

      final assignees = (response as List).map((json) {
        return UserProfile.fromJson(json as Map<String, dynamic>);
      }).toList();

      debugPrint('✅ Fetched ${assignees.length} available assignees');
      return assignees;
    } on PostgrestException catch (e) {
      debugPrint('❌ Failed to fetch assignees: ${e.message}');
      throw e.toSupabaseException();
    } catch (e) {
      debugPrint('❌ Unexpected error fetching assignees: $e');
      throw SupabaseException('Failed to fetch assignees: ${e.toString()}');
    }
  }
}

/// KPI data model
class RequestKPIs extends Equatable {
  const RequestKPIs({
    required this.openRequests,
    required this.overdueRequests,
    required this.dueTodayRequests,
    required this.avgTtrHours,
  });

  final int openRequests;
  final int overdueRequests;
  final int dueTodayRequests;
  final double avgTtrHours;

  @override
  List<Object?> get props => [
        openRequests,
        overdueRequests,
        dueTodayRequests,
        avgTtrHours,
      ];

  @override
  String toString() => 'RequestKPIs(open: $openRequests, overdue: $overdueRequests, '
      'dueToday: $dueTodayRequests, avgTTR: ${avgTtrHours.toStringAsFixed(1)}h)';
}