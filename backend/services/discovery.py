import os
import json
import logging
from typing import List, Dict, Any, Tuple
from google import genai
from pydantic import BaseModel, Field
from google_play_scraper import search
import requests
from services.scraper import scrape_play_store_reviews, scrape_app_store_reviews

logger = logging.getLogger(__name__)

class SearchQueryOutput(BaseModel):
    query: str = Field(description="A short 3-5 word search query to find competitors.")

def discover_competitors_and_scrape(app_idea: str) -> Tuple[List[Dict[str, Any]], List[Dict[str, Any]]]:
    """
    Agent 0: Discovery Agent.
    Uses an LLM to generate a search query, searches the Play Store for the top 3 competitors,
    and scrapes their reviews automatically.
    Returns: (all_reviews_list, competitor_metadata_list)
    """
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        raise ValueError("GEMINI_API_KEY environment variable not set. Please add it to your .env file.")
        
    client = genai.Client(api_key=api_key)
    
    # 1. Generate the optimal search query
    logger.info("Agent 0 (Discovery) is analyzing the idea to formulate a search query...")
    prompt = f"""
    You are an expert App Store Search Optimizer.
    The user has a new app idea: "{app_idea}"
    
    Generate the most optimal 3-5 word search query to find directly competing apps on the Google Play Store. 
    Focus on the core utility or mechanism of the idea.
    """
    
    response = client.models.generate_content(
        model='gemini-3-flash-preview',
        contents=prompt,
        config={"response_mime_type": "application/json", "response_schema": SearchQueryOutput, "temperature": 0.2},
    )
    
    result = json.loads(response.text)
    query = result.get("query", app_idea[:30]) # Fallback to part of the string if failed
    logger.info(f"Discovery Agent generated query: '{query}'")
    
    # 2. Search Stores for top 3 competitors each
    try:
        all_reviews = []
        competitors_list = []
        
        # --- PLAY STORE SEARCH ---
        logger.info("Searching Google Play Store...")
        play_search_results = search(query, n_hits=3, lang='en', country='us')
        
        for app in (play_search_results or []):
            app_id = app.get('appId')
            if not app_id:
                continue
                
            app_title = app.get('title', 'Unknown App')
            app_score = float(app.get('score') or 0.0)
            app_icon = app.get('icon', '')
            
            logger.info(f"Discovery Agent found Android competitor: {app_title} ({app_id})")
            
            competitors_list.append({
                "app_id": app_id,
                "title": app_title,
                "score": app_score,
                "icon": app_icon,
                "platform": "android"
            })
            
            reviews = scrape_play_store_reviews(app_id, count=100)
            all_reviews.extend(reviews)
            
        # --- APPLE APP STORE SEARCH ---
        logger.info("Searching Apple App Store...")
        itunes_url = f"https://itunes.apple.com/search?term={query}&entity=software&limit=3&country=us"
        try:
            itunes_res = requests.get(itunes_url, timeout=10)
            itunes_data = itunes_res.json()
            
            for app in itunes_data.get('results', []):
                app_id = app.get('trackId')
                app_bundle_id = app.get('bundleId')
                app_title = app.get('trackName', 'Unknown App')
                
                if not app_id or not app_bundle_id:
                    continue
                    
                app_score = float(app.get('averageUserRating') or 0.0)
                app_icon = app.get('artworkUrl512', '')
                
                logger.info(f"Discovery Agent found iOS competitor: {app_title} ({app_id})")
                
                competitors_list.append({
                    "app_id": str(app_id),
                    "title": app_title,
                    "score": app_score,
                    "icon": app_icon,
                    "platform": "ios"
                })
                
                # App Store scraper needs the bundle ID as the app_name string, and numeric trackId
                reviews = scrape_app_store_reviews(app_name=app_bundle_id, app_id=app_id, count=100)
                all_reviews.extend(reviews)
        except Exception as e:
            logger.error(f"Error searching iTunes API for iOS apps: {e}")
            
        return all_reviews, competitors_list
    
    except Exception as e:
        logger.error(f"Error during competitor discovery and scraping: {e}")
        return [], []
