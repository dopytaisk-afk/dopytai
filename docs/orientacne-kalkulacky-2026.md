# DopytAI – orientačné kalkulačky pre 16 nových remesiel (18. 11. 2026)

## Účel a rozsah
Pripravených 16 kategórií a 64 podtypov prác v existujúcom súbore `index.html`.
- 51 podtypov má hrubé cenové rozpätie.
- 13 podtypov má individuálne nacenenie (bez nepresného čísla).
- Jednotky: `m²`, `m³`, `bm` (bežný meter), `ks`; sú priradené konkrétnemu podtypu.
- Výsledok = množstvo × rozsah sadzby (zaokrúhlené na 5 €). Malé zákazky využívajú **modelové**, nie skutočne účtované minimum, ktoré sa v aplikácii vysvetľuje.
- Ide o **redakčné približné sadzby**. Jednotlivé sadzby nie sú doslovným prepisom ani cenovou ponukou konkrétneho poskytovateľa.
- Odhad zahŕňa len bežnú prácu; neobsahuje materiál, dopravu ani DPH. Složitý prístup, čas, región, atypické rozmery, demolácia, odvoz a ďalšie technologické kroky cenu výrazne zmenia.
- Keďže sa zdrojové cenníky významne líšia v definíciách výkonu a rozsahu materiálu, nesmie sa porovnávať „samotná práca“ s kompletnou dodávkou.
- Kalkulačky **zatiaľ len lokálne zobrazujú orientačné čísla** vo vývojovej vetve. Nie sú napojené na vytvorenie nového dopytu a nijako nemenia bezpečné existujúce workflow strechy/sadrokartón.

## Overené referenčné podklady z novembra 2026
1. [NUMIQ – slovenské stavebné práce a jednotkové položky](https://numiq.com/sk/stavebne-prace/) – kategórie a typy sadzieb, nie nevyhnutne porovnateľné celky.
2. [NUMIQ – cenník stavebných prác 2026](https://numiq.com/sk/blog/cennik-stavebnych-prac-2026-prehlad-cien/) – orientácia v sadzbách za prácu a v rozdieloch rozsahu.
3. [NUMIQ – montáž klimatizácie, cena 2026](https://numiq.com/sk/stavebne-prace/montaz-klimatizacie/) – napr. štandardná split montáž 299,30 €/ks v uvedenom rozsahu.
4. [Zámková.sk – orientačné ceny pokládky 2026](https://zamkova.sk/cena-pokladky-zamkovej-dlazby/) – jednoduchá pokládka cca 15–25 €/m² bez materiálu.
5. [NUMIQ – zámková dlažba a obrubníky 2026](https://numiq.com/sk/stavebne-prace/zamkova-dlazba-obrubniky/) – samostatná práca na dlažbe od 11 €/m², obvykle s iným rozsahom ako pri kompletnom teréne.
6. [Renovopro – orientačný remeselný cenník 2026](https://www.renovopro.sk/cennik/) – maľovanie, nivelácia, obklady a lokálne rekonštrukčné úkony.
7. [Domy pre mladých – porovnávanie m², bm, ks a DPH](https://domypremladych.sk/cennik-stavebnych-prac/) – vysvetlenie rozdielov medzi definíciami cien.
8. [Flavio – montáž klimatizácie](https://www.flavio.sk/cena/montaz-klimatizacie) – orientačný trh, individuálny rozsah montáže.

## Príklady, nie cenník DopytAI
- Maľovanie interiéru 60 m²: model 3–7 €/m² = približne 180–420 € len práca.
- Jednoduchá pokládka zámkovej dlažby 30 m²: model 15–25 €/m² = približne 450–750 € len práca.
- Štandardná montáž 1 split klimatizácie: model 250–420 € za bežnú prácu.
- Kompletná rekonštrukcia kúpeľne: individuálne (rozsah prác nemožno vyjadriť jedným spravodlivým m² koeficientom).

## Riziká a kontrolný postup
1. Overiť, či HTML súbor z vývojovej vetvy zobrazuje všetkých 16 kategórií správne aj na mobile.
2. Pre každé 4 podtypy skontrolovať príslušnú jednotku alebo individuálnu vetvu, nulové hodnoty, desatinné čísla pre `ks`, chýbajúce čísla.
3. Prepojiť odhady so správnou kategóriou po návrhu bezpečnej DB architektúry; kým nie je hotová, odosielanie v `submit` handleri ostáva zakázané.
4. Pri prípadnom spustení získať živé cenové ponuky z regiónov, aktualizovať konfiguračné sadzby a testovať znovu.
5. Zámerne ponechať pôvodné kalkulačky strechy, sadrokartón a elektro bez úprav.

## Bezpečnosť nasadenia
Zmeny **len** v `feature/elektroinstalacie`, PR #9 stále draft. Produkčná `main` a produkčný Supabase sa nemenia. HTML/JS nemožno označiť za úplne integračne otestované, kým sa manuálne neskontroluje na Netlify preview.
