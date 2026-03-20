"""Tests for the job history DB function."""

import pytest
from unittest.mock import patch, MagicMock

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))


def _mock_supabase_response(data):
    mock = MagicMock()
    chain = mock.table.return_value.select.return_value.eq.return_value.order.return_value.limit.return_value.execute
    response = MagicMock()
    response.data = data
    chain.return_value = response
    return mock


class TestListJobsForTopic:
    def test_returns_empty_when_no_supabase(self):
        from services.research_db import list_jobs_for_topic
        with patch("services.research_db.get_supabase", return_value=None):
            result = list_jobs_for_topic("topic-123")
        assert result == []

    def test_returns_jobs_list(self):
        from services.research_db import list_jobs_for_topic
        mock_supabase = _mock_supabase_response([
            {"id": "j1", "status": "completed", "started_at": "2026-03-20T10:00:00Z"},
            {"id": "j2", "status": "failed", "started_at": "2026-03-19T10:00:00Z"},
        ])
        with patch("services.research_db.get_supabase", return_value=mock_supabase):
            result = list_jobs_for_topic("topic-123", limit=10)
        assert len(result) == 2
        assert result[0]["id"] == "j1"

    def test_respects_limit(self):
        from services.research_db import list_jobs_for_topic
        mock_supabase = _mock_supabase_response([{"id": "j1"}])
        with patch("services.research_db.get_supabase", return_value=mock_supabase):
            list_jobs_for_topic("topic-123", limit=5)
        mock_supabase.table.return_value.select.return_value.eq.return_value.order.return_value.limit.assert_called_once_with(5)
