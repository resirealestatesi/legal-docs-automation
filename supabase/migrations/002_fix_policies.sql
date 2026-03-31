-- supabase/migrations/002_fix_policies.sql

-- ============================================
-- DELETE/UPDATE POLICIES
-- ============================================

CREATE POLICY "Delete templates" ON templates FOR DELETE USING (true);
CREATE POLICY "Update templates" ON templates FOR UPDATE USING (true);
CREATE POLICY "Delete automations" ON automations FOR DELETE USING (true);
CREATE POLICY "Update automations" ON automations FOR UPDATE USING (true);

-- ============================================
-- TEMPLATE VALUES (for filling templates)
-- ============================================

CREATE TABLE template_values (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    automation_id UUID NOT NULL REFERENCES automations(id) ON DELETE CASCADE,
    filled_value TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_template_values_automation ON template_values(automation_id);

ALTER TABLE template_values ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Read template_values" ON template_values FOR SELECT USING (true);
CREATE POLICY "Insert template_values" ON template_values FOR INSERT WITH CHECK (true);
CREATE POLICY "Update template_values" ON template_values FOR UPDATE USING (true);
CREATE POLICY "Delete template_values" ON template_values FOR DELETE USING (true);
