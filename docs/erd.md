# CUERON SAAN - Entity Relationship Diagram

## Overview
This ERD represents the database schema for the CUERON SAAN HVAC/R service management platform, designed with strict multi-tenant isolation and enterprise workflow support.

## Core Entity Relationships

### Multi-Tenant Root
```
TENANTS (Root Entity)
├── id (PK, UUID)
├── name, domain, gst, cin, business_type
└── created_at
```

### User Management
```
PROFILES (extends auth.users)
├── user_id (PK, FK → auth.users.id)
├── tenant_id (FK → tenants.id) 🔒
├── email, name, phone
├── role (admin|requester)
└── created_at
```

### Location Management
```
FACILITIES
├── id (PK, UUID)
├── tenant_id (FK → tenants.id) 🔒
├── name, address, lat, lng
├── poc_name, poc_phone, poc_email
└── created_at
```

### Service Contracts
```
CONTRACTS                           CONTRACT_FACILITIES (Junction)
├── id (PK, UUID)                  ├── contract_id (FK → contracts.id)
├── tenant_id (FK → tenants.id) 🔒  └── facility_id (FK → facilities.id)
├── type (amc|cmc)
├── term_months, tier, price_paisa
├── billing_cycle (monthly|annual)
├── status (active|pending|cancelled|expired)
├── start_at, end_at
└── created_at
```

### Service Requests
```
REQUESTS
├── id (PK, UUID)
├── tenant_id (FK → tenants.id) 🔒
├── facility_id (FK → facilities.id)
├── type (on_demand|contract)
├── priority (critical|standard)
├── description, media_urls (JSONB)
├── preferred_window (tstzrange)
├── status (new|triaged|assigned|en_route|on_site|completed|verified)
├── assigned_engineer_name, eta, sla_due_at
└── created_at
```

### Planned Maintenance
```
PM_VISITS
├── id (PK, UUID)
├── tenant_id (FK → tenants.id) 🔒
├── contract_id (FK → contracts.id)
├── facility_id (FK → facilities.id)
├── scheduled_for
├── status (planned|due|completed)
├── checklist (JSONB)
└── created_at
```

### Billing System
```
INVOICES
├── id (PK, UUID)
├── tenant_id (FK → tenants.id) 🔒
├── contract_id (FK → contracts.id) [nullable]
├── request_id (FK → requests.id) [nullable]
├── amount_paisa, currency
├── status (pending|paid|failed)
├── issued_at, due_at
├── phonepe_ref
└── created_at

SUBSCRIPTIONS (Future PhonePe)
├── id (PK, UUID)
├── tenant_id (FK → tenants.id) 🔒
├── contract_id (FK → contracts.id)
├── phonepe_subscription_id
├── status (created|active|pending_auth|paused|cancelled)
├── mandate_type, amount_paisa
├── next_debit_at
└── created_at
```

### Audit Trail
```
AUDIT_LOGS
├── id (PK, UUID)
├── tenant_id (FK → tenants.id) 🔒
├── actor_user_id (FK → auth.users.id)
├── action, entity, entity_id
├── metadata (JSONB)
└── created_at
```

## Key Relationships

### One-to-Many
- **Tenant** → Profiles, Facilities, Contracts, Requests, PM Visits, Invoices, Subscriptions, Audit Logs
- **Facility** → Requests, PM Visits
- **Contract** → PM Visits, Invoices, Subscriptions

### Many-to-Many
- **Contracts** ↔ **Facilities** (via contract_facilities junction table)

### Optional References
- **Invoice** → Contract OR Request (one must be present)
- **Request** → assigned_engineer_name (nullable until dispatch)

## Business Rules

### Tenant Isolation 🔒
- Every business table includes `tenant_id` column
- RLS policies enforce strict tenant-based data isolation
- Storage bucket paths include tenant_id prefix

### SLA Management
- Critical requests auto-set `sla_due_at` = created_at + 6 hours
- Standard requests have no automatic SLA

### Contract-Facility Mapping
- Contracts can cover multiple facilities
- Facilities can be covered by multiple contracts
- PM visits are generated based on contract-facility mappings

### Invoice Sources
- Invoices linked to either contracts (recurring) OR requests (ad-hoc)
- Constraint ensures at least one source is present

### Status Workflows
- **Requests**: new → triaged → assigned → en_route → on_site → completed → verified
- **Contracts**: pending → active → expired/cancelled
- **PM Visits**: planned → due → completed

## Storage Integration

### Supabase Storage
```
Bucket: attachments
Path Structure: {tenant_id}/{entity}/{record_id}/{filename}
Policies: Tenant-isolated read/write access
MIME Types: images, PDFs, videos
Size Limit: 10MB per file
```

## Indexes & Performance

### High-Frequency Queries
- Tenant-scoped request listing with status filtering
- SLA monitoring for critical requests
- Active contract lookups
- Upcoming PM visit scheduling
- Invoice payment status tracking

### Optimizations
- Partial indexes for active records only
- Compound indexes for common filter combinations
- Tenant-scoped indexes for all business queries