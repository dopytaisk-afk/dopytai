# DopytAI – kalkulačka elektroinštalácií (návrh 18.11.2026)

Stav: **vývojová vetva**, nie produkcia. Zápis elektro dopytov ostáva zablokovaný prepínačom `ELEKTRO_ODOSIELANIE_POVOLENE=false`, pokiaľ nebude skontrolovaná a otestovaná SQL logika, emailové notifikácie, prípadná RLS a ochrana kontaktov.

## Prečo tieto čísla
Verejné cenníky používajú rôzne meracie jednotky: za m², za bod, za výjazd alebo paušálne za revíziu. Nižšie uvedené modelové hodnoty DopytAI sú **ilustratívne predpoklady**, nie priamo prebraté garantované cenníky a nevznikli cenovou ponukou zhotoviteľa.

- Kompletná elektroinštalácia bytu alebo domu: 35–65 €/m², práca a základný materiál, minimum 900–1 300 €. Typický dom 120 m²: 4 200–7 800 €.
- Čiastočná elektroinštalácia: 15–35 €/m² plochy, ktorej sa práce týkajú, minimum 200–350 €. Pre 50 m²: 750–1 750 €.
- Oprava alebo porucha: menšia 60–180 €; stredná 130–380 €; väčšia 300–850 €.
- Revízia bežného bytu: 90–240 €; bežného rodinného domu: 150–420 €.
- Iný objekt: individuálna cenová ponuka, kalkulačka nevytvára zavádzajúcu automatickú sumu.

Vyžaduje sa plocha pre kompletné a čiastočné práce. Pri oprave alebo revízii sa plocha nevyžaduje. Vyhodnotenie je okamžité pri zmene formulára, *pred odoslaním zákazníckeho dopytu*.

## Verejné referenčné cenníky
- INEKTRA – https://inektra.sk/cennik (uvádza kompletné elektroinštalácie rodinných domov)
- Daibau – https://www.daibau.sk/ceny/elektroinstalacie (porovnanie cena za m², odlišný rozsah prác)
- Elektroinštalácie Orava – https://www.elektroinstalacieorava.sk/cennik-prac/ (práce bez materiálu)
- Flavio – https://www.flavio.sk/blog/elektrikar-cena (hodinové sadzby a revízie)
- Multistep Žilina – https://www.elektrikar-zilina.sk/revizie/cennik (revízie domov)
- PROWORKIO – https://proworkio.sk/blog/revizia-elektroinstalacie-cena-na-slovensku-v-roku-2026 (porovnanie cien revízií)

Rôzne zdroje opisujú neporovnateľné rozsahy, DPH a materiál. Preto treba hodnoty kalibrovať podľa reálnych ponúk elektrikárov a vysvetľovať, čo odhad zahŕňa. Najmä rozvádzače, počet okruhov, podklad, región, náročnosť drážkovania, projekt a termín môžu cenu výrazne zmeniť.

## Overené výpočty (izolovaný JS test)
- Kompletná / dom / 120 m² = 4 200–7 800 €, stred 6 000 €.
- Čiastočná / byt / 50 m² = 750–1 750 €, stred 1 250 €.
- Oprava / stredná = 130–380 €, stred 255 €.
- Revízia / dom = 150–420 €, stred 285 €.
- Nezadaná plocha pri kompletnej elektroinštalácii = validácia a výzva doplniť plochu.
- Iný typ objektu = individuálne nacenenie.

Syntax JavaScriptu prešla kontrolou. Nešlo o plný E2E test v prehliadači, SQL ani email test.

## Pred produkciou
1. UX test na mobile a PC: všetky typy prác, prepnutie remesla a zmena plochy.
2. Preskúmať kalkulačné sadzby s reálnymi zhotoviteľmi; rozhodnúť, či zahrnúť materiál a DPH.
3. Po schválení rozšíriť SQL / bezpečné RPC / notifikácie. Otestovať osobné údaje pred a po kúpe kontaktu.
4. Overiť správny text orientačnej ceny aj v e-maili zákazníka a firemnej notifikácii.
5. Až potom výslovne schváliť zmenu flagu a prípadné zlúčenie PR do main.
