import os
import logging
from datetime import datetime, timezone
from supabase import create_client, Client
from dotenv import load_dotenv
from services.push_service import send_push_notification

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

def save_validation_result(user_id: str, idea: str, result: dict) -> dict:
    """Save the AI validation result to Supabase."""
    supabase = get_supabase()
    
    data_payload = {
        "user_id": user_id,
        "idea": idea,
        "opportunity_score": result.get("opportunity_score", 0),
        "what_users_love": result.get("what_users_love", []),
        "what_users_hate": result.get("what_users_hate", []),
        "mvp_roadmap": result.get("mvp_roadmap", []),
        "pricing_suggestion": result.get("pricing_suggestion", ""),
        "target_os_recommendation": result.get("target_os_recommendation") or result.get("target_platform_recommendation", ""),
        "market_breakdown": result.get("market_breakdown", ""),
        "score_breakdown": result.get("score_breakdown", {}),
        "community_signals": result.get("community_signals", []),
        "competitors_analyzed": result.get("competitors_analyzed", []),
        "category": result.get("category", "mobile_app"),
        "subcategory": result.get("subcategory", ""),
        "tam": result.get("tam", ""),
        "sam": result.get("sam", ""),
        "som": result.get("som", ""),
        "revenue_model_options": result.get("revenue_model_options", []),
        "top_funded_competitors": result.get("top_funded_competitors", []),
        "funding_landscape": result.get("funding_landscape", ""),
        "go_to_market_strategy": result.get("go_to_market_strategy", ""),
    }
    
    if not supabase:
        logger.info(f"[MOCKED DB SAVE] Validation data for user '{user_id}', idea '{idea}' would be saved to Supabase: {data_payload}")
        return {"status": "mocked", "data": data_payload}

    try:
        # Assuming you will create a table named 'validations' in Supabase
        response = supabase.table("validations").insert(data_payload).execute()
        logger.info(f"Successfully saved validation record to Supabase.")
        return {"status": "success", "data": response.data}
    except Exception as e:
        logger.error(f"Error saving to Supabase: {e}")
        return {"status": "error", "message": str(e)}

def send_notification(user_id: str, type: str, title: str, body: str, metadata: dict | None = None):
    """Insert a notification row into Supabase (triggers Realtime for frontend)."""
    supabase = get_supabase()
    notification_metadata = metadata or {}
    if not supabase:
        logger.info(f"[MOCKED] Notification for user '{user_id}': {type} — {title}")
        send_push_notification(
            title=title,
            body=body,
            data={"type": type, "route": "notification_center", **notification_metadata},
            user_id=user_id,
        )
        return
    try:
        supabase.table("notifications").insert({
            "user_id": user_id,
            "type": type,
            "title": title,
            "body": body,
            "metadata": notification_metadata,
        }).execute()
    except Exception as e:
        logger.warning(f"Failed to send notification: {e}")

    send_push_notification(
        title=title,
        body=body,
        data={"type": type, "route": "notification_center", **notification_metadata},
        user_id=user_id,
    )


def create_validation_job(user_id: str, job_id: str, idea: str, category: str | None) -> None:
    """Insert a new validation_jobs row with status=pending."""
    supabase = get_supabase()
    if not supabase:
        logger.info(f"[MOCKED] create_validation_job for user '{user_id}': {job_id}")
        return
    try:
        supabase.table("validation_jobs").insert({
            "user_id": user_id,
            "id": job_id,
            "idea": idea,
            "category": category,
            "status": "pending",
        }).execute()
    except Exception as e:
        logger.warning(f"Failed to create validation job: {e}")


def update_validation_job(job_id: str, updates: dict) -> None:
    """Update a validation_jobs row by ID with arbitrary fields."""
    supabase = get_supabase()
    if not supabase:
        logger.info(f"[MOCKED] update_validation_job {job_id}: {updates}")
        return
    try:
        supabase.table("validation_jobs").update(updates).eq("id", job_id).execute()
    except Exception as e:
        logger.warning(f"Failed to update validation job: {e}")


def get_validation_job(job_id: str) -> dict | None:
    """Fetch a single validation_jobs row by ID."""
    supabase = get_supabase()
    if not supabase:
        logger.info(f"[MOCKED] get_validation_job {job_id}")
        return None
    try:
        resp = supabase.table("validation_jobs").select("*").eq("id", job_id).maybe_single().execute()
        return resp.data
    except Exception as e:
        logger.warning(f"Failed to get validation job: {e}")
        return None


def list_active_validation_jobs(user_id: str) -> list[dict]:
    """Fetch validation_jobs with status pending or running, newest first."""
    supabase = get_supabase()
    if not supabase:
        logger.info(f"[MOCKED] list_active_validation_jobs for user '{user_id}'")
        return []
    try:
        resp = (
            supabase.table("validation_jobs")
            .select("*")
            .eq("user_id", user_id)
            .in_("status", ["pending", "running"])
            .order("created_at", desc=True)
            .execute()
        )
        return resp.data or []
    except Exception as e:
        logger.warning(f"Failed to list active validation jobs: {e}")
        return []


def upsert_push_token(user_id: str, token: str, platform: str) -> None:
    supabase = get_supabase()
    if not supabase:
        logger.info(f"[MOCKED] upsert_push_token for user '{user_id}': {platform}")
        return
    try:
        supabase.table("push_tokens").upsert({
            "user_id": user_id,
            "token": token,
            "platform": platform,
            "updated_at": datetime.now(timezone.utc).isoformat(),
        }, on_conflict="token").execute()
    except Exception as e:
        logger.warning(f"Failed to upsert push token: {e}")


def delete_push_token(token: str) -> None:
    supabase = get_supabase()
    if not supabase:
        logger.info("[MOCKED] delete_push_token")
        return
    try:
        supabase.table("push_tokens").delete().eq("token", token).execute()
    except Exception as e:
        logger.warning(f"Failed to delete push token: {e}")


def delete_all_validations(user_id: str) -> int:
    """Delete all rows from validations and validation_jobs tables for a user. Returns total deleted."""
    supabase = get_supabase()
    if not supabase:
        logger.info(f"[MOCKED] delete_all_validations for user '{user_id}'")
        return 0
    deleted = 0
    try:
        resp = supabase.table("validation_jobs").delete().eq("user_id", user_id).neq("id", "00000000-0000-0000-0000-000000000000").execute()
        deleted += len(resp.data or [])
    except Exception as e:
        logger.warning(f"Failed to delete validation_jobs: {e}")
    try:
        resp = supabase.table("validations").delete().eq("user_id", user_id).gt("id", 0).execute()
        deleted += len(resp.data or [])
    except Exception as e:
        logger.warning(f"Failed to delete validations: {e}")
    return deleted


def list_push_tokens(user_id: str, platforms: list[str] | None = None) -> list[dict]:
    supabase = get_supabase()
    if not supabase:
        logger.info(f"[MOCKED] list_push_tokens for user '{user_id}'")
        return []
    try:
        query = supabase.table("push_tokens").select("*").eq("user_id", user_id)
        if platforms:
            query = query.in_("platform", platforms)
        resp = query.execute()
        return resp.data or []
    except Exception as e:
        logger.warning(f"Failed to list push tokens: {e}")
        return []
