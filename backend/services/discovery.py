import os
import json
import logging
import re
from typing import List, Dict, Any, Tuple
from google import genai
from pydantic import BaseModel, Field
from google_play_scraper import search
import requests
from services.scraper import scrape_play_store_reviews, scrape_app_store_reviews

logger = logging.getLogger(__name__)

class SearchQueryOutput(BaseModel):
    query: str = Field(description="A short 3-5 word search query to find competitors.")

class StartupCompetitor(BaseModel):
    title: str = Field(description="Name of the startup or product.")
    url: str = Field(description="URL of the Product Hunt launch, YC page, or website.")
    source: str = Field(description="Where this was found: 'product_hunt', 'ycombinator', or 'web'.")
    description: str = Field(description="One sentence description of what this product does.")

class StartupDiscoveryOutput(BaseModel):
    startups: List[StartupCompetitor] = Field(description="Up to 6 relevant startups or products found from Product Hunt, YCombinator, and the broader web.")

def _discover_web_startups(client: genai.Client, idea: str, query: str) -> List[Dict[str, Any]]:
    """Uses Gemini Google Search grounding to find relevant startups on Product Hunt, YC, and HN."""
    from google.genai import types

    prompt = f"""
    You are a startup market researcher. The user has this app idea: "{idea}"
    The core search query for this space is: "{query}"

    Use Google Search to find up to 6 relevant competing products or startups from these sources:
    1. Product Hunt — search for "{query} site:producthunt.com" to find launched products
    2. YCombinator — search for "{query} site:ycombinator.com" to find YC-funded startups
    3. HackerNews Show HN — search for "Show HN {query}" to find indie launches
    4. Broader web — any notable startups or indie products solving the same problem

    For each, return: title, url, source (product_hunt/ycombinator/web), and a one-sentence description.
    Only include products that are genuinely relevant to the idea. Skip vague matches.
    Return an empty list if nothing relevant is found.
    """

    response = client.models.generate_content(
        model='gemini-3-flash-preview',
        contents=prompt,
        config=types.GenerateContentConfig(
            response_mime_type="application/json",
            response_schema=StartupDiscoveryOutput,
            temperature=0.2,
            tools=[types.Tool(google_search=types.GoogleSearch())]
        ),
    )

    result = StartupDiscoveryOutput(**json.loads(response.text))

    return [
        {
            "app_id": s.url,
            "title": s.title,
            "score": 0.0,
            "icon": "",
            "platform": "web",
            "source": s.source,
        }
        for s in result.startups
    ]

def _discover_hardware_competitors(client: genai.Client, idea: str) -> tuple[list, list]:
    """Hardware ideas: searches Kickstarter, Amazon, YC hardware via Google Search grounding."""
    from google.genai import types
    prompt = f"""You are a hardware startup researcher. For: "{idea}"
Search for similar products on: Kickstarter/Indiegogo, Amazon, YC Hardware portfolio, funded startups.
Return up to 8 competitors as JSON array:
[{{"title": "...", "url": "...", "source": "kickstarter|amazon|ycombinator|web",
  "description": "...", "funding_hint": "..."}}]"""
    response = client.models.generate_content(
        model="gemini-3-flash-preview", contents=prompt,
        config=types.GenerateContentConfig(
            temperature=0.2, tools=[types.Tool(google_search=types.GoogleSearch())],
        ),
    )
    match = re.search(r'\[.*\]', response.text, re.DOTALL)
    if not match:
        logger.warning("No JSON array found in hardware discovery response. Response text: %s", response.text[:200])
        return [], []
    try:
        competitors = json.loads(match.group())
    except json.JSONDecodeError as e:
        logger.warning("Failed to parse JSON from hardware discovery: %s", e)
        return [], []
    metas = [{"app_id": c.get("url",""), "title": c.get("title",""), "score": 0.0,
               "icon": "", "platform": "hardware", "source": c.get("source","web"),
               "description": c.get("description",""), "funding_hint": c.get("funding_hint","")}
              for c in competitors[:8]]
    return [], metas  # no app-store reviews for hardware


def _discover_saas_competitors(client: genai.Client, idea: str) -> tuple[list, list]:
    """SaaS/web ideas: searches ProductHunt, G2, Capterra, YC via Google Search."""
    from google.genai import types
    prompt = f"""You are a SaaS market researcher. For: "{idea}"
Search ProductHunt, G2 alternatives, Capterra, YC SaaS portfolio, Crunchbase funded competitors.
Return up to 8 competitors as JSON array:
[{{"title": "...", "url": "...", "source": "product_hunt|g2|ycombinator|web",
  "description": "...", "pricing_hint": "..."}}]"""
    response = client.models.generate_content(
        model="gemini-3-flash-preview", contents=prompt,
        config=types.GenerateContentConfig(
            temperature=0.2, tools=[types.Tool(google_search=types.GoogleSearch())],
        ),
    )
    match = re.search(r'\[.*\]', response.text, re.DOTALL)
    if not match:
        logger.warning("No JSON array found in saas discovery response. Response text: %s", response.text[:200])
        return [], []
    try:
        competitors = json.loads(match.group())
    except json.JSONDecodeError as e:
        logger.warning("Failed to parse JSON from saas discovery: %s", e)
        return [], []
    metas = [{"app_id": c.get("url",""), "title": c.get("title",""), "score": 0.0,
               "icon": "", "platform": "web", "source": c.get("source","web"),
               "description": c.get("description","")}
              for c in competitors[:8]]
    return [], metas


def discover_competitors_and_scrape(app_idea: str, category: str = "mobile_app") -> Tuple[List[Dict[str, Any]], List[Dict[str, Any]]]:
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

    if category == "hardware":
        return _discover_hardware_competitors(client, app_idea)
    if category == "saas_web":
        return _discover_saas_competitors(client, app_idea)
    # mobile_app and fintech: run existing app store + web discovery (unchanged)

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
                "platform": "android",
                "source": "play_store",
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
                    "platform": "ios",
                    "source": "app_store",
                })
                
                # App Store scraper needs the bundle ID as the app_name string, and numeric trackId
                reviews = scrape_app_store_reviews(app_name=app_bundle_id, app_id=app_id, count=100)
                all_reviews.extend(reviews)
        except Exception as e:
            logger.error(f"Error searching iTunes API for iOS apps: {e}")

        # --- WEB / STARTUP DISCOVERY (Product Hunt, YC, HN) ---
        logger.info("Searching Product Hunt, YCombinator, and HN for startup competitors...")
        try:
            web_startups = _discover_web_startups(client, app_idea, query)
            competitors_list.extend(web_startups)
            logger.info(f"Found {len(web_startups)} web/startup competitors.")
        except Exception as e:
            logger.error(f"Error during web startup discovery: {e}")

        return all_reviews, competitors_list
    
    except Exception as e:
        logger.error(f"Error during competitor discovery and scraping: {e}")
        return [], []
