# Elektroinštalácie – vývojový checklist

**Stav:** WIP. Vetva `feature/elektroinstalacie`, PR #9. **NESLUČOVAŤ do `main` bez výslovného súhlasu majiteľa.**

## Čo je pripravené v GitHube
- Tretie remeslo na hlavnej stránke a v zákazníckom formulári
- Polia: typ elektroinštalácie, objekt a voliteľná plocha
- Typ práce `Elektroinštalácie` v registrácii firiem
- Tvar dopytu `typ_prace = 'Elektroinštalácie'`, cenová ponuka individuálna; údaje zákazníka do `popis`
- Zobrazenie elektro detailov v sekciách dostupných i zakúpených dopytov
- Filtrovanie notifikácií iba firmám s rovnakým remeslom a krajom
- `ELEKTRO_ODOSIELANIE_POVOLENE = false` – zámerný bezpečnostný zámok, kým nebude overený backend

## Čo sa nesmie predčasne spraviť
- Nenastavovať flag na `true`, kým nie je overené vytvorenie, viditeľnosť a nákup elektro dopytu na testovacej DB.
- Nemeniť produkčnú SQL funkciu `bezpecne_dopyty()` naslepo: jej aktuálna definícia bola v novembri upravovaná.
- Nemeniť e-mailovú logiku pre už existujúce strechy a sadrokartón.
- Nenasadzovať testovacie vetvy s prístupom k produkčným tajným kľúčom.

## Nasledujúca kontrola – iba SELECT (Supabase SQL Editor, produkcia, bez zmien)
```sql
SELECT p.proname AS funkcia, pg_get_functiondef(p.oid) AS definicia
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN (
    'bezpecne_dopyty',
    'vytvor_dopyt_s_token_v2',
    'kup_dopyt',
    'uz_predane_dopyty',
    'rezervuj_upozornenie_v2'
  )
ORDER BY p.proname;
```

**Načo:** zistiť, či funkcie explicitne filtrujú remeslo / akceptujú nový názov, či ceny dopytov zostanú nastavené serverom, či iná firma nezíska kontakt a či nákup zostane exkluzívny. Pred každou SQL úpravou vychádzať z *aktuálnej* definície a zachovať produkčnú logiku.

## Koncové skúšky po dokončení
1. TEST DB: vytvorenie dopytu elektro (bez reálnych kontaktov), potvrdenie zákazníckeho e-mailu.
2. Zobrazenie po potvrdení iba elektrikárom; dostupnosť zo všetkých krajov na webe, notifikácia iba firmám z kraja dopytu.
3. Skrytie mena, telefónu a e-mailu pred kúpou v RPC, nielen na stránke.
4. Preveriť fotografiu pred kúpou, exkluzívny nákup za správnu serverovú cenu pomocou skúšobného kreditu.
5. Overiť stav po F5 a novom prihlásení; druhá firma už predaný kontakt nezíska.
6. Regress test strechy a sadrokartón, vrátane notifikácií; Stripe ostrú platbu neopakovať bez rozhodnutia majiteľa.
7. Po manuálnom schválení PR pripraviť produkčné zmeny a znovu preveriť povolenia/Netlify deploy kontext.

**Poznámka:** Dokument neznamená, že SQL alebo reálne e-mailové testy už prebehli.
