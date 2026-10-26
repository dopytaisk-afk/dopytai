
"use strict";

const { handler: notifyCompanies } = require("./notify-new-demand-secure");

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
  const webhookSecret = process.env.DOPYTAI_WEBHOOK_SECRET;

  if (!url || !key || !webhookSecret) {
    return reply(503, { error: "Serverova konfiguracia chyba" });
  }

  let leadId;
  let token;

  try {
    const data = JSON.parse(event.body || "{}");
    leadId = Number(data.dopyt_id);
    token = data.token;
  } catch {
    return reply(400, { error: "Neplatna poziadavka" });
  }

  if (
    !Number.isSafeInteger(leadId) ||
    leadId <= 0 ||
    typeof token !== "string" ||
    !/^[0-9a-f]{64}$/.test(token)
  ) {
    return reply(400, { error: "Neplatne overovacie udaje" });
  }

  // 1. Potvrdime zakaznicky email v databaze.
  try {
    const response = await fetch(
      `${url}/rest/v1/rpc/server_potvrd_email_dopytu`,
      {
        method: "POST",
        headers: {
          apikey: key,
          Authorization: `Bearer ${key}`,
          "Content-Type": "application/json"
        },
        body: JSON.stringify({
          p_dopyt_id: leadId,
          p_token: token
        })
      }
    );

    if (!response.ok) {
      console.error(
        "Potvrdenie emailu zlyhalo, HTTP:",
        response.status
      );

      return reply(502, {
        error: "Databazove overenie zlyhalo"
      });
    }

    const confirmed = await response.json();

    if (confirmed !== true) {
      return reply(400, { success: false });
    }

  } catch (error) {
    console.error(
      "Confirm demand email error:",
      error.message
    );

    return reply(500, {
      error: "Internal server error"
    });
  }

  // 2. Email je potvrdeny.
  // Pripadna chyba upozorneni nesmie zrusit potvrdenie.
  let notificationStatus = "failed";

  try {
    const notificationResponse = await notifyCompanies({
      httpMethod: "POST",
      headers: {
        "x-dopytai-secret": webhookSecret
      },
      body: JSON.stringify({
        type: "UPDATE",
        table: "dopyty",
        schema: "public",
        record: {
          id: leadId,
          stav: "novy"
        },
        old_record: {
          id: leadId,
          stav: "caka_na_overenie"
        }
      })
    });

    const result = JSON.parse(
      notificationResponse.body || "{}"
    );

    if (
      notificationResponse.statusCode === 200 &&
      !result.error &&
      !result.skipped
    ) {
      notificationStatus = "processed";

      console.info("Upozornenia firmam:", {
        dopyt_id: leadId,
        sent: result.sent,
        failed: result.failed
      });
    } else {
      console.error("Upozornenia firmam zlyhali:", {
        dopyt_id: leadId,
        statusCode: notificationResponse.statusCode,
        error: result.error || result.skipped || "Neznama chyba"
      });
    }

  } catch (error) {
    console.error(
      "Chyba spustenia upozorneni firmam:",
      error.message
    );
  }

  // 3. Zakaznikovi potvrdime uspech nezavisle od notifikacii.
  return reply(200, {
    success: true,
    notifications: notificationStatus
  });
};
