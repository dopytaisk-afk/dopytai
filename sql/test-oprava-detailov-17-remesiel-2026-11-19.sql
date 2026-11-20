-- DopytAI-TEST ONLY. PR #9 / feature/elektroinstalacie.
-- Oprava BEZPECNEHO textu technickych detailov 17 remesiel pred kupou.
-- Nezasahuje do starych vetiev Strechy/Sadrokarton, auth, exkluzivity ani fotografii.
-- Presne ocakava aktualnu SQL definiciu z auditu 19.11.2026; inak zlyha a ziadna zmena sa neulozi.
BEGIN;
DO $dopytai_patch$
DECLARE
  v_def text;
  v_old text := $old_trade_branch$
    WHEN d.typ_prace IN (
      'Elektroinštalácie',
      'Vodoinštalácie',
      'Kúrenie',
      'Klimatizácie',
      'Murárske práce',
      'Fasády a zateplenie',
      'Maliarske práce',
      'Obklady a dlažby',
      'Podlahy',
      'Okná a dvere',
      'Tesárske práce',
      'Hydroizolácie',
      'Zámková dlažba',
      'Ploty a brány',
      'Zemné práce',
      'Rekonštrukcie kúpeľní',
      'Betonárske práce'
    )
    THEN concat_ws(
      E'\n',
      'Remeslo: ' || d.typ_prace,
      'Kraj: ' || COALESCE(
        d.region, 'neuvedený'
      ),
      'Okres: ' || COALESCE(
        d.okres, 'neuvedený'
      )
    )
$old_trade_branch$;
  v_new text := $new_trade_branches$
    WHEN d.typ_prace = 'Elektroinštalácie' THEN
      concat_ws(
        E'\n',
        'Typ elektroinštalácie: ' || COALESCE(
          (regexp_match(
            d.popis,
            '(?m)^Typ elektroinštalácie: (Kompletná elektroinštalácia|Čiastočná elektroinštalácia|Oprava alebo porucha|Elektroinštalačná revízia)$'
          ))[1], 'neuvedený'
        ),
        'Objekt: ' || COALESCE(
          (regexp_match(d.popis, '(?m)^Objekt: (Rodinný dom|Byt|Iný objekt)$'))[1],
          'neuvedený'
        ),
        'Plocha objektu: ' || COALESCE(
          (regexp_match(d.popis, '(?m)^Plocha objektu: ([0-9]{1,5} m²)$'))[1],
          'neuvedená'
        ),
        'Kraj: ' || COALESCE(
          (regexp_match(
            d.popis,
            '(?m)^Kraj: (Bratislavský kraj|Trnavský kraj|Trenčiansky kraj|Nitriansky kraj|Žilinský kraj|Banskobystrický kraj|Prešovský kraj|Košický kraj)$'
          ))[1], 'neuvedený'
        ),
        'Termín: ' || COALESCE(
          (regexp_match(
            d.popis,
            '(?m)^Termín: (Čo najskôr|Do 1–3 mesiacov|Do 3–6 mesiacov|Len zisťujem cenu)$'
          ))[1], 'neuvedený'
        ),
        'Odhad: Individuálne podľa rozsahu prác'
      )

    WHEN d.typ_prace = 'Vodoinštalácie' THEN
      concat_ws(
        E'\n',
        'Druh práce: ' || COALESCE(
          (SELECT t.praca FROM (
            SELECT (regexp_match(d.popis, '(?m)^Druh práce: ([^\r\n]{1,100})$'))[1] AS praca
          ) t WHERE t.praca IN ('Nové rozvody vody a odpadu', 'Oprava úniku vody', 'Montáž sanity', 'Iné vodoinštalačné práce')),
          'neuvedený'
        ),
        'Rozsah: ' || COALESCE(
          (regexp_match(d.popis, '(?m)^Rozsah: ([0-9]{1,5}(?:[.,][0-9])? (?:m²|m³|bm|ks))$'))[1],
          'neuvedený'
        ),
        'Kraj: ' || COALESCE(d.region, 'neuvedený'),
        'Okres: ' || COALESCE(d.okres, 'neuvedený')
      )
    WHEN d.typ_prace = 'Kúrenie' THEN
      concat_ws(
        E'\n',
        'Druh práce: ' || COALESCE(
          (SELECT t.praca FROM (
            SELECT (regexp_match(d.popis, '(?m)^Druh práce: ([^\r\n]{1,100})$'))[1] AS praca
          ) t WHERE t.praca IN ('Podlahové kúrenie', 'Radiátory a rozvody', 'Výmena zdroja vykurovania', 'Oprava kúrenia')),
          'neuvedený'
        ),
        'Rozsah: ' || COALESCE(
          (regexp_match(d.popis, '(?m)^Rozsah: ([0-9]{1,5}(?:[.,][0-9])? (?:m²|m³|bm|ks))$'))[1],
          'neuvedený'
        ),
        'Kraj: ' || COALESCE(d.region, 'neuvedený'),
        'Okres: ' || COALESCE(d.okres, 'neuvedený')
      )
    WHEN d.typ_prace = 'Klimatizácie' THEN
      concat_ws(
        E'\n',
        'Druh práce: ' || COALESCE(
          (SELECT t.praca FROM (
            SELECT (regexp_match(d.popis, '(?m)^Druh práce: ([^\r\n]{1,100})$'))[1] AS praca
          ) t WHERE t.praca IN ('Montáž klimatizácie', 'Servis a čistenie', 'Oprava klimatizácie', 'Multi-split systém')),
          'neuvedený'
        ),
        'Rozsah: ' || COALESCE(
          (regexp_match(d.popis, '(?m)^Rozsah: ([0-9]{1,5}(?:[.,][0-9])? (?:m²|m³|bm|ks))$'))[1],
          'neuvedený'
        ),
        'Kraj: ' || COALESCE(d.region, 'neuvedený'),
        'Okres: ' || COALESCE(d.okres, 'neuvedený')
      )
    WHEN d.typ_prace = 'Murárske práce' THEN
      concat_ws(
        E'\n',
        'Druh práce: ' || COALESCE(
          (SELECT t.praca FROM (
            SELECT (regexp_match(d.popis, '(?m)^Druh práce: ([^\r\n]{1,100})$'))[1] AS praca
          ) t WHERE t.praca IN ('Nové murivo', 'Vnútorné priečky', 'Omietky', 'Stavebné úpravy')),
          'neuvedený'
        ),
        'Rozsah: ' || COALESCE(
          (regexp_match(d.popis, '(?m)^Rozsah: ([0-9]{1,5}(?:[.,][0-9])? (?:m²|m³|bm|ks))$'))[1],
          'neuvedený'
        ),
        'Kraj: ' || COALESCE(d.region, 'neuvedený'),
        'Okres: ' || COALESCE(d.okres, 'neuvedený')
      )
    WHEN d.typ_prace = 'Fasády a zateplenie' THEN
      concat_ws(
        E'\n',
        'Druh práce: ' || COALESCE(
          (SELECT t.praca FROM (
            SELECT (regexp_match(d.popis, '(?m)^Druh práce: ([^\r\n]{1,100})$'))[1] AS praca
          ) t WHERE t.praca IN ('Zateplenie fasády', 'Nová fasádna omietka', 'Oprava fasády', 'Iné fasádne práce')),
          'neuvedený'
        ),
        'Rozsah: ' || COALESCE(
          (regexp_match(d.popis, '(?m)^Rozsah: ([0-9]{1,5}(?:[.,][0-9])? (?:m²|m³|bm|ks))$'))[1],
          'neuvedený'
        ),
        'Kraj: ' || COALESCE(d.region, 'neuvedený'),
        'Okres: ' || COALESCE(d.okres, 'neuvedený')
      )
    WHEN d.typ_prace = 'Maliarske práce' THEN
      concat_ws(
        E'\n',
        'Druh práce: ' || COALESCE(
          (SELECT t.praca FROM (
            SELECT (regexp_match(d.popis, '(?m)^Druh práce: ([^\r\n]{1,100})$'))[1] AS praca
          ) t WHERE t.praca IN ('Maľovanie interiéru', 'Maľovanie exteriéru', 'Stierkovanie', 'Tapetovanie')),
          'neuvedený'
        ),
        'Rozsah: ' || COALESCE(
          (regexp_match(d.popis, '(?m)^Rozsah: ([0-9]{1,5}(?:[.,][0-9])? (?:m²|m³|bm|ks))$'))[1],
          'neuvedený'
        ),
        'Kraj: ' || COALESCE(d.region, 'neuvedený'),
        'Okres: ' || COALESCE(d.okres, 'neuvedený')
      )
    WHEN d.typ_prace = 'Obklady a dlažby' THEN
      concat_ws(
        E'\n',
        'Druh práce: ' || COALESCE(
          (SELECT t.praca FROM (
            SELECT (regexp_match(d.popis, '(?m)^Druh práce: ([^\r\n]{1,100})$'))[1] AS praca
          ) t WHERE t.praca IN ('Obklad kúpeľne', 'Pokládka interiérovej dlažby', 'Pokládka terasovej dlažby', 'Oprava obkladov')),
          'neuvedený'
        ),
        'Rozsah: ' || COALESCE(
          (regexp_match(d.popis, '(?m)^Rozsah: ([0-9]{1,5}(?:[.,][0-9])? (?:m²|m³|bm|ks))$'))[1],
          'neuvedený'
        ),
        'Kraj: ' || COALESCE(d.region, 'neuvedený'),
        'Okres: ' || COALESCE(d.okres, 'neuvedený')
      )
    WHEN d.typ_prace = 'Podlahy' THEN
      concat_ws(
        E'\n',
        'Druh práce: ' || COALESCE(
          (SELECT t.praca FROM (
            SELECT (regexp_match(d.popis, '(?m)^Druh práce: ([^\r\n]{1,100})$'))[1] AS praca
          ) t WHERE t.praca IN ('Vinylová podlaha', 'Laminátová podlaha', 'Drevená podlaha', 'Príprava a nivelizácia')),
          'neuvedený'
        ),
        'Rozsah: ' || COALESCE(
          (regexp_match(d.popis, '(?m)^Rozsah: ([0-9]{1,5}(?:[.,][0-9])? (?:m²|m³|bm|ks))$'))[1],
          'neuvedený'
        ),
        'Kraj: ' || COALESCE(d.region, 'neuvedený'),
        'Okres: ' || COALESCE(d.okres, 'neuvedený')
      )
    WHEN d.typ_prace = 'Okná a dvere' THEN
      concat_ws(
        E'\n',
        'Druh práce: ' || COALESCE(
          (SELECT t.praca FROM (
            SELECT (regexp_match(d.popis, '(?m)^Druh práce: ([^\r\n]{1,100})$'))[1] AS praca
          ) t WHERE t.praca IN ('Plastové okná', 'Drevené okná', 'Vchodové dvere', 'Interiérové dvere')),
          'neuvedený'
        ),
        'Rozsah: ' || COALESCE(
          (regexp_match(d.popis, '(?m)^Rozsah: ([0-9]{1,5}(?:[.,][0-9])? (?:m²|m³|bm|ks))$'))[1],
          'neuvedený'
        ),
        'Kraj: ' || COALESCE(d.region, 'neuvedený'),
        'Okres: ' || COALESCE(d.okres, 'neuvedený')
      )
    WHEN d.typ_prace = 'Tesárske práce' THEN
      concat_ws(
        E'\n',
        'Druh práce: ' || COALESCE(
          (SELECT t.praca FROM (
            SELECT (regexp_match(d.popis, '(?m)^Druh práce: ([^\r\n]{1,100})$'))[1] AS praca
          ) t WHERE t.praca IN ('Krov strechy', 'Drevený prístrešok', 'Terasa z dreva', 'Iné tesárske práce')),
          'neuvedený'
        ),
        'Rozsah: ' || COALESCE(
          (regexp_match(d.popis, '(?m)^Rozsah: ([0-9]{1,5}(?:[.,][0-9])? (?:m²|m³|bm|ks))$'))[1],
          'neuvedený'
        ),
        'Kraj: ' || COALESCE(d.region, 'neuvedený'),
        'Okres: ' || COALESCE(d.okres, 'neuvedený')
      )
    WHEN d.typ_prace = 'Hydroizolácie' THEN
      concat_ws(
        E'\n',
        'Druh práce: ' || COALESCE(
          (SELECT t.praca FROM (
            SELECT (regexp_match(d.popis, '(?m)^Druh práce: ([^\r\n]{1,100})$'))[1] AS praca
          ) t WHERE t.praca IN ('Izolácia základov', 'Izolácia terasy', 'Plochá strecha', 'Sanácia vlhkosti')),
          'neuvedený'
        ),
        'Rozsah: ' || COALESCE(
          (regexp_match(d.popis, '(?m)^Rozsah: ([0-9]{1,5}(?:[.,][0-9])? (?:m²|m³|bm|ks))$'))[1],
          'neuvedený'
        ),
        'Kraj: ' || COALESCE(d.region, 'neuvedený'),
        'Okres: ' || COALESCE(d.okres, 'neuvedený')
      )
    WHEN d.typ_prace = 'Zámková dlažba' THEN
      concat_ws(
        E'\n',
        'Druh práce: ' || COALESCE(
          (SELECT t.praca FROM (
            SELECT (regexp_match(d.popis, '(?m)^Druh práce: ([^\r\n]{1,100})$'))[1] AS praca
          ) t WHERE t.praca IN ('Chodníky', 'Príjazdová cesta', 'Terasa a dvor', 'Oprava dlažby')),
          'neuvedený'
        ),
        'Rozsah: ' || COALESCE(
          (regexp_match(d.popis, '(?m)^Rozsah: ([0-9]{1,5}(?:[.,][0-9])? (?:m²|m³|bm|ks))$'))[1],
          'neuvedený'
        ),
        'Kraj: ' || COALESCE(d.region, 'neuvedený'),
        'Okres: ' || COALESCE(d.okres, 'neuvedený')
      )
    WHEN d.typ_prace = 'Ploty a brány' THEN
      concat_ws(
        E'\n',
        'Druh práce: ' || COALESCE(
          (SELECT t.praca FROM (
            SELECT (regexp_match(d.popis, '(?m)^Druh práce: ([^\r\n]{1,100})$'))[1] AS praca
          ) t WHERE t.praca IN ('Nový plot', 'Posuvná brána', 'Krídlová brána', 'Oprava oplotenia')),
          'neuvedený'
        ),
        'Rozsah: ' || COALESCE(
          (regexp_match(d.popis, '(?m)^Rozsah: ([0-9]{1,5}(?:[.,][0-9])? (?:m²|m³|bm|ks))$'))[1],
          'neuvedený'
        ),
        'Kraj: ' || COALESCE(d.region, 'neuvedený'),
        'Okres: ' || COALESCE(d.okres, 'neuvedený')
      )
    WHEN d.typ_prace = 'Zemné práce' THEN
      concat_ws(
        E'\n',
        'Druh práce: ' || COALESCE(
          (SELECT t.praca FROM (
            SELECT (regexp_match(d.popis, '(?m)^Druh práce: ([^\r\n]{1,100})$'))[1] AS praca
          ) t WHERE t.praca IN ('Výkop základov', 'Prípojky a ryhy', 'Úprava terénu', 'Búranie a odvoz')),
          'neuvedený'
        ),
        'Rozsah: ' || COALESCE(
          (regexp_match(d.popis, '(?m)^Rozsah: ([0-9]{1,5}(?:[.,][0-9])? (?:m²|m³|bm|ks))$'))[1],
          'neuvedený'
        ),
        'Kraj: ' || COALESCE(d.region, 'neuvedený'),
        'Okres: ' || COALESCE(d.okres, 'neuvedený')
      )
    WHEN d.typ_prace = 'Rekonštrukcie kúpeľní' THEN
      concat_ws(
        E'\n',
        'Druh práce: ' || COALESCE(
          (SELECT t.praca FROM (
            SELECT (regexp_match(d.popis, '(?m)^Druh práce: ([^\r\n]{1,100})$'))[1] AS praca
          ) t WHERE t.praca IN ('Kompletná rekonštrukcia', 'Výmena vane alebo sprchy', 'Čiastočná rekonštrukcia', 'Samostatné WC')),
          'neuvedený'
        ),
        'Rozsah: ' || COALESCE(
          (regexp_match(d.popis, '(?m)^Rozsah: ([0-9]{1,5}(?:[.,][0-9])? (?:m²|m³|bm|ks))$'))[1],
          'neuvedený'
        ),
        'Kraj: ' || COALESCE(d.region, 'neuvedený'),
        'Okres: ' || COALESCE(d.okres, 'neuvedený')
      )
    WHEN d.typ_prace = 'Betonárske práce' THEN
      concat_ws(
        E'\n',
        'Druh práce: ' || COALESCE(
          (SELECT t.praca FROM (
            SELECT (regexp_match(d.popis, '(?m)^Druh práce: ([^\r\n]{1,100})$'))[1] AS praca
          ) t WHERE t.praca IN ('Základová doska', 'Betónový poter', 'Schodisko', 'Iné betónové práce')),
          'neuvedený'
        ),
        'Rozsah: ' || COALESCE(
          (regexp_match(d.popis, '(?m)^Rozsah: ([0-9]{1,5}(?:[.,][0-9])? (?:m²|m³|bm|ks))$'))[1],
          'neuvedený'
        ),
        'Kraj: ' || COALESCE(d.region, 'neuvedený'),
        'Okres: ' || COALESCE(d.okres, 'neuvedený')
      )
$new_trade_branches$;
  v_newdef text;
BEGIN
  SELECT pg_get_functiondef('public.bezpecne_dopyty()'::regprocedure) INTO v_def;

  IF v_def IS NULL
     OR position(v_old IN v_def) = 0
     OR length(v_def) - length(replace(v_def, v_old, '')) <> length(v_old)
     OR position('WHEN od.firma_id IS NOT NULL' IN v_def) = 0
     OR position('AND public.dopytai_typ_firmy(d.typ_prace) = f.typ_prace' IN v_def) = 0
     OR position('NOT EXISTS (' IN v_def) = 0
     OR position('SECURITY DEFINER' IN v_def) = 0
  THEN
    RAISE EXCEPTION 'STOP: TEST bezpecne_dopyty sa nezhoduje s auditom. ZIADNA ZMENA.';
  END IF;

  v_newdef := replace(v_def, v_old, v_new);
  EXECUTE v_newdef;

  IF position('WHEN d.typ_prace = ''Elektroinštalácie'' THEN' IN
      pg_get_functiondef('public.bezpecne_dopyty()'::regprocedure)) = 0
  THEN
    RAISE EXCEPTION 'STOP: Oprava sa neoverila, transakcia sa vrati.';
  END IF;
END
$dopytai_patch$;
COMMIT;

-- Overenie po nasadeni (iba citanie):
SELECT
  position('WHEN d.typ_prace = ''Elektroinštalácie'' THEN' IN
    pg_get_functiondef('public.bezpecne_dopyty()'::regprocedure)) > 0
    AS elektro_ma_samostatne_bezpecne_detaily,
  position('Remeslo: ' IN pg_get_functiondef('public.bezpecne_dopyty()'::regprocedure)) = 0
    AS zjednodusena_vetva_odstranena;
