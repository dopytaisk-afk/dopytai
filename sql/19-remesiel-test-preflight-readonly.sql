-- DopytAI / kontrola pripravenosti testovacej schemy na migraciu 19 remesiel
-- Len SELECT: nic neprepisuje, nespusta emaily, nevytvara dopyty.
-- Spustit v SQL Editore TEST projektu najprv.
-- V produkcii povolene LEN ako read-only audit; migraciu v produkcii nespustat.

WITH expected AS (
 SELECT *
 FROM (VALUES
  ('vytvor_dopyt_s_token_v2', 'public.vytvor_dopyt_s_token_v2(text,text,text,text,text,text,text,numeric,text)', '566a8d4ff9e9e27ab7aa6e3cc62fd0e1'),
  ('bezpecne_dopyty', 'public.bezpecne_dopyty()', 'd45f9ecf839e7e955ada8282f21f7ca8'),
  ('kup_dopyt', 'public.kup_dopyt(bigint,bigint,numeric)', 'a5016e77c74e5552a59f42aa5b6ca78c')
 ) AS t(nazov, podpis, ocakavany_md5)
),
functions AS (
 SELECT
  e.nazov,
  e.podpis,
  e.ocakavany_md5,
  to_regprocedure(e.podpis) AS oid
 FROM expected e
),
basic AS (
 SELECT '01_FUNKCIA' AS oblast, f.nazov AS kontrola,
  CASE WHEN oid IS NULL THEN 'CHYBA: neexistuje'
       WHEN md5(pg_get_functiondef(oid)) = f.ocakavany_md5 THEN 'OK'
       ELSE 'NEZHODA DEFINICIE'
  END AS stav,
  COALESCE(md5(pg_get_functiondef(oid)), 'nenajdena') AS detail
 FROM functions f

 UNION ALL SELECT '02_TABULKA', t, 
 CASE WHEN to_regclass('public.'||t) IS NOT NULL THEN 'OK' ELSE 'CHYBA' END,
 COALESCE(to_regclass('public.'||t)::text, 'nenajdena')
 FROM (VALUES ('dopyty'), ('firmy'), ('odomknute_dopyty')) AS a(t)

 UNION ALL SELECT '03_PRIVATNA_TABULKA', 'private.dopyt_upload_auth',
 CASE WHEN to_regclass('private.dopyt_upload_auth') IS NOT NULL THEN 'OK' ELSE 'CHYBA' END,
 COALESCE(to_regclass('private.dopyt_upload_auth')::text, 'nenajdena')

 UNION ALL SELECT '04_RLS', c.relname,
 CASE WHEN c.relrowsecurity THEN 'OK' ELSE 'CHYBA: RLS vypnute' END,
 'force='||c.relforcerowsecurity::text
 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname='public'
   AND c.relname IN ('dopyty','firmy','odomknute_dopyty')

 UNION ALL SELECT '05_DUPLICITY', 'odomknute_dopyty',
 CASE WHEN count(*)=0 THEN 'OK' ELSE 'CHYBA: DUPLICITY' END,
 count(*)::text
 FROM (
   SELECT dopyt_id FROM public.odomknute_dopyty
   WHERE dopyt_id IS NOT NULL GROUP BY dopyt_id HAVING count(*)>1
 ) x
)
SELECT * FROM basic ORDER BY oblast,kontrola;
