-- Seed data for CUERON SAAN application testing
-- This script creates sample data for testing multi-tenant isolation and basic functionality

-- Create two test tenants
INSERT INTO tenants (id, name, domain, gst, cin, business_type) VALUES
  ('550e8400-e29b-41d4-a716-446655440001', 'Acme Manufacturing Ltd', 'acme.com', '22AAAAA0000A1Z5', 'L74899DL2019PLC123456', 'Manufacturing'),
  ('550e8400-e29b-41d4-a716-446655440002', 'Beta Pharma Corp', 'beta-pharma.com', '33BBBBB1111B2Y6', 'L24232MH2020PTC234567', 'Pharmaceuticals');

-- Create test users in Supabase Auth (these need to be created via Supabase Dashboard or Auth API)
-- User 1: admin@acme.com (password: TestPass123!) - for Acme Manufacturing
-- User 2: manager@acme.com (password: TestPass123!) - for Acme Manufacturing  
-- User 3: admin@beta.com (password: TestPass123!) - for Beta Pharma
-- User 4: user@beta.com (password: TestPass123!) - for Beta Pharma

-- Note: The actual user creation in auth.users needs to be done via Supabase Auth
-- The UUIDs below should match the ones created in auth.users

-- Create profiles for test users
INSERT INTO profiles (user_id, tenant_id, email, name, role, phone) VALUES
  ('11111111-1111-1111-1111-111111111111', '550e8400-e29b-41d4-a716-446655440001', 'admin@acme.com', 'John Admin', 'admin', '+91-9876543210'),
  ('22222222-2222-2222-2222-222222222222', '550e8400-e29b-41d4-a716-446655440001', 'manager@acme.com', 'Jane Manager', 'requester', '+91-9876543211'),
  ('33333333-3333-3333-3333-333333333333', '550e8400-e29b-41d4-a716-446655440002', 'admin@beta.com', 'Bob Admin', 'admin', '+91-9876543212'),
  ('44444444-4444-4444-4444-444444444444', '550e8400-e29b-41d4-a716-446655440002', 'user@beta.com', 'Alice User', 'requester', '+91-9876543213');

-- Create facilities for each tenant
INSERT INTO facilities (id, tenant_id, name, address, lat, lng, poc_name, poc_phone, poc_email) VALUES
  -- Acme Manufacturing facilities
  ('f0000001-0000-0000-0000-000000000001', '550e8400-e29b-41d4-a716-446655440001', 'Acme Plant 1', '123 Industrial Area, Gurgaon, Haryana 122001', 28.4595, 77.0266, 'Ravi Kumar', '+91-9876540001', 'ravi.kumar@acme.com'),
  ('f0000001-0000-0000-0000-000000000002', '550e8400-e29b-41d4-a716-446655440001', 'Acme Warehouse Delhi', '456 Logistics Hub, New Delhi 110001', 28.7041, 77.1025, 'Priya Sharma', '+91-9876540002', 'priya.sharma@acme.com'),
  
  -- Beta Pharma facilities  
  ('f0000002-0000-0000-0000-000000000001', '550e8400-e29b-41d4-a716-446655440002', 'Beta Lab Complex', '789 Pharma City, Hyderabad, Telangana 500032', 17.4065, 78.4772, 'Suresh Reddy', '+91-9876540003', 'suresh.reddy@beta.com'),
  ('f0000002-0000-0000-0000-000000000002', '550e8400-e29b-41d4-a716-446655440002', 'Beta Cold Storage', '321 Cold Chain Blvd, Mumbai, Maharashtra 400001', 19.0760, 72.8777, 'Meera Patel', '+91-9876540004', 'meera.patel@beta.com');

-- Create sample contracts
INSERT INTO contracts (id, tenant_id, type, term_months, tier, price_paisa, billing_cycle, status, start_at, end_at) VALUES
  -- Acme contracts
  ('c0000001-0000-0000-0000-000000000001', '550e8400-e29b-41d4-a716-446655440001', 'amc', 12, 'Premium', 12000000, 'annual', 'active', '2025-01-01 00:00:00+00', '2025-12-31 23:59:59+00'),
  ('c0000001-0000-0000-0000-000000000002', '550e8400-e29b-41d4-a716-446655440001', 'cmc', 24, 'Standard', 8000000, 'monthly', 'pending', '2025-02-01 00:00:00+00', '2027-01-31 23:59:59+00'),
  
  -- Beta contracts
  ('c0000002-0000-0000-0000-000000000001', '550e8400-e29b-41d4-a716-446655440002', 'amc', 12, 'Basic', 6000000, 'annual', 'active', '2025-01-15 00:00:00+00', '2026-01-14 23:59:59+00');

-- Map facilities to contracts
INSERT INTO contract_facilities (contract_id, facility_id) VALUES
  -- Acme Premium AMC covers both facilities
  ('c0000001-0000-0000-0000-000000000001', 'f0000001-0000-0000-0000-000000000001'),
  ('c0000001-0000-0000-0000-000000000001', 'f0000001-0000-0000-0000-000000000002'),
  
  -- Acme CMC covers only Plant 1
  ('c0000001-0000-0000-0000-000000000002', 'f0000001-0000-0000-0000-000000000001'),
  
  -- Beta AMC covers Lab Complex only
  ('c0000002-0000-0000-0000-000000000001', 'f0000002-0000-0000-0000-000000000001');

-- Create sample service requests
INSERT INTO requests (id, tenant_id, facility_id, type, priority, description, preferred_window, status, assigned_engineer_name, eta, sla_due_at) VALUES
  -- Acme requests
  ('r0000001-0000-0000-0000-000000000001', '550e8400-e29b-41d4-a716-446655440001', 'f0000001-0000-0000-0000-000000000001', 'on_demand', 'critical', 'HVAC system failure in clean room - production stopped', '[2025-01-26 09:00:00+00, 2025-01-26 12:00:00+00)', 'assigned', 'Rajesh Singh', '2025-01-26 10:30:00+00', '2025-01-26 15:00:00+00'),
  ('r0000001-0000-0000-0000-000000000002', '550e8400-e29b-41d4-a716-446655440001', 'f0000001-0000-0000-0000-000000000002', 'contract', 'standard', 'Routine cooling system maintenance', '[2025-01-27 14:00:00+00, 2025-01-27 17:00:00+00)', 'new', NULL, NULL, NULL),
  
  -- Beta requests
  ('r0000002-0000-0000-0000-000000000001', '550e8400-e29b-41d4-a716-446655440002', 'f0000002-0000-0000-0000-000000000001', 'on_demand', 'standard', 'Temperature monitoring calibration needed', '[2025-01-28 10:00:00+00, 2025-01-28 16:00:00+00)', 'triaged', NULL, NULL, NULL);

-- Create sample PM visits
INSERT INTO pm_visits (id, tenant_id, contract_id, facility_id, scheduled_for, status, checklist) VALUES
  -- Acme PM visits
  ('p0000001-0000-0000-0000-000000000001', '550e8400-e29b-41d4-a716-446655440001', 'c0000001-0000-0000-0000-000000000001', 'f0000001-0000-0000-0000-000000000001', '2025-02-15 10:00:00+00', 'planned', '["Check air filters", "Inspect compressor", "Test safety systems", "Calibrate sensors"]'),
  ('p0000001-0000-0000-0000-000000000002', '550e8400-e29b-41d4-a716-446655440001', 'c0000001-0000-0000-0000-000000000001', 'f0000001-0000-0000-0000-000000000002', '2025-02-20 14:00:00+00', 'planned', '["Refrigeration system check", "Electrical connections", "Control panel inspection"]'),
  
  -- Beta PM visits
  ('p0000002-0000-0000-0000-000000000001', '550e8400-e29b-41d4-a716-446655440002', 'c0000002-0000-0000-0000-000000000001', 'f0000002-0000-0000-0000-000000000001', '2025-03-01 09:00:00+00', 'planned', '["Clean room HVAC check", "Temperature logging review", "Filter replacement", "Compliance documentation"]');

-- Create sample invoices
INSERT INTO invoices (id, tenant_id, contract_id, request_id, amount_paisa, currency, status, issued_at, due_at) VALUES
  -- Acme invoices
  ('i0000001-0000-0000-0000-000000000001', '550e8400-e29b-41d4-a716-446655440001', 'c0000001-0000-0000-0000-000000000001', NULL, 12000000, 'INR', 'paid', '2025-01-01 00:00:00+00', '2025-01-31 23:59:59+00'),
  ('i0000001-0000-0000-0000-000000000002', '550e8400-e29b-41d4-a716-446655440001', NULL, 'r0000001-0000-0000-0000-000000000001', 500000, 'INR', 'pending', '2025-01-26 12:00:00+00', '2025-02-10 23:59:59+00'),
  
  -- Beta invoices
  ('i0000002-0000-0000-0000-000000000001', '550e8400-e29b-41d4-a716-446655440002', 'c0000002-0000-0000-0000-000000000001', NULL, 6000000, 'INR', 'paid', '2025-01-15 00:00:00+00', '2025-02-14 23:59:59+00');

-- Create some audit log entries
INSERT INTO audit_logs (tenant_id, actor_user_id, action, entity, entity_id, metadata) VALUES
  ('550e8400-e29b-41d4-a716-446655440001', '11111111-1111-1111-1111-111111111111', 'INSERT', 'requests', 'r0000001-0000-0000-0000-000000000001', '{"description": "Critical HVAC request created"}'),
  ('550e8400-e29b-41d4-a716-446655440001', '11111111-1111-1111-1111-111111111111', 'UPDATE', 'requests', 'r0000001-0000-0000-0000-000000000001', '{"status_changed": "new -> assigned", "engineer": "Rajesh Singh"}'),
  ('550e8400-e29b-41d4-a716-446655440002', '33333333-3333-3333-3333-333333333333', 'INSERT', 'contracts', 'c0000002-0000-0000-0000-000000000001', '{"contract_type": "amc", "tier": "Basic"}');

-- Add comments for seed data documentation
COMMENT ON TABLE tenants IS 'Sample tenants: Acme Manufacturing and Beta Pharma for testing tenant isolation';
-- Note: Remember to create corresponding auth.users entries in Supabase Dashboard:
-- admin@acme.com, manager@acme.com, admin@beta.com, user@beta.com