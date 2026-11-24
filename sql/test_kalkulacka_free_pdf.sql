-- DopytAI kalkulačka: návrh serverového obmedzenia 1 bezplatné PDF na overený e-mail.
-- Nasadiť najprv iba v DopytAI-TEST. Samotné vytvorenie SQL súboru nič nespúšťa.
-- Bezplatné PDF nebude vytvorené v prehliadači: server skontroluje overovací token a kvótu.

BEGIN;

CREATE TABLE IF NOT EXISTS public.kalkulacka_free_challenges (
  id uuid PRIMARY KEY,
  email_hash text NOT NULL,
  ip_hash text,
  token_hash text NOT NULL UNIQUE,
  quote_payload jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  claimed_at timestamptz,
  CONSTRAINT free_challenges_email_sha CHECK (email_hash ~ '^[0-9a-f]{64}$'),
  CONSTRAINT free_challenges_ip_sha CHECK (ip_hash IS NULL OR ip_hash ~ '^[0-9a-f]{64}$'),
  CONSTRAINT free_challenges_token_sha CHECK (token_hash ~ '^[0-9a-f]{64}$'),
  CONSTRAINT free_challenges_expiry CHECK (expires_at > created_at)
);
CREATE INDEX IF NOT EXISTS idx_kalkulacka_free_challenges_email
  ON public.kalkulacka_free_challenges(email_hash);
CREATE INDEX IF NOT EXISTS idx_kalkulacka_free_challenges_ip
  ON public.kalkulacka_free_challenges(ip_hash,created_at);
CREATE INDEX IF NOT EXISTS idx_kalkulacka_free_challenges_expiry
  ON public.kalkulacka_free_challenges(expires_at);

CREATE TABLE IF NOT EXISTS public.kalkulacka_free_used (
  email_hash text PRIMARY KEY,
  challenge_id uuid NOT NULL UNIQUE REFERENCES public.kalkulacka_free_challenges(id),
  claimed_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT free_used_email_sha CHECK (email_hash ~ '^[0-9a-f]{64}$')
);

ALTER TABLE public.kalkulacka_free_challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kalkulacka_free_used ENABLE ROW LEVEL SECURITY;
-- Žiadne verejné politiky: čítanie a zápis len cez server so service-role oprávnením.
REVOKE ALL ON public.kalkulacka_free_challenges FROM anon, authenticated;
REVOKE ALL ON public.kalkulacka_free_used FROM anon, authenticated;

-- Claim je atómový: UNIQUE(email_hash) zaručí najviac jedno úspešné použitie.
-- Funkciu bude volať iba dôveryhodný server; nevystavovať priamo verejnosti.
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
BEGIN
  SELECT * INTO v_ch
  FROM public.kalkulacka_free_challenges
  WHERE id=p_challenge_id
    AND token_hash=p_token_hash
    AND claimed_at IS NULL
    AND expires_at>now()
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  INSERT INTO public.kalkulacka_free_used(email_hash,challenge_id)
  VALUES (v_ch.email_hash,v_ch.id)
  ON CONFLICT (email_hash) DO NOTHING;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  UPDATE public.kalkulacka_free_challenges
  SET claimed_at=now(),quote_payload='{}'::jsonb
  WHERE id=v_ch.id;

  RETURN v_ch.quote_payload;
END;
$$;

REVOKE ALL ON FUNCTION public.kalkulacka_claim_free_pdf(uuid,text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.kalkulacka_claim_free_pdf(uuid,text)
  TO service_role;

COMMIT;
