
"use strict";

const { handler: sendVerificationEmail } =
  require("./send-verification-email");

const reply = (statusCode, body) => ({
  statusCode,
  headers: {
    "Content-Type": "application/json; charset=utf-8",
    "Cache-Control": "no-store"
  },
  body: JSON.stringify(body)
});

exports.handler = async (event) => {
  if (event.httpMethod !== "POST") {
    return reply(405, { error: "Method not allowed" });
  }

  const url = process.env.SUPABASE_URL?.replace(/\/$/, "");
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  const secret = process.env.DOPYTAI_VERIFICATION_SECRET;

  if (!url || !key || !secret) {
    return reply(503, {
      error: "Serverova konfiguracia nie je pripravena"
    });
  }

  let data;

  try {
    data = JSON.parse(event.body || "{}");
  } catch {
    return reply(400, { error: "Neplatne udaje" });
  }

  const leadId = Number(data.dopyt_id);
  const uploadToken = data.upload_token;

  if (
    !Number.isSafeInteger(leadId) ||
    leadId <= 0 ||
    typeof uploadToken !== "string" ||
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(uploadToken)
  ) {
    return reply(400, { error: "Neplatne udaje dopytu" });
  }

  try {
    // Overenie, ze poziadavka patri k vytvorenemu dopytu.
    const verifyResponse = await fetch(
      `${url}/rest/v1/rpc/server_over_vytvorenie_dopytu`,
      {
        method: "POST",
        headers: {
          apikey: key,
          Authorization: `Bearer ${key}`,
          "Content-Type": "application/json"
        },
        body: JSON.stringify({
          p_dopyt_id: leadId,
          p_upload_token: uploadToken
        })
      }
    );

    if (!verifyResponse.ok) {
      console.error(
        "Overenie vlastnictva dopytu zlyhalo:",
        verifyResponse.status
      );

      return reply(502, {
        error: "Overenie dopytu sa nepodarilo"
      });
    }

    const allowed = await verifyResponse.json();

    if (allowed !== true) {
      return reply(403, {
        error: "Neplatne alebo expirovane opravnenie"
      });
    }

    // Tajny kluc zostava iba na serveri.
    // Povodna funkcia vykona rezervaciu a odoslanie.
    return await sendVerificationEmail({
      httpMethod: "POST",
      headers: {
        "x-verification-secret": secret
      },
      body: JSON.stringify({
        dopyt_id: leadId
      })
    });

  } catch (error) {
    console.error(
      "Spustenie overovacieho emailu zlyhalo:",
      error.message
    );

    return reply(500, {
      error: "Overovaci email sa nepodarilo spracovat"
    });
  }
};
