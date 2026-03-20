"""Tests for cron_trigger structured logging and missed-run catch-up."""

import pytest
import json
import asyncio
import logging
from unittest.mock import patch, MagicMock
from datetime import datetime, timezone, timedelta

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from api.research_routes import cron_trigger, _compute_diff_min


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _make_topic(topic_id="t1", schedule_cron="daily|6:00", is_active=True,
                timezone_str="UTC", domain="apps"):
    return {
        "id": topic_id,
        "schedule_cron": schedule_cron,
        "is_active": is_active,
        "timezone": timezone_str,
        "domain": domain,
        "keywords": ["k"],
        "interests": ["i"],
        "user_id": "u1",
    }


def _schedule_for_now(offset_min=0):
    """Return a 'daily|HH:MM' schedule string that is `offset_min` minutes
    away from the current UTC time."""
    now = datetime.now(timezone.utc)
    target = now - timedelta(minutes=offset_min)
    return f"daily|{target.hour}:{target.minute:02d}"


def _make_job(minutes_ago, now_utc=None):
    """Return a fake job dict whose created_at is `minutes_ago` minutes in the past."""
    if now_utc is None:
        now_utc = datetime.now(timezone.utc)
    ts = (now_utc - timedelta(minutes=minutes_ago)).isoformat()
    return {"created_at": ts, "started_at": ts}


def _fake_loop():
    """Return a mock event loop whose run_in_executor is a no-op."""
    loop = MagicMock()
    loop.run_in_executor = MagicMock(return_value=asyncio.Future())
    loop.run_in_executor.return_value.set_result(None)
    return loop


# ---------------------------------------------------------------------------
# _compute_diff_min unit tests
# ---------------------------------------------------------------------------

class TestComputeDiffMin:
    def test_daily_exact_match(self):
        from zoneinfo import ZoneInfo
        now = datetime(2026, 3, 20, 6, 0, tzinfo=ZoneInfo("UTC"))
        result = _compute_diff_min("daily", ["daily", "6:00"], now)
        assert result == 0

    def test_daily_5_min_past(self):
        from zoneinfo import ZoneInfo
        now = datetime(2026, 3, 20, 6, 5, tzinfo=ZoneInfo("UTC"))
        result = _compute_diff_min("daily", ["daily", "6:00"], now)
        assert result == 5

    def test_daily_midnight_wrap(self):
        from zoneinfo import ZoneInfo
        now = datetime(2026, 3, 20, 23, 55, tzinfo=ZoneInfo("UTC"))
        result = _compute_diff_min("daily", ["daily", "0:00"], now)
        assert result == 5

    def test_weekly_wrong_day(self):
        from zoneinfo import ZoneInfo
        # 2026-03-20 is a Friday => weekday() == 4, which is dow_map key 5
        now = datetime(2026, 3, 20, 6, 0, tzinfo=ZoneInfo("UTC"))
        # weekly|1 means Monday (dow_map 1 -> weekday 0)
        result = _compute_diff_min("weekly", ["weekly", "1", "6:00"], now)
        assert result is None

    def test_weekly_correct_day(self):
        from zoneinfo import ZoneInfo
        # Friday => weekday 4 => dow_map key 5
        now = datetime(2026, 3, 20, 6, 0, tzinfo=ZoneInfo("UTC"))
        result = _compute_diff_min("weekly", ["weekly", "5", "6:00"], now)
        assert result == 0


# ---------------------------------------------------------------------------
# cron_trigger integration tests
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
class TestCronTriggerStructuredLog:
    """Verify that cron_trigger emits a structured JSON log."""

    @patch("api.research_routes.os.getenv", return_value=None)
    @patch("api.research_routes.get_latest_job_for_topic", return_value=None)
    @patch("api.research_routes.list_research_topics")
    @patch("asyncio.get_running_loop")
    async def test_log_contains_required_fields(self, mock_loop, mock_list, mock_job, mock_env, caplog):
        """Structured log must have event, topics_evaluated, topics_triggered, details."""
        mock_loop.return_value = _fake_loop()
        # Schedule exactly at current time so it triggers
        mock_list.return_value = [
            _make_topic("t1", _schedule_for_now(0), timezone_str="UTC"),
        ]

        with caplog.at_level(logging.INFO, logger="api.research_routes"):
            result = await cron_trigger()

        assert result["triggered"] == 1

        log_line = _extract_cron_log(caplog)
        assert log_line is not None, f"No structured log found. Records: {[r.message for r in caplog.records]}"
        assert "event" in log_line
        assert "topics_evaluated" in log_line
        assert "topics_triggered" in log_line
        assert "details" in log_line
        assert isinstance(log_line["details"], list)


@pytest.mark.asyncio
class TestCronTriggerSkipReasons:
    """Verify skip reasons for various topic states."""

    @patch("api.research_routes.os.getenv", return_value=None)
    @patch("api.research_routes.get_latest_job_for_topic", return_value=None)
    @patch("api.research_routes.list_research_topics")
    @patch("asyncio.get_running_loop")
    async def test_inactive_topic_skipped(self, mock_loop, mock_list, mock_job, mock_env, caplog):
        mock_loop.return_value = _fake_loop()
        mock_list.return_value = [
            _make_topic("t1", "daily|6:00", is_active=False),
        ]

        with caplog.at_level(logging.INFO, logger="api.research_routes"):
            result = await cron_trigger()

        assert result["triggered"] == 0
        log_line = _extract_cron_log(caplog)
        assert log_line is not None
        detail = log_line["details"][0]
        assert detail["topic_id"] == "t1"
        assert detail["action"] == "skipped"
        assert detail["reason"] == "inactive"

    @patch("api.research_routes.os.getenv", return_value=None)
    @patch("api.research_routes.get_latest_job_for_topic")
    @patch("api.research_routes.list_research_topics")
    @patch("asyncio.get_running_loop")
    async def test_cooldown_topic_skipped(self, mock_loop, mock_list, mock_job, mock_env, caplog):
        mock_loop.return_value = _fake_loop()
        # Schedule at current time (would normally trigger)
        mock_list.return_value = [
            _make_topic("t1", _schedule_for_now(0), timezone_str="UTC"),
        ]
        # Job ran 10 minutes ago => within 30 min cooldown
        mock_job.return_value = _make_job(10)

        with caplog.at_level(logging.INFO, logger="api.research_routes"):
            result = await cron_trigger()

        assert result["triggered"] == 0
        log_line = _extract_cron_log(caplog)
        detail = _find_detail(log_line, "t1")
        assert detail["action"] == "skipped"
        assert detail["reason"] == "cooldown"

    @patch("api.research_routes.os.getenv", return_value=None)
    @patch("api.research_routes.get_latest_job_for_topic", return_value=None)
    @patch("api.research_routes.list_research_topics")
    @patch("asyncio.get_running_loop")
    async def test_outside_window_skipped(self, mock_loop, mock_list, mock_job, mock_env, caplog):
        mock_loop.return_value = _fake_loop()
        # Schedule 120 minutes away from now => outside ±10 and ±20 window
        mock_list.return_value = [
            _make_topic("t1", _schedule_for_now(-120), timezone_str="UTC"),
        ]

        with caplog.at_level(logging.INFO, logger="api.research_routes"):
            result = await cron_trigger()

        assert result["triggered"] == 0
        log_line = _extract_cron_log(caplog)
        detail = _find_detail(log_line, "t1")
        assert detail["action"] == "skipped"
        assert detail["reason"] == "outside_window"

    @patch("api.research_routes.os.getenv", return_value=None)
    @patch("api.research_routes.get_latest_job_for_topic", return_value=None)
    @patch("api.research_routes.list_research_topics")
    @patch("asyncio.get_running_loop")
    async def test_within_window_triggered(self, mock_loop, mock_list, mock_job, mock_env, caplog):
        mock_loop.return_value = _fake_loop()
        # Schedule 5 minutes ago => within ±10 window
        mock_list.return_value = [
            _make_topic("t1", _schedule_for_now(5), timezone_str="UTC"),
        ]

        with caplog.at_level(logging.INFO, logger="api.research_routes"):
            result = await cron_trigger()

        assert result["triggered"] == 1
        log_line = _extract_cron_log(caplog)
        detail = _find_detail(log_line, "t1")
        assert detail["action"] == "triggered"


@pytest.mark.asyncio
class TestCronTriggerMissedRunCatchup:
    """Verify that topics whose scheduled time is 11-20 min in the past
    with no previous job are still triggered (catch-up)."""

    @patch("api.research_routes.os.getenv", return_value=None)
    @patch("api.research_routes.get_latest_job_for_topic", return_value=None)
    @patch("api.research_routes.list_research_topics")
    @patch("asyncio.get_running_loop")
    async def test_missed_run_catchup_triggered(self, mock_loop, mock_list, mock_job, mock_env, caplog):
        mock_loop.return_value = _fake_loop()
        # Schedule 15 min ago => outside ±10 window but within 20 min, no prior job
        mock_list.return_value = [
            _make_topic("t1", _schedule_for_now(15), timezone_str="UTC"),
        ]

        with caplog.at_level(logging.INFO, logger="api.research_routes"):
            result = await cron_trigger()

        assert result["triggered"] == 1
        log_line = _extract_cron_log(caplog)
        detail = _find_detail(log_line, "t1")
        assert detail["action"] == "triggered"

    @patch("api.research_routes.os.getenv", return_value=None)
    @patch("api.research_routes.get_latest_job_for_topic")
    @patch("api.research_routes.list_research_topics")
    @patch("asyncio.get_running_loop")
    async def test_missed_run_with_existing_job_not_caught_up(self, mock_loop, mock_list, mock_job, mock_env, caplog):
        """If there IS a previous job (even old), missed-run catch-up should NOT fire."""
        mock_loop.return_value = _fake_loop()
        # Schedule 15 min ago => outside ±10 window, within 20 min
        mock_list.return_value = [
            _make_topic("t1", _schedule_for_now(15), timezone_str="UTC"),
        ]
        # Old job from 2 hours ago (past cooldown, but exists)
        mock_job.return_value = _make_job(120)

        with caplog.at_level(logging.INFO, logger="api.research_routes"):
            result = await cron_trigger()

        assert result["triggered"] == 0
        log_line = _extract_cron_log(caplog)
        detail = _find_detail(log_line, "t1")
        assert detail["action"] == "skipped"
        assert detail["reason"] == "outside_window"


# ---------------------------------------------------------------------------
# Helpers for extracting log data
# ---------------------------------------------------------------------------

def _extract_cron_log(caplog):
    for record in caplog.records:
        try:
            parsed = json.loads(record.message)
            if parsed.get("event") == "cron_trigger_completed":
                return parsed
        except (json.JSONDecodeError, TypeError):
            continue
    return None


def _find_detail(log_line, topic_id):
    assert log_line is not None, "No structured cron log found"
    for d in log_line["details"]:
        if d["topic_id"] == topic_id:
            return d
    raise AssertionError(f"No detail found for topic_id={topic_id}")
