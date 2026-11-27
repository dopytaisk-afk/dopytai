-- TEST ONLY. Run only after PRO server path passes tests.
BEGIN;
REVOKE ALL ON public.kalkulacka_cennik, public.kalkulacka_ponuky, public.kalkulacka_polozky FROM PUBLIC, anon, authenticated;
COMMIT;
