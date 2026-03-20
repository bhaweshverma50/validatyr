"""API routes for the research feature."""

from fastapi import APIRouter, Depends, HTTPException, Header
from pydantic import BaseModel, field_validator
from typing import List, Literal, Optional
from concurrent.futures import ThreadPoolExecutor
import asyncio
import logging
import os
import re

from services.research_models import ResearchTopic, ResearchReport, ResearchJobStatus
from services.research_db import (
    save_research_topic,
    list_research_topics,
    get_research_topic,
    update_research_topic,
    delete_research_topic,
    list_research_reports,
    get_research_report,
    get_research_job,
    get_latest_job_for_topic,
)
from services.research_pipeline import run_research_pipeline
from services.auth import get_current_user_id
from services.research_scheduler import schedule_topic, unschedule_topic
from services.research_db import get_research_report as _get_report_db

logger = logging.getLogger(__name__)

_executor = ThreadPoolExecutor(max_workers=2)

router = APIRouter()


def _run_pipeline_safe(domain: str, keywords: list, interests: list, topic_id: str, user_id: str = "") -> None:
    """Wrapper that catches and logs pipeline errors (for fire-and-forget calls)."""
    try:
        run_research_pipeline(
            domain=domain,
            keywords=keywords,
            interests=interests,
            topic_id=topic_id,
            user_id=user_id,
        )
    except Exception as e:
        logger.error(f"Background research pipeline failed for topic {topic_id}: {e}", exc_info=True)


_VALID_DOMAINS = Literal["apps", "saas", "hardware", "fintech", "general"]

# Regex patterns for valid schedule_cron strings
_SCHEDULE_RE = re.compile(
    r"^(daily(\|\d{1,2}:\d{2})?)$"          # daily  or  daily|HH:MM
    r"|^(weekly(\|[1-7](\|\d{1,2}:\d{2})?)?)$"  # weekly  or  weekly|D  or  weekly|D|HH:MM
)


def _validate_schedule_cron(v: str | None) -> str | None:
    """Validate schedule_cron format. Returns the value or raises ValueError."""
    if v is not None:
        if not _SCHEDULE_RE.match(v):
            raise ValueError(
                f"Invalid schedule_cron format: '{v}'. "
                "Expected: 'daily', 'daily|HH:MM', 'weekly', 'weekly|1-7', or 'weekly|1-7|HH:MM'"
            )
        # Validate HH:MM ranges
        parts = v.split("|")
        for part in parts[1:]:
            if ":" in part:
                h, m = part.split(":")
                if not (0 <= int(h) <= 23 and 0 <= int(m) <= 59):
                    raise ValueError(f"Invalid time in schedule: '{part}'. Hours must be 0-23, minutes 0-59.")
    return v


class _TimezoneMixin(BaseModel):
    timezone: Optional[str] = None

    @field_validator("timezone")
    @classmethod
    def validate_timezone(cls, v: str | None) -> str | None:
        if v is not None:
            from zoneinfo import ZoneInfo
            try:
                ZoneInfo(v)
            except (KeyError, ValueError):
                raise ValueError(f"Invalid IANA timezone: {v}")
        return v


class CreateTopicRequest(_TimezoneMixin):
    domain: _VALID_DOMAINS
    keywords: List[str] = []
    interests: List[str] = []
    schedule_cron: Optional[str] = None
    start_immediately: bool = True

    @field_validator("schedule_cron")
    @classmethod
    def validate_schedule(cls, v: str | None) -> str | None:
        return _validate_schedule_cron(v)


class UpdateTopicRequest(_TimezoneMixin):
    domain: Optional[str] = None
    keywords: Optional[List[str]] = None
    interests: Optional[List[str]] = None
    schedule_cron: Optional[str] = None
    is_active: Optional[bool] = None

    @field_validator("schedule_cron")
    @classmethod
    def validate_schedule(cls, v: str | None) -> str | None:
        return _validate_schedule_cron(v)


class StartResearchRequest(BaseModel):
    topic_id: str


@router.post("/topics")
async def create_topic(request: CreateTopicRequest, user_id: str = Depends(get_current_user_id)):
    topic_data = {
        "domain": request.domain,
        "keywords": request.keywords,
        "interests": request.interests,
        "schedule_cron": request.schedule_cron,
        "timezone": request.timezone or "Asia/Kolkata",
        "is_active": True,
    }
    result = save_research_topic(user_id, topic_data)
    if result.get("status") == "error":
        raise HTTPException(status_code=500, detail=result.get("message", "Failed to save topic"))

    saved_topic = result.get("data", topic_data)
    topic_id = saved_topic.get("id", "")

    if request.schedule_cron:
        schedule_topic(saved_topic)

    if request.start_immediately and topic_id:
        loop = asyncio.get_running_loop()
        loop.run_in_executor(
            _executor,
            lambda: _run_pipeline_safe(
                domain=request.domain,
                keywords=list(request.keywords),
                interests=list(request.interests),
                topic_id=topic_id,
                user_id=user_id,
            ),
        )

    return {"topic": saved_topic, "research_started": request.start_immediately}


@router.get("/topics")
async def get_topics(user_id: str = Depends(get_current_user_id)):
    topics = list_research_topics(user_id)
    return {"topics": topics}


@router.put("/topics/{topic_id}")
async def update_topic(topic_id: str, request: UpdateTopicRequest, user_id: str = Depends(get_current_user_id)):
    existing = get_research_topic(topic_id)
    if not existing:
        raise HTTPException(status_code=404, detail="Topic not found")

    updates = {k: v for k, v in request.model_dump().items() if v is not None}
    if not updates:
        raise HTTPException(status_code=400, detail="No updates provided")

    result = update_research_topic(topic_id, updates)

    if "schedule_cron" in updates or "is_active" in updates or "timezone" in updates:
        merged = {**existing, **updates}
        if merged.get("is_active") and merged.get("schedule_cron"):
            schedule_topic(merged)
        else:
            unschedule_topic(topic_id)

    return {"topic": result.get("data", updates)}


@router.delete("/topics/{topic_id}")
async def remove_topic(topic_id: str, user_id: str = Depends(get_current_user_id)):
    unschedule_topic(topic_id)
    success = delete_research_topic(topic_id)
    if not success:
        raise HTTPException(status_code=500, detail="Failed to delete topic")
    return {"deleted": True}


@router.post("/cron-trigger")
async def cron_trigger(
    x_cloudscheduler: Optional[str] = Header(None, alias="X-CloudScheduler"),
    x_cron_secret: Optional[str] = Header(None, alias="X-Cron-Secret"),
):
    """Called by Cloud Scheduler to run all due scheduled research topics.

    Cloud Scheduler hits this every 15 minutes. We check which topics
    have a schedule that falls within a ±8 minute window of "now" in the
    user's configured timezone, then run them. A cooldown check prevents
    double-runs (23h for daily, 6 days for weekly).

    Requires X-Cron-Secret header matching CRON_TRIGGER_SECRET env var
    when the env var is set.
    """
    expected_secret = os.getenv("CRON_TRIGGER_SECRET")
    if expected_secret and x_cron_secret != expected_secret:
        raise HTTPException(status_code=403, detail="Invalid or missing X-Cron-Secret header")
    from services.research_db import get_latest_job_for_topic
    from zoneinfo import ZoneInfo
    from datetime import datetime, timezone, timedelta

    topics = list_research_topics(user_id=None)
    started = []

    now_utc = datetime.now(timezone.utc)

    for topic in topics:
        if not topic.get("is_active") or not topic.get("schedule_cron"):
            continue

        topic_id = topic["id"]
        schedule = topic["schedule_cron"]
        parts = schedule.split("|")
        kind = parts[0]

        # Resolve this topic's timezone
        try:
            topic_tz = ZoneInfo(topic.get("timezone") or "Asia/Kolkata")
        except (KeyError, ValueError):
            topic_tz = ZoneInfo("Asia/Kolkata")
        now_local = now_utc.astimezone(topic_tz)

        # --- Cooldown: skip if already ran recently ---
        latest_job = get_latest_job_for_topic(topic_id)
        if latest_job:
            job_created = latest_job.get("created_at", "") or latest_job.get("started_at", "")
            if job_created:
                try:
                    created_dt = datetime.fromisoformat(job_created.replace("Z", "+00:00"))
                    if kind == "daily" and (now_utc - created_dt) < timedelta(hours=23):
                        continue
                    if kind == "weekly" and (now_utc - created_dt) < timedelta(days=6):
                        continue
                except (ValueError, TypeError):
                    pass

        # --- Time-window match (±8 min — fits within the 15-min poll interval) ---
        should_run = False

        if kind == "daily":
            target_h, target_m = (int(x) for x in parts[1].split(":")) if len(parts) >= 2 else (6, 0)
            diff_min = abs((now_local.hour * 60 + now_local.minute) - (target_h * 60 + target_m))
            # Handle midnight wrap-around
            if diff_min > 12 * 60:
                diff_min = 24 * 60 - diff_min
            if diff_min <= 8:
                should_run = True

        elif kind == "weekly":
            dow_map = {1: 0, 2: 1, 3: 2, 4: 3, 5: 4, 6: 5, 7: 6}
            target_dow = dow_map.get(int(parts[1]), 0) if len(parts) >= 2 else 0
            target_h, target_m = (int(x) for x in parts[2].split(":")) if len(parts) >= 3 else (6, 0)
            if now_local.weekday() == target_dow:
                diff_min = abs((now_local.hour * 60 + now_local.minute) - (target_h * 60 + target_m))
                if diff_min > 12 * 60:
                    diff_min = 24 * 60 - diff_min
                if diff_min <= 8:
                    should_run = True

        if not should_run:
            continue

        loop = asyncio.get_running_loop()
        loop.run_in_executor(
            _executor,
            lambda tid=topic_id, t=topic: _run_pipeline_safe(
                domain=t.get("domain", "general"),
                keywords=list(t.get("keywords", [])),
                interests=list(t.get("interests", [])),
                topic_id=tid,
                user_id=t.get("user_id", ""),
            ),
        )
        started.append(topic_id)

    return {"triggered": len(started), "topic_ids": started}


@router.post("/start")
async def start_research(request: StartResearchRequest, user_id: str = Depends(get_current_user_id)):
    topic = get_research_topic(request.topic_id)
    if not topic:
        raise HTTPException(status_code=404, detail="Topic not found")

    loop = asyncio.get_running_loop()
    loop.run_in_executor(
        _executor,
        lambda: _run_pipeline_safe(
            domain=topic.get("domain", "general"),
            keywords=list(topic.get("keywords", [])),
            interests=list(topic.get("interests", [])),
            topic_id=request.topic_id,
            user_id=user_id,
        ),
    )

    return {"message": "Research started", "topic_id": request.topic_id}


@router.get("/status/{job_id}")
async def get_job_status(job_id: str, user_id: str = Depends(get_current_user_id)):
    job = get_research_job(job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    return job


@router.post("/jobs/{job_id}/cancel")
async def cancel_research_job(job_id: str, user_id: str = Depends(get_current_user_id)):
    """Cancel a running research job, stopping it before the next expensive step."""
    from services.research_db import update_research_job
    from services.research_pipeline import research_cancel_events

    job = get_research_job(job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    if job.get("status") not in ("pending", "running"):
        return {"status": job.get("status"), "message": "Job is not running"}

    # Signal the background thread to stop
    ev = research_cancel_events.get(job_id)
    if ev:
        ev.set()
    update_research_job(job_id, {"status": "cancelled"})
    return {"status": "cancelled", "job_id": job_id}


@router.get("/topics/{topic_id}/latest-job")
async def get_latest_job(topic_id: str, user_id: str = Depends(get_current_user_id)):
    job = get_latest_job_for_topic(topic_id)
    return {"job": job}


@router.get("/reports")
async def get_reports(topic_id: str, limit: int = 20, offset: int = 0, user_id: str = Depends(get_current_user_id)):
    reports = list_research_reports(topic_id, limit=limit, offset=offset)
    return {"reports": reports, "limit": limit, "offset": offset}


@router.get("/reports/{report_id}")
async def get_report(report_id: str, user_id: str = Depends(get_current_user_id)):
    report = get_research_report(report_id)
    if not report:
        raise HTTPException(status_code=404, detail="Report not found")
    return report


class ValidateIdeaRequest(BaseModel):
    report_id: str
    idea_index: int = 0


@router.post("/ideas/{idea_id}/validate")
async def validate_research_idea(idea_id: str, request: ValidateIdeaRequest, user_id: str = Depends(get_current_user_id)):
    """Deep-validate a generated research idea using the existing validation pipeline."""
    report = _get_report_db(request.report_id)
    if not report:
        raise HTTPException(status_code=404, detail="Report not found")

    ideas = report.get("ideas", [])
    if request.idea_index < 0 or request.idea_index >= len(ideas):
        raise HTTPException(status_code=404, detail="Idea not found at given index")

    idea = ideas[request.idea_index]
    name = idea.get("name", "")
    one_liner = idea.get("one_liner", "")
    problem = idea.get("problem_statement", "")
    category = idea.get("category", "mobile_app")
    idea_text = f"{name} — {one_liner}. {problem}"

    return {
        "idea_text": idea_text,
        "category": category,
        "idea": idea,
    }


# ---------------------------------------------------------------------------
# Notifications
# ---------------------------------------------------------------------------

@router.get("/notifications")
async def get_notifications(limit: int = 50, offset: int = 0, user_id: str = Depends(get_current_user_id)):
    """Fetch notifications, newest first."""
    from services.db import get_supabase
    supabase = get_supabase()
    if not supabase:
        return {"notifications": []}
    try:
        response = (
            supabase.table("notifications")
            .select("*")
            .eq("user_id", user_id)
            .order("created_at", desc=True)
            .range(offset, offset + limit - 1)
            .execute()
        )
        return {"notifications": response.data or []}
    except Exception as e:
        logger.error(f"Error fetching notifications: {e}")
        return {"notifications": []}


@router.put("/notifications/{notification_id}/read")
async def mark_notification_read(notification_id: int, user_id: str = Depends(get_current_user_id)):
    from services.db import get_supabase
    supabase = get_supabase()
    if not supabase:
        return {"status": "mocked"}
    try:
        supabase.table("notifications").update({"is_read": True}).eq("id", notification_id).execute()
        return {"status": "ok"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.put("/notifications/read-all")
async def mark_all_notifications_read(user_id: str = Depends(get_current_user_id)):
    from services.db import get_supabase
    supabase = get_supabase()
    if not supabase:
        return {"status": "mocked"}
    try:
        supabase.table("notifications").update({"is_read": True}).eq("user_id", user_id).eq("is_read", False).execute()
        return {"status": "ok"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
