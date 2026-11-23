-- =====================================================================
-- Garaad database update 9: class tablets and "only today's practice"
-- =====================================================================
-- Run once in Supabase: SQL Editor > New query > paste all > Run.
-- Run it after update 8. Safe to run again. One transaction: if anything
-- fails, nothing changes.
--
-- What it adds:
--   * A class tablet: a teacher turns a tablet into the tablet of one
--     class. Children tap their own owl to play; no PIN for children.
--     The tablet can only open and play the children of that class: it
--     cannot add, change or remove children, or see reports or other
--     classes. To leave tablet mode a teacher logs in on the tablet.
--     A teacher can sign out every tablet of a class at once.
--   * "Only today's practice": when the teacher sets today's practice
--     they can lock it, so children see only that practice, not the
--     other games.
--
-- Nothing already saved is changed.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- 1. Tables
-- ---------------------------------------------------------------------
alter table public.tokens drop constraint if exists tokens_role_check;
alter table public.tokens add constraint tokens_role_check check (role in ('admin','teacher','principal','family','tablet'));
alter table public.tokens add column if not exists class_id uuid references public.classes(id) on delete cascade;
create index if not exists tokens_class_idx on public.tokens (class_id) where class_id is not null;

alter table public.class_practice add column if not exists locked boolean not null default false;

-- ---------------------------------------------------------------------
-- 2. Who may play as a child: as before, plus a class tablet for the
--    children of its own class (and only for playing).
-- ---------------------------------------------------------------------
create or replace function public._play_ok(t public.tokens, p_child uuid) returns boolean
language sql stable security definer set search_path = public, extensions as $$
  select public._child_ok(t, p_child)
      or (t.role = 'tablet' and exists (select 1 from public.children c
                                         where c.id = p_child and c.class_id = t.class_id and c.school_id = t.school_id));
$$;

create or replace function public.child_open(p_token text, p_child_id uuid) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare t public.tokens := public._tok(p_token);
begin
  if not public._play_ok(t, p_child_id) then raise exception 'not_allowed'; end if;
  return (select json_build_object(
      'id', c.id, 'name', c.name, 'age', c.age, 'expected_group', c.expected_group,
      'class_id', c.class_id, 'class_name', cl.name,
      'start_score', c.start_score, 'start_total', c.start_total, 'start_done_at', c.start_done_at,
      'progress', c.progress,
      'avatar', c.avatar, 'theme', c.theme,
      'parent_phone', case when t.role = 'tablet' then null else c.parent_phone end)
    from public.children c left join public.classes cl on cl.id = c.class_id
    where c.id = p_child_id);
end $$;

create or replace function public.open_session(p_token text, p_session_id uuid, p_child_id uuid,
  p_task_type text default 'in_class', p_started_at timestamptz default null) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare t public.tokens := public._tok(p_token);
begin
  if t.role = 'principal' or not public._play_ok(t, p_child_id) then raise exception 'not_allowed'; end if;
  insert into public.sessions(id, child_id, teacher_id, task_type, started_at)
  values (p_session_id, p_child_id, t.teacher_id,
          case when t.role = 'family' then 'family' else coalesce(p_task_type, 'in_class') end,
          coalesce(p_started_at, now()))
  on conflict (id) do nothing;
  return json_build_object('ok', true);
end $$;

create or replace function public.start_session(p_token text, p_child_id uuid, p_task_type text default 'in_class') returns json
language plpgsql security definer set search_path = public, extensions as $$
declare t public.tokens := public._tok(p_token); v uuid;
begin
  if t.role = 'principal' or not public._play_ok(t, p_child_id) then raise exception 'not_allowed'; end if;
  insert into public.sessions(child_id, teacher_id, task_type)
  values (p_child_id, t.teacher_id, case when t.role = 'family' then 'family' else coalesce(p_task_type, 'in_class') end)
  returning id into v;
  return json_build_object('ok', true, 'session_id', v);
end $$;

create or replace function public.end_session(p_token text, p_session_id uuid, p_minutes numeric) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare t public.tokens := public._tok(p_token); v_child uuid;
begin
  select child_id into v_child from public.sessions where id = p_session_id;
  if v_child is null or t.role = 'principal' or not public._play_ok(t, v_child) then raise exception 'not_allowed'; end if;
  update public.sessions set ended_at = now(), minutes = p_minutes where id = p_session_id;
  return json_build_object('ok', true);
end $$;

create or replace function public.record_round(p_token text, p_round_id uuid, p_session_id uuid, p_subject text,
  p_game text, p_skill text, p_level int, p_questions int, p_right_first_time int, p_stars int,
  p_missed jsonb default '[]'::jsonb, p_played_at timestamptz default null,
  p_hints_used int default 0, p_stars_spent int default 0) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare t public.tokens := public._tok(p_token); v_child uuid;
begin
  select child_id into v_child from public.sessions where id = p_session_id;
  if v_child is null or t.role = 'principal' or not public._play_ok(t, v_child) then raise exception 'not_allowed'; end if;
  insert into public.rounds(id, session_id, child_id, subject, game, skill, level, questions, right_first_time, stars,
                            missed, played_at, hints_used, stars_spent)
  values (p_round_id, p_session_id, v_child, p_subject, p_game, p_skill, p_level, p_questions, p_right_first_time, p_stars,
          coalesce(p_missed, '[]'::jsonb), coalesce(p_played_at, now()),
          greatest(coalesce(p_hints_used, 0), 0), greatest(coalesce(p_stars_spent, 0), 0))
  on conflict (id) do nothing;
  return json_build_object('ok', true);
end $$;

create or replace function public.save_round(p_token text, p_session_id uuid, p_subject text, p_game text, p_skill text,
  p_level int, p_questions int, p_right_first_time int, p_stars int, p_missed jsonb default '[]'::jsonb) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare t public.tokens := public._tok(p_token); v_child uuid;
begin
  select child_id into v_child from public.sessions where id = p_session_id;
  if v_child is null or t.role = 'principal' or not public._play_ok(t, v_child) then raise exception 'not_allowed'; end if;
  insert into public.rounds(session_id, child_id, subject, game, skill, level, questions, right_first_time, stars, missed)
  values (p_session_id, v_child, p_subject, p_game, p_skill, p_level, p_questions, p_right_first_time, p_stars,
          coalesce(p_missed, '[]'::jsonb));
  return json_build_object('ok', true);
end $$;

create or replace function public.save_progress(p_token text, p_child_id uuid, p_progress jsonb) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare t public.tokens := public._tok(p_token);
begin
  if t.role = 'principal' or not public._play_ok(t, p_child_id) then raise exception 'not_allowed'; end if;
  update public.children set progress = coalesce(p_progress, '{}'::jsonb) where id = p_child_id;
  return json_build_object('ok', true);
end $$;

-- ---------------------------------------------------------------------
-- 3. Today's practice can be locked ("only this practice")
-- ---------------------------------------------------------------------
drop function if exists public.class_set_practice(text, uuid, text[], text[]);
create or replace function public.class_set_practice(p_token text, p_class_id uuid, p_skills text[], p_games text[],
  p_locked boolean default false) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare t public.tokens := public._tok(p_token); c public.classes := public._school_class(t, p_class_id);
begin
  if coalesce(array_length(p_skills, 1), 0) = 0 then
    delete from public.class_practice where class_id = c.id and day = public._today();
    return json_build_object('ok', true, 'cleared', true);
  end if;
  insert into public.class_practice(class_id, day, skills, games, set_by, locked)
  values (c.id, public._today(), p_skills[1:6], coalesce(p_games[1:12], '{}'), t.teacher_id, coalesce(p_locked, false))
  on conflict (class_id, day) do update set skills = excluded.skills, games = excluded.games, set_by = excluded.set_by,
    locked = excluded.locked, set_at = now();
  return json_build_object('ok', true);
end $$;

-- the practice of a class today, as the app reads it
create or replace function public._practice_json(p_class_id uuid) returns json
language sql stable security definer set search_path = public, extensions as $$
  select json_build_object('games', p.games, 'locked', p.locked,
           'skills', (select json_agg(json_build_object('id', sk.id, 'name', sk.name)) from public.skills sk where sk.id = any(p.skills)))
    from public.class_practice p where p.class_id = p_class_id and p.day = public._today();
$$;

-- School settings: as in update 8, now also for a class tablet (its own class only), with the lock.
create or replace function public.school_options(p_token text) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare t public.tokens := public._tok(p_token);
begin
  if t.role not in ('teacher','principal','tablet') then raise exception 'not_allowed'; end if;
  return (select json_build_object(
    'curriculum', s.curriculum, 'currency', s.currency, 'features', s.features, 'date', public._today(),
    'classes', coalesce((select json_agg(json_build_object('id', c.id, 'name', c.name,
                 'curriculum_class', c.curriculum_class, 'options', c.options) order by c.sort_order)
               from public.classes c where c.school_id = s.id and c.active
                 and (t.role <> 'tablet' or c.id = t.class_id)), '[]'::json),
    'practice', coalesce((select json_object_agg(c.id, public._practice_json(c.id))
               from public.classes c
              where c.school_id = s.id and (t.role <> 'tablet' or c.id = t.class_id)
                and exists (select 1 from public.class_practice p where p.class_id = c.id and p.day = public._today())), '{}'::json))
    from public.schools s where s.id = t.school_id);
end $$;

-- ---------------------------------------------------------------------
-- 4. Class tablets
-- ---------------------------------------------------------------------

-- A teacher (or the principal) turns this device into the tablet of a class. It stays signed in for a school term.
create or replace function public.tablet_start(p_token text, p_class_id uuid) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare t public.tokens := public._tok(p_token); c public.classes := public._school_class(t, p_class_id);
  v text := encode(extensions.gen_random_bytes(32), 'hex');
begin
  delete from public.tokens where expires_at < now();
  insert into public.tokens(token, role, teacher_id, school_id, class_id, expires_at)
  values (v, 'tablet', t.teacher_id, t.school_id, c.id, now() + interval '120 days');
  return json_build_object('ok', true, 'token', v, 'class', json_build_object('id', c.id, 'name', c.name),
    'school', (select name from public.schools where id = t.school_id));
end $$;

-- What the tablet shows: its class, the children (to tap their owl), and today's practice.
create or replace function public.tablet_class(p_token text) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare t public.tokens := public._tok(p_token);
begin
  if t.role <> 'tablet' then raise exception 'not_allowed'; end if;
  return (select json_build_object(
    'school', (select name from public.schools where id = t.school_id),
    'class', json_build_object('id', c.id, 'name', c.name),
    'practice', public._practice_json(c.id),
    'children', coalesce((select json_agg(json_build_object('id', ch.id, 'name', ch.name, 'avatar', ch.avatar, 'theme', ch.theme,
                  'start_done', ch.start_done_at is not null,
                  'played_today', exists (select 1 from public.rounds r where r.child_id = ch.id and r.played_at >= public._at(public._today()))) order by ch.name)
               from public.children ch where ch.class_id = c.id), '[]'::json))
    from public.classes c where c.id = t.class_id);
end $$;

-- How many tablets are signed in for a class, and signing them all out (e.g. a lost tablet).
create or replace function public.class_tablets(p_token text, p_class_id uuid) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare t public.tokens := public._tok(p_token); c public.classes := public._school_class(t, p_class_id);
begin
  return json_build_object('count', (select count(*) from public.tokens where role = 'tablet' and class_id = c.id and expires_at > now()));
end $$;

create or replace function public.class_end_tablets(p_token text, p_class_id uuid) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare t public.tokens := public._tok(p_token); c public.classes := public._school_class(t, p_class_id); n int;
begin
  delete from public.tokens where role = 'tablet' and class_id = c.id;
  get diagnostics n = row_count;
  return json_build_object('ok', true, 'signed_out', n);
end $$;

-- ---------------------------------------------------------------------
-- 5. Who may call what
-- ---------------------------------------------------------------------
revoke execute on function public._play_ok(public.tokens, uuid), public._practice_json(uuid) from public, anon, authenticated;

revoke execute on function
  public.child_open(text, uuid),
  public.open_session(text, uuid, uuid, text, timestamptz),
  public.start_session(text, uuid, text),
  public.end_session(text, uuid, numeric),
  public.record_round(text, uuid, uuid, text, text, text, int, int, int, int, jsonb, timestamptz, int, int),
  public.save_round(text, uuid, text, text, text, int, int, int, int, jsonb),
  public.save_progress(text, uuid, jsonb),
  public.class_set_practice(text, uuid, text[], text[], boolean),
  public.school_options(text),
  public.tablet_start(text, uuid),
  public.tablet_class(text),
  public.class_tablets(text, uuid),
  public.class_end_tablets(text, uuid)
from public;

grant execute on function
  public.child_open(text, uuid),
  public.open_session(text, uuid, uuid, text, timestamptz),
  public.start_session(text, uuid, text),
  public.end_session(text, uuid, numeric),
  public.record_round(text, uuid, uuid, text, text, text, int, int, int, int, jsonb, timestamptz, int, int),
  public.save_round(text, uuid, text, text, text, int, int, int, int, jsonb),
  public.save_progress(text, uuid, jsonb),
  public.class_set_practice(text, uuid, text[], text[], boolean),
  public.school_options(text),
  public.tablet_start(text, uuid),
  public.tablet_class(text),
  public.class_tablets(text, uuid),
  public.class_end_tablets(text, uuid)
to anon, authenticated;

commit;
