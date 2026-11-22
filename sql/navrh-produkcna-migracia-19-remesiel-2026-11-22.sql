-- DopytAI | PR #9 | OPRAVENY NAVRH produkcnej migracie, 22.11.2026
-- POZOR: ZATIAL NESPÚŠŤAŤ V PRODUKCII. Najprv overit obnovitelnu DB zalohu.
-- Predosly navrh obsahoval stary patch detailov, ktory ocakaval spolocnu
-- vetvu remesiel. Ta uz v zakladnej migracii neexistuje: je tam 17
-- samostatnych vetiev. Preto sme stary patch DETAILOV VYNECHALI.
-- Zostava zakladna migracia + patch ODHADY + patch TERMINY.
-- Vyskusana verzia produkcnych funkcnych MD5: 22.11.2026.
-- SQL neupravuje Stripe, faktury ani tabulku platieb.
-- Vsetko v jednej transakcii; RAISE EXCEPTION vyvola ROLLBACK.
-- Pred spustenim vyzaduje samostatnu technicku reviziu a zalohu.

BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

-- 0. Kontrola vstupneho stavu. Ak sa funkcie zmenili, zastavit a vsetko vratit.
DO $preflight$
DECLARE
 v_create text;
 v_safe text;
 v_buy text;
BEGIN
 SELECT pg_get_functiondef(
 'public.vytvor_dopyt_s_token_v2(text,text,text,text,text,text,text,numeric,text)'::regprocedure) INTO v_create;
 SELECT pg_get_functiondef('public.bezpecne_dopyty()'::regprocedure) INTO v_safe;
 SELECT pg_get_functiondef('public.kup_dopyt(bigint,bigint,numeric)'::regprocedure) INTO v_buy;

 IF md5(v_create) <> '566a8d4ff9e9e27ab7aa6e3cc62fd0e1'
  OR md5(v_safe) <> 'd45f9ecf839e7e955ada8282f21f7ca8'
  OR md5(v_buy) <> 'a5016e77c74e5552a59f42aa5b6ca78c'
 THEN RAISE EXCEPTION 'DopytAI: schema nie je zhodna s auditom. ROLLBACK.'; END IF;

 IF EXISTS(
   SELECT 1 FROM public.odomknute_dopyty
   WHERE dopyt_id IS NOT NULL
   GROUP BY dopyt_id HAVING count(*)>1
 ) THEN RAISE EXCEPTION 'DopytAI: uz existuju duplicitne nakupy. ROLLBACK.'; END IF;
END $preflight$;

-- Zabezpecit unikátny nákup aj na urovni databazoveho indexu:
CREATE UNIQUE INDEX IF NOT EXISTS
  dopytai_unikatny_nakup_dopytu_idx
ON public.odomknute_dopyty (dopyt_id)
WHERE dopyt_id IS NOT NULL;

-- Nepovolujeme priame INSERT do dopyty cez API role.
-- Vytvaranie prebieha len cez povolenu SECURITY DEFINER RPC v2.
REVOKE INSERT ON public.dopyty FROM anon, authenticated;

-- 1. Mapovanie typu dopytu na odbor firmy; jednotny zdroj pravdy pre server.
CREATE OR REPLACE FUNCTION public.dopytai_typ_firmy(p_typ_prace text)
RETURNS text
LANGUAGE sql IMMUTABLE STRICT
SET search_path TO ''
AS $body$
 SELECT CASE
   WHEN p_typ_prace IN ('Nová strecha','Rekonštrukcia strechy','Oprava / zatekanie')
     THEN 'Strechy'
   WHEN p_typ_prace = 'Sadrokartón' THEN 'Sadrokartón'
   WHEN p_typ_prace = 'Elektroinštalácie' THEN 'Elektroinštalácie'
   WHEN p_typ_prace = 'Vodoinštalácie' THEN 'Vodoinštalácie'
   WHEN p_typ_prace = 'Kúrenie' THEN 'Kúrenie'
   WHEN p_typ_prace = 'Klimatizácie' THEN 'Klimatizácie'
   WHEN p_typ_prace = 'Murárske práce' THEN 'Murárske práce'
   WHEN p_typ_prace = 'Fasády a zateplenie' THEN 'Fasády a zateplenie'
   WHEN p_typ_prace = 'Maliarske práce' THEN 'Maliarske práce'
   WHEN p_typ_prace = 'Obklady a dlažby' THEN 'Obklady a dlažby'
   WHEN p_typ_prace = 'Podlahy' THEN 'Podlahy'
   WHEN p_typ_prace = 'Okná a dvere' THEN 'Okná a dvere'
   WHEN p_typ_prace = 'Tesárske práce' THEN 'Tesárske práce'
   WHEN p_typ_prace = 'Hydroizolácie' THEN 'Hydroizolácie'
   WHEN p_typ_prace = 'Zámková dlažba' THEN 'Zámková dlažba'
   WHEN p_typ_prace = 'Ploty a brány' THEN 'Ploty a brány'
   WHEN p_typ_prace = 'Zemné práce' THEN 'Zemné práce'
   WHEN p_typ_prace = 'Rekonštrukcie kúpeľní' THEN 'Rekonštrukcie kúpeľní'
   WHEN p_typ_prace = 'Betonárske práce' THEN 'Betonárske práce'
   ELSE NULL
 END;
$body$;

-- Tento helper nie je klientsky endpoint.
REVOKE ALL ON FUNCTION public.dopytai_typ_firmy(text) FROM PUBLIC, anon, authenticated;


-- 2. Povolene remesla: validacia aj v starsom vnutornom RPC, aby sa
-- whitelist vo v2 nedal obist priamym zavolanim vnutornej funkcie.
-- Nutne vykonat ako SECURITY DEFINER pod vlastnikom funkcii.
CREATE OR REPLACE FUNCTION public.vytvor_dopyt_s_token(
 p_meno text, p_telefon text, p_email text, p_typ_prace text,
 p_lokalita text, p_region text, p_popis text, p_odhad_ceny numeric
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $body$
DECLARE
 v_id bigint;
 v_token uuid := gen_random_uuid();
BEGIN
 IF nullif(btrim(p_meno), '') IS NULL
   OR nullif(btrim(p_telefon), '') IS NULL
   OR nullif(btrim(p_email), '') IS NULL
   OR nullif(btrim(p_lokalita), '') IS NULL
   OR nullif(btrim(p_region), '') IS NULL
   OR public.dopytai_typ_firmy(p_typ_prace) IS NULL
   OR p_odhad_ceny IS NULL OR p_odhad_ceny < 0
 THEN
   RAISE EXCEPTION 'Neplatne udaje dopytu';
 END IF;

 INSERT INTO public.dopyty (
   meno, telefon, email, typ_prace, lokalita, region, popis, odhad_ceny, stav
 ) VALUES (
   p_meno, p_telefon, p_email, p_typ_prace, p_lokalita, p_region,
   p_popis, p_odhad_ceny, 'caka_na_overenie'
 ) RETURNING id INTO v_id;

 INSERT INTO private.dopyt_upload_auth(dopyt_id,token,expires_at)
 VALUES(v_id,v_token,now() + interval '30 minutes');
 RETURN jsonb_build_object('id',v_id,'upload_token',v_token);
END
$body$;

-- Obmedzenie starsieho endpointu na klientskom API. V2 ako SECURITY DEFINER
-- nadalej dokaze volat starsiu funkciu pri rovnakom vlastnikovi.
REVOKE EXECUTE ON FUNCTION public.vytvor_dopyt_s_token(
 text,text,text,text,text,text,text,numeric
) FROM PUBLIC, anon, authenticated;

-- 3. V2 validuje povoleny typ, email a okres.
CREATE OR REPLACE FUNCTION public.vytvor_dopyt_s_token_v2(
 p_meno text, p_telefon text, p_email text, p_typ_prace text,
 p_lokalita text, p_region text, p_popis text,
 p_odhad_ceny numeric, p_okres text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $body$
DECLARE v_vysledok jsonb; v_id bigint;
BEGIN
 IF public.dopytai_typ_firmy(p_typ_prace) IS NULL
 THEN RAISE EXCEPTION 'Nepovoleny typ prace.'; END IF;
 IF NULLIF(btrim(p_email),'') IS NULL
 THEN RAISE EXCEPTION 'Email je povinny.'; END IF;
 IF NULLIF(btrim(p_okres),'') IS NULL
 THEN RAISE EXCEPTION 'Okres je povinny.'; END IF;

 v_vysledok := public.vytvor_dopyt_s_token(
   p_meno,p_telefon,p_email,p_typ_prace,p_lokalita,
   p_region,p_popis,p_odhad_ceny
 );
 v_id := (v_vysledok->>'id')::bigint;
 UPDATE public.dopyty SET okres=btrim(p_okres) WHERE id=v_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Okres sa nepodarilo ulozit.'; END IF;
 RETURN v_vysledok;
END
$body$;


-- 4. Bezpecny nakup: auth, stav firmy, remeslo, stav dopytu,
-- exkluzivita, serverova cena a atomicky odpocet kreditu.
-- KRAJ ANI OKRES NESMU OBMEDZOVAT VIDITELNOST ALEBO NAKUP.
-- Kraj pouzit iba pre emailove upozornenia firmam daneho remesla.
CREATE OR REPLACE FUNCTION public.kup_dopyt(
 p_firma_id bigint, p_dopyt_id bigint, p_suma numeric
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $body$
DECLARE
 v_firma_id bigint;
 v_firma_stav text;
 v_firma_typ text;
 v_cena numeric;
 v_stav text;
 v_typ text;
BEGIN
 SELECT id,stav,typ_prace
 INTO v_firma_id,v_firma_stav,v_firma_typ
 FROM public.firmy
 WHERE auth_user_id=auth.uid();

 IF v_firma_id IS NULL OR v_firma_id<>p_firma_id
 THEN RAISE EXCEPTION 'Neplatna firma.'; END IF;
 IF v_firma_stav <> 'aktivna'
 THEN RAISE EXCEPTION 'Firma nie je aktivna.'; END IF;

 SELECT cena_dopytu,stav,typ_prace
 INTO v_cena,v_stav,v_typ
 FROM public.dopyty
 WHERE id=p_dopyt_id
 FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Dopyt neexistuje.'; END IF;
 IF v_stav IS DISTINCT FROM 'novy'
 THEN RAISE EXCEPTION 'Dopyt nie je dostupny.'; END IF;
 IF v_cena IS NULL OR v_cena<=0
 THEN RAISE EXCEPTION 'Neplatna cena dopytu.'; END IF;
 IF public.dopytai_typ_firmy(v_typ) IS DISTINCT FROM v_firma_typ
 THEN RAISE EXCEPTION 'Dopyt nepatri do remesla firmy.'; END IF;

 IF EXISTS(SELECT 1 FROM public.odomknute_dopyty WHERE dopyt_id=p_dopyt_id)
 THEN RAISE EXCEPTION 'Dopyt uz bol odomknuty.'; END IF;

 UPDATE public.firmy SET kredit=kredit-v_cena
 WHERE id=v_firma_id AND kredit>=v_cena;
 IF NOT FOUND THEN RAISE EXCEPTION 'Nedostatok kreditu.'; END IF;

 INSERT INTO public.odomknute_dopyty(firma_id,dopyt_id)
 VALUES(v_firma_id,p_dopyt_id);
END
$body$;


CREATE OR REPLACE FUNCTION public.bezpecne_dopyty()
RETURNS SETOF public.dopyty
LANGUAGE sql
SECURITY DEFINER
SET search_path TO ''
AS $function$
SELECT
  d.id,
  d.created_at,

  CASE WHEN od.firma_id IS NOT NULL THEN d.meno END,
  CASE WHEN od.firma_id IS NOT NULL THEN d.telefon END,

  d.typ_prace,
  d.lokalita,

  CASE
    WHEN od.firma_id IS NOT NULL THEN d.popis

    WHEN d.typ_prace = 'Sadrokartón' THEN
      concat_ws(
        E'\n',
        'Plocha: ' || COALESCE(
          (regexp_match(d.popis, '(?m)^Plocha: ([0-9]{1,5}) m²$'))[1],
          'neuvedená'
        ) || ' m²',
        'Typ sadrokartónu: ' || COALESCE(
          (regexp_match(
            d.popis,
            '(?m)^Typ sadrokartónu: (Priečky|Podhľady|Predsadené steny|Iné)$'
          ))[1],
          'neuvedený'
        ),
        CASE WHEN d.popis ~ '(?m)^Typ sadrokartónu: Iné$' THEN
          'Konkrétna práca: ' || COALESCE(
            (regexp_match(
              d.popis,
              '(?m)^Konkrétna práca: (Oprava sadrokartónu|Obklad podkrovia|Zakrytie rozvodov|Dekoratívne konštrukcie|Ostatné sadrokartónové práce)$'
            ))[1], 'neuvedená'
          )
        END,
        'Kraj: ' || COALESCE(
          (regexp_match(
            d.popis,
            '(?m)^Kraj: (Bratislavský kraj|Trnavský kraj|Trenčiansky kraj|Nitriansky kraj|Žilinský kraj|Banskobystrický kraj|Prešovský kraj|Košický kraj)$'
          ))[1],
          'neuvedený'
        ),
        'Termín: ' || COALESCE(
          (regexp_match(
            d.popis,
            '(?m)^Termín: (Čo najskôr|Do 1–3 mesiacov|Do 3–6 mesiacov|Len zisťujem cenu)$'
          ))[1],
          'neuvedený'
        ),
        CASE WHEN d.popis ~ '(?m)^Typ sadrokartónu: Iné$' THEN
          'Odhad: Individuálne podľa rozsahu prác'
        ELSE
          'Odhad: ' || COALESCE(
            (regexp_match(
              replace(replace(d.popis, chr(160), ' '), chr(8239), ' '),
              '(?m)^Odhad: ([0-9 ]+[–-][0-9 ]+ €)$'
            ))[1],
            'neuvedený'
          )
        END
      )

    WHEN d.typ_prace = 'Elektroinštalácie' THEN
      concat_ws(
        E'\n',
        'Typ elektroinštalácie: ' || COALESCE(
          (regexp_match(
            d.popis,
            '(?m)^Typ elektroinštalácie: (Kompletná elektroinštalácia|Čiastočná elektroinštalácia|Oprava alebo porucha|Elektroinštalačná revízia)$'
          ))[1], 'neuvedený'
        ),
        'Objekt: ' || COALESCE(
          (regexp_match(d.popis, '(?m)^Objekt: (Rodinný dom|Byt|Iný objekt)$'))[1],
          'neuvedený'
        ),
        'Plocha objektu: ' || COALESCE(
          (regexp_match(d.popis, '(?m)^Plocha objektu: ([0-9]{1,5} m²)$'))[1],
          'neuvedená'
        ),
        'Kraj: ' || COALESCE(
          (regexp_match(
            d.popis,
            '(?m)^Kraj: (Bratislavský kraj|Trnavský kraj|Trenčiansky kraj|Nitriansky kraj|Žilinský kraj|Banskobystrický kraj|Prešovský kraj|Košický kraj)$'
          ))[1], 'neuvedený'
        ),
        'Termín: ' || COALESCE(
          (regexp_match(
            d.popis,
            '(?m)^Termín: (Čo najskôr|Do 1–3 mesiacov|Do 3–6 mesiacov|Len zisťujem cenu)$'
          ))[1], 'neuvedený'
        ),
        'Odhad: Individuálne podľa rozsahu prác'
      )

    WHEN d.typ_prace = 'Vodoinštalácie' THEN
      concat_ws(
        E'\n',
        'Druh práce: ' || COALESCE(
          (SELECT t.praca FROM (
            SELECT (regexp_match(d.popis, '(?m)^Druh práce: ([^\r\n]{1,100})$'))[1] AS praca
          ) t WHERE t.praca IN ('Nové rozvody vody a odpadu', 'Oprava úniku vody', 'Montáž sanity', 'Iné vodoinštalačné práce')),
          'neuvedený'
        ),
        'Rozsah: ' || COALESCE(
          (regexp_match(d.popis, '(?m)^Rozsah: ([0-9]{1,5}(?:[.,][0-9])? (?:m²|m³|bm|ks))$'))[1],
          'neuvedený'
        ),
        'Kraj: ' || COALESCE(d.region, 'neuvedený'),
        'Okres: ' || COALESCE(d.okres, 'neuvedený')
      )
    WHEN d.typ_prace = 'Kúrenie' THEN
      concat_ws(
        E'\n',
        'Druh práce: ' || COALESCE(
          (SELECT t.praca FROM (
            SELECT (regexp_match(d.popis, '(?m)^Druh práce: ([^\r\n]{1,100})$'))[1] AS praca
          ) t WHERE t.praca IN ('Podlahové kúrenie', 'Radiátory a rozvody', 'Výmena zdroja vykurovania', 'Oprava kúrenia')),
          'neuvedený'
        ),
        'Rozsah: ' || COALESCE(
          (regexp_match(d.popis, '(?m)^Rozsah: ([0-9]{1,5}(?:[.,][0-9])? (?:m²|m³|bm|ks))$'))[1],
          'neuvedený'
        ),
        'Kraj: ' || COALESCE(d.region, 'neuvedený'),
        'Okres: ' || COALESCE(d.okres, 'neuvedený')
      )
    WHEN d.typ_prace = 'Klimatizácie' THEN
      concat_ws(
        E'\n',
        'Druh práce: ' || COALESCE(
          (SELECT t.praca FROM (
            SELECT (regexp_match(d.popis, '(?m)^Druh práce: ([^\r\n]{1,100})$'))[1] AS praca
          ) t WHERE t.praca IN ('Montáž klimatizácie', 'Servis a čistenie', 'Oprava klimatizácie', 'Multi-split systém')),
          'neuvedený'
        ),
        'Rozsah: ' || COALESCE(
          (regexp_match(d.popis, '(?m)^Rozsah: ([0-9]{1,5}(?:[.,][0-9])? (?:m²|m³|bm|ks))$'))[1],
          'neuvedený'
        ),
        'Kraj: ' || COALESCE(d.region, 'neuvedený'),
        'Okres: ' || COALESCE(d.okres, 'neuvedený')
      )
    WHEN d.typ_prace = 'Murárske práce' THEN
      concat_ws(
        E'\n',
        'Druh práce: ' || COALESCE(
          (SELECT t.praca FROM (
            SELECT (regexp_match(d.popis, '(?m)^Druh práce: ([^\r\n]{1,100})$'))[1] AS praca
          ) t WHERE t.praca IN ('Nové murivo', 'Vnútorné priečky', 'Omietky', 'Stavebné úpravy')),
          'neuvedený'
        ),
        'Rozsah: ' || COALESCE(
          (regexp_match(d.popis, '(?m)^Rozsah: ([0-9]{1,5}(?:[.,][0-9])? (?:m²|m³|bm|ks))$'))[1],
          'neuvedený'
        ),
        'Kraj: ' || COALESCE(d.region, 'neuvedený'),
        'Okres: ' || COALESCE(d.okres, 'neuvedený')
      )
    WHEN d.typ_prace = 'Fasády a zateplenie' THEN
      concat_ws(
        E'\n',
        'Druh práce: ' || COALESCE(
          (SELECT t.praca FROM (
            SELECT (regexp_match(d.popis, '(?m)^Druh práce: ([^\r\n]{1,100})$'))[1] AS praca
          ) t WHERE t.praca IN ('Zateplenie fasády', 'Nová fasádna omietka', 'Oprava fasády', 'Iné fasádne práce')),
          'neuvedený'
        ),
        'Rozsah: ' || COALESCE(
          (regexp_match(d.popis, '(?m)^Rozsah: ([0-9]{1,5}(?:[.,][0-9])? (?:m²|m³|bm|ks))$'))[1],
          'neuvedený'
        ),
        'Kraj: ' || COALESCE(d.region, 'neuvedený'),
        'Okres: ' || COALESCE(d.okres, 'neuvedený')
      )
    WHEN d.typ_prace = 'Maliarske práce' THEN
      concat_ws(
        E'\n',
        'Druh práce: ' || COALESCE(
          (SELECT t.praca FROM (
            SELECT (regexp_match(d.popis, '(?m)^Druh práce: ([^\r\n]{1,100})$'))[1] AS praca
          ) t WHERE t.praca IN ('Maľovanie interiéru', 'Maľovanie exteriéru', 'Stierkovanie', 'Tapetovanie')),
          'neuvedený'
        ),
        'Rozsah: ' || COALESCE(
          (regexp_match(d.popis, '(?m)^Rozsah: ([0-9]{1,5}(?:[.,][0-9])? (?:m²|m³|bm|ks))$'))[1],
          'neuvedený'
        ),
        'Kraj: ' || COALESCE(d.region, 'neuvedený'),
        'Okres: ' || COALESCE(d.okres, 'neuvedený')
      )
    WHEN d.typ_prace = 'Obklady a dlažby' THEN
      concat_ws(
        E'\n',
        'Druh práce: ' || COALESCE(
          (SELECT t.praca FROM (
            SELECT (regexp_match(d.popis, '(?m)^Druh práce: ([^\r\n]{1,100})$'))[1] AS praca
          ) t WHERE t.praca IN ('Obklad kúpeľne', 'Pokládka interiérovej dlažby', 'Pokládka terasovej dlažby', 'Oprava obkladov')),
          'neuvedený'
        ),
        'Rozsah: ' || COALESCE(
          (regexp_match(d.popis, '(?m)^Rozsah: ([0-9]{1,5}(?:[.,][0-9])? (?:m²|m³|bm|ks))$'))[1],
          'neuvedený'
        ),
        'Kraj: ' || COALESCE(d.region, 'neuvedený'),
        'Okres: ' || COALESCE(d.okres, 'neuvedený')
      )
    WHEN d.typ_prace = 'Podlahy' THEN
      concat_ws(
        E'\n',
        'Druh práce: ' || COALESCE(
          (SELECT t.praca FROM (
            SELECT (regexp_match(d.popis, '(?m)^Druh práce: ([^\r\n]{1,100})$'))[1] AS praca
          ) t WHERE t.praca IN ('Vinylová podlaha', 'Laminátová podlaha', 'Drevená podlaha', 'Príprava a nivelizácia')),
          'neuvedený'
        ),
        'Rozsah: ' || COALESCE(
          (regexp_match(d.popis, '(?m)^Rozsah: ([0-9]{1,5}(?:[.,][0-9])? (?:m²|m³|bm|ks))$'))[1],
          'neuvedený'
        ),
        'Kraj: ' || COALESCE(d.region, 'neuvedený'),
        'Okres: ' || COALESCE(d.okres, 'neuvedený')
      )
    WHEN d.typ_prace = 'Okná a dvere' THEN
      concat_ws(
        E'\n',
        'Druh práce: ' || COALESCE(
          (SELECT t.praca FROM (
            SELECT (regexp_match(d.popis, '(?m)^Druh práce: ([^\r\n]{1,100})$'))[1] AS praca
          ) t WHERE t.praca IN ('Plastové okná', 'Drevené okná', 'Vchodové dvere', 'Interiérové dvere')),
          'neuvedený'
        ),
        'Rozsah: ' || COALESCE(
          (regexp_match(d.popis, '(?m)^Rozsah: ([0-9]{1,5}(?:[.,][0-9])? (?:m²|m³|bm|ks))$'))[1],
          'neuvedený'
        ),
        'Kraj: ' || COALESCE(d.region, 'neuvedený'),
        'Okres: ' || COALESCE(d.okres, 'neuvedený')
      )
    WHEN d.typ_prace = 'Tesárske práce' THEN
      concat_ws(
        E'\n',
        'Druh práce: ' || COALESCE(
          (SELECT t.praca FROM (
            SELECT (regexp_match(d.popis, '(?m)^Druh práce: ([^\r\n]{1,100})$'))[1] AS praca
          ) t WHERE t.praca IN ('Krov strechy', 'Drevený prístrešok', 'Terasa z dreva', 'Iné tesárske práce')),
          'neuvedený'
        ),
        'Rozsah: ' || COALESCE(
          (regexp_match(d.popis, '(?m)^Rozsah: ([0-9]{1,5}(?:[.,][0-9])? (?:m²|m³|bm|ks))$'))[1],
          'neuvedený'
        ),
        'Kraj: ' || COALESCE(d.region, 'neuvedený'),
        'Okres: ' || COALESCE(d.okres, 'neuvedený')
      )
    WHEN d.typ_prace = 'Hydroizolácie' THEN
      concat_ws(
        E'\n',
        'Druh práce: ' || COALESCE(
          (SELECT t.praca FROM (
            SELECT (regexp_match(d.popis, '(?m)^Druh práce: ([^\r\n]{1,100})$'))[1] AS praca
          ) t WHERE t.praca IN ('Izolácia základov', 'Izolácia terasy', 'Plochá strecha', 'Sanácia vlhkosti')),
          'neuvedený'
        ),
        'Rozsah: ' || COALESCE(
          (regexp_match(d.popis, '(?m)^Rozsah: ([0-9]{1,5}(?:[.,][0-9])? (?:m²|m³|bm|ks))$'))[1],
          'neuvedený'
        ),
        'Kraj: ' || COALESCE(d.region, 'neuvedený'),
        'Okres: ' || COALESCE(d.okres, 'neuvedený')
      )
    WHEN d.typ_prace = 'Zámková dlažba' THEN
      concat_ws(
        E'\n',
        'Druh práce: ' || COALESCE(
          (SELECT t.praca FROM (
            SELECT (regexp_match(d.popis, '(?m)^Druh práce: ([^\r\n]{1,100})$'))[1] AS praca
          ) t WHERE t.praca IN ('Chodníky', 'Príjazdová cesta', 'Terasa a dvor', 'Oprava dlažby')),
          'neuvedený'
        ),
        'Rozsah: ' || COALESCE(
          (regexp_match(d.popis, '(?m)^Rozsah: ([0-9]{1,5}(?:[.,][0-9])? (?:m²|m³|bm|ks))$'))[1],
          'neuvedený'
        ),
        'Kraj: ' || COALESCE(d.region, 'neuvedený'),
        'Okres: ' || COALESCE(d.okres, 'neuvedený')
      )
    WHEN d.typ_prace = 'Ploty a brány' THEN
      concat_ws(
        E'\n',
        'Druh práce: ' || COALESCE(
          (SELECT t.praca FROM (
            SELECT (regexp_match(d.popis, '(?m)^Druh práce: ([^\r\n]{1,100})$'))[1] AS praca
          ) t WHERE t.praca IN ('Nový plot', 'Posuvná brána', 'Krídlová brána', 'Oprava oplotenia')),
          'neuvedený'
        ),
        'Rozsah: ' || COALESCE(
          (regexp_match(d.popis, '(?m)^Rozsah: ([0-9]{1,5}(?:[.,][0-9])? (?:m²|m³|bm|ks))$'))[1],
          'neuvedený'
        ),
        'Kraj: ' || COALESCE(d.region, 'neuvedený'),
        'Okres: ' || COALESCE(d.okres, 'neuvedený')
      )
    WHEN d.typ_prace = 'Zemné práce' THEN
      concat_ws(
        E'\n',
        'Druh práce: ' || COALESCE(
          (SELECT t.praca FROM (
            SELECT (regexp_match(d.popis, '(?m)^Druh práce: ([^\r\n]{1,100})$'))[1] AS praca
          ) t WHERE t.praca IN ('Výkop základov', 'Prípojky a ryhy', 'Úprava terénu', 'Búranie a odvoz')),
          'neuvedený'
        ),
        'Rozsah: ' || COALESCE(
          (regexp_match(d.popis, '(?m)^Rozsah: ([0-9]{1,5}(?:[.,][0-9])? (?:m²|m³|bm|ks))$'))[1],
          'neuvedený'
        ),
        'Kraj: ' || COALESCE(d.region, 'neuvedený'),
        'Okres: ' || COALESCE(d.okres, 'neuvedený')
      )
    WHEN d.typ_prace = 'Rekonštrukcie kúpeľní' THEN
      concat_ws(
        E'\n',
        'Druh práce: ' || COALESCE(
          (SELECT t.praca FROM (
            SELECT (regexp_match(d.popis, '(?m)^Druh práce: ([^\r\n]{1,100})$'))[1] AS praca
          ) t WHERE t.praca IN ('Kompletná rekonštrukcia', 'Výmena vane alebo sprchy', 'Čiastočná rekonštrukcia', 'Samostatné WC')),
          'neuvedený'
        ),
        'Rozsah: ' || COALESCE(
          (regexp_match(d.popis, '(?m)^Rozsah: ([0-9]{1,5}(?:[.,][0-9])? (?:m²|m³|bm|ks))$'))[1],
          'neuvedený'
        ),
        'Kraj: ' || COALESCE(d.region, 'neuvedený'),
        'Okres: ' || COALESCE(d.okres, 'neuvedený')
      )
    WHEN d.typ_prace = 'Betonárske práce' THEN
      concat_ws(
        E'\n',
        'Druh práce: ' || COALESCE(
          (SELECT t.praca FROM (
            SELECT (regexp_match(d.popis, '(?m)^Druh práce: ([^\r\n]{1,100})$'))[1] AS praca
          ) t WHERE t.praca IN ('Základová doska', 'Betónový poter', 'Schodisko', 'Iné betónové práce')),
          'neuvedený'
        ),
        'Rozsah: ' || COALESCE(
          (regexp_match(d.popis, '(?m)^Rozsah: ([0-9]{1,5}(?:[.,][0-9])? (?:m²|m³|bm|ks))$'))[1],
          'neuvedený'
        ),
        'Kraj: ' || COALESCE(d.region, 'neuvedený'),
        'Okres: ' || COALESCE(d.okres, 'neuvedený')
      )

    ELSE
      concat_ws(
        E'\n',
        'Plocha: ' || COALESCE(
          (regexp_match(d.popis, '(?m)^Plocha: ([0-9]{1,5}) m²$'))[1],
          'neuvedená'
        ) || ' m²',
        'Krytina: ' || COALESCE(
          (regexp_match(
            d.popis,
            '(?m)^Krytina: (Betónová škridla|Pálená škridla|Plechová krytina|Plastový šindeľ|Neviem – chcem odporúčanie)$'
          ))[1], 'neuvedená'
        ),
        'Krov: ' || COALESCE(
          (regexp_match(d.popis, '(?m)^Krov: (Áno|Nie|Čiastočne)$'))[1],
          'neuvedený'
        ),
        'Kraj: ' || COALESCE(
          (regexp_match(
            d.popis,
            '(?m)^Kraj: (Bratislavský kraj|Trnavský kraj|Trenčiansky kraj|Nitriansky kraj|Žilinský kraj|Banskobystrický kraj|Prešovský kraj|Košický kraj)$'
          ))[1], 'neuvedený'
        ),
        'Termín: ' || COALESCE(
          (regexp_match(
            d.popis,
            '(?m)^Termín: (Čo najskôr|Do 1–3 mesiacov|Do 3–6 mesiacov|Len zisťujem cenu)$'
          ))[1], 'neuvedený'
        ),
        'Odhad: ' || COALESCE(
          (regexp_match(
            replace(replace(d.popis, chr(160), ' '), chr(8239), ' '),
            '(?m)^Odhad: ([0-9 ]+[–-][0-9 ]+ €)$'
          ))[1], 'neuvedený'
        )
      )
  END,

  d.odhad_ceny,
  d.stav,
  d.firma_id,
  d.region,
  CASE WHEN od.firma_id IS NOT NULL THEN d.email END,
  CASE WHEN od.firma_id IS NOT NULL THEN d.fotky END,
  d.cena_dopytu,
  d.anonymizovane_at,
  d.okres

FROM public.dopyty d
JOIN public.firmy f
  ON f.auth_user_id = (SELECT auth.uid())
LEFT JOIN public.odomknute_dopyty od
  ON od.dopyt_id = d.id
 AND od.firma_id = f.id

WHERE f.stav = 'aktivna'
  AND (
    od.firma_id IS NOT NULL
    OR (
      d.stav = 'novy'
      AND NOT EXISTS (
        SELECT 1 FROM public.odomknute_dopyty od2
        WHERE od2.dopyt_id = d.id
      )
    )
  )
  AND public.dopytai_typ_firmy(d.typ_prace) = f.typ_prace;
$function$;

-- Pomocne databazove a HTTP kontroly po migracii, bez realnych klientov:
DO $checks$
DECLARE v_sql text;
BEGIN
 v_sql := pg_get_functiondef('public.bezpecne_dopyty()'::regprocedure);
 IF position('public.dopytai_typ_firmy(d.typ_prace) = f.typ_prace' IN v_sql) = 0
  OR position('CASE WHEN od.firma_id IS NOT NULL THEN d.email END' IN v_sql) = 0
  OR position('d.stav = ''novy''' IN v_sql) = 0
 THEN RAISE EXCEPTION 'DopytAI: kontrola bezpecneho nahladu zlyhala. ROLLBACK.'; END IF;
 IF has_table_privilege('anon', 'public.dopyty', 'INSERT')
 THEN RAISE EXCEPTION 'DopytAI: anon ma stale INSERT. ROLLBACK.'; END IF;
 IF has_function_privilege('anon',
 'public.vytvor_dopyt_s_token(text,text,text,text,text,text,text,numeric)'::regprocedure,'EXECUTE')
 THEN RAISE EXCEPTION 'DopytAI: stare RPC je stale anonymne pristupne. ROLLBACK.'; END IF;
END $checks$;


-- Patch odhady pre 17 dalsich remesiel.
DO $patch$
DECLARE
  v_def text;
  v_ele_start int;
  v_next_start int;
  v_segment text;
  v_ele_old text := '''Odhad: Individuálne podľa rozsahu prác''';
  v_ele_new text := $price$'Odhad: ' || COALESCE(
          (regexp_match(
            replace(replace(d.popis, chr(160), ' '), chr(8239), ' '),
            '(?m)^Odhad: ([0-9 ]+[–-][0-9 ]+ €)$'
          ))[1],
          CASE WHEN d.odhad_ceny > 0
            THEN to_char(d.odhad_ceny, 'FM999999999990.##') || ' €'
            ELSE 'Individuálne podľa rozsahu prác'
          END
        )$price$;
  v_generic_old text := $$'Okres: ' || COALESCE(d.okres, 'neuvedený')$$;
  v_generic_new text := $$'Okres: ' || COALESCE(d.okres, 'neuvedený')$$
    || ',' || E'\n        ' || $price$'Odhad: ' || COALESCE(
          (regexp_match(
            replace(replace(d.popis, chr(160), ' '), chr(8239), ' '),
            '(?m)^Odhad: ([0-9 ]+[–-][0-9 ]+ €)$'
          ))[1],
          CASE WHEN d.odhad_ceny > 0
            THEN to_char(d.odhad_ceny, 'FM999999999990.##') || ' €'
            ELSE 'Individuálne podľa rozsahu prác'
          END
        )$price$;
BEGIN
  SELECT pg_get_functiondef('public.bezpecne_dopyty()'::regprocedure) INTO v_def;
  v_ele_start := strpos(v_def, 'WHEN d.typ_prace = ''Elektroinštalácie'' THEN');
  v_next_start := strpos(v_def, 'WHEN d.typ_prace = ''Vodoinštalácie'' THEN');

  IF v_ele_start = 0 OR v_next_start <= v_ele_start
    OR strpos(v_def, 'NOT EXISTS (') = 0
    OR strpos(v_def, 'SECURITY DEFINER') = 0
  THEN RAISE EXCEPTION 'STOP: Neocakavana verzia TEST funkcie; nic nezmenene.'; END IF;

  v_segment := substr(v_def, v_ele_start, v_next_start-v_ele_start);
  IF (length(v_segment)-length(replace(v_segment,v_ele_old,''))) <> length(v_ele_old)
  THEN RAISE EXCEPTION 'STOP: Elektro odhad sa nezhoduje; nic nezmenene.'; END IF;

  -- Iba elektro vetva, nikdy existujuca vetva sadrokartonu.
  v_def := overlay(v_def placing replace(v_segment,v_ele_old,v_ele_new)
                   from v_ele_start for length(v_segment));

  -- 16 dalsich remesiel, presne 16 pouziti pola Okres.
  IF (length(v_def)-length(replace(v_def,v_generic_old,''))) / length(v_generic_old) <> 16
  THEN RAISE EXCEPTION 'STOP: Pocet remesiel sa nezhoduje; nic nezmenene.'; END IF;

  v_def := replace(v_def, v_generic_old, v_generic_new);
  EXECUTE v_def;
END
$patch$;

-- Patch termin pre 16 generickych remesiel.
DO $dopytai_term_patch$
DECLARE
  v_definition text;
  v_old text := $needle$'Okres: ' || COALESCE(d.okres, 'neuvedený')$needle$;
  v_new text := $replacement$'Okres: ' || COALESCE(d.okres, 'neuvedený'),
        'Termín: ' || COALESCE(
          (regexp_match(d.popis, '(?m)^Termín: (Čo najskôr|Do 1–3 mesiacov|Do 3–6 mesiacov|Len zisťujem cenu)$'))[1],
          'neuvedený'
        )$replacement$;
  v_count integer;
BEGIN
  SELECT pg_get_functiondef('public.bezpecne_dopyty()'::regprocedure)
    INTO v_definition;
  IF v_definition IS NULL
    OR position('SECURITY DEFINER' IN v_definition) = 0
    OR position('AND public.dopytai_typ_firmy(d.typ_prace) = f.typ_prace' IN v_definition) = 0
    OR position('NOT EXISTS (' IN v_definition) = 0
    OR v_definition !~ 'WHEN[[:space:]]+od[.]firma_id[[:space:]]+IS[[:space:]]+NOT[[:space:]]+NULL[[:space:]]+THEN[[:space:]]+d[.]popis'
  THEN RAISE EXCEPTION 'STOP: DB funkcia sa nezhoduje s TEST auditom.';
  END IF;
  v_count := (length(v_definition) - length(replace(v_definition, v_old, ''))) / length(v_old);
  IF v_count <> 16 THEN
    RAISE EXCEPTION 'STOP: ocakavanych 16 generickych vetiev, najdenych %.', v_count;
  END IF;
  EXECUTE replace(v_definition, v_old, v_new);
  IF position('Termín: ' IN pg_get_functiondef('public.bezpecne_dopyty()'::regprocedure)) = 0
  THEN RAISE EXCEPTION 'STOP: termin sa neulozil.'; END IF;
END
$dopytai_term_patch$;

-- Pred commit overit strukturu a ocakavane zobrazovanie.
DO $final_guard$
DECLARE
  v_def text;
BEGIN
  SELECT pg_get_functiondef('public.bezpecne_dopyty()'::regprocedure) INTO v_def;
  IF position('WHEN d.typ_prace = ''Elektroinštalácie'' THEN' IN v_def) = 0
    OR position('WHEN d.typ_prace = ''Vodoinštalácie'' THEN' IN v_def) = 0
    OR position('Termín: ' IN v_def) = 0
    OR position('Odhad: ' IN v_def) = 0
    OR position('AND public.dopytai_typ_firmy(d.typ_prace) = f.typ_prace' IN v_def) = 0
  THEN RAISE EXCEPTION 'STOP: Neocakavany vysledok SQL; ROLLBACK'; END IF;
END
$final_guard$;

COMMIT;
