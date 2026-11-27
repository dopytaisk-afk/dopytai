-- PR #11: DopytAI-TEST ONLY. No changes to credit or existing calculator tables.
BEGIN;
CREATE TABLE IF NOT EXISTS public.kalkulacka_pro_customers (
  auth_user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE RESTRICT,
  firma_id bigint NOT NULL UNIQUE,
  stripe_customer_id text NOT NULL UNIQUE CHECK (stripe_customer_id ~ '^cus_[A-Za-z0-9]+$'),
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.kalkulacka_pro_customers ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.kalkulacka_pro_customers FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT ON public.kalkulacka_pro_customers TO service_role;

CREATE TABLE IF NOT EXISTS public.kalkulacka_pro_checkout (
  auth_user_id uuid PRIMARY KEY REFERENCES public.kalkulacka_pro_customers(auth_user_id) ON DELETE RESTRICT,
  attempt_id uuid NOT NULL DEFAULT gen_random_uuid(),
  plan text NOT NULL CHECK (plan IN ('monthly','yearly')),
  expires_at timestamptz NOT NULL
);
ALTER TABLE public.kalkulacka_pro_checkout ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.kalkulacka_pro_checkout FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON public.kalkulacka_pro_checkout TO service_role;
CREATE OR REPLACE FUNCTION public.kalkulacka_pro_reserve_checkout(p_user uuid,p_plan text)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=public AS $$
DECLARE a public.kalkulacka_pro_checkout%ROWTYPE;
BEGIN
  IF p_plan NOT IN ('monthly','yearly') OR p_plan IS NULL THEN RAISE EXCEPTION 'Invalid plan'; END IF;
  INSERT INTO public.kalkulacka_pro_checkout(auth_user_id,plan,expires_at)
    VALUES(p_user,p_plan,date_trunc('second',now())+interval '1 hour')
  ON CONFLICT(auth_user_id) DO UPDATE
    SET attempt_id=gen_random_uuid(),plan=EXCLUDED.plan,expires_at=EXCLUDED.expires_at
    WHERE kalkulacka_pro_checkout.expires_at < now()-interval '2 minutes';
  SELECT * INTO STRICT a FROM public.kalkulacka_pro_checkout WHERE auth_user_id=p_user;
  RETURN to_jsonb(a);
END;
$$;
REVOKE ALL ON FUNCTION public.kalkulacka_pro_reserve_checkout(uuid,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.kalkulacka_pro_reserve_checkout(uuid,text) TO service_role;
COMMIT;
