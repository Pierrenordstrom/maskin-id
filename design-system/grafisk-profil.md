MaskinID är registret där maskinhandlare, maskinägare, långivare och försäkringsbolag ser vem som äger en maskin, om den är belånad och vem som försäkrar den. Identiteten ska kännas som en myndighet – saklig, stabil och opartisk – och samtidigt som ett modernt tekniksystem: exakt, snabbt och läsbart ner till sista tecknet i ett serienummer. Allt utgår från ordmärket: den tunga, breda svarta grotesken och det gula ID:t som markerar det som är identifierat.

## Grundidé

Tre element bär profilen. Allt annat ska vara tyst.

- **Ordmärket** i `maskin-svart` och `id-gul`. Det ritas aldrig om.
- **ID-ramen** – fyra raka hörnvinklar runt det som är verifierat. Den är symbolens ram och gränssnittets starkaste markering. Använd den en gång per vy, runt det viktigaste identifierade värdet: PIN-numret i en registerpost, sökfältet i fokus eller maskinen på ett foto. Komponent: `IdFrame`.
- **Registerlinjen** – en svart toppkant på 4 px (`stroke-register` i `text`) på registerposter och registerutdrag. Den ger dokumentkänsla och ersätter skuggor och färgade kortkanter.

## Tonalitet

Skriv som en myndighet som respekterar läsarens tid: klarspråk, du-tilltal, fakta först. Inga utropstecken, inga emojis, inga superlativ. Versal bara i början av meningen – även i rubriker, knappar och etiketter.

- Säg vad som gäller: "Ingen registrerad belåning", inte "Grattis, maskinen är fri!".
- Ange källa och tid: "Uppgift från långivaren, uppdaterad 26 sep 2026 kl. 14.05."
- Knappar börjar med verb och behåller namnet genom hela flödet: "Hämta registerutdrag" ger bekräftelsen "Registerutdrag hämtat".
- Fel säger vad som hände och vad man gör: "Inget resultat för 7KX0L2T4003198. Kontrollera numret på maskinens typskylt."

Fasta termer – använd alltid samma ord:

| Använd | Undvik |
| --- | --- |
| Registrerad ägare | Innehavare, ägaren |
| Belånad / Ingen registrerad belåning | Pantsatt, skuldfri |
| Långivare | Bank, kreditgivare |
| Försäkringsgivare | Bolaget |
| Spärrad | Blockerad, flaggad |
| Registerutdrag | Rapport, intyg |

Format: datum "26 sep 2026" i löptext och "2026-09-26" i tabeller, tid "kl. 14.05", belopp "1 250 000 kr" med hårt mellanslag. Identifierare skrivs alltid i versaler med `id-nummer`. Namnet skrivs "MaskinID" – ett ord, versalt M och ID – även i löptext.

## Logotyp

Ordmärket är huvudavsändaren. Se `Logotyp` för frizon och exempel.

- `maskinid-ordmarke.svg` på vit eller ljus botten (`vit`, `yta-2`).
- `maskinid-ordmarke-negativ.svg` på `maskin-svart` eller mörka, lugna fotoytor. "Maskin" blir vitt, ID förblir gult.
- `maskinid-ordmarke-svart.svg` och `maskinid-ordmarke-vit.svg` bara när en färg är tekniskt tvingande: gravyr, stämpel, lasermärkning på maskinskylt.
- Frizon: bredden av I:et i "ID" på alla sidor. Minsta storlek: 100 px bred på skärm, 25 mm i tryck. Mindre än så – använd symbolen (minst 24 px bred).
- Gör aldrig: färga om "Maskin" eller "ID", byt plats på färgerna, lägg ordmärket på gul botten, lägg till kontur, skugga eller gradient, töj, luta eller sätt om namnet i ett annat typsnitt.

## Symbolen

Symbolen är ID:t ur ordmärket inom ID-ramen. Ramens tjocklek är densamma som D:ets horisontella stapel (cirka 17 % av versalhöjden), luften mellan ram och bokstäver cirka 19 % och hörnens armlängd cirka 49 %. Ramen har samma färg som "Maskin" i ordmärket: svart på ljus botten (`maskinid-symbol.svg`), vit på mörk (`maskinid-symbol-negativ.svg`).

- Använd symbolen där ordmärket inte ryms eller redan syns: favicon, appikon, profilbild, sigill, dekaler på maskiner och stämplar.
- Appikonen (`maskinid-appikon.svg`) är en svart platta med symbolen helt i gult. `maskinid-appikon-gul.svg` är inversen för gula miljöer. Plattan rundas med `radius-ikon`.
- Ställ aldrig symbolen bredvid ordmärket – ID skulle stå två gånger. Välj det ena.

## Färg

Paletten är svart, vitt och en gul. Ungefärlig fördelning på en sida: 70 % `yta` och `yta-2`, 25 % `text`, högst 5 % `id-gul`.

- `id-gul` betyder MaskinID: logotypen, den primära handlingen (en gul knapp per vy) och ID-markeringar. Aldrig som text på ljus botten – använd `id-text`. Text på gult är alltid `pa-gul`, aldrig vit.
- Statusfärgerna (`status-verifierad`, `status-belanad`, `status-sparr`) används bara för registerstatus, alltid med ord och ikon. Gult betyder aldrig status.
- Tryck: svart CMYK 0/0/0/100 (på stora ytor rik svart 60/40/40/100) och gul CMYK 0/39/90/0. Välj Pantone-dekorfärg mot ett provtryck av originalet, inte mot skärmen.

## Typografi

- Rubriker i `display` (Archivo Expanded 800) – bred och tung, nära släkt med ordmärket. Stilar: `display`, `rubrik-1` till `rubrik-4`. Vänsterställt, tätt radavstånd.
- Löptext i `text` (Archivo): `ingress`, `brodtext`, `brodtext-liten`, `etikett`, `knapp`. Högst cirka 70 tecken per rad.
- `mono` (IBM Plex Mono) bara för riktiga identifierare: PIN, serienummer, registernummer, org.nr. Stilar: `id-nummer`, `id-nummer-liten`, med tabellsiffror och överstruken nolla.
- Där webbfonter inte fungerar (Office, e-post): Arial Black för rubriker, Arial för text, Consolas för identifierare.

## Layout

- 12 kolumner, 24 px mellanrum (`space-5`) och 4 px grundrutnät (`space-1` till `space-9`). Vänsterställt; centrerat bara i sigill och appikon.
- Raka hörn (`radius-0`) på poster, kort, tabeller och bilder. `radius-1` bara på knappar, fält och statusmärkningar.
- Avgränsa med `linje` och `yta-2`, inte med skuggor. `skugga-lyft` bara på flytande lager som menyer och dialoger.
- Uppgifter står som definitionslistor: etikett i `etikett` och `text-sekundar` ovanför värdet i `brodtext` och `text`.

## Ikoner

Det finns ännu ingen ikonserie. Rita ikoner på ett 24 px-rutnät med 2 px linje, raka linjeändar och spetsiga hörn – samma geometri som ID-ramen. Ikonen ärver textens färg. Inga fyllda ikoner och inga emojis. Komponenterna innehåller grunduppsättningen: bock (verifierad), hänglås (belånad), varningstriangel (spärrad), förstoringsglas (sök) och nedladdning (utdrag). Behövs fler, välj en öppen serie med raka linjeändar och 2 px linje och lägg den i en egen tillgångsgrupp.

## Bildspråk

Dokumentära fotografier av riktiga maskiner i arbete – grävmaskiner, hjullastare, skogsmaskiner – i naturligt ljus. Närbilder på typskyltar och serienummer förstärker registerkänslan. Inga handslag och inga leende modeller vid laptops. ID-ramen får läggas över ett foto för att peka ut maskinen; ramen är då `vit` eller `id-gul`.

## Rörelse

Profilen står still. En rörelse är tillåten: när en sökning ger träff dras ID-ramens hörn in mot det identifierade värdet på 200 ms med ease-out. Vid "reducera rörelse" visas ramen direkt.

## Tillgänglighet

Fokus markeras med en heldragen ring på 2 px i `fokus` med 2 px luft. Varje texttoken anger vilka ytor den håller minst 4,5:1 på – håll dig till de paren. Status bärs alltid av ord och ikon, aldrig av färg ensam.
