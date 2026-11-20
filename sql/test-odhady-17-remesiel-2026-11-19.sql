-- DopytAI-TEST ONLY | PR #9. DOPLNENIE BEZPECNEHO ODHADU pre 17 remesiel.
-- NEMENI prihlasovanie, viditelnost, kupu, fotografie ani kontakty.
BEGIN;
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
COMMIT;

-- Kontrola iba definicie, bez citania osobnych udajov.
SELECT
  (length(pg_get_functiondef('public.bezpecne_dopyty()'::regprocedure)) -
   length(replace(pg_get_functiondef('public.bezpecne_dopyty()'::regprocedure),
   'Odhad: ', ''))) / length('Odhad: ') >= 19 AS odhady_pre_remesla_pripravene;
