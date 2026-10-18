"use strict";

const { dorucFakturu } = require("./invoice-delivery");
const crypto = require("node:crypto");

const TEST_INVOICE_ID = 8;
const TEST_SUPABASE_URL =
  "https://pwtvquyefpucjufvwnxp.supabase.co";

exports.handler = async function (event) {
   const siteUrl = (process.env.URL || "").replace(/\/$/, "");
const deployUrl = (process.env.DEPLOY_URL || "").replace(/\/$/, "");
console.log("TEST DEPLOY CHECK", {
  url: process.env.URL || "nezname",
  deployUrl: process.env.DEPLOY_URL || "nezname",
  deployPrimeUrl: process.env.DEPLOY_PRIME_URL || "nezname",
  context: process.env.CONTEXT || "nezname"
});

    const secret = process.env.DOPYTAI_TEST_INVOICE_TOKEN;
  const supplied = event.headers["x-dopytai-secret"] || "";

  if (!secret || !supplied ||
      !crypto.timingSafeEqual(
        crypto.createHash("sha256").update(supplied).digest(),
        crypto.createHash("sha256").update(secret).digest()
      )) {
    return {
      statusCode: 403,
      body: "Unauthorized"
    };
  }
  // Tento test sa nesmie spustiť cez bežný prehliadač.
  if (event.httpMethod !== "POST") {
    return {
      statusCode: 405,
      body: "Method not allowed"
    };
  }

  // Kontrola testovacej databázy.
  const testUrl =
    "https://pwtvquyefpucjufvwnxp.supabase.co";

  const actualUrl =
    (process.env.SUPABASE_URL || "").replace(/\/$/, "");

  if (actualUrl !== testUrl) {
    return {
      statusCode: 403,
      body: "Povolena je iba testovacia databaza."
    };
  }

  try {
    const vysledok = await dorucFakturu(TEST_INVOICE_ID);

    return {
      statusCode: 200,
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(vysledok)
    };
  } catch (error) {
    console.error("Test invoice delivery failed:", error.message);

    return {
      statusCode: 500,
      body: JSON.stringify({
        ok: false,
        error: "Odoslanie faktury zlyhalo."
      })
    };
  }
};
