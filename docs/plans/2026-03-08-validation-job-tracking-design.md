# Validation Job Tracking & Reconnection Design

**Date:** 2026-03-08
**Status:** Approved

## Overview

Add validation job tracking so the pipeline survives phone lock with full reconnection. Running jobs appear in the History tab with live progress. Tapping a running job reconnects to its progress screen.

## Backend

### New Supabase table: `validation_jobs`

```sql
CREATE TABLE validation_jobs (
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

ALTER PUBLICATION supabase_realtime ADD TABLE validation_jobs;
```

### Pipeline changes (`backend/api/routes.py`)

`_run_validation_pipeline` changes:
1. At start: create `validation_jobs` row with status=pending, idea, category
2. At each step: update row with current_step, step_number, step_message, progress_pct
3. On completion: save to `validations`, update job with status=completed, result_id pointing to the saved validation row
4. On error: update job with status=failed, error message
5. Put `job_id` into the queue as the very first event so the SSE generator can send it to the frontend

### New DB helpers (`backend/services/db.py`)

```python
def create_validation_job(job_id, idea, category): ...
def update_validation_job(job_id, updates): ...
def get_validation_job(job_id): ...
def list_active_validation_jobs(): ...
```

### New API endpoints

- `GET /api/v1/validation-jobs` — list running/pending jobs (for History tab)
- `GET /api/v1/validation-jobs/{job_id}` — single job status (for loading screen polling)

### SSE first event

The `/validate/stream` endpoint sends a `job` event first:
```json
{"event": "job", "data": {"job_id": "uuid-here"}}
```

## Frontend

### History tab (`history_screen.dart`)

- On load: fetch both active `validation_jobs` AND completed `validations`
- **Top section:** "RUNNING" header with running job cards pinned at top
  - Each card: idea text (truncated), current agent name, step X/6, pulsing indicator
  - Tap opens `LoadingScreen(jobId: ...)` in poll mode
- **Below:** existing completed validation cards unchanged
- Auto-refresh every 5s while any job is running (timer-based)
- Pull-to-refresh still works for manual refresh

### Loading screen (`loading_screen.dart`)

**New constructor parameter:** `jobId` (optional String)

**Two modes:**

1. **SSE mode** (default, when `jobId` is null):
   - Starts SSE stream as before
   - On first `job` event, stores the `job_id`
   - If SSE drops (phone lock / `onDone` / error), switches to poll mode using stored `job_id` instead of showing error card

2. **Poll mode** (when `jobId` is provided, or after SSE drops):
   - Calls `GET /validation-jobs/{jobId}` every 2s
   - Updates step list from response (current_step, step_number, step_message)
   - When status=completed: fetch result from `validations` by `result_id`, navigate to `ResultsScreen`
   - When status=failed: show error card with the error message

### Data flow

```
User submits idea
    │
    ▼
POST /validate/stream
    ├─► Creates validation_job row (status=pending)
    ├─► Returns job_id in first SSE event
    └─► Fires pipeline in background thread
            ├─ Each step: UPDATE validation_jobs
            ├─ On complete: save to validations, SET status=completed, result_id
            └─ On error: SET status=failed, error

Frontend (SSE connected):
    Reads from SSE queue, shows live progress
    Stores job_id from first event

Frontend (SSE drops):
    Switches to poll mode using stored job_id
    Polls GET /validation-jobs/{job_id} every 2s
    When completed → fetches result → ResultsScreen

History tab:
    Fetches active validation_jobs + completed validations
    Running jobs pinned at top with pulsing badge
    Tap → LoadingScreen(jobId) in poll mode
    Auto-refreshes every 5s while jobs running
```

## Dependencies

- No new Flutter packages needed
- Supabase table migration required
- Supabase Realtime enabled on `validation_jobs` (optional, polling is primary)
