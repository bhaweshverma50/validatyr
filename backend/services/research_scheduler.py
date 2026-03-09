"""APScheduler integration for scheduled research jobs.

Manages cron-style jobs for saved research topics. Each topic with a
schedule_cron ('daily' or 'weekly') gets an APScheduler job that triggers
the research pipeline on schedule.

Runs in-process within the FastAPI server — no Redis/Celery needed.
Disabled when CLOUD_SCHEDULER_ENABLED=true (Cloud Run deployments use the
/cron-trigger endpoint instead).
"""

import asyncio
import logging
import os
from concurrent.futures import ThreadPoolExecutor
from zoneinfo import ZoneInfo
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger

from services.research_db import list_research_topics, get_research_topic
from services.research_pipeline import run_research_pipeline
from services.db import send_notification

_executor = ThreadPoolExecutor(max_workers=2)

logger = logging.getLogger(__name__)

_scheduler: AsyncIOScheduler | None = None

# Default timezone used when a topic does not carry its own timezone field.
_DEFAULT_TZ = "Asia/Kolkata"


def get_scheduler() -> AsyncIOScheduler:
    global _scheduler
    if _scheduler is None:
        # The scheduler itself runs in UTC; individual jobs carry their own
        # per-topic timezone via the CronTrigger passed to add_job().
        _scheduler = AsyncIOScheduler(timezone="UTC")
    return _scheduler


def start_scheduler() -> None:
    # When Cloud Scheduler is handling cron, skip in-process scheduler.
    if os.getenv("CLOUD_SCHEDULER_ENABLED", "").lower() == "true":
        logger.info("CLOUD_SCHEDULER_ENABLED=true — skipping in-process APScheduler.")
        return

    scheduler = get_scheduler()
    if scheduler.running:
        return
    topics = list_research_topics()
    for topic in topics:
        if topic.get("is_active") and topic.get("schedule_cron"):
            _add_topic_job(topic)
    scheduler.start()
    logger.info(f"Research scheduler started with {len(scheduler.get_jobs())} jobs.")


def shutdown_scheduler() -> None:
    global _scheduler
    if _scheduler and _scheduler.running:
        _scheduler.shutdown(wait=False)
        logger.info("Research scheduler shut down.")
    _scheduler = None


def schedule_topic(topic: dict) -> None:
    scheduler = get_scheduler()
    topic_id = topic.get("id", "")
    job_id = f"research_{topic_id}"
    if scheduler.get_job(job_id):
        scheduler.remove_job(job_id)
    if topic.get("is_active") and topic.get("schedule_cron"):
        _add_topic_job(topic)
        logger.info(f"Scheduled research job for topic {topic_id}: {topic.get('schedule_cron')}")


def unschedule_topic(topic_id: str) -> None:
    scheduler = get_scheduler()
    job_id = f"research_{topic_id}"
    if scheduler.get_job(job_id):
        scheduler.remove_job(job_id)
        logger.info(f"Unscheduled research job for topic {topic_id}")


_DOW_MAP = {1: "mon", 2: "tue", 3: "wed", 4: "thu", 5: "fri", 6: "sat", 7: "sun"}


def _parse_schedule(schedule: str, tz: ZoneInfo) -> CronTrigger | None:
    """Parse schedule string into a CronTrigger.

    Formats:
      - "daily|HH:MM"          → every day at HH:MM (in tz)
      - "weekly|DAY_NUM|HH:MM" → every week on DAY (1=Mon..7=Sun) at HH:MM
      - "daily" (legacy)        → every day at 06:00
      - "weekly" (legacy)       → every Monday at 06:00
    """
    parts = schedule.split("|")
    kind = parts[0]

    if kind == "daily":
        if len(parts) >= 2:
            h, m = parts[1].split(":")
            return CronTrigger(hour=int(h), minute=int(m), timezone=tz)
        return CronTrigger(hour=6, minute=0, timezone=tz)

    if kind == "weekly":
        if len(parts) >= 3:
            dow = _DOW_MAP.get(int(parts[1]), "mon")
            h, m = parts[2].split(":")
            return CronTrigger(day_of_week=dow, hour=int(h), minute=int(m), timezone=tz)
        return CronTrigger(day_of_week="mon", hour=6, minute=0, timezone=tz)

    return None


def _add_topic_job(topic: dict) -> None:
    scheduler = get_scheduler()
    topic_id = topic.get("id", "")
    schedule = topic.get("schedule_cron", "")
    tz = ZoneInfo(topic.get("timezone") or _DEFAULT_TZ)
    trigger = _parse_schedule(schedule, tz)
    if trigger is None:
        return
    scheduler.add_job(
        _execute_research_job,
        trigger=trigger,
        id=f"research_{topic_id}",
        args=[topic_id],
        replace_existing=True,
        misfire_grace_time=3600,
    )


async def _execute_research_job(topic_id: str) -> None:
    topic = get_research_topic(topic_id)
    if not topic:
        logger.warning(f"Scheduled research job for unknown topic {topic_id}")
        return
    if not topic.get("is_active", True):
        logger.info(f"Skipping inactive topic {topic_id}")
        return
    send_notification(
        type="schedule_reminder",
        title="Research Starting",
        body=f"{topic.get('domain', 'general')} topic research starting now",
        metadata={"topic_id": topic_id},
    )
    loop = asyncio.get_running_loop()
    try:
        await loop.run_in_executor(
            _executor,
            lambda: run_research_pipeline(
                domain=topic.get("domain", "general"),
                keywords=topic.get("keywords", []),
                interests=topic.get("interests", []),
                topic_id=topic_id,
            ),
        )
    except Exception as e:
        logger.error(f"Scheduled research job failed for topic {topic_id}: {e}")
