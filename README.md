# <img src="https://img.icons8.com/emoji/48/high-voltage.png" width="32"/> VALIDATYR

### AI tells you if your app idea sucks — before you waste 6 months building it.

<br/>

<p align="center">
  <img src="https://img.shields.io/badge/FastAPI-009688?style=for-the-badge&logo=fastapi&logoColor=white" />
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" />
  <img src="https://img.shields.io/badge/Gemini_AI-8E75B2?style=for-the-badge&logo=google&logoColor=white" />
  <img src="https://img.shields.io/badge/Supabase-3FCF8E?style=for-the-badge&logo=supabase&logoColor=white" />
  <img src="https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white" />
</p>

<br/>

> Dump your app idea. We scrape real competitor reviews from the Play Store & App Store, run 3 AI agents, and give you a data-backed **Opportunity Score** with actionable insights.

---

## How It Works

```
You describe your idea (text or voice)
        │
        ▼
┌─────────────────────────────────────────────┐
│  🔍 Agent 0 — Discovery                    │
│  Finds top competitors on Play Store &      │
│  App Store, scrapes their reviews           │
└──────────────────┬──────────────────────────┘
                   ▼
┌─────────────────────────────────────────────┐
│  📊 Agent 1 — Researcher                   │
│  Analyzes reviews + Google Search to find   │
│  what users love & hate about competitors   │
└──────────────────┬──────────────────────────┘
                   ▼
┌─────────────────────────────────────────────┐
│  📋 Agent 2 — Product Manager              │
│  Builds a Day-1 MVP roadmap that attacks    │
│  the pain points                            │
└──────────────────┬──────────────────────────┘
                   ▼
┌─────────────────────────────────────────────┐
│  💰 Agent 3 — Business Analyst             │
│  Scores the opportunity, suggests pricing,  │
│  target platform, and market breakdown      │
└──────────────────┬──────────────────────────┘
                   ▼
        Opportunity Score (0-100)
        + Full validation report
```

---

## What You Get

| Insight | Description |
|---|---|
| **Opportunity Score** | Weighted 0–100 score across 5 dimensions |
| **Score Breakdown** | Pain severity, market gap, MVP feasibility, competition density, monetization potential |
| **What Users Love** | Top things competitors do right (table stakes) |
| **What Users Hate** | Real pain points from actual user reviews |
| **MVP Roadmap** | Actionable Day-1 feature list |
| **Pricing Strategy** | Data-backed monetization suggestion |
| **Target Platform** | iOS vs Android vs Web recommendation |
| **Market Breakdown** | Platform-specific user behavior analysis |
| **Competitors Analyzed** | List of apps scraped with ratings |

---

## Tech Stack

| Layer | Tech |
|---|---|
| **Backend** | Python, FastAPI, Pydantic |
| **AI Engine** | Google Gemini 3 Flash (multi-agent pipeline with structured JSON output) |
| **Scraping** | `google-play-scraper`, Apple RSS feeds, iTunes Search API |
| **Frontend** | Flutter (Dart), Riverpod, Google Fonts |
| **Database** | Supabase (optional — mocks gracefully without it) |
| **Voice Input** | Gemini multimodal audio transcription |

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
pip install fastapi uvicorn google-genai google-play-scraper pydantic python-dotenv supabase requests
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

The API will be running at `http://127.0.0.1:8000`. Hit `/docs` for the interactive Swagger UI.

### 3. Frontend Setup

```bash
cd frontend
flutter pub get
flutter run -d macos      # or: chrome, ios, android
```

---

## API Endpoints

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/api/v1/validate` | Validate an app idea (main pipeline) |
| `POST` | `/api/v1/transcribe` | Transcribe a voice memo to text |
| `GET` | `/health` | Health check |

### Validate Request

```json
{
  "idea": "A social network for dogs",
  "model_provider": "gemini"
}
```

---

## Project Structure

```
validatyr/
├── backend/
│   ├── main.py                 # FastAPI entry point
│   ├── api/
│   │   └── routes.py           # API route definitions
│   ├── services/
│   │   ├── discovery.py        # Agent 0: competitor discovery
│   │   ├── scraper.py          # Play Store & App Store scraping
│   │   ├── ai_analyzer.py      # Agents 1-3: multi-agent AI pipeline
│   │   ├── audio_processor.py  # Voice transcription via Gemini
│   │   └── db.py               # Supabase persistence layer
│   └── .env.example
├── frontend/
│   ├── lib/
│   │   ├── main.dart
│   │   ├── core/theme/         # Retro neo-brutalist design system
│   │   ├── features/           # Screens (home, results)
│   │   └── shared_widgets/     # RetroCard, RetroButton
│   └── pubspec.yaml
└── README.md
```

---

## Scoring Formula

The Opportunity Score is a weighted composite:

| Dimension | Weight |
|---|---|
| Pain Severity | 30% |
| Market Gap | 25% |
| MVP Feasibility | 20% |
| Competition Density | 15% |
| Monetization Potential | 10% |

Each dimension is scored 0–100 by the Business Analyst agent based on evidence from scraped reviews and market research.

---

## Environment Variables

| Variable | Required | Description |
|---|---|---|
| `GEMINI_API_KEY` | Yes | Google Gemini API key |
| `SUPABASE_URL` | No | Supabase project URL (for persistence) |
| `SUPABASE_KEY` | No | Supabase anon key |

---

## License

MIT

---

<p align="center">
  <b>Stop guessing. Start validating.</b>
</p>
