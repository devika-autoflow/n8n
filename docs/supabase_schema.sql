-- Career Content Factory — full schema
-- Target: new Supabase project bxtyomzvyyjngvwwbfqq (https://bxtyomzvyyjngvwwbfqq.supabase.co)
-- Run whole file once in Supabase SQL Editor. Safe to re-run (IF NOT EXISTS guards).
-- Built from Career_Content_Factory_Complete_Guide.md schema section.

create extension if not exists vector;
create extension if not exists pgcrypto;

-- ============================================================
-- workflow_runs — master audit log
-- ============================================================
create table if not exists workflow_runs (
  id bigint generated always as identity primary key,
  workflow_name text not null,
  n8n_execution_id text not null unique,
  status text not null check (status in ('running','success','dead_letter','failed')),
  items_processed int default 0,
  items_failed int default 0,
  error_summary text,
  started_at timestamptz default now(),
  finished_at timestamptz
);
create index if not exists idx_workflow_runs_name on workflow_runs(workflow_name);

-- ============================================================
-- dead_letter_queue — failed items
-- ============================================================
create table if not exists dead_letter_queue (
  id bigint generated always as identity primary key,
  workflow_name text not null,
  node_name text,
  payload jsonb,
  error_message text,
  retry_count int default 0,
  resolved boolean default false,
  resolved_at timestamptz,
  created_at timestamptz default now()
);
create index if not exists idx_dlq_resolved on dead_letter_queue(resolved, resolved_at);

-- ============================================================
-- content_queue — what-to-cover-next pool
-- ============================================================
create table if not exists content_queue (
  id bigint generated always as identity primary key,
  course_name text not null,
  normalized_name text,
  trend_score numeric,
  rank_position int,
  queued_at timestamptz default now(),
  consumed boolean default false,
  consumed_at timestamptz
);
create index if not exists idx_content_queue_consumed on content_queue(consumed, queued_at);

-- ============================================================
-- trend_history — one row/day of market research
-- ============================================================
create table if not exists trend_history (
  id bigint generated always as identity primary key,
  captured_date date not null unique,
  total_courses int,
  source_count int,
  courses jsonb not null default '[]'::jsonb,
  created_at timestamptz default now()
);

-- ============================================================
-- research_raw — unfiltered AI research output
-- ============================================================
create table if not exists research_raw (
  id bigint generated always as identity primary key,
  course_name text not null,
  n8n_execution_id text,
  fields jsonb not null default '[]'::jsonb,
  created_at timestamptz default now()
);
create index if not exists idx_research_raw_course on research_raw(course_name, created_at desc);

-- ============================================================
-- course_facts — validated, confidence-scored facts
-- ============================================================
create table if not exists course_facts (
  id bigint generated always as identity primary key,
  course_id bigint,
  fact_key text not null,
  fact_value text,
  fact_value_numeric numeric,
  confidence_score numeric check (confidence_score between 0 and 1),
  source_count int,
  agreement_pct numeric,
  review_status text default 'pending' check (review_status in ('pending','verified','flagged','rejected')),
  source_urls jsonb default '[]'::jsonb,
  last_verified_at timestamptz default now(),
  deleted_at timestamptz,
  created_at timestamptz default now()
);
create index if not exists idx_course_facts_course on course_facts(course_id);

-- ============================================================
-- courses — master course record
-- ============================================================
create table if not exists courses (
  id bigint generated always as identity primary key,
  name text not null,
  slug text unique,
  description text,
  eligibility text,
  duration text,
  entrance_exams text,
  emerging_trends text,
  future_scope text,
  career_path text,
  abroad_opportunities text,
  scholarships text,
  industry_demand text,
  ai_summary text,
  embedding vector(768),
  confidence_score numeric,
  review_status text default 'pending' check (review_status in ('pending','verified','flagged','rejected')),
  last_verified_at timestamptz,
  deleted_at timestamptz,
  created_at timestamptz default now()
);
create unique index if not exists idx_courses_slug on courses(slug);

-- ============================================================
-- salaries — one row per course
-- ============================================================
create table if not exists salaries (
  id bigint generated always as identity primary key,
  course_id bigint references courses(id),
  average_salary numeric,
  highest_salary numeric,
  placement_percent numeric,
  confidence_score numeric,
  deleted_at timestamptz,
  created_at timestamptz default now()
);
create index if not exists idx_salaries_course on salaries(course_id);

-- ============================================================
-- colleges — several rows per course
-- ============================================================
create table if not exists colleges (
  id bigint generated always as identity primary key,
  course_id bigint references courses(id),
  name text,
  type text check (type in ('government','private')),
  city text,
  fees_annual numeric,
  deleted_at timestamptz,
  created_at timestamptz default now()
);
create index if not exists idx_colleges_course on colleges(course_id);

-- ============================================================
-- careers — recruiters/roles per course
-- ============================================================
create table if not exists careers (
  id bigint generated always as identity primary key,
  course_id bigint references courses(id),
  role text,
  description text,
  deleted_at timestamptz,
  created_at timestamptz default now()
);
create index if not exists idx_careers_course on careers(course_id);

-- ============================================================
-- faq
-- ============================================================
create table if not exists faq (
  id bigint generated always as identity primary key,
  course_id bigint references courses(id),
  question text,
  answer text,
  category text,
  embedding vector(768),
  deleted_at timestamptz,
  created_at timestamptz default now()
);
create index if not exists idx_faq_course on faq(course_id);

-- ============================================================
-- news
-- ============================================================
create table if not exists news (
  id bigint generated always as identity primary key,
  course_id bigint references courses(id),
  headline text,
  summary text,
  url text,
  published_at timestamptz,
  deleted_at timestamptz,
  created_at timestamptz default now()
);
create index if not exists idx_news_course on news(course_id);

-- ============================================================
-- audit_log
-- ============================================================
create table if not exists audit_log (
  id bigint generated always as identity primary key,
  table_name text,
  record_id bigint,
  action text,
  changed_by text,
  diff jsonb,
  created_at timestamptz default now()
);

-- ============================================================
-- prompt_templates — editable AI instructions
-- ============================================================
create table if not exists prompt_templates (
  id bigint generated always as identity primary key,
  template_key text not null,
  version int not null,
  template_body text not null,
  is_active boolean default true,
  created_by text default 'manual',
  created_at timestamptz default now()
);
create index if not exists idx_prompt_templates_key on prompt_templates(template_key, is_active);

-- ============================================================
-- content_items — drafted social posts
-- ============================================================
create table if not exists content_items (
  id bigint generated always as identity primary key,
  course_id bigint references courses(id),
  platform text check (platform in ('instagram_reel','youtube_shorts','linkedin_post','facebook_post')),
  title text,
  body text,
  hashtags text,
  metadata jsonb default '{}'::jsonb,
  script_json jsonb,
  status text default 'draft' check (status in ('draft','published')),
  word_count int,
  created_at timestamptz default now()
);
create index if not exists idx_content_items_course on content_items(course_id);

-- ============================================================
-- video_assets — HeyGen render tracking
-- ============================================================
create table if not exists video_assets (
  id bigint generated always as identity primary key,
  course_id bigint references courses(id),
  thumbnail_prompt text,
  heygen_video_id text,
  video_url text,
  duration_seconds numeric,
  status text default 'queued' check (status in ('queued','generating','ready','failed')),
  error_message text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
create index if not exists idx_video_assets_course on video_assets(course_id);

-- ============================================================
-- publish_targets — one row per actually-published post
-- ============================================================
create table if not exists publish_targets (
  id bigint generated always as identity primary key,
  content_item_id bigint references content_items(id),
  video_asset_id bigint references video_assets(id),
  platform text,
  published_at timestamptz default now(),
  external_post_id text,
  external_url text,
  status text default 'published'
);
create index if not exists idx_publish_targets_platform on publish_targets(platform, published_at);

-- ============================================================
-- analytics — daily performance numbers
-- ============================================================
create table if not exists analytics (
  id bigint generated always as identity primary key,
  publish_target_id bigint references publish_targets(id),
  metric_date date not null,
  views bigint,
  reach bigint,
  watch_time_seconds bigint,
  retention_pct numeric,
  likes bigint,
  comments bigint,
  shares bigint,
  saves bigint,
  new_subscribers bigint,
  new_followers bigint,
  ctr_pct numeric,
  completion_rate_pct numeric,
  raw_payload jsonb,
  created_at timestamptz default now(),
  unique (publish_target_id, metric_date)
);

-- ============================================================
-- learning_insights — WF11 findings
-- ============================================================
create table if not exists learning_insights (
  id bigint generated always as identity primary key,
  insight_type text,
  finding text,
  supporting_data jsonb,
  confidence numeric,
  applied boolean default false,
  applied_at timestamptz,
  created_at timestamptz default now()
);

-- ============================================================
-- Seed: prompt_templates row WF08 needs to exist before first run
-- (heygen_video_agent_system v1 — edit later in Supabase to refine)
-- ============================================================
insert into prompt_templates (template_key, version, template_body, is_active, created_by)
select
  'heygen_video_agent_system',
  1,
  'You are directing a 45-50 second vertical (9:16) presenter video for an Indian career/education channel. '
  || 'Write a 6-beat narrative script (~115-125 words spoken dialogue) introducing one graduate course. '
  || 'Beat 1: hook. Beat 2: MUST state course duration and minimum eligibility explicitly. '
  || 'Beats 3-4: career scope, named colleges/recruiters/scholarships when available — prefer concrete named facts over generic statements. '
  || 'At least 2 beats must be B-roll-only (no presenter on camera). '
  || 'Closing beat: brand logo + QR code call-to-action. '
  || 'Camera framing: medium shot, head/shoulders/chest/hands visible, subject centered — never a tight face close-up. '
  || 'Minimal hand gestures. Skip any field gracefully if data is missing — never invent facts. '
  || 'Return JSON with keys: video_prompt, youtube_thumbnail_prompt, instagram_reel, youtube_shorts, linkedin_post, facebook_post.',
  true,
  'manual'
where not exists (
  select 1 from prompt_templates where template_key = 'heygen_video_agent_system'
);
