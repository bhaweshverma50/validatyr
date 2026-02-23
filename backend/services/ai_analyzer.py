import os
import json
import logging
from typing import List, Dict, Any
from google import genai
from pydantic import BaseModel, Field

logger = logging.getLogger(__name__)

# --- Agent Output Schemas ---

class ResearcherOutput(BaseModel):
    what_users_love: List[str] = Field(description="Top 5 aspects users love across these competitors.")
    what_users_hate: List[str] = Field(description="Top 5 pain points and complaints users have with these competitors.")

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
    target_os_recommendation: str
    market_breakdown: str
    competitors_analyzed: List[CompetitorInfo] = []
    community_signals: List[str] = []  # Notable Reddit/HN/PH/Twitter insights

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
    researcher_result = _run_researcher_agent(client, app_idea, reviews_text)
    
    logger.info("Agent 2 (Product Manager) is spinning up...")
    pm_result = _run_pm_agent(client, app_idea, researcher_result)
    
    logger.info("Agent 3 (Business Analyst) is spinning up...")
    analyst_result = _run_analyst_agent(client, app_idea, researcher_result, pm_result)

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
        target_os_recommendation=analyst_result.target_os_recommendation,
        market_breakdown=analyst_result.market_breakdown,
        competitors_analyzed=competitors_meta or []
    )

# --- Individual Agents ---

def _run_researcher_agent(client: genai.Client, idea: str, reviews_text: str) -> ResearcherOutput:
    prompt = f"""
    You are an expert App Market Researcher with access to Google Search.
    The user is building an app with this idea: "{idea}"
    
    Task:
    1. Analyze the following recently scraped reviews from competitor apps.
    2. USE GOOGLE SEARCH to actively find more opinions, Reddit threads, and blog reviews about these specific competitors to find deep pain points or missing features that aren't mentioned in the App Store.
    
    Strictly extract what users love and what users absolutely hate (the pain points) across all sources.
    
    SCRAPED REVIEWS:
    {reviews_text}
    """
    from google.genai import types
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

def _run_pm_agent(client: genai.Client, idea: str, researcher_data: ResearcherOutput) -> PMOutput:
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

def _run_analyst_agent(client: genai.Client, idea: str, researcher_data: ResearcherOutput, pm_data: PMOutput) -> AnalystOutput:
    prompt = f"""
    You are an expert Business Analyst & Strategist.
    App Idea: "{idea}"

    Researcher's findings:
    - What users love about competitors: {json.dumps(researcher_data.what_users_love)}
    - What users hate (pain points): {json.dumps(researcher_data.what_users_hate)}
    PM's MVP Roadmap: {json.dumps(pm_data.mvp_roadmap)}

    Task 1 — Score the opportunity across these 5 dimensions (each 0-100). Be critical and evidence-based, not optimistic:
      • pain_severity: How severe and frequent are the unmet pain points? (100 = users are desperate, 0 = minor annoyances)
      • market_gap: How large is the gap between user needs and what competitors deliver? (100 = massive unserved need, 0 = competitors already solve everything)
      • mvp_feasibility: How realistic is the proposed MVP to build and ship within 3 months for a small team? (100 = trivially buildable, 0 = requires years of R&D)
      • competition_density: How crowded is the market? (100 = wide open / few weak competitors, 0 = saturated with well-funded strong players)
      • monetization_potential: How willing are target users to pay, based on category norms and competitor pricing? (100 = high willingness, proven paid market, 0 = users expect everything free)

    Task 2: Suggest a concise 'pricing_suggestion' (e.g., Freemium, One-Time $4.99, Subscription $X/mo) based on typical software economics in this category.
    Task 3: Provide a 'market_breakdown' comparing typical iOS vs Android user behaviors for this specific app category.
    Task 4: Give a definite 'target_os_recommendation' for which platform to target first for MVP launch and why.
    """
    response = client.models.generate_content(
        model='gemini-3-flash-preview',
        contents=prompt,
        config={"response_mime_type": "application/json", "response_schema": AnalystOutput, "temperature": 0.2},
    )
    return AnalystOutput(**json.loads(response.text))
