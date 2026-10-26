-- =====================================================================
-- Garaad database — update 6: Arabic games. Run once, after 01–05.
-- Paste this whole file into Supabase > SQL Editor and press Run.
-- One transaction: if anything fails, nothing changes.
--
-- Adds:
--   * results can be saved with subject 'arabic' (Arabic tab).
--   * a setting 'arabic_schools': when it is 'on', schools see the
--     Arabic tab too. Families always see it. The admin switches it
--     in the app (Admin › Arabic games).
--   * public_settings also returns arabic_schools.
-- =====================================================================
begin;

-- 1. Arabic results
alter table public.rounds drop constraint if exists rounds_subject_check;
alter table public.rounds add constraint rounds_subject_check check (subject in ('maths', 'english', 'arabic'));

-- 2. The schools switch (off until the admin turns it on)
insert into public.settings(key, value) values ('arabic_schools', null)
on conflict (key) do nothing;

create or replace function public.public_settings() returns json
language sql stable security definer set search_path = public, extensions as $$
  select json_build_object(
    'parents_group_link', (select value from public.settings where key = 'parents_group_link'),
    'admin_whatsapp',     (select value from public.settings where key = 'admin_whatsapp'),
    'arabic_schools',     (select value from public.settings where key = 'arabic_schools'));
$$;

create or replace function public.admin_set_setting(p_token text, p_key text, p_value text) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare v text := nullif(trim(coalesce(p_value,'')), '');
begin
  perform public._need_admin(p_token);
  if p_key not in ('parents_group_link', 'admin_whatsapp', 'arabic_schools') then return json_build_object('ok', false, 'error', 'bad_setting'); end if;
  if p_key = 'parents_group_link' and v is not null and v !~ '^https://(chat\.whatsapp\.com|whatsapp\.com/channel)/' then
    return json_build_object('ok', false, 'error', 'bad_group_link');
  end if;
  if p_key = 'admin_whatsapp' and v is not null then
    v := regexp_replace(v, '[^0-9]', '', 'g');
    if length(v) < 8 or length(v) > 15 then return json_build_object('ok', false, 'error', 'bad_whatsapp'); end if;
  end if;
  if p_key = 'arabic_schools' and v is not null and v <> 'on' then
    return json_build_object('ok', false, 'error', 'bad_setting');
  end if;
  update public.settings set value = v, updated_at = now() where key = p_key;
  return json_build_object('ok', true);
end $$;

revoke execute on function public.public_settings(), public.admin_set_setting(text, text, text) from public;
grant execute on function public.public_settings(), public.admin_set_setting(text, text, text) to anon, authenticated;

commit;
