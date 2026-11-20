-- DopytAI / Elektroinštalácie
-- LEN NAVRH: nebolo spustené na Supabase. Vývojová vetva feature/elektroinstalacie.
-- VYŽADUJE predbežný review a zálohu existujúcich definícií z produkcie.
-- Skript vychádza z definícií poskytnutých 2026-11-17; pred použitím znovu
-- porovnajte ich s pg_get_functiondef v správnom projekte. Neaplikovať naslepo.
-- POZOR: API a autentifikačné testy, trigger/RLS a anonymizácia nie sú týmto otestované.
BEGIN;

-- 1/2: Povoliť nový typ práce bez zmeny ostatných kontrol.
CREATE OR REPLACE FUNCTION public.vytvor_dopyt_s_token_v2(
  p_meno text,
  p_telefon text,
  p_email text,
  p_typ_prace text,
  p_lokalita text,
  p_region text,
  p_popis text,
  p_odhad_ceny numeric,
  p_okres text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_vysledok jsonb;
  v_id bigint;
BEGIN
  IF p_typ_prace IS NULL
     OR p_typ_prace NOT IN (
       'Nová strecha',
       'Rekonštrukcia strechy',
       'Oprava / zatekanie',
       'Sadrokartón',
       'Elektroinštalácie'
     )
  THEN
    RAISE EXCEPTION 'Nepovoleny typ prace.';
  END IF;

  IF NULLIF(btrim(p_email), '') IS NULL THEN
    RAISE EXCEPTION 'Email je povinny.';
  END IF;

  IF NULLIF(btrim(p_okres), '') IS NULL THEN
    RAISE EXCEPTION 'Okres je povinny.';
  END IF;

  v_vysledok := public.vytvor_dopyt_s_token(
    p_meno,
    p_telefon,
    p_email,
    p_typ_prace,
    p_lokalita,
    p_region,
    p_popis,
    p_odhad_ceny
  );

  v_id := (v_vysledok->>'id')::bigint;

  UPDATE public.dopyty
  SET okres = btrim(p_okres)
  WHERE id = v_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Okres sa nepodarilo ulozit.';
  END IF;

  RETURN v_vysledok;
END;
$function$;

-- 2/2: Zachovať existujúcu exkluzivitu a zámerne nezobrazovať voľný opis
-- pred kúpou. Elektro pred kúpou dostane len hodnoty z pevného whitelistu.
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
    OR NOT EXISTS (
      SELECT 1
      FROM public.odomknute_dopyty od2
      WHERE od2.dopyt_id = d.id
    )
  )
  AND (
    (
      f.typ_prace = 'Strechy'
      AND d.typ_prace IN (
        'Nová strecha',
        'Rekonštrukcia strechy',
        'Oprava / zatekanie'
      )
    )
    OR (f.typ_prace = 'Sadrokartón' AND d.typ_prace = 'Sadrokartón')
    OR (f.typ_prace = 'Elektroinštalácie' AND d.typ_prace = 'Elektroinštalácie')
  );
$function$;

COMMIT;

-- KONTROLA PO SKÚŠOBNOM NASADENÍ:
-- SELECT pg_get_functiondef('public.vytvor_dopyt_s_token_v2'::regproc);
-- SELECT pg_get_functiondef('public.bezpecne_dopyty'::regproc);
-- Nevykonávať žiadny test na produkcii so skutočnými kontaktmi.
