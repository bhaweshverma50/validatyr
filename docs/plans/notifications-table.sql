-- Run this in your Supabase SQL Editor to create the notifications table.
-- Also enable Realtime on this table in the Supabase Dashboard:
--   Database → Replication → Enable for 'notifications' table

CREATE TABLE IF NOT EXISTS notifications (
  id          bigserial PRIMARY KEY,
  type        text NOT NULL,
  title       text NOT NULL,
  body        text NOT NULL,
  metadata    jsonb DEFAULT '{}',
  is_read     boolean DEFAULT false,
  created_at  timestamptz DEFAULT now()
);

-- Enable Realtime (run in SQL editor):
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;
