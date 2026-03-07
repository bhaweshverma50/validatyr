"""Community scraper service.

Scrapes Reddit, HackerNews, Twitter/X, Product Hunt, Dev.to, Lemmy,
Google News, Lobsters, and G2 for real community signals to feed into
the Researcher Agent.
"""

import os
import json
import time
import logging
import urllib.parse
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
    DEVTO = "devto"
    LEMMY = "lemmy"
    GOOGLENEWS = "googlenews"
    LOBSTERS = "lobsters"


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
    "mobile_app": [
        CommunitySource.REDDIT, CommunitySource.HACKERNEWS, CommunitySource.TWITTER,
        CommunitySource.PRODUCTHUNT, CommunitySource.DEVTO, CommunitySource.LEMMY,
        CommunitySource.GOOGLENEWS, CommunitySource.LOBSTERS,
    ],
    "saas_web": [
        CommunitySource.REDDIT, CommunitySource.HACKERNEWS, CommunitySource.TWITTER,
        CommunitySource.PRODUCTHUNT, CommunitySource.G2, CommunitySource.DEVTO,
        CommunitySource.LEMMY, CommunitySource.GOOGLENEWS, CommunitySource.LOBSTERS,
    ],
    "hardware": [
        CommunitySource.REDDIT, CommunitySource.HACKERNEWS, CommunitySource.TWITTER,
        CommunitySource.PRODUCTHUNT, CommunitySource.DEVTO, CommunitySource.LEMMY,
        CommunitySource.GOOGLENEWS,
    ],
    "fintech": [
        CommunitySource.REDDIT, CommunitySource.HACKERNEWS, CommunitySource.TWITTER,
        CommunitySource.PRODUCTHUNT, CommunitySource.G2, CommunitySource.DEVTO,
        CommunitySource.LEMMY, CommunitySource.GOOGLENEWS, CommunitySource.LOBSTERS,
    ],
}

CATEGORY_SUBREDDITS = {
    "mobile_app": ["apps", "androidapps", "iphone", "startups"],
    "saas_web": ["SaaS", "startups", "webdev", "entrepreneur"],
    "hardware": ["hardware", "gadgets", "DIY", "3Dprinting"],
    "fintech": ["fintech", "personalfinance", "CreditCards", "investing"],
}

LEMMY_COMMUNITIES = {
    "mobile_app": ["technology@lemmy.world", "android@lemmy.world", "apple@lemmy.world"],
    "saas_web": ["technology@lemmy.world", "programming@lemmy.ml", "selfhosted@lemmy.world"],
    "hardware": ["technology@lemmy.world", "hardware@lemmy.world"],
    "fintech": ["technology@lemmy.world", "personalfinance@lemmy.world"],
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
        self.lemmy_communities = LEMMY_COMMUNITIES.get(category, LEMMY_COMMUNITIES["mobile_app"])
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
            CommunitySource.DEVTO: self._scrape_devto,
            CommunitySource.LEMMY: self._scrape_lemmy,
            CommunitySource.GOOGLENEWS: self._scrape_google_news,
            CommunitySource.LOBSTERS: self._scrape_lobsters,
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
        # Main idea query — use only first 3 keywords to avoid overly specific searches
        if idea_keywords:
            words = idea_keywords.strip().split()
            if len(words) > 3:
                queries.append(" ".join(words[:3]))
            else:
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
    # Reddit (using requests with proper User-Agent — Reddit blocks
    # generic fetchers with 403)
    # ------------------------------------------------------------------
    def _scrape_reddit(self, queries: List[str], competitor_names: List[str]) -> List[ScrapedPost]:
        import requests as req

        headers = {
            "User-Agent": "Validatyr/1.0 (community research bot)",
            "Accept": "application/json",
        }
        posts: List[ScrapedPost] = []

        for sub in self.subreddits[:4]:
            for query in queries[:2]:
                try:
                    url = f"https://www.reddit.com/r/{sub}/search.json"
                    params = {"q": query, "restrict_sr": "1", "sort": "relevance", "limit": "10", "raw_json": "1"}
                    resp = req.get(url, headers=headers, params=params, timeout=10)
                    if resp.status_code != 200:
                        logger.debug(f"Reddit returned {resp.status_code} for r/{sub} q={query}")
                        time.sleep(SCRAPING_REQUEST_DELAY)
                        continue

                    data = resp.json()
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
                    for tp in children[:3]:
                        permalink = tp.get("data", {}).get("permalink", "")
                        if not permalink:
                            continue
                        try:
                            time.sleep(SCRAPING_REQUEST_DELAY)
                            comment_url = f"https://www.reddit.com{permalink}.json?limit=5&raw_json=1"
                            comment_resp = req.get(comment_url, headers=headers, timeout=10)
                            if comment_resp.status_code != 200:
                                continue
                            comment_data = comment_resp.json()

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
    # Hacker News (Algolia API) — searches both stories AND comments
    # ------------------------------------------------------------------
    def _scrape_hackernews(self, queries: List[str], competitor_names: List[str]) -> List[ScrapedPost]:
        import requests as req

        posts: List[ScrapedPost] = []

        for query in queries[:3]:
            encoded = urllib.parse.quote(query)

            # Search stories
            try:
                url = f"https://hn.algolia.com/api/v1/search?query={encoded}&tags=story&hitsPerPage=10"
                resp = req.get(url, timeout=10)
                if resp.status_code == 200:
                    hits = resp.json().get("hits", [])
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
            except Exception as e:
                logger.debug(f"HN story search failed for q={query}: {e}")

            # Search comments directly (this is where the real insights are)
            try:
                url = f"https://hn.algolia.com/api/v1/search?query={encoded}&tags=comment&hitsPerPage=15"
                resp = req.get(url, timeout=10)
                if resp.status_code == 200:
                    hits = resp.json().get("hits", [])
                    for hit in hits[:15]:
                        comment_text = hit.get("comment_text", "")
                        if comment_text and len(comment_text) > 30:
                            story_title = hit.get("story_title", "")
                            story_id = hit.get("story_id", "")
                            posts.append(ScrapedPost(
                                source=CommunitySource.HACKERNEWS,
                                title=f"Comment on: {story_title}" if story_title else "HN Comment",
                                content=self._truncate(comment_text),
                                url=f"https://news.ycombinator.com/item?id={hit.get('objectID', '')}",
                                author=hit.get("author", ""),
                            ))
            except Exception as e:
                logger.debug(f"HN comment search failed for q={query}: {e}")

            time.sleep(0.5)

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
    # Dev.to (public API, no auth needed)
    # ------------------------------------------------------------------
    def _scrape_devto(self, queries: List[str], competitor_names: List[str]) -> List[ScrapedPost]:
        import requests as req

        posts: List[ScrapedPost] = []

        for query in queries[:3]:
            try:
                url = "https://dev.to/api/articles"
                params = {"tag": query.replace(" ", ""), "per_page": 10, "top": 30}
                resp = req.get(url, params=params, timeout=10)

                # Also try search endpoint which is more flexible
                if resp.status_code != 200 or not resp.json():
                    url = f"https://dev.to/api/articles?per_page=10&page=1"
                    # Dev.to search via the search param
                    resp = req.get(url, params={"per_page": 10}, timeout=10)

                search_url = "https://dev.to/search/feed_content"
                search_params = {
                    "per_page": 10,
                    "page": 0,
                    "search_fields": query,
                    "class_name": "Article",
                }
                search_resp = req.get(search_url, params=search_params, timeout=10,
                                      headers={"Accept": "application/json"})

                if search_resp.status_code == 200:
                    results = search_resp.json().get("result", [])
                    for article in results[:10]:
                        title = article.get("title", "")
                        # The search endpoint returns different fields
                        body = article.get("body_text", "") or article.get("highlight", {}).get("body_text", [""])[0]
                        path = article.get("path", "")
                        posts.append(ScrapedPost(
                            source=CommunitySource.DEVTO,
                            title=title,
                            content=self._truncate(f"{title}. {body}" if body else title),
                            url=f"https://dev.to{path}" if path else "",
                            author=article.get("user", {}).get("username", ""),
                        ))

                # Also use the articles API for tag-based results
                tag_url = "https://dev.to/api/articles"
                tag_resp = req.get(tag_url, params={"tag": query.split()[0].lower(), "per_page": 5, "top": 30}, timeout=10)
                if tag_resp.status_code == 200:
                    for article in tag_resp.json()[:5]:
                        title = article.get("title", "")
                        desc = article.get("description", "")
                        posts.append(ScrapedPost(
                            source=CommunitySource.DEVTO,
                            title=title,
                            content=self._truncate(f"{title}. {desc}" if desc else title),
                            url=article.get("url", ""),
                            author=article.get("user", {}).get("username", ""),
                            score=article.get("positive_reactions_count"),
                        ))

                # Fetch comments from top articles
                if tag_resp.status_code == 200:
                    for article in tag_resp.json()[:3]:
                        article_id = article.get("id")
                        if not article_id:
                            continue
                        try:
                            comments_resp = req.get(f"https://dev.to/api/comments?a_id={article_id}&per_page=5", timeout=10)
                            if comments_resp.status_code == 200:
                                for comment in comments_resp.json()[:5]:
                                    body = comment.get("body_html", "")
                                    # Strip HTML tags simply
                                    import re
                                    body_text = re.sub(r'<[^>]+>', '', body).strip()
                                    if body_text and len(body_text) > 20:
                                        posts.append(ScrapedPost(
                                            source=CommunitySource.DEVTO,
                                            title=f"Comment on: {article.get('title', '')}",
                                            content=self._truncate(body_text),
                                            url=article.get("url", ""),
                                            author=comment.get("user", {}).get("username", ""),
                                        ))
                        except Exception as e:
                            logger.debug(f"Dev.to comment fetch failed: {e}")

                time.sleep(0.5)
            except Exception as e:
                logger.debug(f"Dev.to search failed for q={query}: {e}")
                continue

        return posts

    # ------------------------------------------------------------------
    # Lemmy (public API — Reddit alternative)
    # ------------------------------------------------------------------
    def _scrape_lemmy(self, queries: List[str], competitor_names: List[str]) -> List[ScrapedPost]:
        import requests as req

        posts: List[ScrapedPost] = []
        lemmy_instances = ["lemmy.world", "lemmy.ml"]

        for query in queries[:2]:
            for instance in lemmy_instances:
                try:
                    url = f"https://{instance}/api/v3/search"
                    params = {
                        "q": query,
                        "type_": "Posts",
                        "sort": "TopAll",
                        "limit": 10,
                    }
                    resp = req.get(url, params=params, timeout=10)
                    if resp.status_code != 200:
                        logger.debug(f"Lemmy {instance} returned {resp.status_code}")
                        continue

                    data = resp.json()
                    for post_view in data.get("posts", [])[:10]:
                        post = post_view.get("post", {})
                        title = post.get("name", "")
                        body = post.get("body", "") or ""
                        content = f"{title}. {body}" if body else title
                        community = post_view.get("community", {}).get("name", "")

                        posts.append(ScrapedPost(
                            source=CommunitySource.LEMMY,
                            title=title,
                            content=self._truncate(content),
                            url=post.get("ap_id", ""),
                            author=post_view.get("creator", {}).get("name", ""),
                            score=post_view.get("counts", {}).get("score"),
                            subreddit=community,
                        ))

                    # Also search comments for deeper insights
                    params["type_"] = "Comments"
                    comment_resp = req.get(url, params=params, timeout=10)
                    if comment_resp.status_code == 200:
                        for cv in comment_resp.json().get("comments", [])[:10]:
                            comment = cv.get("comment", {})
                            body = comment.get("content", "")
                            if body and len(body) > 30:
                                post_info = cv.get("post", {})
                                posts.append(ScrapedPost(
                                    source=CommunitySource.LEMMY,
                                    title=f"Comment on: {post_info.get('name', '')}",
                                    content=self._truncate(body),
                                    url=comment.get("ap_id", ""),
                                    author=cv.get("creator", {}).get("name", ""),
                                    score=cv.get("counts", {}).get("score"),
                                ))

                    time.sleep(0.5)
                except Exception as e:
                    logger.debug(f"Lemmy {instance} search failed for q={query}: {e}")
                    continue

        return posts

    # ------------------------------------------------------------------
    # Google News (RSS feed — no API key needed)
    # ------------------------------------------------------------------
    def _scrape_google_news(self, queries: List[str], competitor_names: List[str]) -> List[ScrapedPost]:
        import requests as req
        import xml.etree.ElementTree as ET

        posts: List[ScrapedPost] = []

        for query in queries[:3]:
            try:
                encoded = urllib.parse.quote(query)
                url = f"https://news.google.com/rss/search?q={encoded}&hl=en-US&gl=US&ceid=US:en"
                resp = req.get(url, timeout=10, headers={
                    "User-Agent": "Validatyr/1.0 (community research bot)",
                })
                if resp.status_code != 200:
                    logger.debug(f"Google News RSS returned {resp.status_code}")
                    continue

                root = ET.fromstring(resp.content)
                items = root.findall(".//item")

                for item in items[:10]:
                    title = item.findtext("title", "")
                    description = item.findtext("description", "")
                    link = item.findtext("link", "")
                    pub_date = item.findtext("pubDate", "")
                    source_name = item.findtext("source", "")

                    # Strip HTML from description
                    import re
                    desc_text = re.sub(r'<[^>]+>', '', description).strip() if description else ""

                    content = f"{title}. {desc_text}" if desc_text else title
                    if source_name:
                        content = f"[{source_name}] {content}"

                    posts.append(ScrapedPost(
                        source=CommunitySource.GOOGLENEWS,
                        title=title,
                        content=self._truncate(content),
                        url=link,
                        author=source_name,
                    ))

                time.sleep(0.5)
            except Exception as e:
                logger.debug(f"Google News RSS failed for q={query}: {e}")
                continue

        return posts

    # ------------------------------------------------------------------
    # Lobsters (public JSON API — HN-like community)
    # ------------------------------------------------------------------
    def _scrape_lobsters(self, queries: List[str], competitor_names: List[str]) -> List[ScrapedPost]:
        import requests as req

        posts: List[ScrapedPost] = []

        for query in queries[:2]:
            try:
                encoded = urllib.parse.quote(query)
                url = f"https://lobste.rs/search?q={encoded}&what=stories&order=relevance&format=json"
                resp = req.get(url, timeout=10, headers={
                    "User-Agent": "Validatyr/1.0 (community research bot)",
                })
                if resp.status_code != 200:
                    logger.debug(f"Lobsters returned {resp.status_code}")
                    continue

                stories = resp.json() if isinstance(resp.json(), list) else resp.json().get("results", [])
                for story in stories[:10]:
                    title = story.get("title", "")
                    description = story.get("description", "") or ""
                    short_id = story.get("short_id", "")
                    tags = ", ".join(story.get("tags", []))

                    content = f"{title}. {description}" if description else title
                    if tags:
                        content = f"[{tags}] {content}"

                    posts.append(ScrapedPost(
                        source=CommunitySource.LOBSTERS,
                        title=title,
                        content=self._truncate(content),
                        url=story.get("url", "") or f"https://lobste.rs/s/{short_id}",
                        author=story.get("submitter_user", {}).get("username", "") if isinstance(story.get("submitter_user"), dict) else story.get("submitter_user", ""),
                        score=story.get("score"),
                    ))

                # Also search comments
                url = f"https://lobste.rs/search?q={encoded}&what=comments&order=relevance&format=json"
                comment_resp = req.get(url, timeout=10, headers={
                    "User-Agent": "Validatyr/1.0 (community research bot)",
                })
                if comment_resp.status_code == 200:
                    comments = comment_resp.json() if isinstance(comment_resp.json(), list) else comment_resp.json().get("results", [])
                    for comment in comments[:10]:
                        body = comment.get("comment", "") or comment.get("comment_plain", "")
                        if body and len(body) > 30:
                            posts.append(ScrapedPost(
                                source=CommunitySource.LOBSTERS,
                                title=f"Comment on: {comment.get('story_title', '')}",
                                content=self._truncate(body),
                                url=comment.get("url", ""),
                                author=comment.get("commenting_user", {}).get("username", "") if isinstance(comment.get("commenting_user"), dict) else comment.get("commenting_user", ""),
                            ))

                time.sleep(0.5)
            except Exception as e:
                logger.debug(f"Lobsters search failed for q={query}: {e}")
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
