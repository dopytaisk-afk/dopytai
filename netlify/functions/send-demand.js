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

  <div style="margin:0;padding:24px 10px;background:#f3f6fa;font-family:Arial,sans-serif;color:#172b4d;">
    <div style="max-width:600px;margin:0 auto;background:#ffffff;border:1px solid #e5e7eb;border-radius:16px;overflow:hidden;">

      <div style="background:#1687f8;padding:28px 24px;color:#ffffff;">
        <div style="font-size:28px;font-weight:700;">DopytAI</div>
        <div style="margin-top:6px;font-size:15px;">Nový zákaznícky dopyt vo vašom regióne</div>
      </div>

      <div style="padding:26px 24px;">
        <div style="font-size:12px;font-weight:700;color:#1687f8;letter-spacing:1px;">
          NOVÝ DOPYT
        </div>

        <h2 style="margin:8px 0 22px;font-size:23px;color:#172b4d;">
          ${data.typ_prace || "Stavebný dopyt"}
        </h2>

        <table style="width:100%;border-collapse:collapse;font-size:15px;">
          <tr>
            <td style="padding:11px 0;color:#6b7280;border-bottom:1px solid #eef0f3;">Lokalita</td>
            <td style="padding:11px 0;text-align:right;font-weight:700;border-bottom:1px solid #eef0f3;">
              ${data.lokalita || "-"}
            </td>
          </tr>
          <tr>
            <td style="padding:11px 0;color:#6b7280;border-bottom:1px solid #eef0f3;">Plocha strechy</td>
            <td style="padding:11px 0;text-align:right;font-weight:700;border-bottom:1px solid #eef0f3;">
              ${data.plocha || "-"} m²
            </td>
          </tr>
          <tr>
            <td style="padding:11px 0;color:#6b7280;">Odhad zákazky</td>
            <td style="padding:11px 0;text-align:right;font-size:20px;font-weight:700;color:#1687f8;">
              ${data.rozpocet || "-"} €
            </td>
          </tr>
        </table>

        <div style="margin:26px 0;border-top:1px solid #e5e7eb;"></div>

        <h3 style="margin:0 0 14px;font-size:18px;color:#172b4d;">Kontakt na zákazníka</h3>

        <div style="background:#f8fafc;padding:18px;border-radius:12px;font-size:15px;line-height:1.8;">
          <div style="font-size:17px;font-weight:700;">${data.meno || "-"}</div>
          <div>
            Telefón:
            <a href="tel:${data.telefon || ""}" style="color:#1687f8;text-decoration:none;font-weight:700;">
              ${data.telefon || "-"}
            </a>
          </div>
          <div>
            E-mail:
            <a href="mailto:${data.email_zakaznika || ""}" style="color:#1687f8;text-decoration:none;">
              ${data.email_zakaznika || "-"}
            </a>
          </div>
        </div>

        <div style="margin-top:24px;padding:18px;background:#eef6ff;border-radius:12px;font-size:14px;line-height:1.6;">
          <strong style="font-size:16px;">Máte záujem o túto zákazku?</strong><br>
          Kontaktujte zákazníka čo najskôr a dohodnite si obhliadku alebo ďalší postup.
        </div>

        <p style="margin:28px 0 0;font-size:12px;color:#6b7280;text-align:center;">
          Dopyt bol odoslaný prostredníctvom DopytAI.
        </p>
      </div>

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
