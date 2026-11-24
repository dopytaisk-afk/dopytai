-- DopytAI-TEST: databázové rozšírenie ponúk.
-- Tento súbor je návrh migrácie. Jeho uloženie do GitHubu SQL NEVYKONÁ.
BEGIN;

ALTER TABLE public.kalkulacka_ponuky
  ADD COLUMN IF NOT EXISTS dodavatel_nazov text,
  ADD COLUMN IF NOT EXISTS dodavatel_ico text,
  ADD COLUMN IF NOT EXISTS dodavatel_kontakt text;

CREATE OR REPLACE FUNCTION public.kalkulacka_autocislo_v1()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF NEW.cislo_ponuky IS NULL OR btrim(NEW.cislo_ponuky) = '' THEN
    NEW.cislo_ponuky := 'PON-' || to_char(CURRENT_DATE, 'YYYY')
                         || '-' || lpad(NEW.id::text, 6, '0');
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS kalkulacka_autocislo_v1_trg ON public.kalkulacka_ponuky;
CREATE TRIGGER kalkulacka_autocislo_v1_trg
BEFORE INSERT ON public.kalkulacka_ponuky
FOR EACH ROW EXECUTE FUNCTION public.kalkulacka_autocislo_v1();

COMMIT;

SELECT
  (SELECT count(*) FROM information_schema.columns
   WHERE table_schema='public'
     AND table_name='kalkulacka_ponuky'
     AND column_name IN ('dodavatel_nazov','dodavatel_ico','dodavatel_kontakt')) AS nove_stlpce,
  (SELECT count(*) FROM pg_trigger
   WHERE tgrelid='public.kalkulacka_ponuky'::regclass
     AND tgname='kalkulacka_autocislo_v1_trg'
     AND NOT tgisinternal) AS trigger_pocet;