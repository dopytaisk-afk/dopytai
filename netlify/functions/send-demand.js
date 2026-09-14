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
  <div style="max-width:600px;margin:0 auto;background:#f8fafc;font-family:Arial,sans-serif;color:#172b4d;border-radius:16px;overflow:hidden;border:1px solid #e5e7eb;">

    <div style="background:#1687f8;padding:28px 24px;color:white;">
      <div style="font-size:28px;font-weight:bold;">DopytAI</div>
      <div style="margin-top:6px;font-size:15px;">Nový zákaznícky dopyt vo vašom regióne</div>
    </div>

    <div style="padding:26px 24px;background:white;">
      <div style="font-size:13px;font-weight:bold;color:#1687f8;text-transform:uppercase;letter-spacing:1px;">
        NOVÝ DOPYT
      </div>

      <h2 style="margin:8px 0 20px;font-size:22px;color:#172b4d;">
        ${data.typ_prace || "Stavebný dopyt"}
      </h2>

      <table style="width:100%;border-collapse:collapse;font-size:15px;">
        <tr>
          <td style="padding:10px 0;color:#6b7280;">Lokalita</td>
          <td style="padding:10px 0;text-align:right;font-weight:bold;">${data.lokalita || "-"}</td>
        </tr>
        <tr>
          <td style="padding:10px 0;color:#6b7280;">Plocha strechy</td>
          <td style="padding:10px 0;text-align:right;font-weight:bold;">${data.plocha || "-"} m²</td>
        </tr>
        <tr>
          <td style="padding:10px 0;color:#6b7280;">Odhad zákazky</td>
          <td style="padding:10px 0;text-align:right;font-size:19px;font-weight:bold;color:#1687f8;">
            ${data.rozpocet || "-"} €
          </td>
        </tr>
      </table>

      <div style="margin:24px 0;border-top:1px solid #e5e7eb;"></div>

      <h3 style="margin:0 0 14px;font-size:17px;">Kontakt na zákazníka</h3>

      <div style="background:#f8fafc;padding:18px;border-radius:10px;line-height:1.8;">
        <strong>${data.meno || "-"}</strong><br>
        Telefón: ${data.telefon || "-"}<br>
        E-mail: ${data.email_zakaznika || "-"}
      </div>

      <div style="margin-top:24px;padding:16px;background:#eef6ff;border-radius:10px;font-size:14px;line-height:1.5;">
        <strong>Máte záujem o túto zákazku?</strong><br>
        Kontaktujte zákazníka čo najskôr a dohodnite si ďalší postup.
      </div>

      <p style="margin:26px 0 0;font-size:12px;color:#6b7280;text-align:center;">
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
