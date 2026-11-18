-- DopytAI: nezavazny navrh bezpecne_dopyty pre 19 remesiel.
-- KONTROLNY DOKUMENT - NESPÚŠŤAŤ: vyzaduje helper dopytai_typ_firmy.
-- Volny opis pred kupou je skryty. Typ prace sa vracia len z whitelistu.
-- Kraj len pre emailove upozornenia; dopyt vidi firma spravneho remesla kdekoľvek.
-- Pred vykonanim preverit foto pristup, SETOF poradie a SQL na izolovanej DB.
BEGIN;
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
            SELECT (regexp_match(d.popis, '(?m)^Druh práce: ([^\r\n]{1,100})
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
$function$;))[1] AS praca
          ) t WHERE t.praca IN ('Nové rozvody vody a odpadu', 'Oprava úniku vody', 'Montáž sanity', 'Iné vodoinštalačné práce')),
          'neuvedený'
        ),
        'Rozsah: ' || COALESCE(
          (regexp_match(d.popis, '(?m)^Rozsah: ([0-9]{1,5}(?:[.,][0-9])? (?:m²|m³|bm|ks))
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
$function$;))[1],
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
            SELECT (regexp_match(d.popis, '(?m)^Druh práce: ([^\r\n]{1,100})
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
$function$;))[1] AS praca
          ) t WHERE t.praca IN ('Podlahové kúrenie', 'Radiátory a rozvody', 'Výmena zdroja vykurovania', 'Oprava kúrenia')),
          'neuvedený'
        ),
        'Rozsah: ' || COALESCE(
          (regexp_match(d.popis, '(?m)^Rozsah: ([0-9]{1,5}(?:[.,][0-9])? (?:m²|m³|bm|ks))
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
$function$;))[1],
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
            SELECT (regexp_match(d.popis, '(?m)^Druh práce: ([^\r\n]{1,100})
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
$function$;))[1] AS praca
          ) t WHERE t.praca IN ('Montáž klimatizácie', 'Servis a čistenie', 'Oprava klimatizácie', 'Multi-split systém')),
          'neuvedený'
        ),
        'Rozsah: ' || COALESCE(
          (regexp_match(d.popis, '(?m)^Rozsah: ([0-9]{1,5}(?:[.,][0-9])? (?:m²|m³|bm|ks))
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
$function$;))[1],
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
            SELECT (regexp_match(d.popis, '(?m)^Druh práce: ([^\r\n]{1,100})
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
$function$;))[1] AS praca
          ) t WHERE t.praca IN ('Nové murivo', 'Vnútorné priečky', 'Omietky', 'Stavebné úpravy')),
          'neuvedený'
        ),
        'Rozsah: ' || COALESCE(
          (regexp_match(d.popis, '(?m)^Rozsah: ([0-9]{1,5}(?:[.,][0-9])? (?:m²|m³|bm|ks))
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
$function$;))[1],
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
            SELECT (regexp_match(d.popis, '(?m)^Druh práce: ([^\r\n]{1,100})
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
$function$;))[1] AS praca
          ) t WHERE t.praca IN ('Zateplenie fasády', 'Nová fasádna omietka', 'Oprava fasády', 'Iné fasádne práce')),
          'neuvedený'
        ),
        'Rozsah: ' || COALESCE(
          (regexp_match(d.popis, '(?m)^Rozsah: ([0-9]{1,5}(?:[.,][0-9])? (?:m²|m³|bm|ks))
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
$function$;))[1],
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
            SELECT (regexp_match(d.popis, '(?m)^Druh práce: ([^\r\n]{1,100})
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
$function$;))[1] AS praca
          ) t WHERE t.praca IN ('Maľovanie interiéru', 'Maľovanie exteriéru', 'Stierkovanie', 'Tapetovanie')),
          'neuvedený'
        ),
        'Rozsah: ' || COALESCE(
          (regexp_match(d.popis, '(?m)^Rozsah: ([0-9]{1,5}(?:[.,][0-9])? (?:m²|m³|bm|ks))
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
$function$;))[1],
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
            SELECT (regexp_match(d.popis, '(?m)^Druh práce: ([^\r\n]{1,100})
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
$function$;))[1] AS praca
          ) t WHERE t.praca IN ('Obklad kúpeľne', 'Pokládka interiérovej dlažby', 'Pokládka terasovej dlažby', 'Oprava obkladov')),
          'neuvedený'
        ),
        'Rozsah: ' || COALESCE(
          (regexp_match(d.popis, '(?m)^Rozsah: ([0-9]{1,5}(?:[.,][0-9])? (?:m²|m³|bm|ks))
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
$function$;))[1],
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
            SELECT (regexp_match(d.popis, '(?m)^Druh práce: ([^\r\n]{1,100})
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
$function$;))[1] AS praca
          ) t WHERE t.praca IN ('Vinylová podlaha', 'Laminátová podlaha', 'Drevená podlaha', 'Príprava a nivelizácia')),
          'neuvedený'
        ),
        'Rozsah: ' || COALESCE(
          (regexp_match(d.popis, '(?m)^Rozsah: ([0-9]{1,5}(?:[.,][0-9])? (?:m²|m³|bm|ks))
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
$function$;))[1],
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
            SELECT (regexp_match(d.popis, '(?m)^Druh práce: ([^\r\n]{1,100})
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
$function$;))[1] AS praca
          ) t WHERE t.praca IN ('Plastové okná', 'Drevené okná', 'Vchodové dvere', 'Interiérové dvere')),
          'neuvedený'
        ),
        'Rozsah: ' || COALESCE(
          (regexp_match(d.popis, '(?m)^Rozsah: ([0-9]{1,5}(?:[.,][0-9])? (?:m²|m³|bm|ks))
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
$function$;))[1],
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
            SELECT (regexp_match(d.popis, '(?m)^Druh práce: ([^\r\n]{1,100})
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
$function$;))[1] AS praca
          ) t WHERE t.praca IN ('Krov strechy', 'Drevený prístrešok', 'Terasa z dreva', 'Iné tesárske práce')),
          'neuvedený'
        ),
        'Rozsah: ' || COALESCE(
          (regexp_match(d.popis, '(?m)^Rozsah: ([0-9]{1,5}(?:[.,][0-9])? (?:m²|m³|bm|ks))
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
$function$;))[1],
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
            SELECT (regexp_match(d.popis, '(?m)^Druh práce: ([^\r\n]{1,100})
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
$function$;))[1] AS praca
          ) t WHERE t.praca IN ('Izolácia základov', 'Izolácia terasy', 'Plochá strecha', 'Sanácia vlhkosti')),
          'neuvedený'
        ),
        'Rozsah: ' || COALESCE(
          (regexp_match(d.popis, '(?m)^Rozsah: ([0-9]{1,5}(?:[.,][0-9])? (?:m²|m³|bm|ks))
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
$function$;))[1],
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
            SELECT (regexp_match(d.popis, '(?m)^Druh práce: ([^\r\n]{1,100})
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
$function$;))[1] AS praca
          ) t WHERE t.praca IN ('Chodníky', 'Príjazdová cesta', 'Terasa a dvor', 'Oprava dlažby')),
          'neuvedený'
        ),
        'Rozsah: ' || COALESCE(
          (regexp_match(d.popis, '(?m)^Rozsah: ([0-9]{1,5}(?:[.,][0-9])? (?:m²|m³|bm|ks))
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
$function$;))[1],
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
            SELECT (regexp_match(d.popis, '(?m)^Druh práce: ([^\r\n]{1,100})
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
$function$;))[1] AS praca
          ) t WHERE t.praca IN ('Nový plot', 'Posuvná brána', 'Krídlová brána', 'Oprava oplotenia')),
          'neuvedený'
        ),
        'Rozsah: ' || COALESCE(
          (regexp_match(d.popis, '(?m)^Rozsah: ([0-9]{1,5}(?:[.,][0-9])? (?:m²|m³|bm|ks))
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
$function$;))[1],
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
            SELECT (regexp_match(d.popis, '(?m)^Druh práce: ([^\r\n]{1,100})
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
$function$;))[1] AS praca
          ) t WHERE t.praca IN ('Výkop základov', 'Prípojky a ryhy', 'Úprava terénu', 'Búranie a odvoz')),
          'neuvedený'
        ),
        'Rozsah: ' || COALESCE(
          (regexp_match(d.popis, '(?m)^Rozsah: ([0-9]{1,5}(?:[.,][0-9])? (?:m²|m³|bm|ks))
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
$function$;))[1],
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
            SELECT (regexp_match(d.popis, '(?m)^Druh práce: ([^\r\n]{1,100})
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
$function$;))[1] AS praca
          ) t WHERE t.praca IN ('Kompletná rekonštrukcia', 'Výmena vane alebo sprchy', 'Čiastočná rekonštrukcia', 'Samostatné WC')),
          'neuvedený'
        ),
        'Rozsah: ' || COALESCE(
          (regexp_match(d.popis, '(?m)^Rozsah: ([0-9]{1,5}(?:[.,][0-9])? (?:m²|m³|bm|ks))
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
$function$;))[1],
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
            SELECT (regexp_match(d.popis, '(?m)^Druh práce: ([^\r\n]{1,100})
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
$function$;))[1] AS praca
          ) t WHERE t.praca IN ('Základová doska', 'Betónový poter', 'Schodisko', 'Iné betónové práce')),
          'neuvedený'
        ),
        'Rozsah: ' || COALESCE(
          (regexp_match(d.popis, '(?m)^Rozsah: ([0-9]{1,5}(?:[.,][0-9])? (?:m²|m³|bm|ks))
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
$function$;))[1],
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
    OR NOT EXISTS (
      SELECT 1
      FROM public.odomknute_dopyty od2
      WHERE od2.dopyt_id = d.id
    )
  )
  AND public.dopytai_typ_firmy(d.typ_prace) = f.typ_prace;
$function$;
DO $stop$ BEGIN
 RAISE EXCEPTION 'NAVRH bezpecne_dopyty: NEAPLIKOVAT! ROLLBACK';
END $stop$;
ROLLBACK;
