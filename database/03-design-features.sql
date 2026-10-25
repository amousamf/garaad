-- =====================================================================
-- Garaad database — update 3. Run once, after 01-schema.sql and
-- 02-progress-and-offline.sql.
-- Paste this whole file into Supabase > SQL Editor and press Run.
-- It runs as one transaction: if anything fails, nothing is changed.
--
-- Adds, for the new design:
--   * children.avatar, children.theme   – each child's owl and colours,
--     kept on any teacher's phone.
--   * children.parent_phone             – where the weekly report is sent.
--   * children.child_code               – a short code used instead of the
--     name in pilot exports.
--   * rounds.hints_used, rounds.stars_spent – hints bought with stars.
--   * assessments table                 – baseline, midline and endline
--     scores (maths and English) for the pilot. Existing starting
--     exercise scores are copied in as baselines.
--   * New functions: update_child, save_assessment, class_needs_help,
--     child_week_report, pilot_summary, pilot_export.
--
-- Phones still running the current app keep working: every new
-- function argument is optional.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- 1. New columns
-- ---------------------------------------------------------------------

alter table public.children
  add column if not exists avatar text,
  add column if not exists theme text not null default 'savanna',
  add column if not exists parent_phone text,
  add column if not exists child_code text
    default ('C-' || upper(encode(extensions.gen_random_bytes(3), 'hex')));

-- Give every existing child a code (new children get one automatically).
update public.children
   set child_code = 'C-' || upper(encode(extensions.gen_random_bytes(3), 'hex'))
 where child_code is null;

alter table public.children alter column child_code set not null;

do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'children_child_code_key') then
    alter table public.children add constraint children_child_code_key unique (child_code);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'children_theme_check') then
    alter table public.children add constraint children_theme_check
      check (theme in ('savanna', 'ocean', 'night'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'children_avatar_check') then
    alter table public.children add constraint children_avatar_check
      check (avatar is null or avatar ~ '^[a-z]{3,12}(-[a-z]{2,12})?$');   -- e.g. teal-cap, orange-bow
  end if;
end $$;

alter table public.rounds
  add column if not exists hints_used  smallint not null default 0,
  add column if not exists stars_spent smallint not null default 0;

do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'rounds_hints_check') then
    alter table public.rounds add constraint rounds_hints_check
      check (hints_used >= 0 and stars_spent >= 0);
  end if;
end $$;

create index if not exists rounds_child_played_idx on public.rounds (child_id, played_at);
create index if not exists sessions_child_started_idx on public.sessions (child_id, started_at);

-- ---------------------------------------------------------------------
-- 2. Assessments (baseline, midline, endline)
-- ---------------------------------------------------------------------

create table if not exists public.assessments (
  id             uuid primary key default gen_random_uuid(),
  child_id       uuid not null references public.children(id) on delete cascade,
  kind           text not null check (kind in ('baseline', 'midline', 'endline')),
  maths_score    smallint,
  maths_total    smallint,
  english_score  smallint,
  english_total  smallint,
  score          smallint not null,             -- all questions right
  total          smallint not null,             -- all questions asked
  teacher_id     uuid references public.teachers(id) on delete set null,
  done_at        timestamptz not null default now(),
  unique (child_id, kind),
  check (total > 0 and score between 0 and total),
  check (maths_score   is null or (maths_total   > 0 and maths_score   between 0 and maths_total)),
  check (english_score is null or (english_total > 0 and english_score between 0 and english_total))
);

alter table public.assessments enable row level security;
revoke all on public.assessments from anon, authenticated;

-- Copy existing starting exercises in as baselines.
insert into public.assessments (child_id, kind, score, total, teacher_id, done_at)
select c.id, 'baseline', c.start_score, c.start_total, c.added_by, c.start_done_at
  from public.children c
 where c.start_done_at is not null and c.start_total > 0
   and c.start_score between 0 and c.start_total
on conflict (child_id, kind) do nothing;

-- ---------------------------------------------------------------------
-- 3. Children: add, open, list, update
-- ---------------------------------------------------------------------

-- add_child gains avatar, theme and parent phone (all optional).
drop function if exists public.add_child(text, uuid, text, int, text);
create or replace function public.add_child(p_token text, p_class_id uuid, p_name text,
  p_age int default null, p_expected_group text default null,
  p_avatar text default null, p_theme text default null, p_parent_phone text default null) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare
  t public.tokens := public._tok(p_token);
  v uuid;
  v_phone text := case when coalesce(trim(p_parent_phone), '') = '' then null
                       else public._phone(p_parent_phone) end;
begin
  if t.role = 'principal' then raise exception 'read_only'; end if;
  if coalesce(trim(p_name),'') = '' then return json_build_object('ok', false, 'error', 'name_required'); end if;
  if t.role = 'teacher' then
    if not exists (select 1 from public.classes where id = p_class_id and school_id = t.school_id) then
      return json_build_object('ok', false, 'error', 'bad_class');
    end if;
    insert into public.children(school_id, class_id, name, age, expected_group, added_by, avatar, theme, parent_phone)
    values (t.school_id, p_class_id, trim(p_name), p_age, p_expected_group, t.teacher_id,
            p_avatar, coalesce(p_theme, 'savanna'), v_phone)
    returning id into v;
  elsif t.role = 'family' then
    insert into public.children(family_id, name, age, avatar, theme, parent_phone)
    values (t.family_id, trim(p_name), p_age, p_avatar, coalesce(p_theme, 'savanna'), v_phone)
    returning id into v;
  else
    raise exception 'not_allowed';
  end if;
  return json_build_object('ok', true, 'child_id', v);
end $$;

-- Change a child's owl, colours or parent phone. Leave an argument out to keep it;
-- pass an empty parent phone ('') to remove it.
create or replace function public.update_child(p_token text, p_child_id uuid,
  p_avatar text default null, p_theme text default null, p_parent_phone text default null) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare t public.tokens := public._tok(p_token);
begin
  if t.role = 'principal' or not public._child_ok(t, p_child_id) then raise exception 'not_allowed'; end if;
  update public.children set
    avatar = coalesce(p_avatar, avatar),
    theme  = coalesce(p_theme, theme),
    parent_phone = case
      when p_parent_phone is null then parent_phone
      when trim(p_parent_phone) = '' then null
      else public._phone(p_parent_phone) end
  where id = p_child_id;
  return json_build_object('ok', true);
end $$;

-- child_open now also returns avatar, theme and parent phone.
create or replace function public.child_open(p_token text, p_child_id uuid) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare t public.tokens := public._tok(p_token);
begin
  if not public._child_ok(t, p_child_id) then raise exception 'not_allowed'; end if;
  return (select json_build_object(
      'id', c.id, 'name', c.name, 'age', c.age, 'expected_group', c.expected_group,
      'class_id', c.class_id, 'class_name', cl.name,
      'start_score', c.start_score, 'start_total', c.start_total, 'start_done_at', c.start_done_at,
      'progress', c.progress,
      'avatar', c.avatar, 'theme', c.theme, 'parent_phone', c.parent_phone)
    from public.children c left join public.classes cl on cl.id = c.class_id
    where c.id = p_child_id);
end $$;

-- list_children now also returns avatar and theme.
create or replace function public.list_children(p_token text, p_class_id uuid default null, p_search text default null) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare t public.tokens := public._tok(p_token);
begin
  return coalesce((select json_agg(x order by x->>'name') from (
    select json_build_object(
      'id', ch.id, 'name', ch.name, 'age', ch.age, 'class_id', ch.class_id,
      'expected_group', ch.expected_group,
      'start_score', ch.start_score, 'start_total', ch.start_total,
      'avatar', ch.avatar, 'theme', ch.theme,
      'sessions', (select count(*) from public.sessions se where se.child_id = ch.id),
      'last_played', (select max(r.played_at) from public.rounds r where r.child_id = ch.id)) as x
    from public.children ch
    where ( (t.role in ('teacher','principal') and ch.school_id = t.school_id
              and (p_class_id is null or ch.class_id = p_class_id))
         or (t.role = 'family' and ch.family_id = t.family_id) )
      and (p_search is null or ch.name ilike '%' || p_search || '%')) q), '[]'::json);
end $$;

-- The starting exercise is also saved as the child's baseline assessment.
create or replace function public.save_start_score(p_token text, p_child_id uuid, p_score int, p_total int) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare t public.tokens := public._tok(p_token);
begin
  if t.role = 'principal' or not public._child_ok(t, p_child_id) then raise exception 'not_allowed'; end if;
  update public.children set start_score = p_score, start_total = p_total, start_done_at = now()
   where id = p_child_id and start_done_at is null;              -- the starting exercise is saved once
  if p_total > 0 and p_score between 0 and p_total then
    insert into public.assessments (child_id, kind, score, total, teacher_id)
    values (p_child_id, 'baseline', p_score, p_total, t.teacher_id)
    on conflict (child_id, kind) do nothing;
  end if;
  return json_build_object('ok', true);
end $$;

-- ---------------------------------------------------------------------
-- 4. Assessments
-- ---------------------------------------------------------------------

-- Save a baseline, midline or endline. A baseline is kept once; a midline or
-- endline done again replaces the earlier one.
create or replace function public.save_assessment(p_token text, p_child_id uuid, p_kind text,
  p_maths_score int default null, p_maths_total int default null,
  p_english_score int default null, p_english_total int default null) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare
  t public.tokens := public._tok(p_token);
  v_score int := coalesce(p_maths_score, 0) + coalesce(p_english_score, 0);
  v_total int := coalesce(p_maths_total, 0) + coalesce(p_english_total, 0);
begin
  if t.role = 'principal' or not public._child_ok(t, p_child_id) then raise exception 'not_allowed'; end if;
  if p_kind not in ('baseline', 'midline', 'endline') then return json_build_object('ok', false, 'error', 'bad_kind'); end if;
  if v_total <= 0 then return json_build_object('ok', false, 'error', 'no_questions'); end if;

  if p_kind = 'baseline' then
    insert into public.assessments (child_id, kind, maths_score, maths_total, english_score, english_total, score, total, teacher_id)
    values (p_child_id, 'baseline', p_maths_score, p_maths_total, p_english_score, p_english_total, v_score, v_total, t.teacher_id)
    on conflict (child_id, kind) do nothing;
    update public.children set start_score = v_score, start_total = v_total, start_done_at = now()
     where id = p_child_id and start_done_at is null;
  else
    insert into public.assessments (child_id, kind, maths_score, maths_total, english_score, english_total, score, total, teacher_id)
    values (p_child_id, p_kind, p_maths_score, p_maths_total, p_english_score, p_english_total, v_score, v_total, t.teacher_id)
    on conflict (child_id, kind) do update set
      maths_score = excluded.maths_score, maths_total = excluded.maths_total,
      english_score = excluded.english_score, english_total = excluded.english_total,
      score = excluded.score, total = excluded.total,
      teacher_id = excluded.teacher_id, done_at = now();
  end if;
  return json_build_object('ok', true);
end $$;

-- ---------------------------------------------------------------------
-- 5. Rounds: hints bought with stars
-- ---------------------------------------------------------------------

drop function if exists public.record_round(text, uuid, uuid, text, text, text, int, int, int, int, jsonb, timestamptz);
create or replace function public.record_round(p_token text, p_round_id uuid, p_session_id uuid,
  p_subject text, p_game text, p_skill text, p_level int, p_questions int, p_right_first_time int,
  p_stars int, p_missed jsonb default '[]'::jsonb, p_played_at timestamptz default null,
  p_hints_used int default 0, p_stars_spent int default 0) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare t public.tokens := public._tok(p_token); v_child uuid;
begin
  select child_id into v_child from public.sessions where id = p_session_id;
  if v_child is null or t.role = 'principal' or not public._child_ok(t, v_child) then raise exception 'not_allowed'; end if;
  insert into public.rounds(id, session_id, child_id, subject, game, skill, level, questions, right_first_time, stars,
                            missed, played_at, hints_used, stars_spent)
  values (p_round_id, p_session_id, v_child, p_subject, p_game, p_skill, p_level, p_questions, p_right_first_time, p_stars,
          coalesce(p_missed, '[]'::jsonb), coalesce(p_played_at, now()),
          greatest(coalesce(p_hints_used, 0), 0), greatest(coalesce(p_stars_spent, 0), 0))
  on conflict (id) do nothing;
  return json_build_object('ok', true);
end $$;

-- child_detail now includes hints, avatar and assessments.
create or replace function public.child_detail(p_token text, p_child_id uuid) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare t public.tokens := public._tok(p_token);
begin
  if not public._child_ok(t, p_child_id) then raise exception 'not_allowed'; end if;
  return json_build_object(
    'child', (select row_to_json(ch) from (
       select c.id, c.name, c.age, c.expected_group, c.start_score, c.start_total, c.start_done_at,
              c.avatar, c.theme, c.parent_phone, cl.name as class_name
       from public.children c left join public.classes cl on cl.id = c.class_id where c.id = p_child_id) ch),
    'assessments', coalesce((select json_agg(a order by a.done_at) from (
       select kind, maths_score, maths_total, english_score, english_total, score, total, done_at
       from public.assessments where child_id = p_child_id) a), '[]'::json),
    'rounds', coalesce((select json_agg(r order by r.played_at desc) from (
       select subject, game, skill, level, questions, right_first_time, stars, hints_used, stars_spent, missed, played_at
       from public.rounds where child_id = p_child_id) r), '[]'::json));
end $$;

-- ---------------------------------------------------------------------
-- 6. Teacher: needs help today
-- ---------------------------------------------------------------------

-- Children who struggled today (Mogadishu time): under half right first time
-- (at least 5 questions), or 3+ hints. Worst first, up to 5 children.
create or replace function public.class_needs_help(p_token text, p_class_id uuid default null) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare
  t public.tokens := public._tok(p_token);
  v_from timestamptz := date_trunc('day', now() at time zone 'Africa/Mogadishu') at time zone 'Africa/Mogadishu';
begin
  if t.role not in ('teacher','principal') then raise exception 'not_allowed'; end if;
  return coalesce((select json_agg(x) from (
    with g as (
      select r.child_id, r.subject, r.game, r.skill,
             sum(r.questions) as q, sum(r.right_first_time) as rf, sum(r.hints_used) as h
        from public.rounds r
        join public.children ch on ch.id = r.child_id
       where ch.school_id = t.school_id
         and (p_class_id is null or ch.class_id = p_class_id)
         and r.played_at >= v_from
       group by r.child_id, r.subject, r.game, r.skill),
    c as (
      select child_id, sum(q) as q, sum(rf) as rf, sum(h) as h from g group by child_id)
    select json_build_object(
      'id', ch.id, 'name', ch.name, 'avatar', ch.avatar,
      'questions', c.q, 'right_pct', round(100.0 * c.rf / nullif(c.q, 0)), 'hints', c.h,
      'game', w.game, 'skill', w.skill, 'subject', w.subject,
      'game_right_pct', round(100.0 * w.rf / nullif(w.q, 0)), 'game_hints', w.h) as x
      from c
      join public.children ch on ch.id = c.child_id
      cross join lateral (
        select g.game, g.skill, g.subject, g.q, g.rf, g.h from g
         where g.child_id = c.child_id
         order by (g.rf::numeric / nullif(g.q, 0)) asc nulls last, g.h desc
         limit 1) w
     where (c.q >= 5 and c.rf::numeric / nullif(c.q, 0) < 0.5) or c.h >= 3
     order by (c.rf::numeric / nullif(c.q, 0)) asc nulls last, c.h desc
     limit 5) q), '[]'::json);
end $$;

-- ---------------------------------------------------------------------
-- 7. Weekly report (shared with parents)
-- ---------------------------------------------------------------------

-- One child's week. Leave p_week_start out for the last 7 days.
create or replace function public.child_week_report(p_token text, p_child_id uuid, p_week_start date default null) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare
  t public.tokens := public._tok(p_token);
  v_day date := coalesce(p_week_start, (now() at time zone 'Africa/Mogadishu')::date - 6);
  v_from timestamptz := v_day::timestamp at time zone 'Africa/Mogadishu';
  v_to   timestamptz := (v_day + 7)::timestamp at time zone 'Africa/Mogadishu';
begin
  if not public._child_ok(t, p_child_id) then raise exception 'not_allowed'; end if;
  return (
    with wk as (
      select * from public.rounds where child_id = p_child_id and played_at >= v_from and played_at < v_to),
    prior as (
      select skill, sum(right_first_time)::numeric / nullif(sum(questions), 0) as pct
        from public.rounds where child_id = p_child_id and played_at < v_from and skill is not null
       group by skill),
    sk as (
      select skill, subject, sum(questions) as q, sum(right_first_time)::numeric / nullif(sum(questions), 0) as pct
        from wk where skill is not null group by skill, subject)
    select json_build_object(
      'child', (select json_build_object('name', c.name, 'avatar', c.avatar, 'class_name', cl.name,
                                         'parent_phone', c.parent_phone)
                  from public.children c left join public.classes cl on cl.id = c.class_id where c.id = p_child_id),
      'teacher_name', (select name from public.teachers where id = t.teacher_id),
      'from', v_day, 'to', v_day + 6,
      'stars', (select coalesce(sum(stars), 0) from wk),
      'stars_spent', (select coalesce(sum(stars_spent), 0) from wk),
      'games', (select count(distinct game) from wk),
      'levels', (select count(*) from wk),
      'right_pct', (select round(100.0 * sum(right_first_time) / nullif(sum(questions), 0)) from wk),
      'minutes', (select coalesce(sum(minutes), 0) from public.sessions
                   where child_id = p_child_id and started_at >= v_from and started_at < v_to),
      -- skills practised this week (at least 3 questions)
      'practised', coalesce((select json_agg(skill order by q desc) from sk where q >= 3), '[]'::json),
      -- of those, skills scoring better than before this week
      'improving', coalesce((select json_agg(s.skill order by s.pct - b.pct desc)
                               from (select * from sk where q >= 3) s join prior b on b.skill = s.skill
                              where s.pct > b.pct), '[]'::json),
      -- the weakest skill this week, for the "try at home" tip
      'practise', (select json_build_object('skill', skill, 'subject', subject)
                     from sk where q >= 3 order by pct asc limit 1)));
end $$;

-- ---------------------------------------------------------------------
-- 8. Pilot evidence (principal: own school; admin: any or all schools)
-- ---------------------------------------------------------------------

create or replace function public._pilot_scope(t public.tokens, p_school_id uuid) returns setof uuid
language sql stable security definer set search_path = public, extensions as $$
  select s.id from public.schools s
   where (t.role = 'principal' and s.id = t.school_id)
      or (t.role = 'admin' and (p_school_id is null or s.id = p_school_id));
$$;

-- Baseline compared with the latest later assessment (endline, else midline),
-- for children who have both. Time learning since p_from (default: first session).
create or replace function public.pilot_summary(p_token text, p_school_id uuid default null, p_from date default null) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare t public.tokens := public._tok(p_token);
begin
  if t.role not in ('principal','admin') then raise exception 'not_allowed'; end if;
  return (
    with kids as (
      select c.id, c.school_id, cl.name as class_name, cl.sort_order
        from public.children c left join public.classes cl on cl.id = c.class_id
       where c.school_id in (select public._pilot_scope(t, p_school_id))),
    base as (
      select a.* from public.assessments a join kids k on k.id = a.child_id where a.kind = 'baseline'),
    latest as (
      select distinct on (a.child_id) a.* from public.assessments a join kids k on k.id = a.child_id
       where a.kind in ('midline','endline')
       order by a.child_id, (a.kind = 'endline') desc, a.done_at desc),
    pair as (
      select k.id, k.class_name, k.sort_order,
             b.score::numeric / b.total as b_pct, l.score::numeric / l.total as l_pct,
             b.maths_score::numeric / nullif(b.maths_total, 0) as b_m, l.maths_score::numeric / nullif(l.maths_total, 0) as l_m,
             b.english_score::numeric / nullif(b.english_total, 0) as b_e, l.english_score::numeric / nullif(l.english_total, 0) as l_e
        from kids k join base b on b.child_id = k.id join latest l on l.child_id = k.id),
    ses as (
      select se.* from public.sessions se join kids k on k.id = se.child_id
       where p_from is null or se.started_at >= (p_from::timestamp at time zone 'Africa/Mogadishu')),
    span as (
      select greatest(1.0, extract(epoch from (now() - min(started_at))) / 604800.0) as weeks from ses)
    select json_build_object(
      'children', (select count(*) from kids),
      'schools', (select count(distinct school_id) from kids),
      'teachers', (select count(*) from public.teachers where school_id in (select public._pilot_scope(t, p_school_id))),
      'with_baseline', (select count(*) from base),
      'with_both', (select count(*) from pair),
      'baseline_pct', (select round(100 * avg(b.score::numeric / b.total)) from base b),
      'latest_pct', (select round(100 * avg(l_pct)) from pair),
      'paired_baseline_pct', (select round(100 * avg(b_pct)) from pair),
      'change_pts', (select round(100 * avg(l_pct - b_pct)) from pair),
      'improved_pct', (select round(100.0 * count(*) filter (where l_pct > b_pct) / nullif(count(*), 0)) from pair),
      'minutes_per_child_per_week', (select round(coalesce(sum(minutes), 0) / nullif((select count(*) from kids), 0)
                                            / (select weeks from span)) from ses),
      'by_subject', json_build_array(
         json_build_object('subject', 'maths',
           'baseline_pct', (select round(100 * avg(b_m)) from pair where b_m is not null and l_m is not null),
           'latest_pct',   (select round(100 * avg(l_m)) from pair where b_m is not null and l_m is not null)),
         json_build_object('subject', 'english',
           'baseline_pct', (select round(100 * avg(b_e)) from pair where b_e is not null and l_e is not null),
           'latest_pct',   (select round(100 * avg(l_e)) from pair where b_e is not null and l_e is not null))),
      'by_class', coalesce((select json_agg(x order by x->>'sort', x->>'class') from (
         select json_build_object(
           'class', coalesce(k.class_name, 'No class'), 'sort', lpad(coalesce(k.sort_order, 99)::text, 3, '0'),
           'children', count(*),
           'with_both', count(p.id),
           'baseline_pct', round(100 * avg(p.b_pct)),
           'latest_pct', round(100 * avg(p.l_pct)),
           'change_pts', round(100 * avg(p.l_pct - p.b_pct)),
           'played_this_week', count(*) filter (where exists (
              select 1 from public.sessions se where se.child_id = k.id and se.started_at >= now() - interval '7 days'))) as x
         from kids k left join pair p on p.id = k.id
         group by k.class_name, k.sort_order) q), '[]'::json)));
end $$;

-- One row per child for funders: no names, only the child code.
create or replace function public.pilot_export(p_token text, p_school_id uuid default null) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare t public.tokens := public._tok(p_token);
begin
  if t.role not in ('principal','admin') then raise exception 'not_allowed'; end if;
  return coalesce((select json_agg(x order by x->>'school', x->>'class', x->>'child_code') from (
    select json_build_object(
      'child_code', c.child_code, 'school', s.name, 'class', cl.name, 'age', c.age,
      'expected_group', c.expected_group,
      'baseline_score', b.score, 'baseline_total', b.total,
      'baseline_maths', b.maths_score, 'baseline_maths_total', b.maths_total,
      'baseline_english', b.english_score, 'baseline_english_total', b.english_total,
      'midline_score', m.score, 'midline_total', m.total,
      'endline_score', e.score, 'endline_total', e.total,
      'endline_maths', e.maths_score, 'endline_maths_total', e.maths_total,
      'endline_english', e.english_score, 'endline_english_total', e.english_total,
      'sessions', (select count(*) from public.sessions se where se.child_id = c.id),
      'minutes', (select coalesce(sum(se.minutes), 0) from public.sessions se where se.child_id = c.id),
      'levels_played', (select count(*) from public.rounds r where r.child_id = c.id),
      'right_first_time_pct', (select round(100.0 * sum(r.right_first_time) / nullif(sum(r.questions), 0))
                                 from public.rounds r where r.child_id = c.id),
      'hints_used', (select coalesce(sum(r.hints_used), 0) from public.rounds r where r.child_id = c.id)) as x
    from public.children c
    join public.schools s on s.id = c.school_id
    left join public.classes cl on cl.id = c.class_id
    left join public.assessments b on b.child_id = c.id and b.kind = 'baseline'
    left join public.assessments m on m.child_id = c.id and m.kind = 'midline'
    left join public.assessments e on e.child_id = c.id and e.kind = 'endline'
    where c.school_id in (select public._pilot_scope(t, p_school_id))) q), '[]'::json);
end $$;

-- ---------------------------------------------------------------------
-- 9. Who can call what
-- ---------------------------------------------------------------------

revoke execute on function public._pilot_scope(public.tokens, uuid) from public, anon, authenticated;

revoke execute on function
  public.add_child(text, uuid, text, int, text, text, text, text),
  public.update_child(text, uuid, text, text, text),
  public.save_assessment(text, uuid, text, int, int, int, int),
  public.record_round(text, uuid, uuid, text, text, text, int, int, int, int, jsonb, timestamptz, int, int),
  public.class_needs_help(text, uuid),
  public.child_week_report(text, uuid, date),
  public.pilot_summary(text, uuid, date),
  public.pilot_export(text, uuid)
from public;

grant execute on function
  public.add_child(text, uuid, text, int, text, text, text, text),
  public.update_child(text, uuid, text, text, text),
  public.save_assessment(text, uuid, text, int, int, int, int),
  public.record_round(text, uuid, uuid, text, text, text, int, int, int, int, jsonb, timestamptz, int, int),
  public.class_needs_help(text, uuid),
  public.child_week_report(text, uuid, date),
  public.pilot_summary(text, uuid, date),
  public.pilot_export(text, uuid)
to anon, authenticated;

commit;

-- Done. Quick check (optional), in a new query:
--   select count(*) from public.assessments;            -- baselines copied in
--   select child_code, theme from public.children limit 5;
