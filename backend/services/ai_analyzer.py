import os
import json
import logging
from typing import List, Dict, Any, Literal
from google import genai
from google.genai import types
from pydantic import BaseModel, Field, computed_field

logger = logging.getLogger(__name__)

class CategoryDetectionOutput(BaseModel):
    category: Literal["mobile_app", "hardware", "fintech", "saas_web"]
    subcategory: str  # e.g. "ios_only", "cross_platform", "payments", "B2B SaaS", "wearables"
    rationale: str

def detect_category(client: genai.Client, idea: str, user_category: str | None = None) -> CategoryDetectionOutput:
    """If user_category is valid, skip LLM and return it directly."""
    valid = ("mobile_app", "hardware", "fintech", "saas_web")
    if user_category and user_category in valid:
        defaults = {"mobile_app": "cross_platform", "hardware": "consumer hardware",
                    "fintech": "payments", "saas_web": "B2B SaaS"}
        return CategoryDetectionOutput(
            category=user_category, subcategory=defaults[user_category], rationale="User-selected"
        )
    prompt = f"""Classify this startup idea into exactly ONE category:
Idea: "{idea}"
Categories:
- "mobile_app": consumer app via App Store / Play Store
- "hardware": physical product, IoT, wearable, robotics
- "fintech": payments, lending, crypto, insurance tech, banking
- "saas_web": web-based B2B/B2C software, API, developer tool

Also provide a short subcategory (e.g. "ios_only", "cross_platform", "payments", "wearables", "B2B SaaS").
Output JSON: {{"category": "...", "subcategory": "...", "rationale": "..."}}"""
    response = client.models.generate_content(
        model="gemini-2.0-flash",
        contents=prompt,
        config=types.GenerateContentConfig(
            temperature=0.1,
            response_mime_type="application/json",
            response_schema=CategoryDetectionOutput,
        ),
    )
    return CategoryDetectionOutput.model_validate_json(response.text)

# --- Agent Output Schemas ---

class ResearcherOutput(BaseModel):
    what_users_love: List[str] = Field(description="Top 5 aspects users love across these competitors.")
    what_users_hate: List[str] = Field(description="Top 5 pain points and complaints users have with these competitors.")
    community_signals: List[str] = Field(description="Top 5 notable quotes or insights found from Reddit threads, HackerNews discussions, Product Hunt comments, or Twitter/X conversations that reveal unmet needs or strong demand signals.")

class PMOutput(BaseModel):
    mvp_roadmap: List[str] = Field(description="Day-1 MVP feature roadmap designed to solve the pain points identified by the researcher.")

class OpportunityScoreBreakdown(BaseModel):
    pain_severity: int = Field(description="How severe and frequent are the unmet pain points in the market? (0-100)")
    market_gap: int = Field(description="How large is the gap between what users want and what competitors offer? (0-100)")
    mvp_feasibility: int = Field(description="How realistic is the proposed MVP to build and ship quickly? (0-100)")
    competition_density: int = Field(description="How crowded is the market? Invert: 100 = wide open, 0 = saturated with strong players. (0-100)")
    monetization_potential: int = Field(description="How willing are users to pay based on the category and competitor pricing? (0-100)")
    community_demand: int = Field(description="How much active community desire exists for this type of product on Reddit, HN, Product Hunt, and Twitter? 100 = loud vocal demand with many posts/requests, 0 = nobody is talking about this need. (0-100)")
    startup_saturation: int = Field(description="Are well-funded startups already competing in this space? Inverted: 100 = no VC-backed players found, 0 = multiple well-funded startups already exist. (0-100)")

class AnalystOutput(BaseModel):
    score_breakdown: OpportunityScoreBreakdown = Field(description="Individual dimension scores that feed into the weighted opportunity score.")
    pricing_suggestion: str = Field(description="A concise suggestion for the app's monetization strategy.")
    target_os_recommendation: str = Field(description="Recommendation on which OS (iOS, Android, Mac, Windows, Web) to target first and why, based on competitor presence and app type.")
    market_breakdown: str = Field(description="A short analysis of the market split and user behaviors on iOS vs Android for this specific idea.")

class MarketIntelligenceOutput(BaseModel):
    score_breakdown: OpportunityScoreBreakdown
    pricing_suggestion: str
    target_platform_recommendation: str
    market_breakdown: str
    tam: str                              # e.g. "$4.2B global market for X by 2026"
    sam: str                              # serviceable addressable segment
    som: str                              # realistically obtainable year 1-2
    revenue_model_options: List[str]      # 2-4 options with pricing benchmarks
    top_funded_competitors: List[dict]    # [{"name": ..., "funding": ..., "investors": ...}]
    funding_landscape: str               # 2-3 sentence VC narrative
    go_to_market_strategy: str           # 2-3 top GTM channels for this category

# --- Final Aggregated Output ---

class CompetitorInfo(BaseModel):
    app_id: str
    title: str
    score: float
    icon: str
    platform: str
    source: str = "app_store"  # play_store | app_store | product_hunt | ycombinator | web

class IdeaValidationResult(BaseModel):
    opportunity_score: int
    score_breakdown: dict = {}
    what_users_love: List[str]
    what_users_hate: List[str]
    mvp_roadmap: List[str]
    pricing_suggestion: str
    target_platform_recommendation: str = ""
    market_breakdown: str
    competitors_analyzed: List[dict] = []
    community_signals: List[str] = []  # Notable Reddit/HN/PH/Twitter insights
    category: str = "mobile_app"
    subcategory: str = ""
    tam: str = ""
    sam: str = ""
    som: str = ""
    revenue_model_options: List[str] = []
    top_funded_competitors: List[dict] = []
    funding_landscape: str = ""
    go_to_market_strategy: str = ""

    @computed_field
    @property
    def target_os_recommendation(self) -> str:
        return self.target_platform_recommendation

# --- Multi-Agent Orchestrator ---

def analyze_reviews_multi_agent(app_idea: str, reviews: List[Dict[str, Any]], competitors_meta: List[Dict[str, Any]] = None, model_provider: str = "gemini") -> IdeaValidationResult:
    """Orchestrates the Multi-Agent pipeline to validate the app idea."""
    if not reviews:
        raise ValueError("No reviews provided for analysis.")

    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        raise ValueError("GEMINI_API_KEY environment variable not set. Please add it to your .env file.")
        
    client = genai.Client(api_key=api_key)
    
    # Take a sample of reviews to manage context limits
    reviews_sample = reviews[:200]
    reviews_text = json.dumps([{"rating": r["score"], "review": r["content"]} for r in reviews_sample])

    logger.info("Agent 1 (Researcher) is spinning up...")
    researcher_result = run_researcher_agent(client, app_idea, reviews_text)
    
    logger.info("Agent 2 (Product Manager) is spinning up...")
    pm_result = run_pm_agent(client, app_idea, researcher_result)
    
    logger.info("Agent 3 (Business Analyst) is spinning up...")
    analyst_result = run_analyst_agent(client, app_idea, researcher_result, pm_result)

    logger.info("Multi-Agent pipeline completed successfully.")
    
    # Weighted opportunity score from individual dimensions
    breakdown = analyst_result.score_breakdown
    weights = {
        "pain_severity": 0.25,
        "market_gap": 0.20,
        "mvp_feasibility": 0.15,
        "competition_density": 0.15,
        "monetization_potential": 0.10,
        "community_demand": 0.10,
        "startup_saturation": 0.05,
    }
    opportunity_score = round(
        breakdown.pain_severity * weights["pain_severity"]
        + breakdown.market_gap * weights["market_gap"]
        + breakdown.mvp_feasibility * weights["mvp_feasibility"]
        + breakdown.competition_density * weights["competition_density"]
        + breakdown.monetization_potential * weights["monetization_potential"]
        + breakdown.community_demand * weights["community_demand"]
        + breakdown.startup_saturation * weights["startup_saturation"]
    )
    opportunity_score = max(0, min(100, opportunity_score))

    logger.info(
        f"Opportunity score: {opportunity_score} "
        f"(pain={breakdown.pain_severity}, gap={breakdown.market_gap}, "
        f"feasibility={breakdown.mvp_feasibility}, competition={breakdown.competition_density}, "
        f"monetization={breakdown.monetization_potential}, "
        f"community={breakdown.community_demand}, startup_sat={breakdown.startup_saturation})"
    )

    return IdeaValidationResult(
        opportunity_score=opportunity_score,
        score_breakdown=breakdown.model_dump(),
        what_users_love=researcher_result.what_users_love,
        what_users_hate=researcher_result.what_users_hate,
        mvp_roadmap=pm_result.mvp_roadmap,
        pricing_suggestion=analyst_result.pricing_suggestion,
        target_platform_recommendation=analyst_result.target_os_recommendation,
        market_breakdown=analyst_result.market_breakdown,
        competitors_analyzed=competitors_meta or [],
        community_signals=researcher_result.community_signals,
    )

# --- Individual Agents ---

def run_researcher_agent(client: genai.Client, idea: str, reviews_text: str) -> ResearcherOutput:
    prompt = f"""
    You are an expert App Market Researcher with live access to Google Search.
    The user is building an app with this idea: "{idea}"

    Task — gather signal from ALL of the following sources:

    1. SCRAPED APP STORE REVIEWS (provided below) — extract pain points and loves directly.
    2. REDDIT — Search Reddit for threads in r/apps, r/startups, r/entrepreneur, r/SideProject, and any niche subreddits relevant to this idea. Look for complaints about existing tools, feature requests, and "is there an app that does X?" posts.
    3. HACKERNEWS — Search HackerNews for "Ask HN" posts, Show HN launches, and comment threads discussing this problem space.
    4. PRODUCT HUNT — Search Product Hunt for upvoted products in this category. Read the comments and reviews on those products.
    5. TWITTER/X — Search Twitter/X for complaints, feature requests, and discussions about the competitor apps and the problem this idea solves.

    Use Google Search actively for each of these sources. Do not rely only on the scraped reviews.

    From all sources combined, extract:
    - what_users_love: Top 5 things users consistently praise about existing solutions
    - what_users_hate: Top 5 pain points, complaints, or unmet needs (be specific, quote where possible)
    - community_signals: Top 5 notable quotes or insights from Reddit/HN/PH/Twitter that reveal strong demand, frustration, or opportunity (include the source platform)

    SCRAPED APP STORE REVIEWS:
    {reviews_text}
    """
    response = client.models.generate_content(
        model='gemini-3-flash-preview',
        contents=prompt,
        config=types.GenerateContentConfig(
            response_mime_type="application/json",
            response_schema=ResearcherOutput,
            temperature=0.2,
            tools=[{"google_search": {}}]
        ),
    )
    return ResearcherOutput(**json.loads(response.text))

def run_pm_agent(client: genai.Client, idea: str, researcher_data: ResearcherOutput) -> PMOutput:
    prompt = f"""
    You are an expert Product Manager.
    The user is building this app: "{idea}"
    
    The Market Researcher has provided the following data about our competitors:
    What users hate: {json.dumps(researcher_data.what_users_hate)}
    What users love: {json.dumps(researcher_data.what_users_love)}
    
    Formulate a strict, actionable Day-1 MVP (Minimum Viable Product) feature roadmap that directly addresses the pain points (what users hate) while ensuring we cover table stakes (what they love). Do not include fluff.
    """
    response = client.models.generate_content(
        model='gemini-3-flash-preview',
        contents=prompt,
        config={"response_mime_type": "application/json", "response_schema": PMOutput, "temperature": 0.4},
    )
    return PMOutput(**json.loads(response.text))

def run_analyst_agent(client: genai.Client, idea: str, researcher_data: ResearcherOutput, pm_data: PMOutput) -> AnalystOutput:
    prompt = f"""
    You are an expert Business Analyst & Strategist.
    App Idea: "{idea}"

    Researcher's findings:
    - What users love about competitors: {json.dumps(researcher_data.what_users_love)}
    - What users hate (pain points): {json.dumps(researcher_data.what_users_hate)}
    - Community signals (Reddit/HN/PH/Twitter): {json.dumps(researcher_data.community_signals)}

    PM's MVP Roadmap: {json.dumps(pm_data.mvp_roadmap)}

    Task 1 — Score the opportunity across these 7 dimensions (each 0-100). Be critical and evidence-based, not optimistic:

      • pain_severity (25% weight): How severe and frequent are the unmet pain points? Base this on app store reviews AND community signals. (100 = users are desperate and vocal, 0 = minor annoyances)
      • market_gap (20% weight): How large is the gap between user needs and what competitors deliver? (100 = massive unserved need, 0 = competitors already solve everything)
      • mvp_feasibility (15% weight): How realistic is the proposed MVP to build and ship within 3 months for a small team? (100 = trivially buildable, 0 = requires years of R&D)
      • competition_density (15% weight): How crowded is the app store market? (100 = wide open / few weak competitors, 0 = saturated with well-funded strong players)
      • monetization_potential (10% weight): How willing are target users to pay, based on category norms and competitor pricing? (100 = proven paid market, 0 = users expect everything free)
      • community_demand (10% weight): How much active community desire exists for this type of product on Reddit, HN, Product Hunt, and Twitter? Use Google Search to check. (100 = loud vocal demand with many posts/requests/upvotes, 0 = nobody is talking about this need online)
      • startup_saturation (5% weight): Are well-funded VC-backed startups already competing in this exact space? Use Google Search to check recent funding rounds. Inverted: (100 = no funded startups found, 0 = multiple well-funded startups with large teams already exist)

    Task 2: Suggest a concise 'pricing_suggestion' (e.g., Freemium, One-Time $4.99, Subscription $X/mo) based on typical software economics in this category.
    Task 3: Provide a 'market_breakdown' comparing typical iOS vs Android user behaviors for this specific app category.
    Task 4: Give a definite 'target_os_recommendation' for which platform to target first for MVP launch and why.
    """
    response = client.models.generate_content(
        model='gemini-3-flash-preview',
        contents=prompt,
        config=types.GenerateContentConfig(
            response_mime_type="application/json",
            response_schema=AnalystOutput,
            temperature=0.2,
            tools=[{"google_search": {}}]
        ),
    )
    return AnalystOutput(**json.loads(response.text))
