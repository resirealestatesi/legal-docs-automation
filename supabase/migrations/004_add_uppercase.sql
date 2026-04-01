-- supabase/migrations/004_add_uppercase.sql

-- Add uppercase column to automations table
ALTER TABLE automations ADD COLUMN IF NOT EXISTS uppercase BOOLEAN DEFAULT FALSE;
