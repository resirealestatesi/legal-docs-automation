-- supabase/migrations/001_initial_schema.sql

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- COMPANIES
-- ============================================
CREATE TABLE companies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_companies_code ON companies(code) WHERE is_active = true;

-- ============================================
-- TEMPLATES
-- ============================================
CREATE TABLE templates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    file_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_templates_company ON templates(company_id);

-- ============================================
-- AUTOMATIONS
-- ============================================
CREATE TABLE automations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    template_id UUID NOT NULL REFERENCES templates(id) ON DELETE CASCADE,
    field_name VARCHAR(255) NOT NULL,
    field_options JSONB DEFAULT '[]'::jsonb,
    highlight_text TEXT NOT NULL,
    highlight_color VARCHAR(20) DEFAULT '#B89B5E4D',
    uppercase BOOLEAN DEFAULT FALSE,
    position_start INTEGER,
    position_end INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_automations_template ON automations(template_id);

-- ============================================
-- ROW LEVEL SECURITY
-- ============================================
ALTER TABLE companies ENABLE ROW LEVEL SECURITY;
ALTER TABLE templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE automations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Read active companies" ON companies FOR SELECT USING (is_active = true);
CREATE POLICY "Read templates" ON templates FOR SELECT USING (true);
CREATE POLICY "Insert templates" ON templates FOR INSERT WITH CHECK (true);
CREATE POLICY "Read automations" ON automations FOR SELECT USING (true);
CREATE POLICY "Insert automations" ON automations FOR INSERT WITH CHECK (true);

-- ============================================
-- SEED DATA
-- ============================================
INSERT INTO companies (code, name, is_active) VALUES
    ('LCC-2026', 'Legal Consulting Center', true),
    ('LCC-2027', 'LC Empresa Demo', true);
