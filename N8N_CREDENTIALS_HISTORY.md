# n8n / Supabase Credentials History

One entry per instance ever used on this project. Newest first. Update this file, not memory, whenever an instance changes — Claude checks here every session.

---

## CURRENT — devikaraj n8n (this session)

- URL: `https://n8n.devikarajnr.fyi/`
- API key: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiI2MmZmYjllOC02MWRjLTQxZGYtYTA4OS05Zjk2YzQ5ODMxMzEiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwianRpIjoiZmFkYTQ4M2YtYjQ1OC00Njc4LWJlYzEtMDA3OTMyNTBkMjA5IiwiaWF0IjoxNzg2MTA1NzA1fQ.LVFI3M-aC9rNzoE470RkyJ7Koi9xS3w8ghnrJ0QISok`
- Status: **active target** — 13-workflow Career Content Factory pipeline imported here 2026-08-07, tagged `Career_Content_Factory` (id `yi5aqtXEg7qDcZpV` — used tags not folders, this instance's Projects/folders API is enterprise-license-gated, 403'd on try).
- Workflow ids: 00=`XMCzliAo8BanhPlX` 01=`5w1kKoifAdS5LMM7` 02=`uKDCKqydRZaLRxXx` 03=`braGhIr8ceJI37RD` 04=`S6KnRz9YhDPbhxyR` 05=`1F8V1mCw2KLmpbTp` 06=`FCAn71ILIw4xD5CF` 07=`a2kCgCVtdztBSre8` 08=`XqgnNKUgc84Hk0mz` 09=`ChSlNGHqqpqJL5Ak` 10=`03ZXpB7GT0CBsgYq` 11=`wZZi5viY798sG4kI` 12=`gyS7OVOBXlQWE4XJ`
- Credential mapping used on import: `supabaseApi` → new `content_factory` cred (id `fQVqgkOGVZ6Zw47v`, points at bxtyomzvyyjngvwwbfqq below); `googlePalmApi` (was `SUGG`) → existing `n8n` cred (id `sanjgJOPV62e0Vul`, googlePalmApi) per your choice, note this instance's Gemini cred isn't named for this project; `gmailOAuth2` → existing `Gmail account` (id `aw0729XCociMNVtw`, exact name match). **Left blank on purpose** (you're wiring these yourself): HeyGen (all 4 nodes in WF06/WF08), Instagram/Facebook/LinkedIn/YouTube (WF09), Instagram/YouTube/LinkedIn analytics (WF10), Slack (WF00/01/10/11/12 — no exact-type `slackApi` match existed here, only a `bhuminexa`-named one, didn't want to risk posting into wrong client's Slack).
- All workflows imported **inactive** — per your process doc, nothing gets activated until tested one by one.

## CURRENT — Supabase (bxtyomzvyyjngvwwbfqq)

- URL: `https://bxtyomzvyyjngvwwbfqq.supabase.co`
- anon key: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ4dHlvbXp2eXlqbmd2d3diZnFxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYxMDAyMTksImV4cCI6MjEwMTY3NjIxOX0.RBcWuZUsBSVvPZgWeZbJwU7SL6Gk-a6CnRU_Q-A70T4`
- service_role key: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ4dHlvbXp2eXlqbmd2d3diZnFxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NjEwMDIxOSwiZXhwIjoyMTAxNjc2MjE5fQ.peLj5DnbWfigrKaApm9QvEUJGf6MVPPrh7RjdeoF58c`
- publishable key: `sb_publishable_dghPBauEyCGMYLd70l0uJw_zhEoGbiw`
- Status: **active target** — new project, schema in `supabase_schema.sql`, replaces `fxhrigzjvpmjvbblbqqr`.

---

## CURRENT — Aravind n8n (separate instance, kept for that client's workflows)

- URL: `https://aravind072.app.n8n.cloud`
- API key: stored in `.env` at project root as `ARAVIND_N8N_URL` / `ARAVIND_N8N_API_KEY`
- Status: **active target**, separate n8n instance from the devikarajnr one above. Use this one only when work is explicitly scoped to Aravind's workflows.

---

## CURRENT — hstgr n8n (this is where the WF00/04/05/06/08/09/10 edits this session actually landed)

- URL: `https://n8n.srv1757918.hstgr.cloud`
- API key: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJjYmI0NTI0My02NmJmLTRhNjgtOWNlOS1hM2FiNmM2ZTlhYWIiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwianRpIjoiMGIyYjc5OWMtN2U5OC00YmVjLTgxZDMtMDRjMjkwYjE1Nzg4IiwiaWF0IjoxNzg1NjY0MzEzfQ.ORUjX2zOzFiyndkBcaPEr9-aOjcrqgE7ZntW7eApb2Y`
- Status: **active target** — 13 workflows live here, tagged Career Content Factory. All the saree/wardrobe-variety, camera-framing, pronunciation-fix, WF10 race-condition, and other prompt/node edits this session were made on THIS instance. Workflow ids in `workflows/archive/workflow id`: 00=`D46SUmWUtLZnTbYp` 04=`a9d2q6NZD4ihu3IW` 05=`R36zNJvuMpxVOoAr` 06=`39qWGhrL0qYt3L2F` 08=`a5pMOiPBAYteh45Q` 09=`fax6LABh67qyY4u7` 10=`Ujbp9WT77pWMi3tH`.
- Relation to devikarajnr instance above: devikarajnr is a separate later import (2026-08-07) of the same 13-workflow pipeline, imported inactive, credentials only partly wired. hstgr is the older instance that's actually been live-edited and tested throughout this session. **Until told otherwise, treat hstgr as the one "in specific n8n" requests without a named instance mean**, since that's where the real work/history is.

## CURRENT — Supabase (fxhrigzjvpmjvbblbqqr)

- Project ref: `fxhrigzjvpmjvbblbqqr`
- URL: `https://fxhrigzjvpmjvbblbqqr.supabase.co`
- Status: **active target** — backs the hstgr n8n instance above. `prompt_templates`, `video_assets`, `content_items`, `publish_targets`, `courses` etc. all live here; this is where `heygen_video_agent_system` v16 and the wardrobe_variant tracking column were changed this session. Service role key not on file — pull from n8n credential node or ask user if a direct call is needed outside n8n.

---

## Retired — mindvault n8n

Removed per instruction 2026-08-07 — no longer in use, not tracked here anymore.

---

**Rule going forward:** any time a new n8n or Supabase instance shows up in chat, add it to the top of this file under CURRENT and move the old CURRENT down to Prior. Never delete a Prior entry, only Retired ones on explicit request.
