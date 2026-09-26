# Grafisk profil i koden

Källan är MaskinIDs grafiska profil (design system-artefakten "MaskinID – grafisk profil"). Profilboken ligger i
[`design-system/grafisk-profil.md`](../design-system/grafisk-profil.md) och alla tokens i
[`design-system/tokens.json`](../design-system/tokens.json).

## Tokens → CSS

`npm run tokens` läser `tokens.json` och skriver `src/styles/tokens.css` med CSS-variabler:

- färger (`--id-gul`, `--text`, `--yta-2`, `--status-sparr` …) i två teman: `ljust` (standard) och `morkt`
- typsnittsfamiljer (`--font-display`, `--font-text`, `--font-mono`)
- avstånd `--space-1`…`--space-9` (4 px-rutnät), hörn `--radius-0/1/ikon`, linjer `--stroke-*`, `--skugga-lyft`

Mörkt tema följer operativsystemet, eller väljs med knappen i sidhuvudet (`<html data-theme="morkt">`).
Ändra aldrig `tokens.css` för hand.

## Komponenter

Stilarna i `src/styles/components.css` kommer ur profilens `bundle.css` (prefix `mid-`). React-komponenterna är tunna lager ovanpå:

| Profilens komponent | Kod | Regel att komma ihåg |
| --- | --- | --- |
| Logotyp | `Wordmark` (`components/Logo.tsx`) | Negativt ordmärke på mörk botten, byts automatiskt per tema |
| IdFrame | `IdFrame`, `IdNumber` | En gång per vy, runt det viktigaste identifierade värdet |
| Button | klasserna `mid-knapp-primar/-sekundar/-kontur` | En gul primärknapp per vy. Knappar börjar med verb |
| StatusBadge | `StatusBadge` | Alltid ord och ikon. Aldrig gul |
| LookupField | `LookupField` | ID-ramen i fokus. Knappen heter "Sök i registret" |
| RecordCard | `RecordCard` | Registerlinjen överst, tre fasta fält: ägare, belåning, försäkring |
| RegisterExtract | `RegisterExtractHeader` | Ordmärke, titel, utdragsuppgifter, sigill |
| Seal | `Seal` | Bara på utfärdade dokument. Minst 96 px |

Ikoner (`components/Icon.tsx`) följer profilens geometri: 24 px-rutnät, 2 px linje, raka linjeändar, spetsiga hörn.

## Tonalitet i gränssnittet

- Klarspråk, du-tilltal, fakta först. Inga utropstecken eller emojis. Versal bara först i meningen.
- Fasta termer: *Registrerad ägare*, *Belånad / Ingen registrerad belåning*, *Långivare*, *Försäkringsgivare*, *Spärrad*, *Registerutdrag*.
- Format via `src/lib/format.ts`: "26 sep 2026" i löptext, "2026-09-26" i tabeller, "kl. 14.05", "1 250 000 kr" (hårda mellanslag).
- Fel säger vad som hände och vad man gör: "Inget resultat för 7KX0L2T4003198. Kontrollera numret på maskinens typskylt."

## Rörelse och tillgänglighet

- Den enda rörelsen: ID-ramen dras in mot värdet (200 ms ease-out) vid sökträff – `mid-ram-traff`. Av vid "reducera rörelse".
- Fokus: 2 px heldragen ring i `--fokus` med 2 px luft.
- Textfärger används bara på de ytor deras token anger (minst 4,5:1).

## Det som saknas i profilen

- **Ikonserie** – bara grunduppsättningen finns. Behövs fler: välj en öppen serie med 2 px linje och raka linjeändar.
- **Bildspråk** – inga fotografier finns ännu; startsidan använder omslagets geometriska komposition.
