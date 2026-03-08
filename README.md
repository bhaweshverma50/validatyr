<div align="center">

# VALIDATYR.

**AI tells you if your app idea sucks — before you waste 6 months building it.**

[![FastAPI](https://img.shields.io/badge/FastAPI-009688?style=for-the-badge&logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)
[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Gemini AI](https://img.shields.io/badge/Gemini_AI-8E75B2?style=for-the-badge&logo=google&logoColor=white)](https://ai.google.dev)
[![Supabase](https://img.shields.io/badge/Supabase-3FCF8E?style=for-the-badge&logo=supabase&logoColor=white)](https://supabase.com)
[![Python](https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white)](https://python.org)

<br/>

Describe your app idea. We scrape **real competitor reviews** from the Play Store & App Store, mine **community signals** from Reddit, HackerNews, ProductHunt & 6 more sources, then run a **5-agent AI pipeline** to give you a data-backed **Opportunity Score** with actionable insights — in under 60 seconds.

</div>

---

## Features

### Idea Validation Pipeline

- **Voice or text input** — describe your idea by typing or recording a voice memo (on-device speech recognition + Gemini fallback)
- **Category detection** — Auto-detect or manually pick: Mobile, SaaS/Web, Hardware, FinTech
- **Live SSE streaming** — watch each agent's progress in real-time with step-by-step updates
- **5-agent AI pipeline** — Discovery, Community Scraper, Researcher, Product Manager, Business Analyst
- **Opportunity Score** — weighted 0-100 composite score with visual gauge and breakdown bars
- **Full validation report** — loves/hates, MVP roadmap, pricing strategy, TAM/SAM/SOM, funded competitors, GTM playbook
- **PDF export** — open your validation report as a polished PDF directly in the system viewer
- **Persistent history** — all validations saved to Supabase, accessible from the History tab

### Research Lab

- **Research topics** — create topics by domain (Apps, SaaS, Hardware, FinTech, General) with custom keywords and focus areas
- **3-agent research pipeline** — Trend Scout, Market Analyst, and Idea Generator produce structured reports
- **Scheduled research** — daily or weekly auto-runs with configurable day and time picker
- **Topic channels** — each topic has a feed of generated reports, newest first
- **Research reports** — executive summary, market overview, scored ideas with trend evidence, MVP features, and monetization hints
- **Deep Validate** — one tap to run any research idea through the full validation pipeline

### Notifications & Alerts

- **Push notifications** — Firebase Cloud Messaging (FCM) for real-time alerts on iOS and Android
- **Notification center** — in-app notification feed with unread badges, mark-read, and clear-all
- **Notification settings** — per-type toggles (validation complete, research complete, high-score, schedule reminder) with configurable score threshold
- **Realtime updates** — Supabase Realtime subscription for instant notification delivery

### Job Tracking & History

- **Validation job tracking** — running jobs persist server-side, survive app close and phone lock
- **Live progress** — SSE streaming with automatic poll fallback if connection drops
- **Running jobs in History** — pinned at top with pulsing indicator, auto-refresh every 5 seconds
- **Job reconnection** — resume watching a running job from the History tab

### Design & UX

- **Retro neo-brutalist UI** — bold 3px borders, sharp offset shadows, pastel color palette (pink, mint, lavender, yellow, blue)
- **Dark mode** — full light/dark/system theme support with `ThemeExtension<RetroColors>`
- **Design token system** — centralized spacing, typography, color, border, radius, and shadow tokens
- **Shared components** — `RetroCard` and `RetroButton` with animated press states and sharp shadows
- **Bottom navigation** — 5-tab shell (Home, Research, History, Alerts, Settings) with retro active state indicators
- **Responsive** — works on iOS, Android, macOS, and web

### Deployment

- **Docker** — production Dockerfile for the backend
- **Google Cloud Run** — scale-to-zero serverless deployment
- **Cloud Scheduler** — cron-triggered research runs (replaces in-memory APScheduler for serverless)
- **Auto host detection** — frontend auto-switches between local (http) and remote (https) backend

---

## How It Works

### Validation Pipeline

```
You describe your idea (text or voice)
        |
        v
+-----------------------------------------------+
|  Agent 0 — Discovery                          |
|  Finds top competitors on Play Store &         |
|  App Store, scrapes their reviews              |
+----------------------+------------------------+
                       v
+-----------------------------------------------+
|  Agent 1 — Community Scraper                  |
|  Mines Reddit, HN, ProductHunt, Twitter/X,    |
|  Dev.to, Lemmy, Google News, Lobsters         |
+----------------------+------------------------+
                       v
+-----------------------------------------------+
|  Agent 2 — Researcher                         |
|  Analyzes reviews + community signals +        |
|  Google Search grounding for pain points       |
+----------------------+------------------------+
                       v
+-----------------------------------------------+
|  Agent 3 — Product Manager                    |
|  Builds Day-1 MVP roadmap targeting the        |
|  biggest pain points                           |
+----------------------+------------------------+
                       v
+-----------------------------------------------+
|  Agent 4 — Business Analyst                   |
|  Scores opportunity, pricing, platform,        |
|  TAM/SAM/SOM, funded competitors, GTM          |
+----------------------+------------------------+
                       v
        Opportunity Score (0-100)
        + Full validation report
```

### Research Pipeline

```
Topic (domain + keywords + focus areas)
        |
        v
+-----------------------------------------------+
|  Trend Scout                                  |
|  Scans forums, news, app stores for           |
|  trending topics and pain points               |
+----------------------+------------------------+
                       v
+-----------------------------------------------+
|  Market Analyst                               |
|  Cross-references trends with funding data,    |
|  validates market gaps                         |
+----------------------+------------------------+
                       v
+-----------------------------------------------+
|  Idea Generator                               |
|  Produces 5-10 scored business ideas with      |
|  evidence, features, and monetization hints    |
+----------------------+------------------------+
                       v
        Research Report with scored ideas
```

---

## What You Get

### From Validation

| Insight | Description |
|---|---|
| **Opportunity Score** | Weighted 0-100 score across 5 dimensions |
| **Score Breakdown** | 7 dimensions: pain severity, market gap, MVP feasibility, competition density, monetization, community demand, startup saturation |
| **What Users Love** | Top things competitors do right (table stakes) |
| **What Users Hate** | Real pain points from actual user reviews |
| **MVP Roadmap** | Actionable Day-1 feature list with priority |
| **Pricing Strategy** | Data-backed monetization suggestion |
| **TAM / SAM / SOM** | Market sizing with estimates |
| **Funded Competitors** | VC-backed players in the space |
| **GTM Playbook** | Go-to-market strategy recommendations |
| **Competitors Analyzed** | Apps scraped with platform tags and ratings |

### From Research

| Insight | Description |
|---|---|
| **Executive Summary** | Key opportunity landscape overview |
| **Market Overview** | Macro trends, funding environment, competitive dynamics |
| **Scored Ideas** | 5-10 business ideas with opportunity scores (0-100) |
| **Trend Evidence** | Why now — signals from forums, news, funding |
| **MVP Features** | Suggested feature list per idea |
| **Monetization Hints** | Revenue model suggestions |
| **Trend Types** | Pain point, rising demand, or follow trend |

---

## Tech Stack

| Layer | Technology |
|---|---|
| **Backend** | Python 3.12+, FastAPI, Pydantic |
| **AI Engine** | Google Gemini 3 Flash — multi-agent pipelines with structured JSON output |
| **App Store Scraping** | `google-play-scraper`, Apple RSS feeds, iTunes Search API |
| **Community Scraping** | Reddit JSON API, HN Algolia, ProductHunt GraphQL, Twitter/X (Nitter), Dev.to, Lemmy, Google News RSS, Lobsters |
| **Frontend** | Flutter (Dart), Riverpod, Lucide Icons, Google Fonts (Outfit + Space Grotesk) |
| **Database** | Supabase (PostgreSQL) — optional, mocks gracefully without it |
| **Push Notifications** | Firebase Cloud Messaging (FCM) + flutter_local_notifications |
| **Voice Input** | On-device speech recognition (`speech_to_text`) with Gemini fallback |
| **Streaming** | Server-Sent Events (SSE) with automatic poll fallback |
| **Export** | PDF generation via `pdf` package, opened with system viewer |
| **Deployment** | Docker, Google Cloud Run, Cloud Scheduler |

---

## Getting Started

### Prerequisites

- Python 3.12+
- Flutter SDK 3.8+
- A [Google Gemini API key](https://aistudio.google.com/apikey)

### 1. Clone

```bash
git clone https://github.com/YOUR_USERNAME/validatyr.git
cd validatyr
```

### 2. Backend Setup

```bash
cd backend
python -m venv venv
source venv/bin/activate        # Windows: venv\Scripts\activate
pip install -r requirements.txt
```

Create your `.env` file:

```bash
cp .env.example .env
# Edit .env and add your GEMINI_API_KEY
```

Start the server:

```bash
uvicorn main:app --reload
```

The API runs at `http://127.0.0.1:8000`. Hit `/docs` for the interactive Swagger UI.

### 3. Frontend Setup

```bash
cd frontend
flutter pub get
flutter run -d macos      # or: chrome, ios, android
```

For physical device testing, create `frontend/.env` with:

```
BACKEND_HOST=<your-machine-ip>
```

---

## API Endpoints

### Validation

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/api/v1/validate` | Validate an app idea (JSON response) |
| `POST` | `/api/v1/validate/stream` | Validate with SSE streaming progress |
| `GET` | `/api/v1/validate/jobs` | List active validation jobs |
| `GET` | `/api/v1/validate/jobs/{id}` | Get job status (for poll fallback) |
| `GET` | `/api/v1/validate/result/{id}` | Fetch completed validation result |
| `POST` | `/api/v1/transcribe` | Transcribe a voice memo to text |
| `POST` | `/api/v1/push-token` | Register FCM push token |
| `DELETE` | `/api/v1/push-token/{token}` | Unregister push token |

### Research

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/api/v1/research/topics` | Create a research topic |
| `GET` | `/api/v1/research/topics` | List all topics |
| `PUT` | `/api/v1/research/topics/{id}` | Update a topic |
| `DELETE` | `/api/v1/research/topics/{id}` | Delete a topic |
| `POST` | `/api/v1/research/start` | Trigger research for a topic |
| `POST` | `/api/v1/research/cron-trigger` | Cloud Scheduler endpoint for scheduled research |
| `GET` | `/api/v1/research/topics/{id}/latest-job` | Get latest job status |
| `GET` | `/api/v1/research/reports?topic_id=` | List reports for a topic |
| `GET` | `/api/v1/research/reports/{id}` | Get a full report |
| `GET` | `/api/v1/research/status/{job_id}` | Get job progress |
| `GET` | `/api/v1/research/notifications` | List notifications |
| `PUT` | `/api/v1/research/notifications/{id}/read` | Mark notification read |
| `PUT` | `/api/v1/research/notifications/read-all` | Mark all notifications read |

---

## Project Structure

```
validatyr/
├── backend/
│   ├── main.py                      # FastAPI entry point
│   ├── Dockerfile                   # Production Docker image
│   ├── .dockerignore
│   ├── api/
│   │   ├── routes.py                # Validation & transcription endpoints
│   │   └── research_routes.py       # Research CRUD, cron trigger & pipeline endpoints
│   ├── services/
│   │   ├── discovery.py             # Agent 0: competitor discovery
│   │   ├── scraper.py               # Play Store & App Store scraping
│   │   ├── community_scraper.py     # 9-source community signal mining
│   │   ├── ai_analyzer.py           # Agents 2-4: multi-agent AI pipeline
│   │   ├── research_pipeline.py     # 3-agent research pipeline
│   │   ├── research_scheduler.py    # Research cron job management
│   │   ├── research_models.py       # Pydantic models for research
│   │   ├── research_db.py           # Supabase persistence for research
│   │   ├── push_service.py          # FCM push notification delivery
│   │   ├── validation_jobs_db.py    # Validation job state tracking
│   │   ├── audio_processor.py       # Voice transcription via Gemini
│   │   └── db.py                    # Supabase persistence for validations
│   └── .env.example
├── frontend/
│   ├── lib/
│   │   ├── main.dart
│   │   ├── core/
│   │   │   ├── theme/
│   │   │   │   ├── custom_theme.dart    # Design tokens + light/dark themes
│   │   │   │   └── retro_colors.dart    # ThemeExtension<RetroColors>
│   │   │   ├── providers/
│   │   │   │   └── theme_provider.dart  # Riverpod theme mode state
│   │   │   └── utils.dart               # Date/time formatters
│   │   ├── features/
│   │   │   ├── shell/app_shell.dart         # 5-tab bottom nav
│   │   │   ├── home/home_screen.dart        # Idea input + voice recording
│   │   │   ├── loading/loading_screen.dart  # SSE streaming + poll fallback
│   │   │   ├── results/results_screen.dart  # Full validation report
│   │   │   ├── history/history_screen.dart  # Saved validations + running jobs
│   │   │   ├── settings/settings_screen.dart  # Theme + profile settings
│   │   │   ├── notifications/
│   │   │   │   ├── notification_center_screen.dart
│   │   │   │   └── notification_settings_screen.dart
│   │   │   └── research/                    # Research Lab screens
│   │   │       ├── research_dashboard_screen.dart
│   │   │       ├── new_topic_screen.dart
│   │   │       ├── topic_channel_screen.dart
│   │   │       └── report_detail_screen.dart
│   │   ├── shared_widgets/
│   │   │   ├── retro_card.dart
│   │   │   ├── retro_button.dart
│   │   │   └── notification_bell.dart
│   │   └── services/
│   │       ├── api_service.dart
│   │       ├── research_api_service.dart
│   │       ├── supabase_service.dart
│   │       ├── notification_service.dart    # FCM + local notifications
│   │       ├── validation_job_recovery.dart # Job reconnection logic
│   │       └── pdf_export_service.dart
│   └── pubspec.yaml
└── README.md
```

---

## Environment Variables

| Variable | Required | Description |
|---|---|---|
| `GEMINI_API_KEY` | Yes | Google Gemini API key |
| `SUPABASE_URL` | No | Supabase project URL (for persistence) |
| `SUPABASE_KEY` | No | Supabase anon key |
| `PRODUCTHUNT_API_TOKEN` | No | ProductHunt API token (for research scraping) |
| `BACKEND_HOST` | No | Backend IP for mobile device testing (frontend `.env`) |

---

## Community Sources

The community scraper mines signals from 9 platforms, selected per category:

| Source | Method | What it finds |
|---|---|---|
| **Reddit** | JSON API with proper User-Agent | Subreddit discussions, complaints, feature requests |
| **HackerNews** | Algolia Search API (stories + comments) | Tech community sentiment, Show HN launches |
| **ProductHunt** | GraphQL API | New product launches, maker discussions |
| **Twitter/X** | Nitter instances | Real-time user complaints and praise |
| **Dev.to** | REST API | Developer community articles and discussions |
| **Lemmy** | Federated API | Open-source community signals |
| **Google News** | RSS feed | Recent press coverage and industry news |
| **Lobsters** | JSON API | Technical community discussions |
| **G2** | Web scraping | Enterprise software reviews |

---

## Scoring Formula

The Opportunity Score is a weighted composite across 7 dimensions:

| Dimension | Weight | What it measures |
|---|---|---|
| Pain Severity | 25% | How painful is the problem users face? |
| Market Gap | 20% | Is there room for a new player? |
| MVP Feasibility | 15% | Can a small team build this quickly? |
| Competition Density | 15% | How crowded is the space? |
| Monetization Potential | 10% | Can this make money? |
| Community Demand | 10% | What are forums and communities saying? |
| Startup Saturation | 5% | How many funded startups are in this space? |

Each dimension is scored 0-100 by the Business Analyst agent based on evidence from scraped reviews, community signals, and market research.

---

## License

MIT

---

<div align="center">

**Stop guessing. Start validating.**

Built with Gemini AI, FastAPI, and Flutter.

</div>
