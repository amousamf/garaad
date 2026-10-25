-- =====================================================================
-- Tiri database — update 2. Run once, after 01-schema.sql.
-- Paste into Supabase > SQL Editor and press Run.
--
-- Adds:
--   * children.progress: each child's levels, stars and missed questions,
--     so a child keeps their place whichever teacher's phone they use.
--   * Functions that accept an id made on the phone, so a session and its
--     rounds can be saved later if the internet drops, without duplicates.
-- =====================================================================

alter table public.children add column if not exists progress jsonb not null default '{}'::jsonb;

-- Open a child: profile, class and saved progress.
create or replace function public.child_open(p_token text, p_child_id uuid) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare t public.tokens := public._tok(p_token);
begin
  if not public._child_ok(t, p_child_id) then raise exception 'not_allowed'; end if;
  return (select json_build_object(
      'id', c.id, 'name', c.name, 'age', c.age, 'expected_group', c.expected_group,
      'class_id', c.class_id, 'class_name', cl.name,
      'start_score', c.start_score, 'start_total', c.start_total, 'start_done_at', c.start_done_at,
      'progress', c.progress)
    from public.children c left join public.classes cl on cl.id = c.class_id
    where c.id = p_child_id);
end $$;

-- Save a child's progress (levels unlocked, stars, missed questions to review).
create or replace function public.save_progress(p_token text, p_child_id uuid, p_progress jsonb) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare t public.tokens := public._tok(p_token);
begin
  if t.role = 'principal' or not public._child_ok(t, p_child_id) then raise exception 'not_allowed'; end if;
  update public.children set progress = coalesce(p_progress, '{}'::jsonb) where id = p_child_id;
  return json_build_object('ok', true);
end $$;

-- Start a session with an id made on the phone. Safe to send twice.
create or replace function public.open_session(p_token text, p_session_id uuid, p_child_id uuid,
  p_task_type text default 'in_class', p_started_at timestamptz default null) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare t public.tokens := public._tok(p_token);
begin
  if t.role = 'principal' or not public._child_ok(t, p_child_id) then raise exception 'not_allowed'; end if;
  insert into public.sessions(id, child_id, teacher_id, task_type, started_at)
  values (p_session_id, p_child_id, t.teacher_id,
          case when t.role = 'family' then 'family' else coalesce(p_task_type, 'in_class') end,
          coalesce(p_started_at, now()))
  on conflict (id) do nothing;
  return json_build_object('ok', true);
end $$;

-- Save one finished level with an id made on the phone. Safe to send twice.
create or replace function public.record_round(p_token text, p_round_id uuid, p_session_id uuid,
  p_subject text, p_game text, p_skill text, p_level int, p_questions int, p_right_first_time int,
  p_stars int, p_missed jsonb default '[]'::jsonb, p_played_at timestamptz default null) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare t public.tokens := public._tok(p_token); v_child uuid;
begin
  select child_id into v_child from public.sessions where id = p_session_id;
  if v_child is null or t.role = 'principal' or not public._child_ok(t, v_child) then raise exception 'not_allowed'; end if;
  insert into public.rounds(id, session_id, child_id, subject, game, skill, level, questions, right_first_time, stars, missed, played_at)
  values (p_round_id, p_session_id, v_child, p_subject, p_game, p_skill, p_level, p_questions, p_right_first_time, p_stars,
          coalesce(p_missed, '[]'::jsonb), coalesce(p_played_at, now()))
  on conflict (id) do nothing;
  return json_build_object('ok', true);
end $$;

revoke execute on function public.child_open(text, uuid) from public, anon, authenticated;
revoke execute on function public.save_progress(text, uuid, jsonb) from public, anon, authenticated;
revoke execute on function public.open_session(text, uuid, uuid, text, timestamptz) from public, anon, authenticated;
revoke execute on function public.record_round(text, uuid, uuid, text, text, text, int, int, int, int, jsonb, timestamptz) from public, anon, authenticated;

grant execute on function
  public.child_open(text, uuid),
  public.save_progress(text, uuid, jsonb),
  public.open_session(text, uuid, uuid, text, timestamptz),
  public.record_round(text, uuid, uuid, text, text, text, int, int, int, int, jsonb, timestamptz)
to anon, authenticated;
