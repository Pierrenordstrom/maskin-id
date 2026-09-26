// Kör schema + seed + RPC-funktioner mot en inbäddad Postgres (PGlite) med stubbat auth-schema.
// Verifierar behörigheter, historik och JSON-formen som frontend förväntar sig. Kör: npm run test:db
import { PGlite } from "@electric-sql/pglite";
import { pgcrypto } from "@electric-sql/pglite/contrib/pgcrypto";
import { readFileSync } from "node:fs";
const root = new URL("..", import.meta.url).pathname;
const db = new PGlite({ extensions: { pgcrypto } });
// Stubbar för Supabase-miljön
await db.exec(`
  create role anon; create role authenticated;
  create schema auth; create schema extensions;
  create extension pgcrypto schema extensions;
  create table auth.users (instance_id uuid, id uuid primary key, aud text, role text, email text, encrypted_password text,
    email_confirmed_at timestamptz, raw_app_meta_data jsonb, raw_user_meta_data jsonb, created_at timestamptz, updated_at timestamptz);
  create table auth.identities (id uuid, user_id uuid, provider_id text, provider text, identity_data jsonb, last_sign_in_at timestamptz, created_at timestamptz, updated_at timestamptz);
  create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('test.uid', true), '')::uuid $$;
`);
const mig = readFileSync(`${root}/migrations/20260926000001_initial_schema.sql`, "utf8").replace("create extension if not exists pgcrypto;", "set search_path = public, extensions;");
await db.exec(mig);
await db.exec(readFileSync(`${root}/seed.sql`, "utf8"));
const as = (uid) => db.exec(`select set_config('test.uid', '${uid ?? ""}', false)`);
const q = async (sql, p) => (await db.query(sql, p)).rows[0];
const ok = (c, m) => { if (!c) { console.error("FAIL", m); process.exitCode = 1; } else console.log("ok", m); };
const err = async (sql, p) => { try { await db.query(sql, p); return null; } catch (e) { return e.code + " " + e.message; } };

await as(null);
let r = (await q("select public.lookup_machine('7kx0 l2t4003198') as r")).r;
ok(r.machine.registerNumber === "MID-2026-0048812", "lookup på PIN");
ok(r.pledges[0].amountSek === null, "belopp dolt för anonym");
ok(r.owner.ownerName === "Exempel Anläggning AB", "ägare");
ok((await q("select public.lookup_machine('mid-2026-0048812') as r")).r.machine.pin === "7KX0L2T4003198", "lookup på registernummer");
ok((await q("select public.lookup_machine('FINNSEJ123') as r")).r === null, "ej hittad");
ok((await err("select public.register_pledge('b0000000-0000-4000-8000-000000000002', null, null)"))?.startsWith("28000"), "kräver inloggning");

await as("c0000000-0000-4000-8000-000000000003"); // långivare
r = (await q("select public.get_machine_record('b0000000-0000-4000-8000-000000000001') as r")).r;
ok(r.pledges[0].amountSek == 1250000, "belopp synligt för långivaren");
r = (await q("select public.register_pledge('b0000000-0000-4000-8000-000000000002', 'KR-1', 500000) as r")).r;
ok(r.pledges.length === 1, "belåning registrerad");
ok((await err("select public.register_pledge('b0000000-0000-4000-8000-000000000002', 'KR-1', 500000)"))?.startsWith("23505"), "dubbel belåning stoppas");
const hist = (await q("select public.get_machine_history('b0000000-0000-4000-8000-000000000002') as r")).r;
ok(hist[0].kind === "belaning_registrerad" && hist[0].sourceName === "Exempelbanken AB", "historik");
ok((await err("select public.register_machine('ABC12345678', null, 'X', 'Y', 'Grävmaskin', 2024, null)"))?.startsWith("42501"), "långivare får inte registrera maskin");
r = (await q("select public.release_pledge($1) as r", [r.pledges[0].id])).r;
ok(r.pledges[0].releasedAt !== null, "belåning avslutad");

await as("c0000000-0000-4000-8000-000000000001"); // ägare
r = (await q("select public.register_machine('abc12345678901', null, 'Test', 'T1', 'Grävmaskin', 2024, null) as r")).r;
ok(/^MID-\d{4}-0071151$/.test(r.machine.registerNumber), "ny maskin " + r.machine.registerNumber);
ok((await err("select public.register_machine('ABC12345678901', null, 'Test', 'T1', 'Grävmaskin', 2024, null)"))?.startsWith("23505"), "dubblett stoppas");
ok((await err("select public.transfer_ownership('b0000000-0000-4000-8000-000000000003', 'a0000000-0000-4000-8000-000000000003', now())"))?.startsWith("42501"), "ej ägare kan inte byta ägare");
r = (await q("select public.transfer_ownership('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000003', now()) as r")).r;
ok(r.owner.ownerName === "Maskinhandel Mitt AB", "ägarbyte");
const list = (await q("select public.list_my_machines() as r")).r;
ok(list.length === 2, "mina maskiner: " + list.length);
ok((await err("select public.report_block('b0000000-0000-4000-8000-000000000002', 'stulen', null, null)"))?.startsWith("22023"), "stöld kräver diarienummer");
r = (await q("select public.report_block('b0000000-0000-4000-8000-000000000002', 'stulen', 'x', '5000-k1-26') as r")).r;
ok(r.blocks[0].policeReportNumber === "5000-K1-26", "spärr");
r = (await q("select public.lift_block($1) as r", [r.blocks[0].id])).r;
ok(r.blocks[0].liftedAt !== null, "spärr hävd");
const ex = (await q("select public.issue_extract('b0000000-0000-4000-8000-000000000002') as r")).r;
ok(/^RU-\d{4}-\d{4}-4471$/.test(ex.id) && ex.issuedToName === "Exempel Anläggning AB", "utdrag " + ex.id);
await as(null);
ok((await q("select public.get_extract($1) as r", [ex.id.toLowerCase()])).r.snapshot.machine.pin === "1FG5H3R8002741", "utdrag verifierbart anonymt");

await as("c0000000-0000-4000-8000-000000000004"); // försäkring
r = (await q("select public.register_insurance('b0000000-0000-4000-8000-000000000004', 'Maskinförsäkring', 'P1', '2026-10-01', '2027-09-30') as r")).r;
ok(r.insurances[0].validTo === "2027-09-30", "försäkring, validTo som datum");
const h2 = (await q("select public.get_machine_history('b0000000-0000-4000-8000-000000000004') as r")).r;
ok(h2[0].description === "Maskinförsäkring registrerad till 30 sep 2027.", h2[0].description);
const prof = (await q("select public.my_profile() as r")).r;
ok(prof.organization.type === "forsakringsgivare", "my_profile");
