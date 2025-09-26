-- Create storage bucket and policies for CUERON SAAN application
-- Migration: 05_storage_policies

-- Create attachments bucket for file storage
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'attachments',
  'attachments',
  false,
  10485760, -- 10MB limit
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf', 'video/mp4', 'video/quicktime']
);

-- Storage policy for uploads
-- Object path structure: attachments/{tenant_id}/{entity}/{record_id}/{filename}
CREATE POLICY "Users can upload to their tenant folder"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'attachments' AND
    -- Extract tenant_id from path (first path segment)
    (string_to_array(name, '/'))[1] = get_user_tenant_id()::text AND
    -- Authenticated users only
    auth.role() = 'authenticated'
  );

-- Storage policy for downloads
CREATE POLICY "Users can download from their tenant folder"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'attachments' AND
    -- Extract tenant_id from path (first path segment)
    (string_to_array(name, '/'))[1] = get_user_tenant_id()::text AND
    -- Authenticated users only
    auth.role() = 'authenticated'
  );

-- Storage policy for updates (metadata, etc.)
CREATE POLICY "Users can update files in their tenant folder"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'attachments' AND
    -- Extract tenant_id from path (first path segment)
    (string_to_array(name, '/'))[1] = get_user_tenant_id()::text AND
    -- Authenticated users only
    auth.role() = 'authenticated'
  );

-- Storage policy for deletions
CREATE POLICY "Users can delete files from their tenant folder"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'attachments' AND
    -- Extract tenant_id from path (first path segment)
    (string_to_array(name, '/'))[1] = get_user_tenant_id()::text AND
    -- Authenticated users only
    auth.role() = 'authenticated'
  );

-- Function to generate storage path for requests
CREATE OR REPLACE FUNCTION generate_storage_path(
  entity_type text,
  record_id uuid,
  filename text
)
RETURNS text AS $$
BEGIN
  RETURN format(
    '%s/%s/%s/%s',
    get_user_tenant_id(),
    entity_type,
    record_id,
    filename
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to validate storage path belongs to user's tenant
CREATE OR REPLACE FUNCTION validate_storage_path(storage_path text)
RETURNS boolean AS $$
DECLARE
  path_tenant_id text;
BEGIN
  -- Extract tenant_id from path (first segment)
  path_tenant_id := (string_to_array(storage_path, '/'))[1];
  
  -- Check if it matches user's tenant
  RETURN path_tenant_id = get_user_tenant_id()::text;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Comments for storage documentation
COMMENT ON POLICY "Users can upload to their tenant folder" ON storage.objects IS 'Tenant-isolated file uploads with MIME type restrictions';
COMMENT ON FUNCTION generate_storage_path(text, uuid, text) IS 'Helper to generate tenant-scoped storage paths';
COMMENT ON FUNCTION validate_storage_path(text) IS 'Validates storage path belongs to users tenant';