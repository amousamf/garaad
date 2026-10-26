-- =====================================================================
-- Garaad database update 7: the principal is the school admin
-- =====================================================================
-- Run once in Supabase: SQL Editor > New query > paste all > Run.
-- Safe to run again.
--
-- What changes:
--   * A principal manages their own school, and only their own school:
--       - teachers: see them all, reset a teacher's PIN, remove a teacher
--         who left (they can no longer log in) or bring them back;
--       - children: change a child's name or class, or remove a child
--         (their scores go with them);
--       - dashboard: pilot results for their school, as before.
--     A principal cannot change another principal or themselves; only the
--     Garaad admin can.
--   * The Garaad admin (the overall admin) keeps everything else: creating
--     schools and classes, families, settings, all schools' results, and
--     choosing who is a principal. The admin can also remove or bring back
--     any teacher.
--   * Removed teachers stay in the records (their sessions keep their name)
--     but cannot log in, register again with the same number, or set a PIN.
-- =====================================================================

begin;

alter table public.teachers add column if not exists active boolean not null default true;

-- ---------------------------------------------------------------------
-- Logins: a removed teacher cannot log in, set a PIN or register again
-- ---------------------------------------------------------------------

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
  if not tr.active then return json_build_object('ok', false, 'error', 'teacher_removed'); end if;
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

create or replace function public.teacher_set_new_pin(p_school_code text, p_phone text, p_new_pin text) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare s public.schools; tr public.teachers; v_phone text;
begin
  select * into s from public.schools where code = upper(trim(p_school_code));
  if not found then return json_build_object('ok', false, 'error', 'school_not_found'); end if;
  begin v_phone := public._phone(p_phone);
  exception when others then return json_build_object('ok', false, 'error', 'bad_phone'); end;
  select * into tr from public.teachers where school_id = s.id and phone = v_phone;
  if found and not tr.active then return json_build_object('ok', false, 'error', 'teacher_removed'); end if;
  if not found or tr.pin_hash is not null then return json_build_object('ok', false, 'error', 'no_reset_pending'); end if;
  if p_new_pin !~ '^[0-9]{4}$' then return json_build_object('ok', false, 'error', 'pin_must_be_4_digits'); end if;
  update public.teachers set pin_hash = extensions.crypt(p_new_pin, extensions.gen_salt('bf')),
         failed_attempts = 0, locked_until = null, last_login_at = now() where id = tr.id;
  return json_build_object('ok', true, 'role', tr.role, 'name', tr.name, 'school', s.name,
    'token', public._issue(tr.role, null, tr.id, null, s.id, 24*30));
end $$;

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
  if exists (select 1 from public.teachers where school_id = s.id and phone = v_phone and not active) then
    return json_build_object('ok', false, 'error', 'teacher_removed');
  end if;
  if exists (select 1 from public.teachers where school_id = s.id and phone = v_phone) then
    return json_build_object('ok', false, 'error', 'phone_already_registered');
  end if;
  insert into public.teachers(school_id, name, phone, pin_hash, last_login_at)
  values (s.id, trim(p_name), v_phone, extensions.crypt(p_pin, extensions.gen_salt('bf')), now())
  returning id into v_id;
  return json_build_object('ok', true, 'role', 'teacher', 'name', trim(p_name), 'school', s.name,
    'token', public._issue('teacher', null, v_id, null, s.id, 24*30));
end $$;

-- ---------------------------------------------------------------------
-- School admin (principal) tools, always limited to the principal's school
-- ---------------------------------------------------------------------

create or replace function public._need_principal(p_token text) returns public.tokens
language plpgsql security definer set search_path = public, extensions as $$
declare t public.tokens := public._tok(p_token);
begin
  if t.role <> 'principal' then raise exception 'principal_only'; end if;
  if not exists (select 1 from public.teachers where id = t.teacher_id and active and role = 'principal') then
    delete from public.tokens where token = p_token;
    raise exception 'invalid_token';
  end if;
  return t;
end $$;

-- The teacher a principal may change: same school, a teacher (not a principal), not themselves.
create or replace function public._school_teacher(t public.tokens, p_teacher_id uuid) returns public.teachers
language plpgsql security definer set search_path = public, extensions as $$
declare tr public.teachers;
begin
  select * into tr from public.teachers where id = p_teacher_id and school_id = t.school_id;
  if not found then raise exception 'not_in_school'; end if;
  if tr.id = t.teacher_id then raise exception 'not_yourself'; end if;
  if tr.role = 'principal' then raise exception 'principal_protected'; end if;
  return tr;
end $$;

create or replace function public.school_overview(p_token text) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare t public.tokens := public._need_principal(p_token);
begin
  return (select json_build_object(
    'school', json_build_object('id', s.id, 'name', s.name, 'code', s.code),
    'classes', coalesce((select json_agg(json_build_object('id', c.id, 'name', c.name) order by c.sort_order)
                         from public.classes c where c.school_id = s.id and c.active), '[]'::json),
    'teachers', coalesce((select json_agg(json_build_object(
        'id', tr.id, 'name', tr.name, 'phone', tr.phone, 'role', tr.role, 'active', tr.active,
        'pin_set', tr.pin_hash is not null, 'last_login', tr.last_login_at, 'me', tr.id = t.teacher_id,
        'children_added', (select count(*) from public.children ch where ch.added_by = tr.id),
        'sessions', (select count(*) from public.sessions se where se.teacher_id = tr.id))
        order by tr.active desc, tr.role desc, tr.name) from public.teachers tr where tr.school_id = s.id), '[]'::json),
    'children', (select count(*) from public.children ch where ch.school_id = s.id))
    from public.schools s where s.id = t.school_id);
end $$;

create or replace function public.school_reset_pin(p_token text, p_teacher_id uuid) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare t public.tokens := public._need_principal(p_token); tr public.teachers := public._school_teacher(t, p_teacher_id);
begin
  update public.teachers set pin_hash = null, failed_attempts = 0, locked_until = null where id = tr.id;
  delete from public.tokens where teacher_id = tr.id;          -- signs the teacher out everywhere
  return json_build_object('ok', true);
end $$;

create or replace function public.school_set_teacher_active(p_token text, p_teacher_id uuid, p_active boolean) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare t public.tokens := public._need_principal(p_token); tr public.teachers := public._school_teacher(t, p_teacher_id);
begin
  update public.teachers set active = coalesce(p_active, true) where id = tr.id;
  if not coalesce(p_active, true) then delete from public.tokens where teacher_id = tr.id; end if;
  return json_build_object('ok', true);
end $$;

create or replace function public.school_edit_child(p_token text, p_child_id uuid, p_name text default null, p_class_id uuid default null) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare t public.tokens := public._need_principal(p_token);
begin
  if not exists (select 1 from public.children where id = p_child_id and school_id = t.school_id) then raise exception 'not_in_school'; end if;
  if p_name is not null and trim(p_name) = '' then return json_build_object('ok', false, 'error', 'name_required'); end if;
  if p_class_id is not null and not exists (select 1 from public.classes where id = p_class_id and school_id = t.school_id and active) then
    return json_build_object('ok', false, 'error', 'bad_class');
  end if;
  update public.children set
    name = coalesce(left(trim(p_name), 40), name),
    class_id = coalesce(p_class_id, class_id)
  where id = p_child_id and school_id = t.school_id;
  return json_build_object('ok', true);
end $$;

create or replace function public.school_remove_child(p_token text, p_child_id uuid) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare t public.tokens := public._need_principal(p_token);
begin
  delete from public.children where id = p_child_id and school_id = t.school_id;   -- sessions and rounds go with it
  if not found then raise exception 'not_in_school'; end if;
  return json_build_object('ok', true);
end $$;

-- ---------------------------------------------------------------------
-- The Garaad admin: sees who was removed, and can remove or bring back anyone
-- ---------------------------------------------------------------------

create or replace function public.admin_set_teacher_active(p_token text, p_teacher_id uuid, p_active boolean) returns json
language plpgsql security definer set search_path = public, extensions as $$
begin
  perform public._need_admin(p_token);
  update public.teachers set active = coalesce(p_active, true) where id = p_teacher_id;
  if not coalesce(p_active, true) then delete from public.tokens where teacher_id = p_teacher_id; end if;
  return json_build_object('ok', true);
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
                       'role', tr.role, 'pin_set', tr.pin_hash is not null, 'last_login', tr.last_login_at, 'active', tr.active)
                       order by tr.active desc, tr.name) from public.teachers tr where tr.school_id = s.id),
        'children', (select count(*) from public.children ch where ch.school_id = s.id))
      order by s.name) from public.schools s), '[]'::json),
    'families', coalesce((select json_agg(json_build_object(
        'id', f.id, 'name', f.name, 'code', f.code, 'whatsapp', f.whatsapp,
        'country', f.country, 'region', f.region, 'location', f.location,
        'wants_group', f.wants_group, 'blocked', f.blocked,
        'pin_set', f.pin_hash is not null, 'registered', f.whatsapp is not null,
        'created_at', f.created_at, 'last_login', f.last_login_at,
        'children', (select count(*) from public.children ch where ch.family_id = f.id))
      order by f.created_at desc) from public.families f), '[]'::json),
    'settings', (select json_object_agg(key, value) from public.settings));
end $$;

-- ---------------------------------------------------------------------
-- Who may call what: the app calls these with the public key
-- ---------------------------------------------------------------------

revoke execute on function
  public._need_principal(text),
  public._school_teacher(public.tokens, uuid)
from public, anon, authenticated;

revoke execute on function
  public.school_overview(text),
  public.school_reset_pin(text, uuid),
  public.school_set_teacher_active(text, uuid, boolean),
  public.school_edit_child(text, uuid, text, uuid),
  public.school_remove_child(text, uuid),
  public.admin_set_teacher_active(text, uuid, boolean)
from public;

grant execute on function
  public.school_overview(text),
  public.school_reset_pin(text, uuid),
  public.school_set_teacher_active(text, uuid, boolean),
  public.school_edit_child(text, uuid, text, uuid),
  public.school_remove_child(text, uuid),
  public.admin_set_teacher_active(text, uuid, boolean)
to anon, authenticated;

commit;

-- Done. Quick check (optional), in a new query:
--   select proname from pg_proc where proname like 'school\_%' order by 1;
