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
        
    try:
        # Pass the concatenated reviews to the Multi-Agent validation engine
        logger.info(f"Starting Multi-Agent analysis for idea: {request.idea[:50]}...")
        result = analyze_reviews_multi_agent(request.idea, reviews, competitors_meta, request.model_provider, request.category or "mobile_app")
        
        # Save to database (will mock if Supabase credentials are not set)
        save_validation_result(request.idea, result.model_dump())
        
        return result
    except ValueError as ve:
        raise HTTPException(status_code=400, detail=str(ve))
    except Exception as e:
        logger.error(f"Internal Error: {e}")
        raise HTTPException(status_code=500, detail=f"Internal AI analysis error: {str(e)}")

@router.post("/validate/stream")
async def validate_idea_stream(request: ValidationRequest):
    """Streams SSE events for the full validation pipeline."""

    async def event_generator() -> AsyncGenerator[dict, None]:
        loop = asyncio.get_running_loop()
        idea = request.idea
        user_category = request.category
        total_steps = 5

        try:
            api_key = os.getenv("GEMINI_API_KEY")
            if not api_key:
                raise ValueError("GEMINI_API_KEY not set.")
            client = _genai.Client(api_key=api_key)

            # ── Step 1: Category Detection ────────────────────────────────
            yield {"event": "status", "data": _json.dumps({
                "agent": "Category Detector",
                "message": "Classifying your idea..." if not user_category else f"Category set to {user_category}",
                "step": 1, "total": total_steps,
            })}

            cat_result = await loop.run_in_executor(
                _executor,
                lambda: detect_category(client, idea, user_category),
            )
            category = cat_result.category
            subcategory = cat_result.subcategory
            yield {"event": "category", "data": _json.dumps({
                "category": category,
                "subcategory": subcategory,
                "label": _CATEGORY_LABELS.get(category, "Software"),
            })}
            yield {"event": "status", "data": _json.dumps({
                "agent": "Category Detector",
                "message": f"Identified: {_CATEGORY_LABELS.get(category, category)} · {subcategory}",
                "step": 1, "total": total_steps,
            })}

            # ── Step 2: Discovery ─────────────────────────────────────────
            yield {"event": "status", "data": _json.dumps({
                "agent": "Discovery Agent",
                "message": _DISCOVERY_MESSAGES.get(category, "Finding competitors..."),
                "step": 2, "total": total_steps,
            })}

            reviews, competitors_meta = await loop.run_in_executor(
                _executor,
                lambda: discover_competitors_and_scrape(idea, category),
            )

            yield {"event": "status", "data": _json.dumps({
                "agent": "Discovery Agent",
                "message": f"Found {len(competitors_meta)} competitors.",
                "step": 2, "total": total_steps,
            })}

            if not reviews and not competitors_meta:
                yield {"event": "error", "data": _json.dumps({"message": "No competitors found. Try adding more detail about your idea."})}
                return

            # ── Step 3: Researcher Agent ──────────────────────────────────
            yield {"event": "status", "data": _json.dumps({
                "agent": "Researcher Agent",
                "message": _RESEARCHER_MESSAGES.get(category, "Researching market..."),
                "step": 3, "total": total_steps,
            })}

            reviews_sample = reviews[:200]
            if not reviews_sample and competitors_meta:
                # Hardware/SaaS: pass competitor descriptions as research input
                reviews_text = _json.dumps([
                    {"title": c.get("title", ""), "description": c.get("description", "")}
                    for c in competitors_meta[:20]
                ])
            else:
                reviews_text = _json.dumps([
                    {"rating": r["score"], "review": r["content"]} for r in reviews_sample
                ])

            researcher_result = await loop.run_in_executor(
                _executor,
                lambda: run_researcher_agent(client, idea, reviews_text, category),
            )

            yield {"event": "status", "data": _json.dumps({
                "agent": "Researcher Agent",
                "message": f"Found {len(researcher_result.what_users_hate)} pain points, {len(researcher_result.community_signals)} community signals.",
                "step": 3, "total": total_steps,
            })}

            # ── Step 4: PM Agent ──────────────────────────────────────────
            yield {"event": "status", "data": _json.dumps({
                "agent": "PM Agent",
                "message": "Building Day-1 MVP roadmap from pain points...",
                "step": 4, "total": total_steps,
            })}

            pm_result = await loop.run_in_executor(
                _executor,
                lambda: run_pm_agent(client, idea, researcher_result),
            )

            yield {"event": "status", "data": _json.dumps({
                "agent": "PM Agent",
                "message": f"MVP roadmap ready — {len(pm_result.mvp_roadmap)} features.",
                "step": 4, "total": total_steps,
            })}

            # ── Step 5: Market Intelligence ───────────────────────────────
            yield {"event": "status", "data": _json.dumps({
                "agent": "Market Intelligence",
                "message": "Researching TAM/SAM/SOM, funded competitors, GTM strategy...",
                "step": 5, "total": total_steps,
            })}

            market_result = await loop.run_in_executor(
                _executor,
                lambda: run_market_intelligence_agent(client, idea, researcher_result, pm_result, category),
            )

            # Compute weighted score
            breakdown = market_result.score_breakdown
            weights = {
                "pain_severity": 0.25,
                "market_gap": 0.20,
                "mvp_feasibility": 0.15,
                "competition_density": 0.15,
                "monetization_potential": 0.10,
                "community_demand": 0.10,
                "startup_saturation": 0.05,
            }
            opportunity_score = max(0, min(100, round(sum(
                getattr(breakdown, k) * v for k, v in weights.items()
            ))))

            # Convert FundedCompetitor objects to dicts for IdeaValidationResult
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

            yield {"event": "status", "data": _json.dumps({
                "agent": "Market Intelligence",
                "message": f"Score: {opportunity_score}/100 · TAM: {(market_result.tam or '')[:50]}",
                "step": 5, "total": total_steps,
            })}

            yield {"event": "result", "data": final_result.model_dump_json()}

        except Exception as e:
            logger.error(f"SSE error: {e}", exc_info=True)
            yield {"event": "error", "data": _json.dumps({"message": str(e)})}

    return EventSourceResponse(event_generator())
