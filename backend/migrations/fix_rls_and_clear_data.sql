-- Fix RLS policies to allow DELETE for anon role on validations and validation_jobs
-- Run this in Supabase SQL Editor (Dashboard → SQL Editor → New Query)

-- 1. Enable RLS if not already (safe to run even if already enabled)
ALTER TABLE public.validations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.validation_jobs ENABLE ROW LEVEL SECURITY;

-- 2. Drop existing restrictive policies (ignore errors if they don't exist)
DROP POLICY IF EXISTS "Allow anon full access to validations" ON public.validations;
DROP POLICY IF EXISTS "Allow anon select validations" ON public.validations;
DROP POLICY IF EXISTS "Allow anon insert validations" ON public.validations;
DROP POLICY IF EXISTS "Allow anon delete validations" ON public.validations;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.validations;
DROP POLICY IF EXISTS "Enable insert for all users" ON public.validations;

DROP POLICY IF EXISTS "Allow anon full access to validation_jobs" ON public.validation_jobs;
DROP POLICY IF EXISTS "Allow anon select validation_jobs" ON public.validation_jobs;
DROP POLICY IF EXISTS "Allow anon insert validation_jobs" ON public.validation_jobs;
DROP POLICY IF EXISTS "Allow anon delete validation_jobs" ON public.validation_jobs;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.validation_jobs;
DROP POLICY IF EXISTS "Enable insert for all users" ON public.validation_jobs;

-- 3. Create permissive policies for anon role (SELECT, INSERT, UPDATE, DELETE)
CREATE POLICY "Allow anon full access to validations"
  ON public.validations
  FOR ALL
  TO anon
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Allow anon full access to validation_jobs"
  ON public.validation_jobs
  FOR ALL
  TO anon
  USING (true)
  WITH CHECK (true);

-- 4. Clear all existing data
TRUNCATE public.validation_jobs;
TRUNCATE public.validations RESTART IDENTITY;

-- Done! The app can now delete rows properly.
