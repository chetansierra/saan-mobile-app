-- Create all tables for CUERON SAAN application
-- Migration: 02_create_tables

-- Tenants table (root entity for multi-tenancy)
CREATE TABLE tenants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  domain text,
  gst text,
  cin text,
  business_type text,
  created_at timestamptz DEFAULT now()
);

-- User profiles table (extends Supabase auth.users)
CREATE TABLE profiles (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  email text NOT NULL,
  name text NOT NULL,
  role user_role NOT NULL DEFAULT 'requester',
  phone text,
  created_at timestamptz DEFAULT now()
);

-- Facilities table (locations within tenant)
CREATE TABLE facilities (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  name text NOT NULL,
  address text NOT NULL,
  lat double precision,
  lng double precision,
  poc_name text,
  poc_phone text,
  poc_email text,
  created_at timestamptz DEFAULT now()
);

-- Contracts table (AMC/CMC agreements)
CREATE TABLE contracts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  type contract_type NOT NULL,
  term_months integer NOT NULL CHECK (term_months > 0),
  tier text,
  price_paisa integer NOT NULL CHECK (price_paisa >= 0),
  billing_cycle billing_cycle NOT NULL,
  status contract_status NOT NULL DEFAULT 'pending',
  start_at timestamptz,
  end_at timestamptz,
  created_at timestamptz DEFAULT now(),
  
  -- Ensure end_at is after start_at
  CONSTRAINT contracts_valid_dates CHECK (end_at > start_at)
);

-- Junction table for contract-facility mapping
CREATE TABLE contract_facilities (
  contract_id uuid REFERENCES contracts(id) ON DELETE CASCADE,
  facility_id uuid REFERENCES facilities(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  
  PRIMARY KEY (contract_id, facility_id)
);

-- Service requests table
CREATE TABLE requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  facility_id uuid NOT NULL REFERENCES facilities(id) ON DELETE CASCADE,
  type request_type NOT NULL,
  priority request_priority NOT NULL DEFAULT 'standard',
  description text NOT NULL,
  media_urls jsonb DEFAULT '[]'::jsonb,
  preferred_window tstzrange,
  status request_status NOT NULL DEFAULT 'new',
  assigned_engineer_name text,
  eta timestamptz,
  sla_due_at timestamptz,
  created_at timestamptz DEFAULT now(),
  
  -- Ensure facility belongs to same tenant (will be enforced by RLS)
  CONSTRAINT requests_valid_tenant CHECK (true)
);

-- Planned maintenance visits table
CREATE TABLE pm_visits (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  contract_id uuid NOT NULL REFERENCES contracts(id) ON DELETE CASCADE,
  facility_id uuid NOT NULL REFERENCES facilities(id) ON DELETE CASCADE,
  scheduled_for timestamptz NOT NULL,
  status pm_visit_status NOT NULL DEFAULT 'planned',
  checklist jsonb DEFAULT '[]'::jsonb,
  created_at timestamptz DEFAULT now()
);

-- Invoices table
CREATE TABLE invoices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  contract_id uuid REFERENCES contracts(id) ON DELETE SET NULL,
  request_id uuid REFERENCES requests(id) ON DELETE SET NULL,
  amount_paisa integer NOT NULL CHECK (amount_paisa >= 0),
  currency text DEFAULT 'INR',
  status invoice_status NOT NULL DEFAULT 'pending',
  issued_at timestamptz DEFAULT now(),
  due_at timestamptz,
  phonepe_ref text,
  created_at timestamptz DEFAULT now(),
  
  -- Invoice must be linked to either contract or request
  CONSTRAINT invoices_has_source CHECK (
    (contract_id IS NOT NULL) OR (request_id IS NOT NULL)
  )
);

-- Subscriptions table (future PhonePe integration)
CREATE TABLE subscriptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  contract_id uuid NOT NULL REFERENCES contracts(id) ON DELETE CASCADE,
  phonepe_subscription_id text,
  status subscription_status NOT NULL DEFAULT 'created',
  mandate_type text,
  amount_paisa integer NOT NULL CHECK (amount_paisa >= 0),
  next_debit_at timestamptz,
  created_at timestamptz DEFAULT now()
);

-- Audit logs table (for tracking changes)
CREATE TABLE audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  actor_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  action text NOT NULL,
  entity text NOT NULL,
  entity_id uuid,
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz DEFAULT now()
);

-- Add table comments for documentation
COMMENT ON TABLE tenants IS 'Root tenant entities for multi-tenant isolation';
COMMENT ON TABLE profiles IS 'User profiles extending Supabase auth with tenant association';
COMMENT ON TABLE facilities IS 'Physical locations managed by tenants';
COMMENT ON TABLE contracts IS 'AMC/CMC service agreements with pricing and terms';
COMMENT ON TABLE contract_facilities IS 'Many-to-many mapping between contracts and facilities';
COMMENT ON TABLE requests IS 'Service requests with priority, SLA tracking, and status';
COMMENT ON TABLE pm_visits IS 'Planned maintenance visits scheduled under contracts';
COMMENT ON TABLE invoices IS 'Billing records for contracts and ad-hoc requests';
COMMENT ON TABLE subscriptions IS 'PhonePe subscription management for recurring payments';
COMMENT ON TABLE audit_logs IS 'System activity tracking for compliance and debugging';