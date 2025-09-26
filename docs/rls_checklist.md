# RLS Security Checklist - CUERON SAAN

## Overview
This checklist validates that Row Level Security (RLS) policies correctly implement multi-tenant isolation and role-based access control for the CUERON SAAN platform.

## Pre-Test Setup
- [ ] Two test tenants created (Acme Manufacturing, Beta Pharma)
- [ ] Four test users with different roles created in auth.users
- [ ] Profiles linked to correct tenants with appropriate roles
- [ ] Sample data seeded for both tenants

## Test Users
| User | Email | Tenant | Role | Purpose |
|------|-------|--------|------|---------|
| User A | admin@acme.com | Acme | admin | Full access to Acme data |
| User B | manager@acme.com | Acme | requester | Limited access to Acme data |
| User C | admin@beta.com | Beta | admin | Full access to Beta data |
| User D | user@beta.com | Beta | requester | Limited access to Beta data |

## RLS Test Scenarios

### 1. Tenant Isolation Tests

#### 1.1 Cross-Tenant Data Visibility
**Test**: Login as User A (Acme admin), attempt to view Beta Pharma data
```sql
-- Should return 0 rows (Acme user cannot see Beta data)
SELECT COUNT(*) FROM facilities WHERE tenant_id = 'beta-tenant-id';
SELECT COUNT(*) FROM requests WHERE tenant_id = 'beta-tenant-id';
SELECT COUNT(*) FROM contracts WHERE tenant_id = 'beta-tenant-id';
```
- [ ] ✅ Facilities: 0 rows returned
- [ ] ✅ Requests: 0 rows returned  
- [ ] ✅ Contracts: 0 rows returned

#### 1.2 Own Tenant Data Visibility
**Test**: Login as User A (Acme admin), view Acme data
```sql
-- Should return > 0 rows (Acme user can see Acme data)
SELECT COUNT(*) FROM facilities WHERE tenant_id = 'acme-tenant-id';
SELECT COUNT(*) FROM requests WHERE tenant_id = 'acme-tenant-id';
SELECT COUNT(*) FROM contracts WHERE tenant_id = 'acme-tenant-id';
```
- [ ] ✅ Facilities: > 0 rows returned
- [ ] ✅ Requests: > 0 rows returned
- [ ] ✅ Contracts: > 0 rows returned

#### 1.3 Cross-Tenant Insertion Block
**Test**: Login as User A (Acme admin), attempt to insert data for Beta tenant
```sql
-- Should fail with RLS policy violation
INSERT INTO facilities (tenant_id, name, address) 
VALUES ('beta-tenant-id', 'Hack Attempt', 'Should Fail');
```
- [ ] ✅ Insert blocked by RLS policy

### 2. Role-Based Access Tests

#### 2.1 Admin vs Requester - Facility Management
**Test**: Compare facility management capabilities

Login as User A (Acme admin):
```sql
-- Should succeed
INSERT INTO facilities (tenant_id, name, address) 
VALUES ('acme-tenant-id', 'New Acme Plant', '123 Test St');
UPDATE facilities SET name = 'Updated Plant' WHERE id = 'test-facility-id';
DELETE FROM facilities WHERE id = 'test-facility-id';
```
- [ ] ✅ Admin can INSERT facilities
- [ ] ✅ Admin can UPDATE facilities  
- [ ] ✅ Admin can DELETE facilities

Login as User B (Acme requester):
```sql
-- Should fail for INSERT/UPDATE/DELETE
INSERT INTO facilities (tenant_id, name, address) 
VALUES ('acme-tenant-id', 'Requester Plant', '456 Test St');
```
- [ ] ✅ Requester INSERT blocked
- [ ] ✅ Requester UPDATE blocked
- [ ] ✅ Requester DELETE blocked
- [ ] ✅ Requester can SELECT facilities

#### 2.2 Request Creation Access
**Test**: Both roles should be able to create requests in their tenant

Login as User B (Acme requester):
```sql
-- Should succeed
INSERT INTO requests (tenant_id, facility_id, type, priority, description)
VALUES ('acme-tenant-id', 'acme-facility-id', 'on_demand', 'standard', 'Test request');
```
- [ ] ✅ Requester can create requests
- [ ] ✅ Requester can update own requests
- [ ] ✅ Requester cannot create requests for other tenants

#### 2.3 Invoice Management Access
**Test**: Only admins should manage invoices

Login as User A (Acme admin):
```sql
-- Should succeed
INSERT INTO invoices (tenant_id, request_id, amount_paisa, status)
VALUES ('acme-tenant-id', 'test-request-id', 100000, 'pending');
```
- [ ] ✅ Admin can manage invoices

Login as User B (Acme requester):
```sql
-- Should fail
INSERT INTO invoices (tenant_id, request_id, amount_paisa, status)
VALUES ('acme-tenant-id', 'test-request-id', 100000, 'pending');
```
- [ ] ✅ Requester cannot manage invoices
- [ ] ✅ Requester can view invoices in their tenant

### 3. Data Relationship Tests

#### 3.1 Cross-Tenant Facility Assignment
**Test**: Prevent requests from being assigned to wrong tenant's facilities
```sql
-- Login as User A (Acme), attempt to create request for Beta facility
INSERT INTO requests (tenant_id, facility_id, type, priority, description)
VALUES ('acme-tenant-id', 'beta-facility-id', 'on_demand', 'standard', 'Cross-tenant hack');
```
- [ ] ✅ Cross-tenant facility assignment blocked

#### 3.2 Contract-Facility Mapping Isolation
**Test**: Contract facilities junction table respects tenant boundaries
```sql
-- Should only return facilities for contracts within same tenant
SELECT cf.* FROM contract_facilities cf
JOIN contracts c ON cf.contract_id = c.id
JOIN facilities f ON cf.facility_id = f.id
WHERE c.tenant_id != f.tenant_id;
```
- [ ] ✅ Returns 0 rows (no cross-tenant mappings)

### 4. Storage Bucket Access Tests

#### 4.1 Tenant Path Isolation
**Test**: Users can only access files in their tenant's storage path

Login as User A (Acme):
```sql
-- Should succeed
SELECT storage.path FROM storage.objects 
WHERE bucket_id = 'attachments' AND name LIKE 'acme-tenant-id/%';
```
- [ ] ✅ Can access own tenant's storage paths

**Test**: Attempt to access other tenant's files
```sql  
-- Should return 0 rows
SELECT storage.path FROM storage.objects
WHERE bucket_id = 'attachments' AND name LIKE 'beta-tenant-id/%';
```
- [ ] ✅ Cannot access other tenant's storage paths

### 5. Helper Function Tests

#### 5.1 get_user_tenant_id() Function
**Test**: Function returns correct tenant for authenticated user
```sql
SELECT get_user_tenant_id(); -- Should match user's profile.tenant_id
```
- [ ] ✅ Returns correct tenant_id for User A (Acme)
- [ ] ✅ Returns correct tenant_id for User B (Acme)  
- [ ] ✅ Returns correct tenant_id for User C (Beta)
- [ ] ✅ Returns correct tenant_id for User D (Beta)

#### 5.2 get_user_role() Function
**Test**: Function returns correct role for authenticated user
```sql
SELECT get_user_role(); -- Should match user's profile.role
```
- [ ] ✅ Returns 'admin' for User A and C
- [ ] ✅ Returns 'requester' for User B and D

### 6. Audit Trail Tests

#### 6.1 Audit Log Isolation
**Test**: Users only see audit logs for their tenant
```sql
SELECT COUNT(*) FROM audit_logs; -- Should only show current tenant's logs
```
- [ ] ✅ Acme users only see Acme audit logs
- [ ] ✅ Beta users only see Beta audit logs

#### 6.2 Automatic Audit Creation
**Test**: Changes to key tables create audit entries
```sql
-- Create a request, check if audit log is generated
INSERT INTO requests (...) VALUES (...);
SELECT COUNT(*) FROM audit_logs WHERE entity = 'requests' AND action = 'INSERT';
```
- [ ] ✅ Request creation generates audit log
- [ ] ✅ Contract changes generate audit logs

### 7. SLA Function Tests

#### 7.1 Automatic SLA Setting
**Test**: Critical requests automatically get SLA due date
```sql
INSERT INTO requests (tenant_id, facility_id, type, priority, description)
VALUES ('acme-tenant-id', 'acme-facility-id', 'on_demand', 'critical', 'Test SLA');

-- Check if sla_due_at is set to created_at + 6 hours
SELECT sla_due_at, created_at, 
       sla_due_at = created_at + INTERVAL '6 hours' as sla_correct
FROM requests WHERE description = 'Test SLA';
```
- [ ] ✅ Critical requests get automatic 6-hour SLA
- [ ] ✅ Standard requests have NULL sla_due_at

## Pass Criteria
- All test scenarios must pass (✅)
- Zero cross-tenant data leakage
- Role-based permissions enforced correctly
- Storage isolation working
- Helper functions return correct values
- Audit trail captures changes properly

## Failed Tests Action Plan
If any tests fail:
1. Review RLS policy for affected table
2. Check helper function logic
3. Verify user profile setup
4. Test with fresh Supabase project if needed
5. Update policies and re-test

## Security Notes
- RLS policies use SECURITY DEFINER functions for consistent tenant resolution
- All business tables have tenant_id isolation
- Storage bucket uses path-based tenant isolation
- Audit logs track all changes with tenant context
- Foreign key constraints complement RLS policies for data integrity