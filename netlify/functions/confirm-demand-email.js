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

  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!url || !key) {
    return reply(503, {
      error: "Serverova konfiguracia chyba"
    });
  }

  let data;

  try {
    data = JSON.parse(event.body || "{}");
  } catch {
    return reply(400, { error: "Neplatna poziadavka" });
  }

  const leadId = Number(data.dopyt_id);
  const token = data.token;

  if (
    !Number.isSafeInteger(leadId) ||
    leadId <= 0 ||
    typeof token !== "string" ||
    !/^[0-9a-f]{64}$/.test(token)
  ) {
    return reply(400, { error: "Neplatne overovacie udaje" });
  }

  try {
    const response = await fetch(
      `${url.replace(/\/$/, "")}/rest/v1/rpc/server_potvrd_email_dopytu`,
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

    return reply(200, { success: true });

  } catch (error) {
    console.error(
      "Confirm demand email error:",
      error.message
    );

    return reply(500, {
      error: "Internal server error"
    });
  }
};
