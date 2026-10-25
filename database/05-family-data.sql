-- =====================================================================
-- Garaad database — update 5: family children and results in the
-- database. Run once, after 01–04. Paste this whole file into
-- Supabase > SQL Editor and press Run. One transaction: if anything
-- fails, nothing changes.
--
-- Adds:
--   * save_family_child: a family phone adds or updates a child, using
--     an id made on the phone, so it also works when the internet comes
--     back later (safe to send twice).
--   * remove_child: a family removes one of its children, with all of
--     that child's sessions and results.
--
-- Family results then use the functions schools already use
-- (open_session, record_round, end_session, save_progress), and a new
-- phone loads the family's children with list_children and child_open.
-- =====================================================================

begin;

create or replace function public.save_family_child(p_token text, p_child_id uuid, p_name text,
  p_age int default null, p_avatar text default null, p_theme text default null) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare t public.tokens := public._tok(p_token);
begin
  if t.role <> 'family' then raise exception 'not_allowed'; end if;
  if coalesce(trim(p_name),'') = '' then return json_build_object('ok', false, 'error', 'name_required'); end if;
  if exists (select 1 from public.children where id = p_child_id and family_id is distinct from t.family_id) then
    raise exception 'not_allowed';
  end if;
  insert into public.children(id, family_id, name, age, avatar, theme)
  values (p_child_id, t.family_id, left(trim(p_name), 60),
          case when p_age between 2 and 18 then p_age end,
          case when p_avatar ~ '^[a-z]{3,12}(-[a-z]{2,12})?$' then p_avatar end,
          case when p_theme in ('savanna','ocean','night') then p_theme else 'savanna' end)
  on conflict (id) do update set
    name   = excluded.name,
    age    = coalesce(excluded.age, public.children.age),
    avatar = coalesce(excluded.avatar, public.children.avatar),
    theme  = excluded.theme;
  return json_build_object('ok', true, 'child_id', p_child_id);
end $$;

create or replace function public.remove_child(p_token text, p_child_id uuid) returns json
language plpgsql security definer set search_path = public, extensions as $$
declare t public.tokens := public._tok(p_token);
begin
  if t.role <> 'family' then raise exception 'not_allowed'; end if;
  delete from public.children where id = p_child_id and family_id = t.family_id;   -- sessions and rounds go with it
  return json_build_object('ok', true);
end $$;

revoke execute on function
  public.save_family_child(text, uuid, text, int, text, text),
  public.remove_child(text, uuid)
from public;

grant execute on function
  public.save_family_child(text, uuid, text, int, text, text),
  public.remove_child(text, uuid)
to anon, authenticated;

commit;

-- Done. Quick check (optional), in a new query:
--   select proname from pg_proc where proname in ('save_family_child', 'remove_child');
