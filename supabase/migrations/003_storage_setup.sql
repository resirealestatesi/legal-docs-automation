-- supabase/migrations/003_storage_setup.sql

-- ============================================
-- CREATE STORAGE BUCKET
-- ============================================

INSERT INTO storage.buckets (id, name, public)
VALUES ('templates-docx', 'templates-docx', false)
ON CONFLICT (id) DO NOTHING;

-- ============================================
-- STORAGE RLS POLICIES
-- Using anon key (matches existing table policies)
-- ============================================

-- Allow upload
CREATE POLICY "Allow upload docx"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'templates-docx');

-- Allow read/download
CREATE POLICY "Allow read docx"
ON storage.objects FOR SELECT
USING (bucket_id = 'templates-docx');

-- Allow update
CREATE POLICY "Allow update docx"
ON storage.objects FOR UPDATE
USING (bucket_id = 'templates-docx');

-- Allow delete
CREATE POLICY "Allow delete docx"
ON storage.objects FOR DELETE
USING (bucket_id = 'templates-docx');
