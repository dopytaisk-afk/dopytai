# DopytAI – testovaci plan migracie 19 remesiel (18.11.2026)

## Stav
- Novy subor `sql/19-remesiel-test-migracia.sql` je urceny **len na izolovany test**. **Neaplikovany na Supabase**.
- Odvodeny z read-only produkcnych auditov CSV (2)–(6). Jedna atomicka transakcia, verzovane hash checks na tri kriticke funkcie, `COMMIT` az po internych kontrolach.
- Pokryva 3 strešné podtypy + SDK + 17 dalsich (elektro a 16 novych), teda 19 remeselnych kategorii.
- Celoslovenska viditelnost a moznost nakupu iba spravneho remesla; kraj len na emaily.
- Prevadzkovy flag na odosielanie v `index.html` pre 17 novych kategorii **ostava vypnuty**.
- Fotky pred kupou ostavaju dostupne cez tokenom chranenu Netlify funkciu, nie priamo cez `bezpecne_dopyty()`.
- Po novej migracii, klientsky JS musi pri novych remeslach vytvorit `typ_prace` ako presny nazov kategorie a `popis` vo whiteliste `Druh práce:\nRozsah:\nKraj:\nOkres:`. Bez tejto zmeny nové odosielanie nezapínat.
- **Nie je to produkcne schvaleny skript.** SQL nebol spusteny ani otestovany na PostgreSQL/Supabase. Syntakticke kontroly casti nie su ekvivalentom integracnych testov.

## Test izolovanej kopie schemy
1. Vytvorit izolovany TEST projekt s kopiou schemy (bez osobnych udajov, skutocnych e-mailov, secretov, kartovych transakcii a automatickych realnych webhooks).
2. Overit, ze `pg_get_functiondef` vracia hash hodnoty ako v audite. Ak sa schema v TEST vyrazne odlišuje, zmeny nevynucovat.
3. Skontrolovat sucastne `SECURITY DEFINER` vlastnictvo RPC, schema `private.dopyt_upload_auth`, GRANT/REVOKE, indexy a pomocne funkcie.
4. Spustit `sql/19-remesiel-test-migracia.sql` len v TEST. Pri chybe transakcia musi vratit stav.
5. Overit, ze volanie stareho `vytvor_dopyt_s_token` je anonymne nedostupne, `vytvor_dopyt_s_token_v2` funguje cez anon.
6. S testovacimi uctami vytvorit fake dopyt, potvrdit mail a overit spravne stavy `caka_na_overenie` -> `novy`; bez skutocnej rozosielky.
7. Dve firmy rovnakeho remesla z **dvoch krajov** musia vidiet rovnaky nepredany dopyt. Firma nespravneho remesla nesmie vidiet ani kupit.
8. Pred zakupenim skontrolovat `bezpecne_dopyty`: nulove meno, telefon, email, ziadny volny opis ani cesty k fotkam.
9. Opravnenej firme sa cez `get-lead-photos` mozu vystavit iba podpisane URL; inemu remeslu, neaktivnej firme a anonymovi 403/401.
10. Kupit dopyt testovacim kreditom; po kupe sa kontakt zobrazi iba vitazovi. Druha firma ho uz neuvidi ako dostupny ani nezaplati. Kredit sa musi odratat presne raz.
11. Potvrdenie e-mailu spusti notifikaciu iba firmam z **kraja dopytu** a rovnakeho remesla; mimo kraja nie. Pozor na existujuci INSERT webhook, ktory podla auditu posiela inu udalost.
12. Regresia: cele vytvorenie, potvrdenie, foto, kupa pre strechy a sadrokarton.
13. Až po tychto krokoch pripravit odlisne produkcne nasadenie, s novym auditom hashov, backupom funkcii, planom rollback a explicitnym suhlasom.

## Blokery / známe riziká pred produkciou
- Navrh nebol spusteny v skutocnom PostgreSQL ani v Supabase. Moze vyzadovat opravu kompatibility.
- Unikatny index `odomknute_dopyty(dopyt_id)` musi byt kompatibilny so stavom TEST dat a viazanim typov.
- Pozor na `get-lead-photos`: podpísané fotky vypršia po 10 minútach, no UI ich cacheuje. Otestovat obnovu zobrazenia.
- Existujuci legacy `INSERT` webhook je odlisny od `confirm-demand-email` workflow, ale samotny INSERT bol v notifikacnom JS odfiltrovany; overit logy bez realnych rozosielok.
- Bezpecnost volneho popisu a anonymizacia pri novych remeslach sa musia potvrdit na urovni DB a Netlify.
- Pred nasadenim v TEST skontrolovat celu logiku `anon` tabulkovych prav a `SECURITY DEFINER` vlastnikov.
