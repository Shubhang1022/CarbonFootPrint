-- Migration: create emissions table
-- Feature: carbon-chain

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE IF NOT EXISTS emissions (
  id          UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  distance    FLOAT         NOT NULL,
  idle_time   FLOAT         NOT NULL,
  fuel_type   TEXT          NOT NULL,
  carbon_kg   FLOAT         NOT NULL,
  created_at  TIMESTAMPTZ   NOT NULL DEFAULT now()
);
