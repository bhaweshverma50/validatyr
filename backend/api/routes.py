from fastapi import APIRouter, HTTPException, UploadFile, File
from pydantic import BaseModel
from typing import List, Optional
from services.scraper import scrape_play_store_reviews, scrape_app_store_reviews
from services.ai_analyzer import analyze_reviews_multi_agent, IdeaValidationResult
from services.discovery import discover_competitors_and_scrape
from services.audio_processor import transcribe_audio
from services.db import save_validation_result
import logging

logger = logging.getLogger(__name__)
router = APIRouter()

class ValidationRequest(BaseModel):
    idea: str
    play_store_id: Optional[str] = None
    app_store_id: Optional[int] = None
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
