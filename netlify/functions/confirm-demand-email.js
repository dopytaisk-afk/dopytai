
"use strict";

const { handler: notifyCompanies } =
  require("./notify-new-demand-secure");

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

  if (!url || !key) {
    return reply(503, {
      error: "Serverova konfiguracia chyba"
    });
  }

  let leadId;
  let token;

  try {
    const data = JSON.parse(event.body || "{}");
    leadId = Number(data.dopyt_id);
    token = data.token;
  } catch {
    return reply(400, {
      error: "Neplatna poziadavka"
    });
  }

  if (
    !Number.isSafeInteger(leadId) ||
    leadId <= 0 ||
    typeof token !== "string" ||
    !/^[0-9a-f]{64}$/.test(token)
  ) {
    return reply(400, {
      error: "Neplatne overovacie udaje"
    });
  }

  // 1. Najskor potvrdime zakaznicky email.
  // Databaza overi token a aktivuje dopyt.

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
        success: false,
        error: "Databazove overenie zlyhalo"
      });
    }

    const confirmed = await response.json();

    if (confirmed !== true) {
      return reply(400, {
        success: false,
        error: "Neplatny alebo uz pouzity overovaci odkaz"
      });
    }

  } catch (error) {
    console.error(
      "Confirm demand email error:",
      error.message
    );

    return reply(500, {
      success: false,
      error: "Internal server error"
    });
  }

  // 2. Zakaznicky email je potvrdeny.
  // Teraz upozornime vhodne firmy v danom kraji.
  // Chyba notifikacii nesmie zrusit potvrdenie.

  let notificationStatus = "failed";

  const webhookSecret =
    process.env.DOPYTAI_WEBHOOK_SECRET;

  if (!webhookSecret) {
    console.error(
      "DOPYTAI_WEBHOOK_SECRET nie je nastaveny"
    );
  } else {
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

      let notificationResult = {};

      try {
        notificationResult = JSON.parse(
          notificationResponse.body || "{}"
        );
      } catch {
        console.error(
          "Neplatna odpoved funkcie na upozornenia"
        );
      }

      if (
        notificationResponse.statusCode === 200 &&
        !notificationResult.error &&
        !notificationResult.skipped &&
        Number(notificationResult.failed || 0) === 0
      ) {
        notificationStatus = "processed";

        console.info(
          "Upozornenia firmam spracovane:",
          {
            dopyt_id: leadId,
            sent: notificationResult.sent || 0,
            failed: 0
          }
        );
      } else {
        console.error(
          "Upozornenia firmam sa nepodarilo dokoncit:",
          {
            dopyt_id: leadId,
            statusCode: notificationResponse.statusCode,
            error:
              notificationResult.error ||
              notificationResult.skipped ||
              "Neznama chyba"
          }
        );
      }

    } catch (error) {
      console.error(
        "Chyba spustenia upozorneni firmam:",
        error.message
      );
    }
  }

  // 3. Zakaznikovi vratime uspech potvrdenia.
  // Vysledok upozorneni sledujeme oddelene.

  return reply(200, {
    success: true,
    notifications: notificationStatus
  });
};
