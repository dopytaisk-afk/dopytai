BEGIN;
CREATE TABLE IF NOT EXISTS public.kalkulacka_firemne_logo (
 firma_id bigint PRIMARY KEY REFERENCES public.firmy(id) ON DELETE CASCADE,
 logo_data text NOT NULL CHECK (length(logo_data) <= 80000 AND logo_data LIKE 'data:image/jpeg;base64,%'),
 updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.kalkulacka_firemne_logo ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.kalkulacka_firemne_logo FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.kalkulacka_firemne_logo TO service_role;
COMMIT;
