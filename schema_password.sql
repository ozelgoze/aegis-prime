-- Add password column to characters table
-- Run this in your Supabase SQL Editor
ALTER TABLE characters ADD COLUMN IF NOT EXISTS password TEXT;
