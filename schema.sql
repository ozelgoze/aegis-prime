-- ═══════════════════════════════════════════════════════════════
--  AEGIS PRIME — SUPABASE SCHEMA
--  Run this in your Supabase SQL Editor to set up the database.
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS characters (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),

  -- Identity
  student_id TEXT NOT NULL UNIQUE,
  type TEXT NOT NULL DEFAULT 'cadet',
  name TEXT NOT NULL,
  callsign TEXT,
  role_title TEXT,
  faction TEXT,
  age TEXT,
  origin TEXT,
  portrait_url TEXT,
  class_rank TEXT,
  threat_level TEXT,
  relationship TEXT,

  -- D20 Rolls (stored as JSONB)
  background JSONB,
  innate_talent JSONB,
  discipline JSONB,

  -- Stats
  hull INT DEFAULT 0,
  agi INT DEFAULT 0,
  sys INT DEFAULT 0,
  eng INT DEFAULT 0,

  -- Triggers (JSONB object: {trigger_id: points})
  triggers JSONB DEFAULT '{}',

  -- Talents (array of talent IDs)
  talents JSONB DEFAULT '[]',

  -- Specialization
  specialization TEXT,

  -- Motivations & Secrets
  motivations TEXT,
  secrets TEXT,

  -- Mech (placeholder)
  mech_frame TEXT DEFAULT 'Cadet Mark I',
  mech_manufacturer TEXT DEFAULT 'GMS',
  mech_loadout JSONB DEFAULT '{}',

  -- Notes
  notes TEXT
);

-- Allow all operations via anon key (personal GM tool, no auth needed)
ALTER TABLE characters ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all operations" ON characters FOR ALL USING (true) WITH CHECK (true);
