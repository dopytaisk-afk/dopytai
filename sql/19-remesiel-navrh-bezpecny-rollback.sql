-- DopytAI / spolocny backend pre 19 remesiel (NÁVRH, NESPUSTAJTE NA PRODUKCII)
-- Tento subor nie je schvalena migracia; je to kontrolny navrh so zabezpecenim fail-closed.
-- Overene podklady: Supabase read-only exporty (3)-(6) z 18.11.2026.
-- Pred vykonanim: skopirovat do izolovaneho TEST projektu, skontrolovat DB funkcie
-- a ich md5, vykonat test vytvorenia, overenia emailu, nacitania, kupy a notifikacii.
--
-- Poznamka: V DB su tri typy strechy + Sadrokarton + 17 dalsich kategorii (Elektro + 16).
-- Elektro a 16 dalsich maju podla sucasneho auditu BLOKOVANE ODOSIELANIE na webe.
-- Priamo do produkcie tento navrh NEPOUZIT.

BEGIN;

-- 0. Kontrola povodnych definicii pred akymkolvek zasahom.
DO $guard$
DECLARE
 v_create text;
 v_safe text;
 v_buy text;
BEGIN
 SELECT pg_get_functiondef('public.vytvor_dopyt_s_token_v2(text,text,text,text,text,text,text,numeric,text)'::regprocedure) INTO v_create;
 SELECT pg_get_functiondef('public.bezpecne_dopyty()'::regprocedure) INTO v_safe;
 SELECT pg_get_functiondef('public.kup_dopyt(bigint,bigint,numeric)'::regprocedure) INTO v_buy;
 IF md5(v_create) <> '566a8d4ff9e9e27ab7aa6e3cc62fd0e1'
   OR md5(v_safe) <> 'd45f9ecf839e7e955ada8282f21f7ca8'
   OR md5(v_buy) <> 'a5016e77c74e5552a59f42aa5b6ca78c'
 THEN
   RAISE EXCEPTION 'DB funkcie sa zmenili oproti auditu. STOP, bez zapisu.';
 END IF;
END
$guard$;

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

-- 5. Bezpecne_dopyty: aktualna produkcna funkcia bola auditovana,
-- ale jej presne stlpcove poradie a whitelist sa NEMOZU prepisat bez
-- detailnych integracnych testov. Preto ju v tomto konceptualnom skripte
-- zamerne NEMENIME; tento subor je NEUPLNY a NESPUSŤAT.
--
-- Pred schvalenim finalnej migracie sa sem musi doplnit:
--   * branch pre Elektro + 16 novych remesiel bez sukromneho popisu pred kupou
--   * filter pre remeslo (bez podmienky na kraj/okres)
--   * stav='novy' pri neodomknutych dopytoch
--   * zachovanie vsetkych 16 stlpcov v presnom poradi
--   * regression test pre Strechy a Sadrokarton
--   * audit foto pristupu (fotky maju byt viditelne pred kupou bez URL tokenov)
--   * audit webhooku INSERT vs UPDATE (notifikacie len po potvrdeni emailu)
--   * EMAILY len firmam z kraja dopytu a spravneho remesla,
--     VIDITELNOST a NAKUP rovnakeho remesla pre firmy z celeho Slovenska.
--     Okres je len informativny udaj pred kupou.
--
-- 6. Ochranna blokada: navrh sa NESMIE uspesne dokoncit.
-- Umyselne zastavi transakciu aj ked niekto omylom spusti cely subor.
DO $stop$
BEGIN
 RAISE EXCEPTION 'DopytAI: NEUPLNY NAVRH - ZIADNE PRODUKCNE ZMENY. ROLLBACK.';
END
$stop$;

ROLLBACK;
