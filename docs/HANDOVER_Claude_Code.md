# Career Content Factory — Claude Code Handover Document
## Everything needed to deploy this correctly from scratch

---

## PROJECT OVERVIEW

This is an n8n automation system for **Sugg.in / Prabhal** — a career guidance platform for Indian high school students. It discovers trending graduation courses in India daily, researches them, generates social media content, renders AI videos, and publishes to LinkedIn, Instagram, Facebook, and YouTube automatically.

**Stack:**
- n8n (self-hosted on Hetzner via Coolify)
- Supabase (PostgreSQL database)
- Google Gemini 2.5 Pro (primary AI)
- SerpAPI (Google Trends + Google News)
- YouTube Data API v3
- HeyGen API (video generation — Video Agent mode)
- Slack (alerts)
- Gmail SMTP (error emails)
- Instagram Graph API, Facebook Graph API, LinkedIn UGC API, YouTube Data API (publishing)

---

## CRITICAL: CHANGES MADE FROM ORIGINAL WORKFLOW FILES

The original JSON files have bugs and design issues that were fixed during setup. Claude Code must implement ALL of these changes — do not use the original JSON as-is.

---

### CHANGE 1 — Credentials approach (affects ALL workflows)

**Original:** All database nodes use `n8n-nodes-base.postgres` with a PostgreSQL credential.

**Changed to:** Use **Supabase node** (`n8n-nodes-base.supabase`) for simple CRUD. Use **HTTP Request** + Supabase REST API + RPC functions for complex SQL.

**Credential name in n8n:** `content_factory` (Supabase type)
- Supabase URL: your project URL e.g. `https://fxhrigzjvpmjvbblbqqr.supabase.co`
- Service Role Secret: from Supabase → Settings → API → service_role key

**For workflows 03–12** that still use Postgres node: replace with either:
- Supabase node for simple SELECT/INSERT/UPDATE
- HTTP POST to `/rest/v1/rpc/function_name` for complex SQL (see SQL functions section below)

---

### CHANGE 2 — Workflow 00: Three bugs fixed

**Bug 1 — Mark Workflow Run Failed used workflow_name (WRONG)**
Original SQL: `WHERE workflow_name = $2 AND status = 'running'`
This matches ALL runs with the same name. Wrong row gets updated.

**Fix:** Created Supabase RPC function, now filters by `n8n_execution_id`.

**Bug 2 — executionId was never passed to Workflow 00**
Original inputs: `workflowName, nodeName, payload, errorMessage, retryCount`
Missing `executionId` — so the RPC functions could never find the right row.

**Fix:** Add `executionId` as 6th input field to the trigger node. Every workflow that calls Workflow 00 must pass `executionId: $execution.id`.

**Bug 3 — Postgres nodes replaced**
- `Log Retry Attempt` → HTTP POST to `/rest/v1/rpc/increment_retry_attempt`
- `Insert into Dead Letter Queue` → Supabase node Create a row on `dead_letter_queue`
- `Mark Workflow Run Failed` → HTTP POST to `/rest/v1/rpc/mark_workflow_failed`

---

### CHANGE 3 — Workflow 01: Two bugs fixed

**Bug 1 — Log Run Start never saved n8n_execution_id**
Original columns: `workflow_name, status` — missing `n8n_execution_id`.

**Fix:** Supabase node Create a row with fields:
- `workflow_name` = `Master Scheduler`
- `n8n_execution_id` = `={{ $execution.id }}`
- `status` = `running`

**Bug 2 — Mark Run Success used workflow_name (WRONG)**
Original SQL: `WHERE workflow_name = 'Master Scheduler' AND status = 'running' ORDER BY started_at DESC LIMIT 1`

**Fix:** Supabase node Update a row filtered by `n8n_execution_id = $execution.id`, sets `status = success` and `finished_at = new Date().toISOString()`.

---

### CHANGE 4 — Workflow 02: Complete redesign

This workflow was almost entirely rewritten. Key changes:

**Sources removed (do not add back):**
- Reddit — removed by client request
- LinkedIn Jobs — no API access (client has posting OAuth only, not jobs API)
- Naukri, Indeed, Shiksha, Careers360, CollegeDekho, AICTE, UGC, NASSCOM, NSDC — all scrape proxy sources removed because education sites require JavaScript rendering (render=true costs 5 credits not 1) and several returned 404. ScraperAPI is NOT used at all.

**Sources kept (3 free API sources):**
1. `google_trends` — SerpAPI, engine: `google_trends`, `data_type: RELATED_QUERIES`, `q: 'courses after 12th'`, geo: IN
2. `google_news` — SerpAPI, engine: `google_news`, `q: 'NEET JEE CAT admission India 2026'`, gl: in
3. `youtube` — YouTube Data API v3, `q: 'courses after 12th India career'`, regionCode: IN, maxResults: 50

**Additional sources (optional, add if data.gov.in key available):**
4. `india_colleges_api` — `https://colleges-api.onrender.com/colleges` — free, no auth, govt AISHE data
5. `datagov_education` — `https://api.data.gov.in/resource/...` — free with registration

**Nodes removed from workflow:**
- `Route by Fetch Mode` (Switch node) — no longer needed, all sources are API
- `Call Scrape Proxy` (HTTP node) — removed entirely
- `Lookup source_id` (Postgres node) — removed, new schema doesn't use source_id FK
- `trend_history` insert node (Postgres) — removed from inside loop

**Nodes added:**
- `Combine All Courses` (Code node) — runs after loop exits, aggregates + deduplicates all courses from all sources
- `Save to trend_history` (Supabase node) — single insert after loop, one row per day

**New flow inside loop:**
```
Call Source API → Normalize to Common Shape → Normalize OK?
    TRUE  → Next Source → back to loop
    FALSE → Error Handler → Next Source → back to loop
```
No database writes inside the loop. All writes happen after the loop completes.

**Bug fixed — missing connection:**
Original: `trend_history` node had no outgoing connection — loop never completed.
Already fixed in `02_Trend_Discovery_FIXED.json` output file.

**Bug fixed — wrong Call Source API wiring:**
Original: `Call Source API output 0` connected to both Normalize AND Error Handler.
Fixed: `output 0` → Normalize only, `output 1` (error) → Error Handler only.

**trend_history table schema changed** (see SQL section below).

**Normalize code completely rewritten** — handles each source type differently with specific parsers. See normalize_code.js output file.

**API keys in code node** — no environment variables available in this n8n version. Keys are hardcoded directly in the Build Source Config List code node. Replace placeholders with real keys:
- `YOUR_SERPAPI_KEY`
- `YOUR_YOUTUBE_API_KEY`

---

### CHANGE 5 — Social platforms reduced (affects Workflows 07, 09, 10)

**Removed platforms:**
- Pinterest
- Telegram
- WhatsApp
- X (Twitter)
- Blog/Newsletter/CMS

**Kept platforms (4 only):**
- Instagram Reels
- YouTube Shorts
- LinkedIn Posts
- Facebook Posts

**In Workflow 07 (Content Generation):**
Change Build Platform List code node from:
```javascript
const platforms = ['instagram_reel','youtube_shorts','linkedin_post','facebook_post','pinterest','telegram','whatsapp','blog','newsletter'];
```
To:
```javascript
const platforms = ['instagram_reel','youtube_shorts','linkedin_post','facebook_post'];
```

**In Workflow 09 (Social Publisher):**
Delete these publish nodes and their connections:
- `Publish: Pinterest API`
- `Publish: Telegram Bot API`
- `Publish: WhatsApp Cloud API`
- `Publish: X API v2`
- `Blog/Newsletter: Mark Scheduled (CMS webhook)`

**In Workflow 10 (Analytics):**
Delete these analytics fetch nodes:
- `GET Pinterest Analytics`
- `GET X Analytics`

---

### CHANGE 6 — HeyGen: Video Agent mode (Workflow 08)

**Original design:** Mode 2 — Custom Avatar with avatar_id + wardrobe pool rotation.

**Changed to:** Mode 1 — Video Agent. Single text prompt, AI generates everything.

**Nodes to DELETE from original Workflow 08:**
- `Pick Next Wardrobe/Background Variant`
- `Mark Variant Used`
- `Gemini: Generate Scene Breakdown`
- `Parse Scene Breakdown`
- `Build HeyGen v2 Payload`

**Nodes to ADD:**
- `Get Total Video Count` — Supabase GET count from video_assets
- `Fetch Active System Prompt Template` — Supabase GET from prompt_templates where template_key = 'heygen_video_agent_system'
- `Fetch Active User Prompt Template` — Supabase GET from prompt_templates where template_key = 'heygen_video_agent_user'
- `Build Video Agent Prompt` — Code node that injects course data into prompt templates and picks attire/background rotation from arrays
- `Payload OK?` — IF node checking prompt is not empty and > 500 chars

**HeyGen API call change:**
Original: `POST /v2/video/generate` with `video_inputs` array (scene by scene)
New: `POST /v2/video/generate` with single `prompt` field combining system + user prompt

**Prompt templates must be inserted into Supabase before first run:**
```sql
INSERT INTO prompt_templates (template_key, version, template_body, is_active, created_by)
VALUES
  ('heygen_video_agent_system', 1, '[paste system prompt from guide]', true, 'manual'),
  ('heygen_video_agent_user',   1, '[paste user prompt from guide]',   true, 'manual');
```

**`wardrobe_background_pool` table** — NOT needed in Video Agent mode. Attire and background rotation is handled by arrays in the Build Video Agent Prompt code node. Do not create this table.

**Cost:** $2 per minute of video (Video Agent mode) vs $1/min (standard avatar).

---

### CHANGE 7 — OpenAI replaced with Gemini (Workflows 04, 07, 11)

**Original:** GPT-5.5 used as primary or fallback in Research Engine, Content Generation, AI Learning Engine.

**Changed:** Replace all OpenAI calls with Gemini 2.5 Pro. OpenAI has no free tier.

**In Workflow 04 (Research Engine):**
`GPT-5.5 Fallback (Grounded)` node — replace URL and body with Gemini 2.5 Pro format.

**In Workflow 07 (Content Generation):**
`GPT-5.5: Generate Content` node — replace with Gemini call.

**In Workflow 11 (AI Learning Engine):**
`GPT-5.5: Rewrite Prompt Template` node — replace with Gemini call.

**Gemini API call format:**
```
POST https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent?key={{GEMINI_API_KEY}}
Body: { contents: [{ role: 'user', parts: [{ text: prompt }] }], generationConfig: { temperature: 0.3 } }
```

---

## SUPABASE SQL FUNCTIONS REQUIRED

Create ALL of these in Supabase SQL Editor before activating any workflow.

```sql
-- Function 1: Used by Workflow 00 (Error Handler) - Log Retry Attempt
CREATE OR REPLACE FUNCTION increment_retry_attempt(
  p_execution_id TEXT,
  p_error_message TEXT
)
RETURNS void AS $$
BEGIN
  UPDATE workflow_runs
  SET items_failed = items_failed + 1,
      error_summary = p_error_message
  WHERE n8n_execution_id = p_execution_id;
END;
$$ LANGUAGE plpgsql;

-- Function 2: Used by Workflow 00 (Error Handler) - Mark Failed
CREATE OR REPLACE FUNCTION mark_workflow_failed(
  p_execution_id TEXT,
  p_error_message TEXT
)
RETURNS void AS $$
BEGIN
  UPDATE workflow_runs
  SET status = 'dead_letter',
      finished_at = now(),
      error_summary = p_error_message
  WHERE n8n_execution_id = p_execution_id;
END;
$$ LANGUAGE plpgsql;

-- Function 3: Used by Workflow 01 (Master Scheduler) - Mark Success
CREATE OR REPLACE FUNCTION mark_workflow_success(
  p_execution_id TEXT
)
RETURNS void AS $$
BEGIN
  UPDATE workflow_runs
  SET status = 'success',
      finished_at = now()
  WHERE n8n_execution_id = p_execution_id;
END;
$$ LANGUAGE plpgsql;
```

---

## COMPLETE DATABASE SCHEMA

Run this entire SQL block in Supabase SQL Editor.

```sql
-- ── EXTENSIONS ───────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS vector;

-- ── ENUMS ────────────────────────────────────────────────────────
CREATE TYPE review_status AS ENUM ('pending','verified','flagged','rejected');
CREATE TYPE content_status AS ENUM ('draft','published','failed','archived');
CREATE TYPE video_status   AS ENUM ('queued','generating','ready','failed');
CREATE TYPE workflow_status AS ENUM ('running','success','dead_letter','failed');

-- ── CORE AUDIT TABLE ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS workflow_runs (
  id               BIGSERIAL PRIMARY KEY,
  workflow_name    TEXT NOT NULL,
  n8n_execution_id TEXT UNIQUE,
  status           workflow_status NOT NULL DEFAULT 'running',
  items_processed  INT DEFAULT 0,
  items_failed     INT DEFAULT 0,
  error_summary    TEXT,
  started_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  finished_at      TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS dead_letter_queue (
  id             BIGSERIAL PRIMARY KEY,
  workflow_name  TEXT NOT NULL,
  node_name      TEXT NOT NULL,
  payload        JSONB,
  error_message  TEXT,
  retry_count    INT DEFAULT 0,
  resolved       BOOLEAN DEFAULT false,
  resolved_at    TIMESTAMPTZ,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ── TREND DISCOVERY ──────────────────────────────────────────────
-- NOTE: New schema — one row per day with all courses in JSONB
-- Original schema had one row per course per source — CHANGED
CREATE TABLE IF NOT EXISTS trend_history (
  id             BIGSERIAL PRIMARY KEY,
  captured_date  DATE NOT NULL UNIQUE,
  total_courses  INT DEFAULT 0,
  source_count   INT DEFAULT 0,
  courses        JSONB NOT NULL DEFAULT '[]',
  created_at     TIMESTAMPTZ DEFAULT now()
);

-- ── COURSE KNOWLEDGE BASE ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS courses (
  id                   BIGSERIAL PRIMARY KEY,
  name                 TEXT NOT NULL,
  slug                 TEXT NOT NULL UNIQUE,
  description          TEXT,
  eligibility          TEXT,
  duration             TEXT,
  entrance_exams       TEXT[],
  emerging_trends      TEXT,
  future_scope         TEXT,
  career_path          TEXT,
  abroad_opportunities TEXT,
  scholarships         TEXT,
  industry_demand      TEXT,
  ai_summary           TEXT,
  embedding            vector(768),
  confidence_score     NUMERIC DEFAULT 0,
  review_status        review_status NOT NULL DEFAULT 'pending',
  last_verified_at     TIMESTAMPTZ,
  deleted_at           TIMESTAMPTZ,
  created_at           TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS course_facts (
  id                 BIGSERIAL PRIMARY KEY,
  course_id          BIGINT REFERENCES courses(id),
  fact_key           TEXT NOT NULL,
  fact_value         TEXT,
  fact_value_numeric NUMERIC,
  confidence_score   NUMERIC DEFAULT 0,
  source_count       INT DEFAULT 0,
  agreement_pct      NUMERIC DEFAULT 0,
  review_status      review_status NOT NULL DEFAULT 'pending',
  source_urls        TEXT[],
  last_verified_at   TIMESTAMPTZ DEFAULT now(),
  deleted_at         TIMESTAMPTZ,
  created_at         TIMESTAMPTZ DEFAULT now(),
  UNIQUE(course_id, fact_key) WHERE deleted_at IS NULL
);

CREATE TABLE IF NOT EXISTS research_raw (
  id           BIGSERIAL PRIMARY KEY,
  course_name  TEXT NOT NULL,
  field_key    TEXT NOT NULL,
  field_value  TEXT,
  model_used   TEXT,
  source_urls  TEXT[],
  raw_payload  JSONB,
  created_at   TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS colleges (
  id          BIGSERIAL PRIMARY KEY,
  course_id   BIGINT REFERENCES courses(id),
  name        TEXT NOT NULL,
  type        TEXT,
  city        TEXT,
  fees_annual NUMERIC,
  deleted_at  TIMESTAMPTZ,
  created_at  TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS salaries (
  id               BIGSERIAL PRIMARY KEY,
  course_id        BIGINT REFERENCES courses(id) UNIQUE,
  average_salary   NUMERIC,
  highest_salary   NUMERIC,
  placement_percent NUMERIC,
  confidence_score NUMERIC DEFAULT 0,
  last_verified_at TIMESTAMPTZ DEFAULT now(),
  deleted_at       TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS careers (
  id          BIGSERIAL PRIMARY KEY,
  course_id   BIGINT REFERENCES courses(id),
  role        TEXT NOT NULL,
  description TEXT,
  deleted_at  TIMESTAMPTZ,
  created_at  TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS faq (
  id          BIGSERIAL PRIMARY KEY,
  course_id   BIGINT REFERENCES courses(id),
  question    TEXT NOT NULL,
  answer      TEXT NOT NULL,
  category    TEXT,
  embedding   vector(768),
  deleted_at  TIMESTAMPTZ,
  created_at  TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS news (
  id           BIGSERIAL PRIMARY KEY,
  course_id    BIGINT REFERENCES courses(id),
  headline     TEXT NOT NULL,
  summary      TEXT,
  url          TEXT,
  published_at TIMESTAMPTZ,
  deleted_at   TIMESTAMPTZ,
  created_at   TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS audit_log (
  id         BIGSERIAL PRIMARY KEY,
  table_name TEXT NOT NULL,
  record_id  BIGINT,
  action     TEXT NOT NULL,
  changed_by TEXT,
  diff       JSONB,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ── CONTENT PIPELINE ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS prompt_templates (
  id            BIGSERIAL PRIMARY KEY,
  template_key  TEXT NOT NULL,
  version       INT NOT NULL DEFAULT 1,
  template_body TEXT NOT NULL,
  is_active     BOOLEAN DEFAULT true,
  created_by    TEXT DEFAULT 'manual',
  created_at    TIMESTAMPTZ DEFAULT now(),
  UNIQUE(template_key, version)
);

CREATE TABLE IF NOT EXISTS content_items (
  id          BIGSERIAL PRIMARY KEY,
  course_id   BIGINT REFERENCES courses(id),
  platform    TEXT NOT NULL,
  title       TEXT,
  body        TEXT,
  hashtags    TEXT[],
  metadata    JSONB,
  script_json JSONB,
  status      content_status NOT NULL DEFAULT 'draft',
  word_count  INT,
  deleted_at  TIMESTAMPTZ,
  created_at  TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS video_assets (
  id                BIGSERIAL PRIMARY KEY,
  content_item_id   BIGINT REFERENCES content_items(id),
  avatar_id         TEXT,
  wardrobe_variant  TEXT,
  background_variant TEXT,
  scene_breakdown   JSONB,
  heygen_video_id   TEXT,
  video_url         TEXT,
  duration_seconds  NUMERIC,
  status            video_status NOT NULL DEFAULT 'queued',
  error_message     TEXT,
  deleted_at        TIMESTAMPTZ,
  created_at        TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS publish_targets (
  id               BIGSERIAL PRIMARY KEY,
  content_item_id  BIGINT REFERENCES content_items(id),
  video_asset_id   BIGINT REFERENCES video_assets(id),
  platform         TEXT NOT NULL,
  published_at     TIMESTAMPTZ,
  external_post_id TEXT,
  external_url     TEXT,
  status           TEXT DEFAULT 'published',
  deleted_at       TIMESTAMPTZ,
  created_at       TIMESTAMPTZ DEFAULT now()
);

-- ── ANALYTICS ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS analytics (
  id                   BIGSERIAL PRIMARY KEY,
  publish_target_id    BIGINT REFERENCES publish_targets(id),
  metric_date          DATE NOT NULL DEFAULT CURRENT_DATE,
  views                BIGINT DEFAULT 0,
  reach                BIGINT DEFAULT 0,
  watch_time_seconds   BIGINT DEFAULT 0,
  retention_pct        NUMERIC DEFAULT 0,
  likes                BIGINT DEFAULT 0,
  comments             BIGINT DEFAULT 0,
  shares               BIGINT DEFAULT 0,
  saves                BIGINT DEFAULT 0,
  new_subscribers      BIGINT DEFAULT 0,
  new_followers        BIGINT DEFAULT 0,
  ctr_pct              NUMERIC DEFAULT 0,
  completion_rate_pct  NUMERIC DEFAULT 0,
  raw_payload          JSONB,
  deleted_at           TIMESTAMPTZ,
  created_at           TIMESTAMPTZ DEFAULT now(),
  UNIQUE(publish_target_id, metric_date) WHERE deleted_at IS NULL
);

-- ── AI LEARNING ENGINE ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS learning_insights (
  id              BIGSERIAL PRIMARY KEY,
  insight_type    TEXT NOT NULL,
  finding         TEXT,
  supporting_data JSONB,
  confidence      NUMERIC DEFAULT 0,
  applied         BOOLEAN DEFAULT false,
  applied_at      TIMESTAMPTZ,
  created_at      TIMESTAMPTZ DEFAULT now()
);
```

---

## N8N CREDENTIALS REQUIRED

Create these in n8n → Credentials before importing workflows.

### 1. Supabase (type: Supabase)
- Name: `content_factory`
- Supabase URL: `https://YOUR_PROJECT_ID.supabase.co`
- Service Role Secret: from Supabase → Settings → API → service_role key

### 2. Slack (type: Slack API)
- Name: `Slack - Career Factory`
- Access Token: `xoxb-...` bot token
- Required scopes: `chat:write`, `chat:write.public`

### 3. Gmail SMTP (type: SMTP)
- Name: `Ops SMTP`
- Host: `smtp.gmail.com`
- Port: `587`
- User: your Gmail address
- Password: Gmail App Password (16-char, generated in Google Account → Security → App Passwords)

---

## N8N VARIABLES (Settings → Variables)

These don't exist as proper variables in this n8n version. Hardcode directly in code nodes.

| Key | Used In | Where to put it |
|---|---|---|
| `SERPAPI_KEY` | Workflow 02 Build Source Config List | Hardcode in code node |
| `YOUTUBE_API_KEY` | Workflow 02 Build Source Config List | Hardcode in code node |
| `GEMINI_API_KEY` | Workflows 04, 06, 07, 08, 11 | Hardcode in HTTP node URL param |
| `HEYGEN_API_KEY` | Workflow 08 | Hardcode in HTTP node header |
| `SLACK_ALERTS_CHANNEL_ID` | Workflows 00, 05, 10, 11, 12 | Hardcode in Slack node channel ID field |
| `ALERTS_FROM_EMAIL` | Workflow 00 | Hardcode in Email node |
| `ALERTS_TO_EMAIL` | Workflow 00 | Hardcode in Email node |
| `IG_BUSINESS_ACCOUNT_ID` | Workflow 09 | Hardcode in HTTP node URL |
| `FB_PAGE_ID` | Workflow 09 | Hardcode in HTTP node URL |
| `META_ACCESS_TOKEN` | Workflow 09 | Hardcode in HTTP node header |
| `LINKEDIN_ORG_ID` | Workflow 09 | Hardcode in HTTP node body |
| `DATAGOV_API_KEY` | Workflow 02 (optional) | Hardcode in code node |

---

## WORKFLOW IMPORT ORDER

Import in this exact sequence. Get the real n8n ID after each import before importing the next.

1. **00 - Shared Error Handler** → note its ID
2. **01 - Master Scheduler** → set error workflow to ID #1
3. **02 - Trend Discovery** → set error workflow to ID #1
4. **03 - Trend Ranking** → set error workflow to ID #1
5. **04 - Research Engine** → set error workflow to ID #1
6. **05 - Fact Validation** → set error workflow to ID #1
7. **06 - Knowledge Base Update** → set error workflow to ID #1
8. **07 - Content Generation** → set error workflow to ID #1
9. **08 - HeyGen Video** → set error workflow to ID #1
10. **09 - Social Publisher** → set error workflow to ID #1
11. **10 - Analytics** → set error workflow to ID #1
12. **11 - AI Learning Engine** → set error workflow to ID #1
13. **12 - Quarterly Data Cleanup** → set error workflow to ID #1

After importing all, go back to each workflow and replace `WORKFLOW_ID_XX` placeholders with real IDs.

---

## PLACEHOLDER REPLACEMENT MAP

Every occurrence of these strings in workflow JSON must be replaced with real values.

| Placeholder | Replace With |
|---|---|
| `CREDENTIAL_ID_POSTGRES` | n8n ID of `content_factory` Supabase credential |
| `CREDENTIAL_ID_SLACK` | n8n ID of `Slack - Career Factory` credential |
| `CREDENTIAL_ID_SMTP` | n8n ID of `Ops SMTP` credential |
| `WORKFLOW_ID_00_ERROR_HANDLER` | Real n8n ID of Workflow 00 |
| `WORKFLOW_ID_02_TREND_DISCOVERY` | Real n8n ID of Workflow 02 |
| `WORKFLOW_ID_04_RESEARCH_ENGINE` | Real n8n ID of Workflow 04 |
| `WORKFLOW_ID_05_FACT_VALIDATION` | Real n8n ID of Workflow 05 |
| `WORKFLOW_ID_06_KNOWLEDGE_BASE_UPDATE` | Real n8n ID of Workflow 06 |
| `WORKFLOW_ID_10_ANALYTICS` | Real n8n ID of Workflow 10 |
| `WORKFLOW_ID_12_DATA_CLEANUP` | Real n8n ID of Workflow 12 |

---

## WORKFLOW-BY-WORKFLOW NODE CHANGES SUMMARY

### Workflow 00 — Shared Error Handler
| Node | Original | Change |
|---|---|---|
| Trigger | 5 inputs | Add 6th input: `executionId` (string) |
| Log Retry Attempt | Postgres executeQuery | HTTP POST to `/rest/v1/rpc/increment_retry_attempt` |
| Insert into Dead Letter Queue | Postgres insert | Supabase node Create a row on `dead_letter_queue` |
| Mark Workflow Run Failed | Postgres executeQuery | HTTP POST to `/rest/v1/rpc/mark_workflow_failed` |

Every workflow calling Workflow 00 must include `executionId: $execution.id` in its inputs.

### Workflow 01 — Master Scheduler
| Node | Original | Change |
|---|---|---|
| Log Run Start | Postgres insert (missing executionId) | Supabase node Create a row — add `n8n_execution_id: $execution.id` |
| Mark Run Success | Postgres executeQuery (wrong WHERE) | Supabase node Update a row — filter by `n8n_execution_id = $execution.id` |

### Workflow 02 — Trend Discovery (biggest change)
| Node | Status | Detail |
|---|---|---|
| Build Source Config List | REWRITE | 3 sources only: google_trends, google_news, youtube. No scrape proxy. Keys hardcoded. |
| Route by Fetch Mode | DELETE | Not needed — all sources are API calls |
| Call Scrape Proxy | DELETE | No scraping |
| Normalize to Common Shape | REWRITE | Full parser for each source type. See normalize_code.js |
| Lookup source_id | DELETE | New schema doesn't use source_id FK |
| trend_history (insert) | DELETE from loop | Moved outside loop |
| Combine All Courses | ADD | Code node after loop — aggregates + deduplicates |
| Save to trend_history | ADD | Supabase Create a row — one row per day |
| Log Run Start | Postgres → Supabase | Add n8n_execution_id |
| Mark Run Complete | Postgres → Supabase Update | Filter by n8n_execution_id |
| Call Source API wiring | FIX | output 0 → Normalize ONLY, output 1 → Error Handler |
| trend_history → Next Source | FIX | Add this missing connection |

### Workflow 07 — Content Generation
- `Build Platform List` code node: remove `pinterest`, `telegram`, `whatsapp`, `blog`, `newsletter`
- `GPT-5.5: Generate Content` HTTP node: replace with Gemini 2.5 Pro call

### Workflow 08 — HeyGen Video
- Delete: `Pick Next Wardrobe/Background Variant`, `Mark Variant Used`, `Gemini: Generate Scene Breakdown`, `Parse Scene Breakdown`, `Build HeyGen v2 Payload`
- Add: `Get Total Video Count`, `Fetch Active System Prompt Template`, `Fetch Active User Prompt Template`, `Build Video Agent Prompt`
- Modify: HeyGen POST payload — use single `prompt` field instead of `video_inputs` array
- All Postgres nodes → Supabase nodes

### Workflow 09 — Social Publisher
- Delete publisher nodes for: Pinterest, Telegram, WhatsApp, X, Blog/Newsletter
- All Postgres nodes → Supabase nodes

### Workflow 10 — Analytics
- Delete: `GET Pinterest Analytics`, `GET X Analytics`
- All Postgres nodes → Supabase nodes

### Workflow 11 — AI Learning Engine
- `GPT-5.5: Rewrite Prompt Template` → replace with Gemini 2.5 Pro call
- All Postgres nodes → Supabase nodes

### Workflows 03, 04, 05, 06, 12
- All Postgres nodes → Supabase nodes or HTTP RPC calls
- For complex SQL (JOINs, ON CONFLICT, array operations): create Supabase RPC functions

---

## EMAIL (GMAIL) CONFIGURATION

**From original JSON:** Workflow 00 uses `n8n-nodes-base.emailSend` with SMTP credential.

**Settings:**
- From: `={{ $env.ALERTS_FROM_EMAIL }}` → hardcode your Gmail address
- To: `={{ $env.ALERTS_TO_EMAIL }}` → hardcode your Gmail address
- Subject: `=[Career Content Factory] {{$json.workflowName}} - Dead Letter`
- Format: Text

**Gmail SMTP setup:**
1. Gmail → Google Account → Security → 2-Step Verification → ON
2. Security → App Passwords → create one named "n8n"
3. Use the 16-char app password (no spaces) as SMTP password
4. Host: `smtp.gmail.com`, Port: `587`

---

## HEYGEN VIDEO AGENT PROMPTS

Insert these into `prompt_templates` table before first run:

### System Prompt (template_key: 'heygen_video_agent_system')
```
You are an AI video director specialising in educational career guidance content for Indian students aged 17–22. Your job is to produce 60-second vertical videos (9:16 aspect ratio) for Instagram Reels and YouTube Shorts.

TONE: Warm, clear, and energising — like a trusted older sibling who has navigated the Indian education system.

PRESENTER: An Indian woman in her early-to-mid 20s. Professional yet approachable. Speaks in clear Indian English. Dressed in professional Indian attire (saree or formal blazer). Warm smile, confident posture.

STUDIO: Clean, modern, well-lit studio with career/education-themed background.

STRUCTURE — every video must follow this exact 5-beat arc:
  Beat 1 — HOOK (5 seconds): One surprising fact or question that grabs attention.
  Beat 2 — PROBLEM (10 seconds): The real confusion students have about this course.
  Beat 3 — OPPORTUNITY (15 seconds): What this course opens up.
  Beat 4 — EVIDENCE (15 seconds): 2–3 hard facts with text overlays.
  Beat 5 — CTA (15 seconds): One clear next step.

OUTPUT: Generate a complete scene-by-scene video with narration and visual direction.
```

### User Prompt Template (template_key: 'heygen_video_agent_user')
```
Create a 60-second career guidance Reel for this course. Use ONLY the facts below — do not invent anything.

COURSE: {{course_name}}
Description: {{description}}
Eligibility: {{eligibility}}
Duration: {{duration}}
Entrance exams: {{entrance_exams}}
Average salary: ₹{{average_salary}} per year
Highest salary: ₹{{highest_salary}} per year
Placement rate: {{placement_percent}}%
Top recruiters: {{recruiters_top5}}
Career paths: {{career_path}}
Top govt colleges: {{government_colleges_top3}}
Industry demand: {{industry_demand}}
Future scope: {{future_scope}}

Presenter attire this video: {{attire_variant}}
Studio background this video: {{background_variant}}

Return scene-by-scene breakdown with narration, duration, text overlays, and visual direction.
```

---

## ACTIVATION ORDER

Activate workflows in this order — never activate 01 (Master Scheduler) until all others are ready:

1. Activate Workflow 00 (Error Handler) — always on
2. Activate Workflow 02 (Trend Discovery) — test manually first
3. Activate Workflow 03, 04, 05, 06 — test manually
4. Activate Workflow 07, 08, 09 — test manually
5. Activate Workflow 10, 11, 12
6. **Activate Workflow 01 (Master Scheduler) LAST** — this starts the daily automation

---

## TESTING SEQUENCE

Before activating Master Scheduler, manually test each workflow in sequence:

1. Manually trigger Workflow 02 → verify `trend_history` has one row in Supabase
2. Manually trigger Workflow 03 → verify courses are ranked
3. Manually trigger Workflow 04 with test course name → verify `research_raw` has rows
4. Manually trigger Workflow 05 → verify `course_facts` has rows
5. Manually trigger Workflow 06 → verify `courses` table has full denormalized record
6. Manually trigger Workflow 07 → verify `content_items` has 4 draft rows (one per platform)
7. Manually trigger Workflow 08 → verify HeyGen renders a test video
8. Manually trigger Workflow 09 → verify posts appear on social platforms
9. Manually trigger Workflow 10 → verify `analytics` table gets data
10. Activate Workflow 01

---

## FILES REFERENCE

| File | What it is |
|---|---|
| `00_-_Shared_Error_Handler_Sub-Workflow.json` | Original — apply credential + executionId fixes |
| `01_-_Master_Scheduler.json` | Original — apply Log Run Start + Mark Run Success fixes |
| `02_Trend_Discovery_FINAL.json` | Fixed version — use this, not the original 02 file |
| `03_-_Trend_Ranking.json` | Original — replace Postgres nodes with Supabase |
| `04_-_Research_Engine.json` | Original — replace Postgres + OpenAI nodes |
| `05_-_Fact_Validation.json` | Original — replace Postgres nodes |
| `06_-_Knowledge_Base_Update.json` | Original — replace Postgres nodes |
| `07_-_Content_Generation.json` | Original — remove 5 platforms, replace OpenAI |
| `08_-_HeyGen_Video.json` | Original — full Video Agent redesign needed |
| `09_-_Social_Publisher.json` | Original — remove 5 platform publisher nodes |
| `10_-_Analytics.json` | Original — remove Pinterest + X analytics nodes |
| `11_-_AI_Learning_Engine.json` | Original — replace OpenAI node |
| `12_-_Quarterly_Data_Cleanup.json` | Original — replace Postgres nodes |
| `normalize_code.js` | Rewritten Normalize to Common Shape code |
| `WF00_Node_Configurations.md` | Detailed node config for Workflow 00 |
| `WF01_Master_Scheduler_Setup.md` | Detailed node config for Workflow 01 |
| `WF02_Trend_Discovery_Setup.md` | Detailed node config for Workflow 02 |

---

## KNOWN ISSUES / WATCH OUT FOR

1. **Workflow 03 queries trend_history with old schema** — it runs SQL aggregating by `normalized_name` and `captured_date`. With the new one-row-per-day schema, this query will fail. Workflow 03 needs to be updated to read from `courses JSONB` column and process the array.

2. **Workflow 05 Fact Validation scrapes Naukri + AmbitionBox via proxy** — these ToS violations should be removed. Replace cross-check sources with LinkedIn Salary Insights API or remove numeric cross-checking entirely for MVP.

3. **Workflow 06 uses pgvector embedding** — Supabase free tier supports pgvector. The `embedding` column is `vector(768)` matching Google's `text-embedding-004` output. Confirm the extension is enabled.

4. **Workflow 08 `wardrobe_background_pool` references** — if using original file, all queries to this table will fail. Either create the table (for Mode 2) or delete all nodes that reference it (for Video Agent Mode 1).

5. **Telegram credential in Workflow 09** — the original file has `telegramApi` credential on the Telegram node. If removing Telegram, delete the node entirely to avoid credential errors.

6. **VACUUM in Workflow 12** — `VACUUM ANALYZE` cannot run inside a transaction. Do NOT wrap this in an RPC function. It requires a direct Postgres connection (not Supabase REST API). Either: use n8n Postgres node with direct Supabase connection for this specific node, or replace VACUUM with `ANALYZE` only (which can run via REST/RPC).
