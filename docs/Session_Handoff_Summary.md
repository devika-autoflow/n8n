# Career Content Factory — Session Handoff Summary

**Purpose of this file:** paste/upload this into a new chat so Claude has full context without re-deriving everything. Written 2026-08-05, updated same day (later pass) with all changes made this session.

---

## Project

Client: Sugg.in (Prabhal Mohandas). A 13-workflow n8n pipeline that researches Indian career/education courses, verifies facts with AI (grounded Google Search), generates a HeyGen presenter video + social captions, and auto-publishes to Instagram/YouTube/LinkedIn/Facebook. 1 video/day (cost-controlled).

## Instance & credentials

- n8n: `https://n8n.srv1757918.hstgr.cloud`, API key in prior messages / n8n Settings → API.
- Supabase project: `fxhrigzjvpmjvbblbqqr`, service_role key needed for direct table access (not the anon key).
- Gemini credential for ALL AI nodes in this project: **`SUGG`** (id `BM52vHe9rRcBkQE4`, type `googlePalmApi`) — swapped in across every AI node in all 13 workflows.
- HeyGen credential: `Hey gen` (httpHeaderAuth).
- Base avatar: `avatar_id = b7b1f63f75ef48df8600a16fb639d47c` ("Sudeepa" avatar group). Logo asset_id `37a09f9dcf7245ffb27399ecedb0fb25`, QR asset_id `eae674e9c1c5468b9ca300e6a4e5b8ee`.

## The 13 workflows (all in n8n project "Prabhal Mohandas")

| # | Name | id | Purpose |
|---|---|---|---|
| 00 | Shared_Error_Handler_Sub-Workflow | D46SUmWUtLZnTbYp | Called by every workflow on failure — classifies error, logs to dead_letter_queue, notifies Slack/Gmail |
| 01 | Master_Scheduler | SiM3RxeLXGCCLqOd | Daily trigger. Checks if queue needs refilling (research cycle: last queued_at ≥5 days old, or no row), pops 1 course/day off content_queue |
| 02 | Trend_Discovery | Hf6w5kimZQzAlOk9 | Scrapes Google Trends/News/YouTube/Careers360 for trending **graduate course** names. Filters out exam-results/headline noise |
| 03 | Trend_Ranking | kdl8dTYU63sqANwh | Scores + ranks trends, picks top 20, filters out courses covered in last 180 days, queues up to 6 into content_queue |
| 04 | Research_Engine | a9d2q6NZD4ihu3IW | AI-researches one course's facts (salary, colleges, exams, eligibility, etc), **real Google Search-grounded Gemini node** with fallback |
| 05 | Fact_Validation | R36zNJvuMpxVOoAr | Independent AI fact-check pass on research_engine output, **also real Google Search-grounded Gemini node** with fallback, scores confidence per field |
| 06 | Knowledge_Base_Update | 39qWGhrL0qYt3L2F | Writes verified facts to courses/colleges/salaries/faq/news/**careers**/audit_log tables |
| 07 | Content_Generation | wO7e9zHZiOWLOSJV | Slim orchestrator: fetch KB → check exists → call WF08 (terminal, no publish call — WF08 triggers WF09 itself once video is truly ready) |
| 08 | HeyGen_Video | a5pMOiPBAYteh45Q | Generates daily avatar "look" (AI picks new saree design/color/draping/background itself each run, same face preserved), generates video prompt + ALL social captions + thumbnail prompt in one AI call, submits to HeyGen, polls for completion, writes video_assets + content_items, then calls WF09 |
| 09 | Social_Publisher | fax6LABh67qyY4u7 | Reads ready video + draft captions from Supabase, publishes to Instagram/YouTube/LinkedIn/Facebook, captures real `external_post_id` per platform, generates YouTube thumbnail |
| 10 | Analytics | Ujbp9WT77pWMi3tH | Pulls engagement metrics per platform (using `external_post_id`), writes to analytics table |
| 11 | AI_Learning_Engine | VKGVHp8eMKJLBfAW | Analyzes analytics for patterns (best hook/CTA/duration/etc), AI-rewrites prompt_templates based on findings |
| 12 | Quarterly_Data_Cleanup | 2GLWTZrjXUl60HWI | Purges old soft-deleted rows, prunes trend_history >1yr |

## All changes made this session (chronological)

1. **Fixed `trend_history` duplicate-key error** — explained full-reset TRUNCATE approach, user ran it (all tables except `prompt_templates`).
2. **WF01 `Compute Needs Research Cycle`** — fixed single-row auto-split bug (`$input.all()` pattern), confirmed logic correctly checks "last queued_at ≥5 days old, or no row exists."
3. **Swapped every AI/Gemini credential** across all 13 workflows to new `SUGG` credential (id `BM52vHe9rRcBkQE4`).
4. **8-instance auto-split bug class fixed** across WF01/WF08/WF09(×2)/WF10/WF11(×2)/WF02 — see bug-class section below.
5. **WF06** — added missing `careers` table sync chain (`Sync careers (Delete+Insert)` → `Soft-Delete Old Careers` → `Insert careers`), wired parallel to colleges/salaries/faq/news branches. Recruiters were being researched but never written to DB — root cause of "no careers showing."
6. **WF07 simplified** — removed entire duplicate per-platform caption AI loop (WF08 now generates all captions in one call) and removed the premature `Execute: Social Publisher` call that was firing off WF08's fast-completing insert branch before video render finished. WF07 is now 4 nodes: `When Called` → `Fetch Full KB Record` → `Check KB Record Exists` → `Execute: HeyGen Video` (terminal).
7. **WF08 `Fetch Course` / `Flatten Course`** — enriched query to also pull `faq(*)`, `news(*)` relations; `Flatten Course` now extracts 19 fields (was 13) including `emerging_trends`, `abroad_opportunities`, `scholarships`, `private_colleges_top3`, `faq_summary`, `latest_news_summary`.
8. **WF08 `Build Agent User Message`** — fixed to read `$('Flatten Course').item.json` (was reading `$json`, which was actually a different upstream node's output at that point — root cause of "AI Agent giving vague output ignoring research data"). Now all 19 researched fields reach the AI Agent.
9. **WF08 `Insert content_items`** — added missing bulk-insert node (4 platform caption rows), wired parallel to `Insert video_assets (queued)`.
10. **WF08 `Execute: Social Publisher`** — completed the user's own half-configured stub node: `workflowId: fax6LABh67qyY4u7`, wired off `Mark video_assets Ready` (the true video-complete point, not WF07's premature trigger).
11. **WF08 prompt_templates `heygen_video_agent_system`** — rewritten through v6 (id=9, active): 6-beat narrative structure, mandatory ≥2 B-roll-only beats (not every scene shows avatar), minimal/limited hand-gesture instruction, eligibility clarity, course-name sanity rephrasing, ~100-115 word dialogue target.
12. **HeyGen `/v3/video-agents` body** — confirmed `aspect_ratio` param is rejected (`"Extra inputs are not permitted"`); removed permanently, 9:16 controlled via prompt text only.
13. **WF08 daily avatar-look system** — built `Generate Daily Look` (POST `/v3/avatars`) → `GET Avatar Group Looks` (polling, URL fixed by user to `/v3/avatars/looks/{id}`) → `Is Look Ready?` → `Finalize Look ID` → feeds into video-agents call. Loops via `Wait Look 20s` if not ready.
14. **WF04 + WF05 major rebuild** — replaced AI-Agent-node research/validation (no real search) with standalone `@n8n/n8n-nodes-langchain.googleGemini` nodes using `builtInTools.googleSearch: true` for real grounded search. Each has a Primary (`gemini-3-flash-preview`) + Fallback (`gemini-2.5-flash`) pair via `onError: continueErrorOutput`, converging into a `Merge Research/Verification Result` code node that robustly extracts text from `candidates[0].content.parts[]` and outputs `{output: text}` so existing downstream parsing code needed zero changes. Research and validation kept as two separate independent AI passes per user's explicit choice.
15. **WF04 `Build Research Prompt` — eligibility field** — strengthened schema instruction to force AI to state exact minimum qualification level upfront (10th / 12th-PCM / 12th-PCB / 12th-Commerce / 12th-any / graduate-any / graduate-relevant-field) before marks/entrance-exam details.
16. **WF02 — fixed root cause of invalid "BTech result today for 11.06 lakh; What after" course**: this was an exam-results news headline, not a real course, caused by regex-based course extraction with no semantic filter, worsened by an untargeted `google_news` search query. Fixed two ways:
    - `Normalize to Common Shape`: fixed `youtube` case to run titles through `extractCoursesFromHTML()` (was pushing raw titles as course names); added `looksLikeHeadline()` guard (regex bank catching "lakh/crore/result/today/apply now/admission open/exam date/scorecard/merit list/cutoff/declared/released/news/what after/how to" etc.) that drops any candidate matching headline patterns.
    - `Build Source Config List`: retargeted all 3 API-source search queries to explicitly say **"trending graduate courses"** (per user's explicit final instruction): `google_trends: "trending graduate courses after 12th India"`, `google_news: "trending graduate courses India 2026"`, `youtube: "trending graduate courses India career"`. (`careers360` unchanged — scrapes a fixed listing URL, not a query.)
17. **WF09 `external_post_id` fix** — root cause: `Insert publish_targets` never captured any platform-returned post id at all (always sent null). Added 4 platform-specific "Shape X Publish Target" code nodes (Instagram/Facebook/LinkedIn/YouTube), each extracting the real id from that platform's actual response shape (LinkedIn falls back to `x-restli-id` header; YouTube reads from the upload response, not the thumbnail response), converging into a rewritten `Insert publish_targets` jsonBody. This unblocks WF10 Analytics, which needs `external_post_id` to query platform APIs.
18. **WF09 `Flatten Video` / `Fan Out content_items`** — fixed same auto-split bug class.
19. **WF08 avatar look prompt — saree variety** — first pass added general "vary saree type" instruction. Second pass: replaced entire prompt with client's own detailed verbatim text (forwarded via WhatsApp) — face-identity preservation, Gen Z career-mentor framing, saree/draping/blouse/border/jewelry variety, new-background-every-time, realistic-photo quality directives, explicit "no repeats" continuity rules.
20. **Saree color — final state**: user first asked for color rotation to be code-driven (added `Pick Daily Saree Color` node, 12-color palette, day-index rotation) — this was then **reverted per explicit user instruction** ("dont give colours option just giev or say us enew colours daily DONT GIVE COLOURS LET IT PICK NO NEED TO USE CODE FOR CHOOSING COLOURS"). Final state: `Pick Daily Saree Color` node **removed entirely**, `Flatten video_assets Insert` wires straight to `Generate Daily Look`, and the prompt itself instructs the AI to "pick a brand-new, sophisticated professional saree color for this look yourself, different from any color used in previous avatars" — no code-based palette, model decides color fresh each run, still bound by the same no-repeat continuity rules.

## Key architecture decisions

1. **Fixed avatar identity, varying wardrobe**: same presenter every video, daily wardrobe/background variation via HeyGen's look-generation API off the base avatar, always a saree, AI now picks the saree color/design itself each run (no hardcoded palette).
2. **Closing-scene branding**: Sugg logo + QR, attached via HeyGen's `files: [{type:"asset_id",...}]` param. **Known limitation, unresolved**: best-effort, not pixel-guaranteed. Real fix = post-render compositing (Shotstack/Creatomate/FFmpeg), vendor not chosen.
3. **9:16 vertical**: prompt-text only, `aspect_ratio` param is rejected by HeyGen.
4. **Content generation unified**: WF08's single AI Agent call produces video_prompt + youtube_thumbnail_prompt + all 4 platform captions in one JSON response, using all 19 researched fields.
5. **Content pacing**: 1 video/day via `content_queue` — WF03 pool of top 20 trending courses/day, filters anything covered in last 180 days, guarantees minimum 6 survivors queued, WF01 pops 1/day.
6. **Research/validation grounding**: two independent real-Google-Search-grounded Gemini calls (research, then fact-validation), each with a same-family fallback model on error — kept deliberately separate, not merged, per user's choice.
7. **Topic scope tightened**: pipeline explicitly searches/accepts only "trending graduate courses" — exam-results/admission-news headlines are filtered out at the source (query targeting + regex headline guard), not left to prompt engineering downstream.

## Recurring bug class found and fixed (important — watch for this pattern in any new code)

**This n8n instance auto-splits any top-level JSON array HTTP response into separate n8n items** (one item per array element), rather than delivering one item whose `.json` is the whole array. Code assuming `$input.first().json` is an array (`rows[0]`, `.map()`, `Array.isArray()` checks) breaks silently or throws. Correct pattern: `$input.all().map(i => i.json)` to safely collect all rows regardless of count; or, if exactly one row is expected, treat `$input.first().json` as the object directly (no `[0]` indexing).

**All confirmed-fixed instances this session:**
1. WF01 `Compute Needs Research Cycle`
2. WF08 `Build Agent User Message` (was also reading from wrong upstream node entirely)
3. WF09 `Flatten Video`
4. WF09 `Fan Out content_items`
5. WF10 `Build Weekly Summary`
6. WF11 `Compute 6 Insight Dimensions`
7. WF11 `Build Rewrite Prompt` (self-learning loop was silently never firing because of this)
8. WF02 `Normalize to Common Shape` — different bug: YouTube case pushed raw video titles as `course_name` instead of extracting actual course names via `extractCoursesFromHTML()`. Fixed to match, plus added `looksLikeHeadline()` filter (see change #16 above).

**Checked and confirmed already safe:** WF00, WF03, WF12.
**Rebuilt from scratch this session (not just bug-patched):** WF04, WF05.

## Push-then-verify discipline (learned the hard way)

Never trust a bare `PUT` / `STATUS 200` alone — always re-fetch fresh via `GET` immediately after and confirm the change actually persisted. This instance has silently reverted pushed changes at least twice when the user had the same workflow open in their own browser tab and saved concurrently (e.g. `aspect_ratio` removal reverted once, `Build Agent User Message` fix reverted once). Every change in this file's change-log was confirmed via fresh re-fetch after pushing.

## Supabase schema (key tables)

`courses`, `course_facts`, `colleges`, `salaries`, `faq`, `news`, `careers`, `content_queue`, `content_items`, `video_assets`, `publish_targets`, `analytics`, `learning_insights`, `prompt_templates`, `trend_history`, `research_raw`, `audit_log`, `dead_letter_queue`, `workflow_runs`.

`prompt_templates` — versioned AI system prompts, keyed by `template_key`. `heygen_video_agent_system` is at v6 (id=9, active) — 6-beat structure, B-roll requirement, gesture limits, eligibility clarity, course-name sanity checks. **Deactivate old versions by `template_key + is_active` filter, never by hardcoded row id** (ids aren't sequential-per-key — this caused two versions being simultaneously active earlier in the session before being caught). **Never truncate this table** — it's config, not pipeline data.

`careers` schema: `id, course_id, role (text), description (text), deleted_at, created_at`.

## Fresh-restart state

All pipeline tables (everything except `prompt_templates`) were `TRUNCATE ... RESTART IDENTITY CASCADE`'d earlier this session. IDs reset to 1. Any old pinned/demo data referencing course_id=3 etc. is stale. One known stale test row (created 08:45, empty caption, already live-published) exists and needs manual correction — can't be retroactively fixed by the pipeline.

## Known open items / unresolved

1. **QR/logo overlay guarantee** — still needs a real compositing vendor decision (Shotstack/Creatomate/FFmpeg), not yet made.
2. **WF02's `careers360` ScraperAPI source** — flagged multiple times as a cost/reliability tradeoff, never resolved (keep or remove).
3. **Branch Testing MD doc** (`Career_Content_Factory_Branch_Testing.md`) — not updated this session, still reflects an older workflow state.
4. **Walkthrough MD doc** — was updated once mid-session (avatar look system, WF07 simplification, 8-bug audit list) but is now stale relative to: WF04/WF05 grounding rebuild, WF02 query/headline-filter changes, eligibility field, WF06 careers fix, external_post_id fix, and the final code-free saree-color prompt. Not re-updated (per standing "only update when told" rule) — flag if user asks for a doc refresh.
5. **No full end-to-end live test** has completed successfully through all 13 workflows in sequence with all current fixes in place simultaneously — individual workflows tested piecemeal, not one full daily-cycle run start-to-finish (WF01 → ... → WF09 actually publishing live).
6. There's a separate local file `Career_Content_Factory_Complete_Guide.md` in the user's IDE that Claude has not reviewed/authored — unclear if current or stale.

## Published docs (artifacts)

- **Full walkthrough** (node-by-node, all 13 workflows): https://claude.ai/code/artifact/75abffe4-9da9-4c7a-b8a3-78c0754667ce — last updated mid-session, now stale (see open item #4 above).
- **Branch/pin-data testing guide**: link not re-confirmed this session, likely stale — ask Claude to look it up via artifact list if needed.

## User's working style / standing instructions

- Wants explicit confirmation of what changed, what broke, and why — after every fix.
- Does NOT want the MD docs auto-updated on every change — only update when explicitly told to.
- Prefers direct fixes over lengthy explanations; verify fixes with a fresh re-fetch after every push (a `STATUS 200` alone is not sufficient — this instance has previously reverted changes silently between pushes).
- When user gives an explicit correction on approach (e.g. "don't use code for this, let AI decide"), apply it immediately and fully — remove the old approach's artifacts (nodes, wiring), don't leave partial/dead structure behind.
- CLAUDE.md project file requires terse "caveman" response style: drop articles/filler, short fragments OK, keep code/errors exact.
