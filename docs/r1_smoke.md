# Round 1 Smoke Test Checklist - Schema + RLS

## Overview
This checklist validates the successful deployment and basic functionality of the database schema, RLS policies, and seed data for CUERON SAAN Round 1.

## Pre-Test Requirements
- [ ] Supabase project created and accessible
- [ ] All migration files applied successfully
- [ ] Seed data script executed without errors
- [ ] Storage bucket 'attachments' created
- [ ] Test user accounts created in Supabase Auth

## Test Environment Setup

### Supabase Project Verification
- [ ] Project URL accessible: `https://your-project.supabase.co`
- [ ] Database shows all tables created (10 tables + junction tables)
- [ ] All enums created and visible in database schema
- [ ] Storage bucket 'attachments' exists with correct policies

### Test Data Verification
```sql
-- Verify seed data loaded correctly
SELECT COUNT(*) FROM tenants; -- Should be 2
SELECT COUNT(*) FROM profiles; -- Should be 4  
SELECT COUNT(*) FROM facilities; -- Should be 4
SELECT COUNT(*) FROM contracts; -- Should be 3
SELECT COUNT(*) FROM requests; -- Should be 3
```
- [ ] ✅ Tenants: 2 records (Acme Manufacturing, Beta Pharma)
- [ ] ✅ Profiles: 4 records (2 per tenant, different roles)
- [ ] ✅ Facilities: 4 records (2 per tenant)
- [ ] ✅ Contracts: 3 records (2 Acme, 1 Beta)
- [ ] ✅ Requests: 3 records with different priorities/statuses

## Schema Validation Tests

### Table Structure
- [ ] All tables have correct primary keys (UUID type)
- [ ] All foreign key constraints created and functional
- [ ] All enum columns use correct enum types
- [ ] Timestamp columns have proper defaults (now())
- [ ] JSON columns (media_urls, checklist, metadata) accept valid JSON

### Index Performance
```sql
-- Test key indexes exist
\di -- List all indexes
-- Verify tenant-scoped indexes for performance
EXPLAIN SELECT * FROM requests WHERE tenant_id = 'some-uuid' AND status = 'new';
```
- [ ] ✅ Primary key indexes on all tables
- [ ] ✅ Tenant isolation indexes present
- [ ] ✅ Status-based indexes for filtering
- [ ] ✅ Query plans show index usage for tenant-scoped queries

### Data Constraints
```sql
-- Test check constraints
INSERT INTO contracts (tenant_id, type, term_months, price_paisa, billing_cycle, start_at, end_at)
VALUES ('test-tenant', 'amc', -1, 1000, 'monthly', '2025-01-01', '2024-01-01'); -- Should fail
```
- [ ] ✅ Negative term_months rejected
- [ ] ✅ End date before start date rejected  
- [ ] ✅ Negative price amounts rejected
- [ ] ✅ Invalid enum values rejected

## RLS Policy Tests

### Basic Tenant Isolation
**Test with two different authenticated users:**

User A (Acme admin: admin@acme.com):
```sql
-- Should see only Acme data
SELECT COUNT(*) FROM facilities; -- Should be 2 (Acme facilities only)
SELECT COUNT(*) FROM requests;   -- Should be 2 (Acme requests only)
SELECT COUNT(*) FROM contracts;  -- Should be 2 (Acme contracts only)
```
- [ ] ✅ Sees only own tenant's facilities
- [ ] ✅ Sees only own tenant's requests  
- [ ] ✅ Sees only own tenant's contracts

User B (Beta admin: admin@beta.com):
```sql
-- Should see only Beta data
SELECT COUNT(*) FROM facilities; -- Should be 2 (Beta facilities only)
SELECT COUNT(*) FROM requests;   -- Should be 1 (Beta requests only)
SELECT COUNT(*) FROM contracts;  -- Should be 1 (Beta contracts only)
```
- [ ] ✅ Sees only own tenant's facilities
- [ ] ✅ Sees only own tenant's requests
- [ ] ✅ Sees only own tenant's contracts

### Role-Based Access
**Admin vs Requester capabilities:**

Admin user test:
```sql
-- Should succeed
UPDATE facilities SET name = 'Updated Name' WHERE id = 'facility-id';
INSERT INTO contracts (...) VALUES (...);
```
- [ ] ✅ Admin can update facilities
- [ ] ✅ Admin can create/manage contracts
- [ ] ✅ Admin can manage invoices

Requester user test:
```sql
-- Should fail
UPDATE facilities SET name = 'Hacked' WHERE id = 'facility-id';
INSERT INTO contracts (...) VALUES (...);
```
- [ ] ✅ Requester cannot update facilities
- [ ] ✅ Requester cannot manage contracts
- [ ] ✅ Requester can create requests
- [ ] ✅ Requester can view invoices but not modify

## Function Tests

### Helper Functions
```sql
-- Test as authenticated user
SELECT get_user_tenant_id(); -- Should return user's tenant_id
SELECT get_user_role();      -- Should return user's role
```
- [ ] ✅ `get_user_tenant_id()` returns correct tenant for each user
- [ ] ✅ `get_user_role()` returns correct role for each user
- [ ] ✅ Functions return NULL for unauthenticated context

### Trigger Functions
```sql
-- Create critical request, verify SLA is set
INSERT INTO requests (tenant_id, facility_id, type, priority, description)
VALUES ('tenant-id', 'facility-id', 'on_demand', 'critical', 'Test SLA trigger');

SELECT sla_due_at, created_at FROM requests WHERE description = 'Test SLA trigger';
-- sla_due_at should be created_at + 6 hours
```
- [ ] ✅ Critical requests get automatic SLA (created_at + 6 hours)
- [ ] ✅ Standard requests don't get automatic SLA (sla_due_at remains NULL)
- [ ] ✅ Audit logs created for request insertion

## Storage Bucket Tests

### Bucket Configuration
- [ ] ✅ 'attachments' bucket exists
- [ ] ✅ Bucket is private (public = false)
- [ ] ✅ File size limit set to 10MB
- [ ] ✅ MIME type restrictions in place

### Storage Policies
**Test with authenticated user:**
```sql
-- Check if user can see storage policies
SELECT * FROM storage.objects WHERE bucket_id = 'attachments';
```

**Manual test via Supabase Storage UI:**
- [ ] ✅ Can upload file to path: `{tenant_id}/requests/{request_id}/photo.jpg`
- [ ] ✅ Cannot upload file to other tenant's path
- [ ] ✅ Can download own tenant's files
- [ ] ✅ Cannot access other tenant's files

## Error Handling Tests

### Invalid Data Scenarios
```sql
-- Test various constraint violations
INSERT INTO requests (tenant_id, facility_id, type, priority, description)
VALUES ('nonexistent-tenant', 'facility-id', 'invalid_type', 'critical', 'Test');
```
- [ ] ✅ Foreign key violations handled gracefully
- [ ] ✅ Invalid enum values rejected with clear error
- [ ] ✅ Required fields enforced (NOT NULL constraints)
- [ ] ✅ Check constraints prevent invalid data

### RLS Violation Scenarios
```sql
-- Attempt cross-tenant data access
UPDATE requests SET description = 'Hacked' WHERE tenant_id = 'other-tenant-id';
```
- [ ] ✅ Cross-tenant updates blocked
- [ ] ✅ Cross-tenant inserts blocked  
- [ ] ✅ Cross-tenant deletes blocked
- [ ] ✅ Appropriate error messages returned

## Performance Validation

### Query Performance
```sql
-- Test common query patterns with EXPLAIN
EXPLAIN ANALYZE SELECT * FROM requests 
WHERE tenant_id = 'tenant-uuid' AND status = 'new'
ORDER BY created_at DESC LIMIT 10;
```
- [ ] ✅ Tenant-scoped queries use appropriate indexes
- [ ] ✅ Status filtering shows index usage
- [ ] ✅ Sorting by created_at performs well
- [ ] ✅ No full table scans on large result sets

### Concurrent Access
- [ ] Multiple users can query simultaneously without conflicts
- [ ] RLS policies don't create deadlocks
- [ ] Audit log generation doesn't impact performance significantly

## Documentation Verification

### ERD Accuracy
- [ ] ✅ ERD matches actual database schema
- [ ] ✅ All relationships documented correctly
- [ ] ✅ Constraints and indexes noted
- [ ] ✅ Business rules reflected in schema

### RLS Documentation
- [ ] ✅ All policies documented in RLS checklist
- [ ] ✅ Test scenarios cover all access patterns
- [ ] ✅ Role-based permissions clearly defined

## Rollback Plan

If any critical issues found:
- [ ] Have migration rollback scripts ready
- [ ] Can restore from clean Supabase project
- [ ] Seed data can be re-applied cleanly
- [ ] Storage bucket can be recreated

## Sign-off Criteria

**All tests must pass before proceeding to Round 2:**
- [ ] ✅ Schema created without errors
- [ ] ✅ All RLS policies enforce tenant isolation
- [ ] ✅ Role-based access working correctly
- [ ] ✅ Storage bucket policies secure
- [ ] ✅ Helper functions return correct values
- [ ] ✅ Triggers create audit trails and SLAs
- [ ] ✅ Performance acceptable for expected load
- [ ] ✅ Error handling graceful and informative
- [ ] ✅ Documentation complete and accurate

## Next Steps (Round 2)
Once all tests pass:
- Share Supabase project credentials for Flutter app setup
- Begin Flutter app shell with authentication
- Implement repository pattern for data access
- Set up navigation structure and Material 3 theming