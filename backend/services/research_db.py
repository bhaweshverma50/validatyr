"""Supabase persistence for research topics, reports, and jobs.

Follows the same graceful-degradation pattern as db.py:
if Supabase credentials are missing, operations are mocked.
"""

import logging
import uuid
from datetime import datetime, timezone
from typing import List, Optional

from services.db import get_supabase

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Research Topics
# ---------------------------------------------------------------------------

def save_research_topic(topic: dict) -> dict:
    """Insert a new research topic. Returns the saved record."""
    supabase = get_supabase()
    topic_id = topic.get("id") or str(uuid.uuid4())
    payload = {
        "id": topic_id,
        "domain": topic.get("domain", "general"),
        "keywords": topic.get("keywords", []),
        "interests": topic.get("interests", []),
        "schedule_cron": topic.get("schedule_cron"),
        "is_active": topic.get("is_active", True),
    }
    if not supabase:
        logger.info(f"[MOCKED] Would save research topic: {payload}")
        payload["created_at"] = datetime.now(timezone.utc).isoformat()
        return {"status": "mocked", "data": payload}

    try:
        response = supabase.table("research_topics").insert(payload).execute()
        return {"status": "success", "data": response.data[0] if response.data else payload}
    except Exception as e:
        logger.error(f"Error saving research topic: {e}")
        return {"status": "error", "message": str(e)}


def list_research_topics() -> List[dict]:
    """Fetch all research topics, ordered by created_at desc."""
    supabase = get_supabase()
    if not supabase:
        return []
    try:
        response = supabase.table("research_topics").select("*").order("created_at", desc=True).execute()
        return response.data or []
    except Exception as e:
        logger.error(f"Error fetching research topics: {e}")
        return []


def get_research_topic(topic_id: str) -> Optional[dict]:
    """Fetch a single research topic by ID."""
    supabase = get_supabase()
    if not supabase:
        return None
    try:
        response = supabase.table("research_topics").select("*").eq("id", topic_id).execute()
        return response.data[0] if response.data else None
    except Exception as e:
        logger.error(f"Error fetching research topic {topic_id}: {e}")
        return None


def update_research_topic(topic_id: str, updates: dict) -> dict:
    """Update a research topic."""
    supabase = get_supabase()
    if not supabase:
        return {"status": "mocked", "data": updates}
    try:
        updates["updated_at"] = datetime.now(timezone.utc).isoformat()
        response = supabase.table("research_topics").update(updates).eq("id", topic_id).execute()
        return {"status": "success", "data": response.data[0] if response.data else updates}
    except Exception as e:
        logger.error(f"Error updating research topic {topic_id}: {e}")
        return {"status": "error", "message": str(e)}


def delete_research_topic(topic_id: str) -> bool:
    """Delete a research topic."""
    supabase = get_supabase()
    if not supabase:
        return True
    try:
        supabase.table("research_topics").delete().eq("id", topic_id).execute()
        return True
    except Exception as e:
        logger.error(f"Error deleting research topic {topic_id}: {e}")
        return False


# ---------------------------------------------------------------------------
# Research Reports
# ---------------------------------------------------------------------------

def save_research_report(report: dict) -> dict:
    """Insert a new research report."""
    supabase = get_supabase()
    report_id = report.get("id") or str(uuid.uuid4())
    payload = {
        "id": report_id,
        "topic_id": report.get("topic_id", ""),
        "executive_summary": report.get("executive_summary", ""),
        "market_overview": report.get("market_overview", ""),
        "ideas": report.get("ideas", []),
        "data_sources": report.get("data_sources", []),
    }
    if not supabase:
        logger.info(f"[MOCKED] Would save research report: {report_id}")
        payload["generated_at"] = datetime.now(timezone.utc).isoformat()
        return {"status": "mocked", "data": payload}

    try:
        response = supabase.table("research_reports").insert(payload).execute()
        return {"status": "success", "data": response.data[0] if response.data else payload}
    except Exception as e:
        logger.error(f"Error saving research report: {e}")
        return {"status": "error", "message": str(e)}


def list_research_reports(topic_id: str, limit: int = 20, offset: int = 0) -> List[dict]:
    """Fetch reports for a topic, ordered by generated_at desc, with pagination."""
    supabase = get_supabase()
    if not supabase:
        return []
    try:
        response = (
            supabase.table("research_reports")
            .select("*")
            .eq("topic_id", topic_id)
            .order("generated_at", desc=True)
            .range(offset, offset + limit - 1)
            .execute()
        )
        return response.data or []
    except Exception as e:
        logger.error(f"Error fetching reports for topic {topic_id}: {e}")
        return []


def get_research_report(report_id: str) -> Optional[dict]:
    """Fetch a single research report."""
    supabase = get_supabase()
    if not supabase:
        return None
    try:
        response = supabase.table("research_reports").select("*").eq("id", report_id).execute()
        return response.data[0] if response.data else None
    except Exception as e:
        logger.error(f"Error fetching research report {report_id}: {e}")
        return None


# ---------------------------------------------------------------------------
# Research Jobs
# ---------------------------------------------------------------------------

def create_research_job(topic_id: str) -> dict:
    """Create a new research job record."""
    supabase = get_supabase()
    job_id = str(uuid.uuid4())
    payload = {
        "id": job_id,
        "topic_id": topic_id,
        "status": "pending",
        "progress_pct": 0,
        "started_at": datetime.now(timezone.utc).isoformat(),
    }
    if not supabase:
        logger.info(f"[MOCKED] Would create research job: {job_id}")
        return payload

    try:
        response = supabase.table("research_jobs").insert(payload).execute()
        return response.data[0] if response.data else payload
    except Exception as e:
        logger.error(f"Error creating research job: {e}")
        return payload


def update_research_job(job_id: str, updates: dict) -> None:
    """Update a research job (status, current_step, report_id, error)."""
    supabase = get_supabase()
    if not supabase:
        logger.info(f"[MOCKED] Would update job {job_id}: {updates}")
        return
    try:
        supabase.table("research_jobs").update(updates).eq("id", job_id).execute()
    except Exception as e:
        logger.error(f"Error updating research job {job_id}: {e}")


def get_latest_job_for_topic(topic_id: str) -> Optional[dict]:
    """Fetch the most recent research job for a topic."""
    supabase = get_supabase()
    if not supabase:
        return None
    try:
        response = (
            supabase.table("research_jobs")
            .select("*")
            .eq("topic_id", topic_id)
            .order("started_at", desc=True)
            .limit(1)
            .execute()
        )
        return response.data[0] if response.data else None
    except Exception as e:
        logger.error(f"Error fetching latest job for topic {topic_id}: {e}")
        return None


def get_research_job(job_id: str) -> Optional[dict]:
    """Fetch a research job by ID."""
    supabase = get_supabase()
    if not supabase:
        return None
    try:
        response = supabase.table("research_jobs").select("*").eq("id", job_id).execute()
        return response.data[0] if response.data else None
    except Exception as e:
        logger.error(f"Error fetching research job {job_id}: {e}")
        return None
