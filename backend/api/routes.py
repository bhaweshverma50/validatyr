from fastapi import APIRouter, HTTPException, UploadFile, File, Request
from pydantic import BaseModel
from typing import List, Optional, AsyncGenerator
from sse_starlette.sse import EventSourceResponse
from services.scraper import scrape_play_store_reviews, scrape_app_store_reviews
from services.ai_analyzer import (
    analyze_reviews_multi_agent,
    run_researcher_agent,
    run_pm_agent,
    run_analyst_agent,
    IdeaValidationResult,
    OpportunityScoreBreakdown,
)
from services.discovery import discover_competitors_and_scrape
from services.audio_processor import transcribe_audio
from services.db import save_validation_result
import asyncio
import json as _json
import os
from concurrent.futures import ThreadPoolExecutor
import logging

from google import genai as _genai

logger = logging.getLogger(__name__)

_executor = ThreadPoolExecutor(max_workers=4)

router = APIRouter()

class ValidationRequest(BaseModel):
    idea: str
    play_store_id: Optional[str] = None
    app_store_id: Optional[int] = None
    app_store_name: Optional[str] = None
    model_provider: str = "gemini"

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
        reviews, competitors_meta = discover_competitors_and_scrape(request.idea)
        
    if not reviews:
        raise HTTPException(status_code=404, detail="No competitors found or failed to scrape reviews. Try providing specific App IDs.")
        
    try:
        # Pass the concatenated reviews to the Multi-Agent validation engine
        logger.info(f"Starting Multi-Agent analysis for idea: {request.idea[:50]}...")
        result = analyze_reviews_multi_agent(request.idea, reviews, competitors_meta, request.model_provider)
        
        # Save to database (will mock if Supabase credentials are not set)
        save_validation_result(request.idea, result.model_dump())
        
        return result
    except ValueError as ve:
        raise HTTPException(status_code=400, detail=str(ve))
    except Exception as e:
        logger.error(f"Internal Error: {e}")
        raise HTTPException(status_code=500, detail=f"Internal AI analysis error: {str(e)}")

@router.post("/validate/stream")
async def validate_idea_stream(request: ValidationRequest, req: Request):
    """Streams SSE events for the full validation pipeline."""

    async def event_generator() -> AsyncGenerator[dict, None]:
        loop = asyncio.get_running_loop()
        idea = request.idea

        try:
            # ── Step 1: Discovery ──────────────────────────────────────
            yield {
                "event": "status",
                "data": _json.dumps({
                    "agent": "Discovery Agent",
                    "message": "Searching Play Store, App Store, Product Hunt & YC for competitors...",
                    "step": 1, "total": 4,
                }),
            }

            reviews, competitors_meta = await loop.run_in_executor(
                _executor, discover_competitors_and_scrape, idea,
            )

            if not reviews:
                yield {
                    "event": "error",
                    "data": _json.dumps({"message": "No competitors found. Try providing more detail about your idea."}),
                }
                return

            yield {
                "event": "status",
                "data": _json.dumps({
                    "agent": "Discovery Agent",
                    "message": f"Found {len(competitors_meta)} competitors with {len(reviews)} reviews.",
                    "step": 1, "total": 4,
                }),
            }

            # ── Step 2: Researcher Agent ───────────────────────────────
            yield {
                "event": "status",
                "data": _json.dumps({
                    "agent": "Researcher Agent",
                    "message": "Analyzing reviews + searching Reddit, HN, and Product Hunt...",
                    "step": 2, "total": 4,
                }),
            }

            api_key = os.getenv("GEMINI_API_KEY")
            if not api_key:
                raise ValueError("GEMINI_API_KEY not set.")
            client = _genai.Client(api_key=api_key)

            reviews_sample = reviews[:200]
            reviews_text = _json.dumps([
                {"rating": r["score"], "review": r["content"]} for r in reviews_sample
            ])

            researcher_result = await loop.run_in_executor(
                _executor, run_researcher_agent, client, idea, reviews_text,
            )

            yield {
                "event": "status",
                "data": _json.dumps({
                    "agent": "Researcher Agent",
                    "message": f"Found {len(researcher_result.what_users_hate)} pain points and {len(researcher_result.community_signals)} community signals.",
                    "step": 2, "total": 4,
                }),
            }

            # ── Step 3: PM Agent ──────────────────────────────────────
            yield {
                "event": "status",
                "data": _json.dumps({
                    "agent": "PM Agent",
                    "message": "Building Day-1 MVP roadmap from pain points...",
                    "step": 3, "total": 4,
                }),
            }

            pm_result = await loop.run_in_executor(
                _executor, run_pm_agent, client, idea, researcher_result,
            )

            yield {
                "event": "status",
                "data": _json.dumps({
                    "agent": "PM Agent",
                    "message": f"MVP roadmap ready — {len(pm_result.mvp_roadmap)} features.",
                    "step": 3, "total": 4,
                }),
            }

            # ── Step 4: Analyst Agent ─────────────────────────────────
            yield {
                "event": "status",
                "data": _json.dumps({
                    "agent": "Analyst Agent",
                    "message": "Scoring opportunity across 7 dimensions with Google Search...",
                    "step": 4, "total": 4,
                }),
            }

            analyst_result = await loop.run_in_executor(
                _executor, run_analyst_agent, client, idea, researcher_result, pm_result,
            )

            # ── Assemble final result ─────────────────────────────────
            breakdown = analyst_result.score_breakdown
            weights = {
                "pain_severity": 0.25, "market_gap": 0.20, "mvp_feasibility": 0.15,
                "competition_density": 0.15, "monetization_potential": 0.10,
                "community_demand": 0.10, "startup_saturation": 0.05,
            }
            opportunity_score = max(0, min(100, round(
                breakdown.pain_severity * weights["pain_severity"]
                + breakdown.market_gap * weights["market_gap"]
                + breakdown.mvp_feasibility * weights["mvp_feasibility"]
                + breakdown.competition_density * weights["competition_density"]
                + breakdown.monetization_potential * weights["monetization_potential"]
                + breakdown.community_demand * weights["community_demand"]
                + breakdown.startup_saturation * weights["startup_saturation"]
            )))

            final_result = IdeaValidationResult(
                opportunity_score=opportunity_score,
                score_breakdown=breakdown.model_dump(),
                what_users_love=researcher_result.what_users_love,
                what_users_hate=researcher_result.what_users_hate,
                mvp_roadmap=pm_result.mvp_roadmap,
                pricing_suggestion=analyst_result.pricing_suggestion,
                target_platform_recommendation=analyst_result.target_os_recommendation,
                market_breakdown=analyst_result.market_breakdown,
                competitors_analyzed=competitors_meta or [],
                community_signals=researcher_result.community_signals,
            )

            yield {
                "event": "status",
                "data": _json.dumps({
                    "agent": "Analyst Agent",
                    "message": f"Opportunity score: {opportunity_score}/100",
                    "step": 4, "total": 4,
                }),
            }

            # NOTE: Flutter handles DB save — no save_validation_result call here
            yield {"event": "result", "data": final_result.model_dump_json()}

        except Exception as e:
            logger.error(f"SSE streaming error: {e}", exc_info=True)
            yield {"event": "error", "data": _json.dumps({"message": str(e)})}

    return EventSourceResponse(event_generator())
