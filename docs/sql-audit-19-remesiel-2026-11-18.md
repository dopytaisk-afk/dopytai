# Audit Supabase pred spoločným SQL pre 19 remesiel

Stav 18. 11. 2026. Podkladom sú dva CSV exporty z produkčného Supabase SQL Editora; ide o **read-only audit**, nie vykonanú migráciu.

## Potvrdené
- `dopyty.typ_prace` a `firmy.typ_prace` sú text, bez CHECK obmedzenia na zoznam remesiel.
- `dopyty.cena_dopytu` má predvolenú hodnotu `25` (to neznamená, že každá kategória má mať rovnakú cenu).
- `vytvor_dopyt_s_token_v2` povoľuje len 3 strešné typy + `Sadrokartón`; používa `vytvor_dopyt_s_token`, zapisuje okres a vracia token.
- `vytvor_dopyt_s_token` vytvorí dopyt v stave `caka_na_overenie` a 30-minútový upload token v `private.dopyt_upload_auth`.
- `bezpecne_dopyty` je SECURITY DEFINER, vracia `SETOF dopyty` so stĺpcami v presnom poradí, skryje `meno`, `telefon`, `email` a `fotky` pred odomknutím; `popis` pred odomknutím sanitizuje pre strechy a SDK. Filtruje len tieto remeslá; budúca podpora musí pred kúpou sanitizovať aj 17 ďalších.
- `kup_dopyt` overuje vlastníctvo firmy cez `auth.uid()`, stav `novy`, serverovú `cena_dopytu`, kredit a používa `FOR UPDATE`. **Neoveruje však remeslo ani stav firmy, región a to, či firmy smú kúpiť daný dopyt.** Parameter `p_suma` sa nepoužíva. Kritická oprava pred rozšírením a vhodná aj pre existujúce remeslá.
- V `odomknute_dopyty` je unikátny len pár `(firma_id,dopyt_id)`, nie samotný `dopyt_id`. Exkluzivita aktuálne závisí na `kup_dopyt` a transakčnom zámku; pre budúcnosť posúdiť UNIQUE `dopyt_id` až po overení historických dát.
- `rezervuj_upozornenie_v2` nemá SECURITY DEFINER, pred vložením overí `dopyty.stav='novy'`; pre notifikácie treba aktualizovať aj serverový JS matching na kraj + remeslo.
- RLS pre `dopyty`: admin SELECT/UPDATE + `anon` INSERT WITH CHECK true. RLS samo osebe nevypovedá o tom, kto má reálne SQL GRANT; treba overiť oprávnenia.
- Z auditu je známy AFTER INSERT trigger `dopytai_novy_dopyt_email`; treba overiť jeho vykonanie (a ďalšie súvisiace NOTIFY/verification procesy), aby sa pre nové remeslá nemenilo správanie existujúcich správ.

## Hashové kotvy aktuálnych definícií (`md5(pg_get_functiondef(...))`)
- `bezpecne_dopyty`: `d45f9ecf839e7e955ada8282f21f7ca8`
- `kup_dopyt`: `a5016e77c74e5552a59f42aa5b6ca78c`
- `rezervuj_upozornenie_v2`: `0c6e92ec07fdcf0c477e362fe99e4e1e`
- `vytvor_dopyt_s_token`: `f117f56e2cb3b05385cf4cd98657fec7`
- `vytvor_dopyt_s_token_v2`: `566a8d4ff9e9e27ab7aa6e3cc62fd0e1`

## Návrh
1. Jedna centrálna databázová whitelist mapa remesiel (v migrácii explicitné typy, prípadne tabuľka katalógu po kontrole bezpečnosti RPC), bez opakovania funkcií pre každú kategóriu.
2. Zachovať pôvodné strešné a sadrokartónové formáty, bezpečné prezentačné whitelisty pre ďalšie typy, ochranu kontaktov aj po kúpe.
3. Spevniť `kup_dopyt`: serverovo overiť stav firmy, typ remesla, prípadne kraj podľa finálneho pravidla, a exkluzivitu; zachovať atomický odpočet kreditu.
4. Zabezpečiť, aby nový typ práce pred emailovým potvrdením nezískal stav `novy` a nevyvolal notifikácie.
5. **Pred migračným SQL** skontrolovať efektívne GRANT/EXECUTE oprávnenia, trigger, DB role a existujúce možné duplicitné odomknutia (iba agregovaným SELECT); potom až navrhnúť transakčný skript s precondition hash kontrolou.
6. Vždy vychádzať z aktuálneho exportu funkcií, nikdy nepoužiť starý elektro string-replacement skript.

Žiadny SQL príkaz z tohto dokumentu nebol aplikovaný na Supabase; `main` zostáva nezmenený.
