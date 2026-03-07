"""Research pipeline: 3-agent chain that discovers trends and generates business ideas.

Agent chain:
  1. Trend Scout — scrapes/searches for trending topics, pain points, rising categories
  2. Market Analyst — cross-references with funding data, validates market signals
  3. Idea Generator — synthesizes 5-10 concrete business ideas with scores

Uses the same Gemini patterns as ai_analyzer.py:
  - google-genai SDK
  - response_mime_type="application/json" + response_schema
  - Google Search grounding for live data
"""

import os
import json
import uuid
import logging
from datetime import datetime, timezone

from google import genai
from google.genai import types

from services.research_models import (
    TrendScoutOutput,
    MarketAnalystOutput,
    IdeaGeneratorOutput,
    ReportSummaryOutput,
    ResearchReport,
)
from services.research_db import (
    create_research_job,
    update_research_job,
    save_research_report,
)
from services.community_scraper import CommunityScraperService

logger = logging.getLogger(__name__)

_DOMAIN_TO_CATEGORY = {
    "apps": "mobile_app",
    "saas": "saas_web",
    "hardware": "hardware",
    "fintech": "fintech",
    "general": "mobile_app",
}


def run_research_pipeline(
    domain: str,
    keywords: list[str],
    interests: list[str],
    topic_id: str = "",
) -> ResearchReport:
    """Execute the full 3-agent research pipeline."""
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        raise ValueError("GEMINI_API_KEY not set.")

    client = genai.Client(api_key=api_key)

    job = create_research_job(topic_id)
    job_id = job.get("id", str(uuid.uuid4()))

    try:
        # Step 1: Community Scraping
        update_research_job(job_id, {"status": "running", "current_step": "community_scraping", "progress_pct": 0})
        category = _DOMAIN_TO_CATEGORY.get(domain, "mobile_app")
        community_text = ""
        community_succeeded = False
        try:
            scraper = CommunityScraperService(category)
            community_result = scraper.scrape_all(
                competitor_names=[],
                idea_keywords=" ".join(keywords),
            )
            community_text = json.dumps([p.model_dump() for p in community_result.posts[:50]])
            community_succeeded = community_result.total_posts > 0
            logger.info(f"Research community scraping: {community_result.total_posts} posts")
        except Exception as e:
            logger.warning(f"Community scraping failed (continuing): {e}")

        # Step 2: Trend Scout Agent
        update_research_job(job_id, {"current_step": "trend_scout", "status": "running", "progress_pct": 20})
        logger.info("Research Agent 1 (Trend Scout) starting...")
        scout_result = _run_trend_scout(client, domain, keywords, interests, community_text)

        # Step 3: Market Analyst Agent
        update_research_job(job_id, {"current_step": "market_analyst", "progress_pct": 40})
        logger.info("Research Agent 2 (Market Analyst) starting...")
        analyst_result = _run_market_analyst(client, domain, keywords, scout_result)

        # Step 4: Idea Generator Agent
        update_research_job(job_id, {"current_step": "idea_generator", "progress_pct": 60})
        logger.info("Research Agent 3 (Idea Generator) starting...")
        ideas_result = _run_idea_generator(client, domain, keywords, interests, scout_result, analyst_result)

        # Step 5: Compile Report
        update_research_job(job_id, {"current_step": "compiling_report", "progress_pct": 80})
        report = _compile_report(client, domain, keywords, scout_result, analyst_result, ideas_result, topic_id, community_succeeded)

        saved = save_research_report(report.model_dump())
        report_id = saved.get("data", {}).get("id", report.id)

        update_research_job(job_id, {
            "status": "completed",
            "current_step": "done",
            "progress_pct": 100,
            "report_id": report_id,
            "completed_at": datetime.now(timezone.utc).isoformat(),
        })

        logger.info(f"Research pipeline completed. Report {report_id} with {len(report.ideas)} ideas.")
        return report

    except Exception as e:
        logger.error(f"Research pipeline failed: {e}", exc_info=True)
        update_research_job(job_id, {
            "status": "failed",
            "error": str(e),
            "completed_at": datetime.now(timezone.utc).isoformat(),
        })
        raise


def _run_trend_scout(
    client: genai.Client,
    domain: str,
    keywords: list[str],
    interests: list[str],
    community_data: str = "",
) -> TrendScoutOutput:
    """Agent 1: Discovers trending topics, pain points, and rising categories."""
    keywords_str = ", ".join(keywords) if keywords else "general technology"
    interests_str = ", ".join(interests) if interests else "no specific focus"

    community_section = ""
    if community_data:
        community_section = f"""
── SCRAPED COMMUNITY DATA ──
Real posts scraped from Reddit, HackerNews, Twitter, Product Hunt:
{community_data}
Use these as PRIMARY evidence. Supplement with Google Search.
"""

    prompt = f"""You are an expert Trend Scout researching the "{domain}" space.

Keywords to focus on: {keywords_str}
Interests/focus areas: {interests_str}
{community_section}

Use Google Search to actively research ALL of the following sources:

1. REDDIT — Search r/startups, r/SideProject, r/entrepreneur, r/apps, r/SaaS, and niche subreddits for:
   - "I wish there was an app/tool that..." posts
   - Complaints about existing solutions
   - "What are you building?" threads
   - Feature request discussions

2. HACKERNEWS — Search for:
   - "Ask HN: What are you working on?" threads
   - "Show HN" launches gaining traction
   - Discussions about problems needing solutions

3. TWITTER/X — Search for:
   - Viral complaint tweets about existing products
   - "#buildinpublic" trends in this space
   - Founder discussions about market gaps

4. PRODUCT HUNT — Search for:
   - Recently launched products in this space (last 3-6 months)
   - Products with high upvotes (indicating demand)
   - Comment sections revealing unmet needs

5. TECH NEWS — Search TechCrunch, The Verge, Wired for:
   - Emerging technology trends
   - Industry reports and market shifts
   - New regulations creating opportunities

6. APP STORES / PRODUCT DIRECTORIES — Check:
   - Trending apps in relevant categories
   - New releases gaining traction
   - Categories with high growth

7. GOOGLE TRENDS — Search for:
   - Rising search terms in this domain
   - Seasonal patterns
   - Geographic demand variations

Return structured findings as JSON."""

    response = client.models.generate_content(
        model="gemini-3-flash-preview",
        contents=prompt,
        config=types.GenerateContentConfig(
            temperature=0.3,
            response_mime_type="application/json",
            response_schema=TrendScoutOutput,
            tools=[types.Tool(google_search=types.GoogleSearch())],
        ),
    )
    return TrendScoutOutput.model_validate_json(response.text)


def _run_market_analyst(
    client: genai.Client,
    domain: str,
    keywords: list[str],
    scout_result: TrendScoutOutput,
) -> MarketAnalystOutput:
    """Agent 2: Validates trends with funding data and market evidence."""
    keywords_str = ", ".join(keywords) if keywords else "general"

    prompt = f"""You are a Market Analyst validating trends in the "{domain}" space.
Keywords: {keywords_str}

The Trend Scout found these signals:
- Trending topics: {json.dumps(scout_result.trending_topics)}
- Pain points: {json.dumps(scout_result.pain_points)}
- Rising categories: {json.dumps(scout_result.rising_categories)}
- Raw signals: {json.dumps(scout_result.raw_signals)}

Use Google Search to validate and enrich these findings:

1. FUNDING DATA — Search Crunchbase, TechCrunch for:
   - Recent funding rounds in these trending areas (2024-2026)
   - YC batch companies in these niches
   - Notable VC investments signaling market validation

2. MARKET SIZE — For each promising trend, search for:
   - Market size data and growth projections
   - Industry reports with TAM/SAM figures

3. COMPETITION — For each trend, assess:
   - How many funded startups exist?
   - Are incumbents strong or weak?
   - Where are the gaps?

4. DEMAND VALIDATION — Cross-reference trends with:
   - Google Trends data
   - App store download trends
   - G2/Capterra category growth

Validate which trends are REAL (backed by evidence) vs NOISE (speculation).

Return structured analysis as JSON."""

    response = client.models.generate_content(
        model="gemini-3-flash-preview",
        contents=prompt,
        config=types.GenerateContentConfig(
            temperature=0.2,
            response_mime_type="application/json",
            response_schema=MarketAnalystOutput,
            tools=[types.Tool(google_search=types.GoogleSearch())],
        ),
    )
    return MarketAnalystOutput.model_validate_json(response.text)


def _run_idea_generator(
    client: genai.Client,
    domain: str,
    keywords: list[str],
    interests: list[str],
    scout_result: TrendScoutOutput,
    analyst_result: MarketAnalystOutput,
) -> IdeaGeneratorOutput:
    """Agent 3: Generates 5-10 concrete business ideas from validated trends."""
    keywords_str = ", ".join(keywords) if keywords else "general"
    interests_str = ", ".join(interests) if interests else "no specific focus"

    prompt = f"""You are a Startup Idea Generator creating actionable business ideas in the "{domain}" space.

User's keywords: {keywords_str}
User's interests: {interests_str}

TREND SCOUT FINDINGS:
- Trending topics: {json.dumps(scout_result.trending_topics)}
- Pain points: {json.dumps(scout_result.pain_points)}
- Rising categories: {json.dumps(scout_result.rising_categories)}

MARKET ANALYST VALIDATION:
- Validated trends: {json.dumps(analyst_result.validated_trends)}
- Funding signals: {json.dumps(analyst_result.funding_signals)}
- Market gaps: {json.dumps(analyst_result.market_gaps)}
- Competition landscape: {analyst_result.competition_landscape}

Generate 5-10 concrete business/app ideas. For EACH idea, provide:

1. **name**: A catchy, memorable product name
2. **one_liner**: One sentence pitch (max 15 words)
3. **problem_statement**: What specific problem does this solve? (2-3 sentences)
4. **trend_evidence**: 2-3 bullet points citing WHY this is timely (reference specific trends/data from above)
5. **category**: apps, saas, hardware, fintech, or general
6. **opportunity_score**: 0-100 based on:
   - Pain severity (how bad is the problem?) — 30%
   - Market gap (how underserved?) — 25%
   - Feasibility (can a small team build MVP in <3 months?) — 20%
   - Competition (how open is the market?) — 15%
   - Monetization (clear path to revenue?) — 10%
7. **suggested_features**: 2-3 core MVP features
8. **monetization_hint**: How this makes money (specific pricing model)
9. **trend_type**: Classify as one of:
   - "pain_point" — Solves a specific, vocal pain point
   - "rising_demand" — Rides a growing market wave
   - "follow_trend" — Builds on what's already popular but with a twist

MIX of idea types: include at least 2 pain_point, 2 rising_demand, and 1 follow_trend.
Order by opportunity_score descending.
Be creative but grounded in the evidence above. No generic ideas.

Return structured ideas as JSON."""

    response = client.models.generate_content(
        model="gemini-3-flash-preview",
        contents=prompt,
        config=types.GenerateContentConfig(
            temperature=0.5,
            response_mime_type="application/json",
            response_schema=IdeaGeneratorOutput,
            tools=[types.Tool(google_search=types.GoogleSearch())],
        ),
    )
    return IdeaGeneratorOutput.model_validate_json(response.text)


def _compile_report(
    client: genai.Client,
    domain: str,
    keywords: list[str],
    scout_result: TrendScoutOutput,
    analyst_result: MarketAnalystOutput,
    ideas_result: IdeaGeneratorOutput,
    topic_id: str,
    community_succeeded: bool = False,
) -> ResearchReport:
    """Compile a research report with executive summary and market overview."""
    prompt = f"""Write a concise research report summary for the "{domain}" space (keywords: {", ".join(keywords)}).

Based on these findings:
- {len(scout_result.trending_topics)} trending topics discovered
- {len(analyst_result.validated_trends)} trends validated with market evidence
- {len(ideas_result.ideas)} business ideas generated

Top trends: {json.dumps(scout_result.trending_topics[:5])}
Key market gaps: {json.dumps(analyst_result.market_gaps[:3])}
Top ideas: {json.dumps([i.name for i in ideas_result.ideas[:5]])}

Return JSON with:
- "executive_summary": 3-4 sentences summarizing the key opportunity landscape
- "market_overview": 3-4 sentences on macro trends, funding environment, and competitive dynamics"""

    response = client.models.generate_content(
        model="gemini-3-flash-preview",
        contents=prompt,
        config=types.GenerateContentConfig(
            temperature=0.3,
            response_mime_type="application/json",
            response_schema=ReportSummaryOutput,
        ),
    )
    summary_data = ReportSummaryOutput.model_validate_json(response.text)

    data_sources = ["Google Search Grounding", "Gemini AI"]
    if community_succeeded:
        data_sources.extend(["Reddit", "HackerNews", "Twitter/X", "Product Hunt"])

    return ResearchReport(
        id=str(uuid.uuid4()),
        topic_id=topic_id,
        executive_summary=summary_data.executive_summary,
        market_overview=summary_data.market_overview,
        ideas=ideas_result.ideas,
        data_sources=data_sources,
        generated_at=datetime.now(timezone.utc),
    )
