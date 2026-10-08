-- ============================================================
-- TRAINING WORKFLOWS — Supabase setup
-- Run in: pension.co project  ->  SQL Editor  ->  New query  ->  Run
-- Project ref: bfbdlkuctycrsmkwnykl  (client's existing project)
-- SAFE FOR PRODUCTION: this script ONLY creates 2 NEW tables.
-- It never ALTERs, DROPs, UPDATEs or DELETEs anything in the existing
-- production tables (members, policies, case_audit_log, demo_progress,
-- dpa_checks, dss_scheme_config, invoices, member_nrd).
-- Safe to re-run: every statement is "if not exists" / "where not exists".
-- RLS left OFF on purpose — training/demo only, keeps n8n access simple.
-- ============================================================

-- 1) Submissions: rows created by the intake / signup demo workflows
create table if not exists public.training_submissions (
  id          bigint generated always as identity primary key,
  created_at  timestamptz not null default now(),
  full_name   text,
  email       text,
  category     text,                 -- e.g. support | sales | general
  message     text,
  status      text not null default 'new'
);

-- 2) Events: step/activity log written by the email + log demo workflows
create table if not exists public.training_events (
  id               bigint generated always as identity primary key,
  created_at       timestamptz not null default now(),
  submission_email text,
  event_name       text,             -- e.g. "Confirmation Sent"
  event_detail     text
);

-- Helpful indexes for the lookup demo
create index if not exists idx_training_submissions_email
  on public.training_submissions (email);

-- Seed row so the "Lookup + Conditional Email" demo finds a match
-- and the "found" email lands in a real inbox (Aravind's Gmail)
insert into public.training_submissions (full_name, email, category, message, status)
select 'Aravind Kumar', 'aravindsg072@gmail.com', 'support', 'Seed row for training lookup demo', 'new'
where not exists (
  select 1 from public.training_submissions where email = 'aravindsg072@gmail.com'
);
