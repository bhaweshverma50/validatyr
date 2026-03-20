-- 002_add_auth_and_user_isolation.sql
-- Run in Supabase SQL Editor (Dashboard -> SQL Editor -> New Query)
--
-- This migration:
--   1. Truncates all existing data
--   2. Adds user_id (UUID, NOT NULL, FK to auth.users) to all 7 tables
--   3. Creates indexes on user_id
--   4. Enables RLS on all 7 tables
--   5. Drops old permissive anon policies
--   6. Creates per-user RLS policies for the authenticated role
--
-- NOTE: service_role bypasses RLS by default in Supabase, so no extra
-- policy is needed for cron jobs or backend service calls that use the
-- service_role key.

BEGIN;

-- ============================================================
-- 1. TRUNCATE all existing data
-- ============================================================
TRUNCATE
  public.research_jobs,
  public.research_reports,
  public.research_topics,
  public.validation_jobs,
  public.validations,
  public.notifications,
  public.push_tokens
  RESTART IDENTITY CASCADE;

-- ============================================================
-- 2. ADD user_id column to all 7 tables
-- ============================================================
ALTER TABLE public.validations
  ADD COLUMN user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.validation_jobs
  ADD COLUMN user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.research_topics
  ADD COLUMN user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.research_jobs
  ADD COLUMN user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.research_reports
  ADD COLUMN user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.notifications
  ADD COLUMN user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.push_tokens
  ADD COLUMN user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE;

-- ============================================================
-- 3. CREATE indexes on user_id for all 7 tables
-- ============================================================
CREATE INDEX idx_validations_user_id ON public.validations(user_id);
CREATE INDEX idx_validation_jobs_user_id ON public.validation_jobs(user_id);
CREATE INDEX idx_research_topics_user_id ON public.research_topics(user_id);
CREATE INDEX idx_research_jobs_user_id ON public.research_jobs(user_id);
CREATE INDEX idx_research_reports_user_id ON public.research_reports(user_id);
CREATE INDEX idx_notifications_user_id ON public.notifications(user_id);
CREATE INDEX idx_push_tokens_user_id ON public.push_tokens(user_id);

-- ============================================================
-- 4. ENABLE RLS on all 7 tables
-- ============================================================
ALTER TABLE public.validations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.validation_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.research_topics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.research_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.research_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.push_tokens ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- 5. DROP old permissive anon policies
-- ============================================================
DROP POLICY IF EXISTS "Allow anon full access to validations" ON public.validations;
DROP POLICY IF EXISTS "Allow anon full access to validation_jobs" ON public.validation_jobs;
DROP POLICY IF EXISTS "Allow anon full access" ON public.research_topics;
DROP POLICY IF EXISTS "Allow anon full access" ON public.research_jobs;
DROP POLICY IF EXISTS "Allow anon full access" ON public.research_reports;
DROP POLICY IF EXISTS "Allow anon full access" ON public.notifications;
DROP POLICY IF EXISTS "Allow anon full access" ON public.push_tokens;

-- ============================================================
-- 6. CREATE per-user RLS policies for authenticated role
-- ============================================================
CREATE POLICY "Authenticated user access to validations"
  ON public.validations
  FOR ALL
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Authenticated user access to validation_jobs"
  ON public.validation_jobs
  FOR ALL
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Authenticated user access to research_topics"
  ON public.research_topics
  FOR ALL
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Authenticated user access to research_jobs"
  ON public.research_jobs
  FOR ALL
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Authenticated user access to research_reports"
  ON public.research_reports
  FOR ALL
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Authenticated user access to notifications"
  ON public.notifications
  FOR ALL
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Authenticated user access to push_tokens"
  ON public.push_tokens
  FOR ALL
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

COMMIT;
