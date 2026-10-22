
"use strict";

const { dorucFakturu } = require("./invoice-delivery");

// Automatická kontrola každých 30 minút – test po nastavení Resend.
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
  const paymentEnv = process.env.DOPYTAI_PAYMENT_ENV;
  const stripeKey = process.env.STRIPE_SECRET_KEY;
  const supabaseUrl = url.replace(/\/$/, "");

  if (paymentEnv === "test") {
    if (
      supabaseUrl !== "https://pwtvquyefpucjufvwnxp.supabase.co" ||
      !stripeKey?.startsWith("sk_test_")
    ) {
      throw new Error("Nesprávne testovacie prostredie fakturácie.");
    }
  } else if (paymentEnv === "live") {
    if (
      supabaseUrl !== "https://unwoolvttaljwbkgwmuy.supabase.co" ||
      !stripeKey?.startsWith("sk_live_")
    ) {
      throw new Error("Nesprávne produkčné prostredie fakturácie.");
    }
  } else {
    throw new Error("Nepovolené prostredie fakturácie.");
  }
  
  // Vyhľadáme najviac 20 faktúr, ktoré ešte neboli odoslané.
  const response = await fetch(
    `${url.replace(/\/$/, "")}/rest/v1/faktury` +
    "?odoslane_at=is.null" +
 "&or=(stav.eq.pripravena,and(stav.eq.odosiela_sa,odosielanie_zacate_at.lt." +
 encodeURIComponent(new Date(Date.now() - 15 * 60 * 1000).toISOString()) +
 "))" +
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
