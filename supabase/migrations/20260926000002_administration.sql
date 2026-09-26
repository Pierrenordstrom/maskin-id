-- =====================================================================
-- MaskinID – administration
--
-- - Registerhållaren (MaskinID själv) som organisationstyp
-- - Administratörer (profiles.is_admin) som skapar organisationer,
--   bjuder in användare (via Edge Function invite-user) och verifierar
--   maskiners identitet
-- =====================================================================

alter type public.organization_type add value if not exists 'registerhallare';

alter table public.profiles add column if not exists is_admin boolean not null default false;

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce((select is_admin from public.profiles where id = auth.uid()), false)
$$;

create or replace function public.require_admin()
returns public.organizations language plpgsql stable security definer set search_path = '' as $$
declare o public.organizations := public.require_org();
begin
  if not public.is_admin() then
    raise exception 'Bara administratörer kan göra den här ändringen.' using errcode = '42501';
  end if;
  return o;
end $$;

-- my_profile får med isAdmin.
create or replace function public.my_profile()
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('id', p.id, 'email', p.email, 'fullName', p.full_name, 'isAdmin', p.is_admin,
    'organization', jsonb_build_object('id', o.id, 'name', o.name, 'orgNr', o.org_nr, 'type', o.type))
  from public.profiles p join public.organizations o on o.id = p.organization_id
  where p.id = auth.uid()
$$;

-- ---------- Verifiera identitet ----------
create or replace function public.verify_identity(p_machine_id uuid, p_note text default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare o public.organizations := public.require_admin();
begin
  update public.machines set identity_verified = true where id = p_machine_id and not identity_verified;
  if not found then
    if not exists (select 1 from public.machines where id = p_machine_id) then
      raise exception 'Maskinen finns inte i registret.' using errcode = 'P0002';
    end if;
    raise exception 'Identiteten är redan verifierad.' using errcode = '22023';
  end if;
  perform public.log_event(p_machine_id, 'identitet_verifierad',
    'Identiteten verifierades mot typskylt.' || coalesce(' ' || nullif(trim(p_note), ''), ''), o.id);
  return public.machine_record_json(p_machine_id);
end $$;

-- ---------- Organisationer ----------
create or replace function public.admin_create_organization(p_name text, p_org_nr text, p_type public.organization_type)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare x public.organizations;
begin
  perform public.require_admin();
  if nullif(trim(p_name), '') is null then
    raise exception 'Ange organisationens namn.' using errcode = '22023';
  end if;
  if trim(p_org_nr) !~ '^\d{6}-\d{4}$' then
    raise exception 'Ange organisationsnumret som NNNNNN-NNNN.' using errcode = '22023';
  end if;
  if exists (select 1 from public.organizations where org_nr = trim(p_org_nr)) then
    raise exception 'Det finns redan en organisation med organisationsnummer %.', trim(p_org_nr) using errcode = '23505';
  end if;
  insert into public.organizations (name, org_nr, type) values (trim(p_name), trim(p_org_nr), p_type) returning * into x;
  return jsonb_build_object('id', x.id, 'name', x.name, 'orgNr', x.org_nr, 'type', x.type);
end $$;

-- ---------- Användare ----------
create or replace function public.admin_list_users()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  perform public.require_admin();
  return coalesce((
    select jsonb_agg(jsonb_build_object('id', p.id, 'email', p.email, 'fullName', p.full_name, 'isAdmin', p.is_admin,
      'organization', jsonb_build_object('id', o.id, 'name', o.name, 'orgNr', o.org_nr, 'type', o.type),
      'lastSignInAt', u.last_sign_in_at, 'invitedAt', u.invited_at)
      order by o.name, p.full_name)
    from public.profiles p
    join public.organizations o on o.id = p.organization_id
    left join auth.users u on u.id = p.id), '[]'::jsonb);
end $$;

-- Anropas av Edge Function invite-user (med service role) efter att auth-användaren skapats.
-- Kontrollerar att den som bjuder in (p_invited_by) är administratör.
create or replace function public.admin_attach_profile(
  p_invited_by uuid, p_user_id uuid, p_email text, p_full_name text, p_organization_id uuid, p_is_admin boolean)
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  if not coalesce((select is_admin from public.profiles where id = p_invited_by), false) then
    raise exception 'Bara administratörer kan bjuda in användare.' using errcode = '42501';
  end if;
  if not exists (select 1 from public.organizations where id = p_organization_id) then
    raise exception 'Välj en organisation.' using errcode = '22023';
  end if;
  insert into public.profiles (id, email, full_name, organization_id, is_admin)
  values (p_user_id, lower(trim(p_email)), trim(p_full_name), p_organization_id, coalesce(p_is_admin, false))
  on conflict (id) do update set full_name = excluded.full_name, organization_id = excluded.organization_id, is_admin = excluded.is_admin;
  return (select jsonb_build_object('id', p.id, 'email', p.email, 'fullName', p.full_name, 'isAdmin', p.is_admin,
      'organization', jsonb_build_object('id', o.id, 'name', o.name, 'orgNr', o.org_nr, 'type', o.type),
      'lastSignInAt', null, 'invitedAt', now())
    from public.profiles p join public.organizations o on o.id = p.organization_id where p.id = p_user_id);
end $$;

-- ---------- Rättigheter ----------
revoke all on function public.is_admin() from public, anon, authenticated;
revoke all on function public.require_admin() from public, anon, authenticated;
revoke all on function public.admin_attach_profile(uuid, uuid, text, text, uuid, boolean) from public, anon, authenticated;
grant execute on function public.admin_attach_profile(uuid, uuid, text, text, uuid, boolean) to service_role;

grant execute on function public.my_profile()                                                 to authenticated;
grant execute on function public.verify_identity(uuid, text)                                  to authenticated;
grant execute on function public.admin_create_organization(text, text, public.organization_type) to authenticated;
grant execute on function public.admin_list_users()                                           to authenticated;
revoke all on function public.verify_identity(uuid, text) from public, anon;
revoke all on function public.admin_create_organization(text, text, public.organization_type) from public, anon;
revoke all on function public.admin_list_users() from public, anon;
