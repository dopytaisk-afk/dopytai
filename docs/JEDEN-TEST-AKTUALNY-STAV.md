# DopytAI – jedno testovacie prostredie, prehľad zmien

**Rozhodnutie vlastníka, 19. 11. 2026:** všetok ďalší vývoj viesť v jednej existujúcej testovacej vetve. Nepresúvať fungujúce integrácie naslepo. Stripe URL a webhooky ponechať v doteraz používanom stave, kým sa neoverí presná príčina nespracovanej platby. Nepokračovať vytváraním nových testovacích vetiev.

## Jediné aktívne pracovné prostredie
- GitHub: `feature/elektroinstalacie`, draft PR #9 (**neprepájať do main bez povolenia**).
- Netlify web: `https://deploy-preview-9--sparkly-choux-e2b050.netlify.app/`
- Supabase: **DopytAI-TEST** `https://pwtvquyefpucjufvwnxp.supabase.co`.
- Produkcia: `main`, `https://dopytai24.sk/`, produkčná Supabase – bez zmien.

## Aktuálne zmeny, uložené v tejto jednej vetve
Tento súbor je **centrálny pracovný prehľad, nie vykonateľný súhrnný kód**. Dôvod: databázové SQL, HTML/JS a Netlify serverové funkcie majú samostatné bezpečnostné a nasadzovacie pravidlá; zlepenie do jedného vykonateľného súboru by rozbilo funkčnosť.

- `index.html`: formuláre a ceny pre 19 remesiel, technické údaje pred nákupom, odstránený duplicitný „Popis“ vo firemnom paneli, cena podľa bezpečného odhadu.
- `netlify/functions/_shared/trade-types.js`: spoločné mapovanie remesiel a regionálne párovanie e-mailových príjemcov.
- `netlify/functions/notify-new-demand-secure.js`: testovacie upozornenia na základe rovnakého kraja a remesla; zobrazovanie orientačnej ceny.
- `netlify/functions/send-verification-email.js`: potvrdenie e-mailu zákazníka so správnym remeslom a odhadom.
- `sql/19-remesiel-test-migracia.sql`: zdrojový návrh migračného SQL pre 19 remesiel; **nespúšťať znovu**.
- `sql/test-oprava-detailov-17-remesiel-2026-11-19.sql`: oprava bezpečného výberu technických údajov, **už úspešne vykonaná v TEST**.
- `sql/test-odhady-17-remesiel-2026-11-19.sql`: prvotná verzia doplnenia cenových odhadov; v TEST bol spustený zodpovedajúci aktualizovaný SQL z chatu a výsledná kontrola vrátila true. **Nespúšťať opäť**.
- `netlify/functions/create-checkout.js`: Stripe návratové URL **vrátené na pôvodné existujúce adresy podľa rozhodnutia majiteľa**; žiadna zmena v nastavení Stripe destinácií.
- `netlify/functions/stripe-webhook.js`: nedotknutý existujúci webhook pre kredit a faktúru.

## Stripe – zámerne ponechané pôvodné adresy
- V `create-checkout.js`: test checkout návrat na `https://rozsirenie-remesiel--sparkly-choux-e2b050.netlify.app`; live návrat na `https://dopytai24.sk`.
- Stripe Dashboard „DopytAI Test Webhook“: existujúca cieľová adresa `https://test-fakturacia--sparkly-choux-e2b050.netlify.app/.netlify/functions/stripe-webhook` – **neprepnutá**.
- Toto sú **historické adresy**, nie potvrdenie správnej funkčnosti s PR #9; testovaciu platbu 100 € z 19.11.2026 nevidno vo vybranom Stripe sandboxe, v DopytAI-TEST firma 10 má 0 € a `stripe_platby` neobsahuje platbu.
- **Neopakovať platbu ani nepripisovať kredit ručne, kým sa neidentifikuje relácia/účtovná evidencia.**
- Zabezpečiť funkčné end-to-end platby pred odstránením akejkoľvek staršej vetvy; nestačí samotná zmena návratovej URL.

## Potvrdené testy
- TEST elektro dopyt, kalkulácia 4 200–7 800 €, e-mail zákazníkovi, overenie a aktivácia.
- E-mailové upozornenie doručené žilinskej firme ID 10; bratislavská ID 11 ho nedostala.
- Obe firmy (rovnaké remeslo) vidia zákazku zo Žiliny, aj napriek odlišnému kraju.
- Technické detaily, cena, skrytý kontakt viditeľné korektne; duplicitný „Popis“ odstránený.
- Ostatných 18 remeselných kategórií ešte nemá samostatne potvrdený úplný end-to-end test.
- **Kúpa za 25 € / exkluzivita a pripísanie Stripe kreditu: otvorené.**

## Pred akýmkoľvek čistením
1. Audit existujúcich referencií na staré testovacie adresy a vetvy.
2. Spoľahlivý test platieb, webhookov, kreditu, e-mailov a fakturácie iba v jednom teste.
3. Až potom, so samostatným schválením, vyradiť nepotrebné vetvy. **Nič nemazať automaticky.**
4. **Celý SQL/JS kód potrebný pre používateľa vždy dať priamo do chatu.**
