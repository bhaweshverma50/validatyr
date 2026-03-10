import json
import logging
import os
from typing import Any

import firebase_admin
from firebase_admin import credentials, messaging
from supabase import Client, create_client

logger = logging.getLogger(__name__)


def _get_supabase() -> Client | None:
    url = os.getenv("SUPABASE_URL")
    key = os.getenv("SUPABASE_KEY")
    if not url or not key:
        return None
    try:
        return create_client(url, key)
    except Exception as exc:
        logger.warning(f"Push service could not create Supabase client: {exc}")
        return None


def _get_firebase_app() -> firebase_admin.App | None:
    try:
        return firebase_admin.get_app()
    except ValueError:
        pass

    raw_json = os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON")
    json_path = os.getenv("FIREBASE_SERVICE_ACCOUNT_PATH")

    if not raw_json and not json_path:
        logger.info("Firebase service account credentials are not configured.")
        return None

    try:
        if raw_json:
            cred = credentials.Certificate(json.loads(raw_json))
        else:
            cred = credentials.Certificate(json_path)

        options: dict[str, Any] = {}
        project_id = os.getenv("FIREBASE_PROJECT_ID")
        if project_id:
            options["projectId"] = project_id

        return firebase_admin.initialize_app(cred, options or None)
    except Exception as exc:
        logger.warning(f"Failed to initialize Firebase Admin SDK: {exc}")
        return None


def _list_push_tokens(user_id: str | None = None) -> list[str]:
    supabase = _get_supabase()
    if not supabase:
        return []

    try:
        query = supabase.table("push_tokens").select("token")
        if user_id:
            query = query.eq("user_id", user_id)
        response = query.execute()
        rows = response.data or []
        return [row["token"] for row in rows if row.get("token")]
    except Exception as exc:
        logger.warning(f"Failed to load push tokens: {exc}")
        return []


def _delete_push_token(token: str) -> None:
    supabase = _get_supabase()
    if not supabase:
        return
    try:
        supabase.table("push_tokens").delete().eq("token", token).execute()
    except Exception as exc:
        logger.warning(f"Failed to delete invalid push token: {exc}")


def _stringify_data(data: dict[str, Any]) -> dict[str, str]:
    stringified: dict[str, str] = {}
    for key, value in data.items():
        if value is None:
            continue
        if isinstance(value, (dict, list)):
            stringified[key] = json.dumps(value)
        else:
            stringified[key] = str(value)
    return stringified


def send_push_notification(title: str, body: str, data: dict[str, Any] | None = None, user_id: str | None = None) -> int:
    app = _get_firebase_app()
    if not app:
        return 0

    tokens = _list_push_tokens(user_id)
    if not tokens:
        logger.info("No push tokens registered; skipping FCM send.")
        return 0

    payload = _stringify_data(data or {})
    sent_count = 0

    for token in tokens:
        message = messaging.Message(
            token=token,
            notification=messaging.Notification(title=title, body=body),
            data=payload,
            android=messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(
                    channel_id="validatyr_notifications"
                ),
            ),
            apns=messaging.APNSConfig(
                headers={"apns-priority": "10"},
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(content_available=True, sound="default")
                ),
            ),
        )

        try:
            messaging.send(message, app=app)
            sent_count += 1
        except Exception as exc:
            error_text = str(exc)
            logger.warning(f"Failed to send push notification: {error_text}")
            if (
                "registration-token-not-registered" in error_text
                or "Requested entity was not found" in error_text
            ):
                _delete_push_token(token)

    return sent_count
