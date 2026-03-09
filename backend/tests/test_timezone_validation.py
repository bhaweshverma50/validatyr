"""Tests for timezone validation logic in scheduling."""

import pytest
from zoneinfo import ZoneInfo
from pydantic import ValidationError


# ---------------------------------------------------------------------------
# _parse_schedule tests
# ---------------------------------------------------------------------------

from services.research_scheduler import _parse_schedule, _DEFAULT_TZ


class TestParseSchedule:
    """Test schedule string → CronTrigger parsing with timezone."""

    def _tz(self, name: str = "Asia/Kolkata") -> ZoneInfo:
        return ZoneInfo(name)

    def test_daily_with_time(self):
        trigger = _parse_schedule("daily|21:00", self._tz())
        assert trigger is not None
        # CronTrigger fields list — check hour/minute
        fields = {f.name: f for f in trigger.fields}
        assert str(fields["hour"]) == "21"
        assert str(fields["minute"]) == "0"
        assert trigger.timezone == self._tz()

    def test_daily_legacy_defaults_to_0600(self):
        trigger = _parse_schedule("daily", self._tz())
        assert trigger is not None
        fields = {f.name: f for f in trigger.fields}
        assert str(fields["hour"]) == "6"
        assert str(fields["minute"]) == "0"

    def test_weekly_with_day_and_time(self):
        trigger = _parse_schedule("weekly|3|14:30", self._tz())
        assert trigger is not None
        fields = {f.name: f for f in trigger.fields}
        assert str(fields["day_of_week"]) == "wed"
        assert str(fields["hour"]) == "14"
        assert str(fields["minute"]) == "30"

    def test_weekly_legacy_defaults_to_monday_0600(self):
        trigger = _parse_schedule("weekly", self._tz())
        assert trigger is not None
        fields = {f.name: f for f in trigger.fields}
        assert str(fields["day_of_week"]) == "mon"
        assert str(fields["hour"]) == "6"

    def test_unknown_kind_returns_none(self):
        assert _parse_schedule("monthly|01|09:00", self._tz()) is None
        assert _parse_schedule("", self._tz()) is None

    def test_timezone_is_applied(self):
        tz_ny = ZoneInfo("America/New_York")
        trigger = _parse_schedule("daily|09:00", tz_ny)
        assert trigger is not None
        assert trigger.timezone == tz_ny

    def test_different_timezones_produce_different_triggers(self):
        t1 = _parse_schedule("daily|21:00", ZoneInfo("Asia/Kolkata"))
        t2 = _parse_schedule("daily|21:00", ZoneInfo("US/Eastern"))
        assert t1 is not None and t2 is not None
        # Same hour/minute but different timezone objects
        assert t1.timezone != t2.timezone


# ---------------------------------------------------------------------------
# API request model timezone validation tests
# ---------------------------------------------------------------------------

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from api.research_routes import CreateTopicRequest, UpdateTopicRequest


class TestTimezoneValidation:
    """Test Pydantic validator rejects invalid timezone strings."""

    def test_valid_timezone_accepted(self):
        req = CreateTopicRequest(domain="apps", keywords=["test"], timezone="Asia/Kolkata")
        assert req.timezone == "Asia/Kolkata"

    def test_none_timezone_accepted(self):
        req = CreateTopicRequest(domain="apps", keywords=["test"])
        assert req.timezone is None

    def test_utc_accepted(self):
        req = CreateTopicRequest(domain="apps", keywords=["test"], timezone="UTC")
        assert req.timezone == "UTC"

    def test_us_eastern_accepted(self):
        req = CreateTopicRequest(domain="apps", keywords=["test"], timezone="US/Eastern")
        assert req.timezone == "US/Eastern"

    def test_invalid_timezone_rejected(self):
        with pytest.raises(ValidationError) as exc_info:
            CreateTopicRequest(domain="apps", keywords=["test"], timezone="Not/A/Zone")
        assert "Invalid IANA timezone" in str(exc_info.value)

    def test_empty_string_timezone_rejected(self):
        with pytest.raises(ValidationError) as exc_info:
            CreateTopicRequest(domain="apps", keywords=["test"], timezone="")
        assert "Invalid IANA timezone" in str(exc_info.value)

    def test_garbage_timezone_rejected(self):
        with pytest.raises(ValidationError) as exc_info:
            CreateTopicRequest(domain="apps", keywords=["test"], timezone="abc123")
        assert "Invalid IANA timezone" in str(exc_info.value)

    def test_update_request_validates_timezone_too(self):
        with pytest.raises(ValidationError):
            UpdateTopicRequest(timezone="Fake/Zone")

    def test_update_request_accepts_valid_timezone(self):
        req = UpdateTopicRequest(timezone="Europe/London")
        assert req.timezone == "Europe/London"


# ---------------------------------------------------------------------------
# _add_topic_job fallback tests
# ---------------------------------------------------------------------------

from services.research_scheduler import _add_topic_job, get_scheduler, _DEFAULT_TZ


class TestAddTopicJobFallback:
    """Test that _add_topic_job handles invalid timezone gracefully."""

    def test_invalid_timezone_falls_back_to_default(self):
        """A topic with a bad timezone should still get scheduled (using default TZ)."""
        scheduler = get_scheduler()
        topic = {
            "id": "test-bad-tz",
            "schedule_cron": "daily|10:00",
            "timezone": "Not/Real/Zone",
        }
        _add_topic_job(topic)
        job = scheduler.get_job("research_test-bad-tz")
        assert job is not None
        # Should have fallen back to default timezone
        assert job.trigger.timezone == ZoneInfo(_DEFAULT_TZ)
        # Cleanup
        scheduler.remove_job("research_test-bad-tz")

    def test_none_timezone_uses_default(self):
        scheduler = get_scheduler()
        topic = {
            "id": "test-none-tz",
            "schedule_cron": "daily|08:00",
            "timezone": None,
        }
        _add_topic_job(topic)
        job = scheduler.get_job("research_test-none-tz")
        assert job is not None
        assert job.trigger.timezone == ZoneInfo(_DEFAULT_TZ)
        scheduler.remove_job("research_test-none-tz")

    def test_valid_timezone_is_used(self):
        scheduler = get_scheduler()
        topic = {
            "id": "test-valid-tz",
            "schedule_cron": "daily|20:00",
            "timezone": "America/New_York",
        }
        _add_topic_job(topic)
        job = scheduler.get_job("research_test-valid-tz")
        assert job is not None
        assert job.trigger.timezone == ZoneInfo("America/New_York")
        scheduler.remove_job("research_test-valid-tz")
