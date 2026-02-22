import os
import logging
from supabase import create_client, Client
from dotenv import load_dotenv

load_dotenv()
logger = logging.getLogger(__name__)

def get_supabase() -> Client:
    url: str = os.getenv("SUPABASE_URL")
    key: str = os.getenv("SUPABASE_KEY")
    if not url or not key:
        logger.warning("Supabase credentials not found in environment. Database operations will be mocked.")
        return None
    try:
        return create_client(url, key)
    except Exception as e:
        logger.error(f"Failed to initialize Supabase client: {e}")
        return None

def save_validation_result(idea: str, result: dict) -> dict:
    """Save the AI validation result to Supabase."""
    supabase = get_supabase()
    
    data_payload = {
        "idea": idea,
        "opportunity_score": result.get("opportunity_score", 0),
        "what_users_love": result.get("what_users_love", []),
        "what_users_hate": result.get("what_users_hate", []),
        "mvp_roadmap": result.get("mvp_roadmap", []),
        "pricing_suggestion": result.get("pricing_suggestion", ""),
        "target_os_recommendation": result.get("target_os_recommendation", ""),
        "market_breakdown": result.get("market_breakdown", ""),
        "score_breakdown": result.get("score_breakdown", {}),
    }
    
    if not supabase:
        logger.info(f"[MOCKED DB SAVE] Validation data for '{idea}' would be saved to Supabase: {data_payload}")
        return {"status": "mocked", "data": data_payload}

    try:
        # Assuming you will create a table named 'validations' in Supabase
        response = supabase.table("validations").insert(data_payload).execute()
        logger.info(f"Successfully saved validation record to Supabase.")
        return {"status": "success", "data": response.data}
    except Exception as e:
        logger.error(f"Error saving to Supabase: {e}")
        return {"status": "error", "message": str(e)}
