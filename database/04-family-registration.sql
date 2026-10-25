-- =====================================================================
-- Garaad database — update 4: free family accounts. Run once, after
-- 01, 02 and 03. Paste this whole file into Supabase > SQL Editor and
-- press Run. It runs as one transaction: if anything fails, nothing changes.
--
-- Adds:
--   * Families register themselves for free: parent's name, WhatsApp
--     number, country, region, location, a 4-digit PIN, and whether they
--     want to join the parents' WhatsApp group. No family code needed.
--   * Family login with WhatsApp number + PIN on a new or second phone,
--     with the same lock after 5 wrong tries as teachers.
--   * Admin: see every family, reset a family PIN, block a fake one.
--   * Settings the admin changes from the app (the parents' WhatsApp
--     group invite link, the admin's WhatsApp number).
--
-- Families that already have a family code keep working as before.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- 1. Families: new columns
-- ---------------------------------------------------------------------

alter table public.families alter column code drop not null;   -- registered families have no code

alter table public.families
  add column if not exists whatsapp        text,
  add column if not exists country         text,               -- ISO code, e.g. SO
  add column if not exists region          text,               -- region name
  add column if not exists location        text,               -- typed by the parent
  add column if not exists wants_group     boolean not null default false,
  add column if not exists pin_hash        text,
  add column if not exists failed_attempts int not null default 0,
  add column if not exists locked_until    timestamptz,
  add column if not exists blocked         boolean not null default false,
  add column if not exists last_login_at   timestamptz;

do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'families_whatsapp_key') then
    alter table public.families add constraint families_whatsapp_key unique (whatsapp);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'families_country_check') then
    alter table public.families add constraint families_country_check
      check (country is null or country ~ '^[A-Z]{2}$');
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 2. Settings the admin can change from the app
-- ---------------------------------------------------------------------

create table if not exists public.settings (
  key        text primary key,
  value      text,
  updated_at timestamptz not null default now()
);
alter table public.settings enable row level security;
revoke all on public.settings from anon, authenticated;

insert into public.settings(key, value) values
  ('parents_group_link', null),
  ('admin_whatsapp', null)
on conflict (key) do nothing;

-- ---------------------------------------------------------------------
-- 3. Helpers
-- ---------------------------------------------------------------------

-- A WhatsApp number in international form: +<country code><number>.
-- p_dial is the country's dialling code (e.g. '+252'); p_number is what
-- the parent typed (a leading 0 or a repeated country code is dropped).
create or replace function public._wa(p_dial text, p_number text) returns text
language plpgsql immutable set search_path = public, extensions as $$
declare
  d text := regexp_replace(coalesce(p_dial,''), '[^0-9]', '', 'g');
  n text := regexp_replace(coalesce(p_number,''), '[^0-9]', '', 'g');
begin
  if d = '' or length(d) > 4 then raise exception 'bad_phone'; end if;
  if n like '00' || d || '%' then n := substr(n, length(d) + 3);
  elsif n like d || '%' and length(n) > length(d) + 6 then n := substr(n, length(d) + 1); end if;
  n := ltrim(n, '0');
  if length(n) < 6 or length(d || n) > 15 then raise exception 'bad_phone'; end if;
  return '+' || d || n;
end $$;

create or replace function public._family_json(f public.families) returns json
language sql stable security definer set search_path = public, extensions as $$
  select json_build_object('ok', true, 'role', 'family', 'name', f.name,
    'whatsapp', f.whatsapp, 'wants_group', f.wants_group,
    'token', public._issue('family', null, null, f.id, null, 24*365));
$$;

-- ---------------------------------------------------------------------
-- 4. Register, log in, set a new PIN after a reset
-- ---------------------------------------------------------------------

create or replace function public.register_family(p_name text, p_dial text, p_number text,
  p_country text, p_region text, p_location text, p_pin text, p_wants_group boolean default false) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare v_wa text; f public.families;
begin
  if coalesce(trim(p_name),'') = '' then return json_build_object('ok', false, 'error', 'name_required'); end if;
  if coalesce(p_country,'') !~ '^[A-Za-z]{2}$' then return json_build_object('ok', false, 'error', 'country_required'); end if;
  if coalesce(trim(p_region),'') = '' then return json_build_object('ok', false, 'error', 'region_required'); end if;
  if coalesce(trim(p_location),'') = '' then return json_build_object('ok', false, 'error', 'location_required'); end if;
  if p_pin !~ '^[0-9]{4}$' then return json_build_object('ok', false, 'error', 'pin_must_be_4_digits'); end if;
  begin v_wa := public._wa(p_dial, p_number);
  exception when others then return json_build_object('ok', false, 'error', 'bad_whatsapp'); end;
  if exists (select 1 from public.families where whatsapp = v_wa) then
    return json_build_object('ok', false, 'error', 'whatsapp_already_registered');
  end if;
  insert into public.families(name, whatsapp, country, region, location, wants_group, pin_hash, last_login_at)
  values (left(trim(p_name), 80), v_wa, upper(p_country), left(trim(p_region), 80), left(trim(p_location), 120),
          coalesce(p_wants_group, false), extensions.crypt(p_pin, extensions.gen_salt('bf')), now())
  returning * into f;
  return public._family_json(f);
end $$;

create or replace function public.family_phone_login(p_dial text, p_number text, p_pin text) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare v_wa text; f public.families;
begin
  begin v_wa := public._wa(p_dial, p_number);
  exception when others then return json_build_object('ok', false, 'error', 'bad_whatsapp'); end;
  select * into f from public.families where whatsapp = v_wa;
  if not found then return json_build_object('ok', false, 'error', 'family_not_registered'); end if;
  if f.blocked then return json_build_object('ok', false, 'error', 'family_blocked'); end if;
  if f.locked_until > now() then return json_build_object('ok', false, 'error', 'locked', 'until', f.locked_until); end if;
  if f.pin_hash is null then return json_build_object('ok', false, 'error', 'pin_reset'); end if;
  if f.pin_hash <> extensions.crypt(p_pin, f.pin_hash) then
    update public.families
       set failed_attempts = failed_attempts + 1,
           locked_until = case when failed_attempts + 1 >= 5 then now() + interval '15 minutes' end
     where id = f.id;
    return json_build_object('ok', false, 'error', 'wrong_pin');
  end if;
  update public.families set failed_attempts = 0, locked_until = null, last_login_at = now() where id = f.id;
  return public._family_json(f);
end $$;

create or replace function public.family_set_new_pin(p_dial text, p_number text, p_new_pin text) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare v_wa text; f public.families;
begin
  begin v_wa := public._wa(p_dial, p_number);
  exception when others then return json_build_object('ok', false, 'error', 'bad_whatsapp'); end;
  select * into f from public.families where whatsapp = v_wa;
  if not found or f.pin_hash is not null then return json_build_object('ok', false, 'error', 'no_reset_pending'); end if;
  if f.blocked then return json_build_object('ok', false, 'error', 'family_blocked'); end if;
  if p_new_pin !~ '^[0-9]{4}$' then return json_build_object('ok', false, 'error', 'pin_must_be_4_digits'); end if;
  update public.families set pin_hash = extensions.crypt(p_new_pin, extensions.gen_salt('bf')),
         failed_attempts = 0, locked_until = null, last_login_at = now() where id = f.id
  returning * into f;
  return public._family_json(f);
end $$;

-- Family codes keep working, unless the family has been blocked.
create or replace function public.family_login(p_family_code text) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare f public.families;
begin
  select * into f from public.families where code = upper(trim(p_family_code));
  if not found then return json_build_object('ok', false, 'error', 'family_not_found'); end if;
  if f.blocked then return json_build_object('ok', false, 'error', 'family_blocked'); end if;
  return json_build_object('ok', true, 'role', 'family', 'name', f.name,
    'token', public._issue('family', null, null, f.id, null, 24*365));
end $$;

-- What any phone may read: the group invite link and the admin's number.
create or replace function public.public_settings() returns json
language sql stable security definer set search_path = public, extensions as $$
  select json_build_object(
    'parents_group_link', (select value from public.settings where key = 'parents_group_link'),
    'admin_whatsapp',     (select value from public.settings where key = 'admin_whatsapp'));
$$;

-- ---------------------------------------------------------------------
-- 5. Admin
-- ---------------------------------------------------------------------

-- admin_overview now lists each family's details too.
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

create or replace function public.admin_reset_family_pin(p_token text, p_family_id uuid) returns json
language plpgsql security definer set search_path = public, extensions as $$
begin
  perform public._need_admin(p_token);
  update public.families set pin_hash = null, failed_attempts = 0, locked_until = null
   where id = p_family_id and whatsapp is not null;
  return json_build_object('ok', true);
end $$;

-- Block (or unblock) a fake registration. Blocking signs the family out everywhere.
create or replace function public.admin_block_family(p_token text, p_family_id uuid, p_blocked boolean) returns json
language plpgsql security definer set search_path = public, extensions as $$
begin
  perform public._need_admin(p_token);
  update public.families set blocked = coalesce(p_blocked, true) where id = p_family_id;
  if coalesce(p_blocked, true) then delete from public.tokens where family_id = p_family_id; end if;
  return json_build_object('ok', true);
end $$;

create or replace function public.admin_set_setting(p_token text, p_key text, p_value text) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare v text := nullif(trim(coalesce(p_value,'')), '');
begin
  perform public._need_admin(p_token);
  if p_key not in ('parents_group_link', 'admin_whatsapp') then return json_build_object('ok', false, 'error', 'bad_setting'); end if;
  if p_key = 'parents_group_link' and v is not null and v !~ '^https://(chat\.whatsapp\.com|whatsapp\.com/channel)/' then
    return json_build_object('ok', false, 'error', 'bad_group_link');
  end if;
  if p_key = 'admin_whatsapp' and v is not null then
    v := regexp_replace(v, '[^0-9]', '', 'g');
    if length(v) < 8 or length(v) > 15 then return json_build_object('ok', false, 'error', 'bad_whatsapp'); end if;
  end if;
  update public.settings set value = v, updated_at = now() where key = p_key;
  return json_build_object('ok', true);
end $$;

-- ---------------------------------------------------------------------
-- 6. Who can call what
-- ---------------------------------------------------------------------

revoke execute on function
  public._wa(text, text),
  public._family_json(public.families)
from public, anon, authenticated;

revoke execute on function
  public.register_family(text, text, text, text, text, text, text, boolean),
  public.family_phone_login(text, text, text),
  public.family_set_new_pin(text, text, text),
  public.family_login(text),
  public.public_settings(),
  public.admin_overview(text),
  public.admin_reset_family_pin(text, uuid),
  public.admin_block_family(text, uuid, boolean),
  public.admin_set_setting(text, text, text)
from public;

grant execute on function
  public.register_family(text, text, text, text, text, text, text, boolean),
  public.family_phone_login(text, text, text),
  public.family_set_new_pin(text, text, text),
  public.family_login(text),
  public.public_settings(),
  public.admin_overview(text),
  public.admin_reset_family_pin(text, uuid),
  public.admin_block_family(text, uuid, boolean),
  public.admin_set_setting(text, text, text)
to anon, authenticated;

commit;

-- Done. Quick check (optional), in a new query:
--   select public.public_settings();
--   select column_name from information_schema.columns
--    where table_schema = 'public' and table_name = 'families';
