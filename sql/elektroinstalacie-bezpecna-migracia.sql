-- DopytAI: elektroinstalacie, kontrolovane rozsirenie existujucich SQL funkcii
-- LEN SPUSTIT RUCNE PO SCHVALENI v spravnom Supabase projekte.
-- Prepisuje LEN presne overene fragmenty existujucich funkcii.
-- Ak sa existujuce funkcie od posledneho auditu zmenili, RAISE EXCEPTION
-- zastavi transakciu a neulozi sa ziadna zmena.
BEGIN;

DO $migration$
DECLARE
  v_def text;
  v_old text := E'''Sadrokartón''\n     )';
  v_new text := E'''Sadrokartón'',\n       ''Elektroinštalácie''\n     )';
BEGIN
  SELECT pg_get_functiondef(
    'public.vytvor_dopyt_s_token_v2(text,text,text,text,text,text,text,numeric,text)'::regprocedure
  ) INTO v_def;

  IF position('''Elektroinštalácie''' IN v_def) > 0 THEN
    RAISE EXCEPTION 'vytvor_dopyt_s_token_v2 uz uvadza elektroinstalacie: skontrolovat manualne';
  END IF;

  IF (length(v_def) - length(replace(v_def, v_old, ''))) <> length(v_old) THEN
    RAISE EXCEPTION 'Nepodporovana podoba funkcie vytvor_dopyt_s_token_v2. Bez zmeny.';
  END IF;

  EXECUTE replace(v_def, v_old, v_new);
END;
$migration$;

DO $migration$
DECLARE
  v_def text;
  v_old_branch text := E'    ELSE\n      concat_ws(';
  v_new_branch text := $branch$    WHEN d.typ_prace = 'Elektroinštalácie' THEN
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
        'Odhad: ' || COALESCE(
          (regexp_match(
            replace(replace(d.popis, chr(160), ' '), chr(8239), ' '),
            '(?m)^Odhad: ([0-9 ]+[–-][0-9 ]+ €)$'
          ))[1],
          'Individuálne podľa rozsahu prác'
        )
      )

    ELSE
      concat_ws($branch$;

  v_old_filter text := $filter$    OR
    (
      f.typ_prace = 'Sadrokartón'
      AND d.typ_prace = 'Sadrokartón'
    )$filter$;

  v_new_filter text := $filter$    OR
    (
      f.typ_prace = 'Sadrokartón'
      AND d.typ_prace = 'Sadrokartón'
    )
    OR
    (
      f.typ_prace = 'Elektroinštalácie'
      AND d.typ_prace = 'Elektroinštalácie'
    )$filter$;

BEGIN
  SELECT pg_get_functiondef('public.bezpecne_dopyty()'::regprocedure)
  INTO v_def;

  IF position('Elektroinštalácie' IN v_def) > 0 THEN
    RAISE EXCEPTION 'bezpecne_dopyty uz uvadza elektroinstalacie: skontrolovat manualne';
  END IF;

  IF (length(v_def) - length(replace(v_def, v_old_branch, ''))) <> length(v_old_branch)
     OR (length(v_def) - length(replace(v_def, v_old_filter, ''))) <> length(v_old_filter)
  THEN
    RAISE EXCEPTION 'Nepodporovana podoba bezpecne_dopyty. Zmeny vratene.';
  END IF;

  v_def := replace(v_def, v_old_branch, v_new_branch);
  v_def := replace(v_def, v_old_filter, v_new_filter);
  EXECUTE v_def;
END;
$migration$;

-- Kontroly po modifikácii (rovnaka transakcia; pri chybe ROLLBACK)
DO $checks$
DECLARE
  v_create text := pg_get_functiondef('public.vytvor_dopyt_s_token_v2(text,text,text,text,text,text,text,numeric,text)'::regprocedure);
  v_safe text := pg_get_functiondef('public.bezpecne_dopyty()'::regprocedure);
BEGIN
  IF position('''Elektroinštalácie''' IN v_create) = 0
    OR position('WHEN d.typ_prace = ''Elektroinštalácie'' THEN' IN v_safe) = 0
    OR position('f.typ_prace = ''Elektroinštalácie''' IN v_safe) = 0
    OR position('NOT EXISTS' IN v_safe) = 0
    OR position('od.firma_id IS NOT NULL' IN v_safe) = 0
  THEN
    RAISE EXCEPTION 'Kontrola neprešla. Zmeny vratene.';
  END IF;
END;
$checks$;

COMMIT;
