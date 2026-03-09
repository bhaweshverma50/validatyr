ALTER TABLE research_topics
  ADD COLUMN IF NOT EXISTS timezone text DEFAULT 'Asia/Kolkata';
