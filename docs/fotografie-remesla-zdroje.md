# DopytAI – fotografický katalóg (vývojová vetva)

Fotografie vybrané z Pexels ako rozličné realistické motívy; ich zdrojové stránky uvádzajú použitie zdarma podľa [licencie Pexels](https://www.pexels.com/license/). V tejto fáze ich web získava cez **externé CDN odkazy** odvodené z ID fotografie. **Priame CDN adresy sa zatiaľ nepodarilo overiť HTTP kontrolou ani vizuálne overiť v Netlify preview.** Ak niektorá nefunguje, karta zobrazí pôvodnú lokálnu SVG ilustráciu. Na ostré spustenie treba fotografie lokálne uložiť ako optimalizované WebP, overiť zobrazovanie a zohľadniť GDPR/cookies pri načítavaní z tretích strán.

| Remeslo | Pexels zdroj |
| --- | --- |
| Vodoinštalácie | https://www.pexels.com/photo/plumber-repairing-pipe-with-wrench-indoors-32588548/ |
| Kúrenie | https://www.pexels.com/photo/technician-maintaining-heating-system-in-workshop-34938442/ |
| Klimatizácie | https://www.pexels.com/photo/technician-fixing-an-aircon-5463582/ |
| Murárske práce | https://www.pexels.com/photo/bricklayers-at-work-on-construction-site-30081237/ |
| Fasády a zateplenie | https://www.pexels.com/photo/men-working-on-scaffolding-near-advertisement-board-on-building-12741270/ |
| Maliarske práce | https://www.pexels.com/photo/woman-painting-a-wall-with-a-roller-paint-brush-6764265/ |
| Obklady a dlažby | https://www.pexels.com/photo/construction-worker-laying-tile-in-renovation-project-29181494/ |
| Podlahy | https://www.pexels.com/photo/crop-man-installing-laminate-flooring-4263067/ |
| Okná a dvere | https://www.pexels.com/photo/handyman-installing-window-frame-with-drill-in-house-5691544/ |
| Tesárske práce | https://www.pexels.com/photo/construction-workers-building-roof-frame-38749905/ |
| Hydroizolácie | https://www.pexels.com/photo/worker-installing-waterproofing-membrane-on-roof-39238313/ |
| Zámková dlažba | https://www.pexels.com/photo/photo-of-two-workers-laying-paving-bricks-14557579/ |
| Ploty a brány | https://www.pexels.com/photo/white-metal-fence-with-gate-near-green-trees-10529669/ |
| Zemné práce | https://www.pexels.com/photo/excavator-scooping-sand-on-a-construction-site-21033111/ |
| Rekonštrukcie kúpeľní | https://www.pexels.com/photo/view-of-a-shower-in-a-modern-bathroom-19991834/ |
| Betonárske práce | https://www.pexels.com/photo/construction-workers-pouring-concrete-on-job-site-37121406/ |

## UI a bezpečnosť
- Všetky karty majú teraz modré tlačidlá `Zadať dopyt na ... →`, ktoré otvoria prípravný formulár.
- Neaktivovať odosielanie týchto remesiel bez backendu.
- Zatiaľ sa nezmenila produkčná vetva main ani Supabase.
