from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from pydantic import BaseModel
from typing import List, Optional, AsyncGenerator
from sse_starlette.sse import EventSourceResponse
from services.scraper import scrape_play_store_reviews, scrape_app_store_reviews
from services.ai_analyzer import (
    analyze_reviews_multi_agent,
    run_researcher_agent,
    run_pm_agent,
    run_market_intelligence_agent,
    detect_category,
    IdeaValidationResult,
    OpportunityScoreBreakdown,
)
from services.discovery import discover_competitors_and_scrape
from services.community_scraper import CommunityScraperService
from services.audio_processor import transcribe_audio
from services.auth import get_current_user_id
from services.db import (
    save_validation_result,
    send_notification,
    create_validation_job,
    update_validation_job,
    upsert_push_token,
    delete_push_token,
)
import asyncio
import json as _json
import os
import queue as _queue
import threading
from concurrent.futures import ThreadPoolExecutor
import logging
import uuid
import datetime

from google import genai as _genai

logger = logging.getLogger(__name__)

_executor = ThreadPoolExecutor(max_workers=8)

# Cancellation registry: job_id → threading.Event (set = cancelled)
_cancel_events: dict[str, threading.Event] = {}

_CATEGORY_LABELS = {
    "mobile_app": "Mobile App",
    "hardware": "Hardware",
    "fintech": "FinTech",
    "saas_web": "SaaS / Web",
}

_DISCOVERY_MESSAGES = {
    "mobile_app": "Searching App Store, Play Store, Product Hunt & YC...",
    "hardware": "Searching Kickstarter, Amazon, YC Hardware portfolio...",
    "fintech": "Searching App Store, YC FinTech, CB Insights, Crunchbase...",
    "saas_web": "Searching ProductHunt, G2, Capterra, YC SaaS portfolio...",
}

_COMMUNITY_MESSAGES = {
    "mobile_app": "Scraping Reddit, HN, Twitter & Product Hunt for real user signals...",
    "hardware": "Scraping Reddit hardware forums, HN, and maker communities...",
    "fintech": "Scraping r/fintech, HN, Twitter & G2 for real user signals...",
    "saas_web": "Scraping Reddit, HN, Twitter, Product Hunt & G2 reviews...",
}

_RESEARCHER_MESSAGES = {
    "mobile_app": "Analyzing app reviews + Reddit, HN, Product Hunt...",
    "hardware": "Researching manufacturing challenges, supply chain forums...",
    "fintech": "Analyzing compliance landscape, FinTech communities...",
    "saas_web": "Analyzing G2 reviews, churn patterns, SaaS communities...",
}

router = APIRouter()

class ValidationRequest(BaseModel):
    idea: str
    play_store_id: Optional[str] = None
    app_store_id: Optional[int] = None
    app_store_name: Optional[str] = None
    model_provider: str = "gemini"
    category: Optional[str] = None
    metadata_only: bool = False  # Return category + competitors without running AI agents


class PushTokenRequest(BaseModel):
    token: str
    platform: str


class PushTokenDeleteRequest(BaseModel):
    token: str

@router.post("/transcribe")
async def transcribe_voice_memo(file: UploadFile = File(...), user_id: str = Depends(get_current_user_id)):
    if not file:
        raise HTTPException(status_code=400, detail="No audio file uploaded.")

    try:
        contents = await file.read()
        if not contents:
            raise HTTPException(status_code=400, detail="Uploaded file is empty.")
        transcript = transcribe_audio(contents)
        return {"transcript": transcript}
    except HTTPException:
        raise
    except ValueError as ve:
        logger.error(f"Configuration error: {ve}")
        raise HTTPException(status_code=500, detail=str(ve))
    except Exception as e:
        logger.error(f"Failed to transcribe audio: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to transcribe audio: {str(e)}")


@router.post("/push-tokens")
async def register_push_token(request: PushTokenRequest, user_id: str = Depends(get_current_user_id)):
    upsert_push_token(user_id, request.token, request.platform)
    return {"status": "ok"}


@router.post("/push-tokens/unregister")
async def unregister_push_token(request: PushTokenDeleteRequest, user_id: str = Depends(get_current_user_id)):
    delete_push_token(request.token)
    return {"status": "ok"}

@router.post("/validate")
async def validate_idea(request: ValidationRequest, user_id: str = Depends(get_current_user_id)):
    reviews = []
    competitors_meta = []

    # ── Step 1: Category detection ─────────────────────────────────
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        raise HTTPException(status_code=500, detail="GEMINI_API_KEY not set.")
    client = _genai.Client(api_key=api_key)
    cat_result = detect_category(client, request.idea, request.category)
    category = cat_result.category

    # ── Step 2: Discovery ──────────────────────────────────────────
    if request.play_store_id or (request.app_store_id and request.app_store_name):
        logger.info("Using explicitly provided App Store IDs...")
        if request.play_store_id:
            play_reviews = scrape_play_store_reviews(request.play_store_id, count=200)
            reviews.extend(play_reviews)

        if request.app_store_id and request.app_store_name:
            ios_reviews = scrape_app_store_reviews(request.app_store_name, request.app_store_id, count=200)
            reviews.extend(ios_reviews)
    else:
        logger.info("No App IDs provided. Firing up Discovery Agent...")
        reviews, competitors_meta = discover_competitors_and_scrape(request.idea, category)

    if not reviews and not competitors_meta:
        raise HTTPException(status_code=404, detail="No competitors found or failed to scrape reviews. Try providing specific App IDs.")

    # ── metadata_only: return category + competitors without AI agents ──
    if request.metadata_only:
        return {
            "category": category,
            "subcategory": cat_result.subcategory,
            "competitors_analyzed": competitors_meta,
            "review_count": len(reviews),
        }

    # ── Step 3: Community scraping ─────────────────────────────────
    community_result = CommunityScraperService(category).scrape_all(
        competitor_names=[c.get("title", "") for c in competitors_meta],
        idea_keywords=request.idea,
    )
    community_text = _json.dumps([p.model_dump() for p in community_result.posts[:50]])
    logger.info(f"Community scraping: {community_result.total_posts} posts from {community_result.sources_succeeded}")

    try:
        # Pass the concatenated reviews to the Multi-Agent validation engine
        logger.info(f"Starting Multi-Agent analysis for idea: {request.idea[:50]}...")
        result = analyze_reviews_multi_agent(request.idea, reviews, competitors_meta, request.model_provider, category, community_data=community_text)

        # Save to database (will mock if Supabase credentials are not set)
        save_resp = save_validation_result(user_id, request.idea, result.model_dump())
        result_id = None
        if save_resp.get("status") == "success" and save_resp.get("data"):
            rows = save_resp["data"]
            if isinstance(rows, list) and rows:
                result_id = rows[0].get("id")
        send_notification(
            user_id,
            type="validation_complete",
            title="Validation Complete",
            body=f"'{request.idea[:50]}' scored {result.opportunity_score}/100",
            metadata={"score": result.opportunity_score, "result_id": result_id},
        )

        return result
    except ValueError as ve:
        raise HTTPException(status_code=400, detail=str(ve))
    except Exception as e:
        logger.error(f"Internal Error: {e}")
        raise HTTPException(status_code=500, detail=f"Internal AI analysis error: {str(e)}")

class _Cancelled(Exception):
    """Raised when a pipeline job is cancelled."""
    pass


def _check_cancelled(job_id: str) -> None:
    """Raise _Cancelled if this job's cancel event has been set."""
    ev = _cancel_events.get(job_id)
    if ev and ev.is_set():
        raise _Cancelled(f"Job {job_id} was cancelled")


def _run_validation_pipeline(q: _queue.Queue, idea: str, user_category: str | None, user_id: str) -> None:
    """Run the full validation pipeline in a background thread.

    Puts SSE-style dicts into *q*.  Runs independently of the SSE connection
    so the pipeline completes and saves even if the client disconnects.
    Checks for cancellation before each expensive step.
    """
    total_steps = 6
    job_id = None

    def _put(event: str, data):
        q.put({"event": event, "data": _json.dumps(data) if isinstance(data, dict) else data})

    try:
        job_id = str(uuid.uuid4())
        # Register a cancel event for this job
        _cancel_events[job_id] = threading.Event()
        create_validation_job(user_id, job_id, idea, user_category)
        _put("job", {"job_id": job_id})

        def _update_job(step_number: int, agent: str, message: str, status: str = "running"):
            pct = round((step_number / total_steps) * 100) if total_steps else 0
            update_validation_job(job_id, {
                "status": status,
                "current_step": agent,
                "step_number": step_number,
                "step_message": message,
                "progress_pct": min(pct, 99),
            })

        api_key = os.getenv("GEMINI_API_KEY")
        if not api_key:
            raise ValueError("GEMINI_API_KEY not set.")
        client = _genai.Client(api_key=api_key)

        # ── Step 1: Category Detection ────────────────────────────────
        _check_cancelled(job_id)
        _put("status", {"agent": "Category Detector",
             "message": "Classifying your idea..." if not user_category else f"Category set to {user_category}",
             "step": 1, "total": total_steps})

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
        _check_cancelled(job_id)
        _put("status", {"agent": "Discovery Agent",
             "message": _DISCOVERY_MESSAGES.get(category, "Finding competitors..."),
             "step": 2, "total": total_steps})

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
        _check_cancelled(job_id)
        _put("status", {"agent": "Community Scanner",
             "message": _COMMUNITY_MESSAGES.get(category, "Scraping community forums for real user signals..."),
             "step": 3, "total": total_steps})

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
        _check_cancelled(job_id)
        _put("status", {"agent": "Researcher Agent",
             "message": _RESEARCHER_MESSAGES.get(category, "Researching market..."),
             "step": 4, "total": total_steps})

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
        _check_cancelled(job_id)
        _put("status", {"agent": "PM Agent",
             "message": "Building Day-1 MVP roadmap from pain points...",
             "step": 5, "total": total_steps})

        pm_result = run_pm_agent(client, idea, researcher_result)

        _put("status", {"agent": "PM Agent",
             "message": f"MVP roadmap ready — {len(pm_result.mvp_roadmap)} features.",
             "step": 5, "total": total_steps})
        _update_job(5, "PM Agent", f"MVP roadmap ready — {len(pm_result.mvp_roadmap)} features.")

        # ── Step 6: Market Intelligence ───────────────────────────────
        _check_cancelled(job_id)
        _put("status", {"agent": "Market Intelligence",
             "message": "Researching TAM/SAM/SOM, funded competitors, GTM strategy...",
             "step": 6, "total": total_steps})

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
        _update_job(6, "Market Intelligence", f"Score: {opportunity_score}/100 · TAM: {(market_result.tam or '')[:50]}")

        # Save to DB — runs regardless of whether SSE client is still connected
        result_id = None
        try:
            save_resp = save_validation_result(user_id, idea, final_result.model_dump())
            if save_resp.get("status") == "success" and save_resp.get("data"):
                rows = save_resp["data"]
                if isinstance(rows, list) and rows:
                    result_id = rows[0].get("id")
            send_notification(
                user_id,
                type="validation_complete",
                title="Validation Complete",
                body=f"'{idea[:50]}' scored {opportunity_score}/100",
                metadata={"score": opportunity_score, "result_id": result_id},
            )
        except Exception as db_err:
            logger.warning(f"Failed to save validation result: {db_err}")

        update_validation_job(job_id, {
            "status": "completed",
            "progress_pct": 100,
            "result_id": result_id,
            "completed_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        })

        _put("result", final_result.model_dump_json())

    except _Cancelled:
        logger.info(f"Pipeline cancelled for job {job_id}")
        _put("error", {"message": "Validation cancelled."})
        if job_id:
            update_validation_job(job_id, {"status": "cancelled"})
    except Exception as e:
        logger.error(f"Pipeline error: {e}", exc_info=True)
        _put("error", {"message": str(e)})
        if job_id:
            update_validation_job(job_id, {"status": "failed", "error": str(e)})
    finally:
        # Clean up cancel event and send sentinel
        if job_id:
            _cancel_events.pop(job_id, None)
        q.put(None)


@router.post("/validate/stream")
async def validate_idea_stream(request: ValidationRequest, user_id: str = Depends(get_current_user_id)):
    """Streams SSE events for the full validation pipeline.

    The pipeline runs in a background thread so it completes and saves
    even if the SSE client disconnects (e.g. phone locked).
    """
    progress_q: _queue.Queue = _queue.Queue()

    # Fire-and-forget: pipeline runs independently of the SSE connection
    _executor.submit(_run_validation_pipeline, progress_q, request.idea, request.category, user_id)

    async def event_generator() -> AsyncGenerator[dict, None]:
        import time
        start = time.monotonic()
        timeout = 300  # 5 minutes max
        while True:
            if time.monotonic() - start > timeout:
                yield {"event": "error", "data": _json.dumps({"message": "Pipeline timed out after 5 minutes."})}
                return
            # Use asyncio.to_thread to avoid blocking the event loop
            try:
                event = await asyncio.wait_for(
                    asyncio.to_thread(progress_q.get, True, 1),
                    timeout=2,
                )
            except (asyncio.TimeoutError, _queue.Empty):
                continue
            if event is None:
                # Pipeline finished (sentinel)
                return
            yield event
            if event.get("event") in ("result", "error"):
                return

    return EventSourceResponse(event_generator())


@router.get("/validation-jobs")
async def list_validation_jobs(user_id: str = Depends(get_current_user_id)):
    """List all active (pending/running) validation jobs."""
    from services.db import list_active_validation_jobs
    jobs = list_active_validation_jobs(user_id)
    return {"jobs": jobs}


@router.get("/validation-jobs/{job_id}")
async def get_validation_job_status(job_id: str, user_id: str = Depends(get_current_user_id)):
    """Get a single validation job's current status."""
    from services.db import get_validation_job
    job = get_validation_job(job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    return job


@router.post("/validation-jobs/{job_id}/cancel")
async def cancel_validation_job(job_id: str, user_id: str = Depends(get_current_user_id)):
    """Cancel a validation job, signalling the background pipeline to stop."""
    from services.db import get_validation_job
    job = get_validation_job(job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    # Signal the background thread to stop before the next expensive step
    ev = _cancel_events.get(job_id)
    if ev:
        ev.set()
    update_validation_job(job_id, {"status": "cancelled"})
    return {"status": "cancelled"}


@router.delete("/history")
async def clear_all_history(user_id: str = Depends(get_current_user_id)):
    """Delete all validations and validation_jobs."""
    from services.db import delete_all_validations
    deleted = delete_all_validations(user_id)
    return {"deleted": deleted}
