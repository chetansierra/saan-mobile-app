-- Enable RLS and create policies for CUERON SAAN application
-- Migration: 04_enable_rls_policies

-- Enable RLS on all business tables
ALTER TABLE tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE facilities ENABLE ROW LEVEL SECURITY;
ALTER TABLE contracts ENABLE ROW LEVEL SECURITY;
ALTER TABLE contract_facilities ENABLE ROW LEVEL SECURITY;
ALTER TABLE requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE pm_visits ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- Helper function to get current user's tenant_id
CREATE OR REPLACE FUNCTION get_user_tenant_id()
RETURNS uuid AS $$
BEGIN
  RETURN (
    SELECT tenant_id 
    FROM profiles 
    WHERE user_id = auth.uid()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Helper function to get current user's role
CREATE OR REPLACE FUNCTION get_user_role()
RETURNS user_role AS $$
BEGIN
  RETURN (
    SELECT role 
    FROM profiles 
    WHERE user_id = auth.uid()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- TENANTS table policies
CREATE POLICY "Users can view their own tenant"
  ON tenants FOR SELECT
  USING (id = get_user_tenant_id());

CREATE POLICY "Admins can update their tenant"
  ON tenants FOR UPDATE
  USING (id = get_user_tenant_id() AND get_user_role() = 'admin');

-- PROFILES table policies
CREATE POLICY "Users can view profiles in their tenant"
  ON profiles FOR SELECT
  USING (tenant_id = get_user_tenant_id());

CREATE POLICY "Users can update their own profile"
  ON profiles FOR UPDATE
  USING (user_id = auth.uid());

CREATE POLICY "Admins can insert profiles in their tenant"
  ON profiles FOR INSERT
  WITH CHECK (tenant_id = get_user_tenant_id() AND get_user_role() = 'admin');

-- FACILITIES table policies
CREATE POLICY "Users can view facilities in their tenant"
  ON facilities FOR SELECT
  USING (tenant_id = get_user_tenant_id());

CREATE POLICY "Admins can manage facilities in their tenant"
  ON facilities FOR ALL
  USING (tenant_id = get_user_tenant_id() AND get_user_role() = 'admin')
  WITH CHECK (tenant_id = get_user_tenant_id() AND get_user_role() = 'admin');

-- CONTRACTS table policies
CREATE POLICY "Users can view contracts in their tenant"
  ON contracts FOR SELECT
  USING (tenant_id = get_user_tenant_id());

CREATE POLICY "Admins can manage contracts in their tenant"
  ON contracts FOR ALL
  USING (tenant_id = get_user_tenant_id() AND get_user_role() = 'admin')
  WITH CHECK (tenant_id = get_user_tenant_id() AND get_user_role() = 'admin');

-- CONTRACT_FACILITIES table policies
CREATE POLICY "Users can view contract facilities in their tenant"
  ON contract_facilities FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM contracts c 
      WHERE c.id = contract_id AND c.tenant_id = get_user_tenant_id()
    )
  );

CREATE POLICY "Admins can manage contract facilities in their tenant"
  ON contract_facilities FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM contracts c 
      WHERE c.id = contract_id AND c.tenant_id = get_user_tenant_id()
    ) AND get_user_role() = 'admin'
  );

-- REQUESTS table policies
CREATE POLICY "Users can view requests in their tenant"
  ON requests FOR SELECT
  USING (tenant_id = get_user_tenant_id());

CREATE POLICY "Users can create requests in their tenant"
  ON requests FOR INSERT
  WITH CHECK (
    tenant_id = get_user_tenant_id() AND
    EXISTS (
      SELECT 1 FROM facilities f 
      WHERE f.id = facility_id AND f.tenant_id = get_user_tenant_id()
    )
  );

CREATE POLICY "Users can update their own requests"
  ON requests FOR UPDATE
  USING (tenant_id = get_user_tenant_id());

-- PM_VISITS table policies
CREATE POLICY "Users can view PM visits in their tenant"
  ON pm_visits FOR SELECT
  USING (tenant_id = get_user_tenant_id());

CREATE POLICY "Admins can manage PM visits in their tenant"
  ON pm_visits FOR ALL
  USING (tenant_id = get_user_tenant_id() AND get_user_role() = 'admin')
  WITH CHECK (tenant_id = get_user_tenant_id() AND get_user_role() = 'admin');

-- INVOICES table policies
CREATE POLICY "Users can view invoices in their tenant"
  ON invoices FOR SELECT
  USING (tenant_id = get_user_tenant_id());

CREATE POLICY "Admins can manage invoices in their tenant"
  ON invoices FOR ALL
  USING (tenant_id = get_user_tenant_id() AND get_user_role() = 'admin')
  WITH CHECK (tenant_id = get_user_tenant_id() AND get_user_role() = 'admin');

-- SUBSCRIPTIONS table policies
CREATE POLICY "Users can view subscriptions in their tenant"
  ON subscriptions FOR SELECT
  USING (tenant_id = get_user_tenant_id());

CREATE POLICY "Admins can manage subscriptions in their tenant"
  ON subscriptions FOR ALL
  USING (tenant_id = get_user_tenant_id() AND get_user_role() = 'admin')
  WITH CHECK (tenant_id = get_user_tenant_id() AND get_user_role() = 'admin');

-- AUDIT_LOGS table policies
CREATE POLICY "Users can view audit logs in their tenant"
  ON audit_logs FOR SELECT
  USING (tenant_id = get_user_tenant_id());

CREATE POLICY "System can insert audit logs"
  ON audit_logs FOR INSERT
  WITH CHECK (tenant_id = get_user_tenant_id());

-- Create function to automatically set SLA due date for critical requests
CREATE OR REPLACE FUNCTION set_request_sla()
RETURNS TRIGGER AS $$
BEGIN
  -- Set SLA due date for critical requests (6 hours from creation)
  IF NEW.priority = 'critical' AND NEW.sla_due_at IS NULL THEN
    NEW.sla_due_at = NEW.created_at + INTERVAL '6 hours';
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for automatic SLA setting
CREATE TRIGGER set_request_sla_trigger
  BEFORE INSERT OR UPDATE ON requests
  FOR EACH ROW
  EXECUTE FUNCTION set_request_sla();

-- Create function to log changes for audit trail
CREATE OR REPLACE FUNCTION create_audit_log()
RETURNS TRIGGER AS $$
DECLARE
  tenant_uuid uuid;
BEGIN
  -- Get tenant_id from the affected row
  tenant_uuid := COALESCE(NEW.tenant_id, OLD.tenant_id);
  
  -- Insert audit log entry
  INSERT INTO audit_logs (tenant_id, actor_user_id, action, entity, entity_id, metadata)
  VALUES (
    tenant_uuid,
    auth.uid(),
    TG_OP,
    TG_TABLE_NAME,
    COALESCE(NEW.id, OLD.id),
    jsonb_build_object('timestamp', now())
  );
  
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Create audit triggers on key tables
CREATE TRIGGER audit_requests_trigger
  AFTER INSERT OR UPDATE OR DELETE ON requests
  FOR EACH ROW
  EXECUTE FUNCTION create_audit_log();

CREATE TRIGGER audit_contracts_trigger
  AFTER INSERT OR UPDATE OR DELETE ON contracts
  FOR EACH ROW
  EXECUTE FUNCTION create_audit_log();

-- Comments for policy documentation
COMMENT ON POLICY "Users can view their own tenant" ON tenants IS 'Basic tenant visibility for authenticated users';
COMMENT ON POLICY "Admins can update their tenant" ON tenants IS 'Only admins can modify tenant settings';
COMMENT ON FUNCTION get_user_tenant_id() IS 'Helper function for tenant isolation in RLS policies';
COMMENT ON FUNCTION set_request_sla() IS 'Automatically sets 6-hour SLA for critical requests';