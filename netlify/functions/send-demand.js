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
          <div style="max-width:600px;margin:0 auto;font-family:Arial,sans-serif;color:#172b4d;">
  <div style="background:#1687f8;padding:24px;border-radius:14px 14px 0 0;color:white;">
    <h1 style="margin:0;font-size:26px;">DopytAI</h1>
    <p style="margin:8px 0 0;">Nový zákaznícky dopyt</p>
  </div>

  <div style="padding:24px;border:1px solid #e5e7eb;border-top:0;border-radius:0 0 14px 14px;">
    <h2 style="margin-top:0;">Nový dopyt vo vašom regióne</h2>

    <p><strong>Meno:</strong> ${data.meno || "-"}</p>
    <p><strong>Lokalita:</strong> ${data.lokalita || "-"}</p>
    <p><strong>Typ práce:</strong> ${data.typ_prace || "-"}</p>
    <p><strong>Plocha:</strong> ${data.plocha || "-"} m²</p>
    <p><strong>Odhad rozpočtu:</strong> ${data.rozpocet || "-"} €</p>

    <hr style="border:0;border-top:1px solid #e5e7eb;margin:22px 0;">

    <h3>Kontakt na zákazníka</h3>
    <p><strong>Telefón:</strong> ${data.telefon || "-"}</p>
    <p><strong>E-mail:</strong> ${data.email_zakaznika || "-"}</p>

    <p style="margin-top:24px;font-size:13px;color:#6b7280;">
      Dopyt bol odoslaný prostredníctvom DopytAI.
    </p>
  </div>
</div>
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
