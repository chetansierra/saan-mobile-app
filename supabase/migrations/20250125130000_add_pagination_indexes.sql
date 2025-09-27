-- Composite index to support efficient cursor-based pagination for invoices
-- This index enables O(log n) pagination performance vs O(n) with OFFSET
-- Query pattern: WHERE (tenant_id = ? AND (issue_date < ? OR (issue_date = ? AND id < ?)))
-- ORDER BY issue_date DESC, id DESC
CREATE INDEX IF NOT EXISTS invoices_tenant_issue_id_desc
  ON invoices (tenant_id, issue_date DESC, id DESC);

-- Similar index for PM visits (for upcoming PMSchedulePage optimization)  
CREATE INDEX IF NOT EXISTS pm_visits_tenant_scheduled_id_desc
  ON pm_visits (tenant_id, scheduled_date DESC, id DESC);

-- Index for requests if not already optimized
CREATE INDEX IF NOT EXISTS requests_tenant_created_id_desc
  ON requests (tenant_id, created_at DESC, id DESC);

-- Partial index for active invoices (common filter)
CREATE INDEX IF NOT EXISTS invoices_active_tenant_issue_id_desc
  ON invoices (tenant_id, issue_date DESC, id DESC)
  WHERE status IN ('draft', 'sent', 'pending');

-- Comment explaining the performance benefit
-- These indexes support cursor-based pagination which:
-- 1. Eliminates the OFFSET scan problem (scanning N records to get to page N)
-- 2. Provides consistent performance regardless of page depth
-- 3. Handles real-time insertions correctly (no duplicate/skip issues)
-- 4. Enables efficient "load more" functionality with stable cursors