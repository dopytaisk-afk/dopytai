
"use strict";

const crypto = require("node:crypto");
const { vytvorPdfFaktury } = require("./generate-invoice");

const TEST_EMAIL = "mirochovanec28@gmail.com";

exports.handler = async function (event) {
  if (event.httpMethod !== "POST") {
    return { statusCode: 405, body: "Method not allowed" };
  }

  const secret = process.env.DOPYTAI_WEBHOOK_SECRET;
  const resendKey = process.env.RESEND_API_KEY;

  if (!secret || !resendKey) {
    return { statusCode: 503, body: "Test nie je nakonfigurovany." };
  }

  const token = event.headers?.["x-test-secret"] || "";
  const a = Buffer.from(token);
  const b = Buffer.from(secret);

  if (
    a.length !== b.length ||
    !crypto.timingSafeEqual(a, b)
  ) {
    return { statusCode: 403, body: "Forbidden" };
  }

  try {
    const faktura = {
      cislo: "TEST-2026-0001",
      suma: 50,
      datum_vystavenia: "2026-10-13",
      datum_dodania: "2026-10-13",
      odberatel_nazov: "Test DopytAI",
      odberatel_ulica: "Testovacia 12",
      odberatel_psc: "010 01",
      odberatel_mesto: "Bystrica",
      odberatel_ico: "12345678",
      odberatel_dic: "1234567890",
      odberatel_email: TEST_EMAIL,
      popis: "Predplatený kredit na sprístupnenie stavebných dopytov"
    };

    const pdf = await vytvorPdfFaktury(faktura);

    const response = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${resendKey}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        from: "DopytAI <info@dopytai24.sk>",
        to: [TEST_EMAIL],
        subject: "DopytAI – TEST PDF faktúry",
        text: "Toto je skúšobná faktúra. Nejde o skutočnú platbu ani účtovný doklad.",
        attachments: [
          {
            filename: "TEST-faktura-DopytAI.pdf",
            content: pdf.toString("base64")
          }
        ]
      })
    });

    if (!response.ok) {
      console.error("Resend test failed:", response.status);
      return { statusCode: 502, body: "Odoslanie zlyhalo." };
    }

    return { statusCode: 200, body: "Testovaci email odoslany." };
  } catch (error) {
    console.error("Invoice email test error:", error.message);
    return { statusCode: 500, body: "Test zlyhal." };
  }
};
