-- DopytAI TEST only. Run phase 1 before testing the new server route.
BEGIN;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.kalkulacka_cennik TO service_role;
GRANT SELECT, INSERT ON public.kalkulacka_ponuky, public.kalkulacka_polozky TO service_role;
DO $$
DECLARE seq text;
BEGIN
 FOR seq IN SELECT pg_get_serial_sequence('public.'||t,'id') FROM unnest(ARRAY['kalkulacka_cennik','kalkulacka_ponuky','kalkulacka_polozky']) t LOOP
  IF seq IS NOT NULL THEN EXECUTE format('GRANT USAGE, SELECT ON SEQUENCE %s TO service_role',seq::regclass); END IF;
 END LOOP;
END $$;
CREATE OR REPLACE FUNCTION public.kalkulacka_pro_save_offer(p_firma bigint,p_offer jsonb,p_lines jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=public AS $$
DECLARE o public.kalkulacka_ponuky%ROWTYPE;
BEGIN
 IF p_firma IS NULL OR jsonb_typeof(p_lines) IS DISTINCT FROM 'array' OR jsonb_array_length(p_lines) NOT BETWEEN 1 AND 500 THEN RAISE EXCEPTION 'Invalid offer'; END IF;
 INSERT INTO public.kalkulacka_ponuky(firma_id,cislo_ponuky,dodavatel_nazov,dodavatel_ico,dodavatel_kontakt,zakaznik,miesto_realizacie,predmet,poznamky,datum_vystavenia,platnost_do,stav,sadzba_dph,zlava_percent)
 SELECT p_firma,NULL,x.dodavatel_nazov,x.dodavatel_ico,x.dodavatel_kontakt,x.zakaznik,x.miesto_realizacie,x.predmet,x.poznamky,x.datum_vystavenia,x.platnost_do,x.stav,x.sadzba_dph,x.zlava_percent
 FROM jsonb_populate_record(NULL::public.kalkulacka_ponuky,p_offer) x RETURNING * INTO o;
 INSERT INTO public.kalkulacka_polozky(ponuka_id,typ,nazov,mnozstvo,jednotka,jednotkova_cena,poradie)
 SELECT o.id,x.typ,x.nazov,x.mnozstvo,x.jednotka,x.jednotkova_cena,x.poradie
 FROM jsonb_populate_recordset(NULL::public.kalkulacka_polozky,p_lines) x;
 RETURN jsonb_build_array(jsonb_build_object('id',o.id,'cislo_ponuky',o.cislo_ponuky));
END $$;
REVOKE ALL ON FUNCTION public.kalkulacka_pro_save_offer(bigint,jsonb,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.kalkulacka_pro_save_offer(bigint,jsonb,jsonb) TO service_role;
COMMIT;
