
"use strict";

const { vytvorPdfFaktury } = require("./generate-invoice");

async function dorucFakturu(faktura) {
  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  const resendKey = process.env.RESEND_API_KEY;

  if (!url || !key || !resendKey) {
    throw new Error("Chýba konfigurácia fakturácie.");
  }

  if (!faktura?.id || !faktura?.cislo_faktury ||
      !faktura?.odberatel_email) {
    throw new Error("Neúplné údaje faktúry.");
  }

  // Zatiaľ iba príprava prepojenia.
  // PDF, uloženie a e-mail zapojíme po kontrole
  // aktuálneho rozhrania generate-invoice.js.
  throw new Error(
    "Odosielanie faktúr ešte nie je aktivované."
  );
}

module.exports = { dorucFakturu };
