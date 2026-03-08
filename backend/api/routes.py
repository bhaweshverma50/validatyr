from fastapi import APIRouter, HTTPException, UploadFile, File
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
from services.db import save_validation_result, send_notification, create_validation_job, update_validation_job
import asyncio
import json as _json
import os
import queue as _queue
from concurrent.futures import ThreadPoolExecutor
import logging
import uuid
import datetime

from google import genai as _genai

logger = logging.getLogger(__name__)

_executor = ThreadPoolExecutor(max_workers=4)

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

@router.post("/transcribe")
async def transcribe_voice_memo(file: UploadFile = File(...)):
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

@router.post("/validate", response_model=IdeaValidationResult)
async def validate_idea(request: ValidationRequest):
    reviews = []
    competitors_meta = []
    
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
        reviews, competitors_meta = discover_competitors_and_scrape(request.idea, request.category or "mobile_app")
        
    if not reviews:
        raise HTTPException(status_code=404, detail="No competitors found or failed to scrape reviews. Try providing specific App IDs.")

    # Community scraping
    category = request.category or "mobile_app"
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
        save_validation_result(request.idea, result.model_dump())
        send_notification(
            type="validation_complete",
            title="Validation Complete",
            body=f"'{request.idea[:50]}' scored {result.opportunity_score}/100",
            metadata={"score": result.opportunity_score},
        )

        return result
    except ValueError as ve:
        raise HTTPException(status_code=400, detail=str(ve))
    except Exception as e:
        logger.error(f"Internal Error: {e}")
        raise HTTPException(status_code=500, detail=f"Internal AI analysis error: {str(e)}")

def _run_validation_pipeline(q: _queue.Queue, idea: str, user_category: str | None) -> None:
    """Run the full validation pipeline in a background thread.

    Puts SSE-style dicts into *q*.  Runs independently of the SSE connection
    so the pipeline completes and saves even if the client disconnects.
    """
    total_steps = 6

    def _put(event: str, data):
        q.put({"event": event, "data": _json.dumps(data) if isinstance(data, dict) else data})

    try:
        job_id = str(uuid.uuid4())
        create_validation_job(job_id, idea, user_category)
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
        _put("status", {"agent": "PM Agent",
             "message": "Building Day-1 MVP roadmap from pain points...",
             "step": 5, "total": total_steps})

        pm_result = run_pm_agent(client, idea, researcher_result)

        _put("status", {"agent": "PM Agent",
             "message": f"MVP roadmap ready — {len(pm_result.mvp_roadmap)} features.",
             "step": 5, "total": total_steps})
        _update_job(5, "PM Agent", f"MVP roadmap ready — {len(pm_result.mvp_roadmap)} features.")

        # ── Step 6: Market Intelligence ───────────────────────────────
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
            save_resp = save_validation_result(idea, final_result.model_dump())
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

        update_validation_job(job_id, {
            "status": "completed",
            "progress_pct": 100,
            "result_id": result_id,
            "completed_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        })

        _put("result", final_result.model_dump_json())

    except Exception as e:
        logger.error(f"Pipeline error: {e}", exc_info=True)
        _put("error", {"message": str(e)})
        update_validation_job(job_id, {"status": "failed", "error": str(e)})
    finally:
        # Sentinel so the SSE generator knows the pipeline is done
        q.put(None)


@router.post("/validate/stream")
async def validate_idea_stream(request: ValidationRequest):
    """Streams SSE events for the full validation pipeline.

    The pipeline runs in a background thread so it completes and saves
    even if the SSE client disconnects (e.g. phone locked).
    """
    progress_q: _queue.Queue = _queue.Queue()

    # Fire-and-forget: pipeline runs independently of the SSE connection
    _executor.submit(_run_validation_pipeline, progress_q, request.idea, request.category)

    async def event_generator() -> AsyncGenerator[dict, None]:
        while True:
            try:
                event = progress_q.get(timeout=0.5)
            except _queue.Empty:
                continue
            if event is None:
                # Pipeline finished (sentinel)
                return
            yield event
            if event.get("event") in ("result", "error"):
                return

    return EventSourceResponse(event_generator())
