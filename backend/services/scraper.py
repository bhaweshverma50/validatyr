import logging
from typing import List, Dict, Any
from google_play_scraper import reviews, Sort
import requests
import json

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def scrape_play_store_reviews(app_id: str, count: int = 500, lang: str = 'en', country: str = 'us') -> List[Dict[str, Any]]:
    """Scrape reviews from Google Play Store."""
    try:
        logger.info(f"Scraping up to {count} reviews for Play Store app {app_id}...")
        result, _ = reviews(
            app_id,
            lang=lang,
            country=country,
            sort=Sort.NEWEST,
            count=count
        )
        parsed = [
            {
                "id": str(r["reviewId"]),
                "content": r["content"],
                "score": r["score"],
                "date": str(r["at"]),
                "platform": "android"
            }
            for r in result
        ]
        logger.info(f"Successfully scraped {len(parsed)} reviews for {app_id}.")
        return parsed
    except Exception as e:
        logger.error(f"Error scraping Play Store app {app_id}: {e}")
        return []

def scrape_app_store_reviews(app_name: str, app_id: int, count: int = 500, country: str = 'us') -> List[Dict[str, Any]]:
    """Scrape reviews from Apple App Store using public RSS Feed."""
    try:
        logger.info(f"Scraping up to {count} reviews for App Store app {app_name} ({app_id}) via RSS...")
        
        # Apple's public RSS feed for customer reviews
        url = f"https://itunes.apple.com/{country}/rss/customerreviews/page=1/id={app_id}/sortby=mostrecent/json"
        
        response = requests.get(url, timeout=10)
        data = response.json()
        
        parsed = []
        entries = data.get('feed', {}).get('entry', [])
        
        # The first entry is usually the app itself, skip it if it doesn't have an author
        for entry in entries:
            if 'author' not in entry:
                continue
                
            review_id = entry.get('id', {}).get('label', '')
            content = entry.get('content', {}).get('label', '')
            score = int(entry.get('im:rating', {}).get('label', 0))
            
            parsed.append({
                "id": review_id,
                "content": content,
                "score": score,
                "date": "", # RSS feed often doesn't give a strict timestamp without deep parsing
                "platform": "ios"
            })
            
            if len(parsed) >= count:
                break
                
        logger.info(f"Successfully scraped {len(parsed)} reviews for {app_name}.")
        return parsed
    except Exception as e:
        logger.error(f"Error scraping App Store app {app_id}: {e}")
        return []
