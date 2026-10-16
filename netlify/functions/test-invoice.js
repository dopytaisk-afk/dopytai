
"use strict";

const crypto = require("node:crypto");
const { vytvorPdfFaktury } = require("./generate-invoice");

const TEST_URL = "https://pwtvquyefpucjufvwnxp.supabase.co";
const FAKTURA_ID = 1;
const BUCKET = "faktury";

function odpoved(statusCode, data) {
  return {
    statusCode,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store"
    },
    body: JSON.stringify(data)
  };
}

exports.handler = async function (event) {
  if (event.httpMethod !== "POST") {
    return odpoved(405, { error: "Použite POST." });
  }

  const url = (process.env.SUPABASE_URL || "").replace(/\/$/, "");
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  const token = process.env.DOPYTAI_TEST_INVOICE_TOKEN;

  // Nikdy nespustiť proti ostrej databáze.
  if (url !== TEST_URL) {
    return odpoved(403, { error: "Povolené iba v DopytAI-TEST." });
  }

  if (!key || !token || token.length < 32) {
    return odpoved(503, { error: "Testovacia konfigurácia chýba." });
  }

  const supplied = event.headers?.["x-test-token"] || "";
  const a = Buffer.from(supplied);
  const b = Buffer.from(token);

  if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) {
    return odpoved(403, { error: "Nepovolený prístup." });
  }

  const headers = {
    apikey: key,
    Authorization: `Bearer ${key}`
  };

  try {
    const response = await fetch(
      `${url}/rest/v1/faktury?id=eq.${FAKTURA_ID}&select=*`,
      { headers }
    );

    if (!response.ok) {
      throw new Error(`Načítanie faktúry: HTTP ${response.status}`);
    }

    const records = await response.json();
    const faktura = records[0];

    if (!faktura) {
      return odpoved(404, { error: "Testovacia faktúra neexistuje." });
    }

    if (
      !String(faktura.cislo_faktury || "").startsWith("DAI-TEST-") ||
      Number(faktura.suma) !== 50 ||
      !faktura.odberatel_nazov
    ) {
      return odpoved(403, { error: "Neočakávaná testovacia faktúra." });
    }

    const cesta = `${FAKTURA_ID}/${faktura.cislo_faktury}.pdf`;

    const pdf = await vytvorPdfFaktury({
      ...faktura,
      cislo: faktura.cislo_faktury
    });

    // Bez prepisovania existujúceho PDF.
    const upload = await fetch(
      `${url}/storage/v1/object/${BUCKET}/${cesta}`,
      {
        method: "POST",
        headers: {
          ...headers,
          "Content-Type": "application/pdf",
          "x-upsert": "false"
        },
        body: pdf
      }
    );

    if (!upload.ok) {
      if (upload.status === 409) {
        return odpoved(200, {
          ok: true,
          alreadyExists: true,
          cesta,
          message: "PDF už je uložené."
        });
      }

      throw new Error(`Uloženie PDF: HTTP ${upload.status}`);
    }

    const update = await fetch(
      `${url}/rest/v1/faktury?id=eq.${FAKTURA_ID}`,
      {
        method: "PATCH",
        headers: {
          ...headers,
          "Content-Type": "application/json",
          Prefer: "return=minimal"
        },
        body: JSON.stringify({ pdf_cesta: cesta })
      }
    );

    if (!update.ok) {
      throw new Error(`Zápis cesty PDF: HTTP ${update.status}`);
    }

    return odpoved(200, {
      ok: true,
      cesta,
      message: "Testovacia faktúra bola bezpečne uložená."
    });
  } catch (error) {
    console.error("Test invoice storage error:", error);
    return odpoved(500, {
      error: "Nepodarilo sa uložiť testovaciu faktúru."
    });
  }
};
