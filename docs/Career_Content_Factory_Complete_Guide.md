# Career Content Factory — Complete System Guide

**For:** Sugg.in / Prabhal Mohandas, and Devika NR (Qubitrix) — one reference doc, kept current.
**What this is:** the single source of truth for all 13 n8n workflows powering the automated career-content pipeline — from "what are Indian students searching for" to "a video is live on Instagram, YouTube, LinkedIn and Facebook." Plain-English purpose + exact node-by-node technical detail for every workflow, so you can study the system or hand it to the client to explain how it works. Updated 2026-08-06 with a full node-mapping audit + WF08 content-quality fixes — this replaces all earlier versions of this doc (there is only one guide now).

---

## How to read this document

Every workflow section has the same shape:

- **Purpose** — one paragraph, plain English, no jargon.
- **Triggered by** — what starts this workflow, and what data it needs.
- **Flow** — the node order, as arrows.
- **Node-by-node table** — for every node: what it does in plain English, the technical detail, and what to check first if it fails.
- **Common failure points** — the specific things most likely to break.

When something breaks: open **n8n → Executions**, find the failed run, click it, click the red node — the error is almost always self-explanatory once you know what that node was trying to do.

---

## The big picture

```
Every day, 8:00 AM IST
        │
        ▼
01 Master Scheduler
        │
        ├─ every ~5 days (queue empty or 5+ days since last batch) ──▶ 02 Trend Discovery
        │                                                                     │
        │                                                                     ▼
        │                                                            03 Trend Ranking
        │                                                          (search top 20, drop anything
        │                                                           covered in last 6mo,
        │                                                           queue up to 6 survivors
        │                                                           into content_queue)
        │
        ├─ every single day ──▶ pop 1 row off content_queue ──▶ 04 Research Engine
        │                       (mark it consumed)                     │
        │                                                               ▼
        │                                                        05 Fact Validation
        │                                                               │
        │                                                               ▼
        │                                                        06 Knowledge Base Update
        │                                                               │
        │                                                               ▼
        │                                                        07 Content Generation
        │                                                               │
        │                                                               ▼
        │                                                        08 HeyGen Video
        │                                                    (video prompt + all captions
        │                                                     + video render, 1/day)
        │                                                               │
        │                                                               ▼
        │                                                        09 Social Publisher
        │                                                    (posts to all 4 platforms,
        │                                                     WF08 calls this itself once
        │                                                     the video is truly ready)
        │
        │ (Mondays)
        ├──▶ 10 Analytics
        │ (1st of month)
        ├──▶ 06 Knowledge Base (monthly_refresh mode)
        │ (quarter start)
        └──▶ 12 Data Cleanup

10 Analytics (9 PM IST daily, or weekly on Mondays) ──▶ 11 AI Learning Engine
                                                              │
                                                              ▼
                                                   rewrites prompt_templates
                                                   (used by 08 next time)

00 Shared Error Handler — called by every workflow above when something fails
12 Quarterly Data Cleanup — runs 4x/year, deletes old soft-deleted rows
```

**Content pacing:** 1 video/day, not 10 — research runs every ~5 days and stocks a small candidate queue (`content_queue`), WF01 draws one course from it each day. A course already covered in the last 6 months is automatically skipped in favor of the next-best-ranked uncovered one.

**This is live, always:** the moment WF01's daily queue-pop fires, it's the real thing — WF08 spends real HeyGen credits (~$2/min) and WF09 posts live to your real social accounts. There is no sandbox mode.

---

## Credentials in use (n8n → Credentials)

| Name | Type | Used by |
|---|---|---|
| `content_factory` | Supabase | almost every workflow — all database reads/writes |
| `insta - sugg` | Facebook Graph API | WF09 Instagram publish + status check |
| `fb -sugg` | HTTP Header Auth | WF09 Facebook publish |
| `linkeidn - sugg` | HTTP Header Auth | WF09 LinkedIn upload + post |
| `YouTube account -sugg` | YouTube OAuth2 | WF09 YouTube upload + thumbnail |
| `Hey gen` | HTTP Header Auth | WF08 video generation + look generation + status polling |
| `SUGG` (id `BM52vHe9rRcBkQE4`) | Google PaLM API (googlePalmApi) | **every** AI/Gemini node across all 13 workflows — WF04/05 grounded research+validation, WF06 summaries, WF08 AI Agent, WF09 thumbnail image, WF11 AI Agents |
| `Slack account` | Slack API | WF00, WF05, WF10, WF11, WF12 alerts |
| `Gmail account` | Gmail OAuth2 | WF00 backup email alerts |

Base avatar: `avatar_id = b7b1f63f75ef48df8600a16fb639d47c` ("Sudeepa" avatar group, fixed face/identity). Logo asset_id `37a09f9dcf7245ffb27399ecedb0fb25`, QR asset_id `eae674e9c1c5468b9ca300e6a4e5b8ee`.

---

## Changes made in the 2026-08-06 session (audit + WF08 content-quality pass)

A full node-mapping audit was run across all 13 workflows — real execution history cross-checked against every `$json` / `$('Node')` reference (the specific bug pattern: `$json` silently resolving to the wrong upstream node after a branch/merge/multi-hop chain). One live bug found and fixed; the rest checked clean. Then a separate pass fixed WF08's video content quality end to end.

1. **WF00 `Mark Workflow Run Failed` — real live bug, fixed.** Read `{{ $json.errorMessage }}`, but its immediate predecessor `Insert into Dead Letter Queue` (a Supabase insert) returns an empty body `{}` — `errorMessage` actually lives 2 hops back, on `Classify Error`. Every failure this handler logged was sending Supabase an empty error message. Fixed to `{{ $('Classify Error').item.json.errorMessage }}`.
2. **Full audit, everything else checked clean:** WF01, WF03, WF07, WF09 — no issues. WF04/WF05's fallback nodes reading `$json.prompt` off the primary node looked suspicious on paper but are correct by design (n8n's error-output branch preserves the original input item). WF02's `Normalize to Common Shape` merges two branches but uses `$input.first().json` + a named ref, immune to the bug pattern by construction. WF10's platform-metrics merge node is safe because the routing switch guarantees only one branch is ever active per execution. **Gaps that remain unverified live:** WF10 has never had a fully successful execution; WF11 and WF12 have never executed at all (no live run to check); WF02's newest code (post-rebuild) has only ever run partially.
3. **WF06 `Insert news` — date bug, fixed.** AI-researched `published_at` values like `"August 2026"` aren't valid Postgres `timestamptz` input (`22007` error). Added a `normalizeDate()` helper (`new Date(s).toISOString()`, `null` if unparseable) before insert.
4. **Manually inserted 3 backfilled `news` rows for course_id=1** that failed to insert before the fix above (same normalization applied by hand).
5. **WF08 content-quality root-cause fix — the AI Agent was only ever seeing about half the researched facts.** `Fetch Course`'s query never joined `faq`/`news` at all, and `Flatten Course` silently dropped `emerging_trends`, `abroad_opportunities`, `scholarships`, and all **private** colleges (only pulled `government` type) even though they were sitting right there on the `courses` row. This is the real reason video scripts felt generic/thin despite rich underlying research. Fixed:
   - `Fetch Course` query now joins `,faq(*),news(*)` too.
   - `Flatten Course` now genuinely extracts all 19 fields (previous session's doc claimed this was done — audit found it wasn't actually live; it is now): adds `private_colleges_top3`, `scholarships`, `abroad_opportunities`, `emerging_trends`, `faq_summary` (top 2 Q&A), `latest_news_summary` (most recent headline).
   - `Build Agent User Message` now surfaces all 19 fields as labeled lines instead of the previous 13.
6. **`heygen_video_agent_system` prompt template, v6 → v10** (id=13, active; v6 through v9 deactivated, never deleted):
   - **v7:** Beat 5 now explicitly told to weave in one specific named fact (a real college/scholarship/trend) when word budget allows, rather than leaving the new fields unused; added a rule prioritizing concrete/named facts over generic statements.
   - **v8:** Beat 2 made mandatory to state course **duration and eligibility** (not just description) — these were being silently dropped under word pressure; word budget loosened 100-115 → 115-135, duration cap raised 50s → 55s to make room.
   - **v9:** duration cap and word budget reverted back down (50s max, 115-125 words) per explicit instruction to keep videos at 50 seconds; facts-only rule hardened — "do not pad the script with generic filler sentences... every sentence must carry a specific fact."
   - **v10:** added a mandatory camera-framing instruction — medium shot, head/shoulders/chest/hands all visible, subject centered, explicitly "not a tight close-up crop on the face" — the generated video was coming out zoomed in tight on the face like a passport photo; now framed like a natural presenter/interview shot.
7. **WF08 AI Agent's two Gemini language-model nodes were pointed at invalid model names** (`gemini-3.5-flash` and `gemini-3.6-flash` — neither exists). Fixed to `gemini-3-flash-preview` (primary) / `gemini-3-pro-preview` (fallback) — both 3-series per explicit instruction, fallback intentionally the heavier tier so a fallback is never a downgrade.
8. **`Generate Daily Look` avatar-look prompt hit HeyGen's 1000-character hard limit** (`invalid_parameter`, "String should have at most 1000 characters") — the client's verbatim wardrobe/continuity text ran long. Condensed to ~994-996 characters across two passes (first pass, then a second pass incorporating the client's fuller original wording and dropping a "Gen Z" reference per instruction), keeping every rule intact: face-identity lock, brand-new saree color/design/fabric/border/drape each run (AI still picks the color itself, no hardcoded palette), new background each run, no-repeat continuity, no bridal styling/excess jewelry/artificial smoothing.
9. **Cleanup:** deleted the stale `queued` `video_assets` row for course_id=1 that was created by the failed run above (never got a real `heygen_video_id`, no `content_items`/`publish_targets` existed for it yet — nothing else needed clearing). `courses`/`course_facts`/`colleges`/`careers`/`faq`/`news` for course_id=1 were confirmed correct and were **not** touched — no need to re-run WF04/05/06 research, only WF08 needs a fresh run to pick up all the fixes above.

---

## The 13 workflows

| # | Name | id | Purpose |
|---|---|---|---|
| 00 | Shared_Error_Handler_Sub-Workflow | `D46SUmWUtLZnTbYp` | Called by every workflow on failure — classifies error, logs to dead_letter_queue, notifies Slack/Gmail |
| 01 | Master_Scheduler | `SiM3RxeLXGCCLqOd` | Daily trigger. Checks if queue needs refilling (research cycle), pops 1 course/day off content_queue |
| 02 | Trend_Discovery | `Hf6w5kimZQzAlOk9` | Scrapes Google Trends/News/YouTube/Careers360 for trending **graduate courses only** |
| 03 | Trend_Ranking | `kdl8dTYU63sqANwh` | Scores + ranks trends, picks top 20, filters out courses covered in last 180 days, queues up to 6 into content_queue |
| 04 | Research_Engine | `a9d2q6NZD4ihu3IW` | AI-researches one course's facts (salary, colleges, exams, eligibility, etc), real Google Search-grounded Gemini call with fallback |
| 05 | Fact_Validation | `R36zNJvuMpxVOoAr` | Independent, also grounded Gemini re-verification pass, scores confidence per field |
| 06 | Knowledge_Base_Update | `39qWGhrL0qYt3L2F` | Writes verified facts to courses/colleges/salaries/faq/news/**careers**/audit_log tables |
| 07 | Content_Generation | `wO7e9zHZiOWLOSJV` | Slim orchestrator — fetch KB, check it's publishable, call WF08 |
| 08 | HeyGen_Video | `a5pMOiPBAYteh45Q` | Generates daily avatar look (AI picks new saree color/design/draping/background itself), generates video prompt + all captions + thumbnail prompt in one AI call, submits to HeyGen, polls, writes video_assets + content_items, then calls WF09 itself |
| 09 | Social_Publisher | `fax6LABh67qyY4u7` | Publishes to Instagram/YouTube/LinkedIn/Facebook, captures real `external_post_id` per platform, generates YouTube thumbnail |
| 10 | Analytics | `Ujbp9WT77pWMi3tH` | Pulls engagement metrics per platform using `external_post_id`, writes to analytics table |
| 11 | AI_Learning_Engine | `VKGVHp8eMKJLBfAW` | Analyzes analytics for patterns, AI-rewrites prompt_templates based on findings |
| 12 | Quarterly_Data_Cleanup | `2GLWTZrjXUl60HWI` | Purges old soft-deleted rows, prunes trend_history >1yr |

---

## Database schema — every table explained

> **Fresh-restart note:** all pipeline tables were truncated (`RESTART IDENTITY CASCADE`) this session, except `prompt_templates` (config, never truncate). Every id restarts at 1 — any old pinned/demo data referencing prior ids is stale.

### `workflow_runs` — the master audit log
Every workflow writes a row here on start, updates it on finish. Query this instead of opening n8n to check "did today's run happen."

| Column | Meaning |
|---|---|
| `workflow_name` | which of the 13 workflows |
| `n8n_execution_id` | join key — not `workflow_name` (two overlapping runs would collide on name) |
| `status` | `running`, `success`, `dead_letter`, `failed` |
| `items_processed` / `items_failed` | counters |
| `error_summary` | last error, if any |
| `started_at` / `finished_at` | a row stuck at `running` forever means the completion step never fired |

### `dead_letter_queue` — the failed-items inbox
Where WF00 saves the full failed payload when it gives up.

| Column | Meaning |
|---|---|
| `workflow_name` / `node_name` | which workflow, which node failed |
| `payload` | full data being processed at failure time |
| `error_message` | why |
| `retry_count` | retries before giving up |
| `resolved` / `resolved_at` | mark `true` manually once fixed — WF12 purges resolved rows >90 days |

### `content_queue` — the "what to cover next" pool
WF03 fills it (up to 6 rows) roughly every 5 days; WF01 drains one row per day.

| Column | Meaning |
|---|---|
| `course_name` / `normalized_name` | which course |
| `trend_score` / `rank_position` | carried from that day's ranking |
| `queued_at` | WF01 checks the newest of these to decide if a new research cycle is due |
| `consumed` / `consumed_at` | flipped `true` by WF01 the moment it's picked — dedup guard within the queue, separate from the 180-day dedup against `courses` |

### `trend_history` — one row per day of market research
WF02 writes exactly one row/day. All sources combined + deduplicated into a single JSONB array — one row per **day**, not per course.

| Column | Meaning |
|---|---|
| `captured_date` | unique, one row per day |
| `total_courses` / `source_count` | how many found, how many sources contributed |
| `courses` | JSONB array — `course_name`, `normalized_name`, `search_volume`, `hiring_demand`, `discussion_count`, `mentions`, `popularity_score`, then after WF03: `trend_score` + `rank_position` |

### `research_raw` — everything Gemini found, unfiltered
WF04's raw output before validation. One row per course per WF04 run — all ~20 researched facts packed into one `fields` JSONB array.

| Column | Meaning |
|---|---|
| `course_name` | which course |
| `n8n_execution_id` | which WF04 run |
| `fields` | JSONB array — `{field_key, field_value, model_used, source_urls}` per fact |

Old rows are never deleted — WF05 always reads `order=created_at.desc&limit=1`, so history accumulating here is harmless (just a storage-cost thing to watch — this table isn't in WF12's cleanup list).

### `course_facts` — the validated, trustworthy version
WF05's output, after independent re-verification with a confidence score. WF06 trusts this table when assembling the final course record.

| Column | Meaning |
|---|---|
| `course_id` | links to `courses.id` |
| `fact_key` / `fact_value` / `fact_value_numeric` | the fact and value |
| `confidence_score` | 0–1, agreement between original research and re-verification |
| `source_count` / `agreement_pct` | how many sources checked / agreed |
| `review_status` | `pending`, `verified`, `flagged`, `rejected` |
| `source_urls` | citations |
| `last_verified_at` | WF06's monthly refresh looks for rows >90 days old here |
| `deleted_at` | soft-delete marker |

### `courses` — the master course record
Single source of truth once a course is fully processed. What WF07/08 actually read from.

| Column | Meaning |
|---|---|
| `id` | **this is `course_id`** — used everywhere downstream |
| `name` / `slug` | display name, URL-safe id |
| `description`, `eligibility`, `duration`, `entrance_exams`, `emerging_trends`, `future_scope`, `career_path`, `abroad_opportunities`, `scholarships`, `industry_demand` | denormalized researched facts |
| `ai_summary` | Gemini-written human-readable summary |
| `embedding` | 768-dim vector (`text-embedding-004`) for future semantic search |
| `confidence_score` | overall trust score — **must be ≥ 0.7 to generate content** |
| `review_status` | must be `verified` for WF07/WF08 to proceed |
| `last_verified_at` / `deleted_at` | refresh tracking / soft-delete |

### `salaries`, `colleges`, `careers`, `faq`, `news` — the satellite tables
One-to-many via `course_id`.

- **`salaries`** — one row per course: `average_salary`, `highest_salary`, `placement_percent`, own `confidence_score`.
- **`colleges`** — several rows: `name`, `type` (`government`/`private`), `city`, `fees_annual`. Soft-deleted and reinserted each refresh.
- **`careers`** — several rows: `id, course_id, role (text), description (text), deleted_at, created_at`. WF08's `Flatten Course` pulls `role` values into `recruiters_top5`. **This table was never written to until this session** — see WF06 section below.
- **`faq`** — `question`, `answer`, `category`, own `embedding`.
- **`news`** — `headline`, `summary`, `url`, `published_at`.

All four use soft-delete-then-reinsert (`deleted_at` set, not hard-deleted).

### `audit_log` — what changed, when
One row per WF06 update describing the change: `table_name`, `record_id`, `action`, `changed_by`, `diff`.

### `prompt_templates` — the editable brain
Edit this directly in Supabase to change *how* content/video generation works, zero workflow edits needed.

| Column | Meaning |
|---|---|
| `template_key` | e.g. `heygen_video_agent_system` (WF08's video-direction instructions) |
| `version` | incrementing — old versions never deleted, only deactivated |
| `template_body` | the instruction text |
| `is_active` | only one version per `template_key` active at once — **deactivate by `template_key + is_active` filter, never a hardcoded row id** (ids aren't sequential-per-key) |
| `created_by` | `manual` or WF11's auto-rewrite tag |

`heygen_video_agent_system` is at **v10** (row id=13, active, as of 2026-08-06): 6-beat narrative structure, mandatory ≥2 B-roll-only beats (not every scene shows the avatar), minimal/limited hand-gesture instruction, **Beat 2 now mandatory for duration + eligibility** (not just description — was silently getting dropped under word pressure), course-name sanity rephrasing, ~115-125 word dialogue target for a 45-50s video (max, not "close to 55s" — that was tried at v8 and reverted), **mandatory medium-shot camera framing** (head/shoulders/chest/hands visible, subject centered — not a tight face close-up), a rule to prioritize named/concrete facts (real college, scholarship, recruiter names) over generic filler, graceful-skip rule for missing data, closing-scene logo/QR branding instructions. v1-v9 kept, deactivated, for history — see the 2026-08-06 changelog above for what changed at each version.

### `content_items` — the drafted social posts
WF08's output (moved here from WF07 this session), one row per platform per course (4 rows: Reel, Shorts, LinkedIn post, Facebook post).

| Column | Meaning |
|---|---|
| `course_id` | which course |
| `platform` | `instagram_reel`, `youtube_shorts`, `linkedin_post`, `facebook_post` |
| `title`, `body`, `hashtags` | the caption content |
| `metadata` | platform-specific extras |
| `script_json` | for Reels/Shorts — structured beat script |
| `status` | `draft` → `published` (WF09 flips this) |
| `word_count` | used by the 90-word reel trim check |

### `video_assets` — the HeyGen render tracking table
WF08 creates one row per video, updates as render progresses.

| Column | Meaning |
|---|---|
| `course_id` | **this is what WF09 queries by** to find a ready video |
| `thumbnail_prompt` | AI Agent's generated YouTube thumbnail prompt, read by WF09 |
| `heygen_video_id` | HeyGen's own render id, used to poll |
| `video_url` / `duration_seconds` | final hosted video + length |
| `status` | `queued` → `generating` → `ready` or `failed` |
| `error_message` | why it failed, if it did |

### `publish_targets` — one row per actual published post
WF09 writes one row per post that goes live; WF10 reads this to know what to pull analytics for.

| Column | Meaning |
|---|---|
| `content_item_id` / `video_asset_id` | links back to what was posted |
| `platform` | which platform |
| `published_at` | when |
| `external_post_id` / `external_url` | **the platform's own post id/link** — fixed this session, see WF09 section, previously always null |
| `status` | `published` |

### `analytics` — daily performance numbers
WF10 writes one row per post per day (upserts if run twice).

Columns: `publish_target_id`, `metric_date`, `views`, `reach`, `watch_time_seconds`, `retention_pct`, `likes`, `comments`, `shares`, `saves`, `new_subscribers`, `new_followers`, `ctr_pct`, `completion_rate_pct`, `raw_payload`. Not every platform fills every column.

### `learning_insights` — every pattern WF11 has ever found
`insight_type`, `finding`, `supporting_data`, `confidence` (only ≥0.7 findings get applied to a live template), `applied` / `applied_at`.

---

## WF00 — Shared Error Handler

**Purpose:** the safety net. Every other workflow calls this when a node fails. Logs the failure permanently and alerts a human, every time.

**Triggered by:** another workflow via `Execute Workflow`. Receives exactly 6 fields: `workflowName`, `nodeName`, `payload`, `errorMessage`, `retryCount`, `executionId`.

**Flow:**
```
When Executed by Another Workflow
  → Classify Error (rate limit? timeout? 5xx? 401/403? bad data? — logged, not acted on)
  → Insert into Dead Letter Queue → Mark Workflow Run Failed
  → Notify Email → Notify Slack → Return Dead-Letter Signal
```

> Real retries for transient failures (rate limits, timeouts) are handled by n8n's native `retryOnFail` on every node, before WF00 is ever called. By the time WF00 sees an error, native retry is already exhausted — going straight to dead-letter + alert is correct, not a downgrade.

| Node | Plain English | Technical | If it breaks |
|---|---|---|---|
| When Executed by Another Workflow | Receives the error report | `executeWorkflowTrigger`, 6 named fields | Missing field arrives `undefined` — check caller's mapping |
| Classify Error | Buckets error into a category (audit trail) | Code node, pattern-matches 429/timeout/5xx/401/403/400 | — |
| Insert into Dead Letter Queue | Saves the failed item permanently | Supabase `dead_letter_queue`, full payload JSON-stringified | Nothing sets `resolved=true` automatically — manual |
| **Mark Workflow Run Failed** | Updates audit trail | HTTP POST → Supabase RPC `mark_workflow_failed`. **Fixed 2026-08-06:** `p_error_message` used to read `{{ $json.errorMessage }}`, but its immediate predecessor (`Insert into Dead Letter Queue`) returns an empty body, so this always sent an empty message. Now reads `{{ $('Classify Error').item.json.errorMessage }}` | Matches by `executionId`, not name |
| Notify Email / Notify Slack | Alerts a human | Gmail / Slack nodes | Check credential + channel id if nothing arrives |

---

## WF01 — Master Scheduler

**Purpose:** the alarm clock. Fires daily, decides what else runs today. This is where "1 video/day, no repeats" lives.

**Triggered by:** Cron, `0 30 2 * * *` (8:00 AM IST).

**Flow:**
```
Every Day 8:00 AM IST
  → Compute Date Flags (isMonday? isFirstOfMonth? isQuarterStart?)
  → Log Run Start, fans out to 6 branches:

      1) Mark Run Success (fires immediately off Log Run Start)

      2) RESEARCH-CYCLE GATE:
         Fetch Latest Queue Batch → Compute Needs Research Cycle
           → Needs New Research Cycle? (true if queue empty, or newest batch ≥5 days old)
                YES → Execute: Trend Discovery (WF02 → cascades into WF03)
                NO  → nothing

      3) DAILY QUEUE-POP:
         Fetch Next Queued Course → Queue Has Course?
                YES → Flatten Queue Pick → Mark Course Consumed
                      → Execute: Research Engine (Daily Pick) — WF04 for exactly ONE course,
                        cascades 04→05→06→07→08→09 → exactly 1 video that day
                NO  → Notify Slack: Queue Empty

      4) Is Monday? → Execute: Analytics (Weekly Rollup)
      5) Is 1st of Month? → Execute: Monthly Knowledge Refresh
      6) Is Quarter Start? → Execute: Quarterly Data Cleanup
```

| Node | Plain English | Technical | If it breaks |
|---|---|---|---|
| Compute Date Flags | Monday / 1st-of-month / quarter-start | Code node | — |
| Log Run Start | Creates audit row | Supabase insert `workflow_runs` | — |
| Fetch Latest Queue Batch | Most recent `content_queue` batch timestamp | Supabase GET, `order=queued_at.desc&limit=1` | — |
| **Compute Needs Research Cycle** | `true` if queue empty, or newest batch ≥5 days old | Code node — `$input.all().map(...)` pattern, correctly checks `daysSince >= 5` or no row at all | Fixed this session (was always `true` due to the single-row auto-split bug — see "Recurring bug class" below) |
| Execute: Trend Discovery | Fires WF02, fire-and-forget | Only fires every ~5 days now | — |
| Fetch Next Queued Course | Oldest unconsumed row | Supabase GET, `consumed=eq.false&order=queued_at.asc&limit=1` | If always empty, check WF03 is inserting into `content_queue` |
| Mark Course Consumed | Flags row so it's never picked again | Supabase PATCH | — |
| Execute: Research Engine (Daily Pick) | Fires WF04 for one course — produces the single daily video | `executeWorkflow`, explicit field mapping | — |
| Notify Slack: Queue Empty | No video ran today, queue ran dry | Slack | If frequent: 5-day cadence too slow, or too many hitting 180-day cooldown |

**Common failure points:** keep this workflow **inactive until every other workflow is manually tested** — activating early fires into a half-ready pipeline daily at 8 AM.

---

## WF02 — Trend Discovery

**Purpose:** market research. Asks sources what Indian students search for related to **trending graduate courses**, saves one clean summary row per day.

**Triggered by:** WF01, no input needed.

**Flow:**
```
When Called → Build Source Config List (3 API sources + careers360 scrape)
  → Loop Sources
      → Call Source API
          success → Normalize to Common Shape → Normalize OK? → Next Source
          error   → Error Handler → Next Source
  → Combine All Courses → Save to trend_history → Mark Run Complete
```

| Node | Plain English | Technical | If it breaks |
|---|---|---|---|
| Build Source Config List | Defines the sources | Code node — search queries are explicitly scoped to **"trending graduate courses"** only: `google_trends: "trending graduate courses after 12th India"`, `google_news: "trending graduate courses India 2026"`, `youtube: "trending graduate courses India career"`; `careers360` scrapes a fixed listing URL | If a source fails, check hardcoded API key hasn't expired |
| Loop Sources | One source at a time | SplitInBatches, size 1 | — |
| Call Source API | HTTP call to source | HTTP Request, `onError: continueErrorOutput` | Check response body — usually API quota/auth |
| **Normalize to Common Shape** | Converts 3 formats into `{course_name, search_volume, hiring_demand, discussion_count, mentions, popularity_score}` | Code node — `youtube` case now runs titles through `extractCoursesFromHTML()` (fixed this session, was pushing raw titles). Also has a **`looksLikeHeadline()` guard**: drops any candidate name matching a regex bank for exam-results/news-headline language (`lakh`, `crore`, `result(s)`, `today`, `apply now`, `admission open`, `registration`, `notification`, `exam date`, `scorecard`, `merit list`, `cutoff`, `declared`, `released`, `news`, `what after`, punctuation like `;?!`, bare years, etc.) | **This is the node to check first** if a course name ever looks like a news headline instead of a real course — this was the root cause of the invalid "BTech result today for 11.06 lakh; What after" course that made it through earlier |
| Normalize OK? | Routes genuine parse errors only — "0 results" is normal | IF node | — |
| Combine All Courses | Merges + dedupes by name after the loop | Code node | — |
| Save to trend_history | One row per day | Supabase insert, `captured_date` UNIQUE | Conflict = already ran today |

**Common failure points:** after any run, open `trend_history` and read a few `course_name` values — if any look like news headlines/clickbait, the headline filter or query targeting needs re-checking.

---

## WF03 — Trend Ranking

**Purpose:** turns raw signals into a ranked list, filters anything recently covered, queues up to 6 fresh candidates. Does not call the Research Engine directly — only fills the queue.

**Triggered by:** WF02, automatically. Only runs every ~5 days, gated by WF01's research-cycle check.

**Flow:**
```
When Called → Fetch Today's Trend Row → Compute Trend Score
  → Write trend_score + rank_position
  → Fetch Recently Covered Courses (verified in last 180 days)
  → Filter Uncovered + Pick Top 6
  → Insert into content_queue
```

| Node | Plain English | Technical | If it breaks |
|---|---|---|---|
| Compute Trend Score | Weighted score: 25% search volume + 25% hiring demand + 20% discussion + 15% news + 15% social, min-max normalized 0–100 | Code node, weights hardcoded (this n8n instance blocks `$env` access entirely — no environment-variable mechanism exists here; any config value must be hardcoded or read from a Supabase table) | — |
| Fetch Recently Covered Courses | Dedup blocklist | Supabase GET, `courses?select=name&last_verified_at=gte.{now-180days}` | 180-day window is hardcoded here |
| Filter Uncovered + Pick Top 6 | Searches top **20** (`SEARCH_POOL_SIZE=20`) for first 6 uncovered (`MIN_REQUIRED=6`), tags `shortfall_warning` if it can't find 6 | Code node | Check `shortfall_warning` field on inserted rows first if queue keeps coming up short |
| Insert into content_queue | Writes up to 6 rows | Supabase insert | If 0 items, every one of top 20 already covered |

---

## WF04 — Research Engine

**Purpose:** deep research on one course, with real grounded web search — not just the model's training knowledge.

**Triggered by:** WF01's daily pick, or WF06's monthly re-verify path. Needs `course_name`.

**Flow:**
```
When Called Per Course → Build Research Prompt
  → Research with Google Search (Primary)
      success → Merge Research Result
      error   → Research with Google Search (Fallback) → Merge Research Result
  → Parse Structured JSON → Parse OK?
      YES → Insert research_raw → Execute: Fact Validation
      NO  → Call Error Handler (Parse Failed)
```

**Rebuilt this session** — previously used an AI Agent node with no real search grounding.

| Node | Plain English | Technical | If it breaks |
|---|---|---|---|
| Build Research Prompt | Asks for ~20 fields about the course (description, colleges, salary, recruiters, FAQs, etc.), "use null if unverifiable, never invent" | Code node. `eligibility` field instruction strengthened this session: AI **must open** with the exact minimum qualification level using precise phrasing ("Must have passed 10th grade" / "12th grade (Science-PCM)" / "12th grade (Commerce)" / "Must hold a graduate degree" / etc.) before marks/entrance-exam detail | — |
| **Research with Google Search (Primary)** | Real Google Search-grounded research call | `@n8n/n8n-nodes-langchain.googleGemini` node (not the Agent node's chat sub-node), model `gemini-3-flash-preview`, `builtInTools.googleSearch: true`, credential `SUGG`, `onError: continueErrorOutput` | If this errors, routes automatically to Fallback |
| Research with Google Search (Fallback) | Same, cheaper model | Same node type, model `gemini-2.5-flash` | — |
| **Merge Research Result** | Extracts the actual JSON answer out of this node type's raw response shape | Code node — reads `candidates[0].content.parts[].text`, extracts the `{...}` JSON substring from the last text part (falls back to scanning all parts joined), outputs `{output: text}` so all downstream parsing code needed zero changes | — |
| Parse Structured JSON | Extracts every field into one row per field | Code node, unchanged, reads `resp.output` | If it throws, model returned malformed JSON — check raw response |
| Insert research_raw | One row per field per course | Supabase insert | — |

---

## WF05 — Fact Validation

**Purpose:** independently re-checks the researched facts with a second, separate grounded search pass before anything gets trusted.

**Triggered by:** WF04, needs `course_name`.

**Flow:**
```
When Called → Fetch research_raw for Course → Build Course Slug
  → Ensure courses Row Exists → Fetch course_id
  → Build Verification Prompt → Validate with Google Search (Primary)
      success → Merge Verification Result Raw
      error   → Validate with Google Search (Fallback) → Merge Verification Result Raw
  → Merge Verification Result → Compute Facts + Confidence → Upsert course_facts
  → Flagged for Review? YES → Notify Slack: Needs Human Review
  → Execute: Knowledge Base Update
```

**Rebuilt this session, same pattern as WF04** — kept as a fully separate/independent AI pass from WF04's research call, per explicit design choice (not merged into one call).

| Node | Plain English | Technical | If it breaks |
|---|---|---|---|
| Ensure courses Row Exists | Creates the course record if missing | Supabase upsert, ON CONFLICT DO NOTHING | — |
| Build Verification Prompt | Asks for independent re-confirmation with fresh search | Code node | — |
| **Validate with Google Search (Primary / Fallback)** | Real Google Search-grounded validation | Same `googleGemini` node pattern as WF04 — `gemini-3-flash-preview` primary, `gemini-2.5-flash` fallback, credential `SUGG` | — |
| **Merge Verification Result Raw** | Extracts text from `candidates[].content.parts[]`, outputs `{output: text}` | Code node, identical extraction logic to WF04's Merge Research Result | — |
| Merge Verification Result | Existing downstream node, unchanged — already reads `item.json.output` | Code node | — |
| Compute Facts + Confidence | Compares original vs re-verification, scores confidence per field | Code node | — |
| Upsert course_facts | Saves validated, confidence-scored version | Supabase upsert | — |
| Flagged for Review? | Confidence < 0.8 → Slack alert | IF node | — |
| Execute: Knowledge Base Update | Fires WF06 | — | — |

---

## WF06 — Knowledge Base Update

**Purpose:** assembles validated facts into one clean course record, writes an AI summary + embedding, syncs all satellite tables.

**Triggered by:** WF05 with `course_name` (normal path), or WF01 with `mode: "monthly_refresh"` (bulk re-verify, no `course_name` needed).

**Flow:**
```
When Called → Mode = monthly_refresh?
    YES → Find Facts > 90 Days Old → Extract Course Names
          → Execute: Research Engine (Re-verify), once per stale course
    NO  → Fetch course_id by Name
  → Fetch Verified course_facts → Build Denormalized Course Record
  → Has Verified Facts?
      YES → Build Summary Prompt → Gemini: AI Summary → Extract Summary Text
            → Generate Embedding → Upsert courses (Denormalized + Embedding)
            → Sync colleges → Upsert salaries → Sync FAQ → Insert news
            → Sync careers (Delete+Insert)  ← added this session
            → Write audit_log
            → Execute: Content Generation
```

| Node | Plain English | Technical | If it breaks |
|---|---|---|---|
| Execute: Research Engine (Re-verify) | Fires WF04 per stale course | `executeWorkflow`, explicitly maps `course_name` | — |
| Build Denormalized Course Record | Assembles everything into one object | Code node | — |
| Generate Embedding | Converts summary to 768-dim vector | HTTP Request → `text-embedding-004` | Requires `vector` extension enabled in Supabase |
| Sync colleges / Sync FAQ | Soft-delete old, insert fresh | Code + 2 HTTP Requests each | — |
| **Insert news** | Builds the news row array for `news` table | Code node. **Fixed 2026-08-06:** AI-researched `published_at` values like `"August 2026"` aren't valid `timestamptz` input (Postgres `22007` error). Now runs every date through `normalizeDate()` (`new Date(s).toISOString()`, `null` if unparseable) before insert | If a news insert 400s, check the raw `published_at` string the AI returned |
| **Sync careers (Delete+Insert)** | Writes recruiter names to the `careers` table | **New this session.** Code node builds rows from `rec.recruiters` (`{course_id, role: name, description: null}`), wired as a 6th parallel branch off `Upsert courses (Denormalized)` alongside colleges/salaries/FAQ/news → `Soft-Delete Old Careers` → `Insert careers` | Was the root cause of "no careers showing" — recruiters were researched by WF04 but this insert chain never existed until now |
| Write audit_log | Records what changed | Supabase insert | — |
| Execute: Content Generation | Fires WF07 with `course_id` | — | — |

---

## WF07 — Content Generation

**Purpose:** a slim orchestrator — checks the course is fully verified and publishable, then hands off to WF08 which now does all the actual generation work.

**Triggered by:** WF06, needs `course_id`.

**Flow:**
```
When Called (course_id) → Fetch Full KB Record → Check KB Record Exists
  → Execute: HeyGen Video (Once Per Course)
```

**Drastically simplified this session** — down to exactly 4 nodes. Previously had its own AI-Agent-per-platform caption loop (4 separate AI calls) and a premature call to Social Publisher; both removed.

| Node | Plain English | Technical | If it breaks |
|---|---|---|---|
| Fetch Full KB Record | Joins courses + salaries + colleges + careers + faq + news into one object | Supabase GET, nested selects | — |
| Check KB Record Exists | Gate — requires `review_status='verified'` and `confidence_score >= 0.7` | IF node | If content never generates, check this gate first — it's silent by design |
| Execute: HeyGen Video (Once Per Course) | Fires WF08, terminal node — no further connection in WF07 | `executeWorkflow` | WF08 itself now calls WF09 once the video is actually ready — this is deliberate, see WF08 below |

**Why the old design was wrong:** WF07 used to also call Social Publisher directly after this. But `executeWorkflow`'s return value is whatever a *terminal node in the callee* last output — and WF08's fast-completing `Insert content_items` branch (seconds) would return long before the actual video render+poll (minutes) finished, so the publisher was getting fired off stale, wrong, or premature data. Fixed by removing the call here entirely and relocating it inside WF08, off the true completion point (`Mark video_assets Ready`).

---

## WF08 — HeyGen Video

**Purpose:** the biggest node in the pipeline. Generates a fresh daily avatar look, writes the video prompt + all social captions + thumbnail prompt in one AI call, submits to HeyGen, polls until done, saves everything, then triggers publishing itself.

**Triggered by:** WF07, needs `course_id`.

**Flow:**
```
When Called → Fetch Course → Flatten Course
  → Fetch Active System Prompt Template → Build Agent User Message
  → AI Agent (writes video prompt + thumbnail prompt + all 4 captions)
  → Parse Agent Output → Payload OK?
      NO  → Call Error Handler (Payload Build Failed)
      YES → Insert video_assets (queued)  +  Insert content_items  (parallel)
            → Flatten video_assets Insert → Generate Daily Look
                (POST /v3/avatars, async)
                → GET Avatar Group Looks → Is Look Ready?
                    NO  → Wait Look 20s → loop back to GET
                    YES → Finalize Look ID
            → POST HeyGen /v3/video-agents
                success → Store heygen_video_id (generating)
                error   → Call Error Handler (Generate API Failed)
  → Wait 90s → GET HeyGen status → Switch on Status
      completed        → Mark video_assets Ready → Execute: Social Publisher
      failed            → Mark video_assets Failed → Call Error Handler (Render Failed)
      still processing  → Wait Again → loop (capped at 10 polls)
      timeout           → Call Error Handler (Render Failed)
```

| Node | Plain English | Technical | If it breaks |
|---|---|---|---|
| Fetch Course | Pulls course + salaries + colleges + careers + faq + news | Supabase GET, `?select=*,salaries(*),colleges(*),careers(*),faq(*),news(*)&review_status=eq.verified`. **`faq(*),news(*)` genuinely added 2026-08-06** — a prior session's doc claimed this was already done, but live audit found the query never actually had them; content was silently missing until now | If empty, course isn't marked verified yet |
| **Flatten Course** | Extracts 19 fields into flat structure for the AI | Code node. **Fixed 2026-08-06** (same story as above — previously documented as done, audit found it wasn't live): now genuinely extracts all 19 fields, including `emerging_trends`, `abroad_opportunities`, `scholarships`, `private_colleges_top3` (was only pulling `government`-type colleges), `faq_summary` (top 2 Q&A), `latest_news_summary` (most recent headline) | — |
| Fetch Active System Prompt Template | Gets the editable video-direction instructions | Supabase GET, `template_key = heygen_video_agent_system` | **Edit this row in Supabase to change how videos are directed** — no workflow edit needed |
| **Build Agent User Message** | Formats all 19 course fields as a structured text block for the agent | Code node — fixed prior session (was reading `$json` from the wrong upstream node). **2026-08-06:** now surfaces all 19 fields as labeled lines (was only 13 — `private colleges`, `scholarships`, `abroad opportunities`, `emerging trends`, `FAQ context`, `latest news context` were being silently dropped even after `Flatten Course` extracted them) | If AI output ignores a fact, confirm it's actually a line in this node's output first |
| AI Agent | Writes video_prompt + youtube_thumbnail_prompt + instagram_reel + youtube_shorts + linkedin_post + facebook_post in one JSON response | LangChain Agent, `systemMessage: ={{ $('Fetch Active System Prompt Template').item.json.template_body }}`, credential `SUGG`. Language model pair: `gemini-3-flash-preview` primary / `gemini-3-pro-preview` fallback (**fixed 2026-08-06** — was pointed at `gemini-3.5-flash`/`gemini-3.6-flash`, neither of which exist) | If output looks generic, check the system prompt in Supabase first, then the course data feeding in |
| Parse Agent Output | Parses the JSON, builds `content_rows` (4 platform rows, 90-word reel trim, word counts) | Code node | — |
| Payload OK? | Sanity check — video prompt >200 chars | IF node | — |
| Insert video_assets (queued) | Tracking row incl. thumbnail prompt | Supabase insert | — |
| **Insert content_items** | Bulk insert, all 4 caption rows at once | New node this session, `jsonBody: {{ $json.content_rows }}`, wired parallel to `Insert video_assets` | Captions now come from here, not WF07 |
| **Generate Daily Look** | Creates a fresh HeyGen "look" off the fixed base avatar each run | `POST /v3/avatars`, async (`status: processing`). jsonBody prompt rewritten to the client's own detailed text: preserves facial identity exactly, requires a completely new saree design/fabric/blouse/border/drape every time, requires a brand-new studio/workplace background every time, explicit "no repeats" continuity rules against all previous avatars, realistic-photography quality directives. **HeyGen enforces a hard 1000-character limit on `prompt`** — the full client text overran it (`invalid_parameter` 400). Condensed to ~994-996 chars across two passes 2026-08-06 (second pass folded in the client's fuller original wording, dropped a "Gen Z" reference per instruction) while keeping every rule intact | Color is **not** code-driven — the AI is instructed to "pick a brand-new, sophisticated professional saree color for this look yourself, different from any color used in previous avatars." (An earlier version of this used a hardcoded 12-color rotation code node — removed per explicit instruction: "let it pick, no need to use code for choosing colours.") If this 400s again with a character-count error, the prompt needs trimming further — check length before adding text back |
| GET Avatar Group Looks | Polls the look's status | `GET /v3/avatars/looks/{look_id}` (URL confirmed correct by direct testing) | — |
| Is Look Ready? | `$json.data.status !== "processing"` | IF node | — |
| Wait Look 20s | Loops back to GET if not ready | Wait node | — |
| Finalize Look ID | Extracts the ready look's own id, with a safe fallback chain to the base avatar id | Code node | — |
| POST HeyGen /v3/video-agents | Sends the prompt + `avatar_id: <today's look id>` + logo/QR `files` attachments | HTTP Request. **Does not accept `aspect_ratio`** — HeyGen rejects it ("Extra inputs are not permitted"); 9:16 is prompt-text only | — |
| Wait 90s → GET status → loop | Polls every 90s, up to 10 times (~15 min ceiling) | Wait + HTTP + Switch | If timeout at 10 polls, check HeyGen's own dashboard |
| Mark video_assets Ready | Saves final `video_url` + duration | Supabase PATCH | — |
| **Execute: Social Publisher** | Fires WF09 once the video is genuinely ready | `executeWorkflowId: fax6LABh67qyY4u7`, `course_id` mapped from `Flatten Course`, wired off `Mark video_assets Ready` — the true completion point | Completed this session (was an unconfigured stub node the user had already dropped on the canvas) |

**Cost note:** every successful run spends real HeyGen credits.

---

## WF09 — Social Publisher

**Purpose:** publishes the 4 drafted captions + the video to Instagram, YouTube, LinkedIn, and Facebook, generates + uploads a custom YouTube thumbnail, and records what actually got published where.

**Triggered by:** WF08, needs `course_id`.

**Flow:**
```
When Called → Fetch Ready Video for Course → Video Ready?
    NO  → Call Error Handler (No Video)
    YES → Flatten Video → Fetch Draft content_items → Fan Out content_items
          → Loop Content Items → Route by Platform

  Instagram: Create Container → Get Status (loop until FINISHED) → Publish → Shape IG Publish Target
  Facebook:  direct POST with video_url → Shape FB Publish Target
  LinkedIn:  Register Upload + Download Video (parallel) → Merge → Upload Bytes
             → Build Post Body → Create Post → Shape LinkedIn Publish Target
  YouTube:   Download Video → Upload → Generate Thumbnail Image (Gemini)
             → Upload YouTube Thumbnail → Shape YouTube Publish Target

  (all 4 shape nodes converge) → Insert publish_targets → Mark content_items Published → Next Item
```

| Node | Plain English | Technical | If it breaks |
|---|---|---|---|
| **Flatten Video** | Pulls video row fields | Code node — fixed this session, `$input.all()` pattern | — |
| **Fan Out content_items** | Attaches video URL to each of the 4 drafts | Code node — fixed same bug class | — |
| Route by Platform | Sends each item down its own branch | Switch on `platform` | — |
| Publish: Instagram (Create/Status/Publish) | Reel media container flow, polls until `FINISHED` | Facebook Graph API nodes | Check container id + credential token if it never finishes |
| Publish: Facebook | Posts video directly by URL | HTTP Request | — |
| Publish: LinkedIn | Register upload → download bytes → upload → create UGC post | HTTP Request chain, org URN `urn:li:organization:134614074` | — |
| Publish: YouTube | Download bytes → upload → generate + set thumbnail | HTTP Request + YouTube node + Gemini image gen | — |
| **Shape IG / FB / LinkedIn / YouTube Publish Target** | **New this session** — extract the real platform-returned post id | 4 code nodes, one per platform, each reading that platform's actual response shape: IG/FB read `resp.id`; LinkedIn reads `resp.id` or falls back to the `x-restli-id` response header; YouTube reads from the **upload** response (`ytResp.id`/`uploadId`), not the thumbnail-upload response which never carried it | Fixes `external_post_id` always being `null` — see below |
| Insert publish_targets | Records `content_item_id, video_asset_id, platform, external_post_id, published_at, status` | Supabase insert, `jsonBody` now sources `external_post_id` from the shape nodes | Previously never referenced any post-id field at all — WF10 Analytics could never have worked without this fix |
| Mark content_items Published | Flips `draft` → `published` | Supabase update | — |

**Live note:** every successful run posts to your real accounts. No draft/preview mode.

---

## WF10 — Analytics

**Purpose:** pulls daily performance metrics for every published post; on Mondays, rolls up a weekly summary and kicks off the learning engine.

**Triggered by:** its own Cron (9 PM IST daily) or WF01 with `mode: "weekly"`.

**Flow:**
```
(cron or called) → Fetch Published publish_targets (last 90 days)
  → Loop Publish Targets → Route by Platform
      Instagram/Facebook → GET Meta Insights
      YouTube             → GET YouTube Analytics
      LinkedIn             → GET LinkedIn Analytics
  → Normalize Metrics to analytics Row → Upsert analytics (today) → Next Batch
  → Weekly Rollup Requested?
      YES → Fetch Weekly Raw Analytics → Build Weekly Summary
            → Slack: Weekly Performance Summary → Execute: AI Learning Engine
```

| Node | Plain English | Technical | If it breaks |
|---|---|---|---|
| GET Meta/YouTube/LinkedIn Analytics | Pulls views/reach/likes/etc per platform, keyed by `external_post_id` | HTTP Request per platform | LinkedIn analytics needs Marketing Developer Platform access (separate from posting access). **Depends on the WF09 `external_post_id` fix above** — without it this whole workflow was non-functional |
| Normalize Metrics to analytics Row | Maps different field names into one shape | Code node | — |
| **Build Weekly Summary** | Rolls up the week | Code node — fixed this session, `$input.all()` pattern (previously would crash once 2+ rows existed) | — |
| Execute: AI Learning Engine | Fires WF11 | — | — |

---

## WF11 — AI Learning Engine

**Purpose:** the self-improvement loop. Looks at what performed well, automatically rewrites the prompt templates WF08 uses.

**Triggered by:** WF10 in weekly mode.

**Flow:**
```
When Called → Fetch Combined Analytics Data → Compute 6 Insight Dimensions
  → Loop Dimensions
      → Build Finding Prompt → AI Agent: Synthesize Finding
      → Parse Finding → Insert learning_insights → Flatten Insight Insert
      → Confidence >= 0.7? → Maps to a Template?
          YES → Fetch Current Active Template → Build Rewrite Prompt
                → Has Current Template?
                    YES → AI Agent: Rewrite Template
                          → Deactivate Old Version → Insert New Template Version
                          → Mark learning_insight Applied → Slack: Prompt Template Updated
      → Next Dimension
```

| Node | Plain English | Technical | If it breaks |
|---|---|---|---|
| **Compute 6 Insight Dimensions** | Builds 6 questions: best hooks, best CTAs, optimal length, top categories, best posting time, best format | Code node — fixed this session, `$input.all()` pattern | — |
| **Build Rewrite Prompt** | Builds the prompt asking Gemini to rewrite a template | Code node — **fixed this session**: the self-learning rewrite loop was silently **never firing** because its `Array.isArray()` guard on a `limit=1` query result was always `false` (n8n delivers a plain object for single-row results, not an array). Now correctly reads `rows[0]` via `$input.all()` | This was a real, previously undetected dead loop — the pipeline was never actually learning from performance data until this fix |
| Deactivate Old Version → Insert New Template Version | Old row's `is_active=false`, new versioned row inserted active | 2 Supabase writes | This is how prompt history is preserved — nothing overwritten, only versioned |

---

## WF12 — Quarterly Data Cleanup

**Purpose:** database hygiene, 4x/year — deletes old soft-deleted rows and stale logs.

**Triggered by:** WF01 on Jan/Apr/Jul/Oct 1st.

**Flow:**
```
When Called (Quarterly) → Build Soft-Delete Table List (11 tables)
  → Loop Tables → Purge Soft-Deleted Rows > 180 Days → Next Table
  (in parallel) → Purge Resolved DLQ > 90 Days
  (in parallel) → Purge trend_history > 1 Year
  (in parallel) → Purge workflow_runs > 1 Year
  → Run ANALYZE Core Tables → Slack: Cleanup Complete
```

Audited this session — no bugs found, no changes made.

---

## Recurring bug class found and fixed (the single most important thing to understand about this codebase)

**This n8n instance auto-splits any top-level JSON array HTTP response into separate n8n items** — one item per array element — rather than delivering one item whose `.json` is the whole array. Any code assuming `$input.first().json` is itself an array (`rows[0]`, `.map()`, `Array.isArray()` checks) breaks silently or throws, because a single-row Supabase query result arrives as a **plain object**, not a one-element array.

**Correct pattern:** `$input.all().map(i => i.json)` to safely collect all rows regardless of count; or, when exactly one row is expected, treat `$input.first().json` as the object directly — no `[0]` indexing.

**All instances found and fixed this session:**
1. WF01 `Compute Needs Research Cycle`
2. WF08 `Build Agent User Message` (also reading from the wrong upstream node entirely)
3. WF09 `Flatten Video`
4. WF09 `Fan Out content_items`
5. WF10 `Build Weekly Summary`
6. WF11 `Compute 6 Insight Dimensions`
7. WF11 `Build Rewrite Prompt` (the self-learning loop was silently never firing because of this)
8. WF02 `Normalize to Common Shape` — related bug: YouTube titles pushed raw instead of extracted via `extractCoursesFromHTML()`

**Checked and confirmed already safe:** WF00, WF03, WF12. **Rebuilt from scratch, not just patched:** WF04, WF05.

---

## Push-then-verify discipline

Never trust a bare `PUT` / `STATUS 200` alone from the n8n API — always re-fetch fresh via `GET` immediately after and confirm the change actually persisted. This instance has silently reverted pushed changes at least twice when the workflow was open in a browser tab and saved concurrently (e.g. HeyGen's `aspect_ratio` removal reverted once, `Build Agent User Message`'s fix reverted once). Every change documented in this guide was confirmed via a fresh re-fetch after pushing.

---

## Known open items / unresolved

1. **QR/logo overlay guarantee** — HeyGen's `files` attachment + prompt instruction is best-effort, not a pixel-guaranteed overlay. A real fix needs post-render compositing (Shotstack/Creatomate/FFmpeg) — vendor not yet chosen.
2. **WF02's `careers360` ScraperAPI source** — flagged as a cost/reliability tradeoff, never resolved (keep or remove).
3. **No full end-to-end live test** has completed successfully through all 13 workflows in sequence with every current fix in place simultaneously — individual workflows tested piecemeal.
4. **WF10 has never had a fully successful execution** — every run so far has errored or been canceled. Downstream nodes past the platform-metrics merge point have no live proof they work.
5. **WF11 and WF12 have never executed, ever** — zero execution history to audit against. Reviewed statically only; genuinely untested live.
6. **WF08's newest fixes (2026-08-06) have not yet run end-to-end** — the richer `Fetch Course`/`Flatten Course`/`Build Agent User Message` data, the v10 system prompt, the corrected Gemini models, and the trimmed avatar-look prompt have each been verified individually via fresh re-fetch, but not yet exercised together in one live WF08 run. Next manual run of WF08 for course_id=1 is the real test.

---

## Debugging playbook

1. **Something failed** → n8n → Executions → filter by workflow → open the red run → click the red node → read the error.
2. **A workflow "did nothing"** → check the IF/Switch node just before the dead end — most silent stops are intentional gates (unverified course, video not ready, low confidence), not bugs.
3. **Data looks wrong in Supabase** → trace backwards: which workflow writes that table, which node builds the value, what did its *input* look like in the execution that produced the bad row.
4. **A sub-workflow call seems to receive the wrong data** → open the caller's `Execute Workflow` node, check the `workflowInputs` mapping against what the target's trigger node actually uses.
5. **Retries aren't happening** → every real work-node has `retryOnFail: true` — check the execution log for "Retry attempt N."
6. **Nothing downstream can find a referenced node's data** → look for `alwaysOutputData: true` on nodes referenced elsewhere via `$('Node Name')` — if that node was skipped or returned zero items, this flag stops the reference from silently breaking.
7. **A single-row/array Code node looks wrong** → first suspect is always the auto-split bug class above — check for `$input.all()` vs `$input.first().json[0]`.
