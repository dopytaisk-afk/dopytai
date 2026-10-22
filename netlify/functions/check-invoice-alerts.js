
"use strict";

// Bezpečnostná poistka: kontrola je aktívna iba po zapnutí.
exports.config = {
  schedule: "*/30 * * * *"
};

const TEST_URL = "https://pwtvquyefpucjufvwnxp.supabase.co";
const LIVE_URL = "https://unwoolvttaljwbkgwmuy.supabase.co";
const ADMIN_EMAIL = "dopytai.sk@gmail.com";
const ODOSIELATEL = "DopytAI <info@dopytai24.sk>";

exports.handler = async function () {
if (process.env.DOPYTAI_ENABLE_INVOICE_ALERTS !== "true") {
  console.log("Upozornenia na faktúry sú vypnuté.");
  return {
    statusCode: 200,
    body: "OK - upozornenia su vypnute."
  };
}

  const url = (process.env.SUPABASE_URL || "").replace(/\/$/, "");
const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
const resendKey = process.env.RESEND_API_KEY;


  const paymentEnv = process.env.DOPYTAI_PAYMENT_ENV;
  const stripeKey = process.env.STRIPE_SECRET_KEY;

  if (paymentEnv === "live") {
    if (
      url !== LIVE_URL ||
      !stripeKey?.startsWith("sk_live_")
    ) {
      throw new Error("Nesprávne produkčné prostredie kontroly faktúr.");
    }
  } else if (paymentEnv === "test") {
    if (
      url !== TEST_URL ||
      !stripeKey?.startsWith("sk_test_")
    ) {
      throw new Error("Nesprávne testovacie prostredie kontroly faktúr.");
    }
  } else {
    throw new Error("Nepovolené prostredie kontroly faktúr.");
  }


  if (!key || !resendKey) {
    throw new Error("Chýba konfigurácia kontroly faktúr.");
  }

  const hranica = new Date(Date.now() - 15 * 60 * 1000).toISOString();

  const query = new URLSearchParams({
    "odoslane_at": "is.null",
    "odosielanie_zacate_at": `lt.${hranica}`,
    "select": "id,cislo_faktury,stav,odosielanie_zacate_at",
    "order": "odosielanie_zacate_at.asc",
    "limit": "20"
  });

  const response = await fetch(`${url}/rest/v1/faktury?${query}`, {
    headers: {
      apikey: key,
      Authorization: `Bearer ${key}`
    }
  });

  if (!response.ok) {
    throw new Error(`Kontrola faktúr zlyhala: ${response.status}`);
  }

  const faktury = await response.json();

 if (faktury.length === 0) {
  console.log("Žiadne zaseknuté faktúry.");
  return {
    statusCode: 200,
    body: "OK - ziadne zaseknute faktury."
  };
}

  const dnes = new Date().toISOString().slice(0, 10);

  const text = [
   `DopytAI ${url === TEST_URL ? "TEST" : "LIVE"} – upozornenie na nedokončené faktúry`,
    "",
    `Počet nájdených faktúr: ${faktury.length}`,
    "",
    ...faktury.map(f =>
      `Faktúra ${f.cislo_faktury || f.id} | stav: ${f.stav} | začiatok: ${f.odosielanie_zacate_at}`
    ),
    "",
    "Pred opakovaným odoslaním najskôr over stav v Resend.",
    "Toto upozornenie faktúry automaticky neodosiela."
  ].join("\n");

  const emailResponse = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${resendKey}`,
      "Content-Type": "application/json",
     "Idempotency-Key": `dopytai-${url === TEST_URL ? "test" : "live"}-invoice-alert-${Math.floor(Date.now() / 1800000)}`
    },
    body: JSON.stringify({
      from: ODOSIELATEL,
      to: [ADMIN_EMAIL],
     subject: `DopytAI ${url === TEST_URL ? "TEST" : "LIVE"} – POZOR: nedokončené faktúry`,
      text
    })
  });

  if (!emailResponse.ok) {
    throw new Error(`Odoslanie upozornenia zlyhalo: ${emailResponse.status}`);
  }

  console.log("Upozornenie na faktúry bolo spracované.");

return {
  statusCode: 200,
  body: "OK - upozornenie bolo spracovane."
};
  };
