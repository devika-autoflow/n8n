# Career Content Factory — Complete Project Brief for Claude Code

> Read this entire document before touching any workflow file.
> This is everything you need to understand what the system does,
> why each workflow exists, what platforms it uses, what went wrong
> during setup, and how each problem was fixed.

---

## WHO BUILT THIS AND FOR WHOM

**Built by:** Devika NR — freelance automation consultant, Qubitrix (Kerala, India)
**Client:** Prabhal — founder of Sugg.in
**Client's product:** Sugg.in is a career guidance platform for Indian high school students. It includes a WhatsApp chatbot called Disha that helps Class 10–12 students choose the right graduation course.
**Infrastructure:** n8n self-hosted on Hetzner via Coolify, Supabase as database

---

## WHAT THIS SYSTEM DOES — THE BIG PICTURE

Every morning at 8 AM IST, this system automatically:

1. Discovers which graduation courses Indian students are searching for today
2. Picks the top 10 trending courses
3. Researches each course deeply — colleges, salary, career paths, entrance exams
4. Verifies the researched facts for accuracy
5. Stores all verified data in a structured knowledge base
6. Generates social media content for each course — Instagram Reel script, YouTube Shorts script, LinkedIn post, Facebook post
7. Renders an AI video using HeyGen for the Reel/Shorts
8. Publishes everything to Instagram, YouTube, LinkedIn, Facebook
9. Tracks analytics for every published post
10. Weekly — analyses what content performed best and automatically improves the AI prompts for next time

**The goal:** Build a fully automated, self-improving content machine that publishes daily educational career content about Indian graduation courses — keeping Sugg.in's social media active and driving students to the platform without any human effort after initial setup.

---

## THE 13 WORKFLOWS — WHAT EACH ONE DOES

---

### WORKFLOW 00 — Shared Error Handler (Sub-Workflow)

**Purpose:** Safety net for the entire system. Never runs on its own. Called by every other workflow when something breaks.

**What it does step by step:**
1. Receives an error from another workflow — the workflow name, node name, error message, how many times it has already retried, and the execution ID
2. Classifies the error — is it a rate limit? A timeout? An auth failure? A bad response?
3. Decides: is this a retryable error AND are we under the retry limit?
4. **If yes (retryable):** waits with exponential backoff (5s, 10s, 20s, 40s...) then signals the calling workflow to retry
5. **If no (give up):** saves the failed item to a `dead_letter_queue` table in Supabase, marks the workflow run as dead_letter, sends a Slack alert AND an email alert to the operator

**Why it matters:** Without this, one API failure would crash the entire daily pipeline. With this, transient failures (rate limits, timeouts) heal themselves, and permanent failures are logged so you can fix and replay them later.

**Platforms used:** Supabase (logging), Slack (alerts), Gmail SMTP (email alerts)

---

### WORKFLOW 01 — Master Scheduler

**Purpose:** The alarm clock. Starts the entire daily pipeline.

**What it does step by step:**
1. Fires at 8:00 AM IST every day (cron: `0 30 2 * * *` = 2:30 AM UTC = 8:00 AM IST)
2. Checks what day it is — Monday? 1st of month? Quarter start?
3. Always fires Workflow 02 (Trend Discovery)
4. Only on Mondays — also fires Workflow 10 (Analytics) in weekly mode
5. Only on 1st of month — also fires Workflow 06 (Knowledge Base) in monthly refresh mode
6. Only on Jan 1, Apr 1, Jul 1, Oct 1 — also fires Workflow 12 (Data Cleanup)
7. Logs the run start and end to Supabase

**Platforms used:** Supabase (run logging)

---

### WORKFLOW 02 — Trend Discovery

**Purpose:** Market research. Finds out what graduation courses Indian students are searching for today.

**What it does step by step:**
1. Called by Master Scheduler
2. Builds a list of data sources to query (after all changes: 3 API sources)
3. Loops through each source one at a time
4. For each source: calls the API, gets raw data
5. Normalizes the completely different response formats into one consistent shape: `{ course_name, search_volume, mentions, hiring_demand, growth_pct... }`
6. Checks if normalization worked — if not, logs the error and moves to next source
7. After ALL sources are done: combines everything, deduplicates courses (same course from multiple sources gets its scores merged), saves ONE row to `trend_history` table for today
8. Marks the run as complete

**Final data sources (after all fixes):**
- Google Trends (via SerpAPI) — `engine: google_trends`, `q: 'courses after 12th'`, `data_type: RELATED_QUERIES`, geo: IN — returns what Indian students are searching related to courses
- Google News (via SerpAPI) — `engine: google_news`, `q: 'NEET JEE CAT admission India 2026'` — returns current education news
- YouTube Data API v3 — `q: 'courses after 12th India career'`, regionCode: IN — returns popular career guidance videos

**Platforms used:** SerpAPI, YouTube Data API v3, Supabase

---

### WORKFLOW 03 — Trend Ranking

**Purpose:** Takes all the raw trend signals and produces a ranked Top 10.

**What it does step by step:**
1. Called by Workflow 02 after it finishes
2. Reads today's `trend_history` row from Supabase (the JSONB column with all courses)
3. For each unique course, computes a weighted trend score:
   - `score = (search_volume × 25%) + (hiring_demand × 25%) + (discussions × 20%) + (news_mentions × 15%) + (social_engagement × 15%)`
   - These weights are configurable — the AI Learning Engine can tune them over time
4. Sorts all courses by score, takes the Top 10
5. For each of the Top 10: calls Workflow 04 (Research Engine) once

**Platforms used:** Supabase

---

### WORKFLOW 04 — Research Engine

**Purpose:** Deep research on each trending course. One execution per course.

**What it does step by step:**
1. Called once per course from Workflow 03 (so runs 10 times per day)
2. Builds 5 research prompts, each covering a different group of data:
   - Group 1: Basic info — description, eligibility, duration, entrance exams, emerging trends
   - Group 2: Colleges — top government colleges, top private colleges (with fees)
   - Group 3: Salary & Career — average salary (INR), highest salary, placement %, top recruiters, career paths
   - Group 4: Opportunities — industry demand, future scope, abroad options, scholarships
   - Group 5: Community — FAQs students ask, common pain points, myths, latest news
3. For each group: sends prompt to Gemini 2.5 Pro with web search enabled (grounded) → gets structured JSON back
4. If Gemini fails: falls back to GPT-5.5 (replace with Gemini in deployment — no OpenAI budget)
5. Parses the JSON and saves each field as its own row in `research_raw` table
6. After all 5 groups: calls Workflow 05 (Fact Validation)

**Platforms used:** Google Gemini 2.5 Pro API, Supabase

---

### WORKFLOW 05 — Fact Validation

**Purpose:** Independent cross-checking of researched facts. Ensures data is accurate before publishing.

**What it does step by step:**
1. Called by Workflow 04 for each course
2. Fetches all the raw research fields from `research_raw` table
3. Loops through each field one at a time
4. For numeric fields (salary, placement %, fees): cross-checks against 4 external sources simultaneously, computes agreement percentage
5. For text fields (description, FAQs, etc.): scores based on how many sources Gemini cited
6. If agreement >= 80%: marks as verified, writes to `course_facts` table
7. If agreement < 80%: flags for human review, sends Slack notification so operator can manually verify
8. After all fields are processed: calls Workflow 06 (Knowledge Base Update)

**Note on cross-check sources:** Original design cross-checked against Naukri, AmbitionBox (ToS violations via scrape proxy). For MVP, simplify or remove numeric cross-checking — or replace with official government data sources.

**Platforms used:** Supabase, Slack

---

### WORKFLOW 06 — Knowledge Base Update

**Purpose:** Assembles all verified facts into a clean, complete course record ready for content generation.

**What it does step by step:**
1. Called by Workflow 05 after validation
2. Checks if this is a `monthly_refresh` — if yes, finds facts older than 90 days and re-researches them
3. Fetches all verified `course_facts` for this course
4. Builds one complete denormalized record — all facts assembled into one object
5. Calls Gemini to write a human-readable AI summary of the course
6. Calls Gemini embedding API (`text-embedding-004`) to generate a 768-dimension vector for semantic search
7. Updates the `courses` table with all fields + the embedding
8. Syncs the `colleges` table (soft-deletes old, inserts new)
9. Syncs the `faq` table (soft-deletes old, inserts new with embeddings)
10. Inserts latest news items into `news` table
11. Writes an audit log entry
12. Calls Workflow 07 (Content Generation)

**Platforms used:** Google Gemini 2.5 Pro API (summary), Google text-embedding-004 API (embeddings), Supabase

---

### WORKFLOW 07 — Content Generation

**Purpose:** Generates social media content for each course across all 4 platforms.

**What it does step by step:**
1. Called by Workflow 06 with a `course_id`
2. Fetches the complete course record from the knowledge base (courses + salaries + colleges + careers + faq + news — joined)
3. Checks that the course is verified and publishable (confidence score >= 0.7, review_status = 'approved')
4. Builds the platform list: `['instagram_reel', 'youtube_shorts', 'linkedin_post', 'facebook_post']`
5. Loops through each platform:
   - Fetches the currently active prompt template for that platform from `prompt_templates` table
   - Injects real course data into the template
   - Calls Gemini 2.5 Pro (replace OpenAI) to generate the content
   - For Instagram/YouTube: enforces a strict 5-beat 90-word script structure (Hook → Problem → Opportunity → Evidence → CTA)
   - If Reel script > 90 words: auto-trims proportionally
   - Saves to `content_items` table with status `draft`
   - If platform needs video (instagram_reel or youtube_shorts): calls Workflow 08 (HeyGen)
6. After all 4 platforms: calls Workflow 09 (Social Publisher)

**Why prompt templates in the database?** The AI Learning Engine (Workflow 11) improves these templates every week based on what content performed best. Storing them in the database means improvements take effect automatically without any code changes.

**Platforms used:** Google Gemini 2.5 Pro API, Supabase

---

### WORKFLOW 08 — HeyGen Video (Video Agent Mode)

**Purpose:** Turns the Reel/Shorts script into a real AI video using HeyGen.

**What it does step by step:**
1. Called by Workflow 07 with a `content_item_id`
2. Fetches the content item and full course data from Supabase
3. Fetches the active system prompt template and user prompt template from `prompt_templates`
4. Gets total video count (used for attire/background rotation)
5. Builds the Video Agent prompt:
   - Picks attire variant (cycles through: deep blue saree, burgundy blazer, teal saree, navy pantsuit)
   - Picks background variant (cycles through: bookshelf, gradient blue studio, green plant office, white modern studio)
   - Injects all course data into the user prompt template
6. Sends the combined prompt to HeyGen's Video Agent API → HeyGen generates the presenter, scenes, narration, everything from the prompt
7. Gets back a `video_id`, saves it to `video_assets` table with status `generating`
8. Waits 90 seconds then polls HeyGen for status
9. If completed: saves the video URL, marks `video_assets` as `ready`
10. If failed: marks as failed, calls error handler
11. If still processing: waits and checks again (loop up to ~10 times)

**HeyGen Mode used:** Video Agent (Mode 1) — NOT Custom Avatar (Mode 2). Reason: No pre-recorded avatar needed, presenter description in the prompt shapes the AI-generated presenter, zero manual setup. Cost: $2 per minute of video.

**Platforms used:** HeyGen API, Google Gemini 2.5 Pro (scene breakdown), Supabase

---

### WORKFLOW 09 — Social Publisher

**Purpose:** Publishes all 4 pieces of content to their respective social platforms.

**What it does step by step:**
1. Called by Workflow 07 after all content is generated
2. Fetches all draft `content_items` for this course plus their video status
3. Loops through each content item:
   - For video platforms (Instagram, YouTube): waits if video not ready yet, re-checks every 5 minutes
   - Calls Gemini to generate platform-specific metadata (hashtags for Instagram, professional tone for LinkedIn, etc.)
   - Routes to the correct publisher based on platform
4. **Instagram Reel:** Two-step process — upload video URL to Meta as media container, then publish the container
5. **Facebook Post:** POST to Facebook Graph API feed
6. **LinkedIn Post:** POST to LinkedIn UGC API with company page URN
7. **YouTube Shorts:** Upload video via YouTube Data API with title, description, tags
8. Records the external post ID in `publish_targets` table
9. Marks content items as `published`

**Platforms used:** Instagram Graph API, Facebook Graph API, LinkedIn UGC API, YouTube Data API v3, Supabase

---

### WORKFLOW 10 — Analytics

**Purpose:** Collects daily performance data for every published post.

**What it does step by step:**
1. Runs on its own cron at 9 PM IST every day (so published posts have time to accumulate engagement)
2. Also called by Master Scheduler on Mondays in `weekly` mode
3. Fetches all published posts from `publish_targets` within last 90 days
4. Loops through each post, routes to the right analytics API by platform:
   - Instagram/Facebook → Meta Graph API Insights (views, reach, likes, comments, shares, saves)
   - YouTube → YouTube Analytics API (views, watch time, retention, likes, comments)
   - LinkedIn → LinkedIn Organization Share Statistics (impressions, clicks, likes, comments)
5. Normalizes all the different metric field names into one consistent schema
6. Upserts into `analytics` table (one row per post per day — if run multiple times, updates)
7. If weekly mode: builds a summary of the past 7 days by platform and posts to Slack
8. If weekly mode: calls Workflow 11 (AI Learning Engine)

**Platforms used:** Meta Graph API, YouTube Analytics API, LinkedIn API, Supabase, Slack

---

### WORKFLOW 11 — AI Learning Engine

**Purpose:** The system's brain for self-improvement. Analyses what content worked and automatically improves the prompts.

**What it does step by step:**
1. Called by Workflow 10 after weekly analytics rollup
2. Builds 8 SQL queries, each measuring a different performance dimension:
   - `best_hook` — which hook texts got highest video completion rates?
   - `best_cta` — which CTAs drove most engagement?
   - `optimal_length` — which video lengths retained most viewers?
   - `top_course_category` — which course types get most reach?
   - `platform_best_time` — when do posts get most reach?
   - `emotion_driver` — which content emotions (hope/curiosity/urgency) work best?
   - `trending_format` — which format (reel vs post) wins this week?
   - `keyword_performance` — which keywords in captions drive most clicks?
3. For each dimension: runs the query, sends results to Gemini, asks "what pattern do you see?"
4. Saves every finding to `learning_insights` table
5. If confidence >= 0.7 (70%) AND the insight maps to a prompt template:
   - Fetches the current active template
   - Asks Gemini to rewrite the template incorporating the insight
   - Deactivates the old template version
   - Inserts new version with incremented version number
   - Sends Slack notification that a template was updated
6. From next run, Content Generation automatically uses the improved template

**This is what makes the system self-improving.** No human needs to manually tune prompts — the system learns from its own performance data.

**Platforms used:** Supabase, Google Gemini 2.5 Pro API, Slack

---

### WORKFLOW 12 — Quarterly Data Cleanup

**Purpose:** Database hygiene. Runs 4 times a year to keep the database fast and lean.

**What it does step by step:**
1. Called by Master Scheduler on Jan 1, Apr 1, Jul 1, Oct 1
2. All 4 cleanup operations run in parallel:
   - Hard-deletes rows that were soft-deleted more than 180 days ago (across 14 tables)
   - Deletes resolved dead_letter_queue entries older than 90 days
   - Deletes raw trend_history rows older than 1 year
   - Deletes workflow_run audit logs older than 1 year
3. Runs VACUUM ANALYZE on core tables (reclaims disk space, updates query planner statistics)
4. Posts Slack notification confirming cleanup completed

**Platforms used:** Supabase, Slack

---

## PLATFORM REFERENCE — EVERY SERVICE AND WHY

| Platform | Used In | What For | Cost |
|---|---|---|---|
| n8n (self-hosted) | All workflows | Automation engine | Free (Hetzner server cost) |
| Supabase | All workflows | Database — PostgreSQL + REST API + pgvector | Free tier |
| SerpAPI | Workflow 02 | Google Trends + Google News queries | 100 searches/month free |
| YouTube Data API v3 | Workflows 02, 09, 10 | Trend search, video upload, analytics | Free (10k units/day) |
| Google Gemini 2.5 Pro | Workflows 04, 06, 07, 08, 11 | Research, content generation, summaries, video prompts | Free tier (15 req/min) |
| Google text-embedding-004 | Workflow 06 | Vector embeddings for semantic search | Free tier |
| HeyGen API (Video Agent) | Workflow 08 | AI video generation | $2/min pay-as-you-go |
| Instagram Graph API | Workflows 09, 10 | Publish Reels, fetch analytics | Free |
| Facebook Graph API | Workflows 09, 10 | Publish posts, fetch analytics | Free |
| LinkedIn UGC API | Workflows 09, 10 | Publish company page posts, fetch analytics | Free (after app approval) |
| Slack API | Workflows 00, 05, 10, 11, 12 | Alerts, weekly summaries, notifications | Free |
| Gmail SMTP | Workflow 00 | Error email alerts | Free (500/day) |

**Removed platforms (do not add back):**
- Reddit — removed by client request
- Pinterest, Telegram, WhatsApp, X (Twitter), Blog/Newsletter — removed, not in scope
- ScraperAPI — removed entirely, modern education sites need JS rendering which costs 5 credits not 1
- LinkedIn Jobs API — client has posting OAuth credentials, not jobs search API
- OpenAI — no free tier, replaced with Gemini 2.5 Pro everywhere

---

## ERRORS ENCOUNTERED AND HOW EACH WAS FIXED

### ERROR 1 — Wrong node type for Supabase operations

**What happened:** Original JSON files use `n8n-nodes-base.postgres` with a PostgreSQL credential for all database operations.

**Problem:** We are using Supabase, not a raw PostgreSQL server. The n8n Supabase node (`n8n-nodes-base.supabase`) is simpler and works with Supabase's REST API directly — no direct database connection needed for most operations.

**Fix:**
- Simple INSERT → Supabase node, Create a row
- Simple SELECT (by ID or column) → Supabase node, Get a row
- Simple UPDATE (by column) → Supabase node, Update a row
- Complex SQL (JOINs, ON CONFLICT, increment operations, `now()`) → HTTP POST to Supabase RPC endpoint (`/rest/v1/rpc/function_name`)
- Credential: `content_factory` (Supabase type in n8n), using service_role key

---

### ERROR 2 — Mark Workflow Run Failed used workflow_name to find the row (ALL workflows)

**What happened:** The original `Mark Workflow Run Failed` SQL was:
```sql
WHERE workflow_name = 'Trend Discovery' AND status = 'running' ORDER BY started_at DESC LIMIT 1
```

**Problem:** If Trend Discovery ran yesterday and today, both rows have the same `workflow_name`. The wrong row gets updated. Also if two runs overlap, wrong row again.

**Fix:** Use `n8n_execution_id` to uniquely identify each run. Every workflow now:
1. Saves `n8n_execution_id = $execution.id` when logging run start
2. Updates `WHERE n8n_execution_id = $execution.id` when marking success or failure
3. Created Supabase RPC functions: `increment_retry_attempt(p_execution_id, p_error_message)` and `mark_workflow_failed(p_execution_id, p_error_message)` and `mark_workflow_success(p_execution_id)`

**Same bug existed in:** Workflow 00, 01, 02, 03, 04, 05, 06, 07, 08, 09, 10, 11, 12 — all had this pattern.

---

### ERROR 3 — executionId never passed to Workflow 00

**What happened:** Workflow 00 trigger accepted: `workflowName, nodeName, payload, errorMessage, retryCount` — no `executionId`.

**Problem:** Without the execution ID, the RPC functions that fix Error 2 cannot find the right row.

**Fix:** Added `executionId` as the 6th input to Workflow 00's trigger node. Every workflow that calls Workflow 00 must pass `executionId: "={{ $execution.id }}"`.

---

### ERROR 4 — Workflow 02 loop never completed (missing connection)

**What happened:** After inserting data into `trend_history`, there was no connection from that node to `Next Source`. The loop just died after the first source.

**Problem:** 12 out of 13 sources never got processed.

**Fix:** Added connection `trend_history [output 0] → Next Source`. Now the loop properly cycles through all sources. (Fixed in `02_Trend_Discovery_FIXED.json`)

---

### ERROR 5 — Call Source API sent success output to Error Handler

**What happened:** `Call Source API output 0` was connected to BOTH `Normalize to Common Shape` AND `Call Error Handler (Fetch Failed)`.

**Problem:** Every successful API call also triggered the error handler unnecessarily.

**Fix:** `output 0` (success) → Normalize only. `output 1` (error, via `onError: continueErrorOutput`) → Error Handler only.

---

### ERROR 6 — Google Trends returning 249 irrelevant items (Friendship Day, cricket, etc.)

**What happened:** Used `engine: google_trends_trending_now` which returns ALL trending searches in India regardless of topic. On Friendship Day it returned Friendship Day content.

**Problem:** 249 items inserted into trend_history, none related to education.

**Attempts made:**
- Added `category: '174'` (Education category in Google Trends) — did NOT work, API ignored it for `trending_now` engine
- Added keyword filter in Normalize code — worked partially but unreliable
- Tried `engine: google_trends` with `q: 'MBA,engineering,MBBS,BTech,MBBS,CA'` — failed, SerpAPI max 5 keywords
- Tried `category: '174'` with `trending_now` — confirmed non-functional

**Final fix:** Changed to `engine: google_trends`, `data_type: RELATED_QUERIES`, `q: 'courses after 12th'`. This returns what people search related to "courses after 12th" — directly relevant, clean data (25 items max), no junk.

---

### ERROR 7 — ScraperAPI 404 errors on all education sites

**What happened:** Tried to scrape Naukri, Shiksha, Careers360, CollegeDekho, NASSCOM, NSDC, Wikipedia with `render=false`.

**Problem:** All modern education sites are React/Angular apps — content loads via JavaScript. Without JS rendering, you get empty HTML or 404. Wikipedia specifically blocks ScraperAPI proxies.

**Attempts made:**
- Changed URLs to simpler pages — still failed
- Tried Wikipedia (static HTML) — blocked by ScraperAPI detection
- Considered `render=true` — costs 5 credits per request, too expensive on free tier

**Final fix:** Removed ScraperAPI entirely. No scraping. Use only free API sources. The 3 API sources (Google Trends RELATED_QUERIES, Google News, YouTube) are sufficient for MVP trend discovery.

---

### ERROR 8 — Query Parameters field in HTTP node accepting wrong format

**What happened:** Tried to pass `Object.entries($json.params).map(...)` into the JSON Query Parameters field in n8n's HTTP Request node.

**Problem:** n8n's HTTP node in this version doesn't accept a JavaScript expression returning an array in the "JSON Query Parameters" field — it expects static key-value pairs.

**Fix:** Build the complete URL with query string directly in the URL field:
```
={{ $json.url + '?' + Object.entries($json.params).map(([k,v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v)}`).join('&') }}
```
Turn off "Send Query Parameters" toggle entirely. Everything is in the URL.

---

### ERROR 9 — Scrape proxy URL built incorrectly

**What happened:** `proxyUrl` was set to `https://api.scraperapi.com/?api_key=KEY&render=false&url=` and then `target` was passed as a separate query parameter.

**Problem:** The target URL ended up double-encoded or in the wrong position in the final URL.

**Fix:** Concatenate directly in the URL field: `={{ $json.url + $json.params.target }}`. The `proxyUrl` already ends with `url=`, so appending the target gives the correct URL.

---

### ERROR 10 — Normalize producing too many rows, each inserted separately

**What happened:** Normalize returned 249 items from Google Trends. Each item went through Lookup source_id → Insert trend_history — creating 249 separate database rows.

**Problem:** Messy data, unnecessary database load, Workflow 03 aggregation queries becoming complex.

**Fix:** Changed architecture — Normalize still processes all items but returns ONE item per source with all courses packed in a JSONB array. After the loop finishes, a Combine All Courses node aggregates everything from all sources, deduplicates by course name (merging scores), and saves ONE row to trend_history per day.

**New trend_history schema:**
```
captured_date (DATE, UNIQUE)
total_courses (INT)
source_count (INT)
courses (JSONB) -- array of all course objects with merged scores
```

---

### ERROR 11 — API keys visible in workflow output / exposed in chat

**What happened:** API keys (SerpAPI, YouTube, ScraperAPI) were hardcoded in the Build Source Config List code node and appeared in n8n execution output which was pasted into chat multiple times.

**Problem:** Keys were exposed. All three keys need to be rotated.

**Fix:**
- Rotate SerpAPI key at serpapi.com → Dashboard → Regenerate
- Rotate YouTube API key at console.cloud.google.com → Credentials → delete old, create new
- Rotate ScraperAPI key at scraperapi.com → Dashboard → Regenerate
- Never paste n8n execution output into chat again — the params object includes the keys
- In the workflow JSON file for handover: keys are shown as `YOUR_SERPAPI_KEY` placeholder — fill in directly inside n8n

---

### ERROR 12 — n8n Variables not available in this version

**What happened:** Attempted to use `$vars.SERPAPI_KEY` to access keys set in n8n Settings → Variables.

**Problem:** This n8n instance/version either doesn't support Variables or they weren't available in this context.

**Fix:** Hardcode keys directly in the code node. Not ideal for security but acceptable for this self-hosted personal instance. For production hardening, use n8n's External Secrets feature (visible in the Settings menu) connected to a vault.

---

### ERROR 13 — HeyGen Video Agent ($2/min) vs Custom Avatar ($1/min) confusion

**What happened:** Original workflow (Workflow 08) was designed for Mode 2 (Custom Avatar) — requires a pre-recorded video of a person to create an avatar, then uses avatar_id per scene.

**Client situation:** No pre-recorded video of a presenter. No avatar set up in HeyGen.

**Decision made:** Switch to Mode 1 (Video Agent) — write a prompt describing the presenter and video, HeyGen AI generates everything. No manual setup needed. Trade-off: presenter looks slightly different each video (AI-generated, not consistent face). Acceptable for educational content channel.

**Fix:** Redesigned Workflow 08 completely:
- Removed `wardrobe_background_pool` table dependency
- Removed scene-by-scene breakdown via Gemini
- Added prompt template system (system prompt + user prompt stored in `prompt_templates` table)
- Attire/background rotation handled by code arrays (not database)
- Single prompt sent to HeyGen Video Agent endpoint

---

### ERROR 14 — LinkedIn Jobs API — client doesn't have it

**What happened:** Original Workflow 02 included LinkedIn Jobs API as a trend source.

**Problem:** Client has LinkedIn OAuth credentials for **posting** (LinkedIn UGC API), not for **job search** (LinkedIn Jobs Search API). These are completely different APIs requiring different permissions.

**Fix:** Removed LinkedIn Jobs from trend sources entirely. The LinkedIn posting credential (Client ID + Client Secret) is used only in Workflow 09 (Social Publisher) for posting content to the company page.

---

## DATA FLOW — HOW ALL 13 WORKFLOWS CONNECT

```
Every day 8:00 AM IST
         │
         ▼
01 Master Scheduler
         │
         ▼ (always)
02 Trend Discovery ──────────────────────────────────────┐
   [Google Trends + Google News + YouTube]               │
   Saves ONE row to trend_history (all courses in JSONB) │
         │                                               │
         ▼                                               │
03 Trend Ranking                                         │
   Scores + ranks → picks Top 10 courses                 │
         │                                               │
         ▼ (once per top course, 10 times)               │
04 Research Engine                                       │
   Gemini researches each course (5 prompt groups)       │
   Saves to research_raw                                 │
         │                                               │
         ▼                                               │
05 Fact Validation                                       │
   Cross-checks numeric facts                            │
   Saves verified data to course_facts                   │
   Flags low-confidence for human review → Slack         │
         │                                               │
         ▼                                               │
06 Knowledge Base Update                                 │
   Assembles complete course record                      │
   Generates AI summary + embedding                      │
   Updates courses table + satellites                    │
         │                                               │
         ▼                                               │
07 Content Generation                                    │
   Generates 4 pieces of content (one per platform)      │
   Saves to content_items as draft                       │
         │                                               │
         ▼ (for Instagram + YouTube only)                │
08 HeyGen Video                                          │
   Renders 60-second AI video                            │
   Video Agent mode — one prompt → full video            │
   Polls until complete → saves video_url                │
         │                                               │
         ▼                                               │
09 Social Publisher                                      │
   Posts to Instagram, YouTube, LinkedIn, Facebook       │
   Records external post IDs in publish_targets          │
         │                                               │
         │ (9 PM IST, daily)                             │
         ▼                                               │
10 Analytics                                             │
   Fetches metrics from all 4 platforms                  │
   Saves to analytics table                              │
         │ (Mondays only)                                │
         ▼                                               │
11 AI Learning Engine ───────────────────────────────────┘
   Analyses what content performed best
   Updates prompt_templates automatically
   (improvements apply to next day's content generation)

On Mondays → 01 also calls 10 (Analytics weekly rollup)
On 1st of month → 01 also calls 06 (refresh old facts)
Quarterly → 01 calls 12 (Data Cleanup)
On any failure → any workflow calls 00 (Error Handler)
```

---

## DATABASE TABLES REFERENCE

| Table | Written By | Read By | Purpose |
|---|---|---|---|
| `workflow_runs` | All workflows | 00, monitoring | Audit log of every workflow execution |
| `dead_letter_queue` | 00 | Manual review | Failed items that exhausted retries |
| `trend_history` | 02 | 03 | Today's course trend signals (one row per day) |
| `research_raw` | 04 | 05 | Raw AI research output per field per course |
| `courses` | 05 (creates), 06 (updates) | 07, 08, 09 | Master course table with all denormalized data |
| `course_facts` | 05 | 06 | Validated facts with confidence scores |
| `colleges` | 06 | 07 | Top colleges per course |
| `salaries` | 06 | 07 | Salary data per course |
| `careers` | 06 | 07 | Career paths per course |
| `faq` | 06 | 07 | FAQs per course (with embeddings) |
| `news` | 06 | 07 | Latest news per course |
| `audit_log` | 06 | Manual review | What changed in the KB and when |
| `prompt_templates` | 11 (updates), manual (creates) | 07, 08 | AI prompts for content + video generation |
| `content_items` | 07 | 08, 09 | Generated content drafts per platform |
| `video_assets` | 08 | 09 | HeyGen video render status and URL |
| `publish_targets` | 09 | 10 | Published post IDs per platform |
| `analytics` | 10 | 11 | Daily performance metrics per post |
| `learning_insights` | 11 | 11 | AI-generated performance insights |

---

## CREDENTIALS SUMMARY

| Credential Name in n8n | Type | Used In | Key Details |
|---|---|---|---|
| `content_factory` | Supabase | All DB nodes | service_role key from Supabase → Settings → API |
| `Slack - Career Factory` | Slack API | 00, 05, 10, 11, 12 | xoxb- bot token, needs chat:write scope |
| `Ops SMTP` | SMTP | 00 | Gmail app password, host: smtp.gmail.com, port: 587 |

**Hardcoded in code nodes (no credential system available):**
- SerpAPI key — in Build Source Config List (Workflow 02)
- YouTube API key — in Build Source Config List (Workflow 02)
- Gemini API key — in all Gemini HTTP nodes (Workflows 04, 06, 07, 08, 11)
- HeyGen API key — in HeyGen HTTP nodes (Workflow 08)
- Meta access token — in Instagram + Facebook publish nodes (Workflow 09)
- LinkedIn client credentials — in LinkedIn publish nodes (Workflow 09)

---

## ACTIVATION ORDER

**Import all 13 workflows first. Then activate in this order:**

1. Workflow 00 — activate first, always on
2. Workflows 02–12 — activate individually, test each manually
3. **Workflow 01 (Master Scheduler) — ACTIVATE LAST**

Workflow 01 is the trigger for everything. Activating it before others are ready means it fires into incomplete workflows.

---

## IMPORTANT NOTES FOR DEPLOYMENT

1. **Workflow 03** still has SQL that queries `trend_history` with the OLD schema (per-course rows with `normalized_name` column). With the new one-row-per-day JSONB schema, this query will fail. Workflow 03 needs to be updated to read from the `courses` JSONB array in the single daily row.

2. **VACUUM in Workflow 12** cannot run through Supabase REST API — it requires a direct Postgres connection. Either: use a direct Postgres credential for that specific node, or replace `VACUUM ANALYZE` with just `ANALYZE` (which can run via RPC).

3. **Workflow 05 fact validation** cross-checks against Naukri and AmbitionBox via scrape proxy — this violates their ToS and those sources are removed. For MVP, remove or simplify the numeric cross-checking step.

4. **pgvector extension** must be enabled in Supabase before creating the schema: `CREATE EXTENSION IF NOT EXISTS vector;`

5. **HeyGen prompt templates** must be manually inserted into `prompt_templates` table before Workflow 08 can run. See HANDOVER_Claude_Code.md for the full prompt text.

6. **LinkedIn posting** requires the LinkedIn Company Page app to go through LinkedIn's developer review process — this takes 1–5 business days after app creation.
