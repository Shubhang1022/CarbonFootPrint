-- Migration: add engine_efficiency column to emissions table
ALTER TABLE emissions ADD COLUMN IF NOT EXISTS engine_efficiency FLOAT NOT NULL DEFAULT 10;
