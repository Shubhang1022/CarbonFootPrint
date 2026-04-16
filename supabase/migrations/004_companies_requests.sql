-- Companies table
CREATE TABLE IF NOT EXISTS companies (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name       TEXT NOT NULL UNIQUE,
  owner_id   UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Driver join requests
CREATE TABLE IF NOT EXISTS driver_requests (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id   UUID REFERENCES profiles(id) ON DELETE CASCADE,
  company_id  UUID REFERENCES companies(id) ON DELETE CASCADE,
  status      TEXT NOT NULL DEFAULT 'pending', -- pending / accepted / rejected
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(driver_id, company_id)
);

-- Add company_id and truck_number to profiles
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS company_id   UUID REFERENCES companies(id);
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS truck_number TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS status       TEXT DEFAULT 'pending'; -- pending/accepted

-- Add company_id to emissions
ALTER TABLE emissions ADD COLUMN IF NOT EXISTS company_id UUID REFERENCES companies(id);
