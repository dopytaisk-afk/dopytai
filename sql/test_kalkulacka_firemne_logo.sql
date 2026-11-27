-- DopytAI TEST only: private company logo for the calculator.
BEGIN;
CREATE TABLE IF NOT EXISTS public.kalkulacka_firemne_logo (
    firma_id bigint PRIMARY KEY REFERENCES public.firmy(id) ON DELETE CASCADE,
    logo_data text NOT NULL CHECK (
        char_length(logo_data) <= 80000
        AND logo_data ~ '^data:image/jpeg;base64,[A-Za-z0-9+/]+={0,2}$'
    ),
    updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.kalkulacka_firemne_logo ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.kalkulacka_firemne_logo FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.kalkulacka_firemne_logo TO service_role;
COMMIT;
