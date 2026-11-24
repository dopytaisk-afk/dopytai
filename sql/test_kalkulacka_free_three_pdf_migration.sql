-- DopytAI-TEST / PR #11: prechod z 1 na 3 bezplatné PDF na overený e-mail.
-- EXISTUJÚCE ZÁZNAMY SA NEMAŽÚ. Spustiť LEN v TEST Supabase.
BEGIN;

-- Predošlá tabuľka mala email_hash ako PRIMARY KEY; jeden e-mail mohol mať len 1 záznam.
-- Prechod na primárny kľúč po challenge_id zachová všetky už využité ponuky.
ALTER TABLE public.kalkulacka_free_used
  DROP CONSTRAINT IF EXISTS kalkulacka_free_used_pkey;

ALTER TABLE public.kalkulacka_free_used
  ADD CONSTRAINT kalkulacka_free_used_pkey PRIMARY KEY (challenge_id);

CREATE INDEX IF NOT EXISTS idx_kalkulacka_free_used_email
  ON public.kalkulacka_free_used (email_hash);

-- Verejné práva sa nemenia. RLS zostáva zapnuté; iba service_role pracuje s evidenciou.
CREATE OR REPLACE FUNCTION public.kalkulacka_claim_free_pdf(
  p_challenge_id uuid,
  p_token_hash text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ch public.kalkulacka_free_challenges%ROWTYPE;
  v_count integer;
BEGIN
  SELECT * INTO v_ch
  FROM public.kalkulacka_free_challenges
  WHERE id = p_challenge_id
    AND token_hash = p_token_hash
    AND claimed_at IS NULL
    AND expires_at > now()
  FOR UPDATE;

  IF NOT FOUND THEN RETURN NULL; END IF;

  -- Jeden zámok na overený e-mail bráni súbežnému vydaniu 4. PDF.
  PERFORM pg_advisory_xact_lock(hashtextextended(v_ch.email_hash, 0));

  SELECT count(*) INTO v_count
  FROM public.kalkulacka_free_used
  WHERE email_hash = v_ch.email_hash;

  IF v_count >= 3 THEN RETURN NULL; END IF;

  INSERT INTO public.kalkulacka_free_used (email_hash,challenge_id)
  VALUES (v_ch.email_hash,v_ch.id);

  UPDATE public.kalkulacka_free_challenges
  SET claimed_at = now(), quote_payload = '{}'::jsonb
  WHERE id = v_ch.id;

  RETURN v_ch.quote_payload;
END;
$$;

REVOKE ALL ON FUNCTION public.kalkulacka_claim_free_pdf(uuid,text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.kalkulacka_claim_free_pdf(uuid,text)
  TO service_role;

COMMIT;

-- Overenie nastavenia bez zmeny dát
SELECT
  (SELECT COUNT(*) FROM public.kalkulacka_free_used) AS doteraz_vyuzite,
  (SELECT COUNT(*) FROM pg_indexes
   WHERE schemaname='public' AND tablename='kalkulacka_free_used'
   AND indexname='idx_kalkulacka_free_used_email') AS index_email,
  (SELECT COUNT(*) FROM pg_proc
   WHERE oid='public.kalkulacka_claim_free_pdf(uuid,text)'::regprocedure) AS funkcia_pocet;