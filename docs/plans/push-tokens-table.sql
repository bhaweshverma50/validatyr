-- Run this in your Supabase SQL Editor to create a table for FCM/APNs device tokens.

CREATE TABLE IF NOT EXISTS push_tokens (
  token       text PRIMARY KEY,
  platform    text NOT NULL,
  created_at  timestamptz DEFAULT now(),
  updated_at  timestamptz DEFAULT now()
);
