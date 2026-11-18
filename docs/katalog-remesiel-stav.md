# DopytAI – katalóg remesiel, vývojový stav 18.11.2026

## Súčasný stav
Vývojová vetva `feature/elektroinstalacie`, PR #9 **draft**, bez merge do main. Žiadna nová SQL migrácia sa nespustila týmto commitom.

### Pôvodné remeslá
- Strechy – existujúce produkčné workflow a kalkulačka, nezmenená logika.
- Sadrokartón – existujúce produkčné workflow a kalkulačka, nezmenená logika.
- Elektroinštalácie – vlastný formulár a orientačná kalkulačka na dev vetve, odosielanie vypnuté až do dokončenia bezpečnostných testov.

### Nový katalóg s jednotným konceptom formulára
Vodoinštalácie, Kúrenie, Klimatizácie, Murárske práce, Fasády a zateplenie, Maliarske práce, Obklady a dlažby, Podlahy, Okná a dvere, Tesárske práce, Hydroizolácie, Zámková dlažba, Ploty a brány, Zemné práce, Rekonštrukcie kúpeľní, Betonárske práce.

Každá má kartu na úvodnej stránke, prepnutie v zozname remesiel, štyri základné druhy prác a voliteľnú plochu. Grafika nových kariet je zatiaľ **náhradná ilustrácia/emoji**, nie finálna fotografia. Firemné registračné možnosti sú zobrazené, ale deaktivované.

**Nové remeslá zatiaľ nemožno odoslať!** `NOVE_REMESLA_MAPA` blokuje submit pred akýmkoľvek Supabase volaním. Nie je vytvorená ich SQL integrácia ani kalkulačka; zákazníkom to nesmie predstierať funkčnosť.

## Kontrola
- JavaScript syntakticky OK
- 16 unikátnych nových kategórií, 4 typy prác na kategóriu
- elektro flag stále false
- spoločný odosielací handler explicitne odmieta nové kategórie
- PR zostal draft a nebol zlúčený do main

## Ďalšie úlohy
1. Grafika: samostatné relevantné kvalitné fotky pre každú kartu a dostupnosť obrázkov z repozitára; nepoužívať obrázky so zapečeným textom do pozadia.
2. Kalkulácie: rozhodnúť kategórie, ktoré sa dajú bezpečne odhadovať podľa množstva, pri ostatných priznať individuálne nacenenie. Nepredstierať univerzálny vzorec.
3. Spoločná bezpečná architektúra Supabase, dostupnosť dopytov podľa remesla (nie kraja), notifikácie podľa kraja + remesla, zachovať exkluzívny nákup, email verification a RLS.
4. Otestovať všetky kategórie, ochranu údajov, fotografií, registráciu, reset hesla, fakturáciu, integráciu Stripe, regresiu striech a SDK.
5. Po manuálnom schválení postupne sprístupňovať beta kategórie a až nakoniec povoliť merge do `main`.

Neúspešný SQL pokus z 18.11.2026 skončil chybou v transakcii; pred nasadením databázy znovu iba čítaním overiť skutočný stav a zachovať zálohy.
