# Case Study: Career Content Factory
### AI-Powered, Fully Automated Content Pipeline for Career Guidance (Sugg.in / Prabhal)

**Status:** Built and in final end-to-end validation (pre-launch). Every workflow has been rebuilt, live-tested against real APIs, and is being validated stage by stage before full activation.

---

## 1. Overall Automation Architecture and Workflow

The system is a **13-workflow pipeline** in n8n, each workflow doing one job and calling the next via `executeWorkflow` sub-workflow calls, coordinated by a master scheduler:

```
01 Master Scheduler (cron)
 └─ 02 Trend Discovery        → pulls trending Indian graduation courses from
                                  Google Trends, Google News, YouTube, and
                                  scraped college/course sites
 └─ 03 Trend Ranking          → scores & ranks courses by demand signal
 └─ 04 Deep Research          → AI research per course, grounded in live web
                                  search (not model memory)
 └─ 05 Fact Validation        → cross-checks facts, flags low-confidence
                                  claims for human review before they enter
                                  the knowledge base
 └─ 06 Knowledge Base Update  → writes verified course facts to Supabase
 └─ 07 Content Generation     → turns facts into a scene-by-scene video
                                  script using a self-improving prompt template
 └─ 08 Video Generation       → sends script to HeyGen's Video Agent API,
                                  polls until the render completes
 └─ 09 Multi-Platform Publish → posts the SAME finished video natively to
                                  Instagram, YouTube, Facebook, and LinkedIn
 └─ 10 Analytics Collection   → pulls performance data back from every
                                  platform into Supabase
 └─ 11 Learning Engine        → analyzes performance data, rewrites and
                                  versions the content-generation prompt
                                  template based on what's actually working
 └─ 12 Quarterly Cleanup      → purges stale data, re-indexes core tables

00 Shared Error Handler        → every workflow above calls this one on
                                  failure — classification, retry, dead-letter,
                                  alerting (detail in section 6)
```

Data flows through Supabase (Postgres) as the single source of truth between stages — no workflow holds state itself, so any stage can be re-run independently without corrupting the others.

---

## 2. Automation Tools Used

**n8n**, self-hosted (Docker via Coolify on a Hetzner VPS) — not Make.com or Zapier.

Why self-hosted n8n over a SaaS automation tool:
- No per-execution/per-operation billing — cost is fixed hosting cost regardless of daily volume
- Direct REST access to Supabase (Postgres) without a paid connector tier
- Full control over retry logic, sub-workflow composition, and credential scoping
- Version-controllable workflow JSON, so every change is auditable and revertible

All inter-workflow data passes through Postgres/Supabase via PostgREST (bulk inserts, nested-resource embeds for joins) rather than raw SQL, which keeps the system portable and avoids needing a direct database credential anywhere in the pipeline.

---

## 3. AI Models / APIs Used

- **Google Gemini** (`gemini-2.5-flash` / `gemini-2.5-pro`) via n8n's AI Agent node with an automatic model-fallback chain (primary model → fallback model on failure), used for content generation, fact synthesis, and the self-improving prompt-rewrite step.
- **Gemini's raw REST API with Google Search grounding** (`tools:[{google_search:{}}]`) used specifically for the research stage — called directly via HTTP rather than n8n's chat-model node, because grounded web search isn't exposed through that node. This is the deliberate design choice that keeps facts current instead of relying on model training data.
- **SerpAPI** (Google Trends + Google News, India-scoped) and **YouTube Data API v3** for trend signal discovery.
- **ScraperAPI** (JS-rendering mode) for sources that require rendering, used only where a pure API source doesn't exist — validated live rather than assumed available.

---

## 4. Voice Generation and Video Generation Approach

Video generation uses **HeyGen's Video Agent API (v3)**:

1. Gemini produces a structured, scene-by-scene script: hook → problem → opportunity → evidence → CTA, with exact narration text and visual direction per scene.
2. That script is submitted as a single prompt to HeyGen's `POST /v3/video-agents` endpoint, which handles presenter avatar, voice synthesis, and scene assembly as one unit — no separate TTS/voice-cloning step needed.
3. n8n polls `GET /v3/videos/{id}` on a switch-routed loop (completed / failed / still-processing / timeout outputs) until the render finishes.

One video is generated **once per course** (keyed by `course_id`), not once per platform or per content variant — the same finished asset is then distributed everywhere, which is both cheaper and keeps messaging consistent across platforms.

---

## 5. YouTube, Instagram, Facebook, LinkedIn Publishing Process

- **YouTube** — n8n's native YouTube node (OAuth2), direct video upload with generated title/description/tags.
- **Facebook & Instagram** — n8n's native Facebook Graph API node; Instagram publishing goes through the Facebook Graph API against the linked IG Business Account, with async processing status polled the same way as HeyGen render status.
- **LinkedIn** — no native n8n video-publish node, so this is a 4-step raw HTTP flow: register an upload asset → download the video bytes → PUT the binary to LinkedIn's signed upload URL → create the UGC post referencing that asset.

All four platforms are triggered from the same distribution workflow after a single successful video render, routed by a switch node with explicit per-platform outputs (not positional merge, which is a common source of silent hangs when branches aren't all guaranteed to fire).

---

## 6. Error Handling, Retries, Duplicate Content, and Failures

- Every workflow calls a **shared error-handler sub-workflow** on failure rather than each implementing its own logic.
- The handler **classifies** the error (rate limit / timeout / server error / auth / validation) from the raw message, and applies **exponential backoff retry** for retryable categories, up to a category-specific max attempt count.
- Once retries are exhausted, the failure is written to a **dead-letter queue** table (full payload + error context, so it can be replayed manually) and a **Slack + email alert** fires immediately.
- **Duplicate content** is prevented structurally, not by dedup logic bolted on after the fact: video generation is keyed by `course_id`, so the same course can't produce two videos even if the pipeline runs twice; trend discovery normalizes course names before insert to avoid near-duplicate entries in the same table.
- All error-handler alert and dead-letter code has been live-tested against real failures during build (not just designed on paper) — including catching and fixing a bug where failure payloads were being serialized incorrectly and silently losing data, found during this project's own validation pass.

---

## 7. Approximate Cost Per Piece of Content

Cost is dominated by video rendering; everything upstream of it is near-free at this volume. Figures below are **estimates based on each vendor's published pricing** at the time of writing — confirm current rates before quoting a client, as AI/video API pricing changes frequently:

| Component | Approx. cost driver | Notes |
|---|---|---|
| Trend discovery (SerpAPI, YouTube API) | Free tier covers daily use at this volume | SerpAPI free tier ~100 searches/mo; scale plans start ~$50/mo |
| Scraping (ScraperAPI, JS render) | Free tier ~5,000 credits/mo | Only used for sources with no API |
| Research + content generation (Gemini) | Free tier is generous at flash-model rate limits | Pro model or high volume moves to paid per-token pricing |
| Video generation (HeyGen) | **Primary cost** — credit/minute-based | Confirm HeyGen's current API plan pricing directly; this is the number to nail down before quoting per-video cost |
| Hosting (n8n + Supabase) | Fixed monthly, not per-execution | Hetzner VPS + Supabase free/pro tier — cost doesn't scale with content volume |

**Bottom line for a client conversation:** infrastructure and research cost is close to fixed/free regardless of volume; the true per-video marginal cost is HeyGen's rendering credits, which should be quoted from their current published tier rather than estimated here.

---

## 8. Fully Automated vs. Human Approval

**Fully automated, no human in the loop:**
Trend discovery → ranking → research → content generation → video rendering → multi-platform publishing → analytics collection → prompt self-improvement → cleanup.

**Human checkpoint by design:**
The Fact Validation stage (WF05) flags any fact that fails a confidence check as **"Flagged for Review"** — those facts do not enter the trusted knowledge base or get used in a video script until manually cleared. This is the only required human touchpoint in the pipeline; everything else runs unattended end to end once activated.

---

## 9. Scalability Design

- **Stateless stage-to-stage handoff** through Postgres means any stage can scale, retry, or be re-run independently without coordination overhead.
- **Bulk inserts** (single request with a JSON array) replace per-row insert loops throughout, keeping database round-trips flat as course volume grows.
- **JSONB-per-day schema** for time-series tables (trend history, research) avoids row-count explosion — one row per day/course instead of one row per field per source.
- **Adding a new trend source or publishing platform** is a matter of adding a case to an existing switch/router node, not restructuring the pipeline.
- **Retry/backoff isolates single-course failures** from the batch — one bad API response doesn't take down the day's run.
- n8n and Supabase scale independently of each other, so either can be upgraded (more workers, bigger DB tier) without touching the other.

---

## 10. Role and Contribution

Full ownership of design and build: designed the Supabase schema (including the JSONB redesign to control row growth), rebuilt and live-audited all 13 workflows against the running n8n instance, replaced every raw-Postgres dependency with Supabase REST equivalents, integrated and **live-validated** every external data source before trusting it in production (catching at least one dead/broken source before it shipped), built the shared retry/dead-letter/alerting infrastructure, and is currently owning the manual end-to-end validation pass before go-live.

---

## How This Adapts to Your Startup Media Platform

Your stated flow — **idea generation/research → script → voice → video → thumbnail/metadata → multi-platform publishing → analytics/reporting** — maps almost directly onto this pipeline's existing stages:

| Your stage | Maps to | Status |
|---|---|---|
| Idea generation / research | WF02–WF06 (trend discovery → ranking → research → validation → knowledge base) | Reusable as-is, topic domain is swappable |
| Script | WF07 (content generation, self-improving prompts) | Reusable as-is |
| Voice + Video | WF08 (HeyGen Video Agent) | Reusable as-is — voice is generated inside the video step, no separate TTS stage needed |
| Thumbnail / metadata | *New* | Not yet a discrete stage in this pipeline — straightforward to add as a step between WF08 and WF09 (Gemini for title/description/tags, a thumbnail-frame extraction or generation call) |
| Multi-platform publishing | WF09 | Reusable as-is for IG/YouTube/FB/LinkedIn |
| Analytics / reporting | WF10–WF11 | Reusable as-is, including the self-improving loop |

The core architecture — trend/topic discovery, grounded research, script generation, HeyGen rendering, multi-platform fan-out, analytics feedback, retry/dead-letter infrastructure — is domain-agnostic. The main net-new work for your platform is the thumbnail/metadata stage and swapping the topic-discovery sources for whatever your content vertical requires.

---

*This document describes an active build for Sugg.in/Prabhal, currently in final validation before production go-live. Demo recordings and screenshots of live output will follow once end-to-end testing across all platforms is complete.*
