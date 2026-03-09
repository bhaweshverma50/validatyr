"""Tests for schedule_cron validation and cron-trigger auth."""

import pytest
from pydantic import ValidationError
from zoneinfo import ZoneInfo

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from api.research_routes import CreateTopicRequest, UpdateTopicRequest


class TestScheduleCronValidation:
    """Test that schedule_cron strings are validated at API boundaries."""

    # --- Valid formats ---

    def test_daily_bare(self):
        req = CreateTopicRequest(domain="apps", schedule_cron="daily")
        assert req.schedule_cron == "daily"

    def test_daily_with_time(self):
        req = CreateTopicRequest(domain="apps", schedule_cron="daily|21:00")
        assert req.schedule_cron == "daily|21:00"

    def test_daily_midnight(self):
        req = CreateTopicRequest(domain="apps", schedule_cron="daily|0:00")
        assert req.schedule_cron == "daily|0:00"

    def test_weekly_bare(self):
        req = CreateTopicRequest(domain="apps", schedule_cron="weekly")
        assert req.schedule_cron == "weekly"

    def test_weekly_with_day(self):
        req = CreateTopicRequest(domain="apps", schedule_cron="weekly|3")
        assert req.schedule_cron == "weekly|3"

    def test_weekly_with_day_and_time(self):
        req = CreateTopicRequest(domain="apps", schedule_cron="weekly|5|14:30")
        assert req.schedule_cron == "weekly|5|14:30"

    def test_none_schedule_accepted(self):
        req = CreateTopicRequest(domain="apps")
        assert req.schedule_cron is None

    # --- Invalid formats ---

    def test_monthly_rejected(self):
        with pytest.raises(ValidationError) as exc_info:
            CreateTopicRequest(domain="apps", schedule_cron="monthly|01|09:00")
        assert "Invalid schedule_cron format" in str(exc_info.value)

    def test_empty_string_rejected(self):
        with pytest.raises(ValidationError) as exc_info:
            CreateTopicRequest(domain="apps", schedule_cron="")
        assert "Invalid schedule_cron format" in str(exc_info.value)

    def test_garbage_rejected(self):
        with pytest.raises(ValidationError) as exc_info:
            CreateTopicRequest(domain="apps", schedule_cron="every tuesday at noon")
        assert "Invalid schedule_cron format" in str(exc_info.value)

    def test_cron_expression_rejected(self):
        with pytest.raises(ValidationError) as exc_info:
            CreateTopicRequest(domain="apps", schedule_cron="0 6 * * 1")
        assert "Invalid schedule_cron format" in str(exc_info.value)

    def test_invalid_hour_rejected(self):
        with pytest.raises(ValidationError) as exc_info:
            CreateTopicRequest(domain="apps", schedule_cron="daily|25:00")
        assert "Invalid time" in str(exc_info.value)

    def test_invalid_minute_rejected(self):
        with pytest.raises(ValidationError) as exc_info:
            CreateTopicRequest(domain="apps", schedule_cron="daily|10:61")
        assert "Invalid time" in str(exc_info.value)

    def test_invalid_day_number_rejected(self):
        with pytest.raises(ValidationError) as exc_info:
            CreateTopicRequest(domain="apps", schedule_cron="weekly|8|10:00")
        assert "Invalid schedule_cron format" in str(exc_info.value)

    def test_weekly_day_zero_rejected(self):
        with pytest.raises(ValidationError) as exc_info:
            CreateTopicRequest(domain="apps", schedule_cron="weekly|0|10:00")
        assert "Invalid schedule_cron format" in str(exc_info.value)

    # --- Update request also validates ---

    def test_update_validates_schedule(self):
        with pytest.raises(ValidationError):
            UpdateTopicRequest(schedule_cron="bad_format")

    def test_update_accepts_valid_schedule(self):
        req = UpdateTopicRequest(schedule_cron="daily|08:00")
        assert req.schedule_cron == "daily|08:00"


from services.research_scheduler import _parse_schedule as _parse


class TestParseScheduleFailSafe:
    """Test that _parse_schedule never raises, even with malformed input."""

    def _tz(self):
        return ZoneInfo("UTC")

    def test_completely_garbage_input(self):
        result = _parse("not-a-schedule-at-all", self._tz())
        assert result is None

    def test_empty_string(self):
        result = _parse("", self._tz())
        assert result is None

    def test_daily_with_bad_time_format(self):
        # "daily|abc" — should not raise, should return None or fallback
        result = _parse("daily|abc", self._tz())
        assert result is None  # fails to parse, caught by except

    def test_weekly_with_non_numeric_day(self):
        result = _parse("weekly|x|10:00", self._tz())
        assert result is None  # int("x") fails, caught by except

    def test_valid_daily_still_works(self):
        result = _parse("daily|09:30", self._tz())
        assert result is not None
        fields = {f.name: f for f in result.fields}
        assert str(fields["hour"]) == "9"
        assert str(fields["minute"]) == "30"

    def test_valid_weekly_still_works(self):
        result = _parse("weekly|2|15:00", self._tz())
        assert result is not None
        fields = {f.name: f for f in result.fields}
        assert str(fields["day_of_week"]) == "tue"


class TestCancellationRegistry:
    """Test pipeline cancellation mechanics."""

    def test_cancel_event_signals_correctly(self):
        import threading
        from api.routes import _cancel_events, _check_cancelled, _Cancelled

        job_id = "test-cancel-001"
        _cancel_events[job_id] = threading.Event()

        # Not cancelled yet — should not raise
        _check_cancelled(job_id)

        # Set cancel
        _cancel_events[job_id].set()

        # Now should raise
        with pytest.raises(_Cancelled):
            _check_cancelled(job_id)

        # Cleanup
        _cancel_events.pop(job_id, None)

    def test_check_cancelled_noop_for_unknown_job(self):
        from api.routes import _check_cancelled
        # Should not raise for a job that doesn't exist in the registry
        _check_cancelled("nonexistent-job-id")
