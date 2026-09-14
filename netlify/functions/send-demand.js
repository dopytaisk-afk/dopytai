exports.handler = async function (event) {
  if (event.httpMethod !== "POST") {
    return {
      statusCode: 405,
      body: JSON.stringify({ error: "Method not allowed" }),
    };
  }

  try {
    const data = JSON.parse(event.body || "{}");

    const response = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${process.env.RESEND_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: "DopytAI <onboarding@resend.dev>",
        to: [data.email],
        subject: "Nový dopyt z DopytAI",
        html: `
          <h2>Nový dopyt z DopytAI</h2>
          <p><strong>Meno:</strong> ${data.meno || "-"}</p>
          <p><strong>Lokalita:</strong> ${data.lokalita || "-"}</p>
          <p><strong>Typ práce:</strong> ${data.typ_prace || "-"}</p>
          <p><strong>Plocha:</strong> ${data.plocha || "-"} m²</p>
          <p><strong>Rozpočet:</strong> ${data.rozpocet || "-"} €</p>
          <p><strong>Telefón:</strong> ${data.telefon || "-"}</p>
          <p><strong>E-mail zákazníka:</strong> ${data.email_zakaznika || "-"}</p>
        `,
      }),
    });

    const result = await response.json();

    if (!response.ok) {
      return {
        statusCode: response.status,
        body: JSON.stringify(result),
      };
    }

    return {
      statusCode: 200,
      body: JSON.stringify({
        success: true,
        result,
      }),
    };
  } catch (error) {
    return {
      statusCode: 500,
      body: JSON.stringify({
        error: error.message,
      }),
    };
  }
};
