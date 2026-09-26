-- Exempeldata för lokal utveckling (`supabase db reset`). Samma innehåll som src/data/seed.ts.
-- Alla företag och personer är påhittade. Lösenord för demokontona: maskinid

-- ---------- Organisationer ----------
insert into public.organizations (id, name, org_nr, type) values
  ('a0000000-0000-4000-8000-000000000001', 'Exempel Anläggning AB',   '556100-0001', 'maskinagare'),
  ('a0000000-0000-4000-8000-000000000002', 'Norrskog Entreprenad AB', '556100-0002', 'maskinagare'),
  ('a0000000-0000-4000-8000-000000000003', 'Maskinhandel Mitt AB',    '556100-0003', 'maskinhandlare'),
  ('a0000000-0000-4000-8000-000000000004', 'Exempelbanken AB',        '516100-0004', 'langivare'),
  ('a0000000-0000-4000-8000-000000000005', 'Maskinfinans Sverige AB', '556100-0005', 'langivare'),
  ('a0000000-0000-4000-8000-000000000006', 'Exempelförsäkring AB',    '516100-0006', 'forsakringsgivare');

-- ---------- Demokonton (auth.users + auth.identities + profiles) ----------
do $$
declare
  u record;
begin
  for u in
    select * from (values
      ('c0000000-0000-4000-8000-000000000001'::uuid, 'agare@exempel.se',      'Anna Ägare',         'a0000000-0000-4000-8000-000000000001'::uuid),
      ('c0000000-0000-4000-8000-000000000002'::uuid, 'handlare@exempel.se',   'Henrik Handlare',    'a0000000-0000-4000-8000-000000000003'::uuid),
      ('c0000000-0000-4000-8000-000000000003'::uuid, 'langivare@exempel.se',  'Lena Långivare',     'a0000000-0000-4000-8000-000000000004'::uuid),
      ('c0000000-0000-4000-8000-000000000004'::uuid, 'forsakring@exempel.se', 'Fredrik Försäkring', 'a0000000-0000-4000-8000-000000000006'::uuid)
    ) as t(id, email, full_name, org_id)
  loop
    insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
                            raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
    values ('00000000-0000-0000-0000-000000000000', u.id, 'authenticated', 'authenticated', u.email,
            extensions.crypt('maskinid', extensions.gen_salt('bf')), now(),
            '{"provider":"email","providers":["email"]}', jsonb_build_object('full_name', u.full_name), now(), now());
    insert into auth.identities (id, user_id, provider_id, provider, identity_data, last_sign_in_at, created_at, updated_at)
    values (gen_random_uuid(), u.id, u.id::text, 'email', jsonb_build_object('sub', u.id::text, 'email', u.email), now(), now(), now());
    insert into public.profiles (id, email, full_name, organization_id) values (u.id, u.email, u.full_name, u.org_id);
  end loop;
end $$;

-- ---------- Maskiner ----------
insert into public.machines (id, register_number, pin, serial_number, manufacturer, model, machine_type, model_year, identity_verified, created_at, updated_at) values
  ('b0000000-0000-4000-8000-000000000001', 'MID-2026-0048812', '7KX0L2T4003198', 'LX4003198', 'Exempeltillverkaren', 'L120',         'Hjullastare',     2021, true,  '2024-03-14T09:12:00Z', '2026-09-26T12:05:00Z'),
  ('b0000000-0000-4000-8000-000000000002', 'MID-2026-0051207', '1FG5H3R8002741', 'EX302741',  'Exempeltillverkaren', 'EC220',        'Grävmaskin',      2019, true,  '2023-05-02T10:00:00Z', '2026-08-11T07:40:00Z'),
  ('b0000000-0000-4000-8000-000000000003', 'MID-2026-0060033', '3SK9P1W2001188', 'SK1188',    'Nordmaskin',          'Skotare 1110', 'Skogsmaskin',     2020, true,  '2022-11-20T13:30:00Z', '2026-09-02T08:15:00Z'),
  ('b0000000-0000-4000-8000-000000000004', 'MID-2026-0060391', '9DM2T7A5000452', 'DM452',     'Exempeltillverkaren', 'A30',          'Dumper',          2018, true,  '2021-06-01T08:00:00Z', '2026-09-19T06:50:00Z'),
  ('b0000000-0000-4000-8000-000000000005', 'MID-2026-0071150', null,             'TL-88213',  'Lyftex',              'TH 3.5',       'Teleskoplastare', 2023, false, '2026-09-10T14:20:00Z', '2026-09-10T14:20:00Z');

insert into public.ownerships (machine_id, owner_organization_id, since, until) values
  ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000003', '2021-04-02', '2024-03-14'),
  ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000001', '2024-03-14', null),
  ('b0000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000001', '2023-05-02', null),
  ('b0000000-0000-4000-8000-000000000003', 'a0000000-0000-4000-8000-000000000002', '2022-11-20', null),
  ('b0000000-0000-4000-8000-000000000004', 'a0000000-0000-4000-8000-000000000002', '2021-06-01', null),
  ('b0000000-0000-4000-8000-000000000005', 'a0000000-0000-4000-8000-000000000003', '2026-09-10', null);

insert into public.pledges (machine_id, lender_organization_id, reference, amount_sek, registered_at, released_at) values
  ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000004', 'KR-2024-11873', 1250000, '2024-03-14T10:00:00Z', null),
  ('b0000000-0000-4000-8000-000000000003', 'a0000000-0000-4000-8000-000000000005', 'MF-88120',      2100000, '2022-11-21T09:00:00Z', '2026-09-02T08:15:00Z'),
  ('b0000000-0000-4000-8000-000000000004', 'a0000000-0000-4000-8000-000000000004', 'KR-2021-04410',  980000, '2021-06-02T09:00:00Z', null);

insert into public.insurances (machine_id, insurer_organization_id, coverage, policy_number, valid_from, valid_to) values
  ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000006', 'Maskinförsäkring', 'MF-448120', '2026-01-01', '2026-12-31'),
  ('b0000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000006', 'Maskinförsäkring', 'MF-397702', '2026-05-01', '2027-04-30'),
  ('b0000000-0000-4000-8000-000000000003', 'a0000000-0000-4000-8000-000000000006', 'Maskinförsäkring', 'MF-300915', '2026-01-01', '2026-12-31');

insert into public.blocks (machine_id, reason, description, police_report_number, reported_by_organization_id, reported_at) values
  ('b0000000-0000-4000-8000-000000000004', 'stulen', 'Försvann från arbetsplats i Umeå natten mot 19 sep.', '5000-K123456-26',
   'a0000000-0000-4000-8000-000000000002', '2026-09-19T06:50:00Z');

insert into public.register_events (machine_id, kind, description, source_organization_id, occurred_at) values
  ('b0000000-0000-4000-8000-000000000001', 'maskin_registrerad',     'Maskinen registrerades i MaskinID.',              'a0000000-0000-4000-8000-000000000003', '2021-04-02T09:00:00Z'),
  ('b0000000-0000-4000-8000-000000000001', 'identitet_verifierad',   'Identiteten verifierades mot typskylt.',          'a0000000-0000-4000-8000-000000000003', '2021-04-02T09:30:00Z'),
  ('b0000000-0000-4000-8000-000000000001', 'agarbyte',               'Ny registrerad ägare: Exempel Anläggning AB.',    'a0000000-0000-4000-8000-000000000003', '2024-03-14T09:12:00Z'),
  ('b0000000-0000-4000-8000-000000000001', 'belaning_registrerad',   'Belåning registrerad.',                           'a0000000-0000-4000-8000-000000000004', '2024-03-14T10:00:00Z'),
  ('b0000000-0000-4000-8000-000000000001', 'forsakring_registrerad', 'Maskinförsäkring registrerad till 31 dec 2026.',  'a0000000-0000-4000-8000-000000000006', '2026-09-26T12:05:00Z'),
  ('b0000000-0000-4000-8000-000000000002', 'maskin_registrerad',     'Maskinen registrerades i MaskinID.',              'a0000000-0000-4000-8000-000000000001', '2023-05-02T10:00:00Z'),
  ('b0000000-0000-4000-8000-000000000002', 'identitet_verifierad',   'Identiteten verifierades mot typskylt.',          'a0000000-0000-4000-8000-000000000001', '2023-05-02T10:10:00Z'),
  ('b0000000-0000-4000-8000-000000000002', 'forsakring_registrerad', 'Maskinförsäkring registrerad till 30 apr 2027.',  'a0000000-0000-4000-8000-000000000006', '2026-08-11T07:40:00Z'),
  ('b0000000-0000-4000-8000-000000000003', 'maskin_registrerad',     'Maskinen registrerades i MaskinID.',              'a0000000-0000-4000-8000-000000000002', '2022-11-20T13:30:00Z'),
  ('b0000000-0000-4000-8000-000000000003', 'belaning_registrerad',   'Belåning registrerad.',                           'a0000000-0000-4000-8000-000000000005', '2022-11-21T09:00:00Z'),
  ('b0000000-0000-4000-8000-000000000003', 'belaning_avslutad',      'Belåningen avslutades.',                          'a0000000-0000-4000-8000-000000000005', '2026-09-02T08:15:00Z'),
  ('b0000000-0000-4000-8000-000000000004', 'maskin_registrerad',     'Maskinen registrerades i MaskinID.',              'a0000000-0000-4000-8000-000000000002', '2021-06-01T08:00:00Z'),
  ('b0000000-0000-4000-8000-000000000004', 'belaning_registrerad',   'Belåning registrerad.',                           'a0000000-0000-4000-8000-000000000004', '2021-06-02T09:00:00Z'),
  ('b0000000-0000-4000-8000-000000000004', 'sparr_registrerad',      'Maskinen anmäld stulen. Polisens diarienummer 5000-K123456-26.', 'a0000000-0000-4000-8000-000000000002', '2026-09-19T06:50:00Z'),
  ('b0000000-0000-4000-8000-000000000005', 'maskin_registrerad',     'Maskinen registrerades i MaskinID.',              'a0000000-0000-4000-8000-000000000003', '2026-09-10T14:20:00Z');
