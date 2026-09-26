# Backend – Supabase

Frontenden är klar och pratar med backend genom ett enda kontrakt, `MaskinIdApi`
([`src/lib/api/types.ts`](../src/lib/api/types.ts)). Det finns två implementationer:

| Implementation | Fil | När |
| --- | --- | --- |
| `mockApi` | `src/lib/api/mockApi.ts` | Standard. Exempeldata i webbläsarens localStorage |
| `supabaseApi` | `src/lib/api/supabaseApi.ts` | När `VITE_DATA_SOURCE=supabase` |

Databasen – tabeller, säkerhet och alla funktioner – finns färdig i
[`supabase/migrations/20260926000001_initial_schema.sql`](../supabase/migrations/20260926000001_initial_schema.sql)
och är testad med `npm run test:db`.

---

## 1. Koppla på Supabase

### Alternativ A – lokalt med Supabase CLI

```bash
npm i -g supabase          # eller: brew install supabase/tap/supabase
supabase start             # startar Postgres, Auth och API i Docker
supabase db reset          # kör migrering + supabase/seed.sql
```

Skriv sedan `.env` med värdena som `supabase start` skriver ut:

```
VITE_DATA_SOURCE=supabase
VITE_SUPABASE_URL=http://127.0.0.1:54321
VITE_SUPABASE_PUBLISHABLE_KEY=<publishable/anon key>
```

### Alternativ B – hostat projekt

1. Skapa ett projekt på supabase.com (region: EU, t.ex. Stockholm/Frankfurt).
2. `supabase link --project-ref <ref>` och `supabase db push` – eller klistra in migreringsfilen i SQL Editor.
3. Kör `supabase/seed.sql` bara i test-/stagingprojekt.
4. Under **Authentication → URL Configuration**: lägg till `https://<din-domän>/mina-sidor` som redirect-URL (e-postlänkar).
5. Stäng av öppen registrering (**Authentication → Providers → Email → Allow new users to sign up: av**). Konton skapas av MaskinID, se avsnitt 4.
6. Sätt miljövariablerna ovan i hostingtjänsten (Vercel/Netlify) och bygg om.

> Använd **aldrig** service role key i frontend. Den publika nyckeln är säker eftersom all åtkomst styrs av RLS och funktionsrättigheter.

### Generera typer (valfritt)

```bash
supabase gen types typescript --local > src/lib/database.types.ts
```

Frontenden behöver dem inte – RPC-funktionerna returnerar JSON i exakt samma form som `src/lib/types.ts` – men de är bra om ni skriver egna frågor.

---

## 2. Arkitektur

```
React-vyer ──▶ api (MaskinIdApi) ──▶ supabaseApi ──▶ supabase.rpc('…') ──▶ Postgres-funktion (security definer)
                                                  └▶ supabase.auth.*                  │
                                                                                       ├─ kontrollerar behörighet
                                                                                       ├─ skriver data + historik
                                                                                       └─ returnerar registerpost som JSON
```

**Varför RPC i stället för tabellåtkomst?** Varje ändring i registret är en affärshändelse som ska
(1) behörighetskontrolleras, (2) loggas i historiken i samma transaktion och (3) returnera den uppdaterade
registerposten. Därför har alla registertabeller RLS påslaget **utan** klientpolicyer – de går inte att läsa
eller skriva direkt – och all åtkomst går via funktionerna nedan. Enda undantagen: inloggade får läsa
`organizations`, och varje användare sin egen rad i `profiles`.

---

## 3. Datamodell

```
organizations ─┬─< profiles (1 per auth.users)
               │
machines ──────┼─< ownerships        (until = null → nuvarande ägare, max 1)
               ├─< pledges           (released_at = null → aktiv belåning)
               ├─< insurances        (cancelled_at = null och datum inom giltighet → gäller)
               ├─< blocks            (lifted_at = null → aktiv spärr)
               ├─< register_events   (historik, append-only)
               └─< register_extracts (utfärdade utdrag med ögonblicksbild i jsonb)
```

| Tabell | Viktiga kolumner | Kommentar |
| --- | --- | --- |
| `organizations` | `name`, `org_nr` (unik, `NNNNNN-NNNN`), `type` | `type`: `maskinhandlare`, `maskinagare`, `langivare`, `forsakringsgivare` |
| `profiles` | `id` = `auth.users.id`, `full_name`, `organization_id` | En användare företräder en organisation |
| `machines` | `register_number` (genereras `MID-ÅÅÅÅ-NNNNNNN`), `pin`, `serial_number`, `manufacturer`, `model`, `machine_type`, `model_year`, `identity_verified` | `pin_key`/`serial_key`/`register_key` är genererade sökningsnycklar (versaler, utan mellanslag/bindestreck) med unika index |
| `ownerships` | `machine_id`, `owner_organization_id`, `since`, `until` | Ägarhistorik |
| `pledges` | `lender_organization_id`, `reference`, `amount_sek`, `registered_at`, `released_at` | Max en aktiv belåning per långivare och maskin |
| `insurances` | `insurer_organization_id`, `coverage`, `policy_number`, `valid_from`, `valid_to` (date, inklusive) | Ny försäkring avslutar tidigare |
| `blocks` | `reason` (`stulen`, `avvikelse`, `myndighetsbeslut`), `police_report_number`, `reported_by_organization_id`, `lifted_at` | Stöld kräver polisens diarienummer |
| `register_events` | `kind`, `description`, `source_organization_id`, `actor_user_id`, `occurred_at` | Visas som "Uppgift från …" |
| `register_extracts` | `id` (`RU-ÅÅÅÅ-MMDD-N`), `snapshot` (jsonb), `issued_to_organization_id` | Kan verifieras av vem som helst med numret |

---

## 4. Auth och konton

- Inloggning med **lösenord** (`signInWithPassword`) eller **e-postlänk** (`signInWithOtp`, `shouldCreateUser: false`).
- En användare måste ha en rad i `profiles` för att kunna göra något. Så skapas ett konto:
  1. Bjud in användaren: **Authentication → Users → Invite** (eller `supabase.auth.admin.inviteUserByEmail` från en server/Edge Function).
  2. Skapa profilen: `insert into profiles (id, email, full_name, organization_id) values (…)`.
- Förslag på nästa steg: en Edge Function `invite-user` som gör båda i ett anrop, åtkomlig för en admin-roll.
- Ev. BankID-inloggning kan läggas till senare via en OIDC-leverantör (t.ex. Criipto/Signicat) som Supabase stöder som tredjepartsinloggning.

---

## 5. API-kontrakt

Alla funktioner ligger i `public` och anropas med `supabase.rpc(namn, argument)`. JSON-svaren har samma
fältnamn (camelCase) som typerna i `src/lib/types.ts`.

### Läsning

| RPC | Argument | Returnerar | Vem |
| --- | --- | --- | --- |
| `lookup_machine` | `q text` | `MachineRecord \| null` – matchar registernummer, PIN eller serienummer | anon, inloggad |
| `get_machine_record` | `p_machine_id uuid` | `MachineRecord \| null` | anon, inloggad |
| `get_machine_history` | `p_machine_id uuid` | `RegisterEvent[]`, nyast först | anon, inloggad |
| `get_extract` | `p_extract_id text` | `RegisterExtract \| null` | anon, inloggad |
| `my_profile` | – | `UserProfile \| null` | inloggad |
| `list_my_machines` | – | `MachineRecord[]` där organisationen är ägare, aktiv långivare eller försäkringsgivare | inloggad |

`organizations` läses direkt: `from('organizations').select('id, name, orgNr:org_nr, type')`.

**Sekretess i registerposten:** belåningens `amountSek` och `reference` är `null` för alla utom den
registrerade ägaren och långivaren själv.

### Skrivning (kräver inloggning)

| RPC | Argument | Får anropas av |
| --- | --- | --- |
| `register_machine` | `p_pin, p_serial_number, p_manufacturer, p_model, p_machine_type, p_model_year, p_owner_organization_id?` | maskinägare, maskinhandlare |
| `transfer_ownership` | `p_machine_id, p_new_owner_organization_id, p_effective_from` | nuvarande registrerad ägare |
| `register_pledge` | `p_machine_id, p_reference, p_amount_sek` | långivare |
| `release_pledge` | `p_pledge_id` | långivaren som registrerade belåningen |
| `register_insurance` | `p_machine_id, p_coverage, p_policy_number, p_valid_from date, p_valid_to date` | försäkringsgivare |
| `report_block` | `p_machine_id, p_reason, p_description, p_police_report_number` | ägare, långivare med aktiv belåning, försäkringsgivare med gällande försäkring |
| `lift_block` | `p_block_id` | organisationen som registrerade spärren |
| `issue_extract` | `p_machine_id` | alla inloggade |

Alla skrivande funktioner returnerar den uppdaterade `MachineRecord` (utom `issue_extract` som returnerar `RegisterExtract`)
och skriver en rad i `register_events`.

Samma regler finns i frontend i [`src/lib/permissions.ts`](../src/lib/permissions.ts) – där bara för att visa rätt knappar.
**Databasen är sanningen.** Ändras en regel: ändra båda och lägg till ett fall i `supabase/tests/rpc.test.mjs`.

### Felkoder

Funktionerna kastar fel med svenska meddelanden som kan visas direkt. `supabaseApi` översätter koden till `ApiError.code`:

| Postgres `errcode` | `ApiError.code` | Exempel |
| --- | --- | --- |
| `28000` | `ej_inloggad` | Du behöver logga in för att göra ändringar i registret. |
| `42501` | `saknar_behorighet` | Din organisation har inte behörighet att göra den här ändringen. |
| `P0002` | `hittades_inte` | Maskinen finns inte i registret. |
| `23505` | `finns_redan` | Maskinen är redan registrerad med registernummer MID-2026-0048812. |
| `22023` | `ogiltig_inmatning` | Ange polisens diarienummer. Det står på anmälningskvittot. |

---

## 6. Testa databasen

```bash
npm run test:db
```

Kör migreringen och `seed.sql` mot [PGlite](https://pglite.dev) (Postgres i WebAssembly) med ett stubbat
`auth`-schema, och går igenom sökning, sekretess, behörigheter, dubblettskydd, historik och utdrag. Inget Docker behövs.

---

## 7. Öppna frågor inför produktion

| Fråga | Nuvarande antagande |
| --- | --- |
| Ska sökning kräva inloggning? | Nej – sökning och registerpost är öppna, belopp döljs. Ändra genom att ta bort `anon` från `grant execute` |
| Vem verifierar identitet (`identity_verified`)? | Sätts manuellt i databasen. Behöver en roll/funktion för besiktning eller tillverkarintegration |
| Belastningsskydd för öppen sökning | Lägg rate limiting framför API:t (t.ex. Edge Function eller Supabase-inställning) |
| Avgift för registerutdrag | Inte implementerat. Lägg betalning före `issue_extract` |
| Import av befintliga maskinparker | Gör via CSV-import i en Edge Function som anropar `register_machine` |
| Notiser (t.ex. långivare när belånad maskin byter ägare) | Database webhook på `register_events` → Edge Function → e-post |
| Gallring/GDPR | Registret innehåller främst juridiska personer. `profiles` innehåller personuppgifter – definiera gallringsregler |
