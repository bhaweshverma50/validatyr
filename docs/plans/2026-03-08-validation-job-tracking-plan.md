# Validation Job Tracking & Reconnection Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Track running validation jobs in Supabase so users can reconnect to live progress after phone lock, and see all running jobs in the History tab.

**Architecture:** New `validation_jobs` Supabase table tracks pipeline state. Backend pipeline creates/updates job rows at each step. Frontend LoadingScreen has two modes: SSE (default) and poll (fallback). History tab pins running jobs at top with pulsing badges. Tapping a running job opens LoadingScreen in poll mode.

**Tech Stack:** Python/FastAPI, Supabase, Flutter/Dart, SSE, HTTP polling

---

### Task 1: Backend DB helpers for validation_jobs

**Files:**
- Modify: `backend/services/db.py:61-76` (add after existing functions)

**Context:** `db.py` already has `get_supabase()`, `save_validation_result()`, and `send_notification()`. All follow the same pattern: get client, mock if None, try/except with logging. The `save_validation_result` function returns `{"status": "success", "data": response.data}` on success with the full Supabase response.

**Step 1: Add `create_validation_job` function to `backend/services/db.py`**

Append to the end of the file:

```python
def create_validation_job(job_id: str, idea: str, category: str | None) -> None:
    """Create a validation_jobs row with status=pending."""
    supabase = get_supabase()
    if not supabase:
        logger.info(f"[MOCKED] Create validation job: {job_id}")
        return
    try:
        supabase.table("validation_jobs").insert({
            "id": job_id,
            "idea": idea,
            "category": category,
            "status": "pending",
        }).execute()
    except Exception as e:
        logger.warning(f"Failed to create validation job: {e}")


def update_validation_job(job_id: str, updates: dict) -> None:
    """Update a validation_jobs row with the given fields."""
    supabase = get_supabase()
    if not supabase:
        logger.info(f"[MOCKED] Update validation job {job_id}: {updates}")
        return
    try:
        supabase.table("validation_jobs").update(updates).eq("id", job_id).execute()
    except Exception as e:
        logger.warning(f"Failed to update validation job: {e}")


def get_validation_job(job_id: str) -> dict | None:
    """Fetch a single validation_jobs row by ID."""
    supabase = get_supabase()
    if not supabase:
        logger.info(f"[MOCKED] Get validation job: {job_id}")
        return None
    try:
        resp = supabase.table("validation_jobs").select("*").eq("id", job_id).maybe_single().execute()
        return resp.data
    except Exception as e:
        logger.warning(f"Failed to get validation job: {e}")
        return None


def list_active_validation_jobs() -> list[dict]:
    """Fetch all validation_jobs with status pending or running, newest first."""
    supabase = get_supabase()
    if not supabase:
        logger.info("[MOCKED] List active validation jobs")
        return []
    try:
        resp = (
            supabase.table("validation_jobs")
            .select("*")
            .in_("status", ["pending", "running"])
            .order("created_at", desc=True)
            .execute()
        )
        return resp.data or []
    except Exception as e:
        logger.warning(f"Failed to list active validation jobs: {e}")
        return []
```

**Step 2: Verify imports are sufficient**

No new imports needed — `db.py` already imports `os`, `logging`, `supabase`, and `dotenv`.

**Step 3: Commit**

```bash
git add backend/services/db.py
git commit -m "feat(jobs): add CRUD helpers for validation_jobs table"
```

---

### Task 2: Backend pipeline — create and update job rows

**Files:**
- Modify: `backend/api/routes.py:1-5` (imports)
- Modify: `backend/api/routes.py:141-300` (`_run_validation_pipeline` function)

**Context:** `_run_validation_pipeline(q, idea, user_category)` runs in a background thread via `_executor.submit()`. It puts SSE-style dicts into `q`. The function already has step tracking with `_put("status", {..., "step": N, "total": total_steps})`. We need to:
1. Generate a `job_id` (UUID) and create a job row at start
2. Send `job_id` as the very first SSE event
3. At each step, update the job row
4. On completion, set `status=completed` with `result_id`
5. On error, set `status=failed` with error message

**Step 1: Add imports to `routes.py`**

Add `import uuid` to the existing imports (after `import logging` on line 24). Add the new DB helpers to the existing import from `services.db` on line 18:

Change line 18 from:
```python
from services.db import save_validation_result, send_notification
```
to:
```python
from services.db import save_validation_result, send_notification, create_validation_job, update_validation_job
```

**Step 2: Modify `_run_validation_pipeline` to track jobs**

Change the function signature on line 141 to accept no new params — the job_id is generated inside. Here is the modified function (replace lines 141–300):

```python
def _run_validation_pipeline(q: _queue.Queue, idea: str, user_category: str | None) -> None:
    """Run the full validation pipeline in a background thread.

    Puts SSE-style dicts into *q*.  Runs independently of the SSE connection
    so the pipeline completes and saves even if the client disconnects.
    """
    total_steps = 6
    job_id = str(uuid.uuid4())

    def _put(event: str, data):
        q.put({"event": event, "data": _json.dumps(data) if isinstance(data, dict) else data})

    def _update_job(step_number: int, agent: str, message: str, status: str = "running"):
        pct = round((step_number / total_steps) * 100) if total_steps else 0
        update_validation_job(job_id, {
            "status": status,
            "current_step": agent,
            "step_number": step_number,
            "step_message": message,
            "progress_pct": min(pct, 99),  # 100 only on completion
        })

    try:
        # Create job row and send job_id as first SSE event
        create_validation_job(job_id, idea, user_category)
        _put("job", {"job_id": job_id})

        api_key = os.getenv("GEMINI_API_KEY")
        if not api_key:
            raise ValueError("GEMINI_API_KEY not set.")
        client = _genai.Client(api_key=api_key)

        # ── Step 1: Category Detection ────────────────────────────────
        _put("status", {"agent": "Category Detector",
             "message": "Classifying your idea..." if not user_category else f"Category set to {user_category}",
             "step": 1, "total": total_steps})
        _update_job(1, "Category Detector", "Classifying your idea..." if not user_category else f"Category set to {user_category}")

        cat_result = detect_category(client, idea, user_category)
        category = cat_result.category
        subcategory = cat_result.subcategory
        _put("category", {"category": category, "subcategory": subcategory,
             "label": _CATEGORY_LABELS.get(category, "Software")})
        _put("status", {"agent": "Category Detector",
             "message": f"Identified: {_CATEGORY_LABELS.get(category, category)} · {subcategory}",
             "step": 1, "total": total_steps})
        _update_job(1, "Category Detector", f"Identified: {_CATEGORY_LABELS.get(category, category)} · {subcategory}")

        # ── Step 2: Discovery ─────────────────────────────────────────
        _put("status", {"agent": "Discovery Agent",
             "message": _DISCOVERY_MESSAGES.get(category, "Finding competitors..."),
             "step": 2, "total": total_steps})
        _update_job(2, "Discovery Agent", _DISCOVERY_MESSAGES.get(category, "Finding competitors..."))

        reviews, competitors_meta = discover_competitors_and_scrape(idea, category)

        _put("status", {"agent": "Discovery Agent",
             "message": f"Found {len(competitors_meta)} competitors.",
             "step": 2, "total": total_steps})
        _update_job(2, "Discovery Agent", f"Found {len(competitors_meta)} competitors.")

        if not reviews and not competitors_meta:
            _put("error", {"message": "No competitors found. Try adding more detail about your idea."})
            update_validation_job(job_id, {"status": "failed", "error": "No competitors found."})
            return

        # ── Step 3: Community Scraping ─────────────────────────────────
        _put("status", {"agent": "Community Scanner",
             "message": _COMMUNITY_MESSAGES.get(category, "Scraping community forums for real user signals..."),
             "step": 3, "total": total_steps})
        _update_job(3, "Community Scanner", _COMMUNITY_MESSAGES.get(category, "Scraping community forums..."))

        community_result = CommunityScraperService(category).scrape_all(
            competitor_names=[c.get("title", "") for c in competitors_meta],
            idea_keywords=idea,
        )
        community_text = _json.dumps([p.model_dump() for p in community_result.posts[:50]])

        _put("status", {"agent": "Community Scanner",
             "message": f"Scraped {community_result.total_posts} posts from {len(community_result.sources_succeeded)} sources.",
             "step": 3, "total": total_steps})
        _update_job(3, "Community Scanner", f"Scraped {community_result.total_posts} posts from {len(community_result.sources_succeeded)} sources.")

        # ── Step 4: Researcher Agent ──────────────────────────────────
        _put("status", {"agent": "Researcher Agent",
             "message": _RESEARCHER_MESSAGES.get(category, "Researching market..."),
             "step": 4, "total": total_steps})
        _update_job(4, "Researcher Agent", _RESEARCHER_MESSAGES.get(category, "Researching market..."))

        reviews_sample = reviews[:200]
        if not reviews_sample and competitors_meta:
            reviews_text = _json.dumps([
                {"title": c.get("title", ""), "description": c.get("description", "")}
                for c in competitors_meta[:20]
            ])
        else:
            reviews_text = _json.dumps([
                {"rating": r["score"], "review": r["content"]} for r in reviews_sample
            ])

        researcher_result = run_researcher_agent(client, idea, reviews_text, category, community_text)

        _put("status", {"agent": "Researcher Agent",
             "message": f"Found {len(researcher_result.what_users_hate)} pain points, {len(researcher_result.community_signals)} community signals.",
             "step": 4, "total": total_steps})
        _update_job(4, "Researcher Agent", f"Found {len(researcher_result.what_users_hate)} pain points, {len(researcher_result.community_signals)} community signals.")

        # ── Step 5: PM Agent ──────────────────────────────────────────
        _put("status", {"agent": "PM Agent",
             "message": "Building Day-1 MVP roadmap from pain points...",
             "step": 5, "total": total_steps})
        _update_job(5, "PM Agent", "Building Day-1 MVP roadmap from pain points...")

        pm_result = run_pm_agent(client, idea, researcher_result)

        _put("status", {"agent": "PM Agent",
             "message": f"MVP roadmap ready — {len(pm_result.mvp_roadmap)} features.",
             "step": 5, "total": total_steps})
        _update_job(5, "PM Agent", f"MVP roadmap ready — {len(pm_result.mvp_roadmap)} features.")

        # ── Step 6: Market Intelligence ───────────────────────────────
        _put("status", {"agent": "Market Intelligence",
             "message": "Researching TAM/SAM/SOM, funded competitors, GTM strategy...",
             "step": 6, "total": total_steps})
        _update_job(6, "Market Intelligence", "Researching TAM/SAM/SOM, funded competitors, GTM strategy...")

        market_result = run_market_intelligence_agent(client, idea, researcher_result, pm_result, category)

        # Compute weighted score
        breakdown = market_result.score_breakdown
        weights = {
            "pain_severity": 0.25, "market_gap": 0.20, "mvp_feasibility": 0.15,
            "competition_density": 0.15, "monetization_potential": 0.10,
            "community_demand": 0.10, "startup_saturation": 0.05,
        }
        opportunity_score = max(0, min(100, round(sum(
            getattr(breakdown, k) * v for k, v in weights.items()
        ))))

        funded_competitors_dicts = [fc.model_dump() for fc in market_result.top_funded_competitors]

        final_result = IdeaValidationResult(
            category=category,
            subcategory=subcategory,
            opportunity_score=opportunity_score,
            score_breakdown=breakdown.model_dump(),
            what_users_love=researcher_result.what_users_love,
            what_users_hate=researcher_result.what_users_hate,
            mvp_roadmap=pm_result.mvp_roadmap,
            pricing_suggestion=market_result.pricing_suggestion,
            target_platform_recommendation=market_result.target_platform_recommendation,
            market_breakdown=market_result.market_breakdown,
            competitors_analyzed=competitors_meta or [],
            community_signals=researcher_result.community_signals,
            tam=market_result.tam,
            sam=market_result.sam,
            som=market_result.som,
            revenue_model_options=market_result.revenue_model_options,
            top_funded_competitors=funded_competitors_dicts,
            funding_landscape=market_result.funding_landscape,
            go_to_market_strategy=market_result.go_to_market_strategy,
        )

        _put("status", {"agent": "Market Intelligence",
             "message": f"Score: {opportunity_score}/100 · TAM: {(market_result.tam or '')[:50]}",
             "step": 6, "total": total_steps})

        # Save to DB — runs regardless of whether SSE client is still connected
        result_id = None
        try:
            save_resp = save_validation_result(idea, final_result.model_dump())
            # Extract the row ID from Supabase response for the job link
            if save_resp.get("status") == "success" and save_resp.get("data"):
                rows = save_resp["data"]
                if isinstance(rows, list) and rows:
                    result_id = rows[0].get("id")
            send_notification(
                type="validation_complete",
                title="Validation Complete",
                body=f"'{idea[:50]}' scored {opportunity_score}/100",
                metadata={"score": opportunity_score},
            )
        except Exception as db_err:
            logger.warning(f"Failed to save validation result: {db_err}")

        # Mark job completed with link to the saved validation row
        update_validation_job(job_id, {
            "status": "completed",
            "progress_pct": 100,
            "result_id": result_id,
            "completed_at": "now()",
        })

        _put("result", final_result.model_dump_json())

    except Exception as e:
        logger.error(f"Pipeline error: {e}", exc_info=True)
        _put("error", {"message": str(e)})
        update_validation_job(job_id, {"status": "failed", "error": str(e)})
    finally:
        # Sentinel so the SSE generator knows the pipeline is done
        q.put(None)
```

**Important notes for implementer:**
- The `completed_at` field uses `"now()"` — this is a Supabase/Postgres function that resolves server-side. If this doesn't work with the Python Supabase client, use `datetime.datetime.now(datetime.timezone.utc).isoformat()` instead (add `import datetime` at top).
- The `result_id` extraction depends on `save_validation_result` returning `{"status": "success", "data": [{"id": 123, ...}]}`. Check the actual response shape.

**Step 3: Commit**

```bash
git add backend/api/routes.py
git commit -m "feat(jobs): track validation pipeline in validation_jobs table"
```

---

### Task 3: Backend API endpoints for job listing and detail

**Files:**
- Modify: `backend/api/routes.py:303-328` (add new endpoints after `validate_idea_stream`)

**Context:** The router is at `router = APIRouter()` (line 60). All routes are prefixed with `/api/v1` by `main.py`. We need two new GET endpoints.

**Step 1: Add `GET /validation-jobs` and `GET /validation-jobs/{job_id}` endpoints**

Add these after the existing `validate_idea_stream` endpoint (after line 328):

```python
@router.get("/validation-jobs")
async def list_validation_jobs():
    """List all active (pending/running) validation jobs."""
    from services.db import list_active_validation_jobs
    jobs = list_active_validation_jobs()
    return {"jobs": jobs}


@router.get("/validation-jobs/{job_id}")
async def get_validation_job_status(job_id: str):
    """Get a single validation job's current status."""
    from services.db import get_validation_job
    job = get_validation_job(job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    return job
```

**Step 2: Verify by running the backend**

```bash
cd backend && source venv/bin/activate && python -c "from api.routes import router; print('OK')"
```

Expected: `OK` (no import errors)

**Step 3: Commit**

```bash
git add backend/api/routes.py
git commit -m "feat(jobs): add GET endpoints for validation job status"
```

---

### Task 4: SQL migration for validation_jobs table

**Files:**
- Create: `docs/plans/validation-jobs-table.sql`

**Context:** The table schema is defined in the design doc. This SQL needs to be run in Supabase SQL Editor.

**Step 1: Create the SQL migration file**

```sql
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
```

**Step 2: Commit**

```bash
git add docs/plans/validation-jobs-table.sql
git commit -m "docs: add SQL migration for validation_jobs table"
```

---

### Task 5: Frontend API methods for validation jobs

**Files:**
- Modify: `frontend/lib/services/api_service.dart:82-102` (add new methods before closing brace)

**Context:** `ApiService` is a static-only class in `api_service.dart`. The `_baseUrl` getter (line 6-8) builds `http://$host:8000/api/v1`. We also need to add a method to `SupabaseService` to fetch a validation by its row ID (for when poll mode sees `status=completed` with a `result_id`).

**Step 1: Add job polling methods to `ApiService`**

Add before the closing `}` of `ApiService` (before line 102):

```dart
  /// Fetch all active (pending/running) validation jobs.
  static Future<List<Map<String, dynamic>>> fetchActiveJobs() async {
    try {
      final resp = await http.get(Uri.parse('$_baseUrl/validation-jobs'))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(body['jobs'] as List);
      }
    } catch (_) {}
    return [];
  }

  /// Fetch a single validation job by ID (for poll mode).
  static Future<Map<String, dynamic>?> fetchValidationJob(String jobId) async {
    try {
      final resp = await http.get(Uri.parse('$_baseUrl/validation-jobs/$jobId'))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }
```

**Step 2: Add `fetchById` to `SupabaseService`**

Add to `frontend/lib/services/supabase_service.dart` before the closing `}` (before line 61):

```dart
  /// Fetch a single validation by its row ID.
  static Future<Map<String, dynamic>?> fetchById(dynamic id) async {
    final response = await _client
        .from('validations')
        .select()
        .eq('id', id)
        .maybeSingle();
    return response as Map<String, dynamic>?;
  }
```

**Step 3: Commit**

```bash
git add frontend/lib/services/api_service.dart frontend/lib/services/supabase_service.dart
git commit -m "feat(jobs): add API methods for job polling and validation fetch by ID"
```

---

### Task 6: Frontend LoadingScreen — poll mode and SSE-to-poll fallback

**Files:**
- Modify: `frontend/lib/features/loading/loading_screen.dart`

**Context:** Currently `LoadingScreen` takes `idea` and optional `category`. It starts an SSE stream in `initState` and shows progress. We need to add:
1. Optional `jobId` parameter for poll mode
2. Store `job_id` from first SSE `job` event
3. On SSE drop, switch to poll mode instead of showing error
4. Poll mode: call `ApiService.fetchValidationJob` every 2s, update UI, navigate on completion

**Step 1: Modify `LoadingScreen` constructor and add poll mode**

Replace the entire `loading_screen.dart` with this updated version. Key changes marked with `// NEW` or `// CHANGED`:

Add `import '../../services/supabase_service.dart';` to imports (line 8).

Change the `LoadingScreen` widget class (lines 22-28):

```dart
class LoadingScreen extends StatefulWidget {
  final String idea;
  final String? category;
  final String? jobId;  // NEW: if set, starts in poll mode
  const LoadingScreen({super.key, required this.idea, this.category, this.jobId});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}
```

In `_LoadingScreenState`, add these fields after `_wasBackgrounded` (line 51):

```dart
  String? _jobId;           // Stored from SSE 'job' event or constructor
  Timer? _pollTimer;        // Poll timer for reconnection mode
  bool _isPolling = false;  // Whether we're in poll mode
```

Add `import 'dart:async';` if not already present (it is — line 1). Add Timer to the existing import.

In `initState`, change the startup logic (after `_stepStates.add(_StepState.active);` on line 68):

```dart
    // Start in poll mode if jobId provided, otherwise SSE mode
    _jobId = widget.jobId;
    if (_jobId != null) {
      _startPolling();
    } else {
      _startStream();
    }
```

In `dispose`, add timer cleanup:

```dart
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _pollTimer?.cancel();
    _progressCtrl.dispose();
    super.dispose();
  }
```

In `didChangeAppLifecycleState`, change the resumed handler (lines 85-94) to switch to polling instead of showing error:

```dart
    if (state == AppLifecycleState.resumed && _wasBackgrounded && !_hasResult) {
      _wasBackgrounded = false;
      // SSE likely broke while backgrounded — switch to poll mode if we have a job ID
      if (!_hasError && !_isPolling && _jobId != null && mounted) {
        _sub?.cancel();
        _startPolling();
      }
    }
```

In `_onEvent`, handle the new `job` event type. Add this case at the top of the method (after `if (!mounted) return;`):

```dart
    if (event.event == 'job') {
      _jobId = event.data['job_id'] as String?;
      return;  // Don't update UI for this meta-event
    }
```

Change the `_startStream` `onDone` callback (lines 111-118) to fallback to polling:

```dart
      onDone: () {
        if (mounted && !_hasError && !_hasResult) {
          if (_jobId != null) {
            // SSE dropped but we have a job ID — switch to poll mode
            _startPolling();
          } else {
            _setError(
              'Connection closed unexpectedly. '
              'If analysis was in progress, results may still be saved — check History.',
            );
          }
        }
      },
```

Also change the `onError` callback to fallback to polling:

```dart
      onError: (e) {
        if (_jobId != null && !_hasResult) {
          _startPolling();
        } else {
          _setError(e.toString());
        }
      },
```

Add the new `_startPolling` method after `_startStream`:

```dart
  void _startPolling() {
    if (_isPolling || _jobId == null) return;
    setState(() => _isPolling = true);
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pollJob());
    _pollJob(); // Immediate first poll
  }

  Future<void> _pollJob() async {
    if (!mounted || _hasResult || _hasError) {
      _pollTimer?.cancel();
      return;
    }
    final job = await ApiService.fetchValidationJob(_jobId!);
    if (job == null || !mounted) return;

    final status = job['status'] as String? ?? 'pending';
    final stepNum = (job['step_number'] as int?) ?? 0;
    final total = (job['total_steps'] as int?) ?? 6;
    final agent = job['current_step'] as String? ?? '';
    final msg = job['step_message'] as String? ?? '';

    if (status == 'completed') {
      _pollTimer?.cancel();
      _hasResult = true;
      setState(() {
        for (int i = 0; i < _stepStates.length; i++) {
          _stepStates[i] = _StepState.done;
        }
      });
      _animateTo(1.0);
      // Fetch the full result by result_id
      final resultId = job['result_id'];
      if (resultId != null) {
        final result = await SupabaseService.fetchById(resultId);
        if (result != null && mounted) {
          await Future.delayed(const Duration(milliseconds: 400));
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ResultsScreen(result: result, saveToHistory: false),
            ),
          );
          return;
        }
      }
      // Fallback: couldn't fetch result, go to history
      if (mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
      return;
    }

    if (status == 'failed') {
      _pollTimer?.cancel();
      _setError(job['error'] as String? ?? 'Validation failed');
      return;
    }

    // Update step UI from poll data
    if (stepNum > 0 && agent.isNotEmpty) {
      final stepIdx = stepNum - 1;
      setState(() {
        _totalSteps = total;
        while (_stepNames.length <= stepIdx) {
          _stepNames.add('');
          _stepMessages.add('');
          _stepStates.add(_StepState.pending);
        }
        _stepNames[stepIdx] = agent;
        _stepMessages[stepIdx] = msg;
        for (int i = 0; i < stepIdx; i++) {
          _stepStates[i] = _StepState.done;
        }
        _stepStates[stepIdx] = _StepState.active;
      });
      _animateTo((stepIdx + 0.5) / _totalSteps);
    }
  }
```

**Step 2: Verify no compile errors**

```bash
cd frontend && flutter analyze lib/features/loading/loading_screen.dart
```

Expected: No errors

**Step 3: Commit**

```bash
git add frontend/lib/features/loading/loading_screen.dart
git commit -m "feat(jobs): add poll mode and SSE-to-poll fallback in LoadingScreen"
```

---

### Task 7: Frontend History tab — show running jobs pinned at top

**Files:**
- Modify: `frontend/lib/features/history/history_screen.dart`

**Context:** `HistoryScreen` currently loads completed validations from `SupabaseService.fetchHistory()`. We need to also fetch active jobs from `ApiService.fetchActiveJobs()`, show them pinned at the top in a "RUNNING" section with pulsing indicators, and auto-refresh every 5s while any job is running. Tapping a running job opens `LoadingScreen(jobId: ...)`.

**Step 1: Add imports**

Add to the top of `history_screen.dart`:

```dart
import 'dart:async';
import '../../services/api_service.dart';
import '../loading/loading_screen.dart';
```

**Step 2: Add running jobs state and auto-refresh timer**

In `HistoryScreenState`, add after `_errorMessage` (line 19-20):

```dart
  List<Map<String, dynamic>> _runningJobs = [];
  Timer? _autoRefreshTimer;
```

**Step 3: Modify `_load` to also fetch active jobs**

Replace the body of `_load` (lines 31-55):

```dart
  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      // Fetch active jobs and completed validations in parallel
      final results = await Future.wait([
        ApiService.fetchActiveJobs(),
        SupabaseService.fetchHistory(),
      ]);
      if (mounted) {
        setState(() {
          _runningJobs = results[0];
          _items = results[1];
          _isLoading = false;
          _errorMessage = null;
        });
        _manageAutoRefresh();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }
```

**Step 4: Add auto-refresh management**

Add after `_load`:

```dart
  void _manageAutoRefresh() {
    if (_runningJobs.isNotEmpty) {
      // Start auto-refresh if not already running
      _autoRefreshTimer ??= Timer.periodic(
        const Duration(seconds: 5),
        (_) => _load(silent: true),
      );
    } else {
      _autoRefreshTimer?.cancel();
      _autoRefreshTimer = null;
    }
  }
```

Update `dispose`:

```dart
  @override
  void dispose() {  // Add this override (currently not present)
    _autoRefreshTimer?.cancel();
    super.dispose();
  }
```

Wait — `HistoryScreen` doesn't have a `dispose` override yet. Add one after `initState`.

**Step 5: Modify `_buildBody` to show running jobs section**

In `_buildBody`, after the empty check (line 204-216), change the return statement. Replace the `return RefreshIndicator(...)` block (lines 218-230) with:

```dart
    return RefreshIndicator(
      color: Colors.black,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: RetroTheme.contentPaddingMobile,
          vertical: RetroTheme.spacingMd,
        ),
        children: [
          // Running jobs section
          if (_runningJobs.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('RUNNING',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: Colors.black54)),
            ),
            ..._runningJobs.map((job) => Padding(
              padding: const EdgeInsets.only(bottom: RetroTheme.spacingMd),
              child: _buildRunningJobCard(job),
            )),
            if (_items.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 4, bottom: 8),
                child: Text('COMPLETED',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: Colors.black54)),
              ),
          ],
          // Completed validations
          ..._items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: RetroTheme.spacingMd),
            child: _buildItem(item),
          )),
        ],
      ),
    );
```

Also update the empty check to account for running jobs:

```dart
    if (_items.isEmpty && _runningJobs.isEmpty) {
```

**Step 6: Add `_buildRunningJobCard` widget**

Add this method after `_buildItem`:

```dart
  Widget _buildRunningJobCard(Map<String, dynamic> job) {
    final idea = job['idea'] as String? ?? '';
    final agent = job['current_step'] as String? ?? 'Starting...';
    final stepNum = (job['step_number'] as int?) ?? 0;
    final total = (job['total_steps'] as int?) ?? 6;
    final displayIdea = idea.length > 60 ? '${idea.substring(0, 60)}...' : idea;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LoadingScreen(
              idea: idea,
              category: job['category'] as String?,
              jobId: job['id'] as String,
            ),
          ),
        ).then((_) => _load(silent: true));  // Refresh when coming back
      },
      child: RetroCard(
        backgroundColor: RetroTheme.yellow.withAlpha(60),
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          // Pulsing indicator
          const _PulsingDot(),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(displayIdea,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.3)),
              const SizedBox(height: 4),
              Text('$agent · Step $stepNum/$total',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54)),
            ],
          )),
          const Icon(LucideIcons.chevronRight, size: 18, color: Colors.black38),
        ]),
      ),
    );
  }
```

**Step 7: Add `_PulsingDot` widget at the bottom of the file**

Add before the closing of the file, after `_SmallBtnState`:

```dart
class _PulsingDot extends StatefulWidget {
  const _PulsingDot();
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.3, end: 1.0).animate(_ctrl),
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: RetroTheme.yellow,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black, width: 1.5),
        ),
      ),
    );
  }
}
```

**Step 8: Verify no compile errors**

```bash
cd frontend && flutter analyze lib/features/history/history_screen.dart
```

Expected: No errors

**Step 9: Commit**

```bash
git add frontend/lib/features/history/history_screen.dart
git commit -m "feat(jobs): show running jobs pinned at top of History tab with auto-refresh"
```

---

### Summary of all tasks

| Task | What | Files |
|------|------|-------|
| 1 | DB helpers for validation_jobs | `backend/services/db.py` |
| 2 | Pipeline creates/updates job rows | `backend/api/routes.py` |
| 3 | GET endpoints for job status | `backend/api/routes.py` |
| 4 | SQL migration file | `docs/plans/validation-jobs-table.sql` |
| 5 | Frontend API methods for jobs | `api_service.dart`, `supabase_service.dart` |
| 6 | LoadingScreen poll mode + fallback | `loading_screen.dart` |
| 7 | History tab running jobs section | `history_screen.dart` |

### Post-implementation: Manual testing checklist

1. Run `validation-jobs-table.sql` in Supabase SQL Editor
2. Start backend: `cd backend && source venv/bin/activate && uvicorn main:app --reload`
3. Run app: `cd frontend && flutter run -d macos`
4. Submit an idea — verify job_id appears in first SSE event (check backend logs)
5. Check Supabase `validation_jobs` table — row should update at each step
6. While validating, switch to History tab — running job should appear with pulsing dot
7. Tap running job — should open LoadingScreen in poll mode showing current progress
8. Lock phone during validation — unlock and verify it reconnects via polling
9. After completion, History tab should move the job from "RUNNING" to "COMPLETED"
