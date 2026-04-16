-- Migration: auth profiles, trucks, and link emissions to users/trucks

-- Profiles table (drivers + admins)
CREATE TABLE IF NOT EXISTS profiles (
  id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  phone       TEXT,
  role        TEXT NOT NULL DEFAULT 'driver', -- 'driver' or 'admin'
  dob         DATE,
  location    TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Trucks table
CREATE TABLE IF NOT EXISTS trucks (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name         TEXT NOT NULL,
  plate_number TEXT NOT NULL,
  driver_id    UUID REFERENCES profiles(id),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Add user/truck columns to emissions
ALTER TABLE emissions ADD COLUMN IF NOT EXISTS user_id    UUID REFERENCES profiles(id);
ALTER TABLE emissions ADD COLUMN IF NOT EXISTS truck_id   UUID REFERENCES trucks(id);
ALTER TABLE emissions ADD COLUMN IF NOT EXISTS driver_name TEXT;

-- RLS policies
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE trucks ENABLE ROW LEVEL SECURITY;

-- Drivers can read/write their own profile
CREATE POLICY "profiles_own" ON profiles FOR ALL USING (auth.uid() = id);

-- Admins can read all profiles
CREATE POLICY "profiles_admin_read" ON profiles FOR SELECT USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);

-- Everyone can read trucks
CREATE POLICY "trucks_read" ON trucks FOR SELECT USING (true);

-- Admins can manage trucks
CREATE POLICY "trucks_admin_write" ON trucks FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);
