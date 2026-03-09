"""Pydantic models for the research feature."""

from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, Field


class ResearchTopic(BaseModel):
    """A saved research topic configuration."""
    id: str = ""
    domain: str = Field(description="Research domain: apps, saas, hardware, fintech, general")
    keywords: List[str] = Field(default_factory=list, description="Search keywords")
    interests: List[str] = Field(default_factory=list, description="Focus areas or interests")
    schedule_cron: Optional[str] = Field(default=None, description="Schedule: 'daily', 'weekly', or None for manual")
    timezone: str = Field(default="Asia/Kolkata", description="IANA timezone for schedule (e.g. Asia/Kolkata, US/Eastern)")
    is_active: bool = True
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None


class ResearchIdea(BaseModel):
    """A single generated business idea from research."""
    name: str
    one_liner: str
    problem_statement: str
    trend_evidence: List[str] = Field(default_factory=list)
    category: str = Field(description="apps, saas, hardware, fintech, general")
    opportunity_score: int = Field(ge=0, le=100)
    suggested_features: List[str] = Field(default_factory=list)
    monetization_hint: str = ""
    trend_type: str = Field(description="pain_point, rising_demand, or follow_trend")


class ResearchReport(BaseModel):
    """A complete research report with ideas."""
    id: str = ""
    topic_id: str = ""
    executive_summary: str = ""
    market_overview: str = ""
    ideas: List[ResearchIdea] = Field(default_factory=list)
    data_sources: List[str] = Field(default_factory=list)
    generated_at: Optional[datetime] = None


class ResearchJobStatus(BaseModel):
    """Status of a running or completed research job."""
    job_id: str
    topic_id: str = ""
    status: str = "pending"
    current_step: Optional[str] = None
    progress_pct: int = 0
    report_id: Optional[str] = None
    error: Optional[str] = None


class TrendScoutOutput(BaseModel):
    """Output from the Trend Scout agent."""
    trending_topics: List[str] = Field(description="Top 10-15 trending topics, complaints, and 'I wish X existed' posts found across forums, news, and app stores.")
    pain_points: List[str] = Field(description="Top 10 specific pain points users are vocal about — include source attribution.")
    rising_categories: List[str] = Field(description="Top 5 categories or niches showing growth in discussions, launches, or downloads.")
    raw_signals: List[str] = Field(description="Top 10 raw quotes or data points from Reddit, HN, Twitter, ProductHunt, news sites — include [source] tag.")


class MarketAnalystOutput(BaseModel):
    """Output from the Market Analyst agent."""
    validated_trends: List[str] = Field(description="Top 8-10 trends cross-referenced with funding data and market growth signals. Each should cite evidence.")
    funding_signals: List[str] = Field(description="Top 5 funding/VC signals: recent raises, YC batches, notable investments in this space.")
    market_gaps: List[str] = Field(description="Top 5 underserved areas where demand exceeds supply of solutions.")
    competition_landscape: str = Field(description="2-3 sentence overview of how crowded or open the space is.")


class ReportSummaryOutput(BaseModel):
    """Output from the Report Compiler — executive summary and market overview."""
    executive_summary: str = Field(description="3-4 sentences summarizing the key opportunity landscape.")
    market_overview: str = Field(description="3-4 sentences on macro trends, funding environment, and competitive dynamics.")


class IdeaGeneratorOutput(BaseModel):
    """Output from the Idea Generator agent — the main deliverable."""
    ideas: List[ResearchIdea] = Field(description="5-10 concrete business/app ideas with scores and evidence.")
