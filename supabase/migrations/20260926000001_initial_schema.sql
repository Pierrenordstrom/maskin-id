-- =====================================================================
-- MaskinID – initialt schema
--
-- Princip: alla registertabeller har RLS påslaget UTAN läs-/skrivpolicyer
-- för klienter. All åtkomst sker via RPC-funktioner (security definer)
-- som kontrollerar behörighet, skriver historik och returnerar JSON i
-- exakt den form som frontendens typer (src/lib/types.ts) förväntar sig.
-- Se docs/BACKEND.md.
-- =====================================================================

create extension if not exists pgcrypto;

-- ---------- Typer ----------
create type public.organization_type as enum ('maskinhandlare', 'maskinagare', 'langivare', 'forsakringsgivare');
create type public.block_reason as enum ('stulen', 'avvikelse', 'myndighetsbeslut');
create type public.register_event_kind as enum (
  'maskin_registrerad', 'identitet_verifierad', 'agarbyte',
  'belaning_registrerad', 'belaning_avslutad',
  'forsakring_registrerad', 'forsakring_avslutad',
  'sparr_registrerad', 'sparr_havd', 'utdrag_hamtat'
);

-- Normaliserad jämförelsenyckel för identifierare: versaler, utan mellanslag och bindestreck.
create or replace function public.identifier_key(v text)
returns text language sql immutable as $$
  select nullif(upper(regexp_replace(coalesce(v, ''), '[\s-]', '', 'g')), '')
$$;

-- ---------- Tabeller ----------
create table public.organizations (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  org_nr      text not null unique check (org_nr ~ '^\d{6}-\d{4}$'),
  type        public.organization_type not null,
  created_at  timestamptz not null default now()
);

-- En rad per inloggningsbar användare. Kopplas till auth.users.
create table public.profiles (
  id               uuid primary key references auth.users (id) on delete cascade,
  email            text not null,
  full_name        text not null,
  organization_id  uuid not null references public.organizations (id),
  created_at       timestamptz not null default now()
);
create index on public.profiles (organization_id);

create sequence public.machine_register_seq start 71151;

create table public.machines (
  id                 uuid primary key default gen_random_uuid(),
  register_number    text not null unique
                     default ('MID-' || to_char(now(), 'YYYY') || '-' || lpad(nextval('public.machine_register_seq')::text, 7, '0')),
  pin                text check (pin is null or pin ~ '^[A-Z0-9]{8,17}$'),
  serial_number      text,
  pin_key            text generated always as (public.identifier_key(pin)) stored,
  serial_key         text generated always as (public.identifier_key(serial_number)) stored,
  register_key       text generated always as (public.identifier_key(register_number)) stored,
  manufacturer       text not null,
  model              text not null,
  machine_type       text not null check (machine_type in ('Grävmaskin','Hjullastare','Dumper','Skogsmaskin','Traktor','Kran','Vält','Teleskoplastare','Övrigt')),
  model_year         int check (model_year between 1950 and 2100),
  identity_verified  boolean not null default false,
  created_by         uuid references auth.users (id),
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  constraint machine_has_identifier check (pin is not null or serial_number is not null)
);
create unique index machines_pin_key_uq on public.machines (pin_key) where pin_key is not null;
create unique index machines_serial_key_uq on public.machines (serial_key) where serial_key is not null;

create table public.ownerships (
  id                     uuid primary key default gen_random_uuid(),
  machine_id             uuid not null references public.machines (id) on delete cascade,
  owner_organization_id  uuid not null references public.organizations (id),
  since                  timestamptz not null default now(),
  until                  timestamptz,
  created_at             timestamptz not null default now()
);
-- Högst en nuvarande ägare per maskin.
create unique index ownerships_current_uq on public.ownerships (machine_id) where until is null;

create table public.pledges (
  id                     uuid primary key default gen_random_uuid(),
  machine_id             uuid not null references public.machines (id) on delete cascade,
  lender_organization_id uuid not null references public.organizations (id),
  reference              text,
  amount_sek             bigint check (amount_sek is null or amount_sek > 0),
  registered_at          timestamptz not null default now(),
  released_at            timestamptz
);
create unique index pledges_active_per_lender_uq on public.pledges (machine_id, lender_organization_id) where released_at is null;

create table public.insurances (
  id                      uuid primary key default gen_random_uuid(),
  machine_id              uuid not null references public.machines (id) on delete cascade,
  insurer_organization_id uuid not null references public.organizations (id),
  coverage                text not null,
  policy_number           text,
  valid_from              date not null,
  valid_to                date not null,
  cancelled_at            timestamptz,
  created_at              timestamptz not null default now(),
  check (valid_to > valid_from)
);

create table public.blocks (
  id                           uuid primary key default gen_random_uuid(),
  machine_id                   uuid not null references public.machines (id) on delete cascade,
  reason                       public.block_reason not null,
  description                  text,
  police_report_number         text,
  reported_by_organization_id  uuid not null references public.organizations (id),
  reported_at                  timestamptz not null default now(),
  lifted_at                    timestamptz
);

-- Historik. Skrivs endast av RPC-funktionerna, ändras aldrig.
create table public.register_events (
  id                      uuid primary key default gen_random_uuid(),
  machine_id              uuid not null references public.machines (id) on delete cascade,
  kind                    public.register_event_kind not null,
  description             text not null,
  source_organization_id  uuid references public.organizations (id),
  actor_user_id           uuid references auth.users (id),
  occurred_at             timestamptz not null default now()
);
create index on public.register_events (machine_id, occurred_at desc);

create sequence public.extract_seq start 4471;

create table public.register_extracts (
  id                         text primary key,
  machine_id                 uuid not null references public.machines (id) on delete cascade,
  issued_at                  timestamptz not null default now(),
  issued_to_organization_id  uuid references public.organizations (id),
  issued_by_user_id          uuid references auth.users (id),
  snapshot                   jsonb not null
);

-- ---------- RLS: påslaget överallt, ingen direktåtkomst utom nedan ----------
alter table public.organizations     enable row level security;
alter table public.profiles          enable row level security;
alter table public.machines          enable row level security;
alter table public.ownerships        enable row level security;
alter table public.pledges           enable row level security;
alter table public.insurances        enable row level security;
alter table public.blocks            enable row level security;
alter table public.register_events   enable row level security;
alter table public.register_extracts enable row level security;

-- Inloggade får lista organisationer (val av ny ägare m.m.).
create policy "organisationer läses av inloggade" on public.organizations
  for select to authenticated using (true);

-- Användaren ser sin egen profil.
create policy "egen profil" on public.profiles
  for select to authenticated using (id = (select auth.uid()));

-- ---------- Hjälpfunktioner ----------
create or replace function public.current_org()
returns public.organizations
language sql stable security definer set search_path = '' as $$
  select o.* from public.organizations o
  join public.profiles p on p.organization_id = o.id
  where p.id = auth.uid()
$$;

create or replace function public.require_org()
returns public.organizations
language plpgsql stable security definer set search_path = '' as $$
declare o public.organizations;
begin
  if auth.uid() is null then
    raise exception 'Du behöver logga in för att göra ändringar i registret.' using errcode = '28000';
  end if;
  select * into o from public.current_org();
  if o.id is null then
    raise exception 'Kontot är inte kopplat till någon organisation ännu.' using errcode = '42501';
  end if;
  return o;
end $$;

create or replace function public.forbidden()
returns void language plpgsql as $$
begin
  raise exception 'Din organisation har inte behörighet att göra den här ändringen.' using errcode = '42501';
end $$;

create or replace function public.log_event(p_machine_id uuid, p_kind public.register_event_kind, p_description text, p_org_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  insert into public.register_events (machine_id, kind, description, source_organization_id, actor_user_id)
  values (p_machine_id, p_kind, p_description, p_org_id, auth.uid());
  if p_kind <> 'utdrag_hamtat' then
    update public.machines set updated_at = now() where id = p_machine_id;
  end if;
end $$;

create or replace function public.is_current_owner(p_machine_id uuid, p_org_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.ownerships where machine_id = p_machine_id and until is null and owner_organization_id = p_org_id)
$$;

-- Registerposten som JSON (form: MachineRecord i src/lib/types.ts).
-- Belopp och avtalsnummer döljs för andra än ägaren och långivaren själv.
create or replace function public.machine_record_json(p_machine_id uuid)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  viewer_org uuid := (select id from public.current_org());
  owner_org uuid;
  result jsonb;
begin
  select owner_organization_id into owner_org from public.ownerships where machine_id = p_machine_id and until is null;

  select jsonb_build_object(
    'machine', jsonb_build_object(
      'id', m.id, 'registerNumber', m.register_number, 'pin', m.pin, 'serialNumber', m.serial_number,
      'manufacturer', m.manufacturer, 'model', m.model, 'machineType', m.machine_type, 'modelYear', m.model_year,
      'identityVerified', m.identity_verified, 'createdAt', m.created_at, 'updatedAt', m.updated_at),
    'owner', (
      select jsonb_build_object('id', o.id, 'machineId', o.machine_id, 'ownerOrganizationId', o.owner_organization_id,
        'ownerName', org.name, 'ownerOrgNr', org.org_nr, 'since', o.since, 'until', o.until)
      from public.ownerships o join public.organizations org on org.id = o.owner_organization_id
      where o.machine_id = m.id and o.until is null),
    'pledges', coalesce((
      select jsonb_agg(jsonb_build_object('id', p.id, 'machineId', p.machine_id, 'lenderOrganizationId', p.lender_organization_id,
        'lenderName', org.name,
        'reference', case when viewer_org in (owner_org, p.lender_organization_id) then p.reference end,
        'amountSek', case when viewer_org in (owner_org, p.lender_organization_id) then p.amount_sek end,
        'registeredAt', p.registered_at, 'releasedAt', p.released_at) order by p.registered_at desc)
      from public.pledges p join public.organizations org on org.id = p.lender_organization_id
      where p.machine_id = m.id), '[]'::jsonb),
    'insurances', coalesce((
      select jsonb_agg(jsonb_build_object('id', i.id, 'machineId', i.machine_id, 'insurerOrganizationId', i.insurer_organization_id,
        'insurerName', org.name, 'coverage', i.coverage, 'policyNumber', i.policy_number,
        'validFrom', i.valid_from, 'validTo', i.valid_to, 'cancelledAt', i.cancelled_at) order by i.valid_from desc)
      from public.insurances i join public.organizations org on org.id = i.insurer_organization_id
      where i.machine_id = m.id), '[]'::jsonb),
    'blocks', coalesce((
      select jsonb_agg(jsonb_build_object('id', b.id, 'machineId', b.machine_id, 'reason', b.reason, 'description', b.description,
        'policeReportNumber', b.police_report_number, 'reportedByOrganizationId', b.reported_by_organization_id,
        'reportedByName', org.name, 'reportedAt', b.reported_at, 'liftedAt', b.lifted_at) order by b.reported_at desc)
      from public.blocks b join public.organizations org on org.id = b.reported_by_organization_id
      where b.machine_id = m.id), '[]'::jsonb),
    'lastUpdatedAt', m.updated_at,
    'lastUpdatedBy', coalesce((
      select org.name from public.register_events e join public.organizations org on org.id = e.source_organization_id
      where e.machine_id = m.id order by e.occurred_at desc limit 1), 'MaskinID')
  ) into result
  from public.machines m where m.id = p_machine_id;

  return result;
end $$;

-- ---------- RPC: läsning ----------
create or replace function public.my_profile()
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('id', p.id, 'email', p.email, 'fullName', p.full_name,
    'organization', jsonb_build_object('id', o.id, 'name', o.name, 'orgNr', o.org_nr, 'type', o.type))
  from public.profiles p join public.organizations o on o.id = p.organization_id
  where p.id = auth.uid()
$$;

create or replace function public.lookup_machine(q text)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare k text := public.identifier_key(q); mid uuid;
begin
  if k is null or length(k) < 5 then return null; end if;
  select id into mid from public.machines
  where register_key = k or pin_key = k or serial_key = k
  order by (register_key = k) desc, (pin_key = k) desc
  limit 1;
  if mid is null then return null; end if;
  return public.machine_record_json(mid);
end $$;

create or replace function public.get_machine_record(p_machine_id uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select public.machine_record_json(p_machine_id)
$$;

create or replace function public.get_machine_history(p_machine_id uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', e.id, 'machineId', e.machine_id, 'kind', e.kind,
    'description', e.description, 'sourceName', coalesce(o.name, 'MaskinID'), 'occurredAt', e.occurred_at)
    order by e.occurred_at desc), '[]'::jsonb)
  from public.register_events e left join public.organizations o on o.id = e.source_organization_id
  where e.machine_id = p_machine_id
$$;

create or replace function public.list_my_machines()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare o public.organizations := public.require_org();
begin
  return coalesce((
    select jsonb_agg(public.machine_record_json(x.id) order by x.updated_at desc)
    from (
      select m.id, m.updated_at from public.machines m
      where exists (select 1 from public.ownerships w where w.machine_id = m.id and w.until is null and w.owner_organization_id = o.id)
         or exists (select 1 from public.pledges p where p.machine_id = m.id and p.released_at is null and p.lender_organization_id = o.id)
         or exists (select 1 from public.insurances i where i.machine_id = m.id and i.cancelled_at is null and i.insurer_organization_id = o.id)
    ) x), '[]'::jsonb);
end $$;

-- ---------- RPC: skrivning ----------
create or replace function public.register_machine(
  p_pin text, p_serial_number text, p_manufacturer text, p_model text, p_machine_type text,
  p_model_year int, p_owner_organization_id uuid default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  o public.organizations := public.require_org();
  owner_id uuid := coalesce(p_owner_organization_id, o.id);
  existing text;
  new_id uuid;
begin
  if o.type not in ('maskinagare', 'maskinhandlare') then perform public.forbidden(); end if;
  if public.identifier_key(p_pin) is null and public.identifier_key(p_serial_number) is null then
    raise exception 'Ange PIN eller serienummer.' using errcode = '22023';
  end if;
  select register_number into existing from public.machines
  where pin_key = public.identifier_key(p_pin) or serial_key = public.identifier_key(p_serial_number) limit 1;
  if existing is not null then
    raise exception 'Maskinen är redan registrerad med registernummer %.', existing using errcode = '23505';
  end if;

  insert into public.machines (pin, serial_number, manufacturer, model, machine_type, model_year, created_by)
  values (public.identifier_key(p_pin), upper(nullif(trim(p_serial_number), '')), trim(p_manufacturer), trim(p_model),
          p_machine_type, p_model_year, auth.uid())
  returning id into new_id;

  insert into public.ownerships (machine_id, owner_organization_id) values (new_id, owner_id);
  perform public.log_event(new_id, 'maskin_registrerad', 'Maskinen registrerades i MaskinID.', o.id);
  return public.machine_record_json(new_id);
end $$;

create or replace function public.transfer_ownership(p_machine_id uuid, p_new_owner_organization_id uuid, p_effective_from timestamptz)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare o public.organizations := public.require_org(); new_owner public.organizations;
begin
  if not public.is_current_owner(p_machine_id, o.id) then perform public.forbidden(); end if;
  select * into new_owner from public.organizations where id = p_new_owner_organization_id;
  if new_owner.id is null then raise exception 'Välj en ny registrerad ägare.' using errcode = '22023'; end if;
  if new_owner.id = o.id then raise exception 'Organisationen är redan registrerad ägare.' using errcode = '22023'; end if;

  update public.ownerships set until = p_effective_from where machine_id = p_machine_id and until is null;
  insert into public.ownerships (machine_id, owner_organization_id, since) values (p_machine_id, new_owner.id, p_effective_from);
  perform public.log_event(p_machine_id, 'agarbyte', 'Ny registrerad ägare: ' || new_owner.name || '.', o.id);
  return public.machine_record_json(p_machine_id);
end $$;

create or replace function public.register_pledge(p_machine_id uuid, p_reference text, p_amount_sek bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare o public.organizations := public.require_org();
begin
  if o.type <> 'langivare' then perform public.forbidden(); end if;
  if not exists (select 1 from public.machines where id = p_machine_id) then
    raise exception 'Maskinen finns inte i registret.' using errcode = 'P0002';
  end if;
  if exists (select 1 from public.pledges where machine_id = p_machine_id and lender_organization_id = o.id and released_at is null) then
    raise exception 'Din organisation har redan en registrerad belåning på maskinen.' using errcode = '23505';
  end if;
  insert into public.pledges (machine_id, lender_organization_id, reference, amount_sek)
  values (p_machine_id, o.id, nullif(trim(p_reference), ''), p_amount_sek);
  perform public.log_event(p_machine_id, 'belaning_registrerad', 'Belåning registrerad.', o.id);
  return public.machine_record_json(p_machine_id);
end $$;

create or replace function public.release_pledge(p_pledge_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare o public.organizations := public.require_org(); p public.pledges;
begin
  select * into p from public.pledges where id = p_pledge_id;
  if p.id is null then raise exception 'Belåningen finns inte.' using errcode = 'P0002'; end if;
  if p.lender_organization_id <> o.id or p.released_at is not null then perform public.forbidden(); end if;
  update public.pledges set released_at = now() where id = p.id;
  perform public.log_event(p.machine_id, 'belaning_avslutad', 'Belåningen avslutades.', o.id);
  return public.machine_record_json(p.machine_id);
end $$;

create or replace function public.register_insurance(p_machine_id uuid, p_coverage text, p_policy_number text, p_valid_from date, p_valid_to date)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare o public.organizations := public.require_org();
begin
  if o.type <> 'forsakringsgivare' then perform public.forbidden(); end if;
  if not exists (select 1 from public.machines where id = p_machine_id) then
    raise exception 'Maskinen finns inte i registret.' using errcode = 'P0002';
  end if;
  if p_valid_to <= p_valid_from then
    raise exception 'Slutdatum måste vara efter startdatum.' using errcode = '22023';
  end if;
  update public.insurances set cancelled_at = now() where machine_id = p_machine_id and cancelled_at is null;
  insert into public.insurances (machine_id, insurer_organization_id, coverage, policy_number, valid_from, valid_to)
  values (p_machine_id, o.id, p_coverage, nullif(trim(p_policy_number), ''), p_valid_from, p_valid_to);
  perform public.log_event(p_machine_id, 'forsakring_registrerad',
    p_coverage || ' registrerad till ' || extract(day from p_valid_to)::int || ' ' ||
    (array['jan','feb','mar','apr','maj','jun','jul','aug','sep','okt','nov','dec'])[extract(month from p_valid_to)::int] || ' ' ||
    extract(year from p_valid_to)::int || '.', o.id);
  return public.machine_record_json(p_machine_id);
end $$;

create or replace function public.report_block(p_machine_id uuid, p_reason public.block_reason, p_description text, p_police_report_number text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare o public.organizations := public.require_org(); allowed boolean; txt text;
begin
  allowed := public.is_current_owner(p_machine_id, o.id)
    or exists (select 1 from public.pledges where machine_id = p_machine_id and lender_organization_id = o.id and released_at is null)
    or exists (select 1 from public.insurances where machine_id = p_machine_id and insurer_organization_id = o.id
               and cancelled_at is null and current_date between valid_from and valid_to);
  if not allowed then perform public.forbidden(); end if;
  if p_reason = 'stulen' and nullif(trim(p_police_report_number), '') is null then
    raise exception 'Ange polisens diarienummer. Det står på anmälningskvittot.' using errcode = '22023';
  end if;
  insert into public.blocks (machine_id, reason, description, police_report_number, reported_by_organization_id)
  values (p_machine_id, p_reason, nullif(trim(p_description), ''), upper(nullif(trim(p_police_report_number), '')), o.id);
  txt := case when p_reason = 'stulen' then 'Maskinen anmäld stulen.' else 'Spärr registrerad.' end;
  if nullif(trim(p_police_report_number), '') is not null then
    txt := txt || ' Polisens diarienummer ' || upper(trim(p_police_report_number)) || '.';
  end if;
  perform public.log_event(p_machine_id, 'sparr_registrerad', txt, o.id);
  return public.machine_record_json(p_machine_id);
end $$;

create or replace function public.lift_block(p_block_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare o public.organizations := public.require_org(); b public.blocks;
begin
  select * into b from public.blocks where id = p_block_id;
  if b.id is null then raise exception 'Spärren finns inte.' using errcode = 'P0002'; end if;
  if b.reported_by_organization_id <> o.id or b.lifted_at is not null then perform public.forbidden(); end if;
  update public.blocks set lifted_at = now() where id = b.id;
  perform public.log_event(b.machine_id, 'sparr_havd', 'Spärren hävdes.', o.id);
  return public.machine_record_json(b.machine_id);
end $$;

-- ---------- RPC: registerutdrag ----------
create or replace function public.extract_json(x public.register_extracts)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('id', x.id, 'machineId', x.machine_id, 'issuedAt', x.issued_at,
    'issuedToName', (select name from public.organizations where id = x.issued_to_organization_id),
    'snapshot', x.snapshot)
$$;

create or replace function public.issue_extract(p_machine_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare o public.organizations := public.require_org(); snap jsonb; x public.register_extracts;
begin
  snap := public.machine_record_json(p_machine_id);
  if snap is null then raise exception 'Maskinen finns inte i registret.' using errcode = 'P0002'; end if;
  insert into public.register_extracts (id, machine_id, issued_to_organization_id, issued_by_user_id, snapshot)
  values ('RU-' || to_char(now() at time zone 'Europe/Stockholm', 'YYYY-MMDD') || '-' || nextval('public.extract_seq'),
          p_machine_id, o.id, auth.uid(), snap)
  returning * into x;
  perform public.log_event(p_machine_id, 'utdrag_hamtat', 'Registerutdrag ' || x.id || ' hämtat.', o.id);
  return public.extract_json(x);
end $$;

-- Ett utdrag kan verifieras av vem som helst som har utdragsnumret.
create or replace function public.get_extract(p_extract_id text)
returns jsonb language sql stable security definer set search_path = '' as $$
  select public.extract_json(x) from public.register_extracts x where x.id = upper(trim(p_extract_id))
$$;

-- ---------- Rättigheter ----------
revoke all on all functions in schema public from public, anon, authenticated;

grant execute on function public.lookup_machine(text)            to anon, authenticated;
grant execute on function public.get_machine_record(uuid)         to anon, authenticated;
grant execute on function public.get_machine_history(uuid)        to anon, authenticated;
grant execute on function public.get_extract(text)                to anon, authenticated;
grant execute on function public.my_profile()                     to authenticated;
grant execute on function public.list_my_machines()               to authenticated;
grant execute on function public.register_machine(text, text, text, text, text, int, uuid) to authenticated;
grant execute on function public.transfer_ownership(uuid, uuid, timestamptz)               to authenticated;
grant execute on function public.register_pledge(uuid, text, bigint)                       to authenticated;
grant execute on function public.release_pledge(uuid)                                      to authenticated;
grant execute on function public.register_insurance(uuid, text, text, date, date)          to authenticated;
grant execute on function public.report_block(uuid, public.block_reason, text, text)       to authenticated;
grant execute on function public.lift_block(uuid)                                          to authenticated;
grant execute on function public.issue_extract(uuid)                                       to authenticated;
