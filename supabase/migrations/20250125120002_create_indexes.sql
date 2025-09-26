-- Create indexes for CUERON SAAN application
-- Migration: 03_create_indexes

-- Profiles indexes
CREATE INDEX idx_profiles_tenant_id ON profiles(tenant_id);
CREATE INDEX idx_profiles_email ON profiles(email);
CREATE INDEX idx_profiles_tenant_role ON profiles(tenant_id, role);

-- Facilities indexes
CREATE INDEX idx_facilities_tenant_id ON facilities(tenant_id);
CREATE INDEX idx_facilities_tenant_name ON facilities(tenant_id, name);

-- Contracts indexes
CREATE INDEX idx_contracts_tenant_id ON contracts(tenant_id);
CREATE INDEX idx_contracts_tenant_status ON contracts(tenant_id, status);
CREATE INDEX idx_contracts_tenant_type ON contracts(tenant_id, type);
CREATE INDEX idx_contracts_status_dates ON contracts(status, start_at, end_at);

-- Contract facilities indexes
CREATE INDEX idx_contract_facilities_facility ON contract_facilities(facility_id);

-- Requests indexes (high-frequency queries)
CREATE INDEX idx_requests_tenant_id ON requests(tenant_id);
CREATE INDEX idx_requests_tenant_status ON requests(tenant_id, status);
CREATE INDEX idx_requests_facility_id ON requests(facility_id);
CREATE INDEX idx_requests_tenant_priority ON requests(tenant_id, priority);
CREATE INDEX idx_requests_sla_due ON requests(sla_due_at) WHERE sla_due_at IS NOT NULL;
CREATE INDEX idx_requests_created_desc ON requests(tenant_id, created_at DESC);
CREATE INDEX idx_requests_status_eta ON requests(status, eta) WHERE eta IS NOT NULL;

-- PM visits indexes
CREATE INDEX idx_pm_visits_tenant_id ON pm_visits(tenant_id);
CREATE INDEX idx_pm_visits_contract_id ON pm_visits(contract_id);
CREATE INDEX idx_pm_visits_facility_id ON pm_visits(facility_id);
CREATE INDEX idx_pm_visits_scheduled ON pm_visits(scheduled_for);
CREATE INDEX idx_pm_visits_tenant_status ON pm_visits(tenant_id, status);

-- Invoices indexes
CREATE INDEX idx_invoices_tenant_id ON invoices(tenant_id);
CREATE INDEX idx_invoices_tenant_status ON invoices(tenant_id, status);
CREATE INDEX idx_invoices_contract_id ON invoices(contract_id) WHERE contract_id IS NOT NULL;
CREATE INDEX idx_invoices_request_id ON invoices(request_id) WHERE request_id IS NOT NULL;
CREATE INDEX idx_invoices_due_date ON invoices(due_at) WHERE due_at IS NOT NULL;
CREATE INDEX idx_invoices_phonepe_ref ON invoices(phonepe_ref) WHERE phonepe_ref IS NOT NULL;

-- Subscriptions indexes
CREATE INDEX idx_subscriptions_tenant_id ON subscriptions(tenant_id);
CREATE INDEX idx_subscriptions_contract_id ON subscriptions(contract_id);
CREATE INDEX idx_subscriptions_status ON subscriptions(status);
CREATE INDEX idx_subscriptions_phonepe_id ON subscriptions(phonepe_subscription_id) WHERE phonepe_subscription_id IS NOT NULL;

-- Audit logs indexes
CREATE INDEX idx_audit_logs_tenant_id ON audit_logs(tenant_id);
CREATE INDEX idx_audit_logs_actor ON audit_logs(actor_user_id);
CREATE INDEX idx_audit_logs_entity ON audit_logs(entity, entity_id);
CREATE INDEX idx_audit_logs_created_desc ON audit_logs(tenant_id, created_at DESC);

-- Partial indexes for performance optimization
CREATE INDEX idx_requests_active ON requests(tenant_id, created_at DESC) 
  WHERE status IN ('new', 'triaged', 'assigned', 'en_route', 'on_site');

CREATE INDEX idx_contracts_active ON contracts(tenant_id, end_at) 
  WHERE status = 'active';

CREATE INDEX idx_pm_visits_upcoming ON pm_visits(tenant_id, scheduled_for) 
  WHERE status IN ('planned', 'due');

-- Comments for index documentation
COMMENT ON INDEX idx_requests_sla_due IS 'Fast lookup for SLA monitoring and alerts';
COMMENT ON INDEX idx_requests_active IS 'Optimized for dashboard active request queries';
COMMENT ON INDEX idx_contracts_active IS 'Fast lookup for active contract management';
COMMENT ON INDEX idx_pm_visits_upcoming IS 'Optimized for PM scheduling dashboard';