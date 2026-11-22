-- DopytAI-TEST / PR #9: doplnit bezpecny termin do 16 generickych remesiel.
-- NEAPLIKOVAT na produkciu. Zadne sukromne udaje ani volny popis pred kupou.
-- Predpoklad: uz aplikovana sql/test-oprava-detailov-17-remesiel-2026-11-19.sql.
-- Bezpecne sa ukonci bez zmeny, ak aktualna funkcia nie je ocakavana.
BEGIN;
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
COMMIT;

-- Read-only overenie, bez mena/emailu/telefonu:
SELECT position('Termín: ' IN pg_get_functiondef('public.bezpecne_dopyty()'::regprocedure)) > 0 AS termin_pridany;
