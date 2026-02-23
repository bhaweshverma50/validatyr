"""Community scraper service using Scrapling.

Scrapes Reddit, HackerNews, Twitter/X, Product Hunt, and G2 for real
community signals to feed into the Researcher Agent.
"""

import os
import json
import time
import logging
from enum import Enum
from typing import List, Optional

from pydantic import BaseModel

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Configuration via env vars
# ---------------------------------------------------------------------------
SCRAPING_ENABLED = os.getenv("SCRAPING_ENABLED", "true").lower() == "true"
SCRAPING_TWITTER_ENABLED = os.getenv("SCRAPING_TWITTER_ENABLED", "true").lower() == "true"
SCRAPING_STEALTHY_ENABLED = os.getenv("SCRAPING_STEALTHY_ENABLED", "true").lower() == "true"
SCRAPING_REQUEST_DELAY = float(os.getenv("SCRAPING_REQUEST_DELAY", "1.5"))
SCRAPING_MAX_PER_SOURCE = int(os.getenv("SCRAPING_MAX_PER_SOURCE", "20"))

# ---------------------------------------------------------------------------
# Data models
# ---------------------------------------------------------------------------

class CommunitySource(str, Enum):
    REDDIT = "reddit"
    HACKERNEWS = "hackernews"
    TWITTER = "twitter"
    PRODUCTHUNT = "producthunt"
    G2 = "g2"


class ScrapedPost(BaseModel):
    source: CommunitySource
    title: str = ""
    content: str  # The actual text (truncated to 500 chars)
    url: str = ""
    author: str = ""
    score: Optional[int] = None  # upvotes/likes/stars
    subreddit: str = ""  # Reddit-specific


class CommunityScrapingResult(BaseModel):
    posts: List[ScrapedPost] = []
    sources_succeeded: List[str] = []
    sources_failed: List[str] = []

    @property
    def total_posts(self) -> int:
        return len(self.posts)


# ---------------------------------------------------------------------------
# Category → source mapping
# ---------------------------------------------------------------------------

CATEGORY_SOURCES = {
    "mobile_app": [CommunitySource.REDDIT, CommunitySource.HACKERNEWS, CommunitySource.TWITTER, CommunitySource.PRODUCTHUNT],
    "saas_web": [CommunitySource.REDDIT, CommunitySource.HACKERNEWS, CommunitySource.TWITTER, CommunitySource.PRODUCTHUNT, CommunitySource.G2],
    "hardware": [CommunitySource.REDDIT, CommunitySource.HACKERNEWS, CommunitySource.TWITTER, CommunitySource.PRODUCTHUNT],
    "fintech": [CommunitySource.REDDIT, CommunitySource.HACKERNEWS, CommunitySource.TWITTER, CommunitySource.PRODUCTHUNT, CommunitySource.G2],
}

CATEGORY_SUBREDDITS = {
    "mobile_app": ["apps", "androidapps", "iphone", "startups"],
    "saas_web": ["SaaS", "startups", "webdev", "entrepreneur"],
    "hardware": ["hardware", "gadgets", "DIY", "3Dprinting"],
    "fintech": ["fintech", "personalfinance", "CreditCards", "investing"],
}


# ---------------------------------------------------------------------------
# Service class
# ---------------------------------------------------------------------------

class CommunityScraperService:
    """Scrapes community platforms for real user signals about competitors/ideas."""

    def __init__(self, category: str = "mobile_app"):
        self.category = category
        self.sources = CATEGORY_SOURCES.get(category, CATEGORY_SOURCES["mobile_app"])
        self.subreddits = CATEGORY_SUBREDDITS.get(category, CATEGORY_SUBREDDITS["mobile_app"])
        self._fetcher = None
        self._stealthy_fetcher = None

    def _get_fetcher(self):
        if self._fetcher is None:
            from scrapling import Fetcher
            self._fetcher = Fetcher(auto_match=False)
        return self._fetcher

    def _get_stealthy_fetcher(self):
        if self._stealthy_fetcher is None:
            from scrapling import StealthyFetcher
            self._stealthy_fetcher = StealthyFetcher(auto_match=False)
        return self._stealthy_fetcher

    def scrape_all(
        self,
        competitor_names: List[str],
        idea_keywords: str,
    ) -> CommunityScrapingResult:
        """Entry point: scrapes all relevant sources for the category."""
        if not SCRAPING_ENABLED:
            logger.info("Community scraping disabled via SCRAPING_ENABLED=false")
            return CommunityScrapingResult()

        all_posts: List[ScrapedPost] = []
        succeeded: List[str] = []
        failed: List[str] = []

        # Build search queries from competitor names and idea
        queries = self._build_queries(competitor_names, idea_keywords)

        dispatch = {
            CommunitySource.REDDIT: self._scrape_reddit,
            CommunitySource.HACKERNEWS: self._scrape_hackernews,
            CommunitySource.TWITTER: self._scrape_twitter,
            CommunitySource.PRODUCTHUNT: self._scrape_producthunt,
            CommunitySource.G2: self._scrape_g2,
        }

        for source in self.sources:
            # Skip Twitter if disabled
            if source == CommunitySource.TWITTER and not SCRAPING_TWITTER_ENABLED:
                logger.info("Skipping Twitter scraping (SCRAPING_TWITTER_ENABLED=false)")
                continue

            # Skip stealthy sources if browser binaries not available
            if source in (CommunitySource.TWITTER, CommunitySource.G2) and not SCRAPING_STEALTHY_ENABLED:
                logger.info(f"Skipping {source.value} (SCRAPING_STEALTHY_ENABLED=false)")
                continue

            scraper_fn = dispatch.get(source)
            if not scraper_fn:
                continue

            try:
                posts = scraper_fn(queries, competitor_names)
                all_posts.extend(posts[:SCRAPING_MAX_PER_SOURCE])
                succeeded.append(source.value)
                logger.info(f"[{source.value}] Scraped {len(posts)} posts")
            except Exception as e:
                logger.warning(f"[{source.value}] Scraping failed: {e}")
                failed.append(source.value)

        return CommunityScrapingResult(
            posts=all_posts,
            sources_succeeded=succeeded,
            sources_failed=failed,
        )

    def _build_queries(self, competitor_names: List[str], idea_keywords: str) -> List[str]:
        """Build search queries from competitor names and idea keywords."""
        queries = []
        # Main idea query
        if idea_keywords:
            # Truncate to reasonable length
            queries.append(idea_keywords[:100])
        # Individual competitor queries
        for name in competitor_names[:5]:
            if name and name.strip():
                queries.append(name.strip())
        return queries if queries else ["app"]

    def _truncate(self, text: str, max_len: int = 500) -> str:
        if not text:
            return ""
        text = text.strip()
        if len(text) > max_len:
            return text[:max_len] + "..."
        return text

    # ------------------------------------------------------------------
    # Reddit
    # ------------------------------------------------------------------
    def _scrape_reddit(self, queries: List[str], competitor_names: List[str]) -> List[ScrapedPost]:
        fetcher = self._get_fetcher()
        posts: List[ScrapedPost] = []

        for sub in self.subreddits[:4]:
            for query in queries[:2]:
                try:
                    url = f"https://www.reddit.com/r/{sub}/search.json?q={query}&restrict_sr=1&sort=relevance&limit=10"
                    response = fetcher.get(url, stealthy_headers=True)

                    data = json.loads(response.text)
                    children = data.get("data", {}).get("children", [])

                    for child in children[:5]:
                        post_data = child.get("data", {})
                        title = post_data.get("title", "")
                        selftext = post_data.get("selftext", "")
                        content = f"{title}. {selftext}" if selftext else title

                        posts.append(ScrapedPost(
                            source=CommunitySource.REDDIT,
                            title=title,
                            content=self._truncate(content),
                            url=f"https://reddit.com{post_data.get('permalink', '')}",
                            author=post_data.get("author", ""),
                            score=post_data.get("score"),
                            subreddit=sub,
                        ))

                    # Fetch top comments from top 3 posts
                    top_posts = children[:3]
                    for tp in top_posts:
                        permalink = tp.get("data", {}).get("permalink", "")
                        if not permalink:
                            continue
                        try:
                            time.sleep(SCRAPING_REQUEST_DELAY)
                            comment_url = f"https://www.reddit.com{permalink}.json?limit=5"
                            comment_resp = fetcher.get(comment_url, stealthy_headers=True)
                            comment_data = json.loads(comment_resp.text)

                            if len(comment_data) > 1:
                                comments = comment_data[1].get("data", {}).get("children", [])
                                for comment in comments[:5]:
                                    body = comment.get("data", {}).get("body", "")
                                    if body and len(body) > 20:
                                        posts.append(ScrapedPost(
                                            source=CommunitySource.REDDIT,
                                            title=f"Comment on: {tp.get('data', {}).get('title', '')}",
                                            content=self._truncate(body),
                                            url=f"https://reddit.com{permalink}",
                                            author=comment.get("data", {}).get("author", ""),
                                            score=comment.get("data", {}).get("score"),
                                            subreddit=sub,
                                        ))
                        except Exception as e:
                            logger.debug(f"Reddit comment fetch failed: {e}")

                    time.sleep(SCRAPING_REQUEST_DELAY)
                except Exception as e:
                    logger.debug(f"Reddit search failed for r/{sub} q={query}: {e}")
                    continue

        return posts

    # ------------------------------------------------------------------
    # Hacker News (Algolia API)
    # ------------------------------------------------------------------
    def _scrape_hackernews(self, queries: List[str], competitor_names: List[str]) -> List[ScrapedPost]:
        fetcher = self._get_fetcher()
        posts: List[ScrapedPost] = []

        for query in queries[:3]:
            try:
                url = f"https://hn.algolia.com/api/v1/search?query={query}&tags=story&hitsPerPage=10"
                response = fetcher.get(url, stealthy_headers=True)
                data = json.loads(response.text)
                hits = data.get("hits", [])

                for hit in hits[:10]:
                    title = hit.get("title", "")
                    story_text = hit.get("story_text", "") or ""
                    object_id = hit.get("objectID", "")

                    posts.append(ScrapedPost(
                        source=CommunitySource.HACKERNEWS,
                        title=title,
                        content=self._truncate(f"{title}. {story_text}" if story_text else title),
                        url=f"https://news.ycombinator.com/item?id={object_id}",
                        author=hit.get("author", ""),
                        score=hit.get("points"),
                    ))

                # Fetch comments for top 3 stories
                for hit in hits[:3]:
                    object_id = hit.get("objectID", "")
                    if not object_id:
                        continue
                    try:
                        time.sleep(0.5)
                        comment_url = f"https://hn.algolia.com/api/v1/search?tags=comment,story_{object_id}&hitsPerPage=10"
                        comment_resp = fetcher.get(comment_url, stealthy_headers=True)
                        comment_data = json.loads(comment_resp.text)

                        for comment_hit in comment_data.get("hits", [])[:5]:
                            comment_text = comment_hit.get("comment_text", "")
                            if comment_text and len(comment_text) > 20:
                                posts.append(ScrapedPost(
                                    source=CommunitySource.HACKERNEWS,
                                    title=f"Comment on: {hit.get('title', '')}",
                                    content=self._truncate(comment_text),
                                    url=f"https://news.ycombinator.com/item?id={comment_hit.get('objectID', '')}",
                                    author=comment_hit.get("author", ""),
                                ))
                    except Exception as e:
                        logger.debug(f"HN comment fetch failed: {e}")

                time.sleep(0.5)
            except Exception as e:
                logger.debug(f"HN search failed for q={query}: {e}")
                continue

        return posts

    # ------------------------------------------------------------------
    # Twitter / X (via Nitter instances, then X.com fallback)
    # ------------------------------------------------------------------
    def _scrape_twitter(self, queries: List[str], competitor_names: List[str]) -> List[ScrapedPost]:
        posts: List[ScrapedPost] = []

        nitter_instances = ["nitter.net"]

        for query in queries[:2]:
            scraped = False

            # Try Nitter instances first (lightweight, no JS)
            for instance in nitter_instances:
                try:
                    fetcher = self._get_fetcher()
                    url = f"https://{instance}/search?f=tweets&q={query}"
                    response = fetcher.get(url, stealthy_headers=True)

                    # Parse tweet content from Nitter HTML
                    tweet_elements = response.css(".tweet-content")
                    for elem in tweet_elements[:10]:
                        text = elem.text or ""
                        if text and len(text) > 15:
                            posts.append(ScrapedPost(
                                source=CommunitySource.TWITTER,
                                content=self._truncate(text),
                                url=f"https://{instance}/search?q={query}",
                            ))

                    if tweet_elements:
                        scraped = True
                        break

                    time.sleep(SCRAPING_REQUEST_DELAY)
                except Exception as e:
                    logger.debug(f"Nitter {instance} failed: {e}")
                    continue

            # Fallback: X.com with StealthyFetcher
            if not scraped and SCRAPING_STEALTHY_ENABLED:
                try:
                    stealthy = self._get_stealthy_fetcher()
                    url = f"https://x.com/search?q={query}&f=live"
                    response = stealthy.fetch(url, headless=True, solve_cloudflare=True)

                    tweet_elements = response.css('[data-testid="tweetText"]')
                    for elem in tweet_elements[:10]:
                        text = elem.text or ""
                        if text and len(text) > 15:
                            posts.append(ScrapedPost(
                                source=CommunitySource.TWITTER,
                                content=self._truncate(text),
                                url=f"https://x.com/search?q={query}",
                            ))
                except Exception as e:
                    logger.debug(f"X.com fallback failed: {e}")

            time.sleep(SCRAPING_REQUEST_DELAY)

        return posts

    # ------------------------------------------------------------------
    # Product Hunt (GraphQL API — no scraping needed)
    # ------------------------------------------------------------------
    def _scrape_producthunt(self, queries: List[str], competitor_names: List[str]) -> List[ScrapedPost]:
        import requests as req

        ph_token = os.getenv("PRODUCTHUNT_API_TOKEN", "")
        if not ph_token:
            logger.info("Skipping ProductHunt (PRODUCTHUNT_API_TOKEN not set)")
            return []

        posts: List[ScrapedPost] = []
        headers = {
            "Authorization": f"Bearer {ph_token}",
            "Content-Type": "application/json",
        }
        api_url = "https://api.producthunt.com/v2/api/graphql"

        for query in queries[:3]:
            try:
                gql = {
                    "query": """
                        query($q: String!) {
                            posts(search: $q, first: 5) {
                                edges {
                                    node {
                                        name
                                        tagline
                                        url
                                        votesCount
                                        comments(first: 5) {
                                            edges {
                                                node {
                                                    body
                                                    user { name }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    """,
                    "variables": {"q": query},
                }
                resp = req.post(api_url, json=gql, headers=headers, timeout=15)
                if resp.status_code != 200:
                    logger.debug(f"ProductHunt API returned {resp.status_code}")
                    continue

                data = resp.json().get("data", {}).get("posts", {}).get("edges", [])
                for edge in data:
                    node = edge.get("node", {})
                    name = node.get("name", "")
                    tagline = node.get("tagline", "")
                    url = node.get("url", "")
                    votes = node.get("votesCount")

                    if name:
                        posts.append(ScrapedPost(
                            source=CommunitySource.PRODUCTHUNT,
                            title=name,
                            content=self._truncate(f"{name}: {tagline}"),
                            url=url,
                            score=votes,
                        ))

                    # Extract comments
                    comments = node.get("comments", {}).get("edges", [])
                    for cedge in comments:
                        cnode = cedge.get("node", {})
                        body = cnode.get("body", "")
                        author = cnode.get("user", {}).get("name", "")
                        if body and len(body) > 20:
                            posts.append(ScrapedPost(
                                source=CommunitySource.PRODUCTHUNT,
                                title=f"Comment on {name}",
                                content=self._truncate(body),
                                url=url,
                                author=author,
                            ))

                time.sleep(0.5)
            except Exception as e:
                logger.debug(f"ProductHunt API failed for q={query}: {e}")
                continue

        return posts

    # ------------------------------------------------------------------
    # G2 (stealthy — Cloudflare protected)
    # ------------------------------------------------------------------
    def _scrape_g2(self, queries: List[str], competitor_names: List[str]) -> List[ScrapedPost]:
        if not SCRAPING_STEALTHY_ENABLED:
            logger.info("Skipping G2 (SCRAPING_STEALTHY_ENABLED=false)")
            return []

        stealthy = self._get_stealthy_fetcher()
        posts: List[ScrapedPost] = []

        for name in competitor_names[:3]:
            if not name or not name.strip():
                continue
            try:
                slug = name.strip().lower().replace(" ", "-")
                url = f"https://www.g2.com/products/{slug}/reviews"
                response = stealthy.fetch(url, headless=True, solve_cloudflare=True)

                review_elements = response.css('[itemprop="reviewBody"]')
                for elem in review_elements[:10]:
                    text = elem.text or ""
                    if text and len(text) > 20:
                        posts.append(ScrapedPost(
                            source=CommunitySource.G2,
                            title=f"G2 Review: {name}",
                            content=self._truncate(text),
                            url=url,
                        ))

                time.sleep(3)  # G2 is aggressive with rate limiting
            except Exception as e:
                logger.debug(f"G2 scraping failed for {name}: {e}")
                continue

        return posts
