-- ═══════════════════════════════════════════════════════════════
--  AEGIS PRIME — GRADUATION CREDITS MIGRATION
--  Run this in your Supabase SQL Editor.
-- ═══════════════════════════════════════════════════════════════

ALTER TABLE characters 
ADD COLUMN IF NOT EXISTS credits INT DEFAULT 0;
