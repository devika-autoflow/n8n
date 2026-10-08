# NAVIGATION — n8n

Map of this repo. One line per file/folder: what it holds and why it matters.
Update the relevant line in the same change that adds, renames or deletes a file.

First-pass map (2026-10-02) — grow this as files are added.

## Entry points / config

- `CLAUDE.md` — project-specific instructions for this n8n workspace.
- `N8N_CREDENTIALS_HISTORY.md` — record of credentials set up over time (check before recreating one).
- `.env` — environment config (gitignored).
- `.gitignore` — keeps local/OS junk and secrets out of the repo.

## Folders

- `completed projects/` — finished n8n workflow projects, archived.
- `docs/` — reference docs for this workspace.
- `logs/` — run logs (gitignored, check before assuming it's empty).
- `skills/` — Claude Code skills used in this workspace.
- `workflows/` — n8n workflow JSON exports.
- `workflows/PENSION/` — client PensionCo automation (main + chaser + drive/email sub).
- `workflows/TRAINING/` — 5 simple generic training workflows (intro to webhook/set/switch/if/http/code/gmail/supabase) + `00_supabase_setup.sql`. Not pension-related; use client pension.co Supabase as DB host only. Workflow 5 calls postcodes.io.
- `workflows/TRAINING/06_*` — Training 6: "Pension Enquiry" main workflow (saves row first) calling 3 sub-workflows (Sub 1 email member, Sub 2 notify admin, Sub 3 update same row status). Import the 3 Subs first.

## Docs

- `LEARNINGS.md` — bugs/gotchas hit in this project.
- `NAVIGATION.md` — this file.
