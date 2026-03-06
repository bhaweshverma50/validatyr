# Research Feature Design

## Overview

Add a proactive market research engine to Validatyr. Instead of validating a specific idea, this feature discovers trending problems and generates 5-10 business/app ideas by scanning forums, news, app stores, and funding data. Users configure research topics with domain/keywords/interests, trigger runs manually or on a cron schedule, and browse results in a channel-style dashboard.

## Architecture

### Approach: Multi-Agent Pipeline

Sequential chain of specialized Gemini agents, consistent with the existing validation pipeline pattern.

```
User Config (domain, keywords, interests)
    |
    v
[Trend Scout Agent]
    Scrapes: Reddit, HN, Twitter, ProductHunt, Indie Hackers,
    TechCrunch, Google Trends, App Store trending, Play Store new releases.
    Uses Gemini Google Search grounding for supplemental discovery.
    Output: raw trending topics, complaints, "I wish X existed" posts
    |
    v
[Market Analyst Agent]
    Cross-references trends with: Crunchbase funding data (via Google Search
    grounding), YC batch data, VC trend signals, app store category growth.
    Output: validated market signals with funding/demand evidence
    |
    v
[Idea Generator Agent]
    Produces 5-10 business ideas, each with:
    - name, one_liner, problem_statement
    - trend_evidence[] (what signals support this)
    - category (app/SaaS/hardware/etc)
    - opportunity_score (quick estimate 0-100)
    - suggested_features[] (2-3 bullets)
    - monetization_hint
    - trend_type: "pain_point" | "rising_demand" | "follow_trend"
    |
    v
[Report Compiler]
    Structures into: executive_summary, market_overview, ideas[],
    data_sources_consulted, generated_at
```

### Background Execution

APScheduler running in-process within the FastAPI server. Each saved topic with a schedule gets its own cron job. Jobs run asynchronously and store results in Supabase.

## Backend

### New Services

- `backend/services/research_pipeline.py` — Orchestrates the 3-agent chain + report compilation
- `backend/services/research_scheduler.py` — APScheduler integration, manages cron jobs for saved topics

### API Endpoints

```
POST   /api/v1/research/start              — Trigger one-off research run
GET    /api/v1/research/reports             — List all reports (paginated)
GET    /api/v1/research/reports/{id}        — Get full report detail
POST   /api/v1/research/topics              — Create/save a research topic
GET    /api/v1/research/topics              — List saved topics
PUT    /api/v1/research/topics/{id}         — Update topic config/schedule
DELETE /api/v1/research/topics/{id}         — Delete topic + cancel cron
POST   /api/v1/research/ideas/{id}/validate — Deep-dive validate a generated idea
GET    /api/v1/research/status/{job_id}     — Poll status of running job
```

### Pydantic Models

```python
class ResearchTopic:
    id: str
    domain: str                    # apps, saas, hardware, fintech, general
    keywords: List[str]
    interests: List[str]
    schedule_cron: Optional[str]   # "daily", "weekly", or None (manual only)
    is_active: bool
    created_at: datetime

class ResearchIdea:
    name: str
    one_liner: str
    problem_statement: str
    trend_evidence: List[str]
    category: str
    opportunity_score: int         # 0-100
    suggested_features: List[str]
    monetization_hint: str
    trend_type: str                # pain_point, rising_demand, follow_trend

class ResearchReport:
    id: str
    topic_id: str
    executive_summary: str
    market_overview: str
    ideas: List[ResearchIdea]
    data_sources: List[str]
    generated_at: datetime

class ResearchJobStatus:
    job_id: str
    status: str                    # pending, running, completed, failed
    current_step: Optional[str]
    progress_pct: int
    report_id: Optional[str]
    error: Optional[str]
```

### Supabase Tables

```sql
research_topics (
    id uuid PK,
    domain text,
    keywords jsonb,
    interests jsonb,
    schedule_cron text,
    is_active boolean DEFAULT true,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
)

research_reports (
    id uuid PK,
    topic_id uuid FK -> research_topics,
    executive_summary text,
    market_overview text,
    ideas jsonb,
    data_sources jsonb,
    generated_at timestamptz DEFAULT now()
)

research_jobs (
    id uuid PK,
    topic_id uuid FK -> research_topics,
    status text DEFAULT 'pending',
    current_step text,
    report_id uuid FK -> research_reports (nullable),
    started_at timestamptz,
    completed_at timestamptz,
    error text
)
```

### Data Sources

The Trend Scout Agent taps into all of these:
- Reddit (existing community_scraper.py)
- HackerNews (existing community_scraper.py)
- Twitter/X (existing community_scraper.py)
- Product Hunt (existing community_scraper.py)
- Indie Hackers (new scraper target)
- TechCrunch / The Verge (via Google Search grounding)
- Google Trends (via Google Search grounding)
- App Store trending/new releases (existing scraper.py)
- Play Store new releases (existing google-play-scraper)
- Crunchbase / funding data (via Google Search grounding)
- YC batch data (via Google Search grounding)

## Frontend

### Navigation

Add bottom navigation bar with 3 tabs:
- Home (existing)
- Research (new)
- History (existing)

### New Screens

#### 1. Research Dashboard (Topic Channels)

Grid/list of saved research topics as RetroCard items. Each card shows:
- Domain icon + name
- Keywords preview
- Schedule badge (Daily/Weekly/Manual)
- Report count
- Last report timestamp
- [+ New] button in app bar

#### 2. New Topic Form

- Domain selector chips: Apps, SaaS, Hardware, FinTech, General
- Keywords text field (comma-separated)
- Interests/focus areas text field
- Schedule radio: Daily, Weekly, Manual only
- "Start Research" RetroButton (saves topic + triggers first run)

#### 3. Topic Channel View (Report Feed)

- Header: topic name + keywords
- Settings (gear) and manual refresh buttons
- Chronological feed of report cards
- Each card: date, idea count, executive summary preview

#### 4. Report Detail View

- Executive summary in RetroCard
- Market overview in RetroCard
- Ideas list — each idea is a RetroCard with:
  - Name + opportunity score badge
  - Trend type tag (pain_point/rising_demand/follow_trend)
  - Problem statement
  - Suggested features
  - [Deep Validate] RetroButton
- Data sources list at bottom

### Deep Validate Flow

Tapping "Deep Validate" on an idea composes the idea's name + one_liner + problem_statement into a text string, then navigates to the existing LoadingScreen → ResultsScreen validation flow via `/api/v1/validate/stream`.

### Job Status UX

- When a research job is running, the topic card shows a pulsing indicator + step text
- User can navigate away and return — status polled from backend
- Failed jobs show error badge; user can retry manually

## Design Decisions

- **No push notifications for MVP** — user checks Research tab for new reports
- **APScheduler in-process** — simple, no Redis/Celery needed, extractable later
- **Tiered depth** — ideas are summaries first; deep validation is on-demand
- **Reuses existing infrastructure** — community_scraper.py, scraper.py, Gemini pipeline patterns, RetroCard/RetroButton widgets, neo-brutalist theme
- **Graceful degradation** — Supabase optional (same pattern as existing db.py)
- **Cost tracking** — job table records per-topic usage for future monitoring
