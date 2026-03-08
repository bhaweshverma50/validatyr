-- Run this in your Supabase SQL Editor to create the validation_jobs table.
-- Also enable Realtime for polling/subscription support.

CREATE TABLE IF NOT EXISTS validation_jobs (
  id           text PRIMARY KEY,
  idea         text NOT NULL,
  category     text,
  status       text DEFAULT 'pending',  -- pending, running, completed, failed
  current_step text,
  step_number  int DEFAULT 0,
  total_steps  int DEFAULT 6,
  step_message text,
  progress_pct int DEFAULT 0,
  result_id    bigint,                  -- FK to validations.id when complete
  error        text,
  created_at   timestamptz DEFAULT now(),
  completed_at timestamptz
);

-- Enable Realtime (optional, polling is primary reconnection method):
ALTER PUBLICATION supabase_realtime ADD TABLE validation_jobs;
