-- Create all enums for CUERON SAAN application
-- Migration: 01_create_enums

-- User role enum
CREATE TYPE user_role AS ENUM ('admin', 'requester');

-- Request type enum
CREATE TYPE request_type AS ENUM ('on_demand', 'contract');

-- Request priority enum
CREATE TYPE request_priority AS ENUM ('critical', 'standard');

-- Request status enum
CREATE TYPE request_status AS ENUM (
  'new', 
  'triaged', 
  'assigned', 
  'en_route', 
  'on_site', 
  'completed', 
  'verified'
);

-- Contract type enum
CREATE TYPE contract_type AS ENUM ('amc', 'cmc');

-- Billing cycle enum
CREATE TYPE billing_cycle AS ENUM ('monthly', 'annual');

-- Contract status enum
CREATE TYPE contract_status AS ENUM ('active', 'pending', 'cancelled', 'expired');

-- PM visit status enum
CREATE TYPE pm_visit_status AS ENUM ('planned', 'due', 'completed');

-- Invoice status enum
CREATE TYPE invoice_status AS ENUM ('pending', 'paid', 'failed');

-- Subscription status enum (future use)
CREATE TYPE subscription_status AS ENUM (
  'created', 
  'active', 
  'pending_auth', 
  'paused', 
  'cancelled'
);

-- Add comments for enum documentation
COMMENT ON TYPE user_role IS 'User roles within tenant: admin (full access) or requester (limited access)';
COMMENT ON TYPE request_priority IS 'Request priority levels: critical (6-hour SLA) or standard';
COMMENT ON TYPE request_status IS 'Request lifecycle status from new submission to verification';
COMMENT ON TYPE contract_type IS 'Contract types: AMC (Annual Maintenance) or CMC (Comprehensive Maintenance)';