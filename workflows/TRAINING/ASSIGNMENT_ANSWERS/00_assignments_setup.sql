                                                                                                                                                                                                                                                                                      -- ============================================================
-- ASSIGNMENT ANSWERS — Supabase setup
-- Run once in: Supabase -> SQL Editor -> New query -> Run
-- Creates 2 NEW tables only. Never alters existing tables.
-- Safe to re-run.
-- ============================================================

-- Assignments 1 and 5
create table if not exists public.students (
  id bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  name text,
  email text,
  course text,
  status text not null default 'new'
);

-- Assignment 3
create table if not exists public.library_books (
  id bigint generated always as identity primary key,
  book_name text,
  author text,
  available boolean default true
);

insert into public.library_books (book_name, author, available)
select * from (values
  ('Atomic Habits', 'James Clear', true),
  ('The Alchemist', 'Paulo Coelho', true),
  ('Wings of Fire', 'A. P. J. Abdul Kalam', false),
  ('Clean Code', 'Robert C. Martin', true)
) as v(book_name, author, available)
where not exists (select 1 from public.library_books);
