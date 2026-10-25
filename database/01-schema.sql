-- =====================================================================
-- Tiri database — version 1 (schools, families, teachers, children,
-- sessions, rounds). Paste this whole file into Supabase > SQL Editor
-- and press Run. It is safe to run on a new, empty project.
--
-- Security model
--   * The web app only holds the publishable key. It can NOT read or
--     write any table directly (row level security is on, no policies).
--   * Everything goes through the functions below, which check a
--     login token first. Teachers see only their school, families only
--     their own children, the principal is read-only.
--   * PINs are stored scrambled (bcrypt). The admin can reset a PIN but
--     never read it. 5 wrong PINs lock that login for 15 minutes.
-- =====================================================================

create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------

create table public.schools (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  code        text not null unique,              -- school code, stored UPPER CASE
  created_at  timestamptz not null default now()
);

create table public.classes (
  id          uuid primary key default gen_random_uuid(),
  school_id   uuid not null references public.schools(id) on delete cascade,
  name        text not null,                     -- KG1, KG2, KG3, Standard 1, Standard 2, ...
  sort_order  int  not null default 0,
  active      boolean not null default true,
  unique (school_id, name)
);

create table public.families (
  id          uuid primary key default gen_random_uuid(),
  name        text,
  code        text not null unique,              -- family code, stored UPPER CASE
  created_at  timestamptz not null default now()
);

create table public.admins (
  id               uuid primary key default gen_random_uuid(),
  name             text not null,
  pin_hash         text not null,
  failed_attempts  int  not null default 0,
  locked_until     timestamptz,
  created_at       timestamptz not null default now()
);

create table public.teachers (
  id               uuid primary key default gen_random_uuid(),
  school_id        uuid not null references public.schools(id) on delete cascade,
  name             text not null,
  phone            text not null,                -- +252XXXXXXXXX
  pin_hash         text,                         -- null = reset by admin, teacher must choose a new PIN
  role             text not null default 'teacher' check (role in ('teacher','principal')),
  failed_attempts  int  not null default 0,
  locked_until     timestamptz,
  last_login_at    timestamptz,
  created_at       timestamptz not null default now(),
  unique (school_id, phone)
);

create table public.children (
  id              uuid primary key default gen_random_uuid(),
  school_id       uuid references public.schools(id)  on delete cascade,
  family_id       uuid references public.families(id) on delete cascade,
  class_id        uuid references public.classes(id)  on delete set null,
  name            text not null,
  age             smallint check (age between 2 and 18),
  expected_group  text check (expected_group in ('very_smart','medium','lowest')),
  start_score     smallint,                      -- starting exercise: questions right
  start_total     smallint,                      -- starting exercise: questions asked
  start_done_at   timestamptz,
  added_by        uuid references public.teachers(id) on delete set null,
  created_at      timestamptz not null default now(),
  check ((school_id is null) <> (family_id is null))   -- belongs to a school OR a family
);

create table public.sessions (
  id          uuid primary key default gen_random_uuid(),
  child_id    uuid not null references public.children(id) on delete cascade,
  teacher_id  uuid references public.teachers(id) on delete set null,
  task_type   text not null default 'in_class' check (task_type in ('in_class','homework','family')),
  started_at  timestamptz not null default now(),
  ended_at    timestamptz,
  minutes     numeric(6,1)
);

create table public.rounds (
  id                uuid primary key default gen_random_uuid(),
  session_id        uuid references public.sessions(id) on delete cascade,
  child_id          uuid not null references public.children(id) on delete cascade,
  subject           text not null check (subject in ('maths','english')),
  game              text not null,               -- game id, e.g. count, erhyme
  skill             text,                        -- e.g. Counting, Sound play, Reading
  level             smallint,
  questions         smallint,
  right_first_time  smallint,
  stars             smallint check (stars between 0 and 3),
  missed            jsonb not null default '[]'::jsonb,
  played_at         timestamptz not null default now()
);

create table public.tokens (
  token       text primary key,
  role        text not null check (role in ('admin','teacher','principal','family')),
  admin_id    uuid references public.admins(id)   on delete cascade,
  teacher_id  uuid references public.teachers(id) on delete cascade,
  family_id   uuid references public.families(id) on delete cascade,
  school_id   uuid references public.schools(id)  on delete cascade,
  expires_at  timestamptz not null,
  created_at  timestamptz not null default now()
);

create index on public.classes  (school_id);
create index on public.teachers (school_id);
create index on public.children (school_id, class_id);
create index on public.children (family_id);
create index on public.sessions (child_id);
create index on public.sessions (teacher_id);
create index on public.rounds   (child_id);
create index on public.rounds   (session_id);
create index on public.tokens   (expires_at);

-- Lock every table: the app reaches data only through the functions below.
alter table public.schools  enable row level security;
alter table public.classes  enable row level security;
alter table public.families enable row level security;
alter table public.admins   enable row level security;
alter table public.teachers enable row level security;
alter table public.children enable row level security;
alter table public.sessions enable row level security;
alter table public.rounds   enable row level security;
alter table public.tokens   enable row level security;
revoke all on all tables in schema public from anon, authenticated;

-- ---------------------------------------------------------------------
-- Internal helpers (not callable from the app)
-- ---------------------------------------------------------------------

create or replace function public._phone(p text) returns text
language plpgsql immutable set search_path = public, extensions as $$
declare v text := regexp_replace(coalesce(p,''), '[^0-9]', '', 'g');
begin
  if v like '252%' then v := substr(v, 4); end if;
  v := ltrim(v, '0');
  if v !~ '^[0-9]{7,9}$' then raise exception 'bad_phone'; end if;
  return '+252' || v;
end $$;

create or replace function public._tok(p_token text) returns public.tokens
language plpgsql security definer set search_path = public, extensions as $$
declare t public.tokens;
begin
  select * into t from public.tokens where token = p_token and expires_at > now();
  if not found then raise exception 'invalid_token'; end if;
  return t;
end $$;

create or replace function public._issue(p_role text, p_admin uuid, p_teacher uuid,
  p_family uuid, p_school uuid, p_hours int) returns text
language plpgsql security definer set search_path = public, extensions as $$
declare v text := encode(extensions.gen_random_bytes(32), 'hex');
begin
  delete from public.tokens where expires_at < now();
  insert into public.tokens(token, role, admin_id, teacher_id, family_id, school_id, expires_at)
  values (v, p_role, p_admin, p_teacher, p_family, p_school, now() + make_interval(hours => p_hours));
  return v;
end $$;

create or replace function public._child_ok(t public.tokens, p_child uuid) returns boolean
language sql stable security definer set search_path = public, extensions as $$
  select exists (
    select 1 from public.children c
    where c.id = p_child
      and ( (t.role in ('teacher','principal') and c.school_id = t.school_id)
         or (t.role = 'family' and c.family_id = t.family_id)
         or  t.role = 'admin'));
$$;

-- Create a school with its first five classes. Run from the SQL Editor:
--   select public._create_school('Aran School', 'ARAN');
create or replace function public._create_school(p_name text, p_code text) returns uuid
language plpgsql security definer set search_path = public, extensions as $$
declare v uuid;
begin
  insert into public.schools(name, code) values (trim(p_name), upper(trim(p_code))) returning id into v;
  insert into public.classes(school_id, name, sort_order) values
    (v,'KG1',1),(v,'KG2',2),(v,'KG3',3),(v,'Standard 1',4),(v,'Standard 2',5);
  return v;
end $$;

-- Create the admin login. Run ONCE from the SQL Editor (PIN: 6+ digits):
--   select public.admin_setup('Abdifatah', 'your-admin-pin');
create or replace function public.admin_setup(p_name text, p_pin text) returns text
language plpgsql security definer set search_path = public, extensions as $$
begin
  if exists (select 1 from public.admins) then raise exception 'admin_exists'; end if;
  if p_pin !~ '^[0-9]{6,}$' then raise exception 'admin_pin_needs_6_digits'; end if;
  insert into public.admins(name, pin_hash) values (p_name, extensions.crypt(p_pin, extensions.gen_salt('bf')));
  return 'admin created';
end $$;

-- ---------------------------------------------------------------------
-- Logins (return {ok:true,...} or {ok:false,error:'...'})
-- ---------------------------------------------------------------------

create or replace function public.school_check(p_school_code text) returns json
language sql stable security definer set search_path = public, extensions as $$
  select coalesce(
    (select json_build_object('ok', true, 'school', name) from public.schools where code = upper(trim(p_school_code))),
    json_build_object('ok', false, 'error', 'school_not_found'));
$$;

create or replace function public.teacher_register(p_school_code text, p_name text, p_phone text, p_pin text) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare s public.schools; v_phone text; v_id uuid;
begin
  select * into s from public.schools where code = upper(trim(p_school_code));
  if not found then return json_build_object('ok', false, 'error', 'school_not_found'); end if;
  if coalesce(trim(p_name),'') = '' then return json_build_object('ok', false, 'error', 'name_required'); end if;
  if p_pin !~ '^[0-9]{4}$' then return json_build_object('ok', false, 'error', 'pin_must_be_4_digits'); end if;
  begin v_phone := public._phone(p_phone);
  exception when others then return json_build_object('ok', false, 'error', 'bad_phone'); end;
  if exists (select 1 from public.teachers where school_id = s.id and phone = v_phone) then
    return json_build_object('ok', false, 'error', 'phone_already_registered');
  end if;
  insert into public.teachers(school_id, name, phone, pin_hash, last_login_at)
  values (s.id, trim(p_name), v_phone, extensions.crypt(p_pin, extensions.gen_salt('bf')), now())
  returning id into v_id;
  return json_build_object('ok', true, 'role', 'teacher', 'name', trim(p_name), 'school', s.name,
    'token', public._issue('teacher', null, v_id, null, s.id, 24*30));
end $$;

create or replace function public.teacher_login(p_school_code text, p_phone text, p_pin text) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare s public.schools; tr public.teachers; v_phone text;
begin
  select * into s from public.schools where code = upper(trim(p_school_code));
  if not found then return json_build_object('ok', false, 'error', 'school_not_found'); end if;
  begin v_phone := public._phone(p_phone);
  exception when others then return json_build_object('ok', false, 'error', 'bad_phone'); end;
  select * into tr from public.teachers where school_id = s.id and phone = v_phone;
  if not found then return json_build_object('ok', false, 'error', 'teacher_not_found'); end if;
  if tr.locked_until > now() then return json_build_object('ok', false, 'error', 'locked', 'until', tr.locked_until); end if;
  if tr.pin_hash is null then return json_build_object('ok', false, 'error', 'pin_reset'); end if;
  if tr.pin_hash <> extensions.crypt(p_pin, tr.pin_hash) then
    update public.teachers
       set failed_attempts = failed_attempts + 1,
           locked_until = case when failed_attempts + 1 >= 5 then now() + interval '15 minutes' end
     where id = tr.id;
    return json_build_object('ok', false, 'error', 'wrong_pin');
  end if;
  update public.teachers set failed_attempts = 0, locked_until = null, last_login_at = now() where id = tr.id;
  return json_build_object('ok', true, 'role', tr.role, 'name', tr.name, 'school', s.name,
    'token', public._issue(tr.role, null, tr.id, null, s.id, 24*30));
end $$;

-- After an admin reset, the teacher chooses a new PIN here.
create or replace function public.teacher_set_new_pin(p_school_code text, p_phone text, p_new_pin text) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare s public.schools; tr public.teachers; v_phone text;
begin
  select * into s from public.schools where code = upper(trim(p_school_code));
  if not found then return json_build_object('ok', false, 'error', 'school_not_found'); end if;
  begin v_phone := public._phone(p_phone);
  exception when others then return json_build_object('ok', false, 'error', 'bad_phone'); end;
  select * into tr from public.teachers where school_id = s.id and phone = v_phone;
  if not found or tr.pin_hash is not null then return json_build_object('ok', false, 'error', 'no_reset_pending'); end if;
  if p_new_pin !~ '^[0-9]{4}$' then return json_build_object('ok', false, 'error', 'pin_must_be_4_digits'); end if;
  update public.teachers set pin_hash = extensions.crypt(p_new_pin, extensions.gen_salt('bf')),
         failed_attempts = 0, locked_until = null, last_login_at = now() where id = tr.id;
  return json_build_object('ok', true, 'role', tr.role, 'name', tr.name, 'school', s.name,
    'token', public._issue(tr.role, null, tr.id, null, s.id, 24*30));
end $$;

create or replace function public.teacher_change_pin(p_token text, p_old_pin text, p_new_pin text) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare t public.tokens := public._tok(p_token); tr public.teachers;
begin
  select * into tr from public.teachers where id = t.teacher_id;
  if not found then return json_build_object('ok', false, 'error', 'not_a_teacher'); end if;
  if tr.pin_hash <> extensions.crypt(p_old_pin, tr.pin_hash) then return json_build_object('ok', false, 'error', 'wrong_pin'); end if;
  if p_new_pin !~ '^[0-9]{4}$' then return json_build_object('ok', false, 'error', 'pin_must_be_4_digits'); end if;
  update public.teachers set pin_hash = extensions.crypt(p_new_pin, extensions.gen_salt('bf')) where id = tr.id;
  return json_build_object('ok', true);
end $$;

create or replace function public.family_login(p_family_code text) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare f public.families;
begin
  select * into f from public.families where code = upper(trim(p_family_code));
  if not found then return json_build_object('ok', false, 'error', 'family_not_found'); end if;
  return json_build_object('ok', true, 'role', 'family', 'name', f.name,
    'token', public._issue('family', null, null, f.id, null, 24*365));
end $$;

create or replace function public.admin_login(p_pin text) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare a public.admins;
begin
  select * into a from public.admins limit 1;
  if not found then return json_build_object('ok', false, 'error', 'no_admin'); end if;
  if a.locked_until > now() then return json_build_object('ok', false, 'error', 'locked', 'until', a.locked_until); end if;
  if a.pin_hash <> extensions.crypt(p_pin, a.pin_hash) then
    update public.admins
       set failed_attempts = failed_attempts + 1,
           locked_until = case when failed_attempts + 1 >= 5 then now() + interval '15 minutes' end
     where id = a.id;
    return json_build_object('ok', false, 'error', 'wrong_pin');
  end if;
  update public.admins set failed_attempts = 0, locked_until = null where id = a.id;
  return json_build_object('ok', true, 'role', 'admin', 'name', a.name,
    'token', public._issue('admin', a.id, null, null, null, 12));
end $$;

create or replace function public.logout(p_token text) returns json
language sql security definer set search_path = public, extensions as $$
  delete from public.tokens where token = p_token;
  select json_build_object('ok', true);
$$;

-- ---------------------------------------------------------------------
-- Admin tools
-- ---------------------------------------------------------------------

create or replace function public._need_admin(p_token text) returns public.tokens
language plpgsql security definer set search_path = public, extensions as $$
declare t public.tokens := public._tok(p_token);
begin
  if t.role <> 'admin' then raise exception 'admin_only'; end if;
  return t;
end $$;

create or replace function public.admin_create_school(p_token text, p_name text, p_code text) returns json
language plpgsql security definer set search_path = public, extensions as $$
begin
  perform public._need_admin(p_token);
  if exists (select 1 from public.schools where code = upper(trim(p_code))) then
    return json_build_object('ok', false, 'error', 'code_taken');
  end if;
  return json_build_object('ok', true, 'school_id', public._create_school(p_name, p_code));
end $$;

create or replace function public.admin_add_class(p_token text, p_school_id uuid, p_name text) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare v uuid;
begin
  perform public._need_admin(p_token);
  insert into public.classes(school_id, name, sort_order)
  values (p_school_id, trim(p_name), coalesce((select max(sort_order) + 1 from public.classes where school_id = p_school_id), 1))
  returning id into v;
  return json_build_object('ok', true, 'class_id', v);
end $$;

create or replace function public.admin_create_family(p_token text, p_name text, p_code text) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare v uuid;
begin
  perform public._need_admin(p_token);
  if exists (select 1 from public.families where code = upper(trim(p_code))) then
    return json_build_object('ok', false, 'error', 'code_taken');
  end if;
  insert into public.families(name, code) values (trim(p_name), upper(trim(p_code))) returning id into v;
  return json_build_object('ok', true, 'family_id', v);
end $$;

create or replace function public.admin_overview(p_token text) returns json
language plpgsql security definer set search_path = public, extensions as $$
begin
  perform public._need_admin(p_token);
  return json_build_object(
    'schools', coalesce((select json_agg(json_build_object(
        'id', s.id, 'name', s.name, 'code', s.code,
        'classes',  (select json_agg(c.name order by c.sort_order) from public.classes c where c.school_id = s.id and c.active),
        'teachers', (select json_agg(json_build_object('id', tr.id, 'name', tr.name, 'phone', tr.phone,
                       'role', tr.role, 'pin_set', tr.pin_hash is not null, 'last_login', tr.last_login_at)
                       order by tr.name) from public.teachers tr where tr.school_id = s.id),
        'children', (select count(*) from public.children ch where ch.school_id = s.id))
      order by s.name) from public.schools s), '[]'::json),
    'families', coalesce((select json_agg(json_build_object('id', f.id, 'name', f.name, 'code', f.code) order by f.name)
                          from public.families f), '[]'::json));
end $$;

create or replace function public.admin_reset_pin(p_token text, p_teacher_id uuid) returns json
language plpgsql security definer set search_path = public, extensions as $$
begin
  perform public._need_admin(p_token);
  update public.teachers set pin_hash = null, failed_attempts = 0, locked_until = null where id = p_teacher_id;
  delete from public.tokens where teacher_id = p_teacher_id;      -- signs the teacher out everywhere
  return json_build_object('ok', true);
end $$;

create or replace function public.admin_set_role(p_token text, p_teacher_id uuid, p_role text) returns json
language plpgsql security definer set search_path = public, extensions as $$
begin
  perform public._need_admin(p_token);
  if p_role not in ('teacher','principal') then return json_build_object('ok', false, 'error', 'bad_role'); end if;
  update public.teachers set role = p_role where id = p_teacher_id;
  delete from public.tokens where teacher_id = p_teacher_id;      -- new role applies at next login
  return json_build_object('ok', true);
end $$;

-- ---------------------------------------------------------------------
-- Classes, children, starting exercise
-- ---------------------------------------------------------------------

create or replace function public.list_classes(p_token text) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare t public.tokens := public._tok(p_token);
begin
  return coalesce((select json_agg(json_build_object('id', c.id, 'name', c.name) order by c.sort_order)
                   from public.classes c where c.school_id = t.school_id and c.active), '[]'::json);
end $$;

-- Children in a class (school) or in the family, with optional name search.
create or replace function public.list_children(p_token text, p_class_id uuid default null, p_search text default null) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare t public.tokens := public._tok(p_token);
begin
  return coalesce((select json_agg(x order by x->>'name') from (
    select json_build_object(
      'id', ch.id, 'name', ch.name, 'age', ch.age, 'class_id', ch.class_id,
      'expected_group', ch.expected_group,
      'start_score', ch.start_score, 'start_total', ch.start_total,
      'sessions', (select count(*) from public.sessions se where se.child_id = ch.id),
      'last_played', (select max(r.played_at) from public.rounds r where r.child_id = ch.id)) as x
    from public.children ch
    where ( (t.role in ('teacher','principal') and ch.school_id = t.school_id
              and (p_class_id is null or ch.class_id = p_class_id))
         or (t.role = 'family' and ch.family_id = t.family_id) )
      and (p_search is null or ch.name ilike '%' || p_search || '%')) q), '[]'::json);
end $$;

create or replace function public.add_child(p_token text, p_class_id uuid, p_name text,
  p_age int default null, p_expected_group text default null) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare t public.tokens := public._tok(p_token); v uuid;
begin
  if t.role = 'principal' then raise exception 'read_only'; end if;
  if coalesce(trim(p_name),'') = '' then return json_build_object('ok', false, 'error', 'name_required'); end if;
  if t.role = 'teacher' then
    if not exists (select 1 from public.classes where id = p_class_id and school_id = t.school_id) then
      return json_build_object('ok', false, 'error', 'bad_class');
    end if;
    insert into public.children(school_id, class_id, name, age, expected_group, added_by)
    values (t.school_id, p_class_id, trim(p_name), p_age, p_expected_group, t.teacher_id) returning id into v;
  elsif t.role = 'family' then
    insert into public.children(family_id, name, age) values (t.family_id, trim(p_name), p_age) returning id into v;
  else
    raise exception 'not_allowed';
  end if;
  return json_build_object('ok', true, 'child_id', v);
end $$;

create or replace function public.save_start_score(p_token text, p_child_id uuid, p_score int, p_total int) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare t public.tokens := public._tok(p_token);
begin
  if t.role = 'principal' or not public._child_ok(t, p_child_id) then raise exception 'not_allowed'; end if;
  update public.children set start_score = p_score, start_total = p_total, start_done_at = now()
   where id = p_child_id and start_done_at is null;              -- the starting exercise is saved once
  return json_build_object('ok', true);
end $$;

-- ---------------------------------------------------------------------
-- Sessions and rounds (what a child plays)
-- ---------------------------------------------------------------------

create or replace function public.start_session(p_token text, p_child_id uuid, p_task_type text default 'in_class') returns json
language plpgsql security definer set search_path = public, extensions as $$
declare t public.tokens := public._tok(p_token); v uuid;
begin
  if t.role = 'principal' or not public._child_ok(t, p_child_id) then raise exception 'not_allowed'; end if;
  insert into public.sessions(child_id, teacher_id, task_type)
  values (p_child_id, t.teacher_id, case when t.role = 'family' then 'family' else coalesce(p_task_type, 'in_class') end)
  returning id into v;
  return json_build_object('ok', true, 'session_id', v);
end $$;

create or replace function public.save_round(p_token text, p_session_id uuid, p_subject text, p_game text,
  p_skill text, p_level int, p_questions int, p_right_first_time int, p_stars int, p_missed jsonb default '[]'::jsonb) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare t public.tokens := public._tok(p_token); v_child uuid;
begin
  select child_id into v_child from public.sessions where id = p_session_id;
  if v_child is null or t.role = 'principal' or not public._child_ok(t, v_child) then raise exception 'not_allowed'; end if;
  insert into public.rounds(session_id, child_id, subject, game, skill, level, questions, right_first_time, stars, missed)
  values (p_session_id, v_child, p_subject, p_game, p_skill, p_level, p_questions, p_right_first_time, p_stars,
          coalesce(p_missed, '[]'::jsonb));
  return json_build_object('ok', true);
end $$;

create or replace function public.end_session(p_token text, p_session_id uuid, p_minutes numeric) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare t public.tokens := public._tok(p_token); v_child uuid;
begin
  select child_id into v_child from public.sessions where id = p_session_id;
  if v_child is null or t.role = 'principal' or not public._child_ok(t, v_child) then raise exception 'not_allowed'; end if;
  update public.sessions set ended_at = now(), minutes = p_minutes where id = p_session_id;
  return json_build_object('ok', true);
end $$;

-- ---------------------------------------------------------------------
-- Teacher area, principal dashboard
-- ---------------------------------------------------------------------

-- One child's full detail: profile plus every round played.
create or replace function public.child_detail(p_token text, p_child_id uuid) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare t public.tokens := public._tok(p_token);
begin
  if not public._child_ok(t, p_child_id) then raise exception 'not_allowed'; end if;
  return json_build_object(
    'child', (select row_to_json(ch) from (
       select c.id, c.name, c.age, c.expected_group, c.start_score, c.start_total, c.start_done_at, cl.name as class_name
       from public.children c left join public.classes cl on cl.id = c.class_id where c.id = p_child_id) ch),
    'rounds', coalesce((select json_agg(r order by r.played_at desc) from (
       select subject, game, skill, level, questions, right_first_time, stars, missed, played_at
       from public.rounds where child_id = p_child_id) r), '[]'::json));
end $$;

-- One row per child. Teacher: children in classes they have worked with. Principal: whole school.
create or replace function public.school_children_summary(p_token text, p_class_id uuid default null) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare t public.tokens := public._tok(p_token);
begin
  if t.role not in ('teacher','principal') then raise exception 'not_allowed'; end if;
  return coalesce((select json_agg(x order by x->>'class', x->>'name') from (
    select json_build_object(
      'id', ch.id, 'name', ch.name, 'age', ch.age, 'class', cl.name, 'expected_group', ch.expected_group,
      'start_score', ch.start_score, 'start_total', ch.start_total,
      'sessions', (select count(*) from public.sessions se where se.child_id = ch.id),
      'minutes',  (select coalesce(sum(se.minutes), 0) from public.sessions se where se.child_id = ch.id),
      'rounds',   (select count(*) from public.rounds r where r.child_id = ch.id),
      'stars',    (select coalesce(sum(r.stars), 0) from public.rounds r where r.child_id = ch.id),
      'maths_pct',   (select round(100.0 * sum(r.right_first_time) / nullif(sum(r.questions), 0))
                      from public.rounds r where r.child_id = ch.id and r.subject = 'maths'),
      'english_pct', (select round(100.0 * sum(r.right_first_time) / nullif(sum(r.questions), 0))
                      from public.rounds r where r.child_id = ch.id and r.subject = 'english'),
      'last_played', (select max(r.played_at) from public.rounds r where r.child_id = ch.id)) as x
    from public.children ch left join public.classes cl on cl.id = ch.class_id
    where ch.school_id = t.school_id
      and (p_class_id is null or ch.class_id = p_class_id)
      and ( t.role = 'principal'
         or ch.class_id in (select c2.class_id from public.children c2 where c2.added_by = t.teacher_id
                            union
                            select c3.class_id from public.sessions s3 join public.children c3 on c3.id = s3.child_id
                            where s3.teacher_id = t.teacher_id))) q), '[]'::json);
end $$;

-- Aggregate table: performance by skill, by class and expected group.
create or replace function public.skills_summary(p_token text, p_class_id uuid default null) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare t public.tokens := public._tok(p_token);
begin
  if t.role not in ('teacher','principal') then raise exception 'not_allowed'; end if;
  return coalesce((select json_agg(x) from (
    select json_build_object(
      'class', cl.name, 'subject', r.subject, 'skill', r.skill, 'expected_group', ch.expected_group,
      'children', count(distinct ch.id), 'rounds', count(*),
      'right_first_time_pct', round(100.0 * sum(r.right_first_time) / nullif(sum(r.questions), 0))) as x
    from public.rounds r
    join public.children ch on ch.id = r.child_id
    left join public.classes cl on cl.id = ch.class_id
    where ch.school_id = t.school_id
      and (p_class_id is null or ch.class_id = p_class_id)
    group by cl.name, cl.sort_order, r.subject, r.skill, ch.expected_group
    order by cl.sort_order, r.subject, r.skill, ch.expected_group) q), '[]'::json);
end $$;

-- ---------------------------------------------------------------------
-- Who can call what: the app (anon key) may call only these functions.
-- ---------------------------------------------------------------------

revoke execute on all functions in schema public from public, anon, authenticated;

grant execute on function
  public.school_check(text),
  public.teacher_register(text, text, text, text),
  public.teacher_login(text, text, text),
  public.teacher_set_new_pin(text, text, text),
  public.teacher_change_pin(text, text, text),
  public.family_login(text),
  public.admin_login(text),
  public.logout(text),
  public.admin_create_school(text, text, text),
  public.admin_add_class(text, uuid, text),
  public.admin_create_family(text, text, text),
  public.admin_overview(text),
  public.admin_reset_pin(text, uuid),
  public.admin_set_role(text, uuid, text),
  public.list_classes(text),
  public.list_children(text, uuid, text),
  public.add_child(text, uuid, text, int, text),
  public.save_start_score(text, uuid, int, int),
  public.start_session(text, uuid, text),
  public.save_round(text, uuid, text, text, text, int, int, int, int, jsonb),
  public.end_session(text, uuid, numeric),
  public.child_detail(text, uuid),
  public.school_children_summary(text, uuid),
  public.skills_summary(text, uuid)
to anon, authenticated;

-- Done. Next, in a NEW query, run these two lines (with your own values):
--   select public.admin_setup('Abdifatah', 'your-admin-pin');   -- 6+ digits
--   select public._create_school('Aran School', 'ARAN');        -- pick Aran's school code
