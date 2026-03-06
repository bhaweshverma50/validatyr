"""API routes for the research feature."""

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Optional
from concurrent.futures import ThreadPoolExecutor
import asyncio
import logging

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
)
from services.research_pipeline import run_research_pipeline
from services.research_scheduler import schedule_topic, unschedule_topic

logger = logging.getLogger(__name__)

_executor = ThreadPoolExecutor(max_workers=2)

router = APIRouter()


class CreateTopicRequest(BaseModel):
    domain: str
    keywords: List[str] = []
    interests: List[str] = []
    schedule_cron: Optional[str] = None
    start_immediately: bool = True


class UpdateTopicRequest(BaseModel):
    domain: Optional[str] = None
    keywords: Optional[List[str]] = None
    interests: Optional[List[str]] = None
    schedule_cron: Optional[str] = None
    is_active: Optional[bool] = None


class StartResearchRequest(BaseModel):
    topic_id: str


@router.post("/topics")
async def create_topic(request: CreateTopicRequest):
    topic_data = {
        "domain": request.domain,
        "keywords": request.keywords,
        "interests": request.interests,
        "schedule_cron": request.schedule_cron,
        "is_active": True,
    }
    result = save_research_topic(topic_data)
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
            lambda: run_research_pipeline(
                domain=request.domain,
                keywords=request.keywords,
                interests=request.interests,
                topic_id=topic_id,
            ),
        )

    return {"topic": saved_topic, "research_started": request.start_immediately}


@router.get("/topics")
async def get_topics():
    topics = list_research_topics()
    return {"topics": topics}


@router.put("/topics/{topic_id}")
async def update_topic(topic_id: str, request: UpdateTopicRequest):
    existing = get_research_topic(topic_id)
    if not existing:
        raise HTTPException(status_code=404, detail="Topic not found")

    updates = {k: v for k, v in request.model_dump().items() if v is not None}
    if not updates:
        raise HTTPException(status_code=400, detail="No updates provided")

    result = update_research_topic(topic_id, updates)

    if "schedule_cron" in updates or "is_active" in updates:
        merged = {**existing, **updates}
        if merged.get("is_active") and merged.get("schedule_cron"):
            schedule_topic(merged)
        else:
            unschedule_topic(topic_id)

    return {"topic": result.get("data", updates)}


@router.delete("/topics/{topic_id}")
async def remove_topic(topic_id: str):
    unschedule_topic(topic_id)
    success = delete_research_topic(topic_id)
    if not success:
        raise HTTPException(status_code=500, detail="Failed to delete topic")
    return {"deleted": True}


@router.post("/start")
async def start_research(request: StartResearchRequest):
    topic = get_research_topic(request.topic_id)
    if not topic:
        raise HTTPException(status_code=404, detail="Topic not found")

    loop = asyncio.get_running_loop()
    loop.run_in_executor(
        _executor,
        lambda: run_research_pipeline(
            domain=topic.get("domain", "general"),
            keywords=topic.get("keywords", []),
            interests=topic.get("interests", []),
            topic_id=request.topic_id,
        ),
    )

    return {"message": "Research started", "topic_id": request.topic_id}


@router.get("/status/{job_id}")
async def get_job_status(job_id: str):
    job = get_research_job(job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    return job


@router.get("/reports")
async def get_reports(topic_id: str):
    reports = list_research_reports(topic_id)
    return {"reports": reports}


@router.get("/reports/{report_id}")
async def get_report(report_id: str):
    report = get_research_report(report_id)
    if not report:
        raise HTTPException(status_code=404, detail="Report not found")
    return report
