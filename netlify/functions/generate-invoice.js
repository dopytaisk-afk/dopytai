
"use strict";

const { vytvorPdfFaktury } = require("./generate-invoice");

const BUCKET = "faktury";
const ODOSIELATEL = "DopytAI <info@dopytai24.sk>";

function konfiguracia() {
  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  const resendKey = process.env.RESEND_API_KEY;

  if (!url || !key || !resendKey) {
    throw new Error("Chýba konfigurácia fakturácie.");
  }

  return { url: url.replace(/\/$/, ""), key, resendKey };
}

function supabaseHeaders(key) {
  return {
    apikey: key,
    Authorization: `Bearer ${key}`
  };
}

async function supabaseRequest(url, key, cesta, options = {}) {
  const response = await fetch(url + cesta, {
    ...options,
    headers: {
      ...supabaseHeaders(key),
      ...(options.headers || {})
    }
  });

  if (!response.ok) {
    const detail = await response.text();
    throw new Error(
      `Supabase chyba ${response.status}: ${detail.slice(0, 500)}`
    );
  }

  return response;
}

async function dorucFakturu(fakturaId) {
  const { url, key, resendKey } = konfiguracia();

  if (!Number.isSafeInteger(Number(fakturaId)) ||
      Number(fakturaId) <= 0) {
    throw new Error("Neplatné ID faktúry.");
  }

  const id = Number(fakturaId);

  const response = await supabaseRequest(
    url,
    key,
    `/rest/v1/faktury?id=eq.${id}&select=*`
  );

  const zaznamy = await response.json();
  const faktura = zaznamy[0];

  if (!faktura) {
    throw new Error("Faktúra neexistuje.");
  }

  if (!faktura.odberatel_email ||
      !faktura.cislo_faktury ||
      !faktura.stripe_payment_id) {
    throw new Error("Faktúra nemá povinné údaje.");
  }

  // Bez overenej Stripe platby faktúru neposielame.
  const paymentId = encodeURIComponent(faktura.stripe_payment_id);

  const platbyResponse = await supabaseRequest(
    url,
    key,
    `/rest/v1/stripe_platby?payment_id=eq.${paymentId}&select=*`
  );

  const platby = await platbyResponse.json();

  const platba = platby.find(p =>
    Number(p.firma_id) === Number(faktura.firma_id) &&
    Number(p.suma) === Number(faktura.suma) &&
    p.livemode === true
  );

  if (!platba) {
    throw new Error("Chýba overená živá Stripe platba.");
  }

  // Základná ochrana pred opakovaným odoslaním.
  if (faktura.odoslane_at) {
    return {
      ok: true,
      alreadySent: true,
      invoiceNumber: faktura.cislo_faktury
    };
  }

  const cesta = `${id}/${faktura.cislo_faktury}.pdf`;

  // Ak PDF už existuje, použijeme uložený súbor.
  let pdfBuffer;

  const downloadResponse = await fetch(
    `${url}/storage/v1/object/${BUCKET}/${cesta}`,
    { headers: supabaseHeaders(key) }
  );

  if (downloadResponse.ok) {
    pdfBuffer = Buffer.from(await downloadResponse.arrayBuffer());
  } else if (downloadResponse.status === 404 ||
             downloadResponse.status === 400) {
    pdfBuffer = await vytvorPdfFaktury({
      ...faktura,
      cislo: faktura.cislo_faktury
    });

    await supabaseRequest(
      url,
      key,
      `/storage/v1/object/${BUCKET}/${cesta}`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/pdf",
          "x-upsert": "false"
        },
        body: pdfBuffer
      }
    );
  } else {
    throw new Error(
      `Nepodarilo sa načítať PDF (${downloadResponse.status}).`
    );
  }

  const emailResponse = await fetch(
    "https://api.resend.com/emails",
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${resendKey}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        from: ODOSIELATEL,
        to: [faktura.odberatel_email],
        subject: `DopytAI – faktúra ${faktura.cislo_faktury}`,
        text:
          `Dobrý deň,\n\n` +
          `ďakujeme za zakúpenie kreditu DopytAI.\n` +
          `V prílohe zasielame uhradenú faktúru ` +
          `${faktura.cislo_faktury}.\n\n` +
          `S pozdravom\nTím DopytAI`,
        attachments: [{
          filename: `${faktura.cislo_faktury}.pdf`,
          content: pdfBuffer.toString("base64")
        }]
      })
    }
  );

  if (!emailResponse.ok) {
    const detail = await emailResponse.text();
    throw new Error(
      `Resend chyba ${emailResponse.status}: ${detail.slice(0, 500)}`
    );
  }

  await supabaseRequest(
    url,
    key,
    `/rest/v1/faktury?id=eq.${id}&odoslane_at=is.null`,
    {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        Prefer: "return=minimal"
      },
      body: JSON.stringify({
        stav: "odoslana",
        pdf_cesta: cesta,
        odoslane_at: new Date().toISOString()
      })
    }
  );

  return {
    ok: true,
    invoiceNumber: faktura.cislo_faktury
  };
}

module.exports = { dorucFakturu };
