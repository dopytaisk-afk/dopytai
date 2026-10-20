
"use strict";

const { dorucFakturu } = require("./invoice-delivery");

// Automatická kontrola každých 30 minút – test fakturácie po nastavení Supabase.
exports.config = {
  schedule: "*/30 * * * *"
};

exports.handler = async function () {
  // Fakturácia zostáva vypnutá, kým ju bezpečne neaktivujeme.
  if (process.env.DOPYTAI_ENABLE_INVOICE_EMAIL !== "true") {
    console.log("Automatické odosielanie faktúr je vypnuté.");
    return;
  }

  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!url || !key) {
    throw new Error("Chýba konfigurácia Supabase.");
  }

  // Vyhľadáme najviac 20 faktúr, ktoré ešte neboli odoslané.
  const response = await fetch(
    `${url.replace(/\/$/, "")}/rest/v1/faktury` +
     "?odoslane_at=is.null" +
"&odosielanie_zacate_at=is.null" +
    "&stav=eq.pripravena" +
      "&select=id" +
      "&order=created_at.asc" +
      "&limit=20",
    {
      headers: {
        apikey: key,
        Authorization: `Bearer ${key}`
      }
    }
  );

  if (!response.ok) {
    throw new Error(
      `Načítanie faktúr zlyhalo: ${response.status}`
    );
  }

  const faktury = await response.json();

  console.log("Neodoslané faktúry:", faktury.length);

  for (const faktura of faktury) {
    try {
      const vysledok = await dorucFakturu(faktura.id);

      console.log(
        "Spracovanie faktúry:",
        faktura.id,
        vysledok
      );
    } catch (error) {
      console.error(
        "Opakované odoslanie zlyhalo:",
        faktura.id,
        error.message
      );
    }
  }
};
