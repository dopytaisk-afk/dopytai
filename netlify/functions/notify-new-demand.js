exports.handler = async function (event) {
  if (event.httpMethod !== "POST") {
    return {
      statusCode: 405,
      body: JSON.stringify({ error: "Method not allowed" }),
    };
  }

  try {
    const data = JSON.parse(event.body || "{}");

    const SUPABASE_URL = process.env.SUPABASE_URL;
    const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      throw new Error("Chýba nastavenie Supabase na serveri.");
    }

    if (!data.region) {
      throw new Error("Chýba región dopytu.");
    }

    // Nájdeme aktívne firmy v rovnakom regióne
    const companiesResponse = await fetch(
      `${SUPABASE_URL}/rest/v1/firmy?select=id,názov,email,region,typ_prace,stav&region=eq.${encodeURIComponent(data.region)}&stav=eq.aktivna`,
      {
        headers: {
          apikey: SUPABASE_SERVICE_ROLE_KEY,
          Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
        },
      }
    );

    const companies = await companiesResponse.json();

    if (!companiesResponse.ok) {
      throw new Error("Nepodarilo sa načítať firmy.");
    }

    // Zatiaľ posielame iba firmám, ktoré majú e-mail
    const matchingCompanies = companies.filter((company) => {
      if (!company.email) return false;

      const companyWork = String(company.typ_prace || "").toLowerCase();
      const leadWork = String(data.typ_prace || "").toLowerCase();

      // Aktuálne máme strechárske dopyty
      return (
        companyWork.includes("strech") &&
        (leadWork.includes("strech") ||
          leadWork.includes("nová") ||
          leadWork.includes("rekonštrukcia") ||
          leadWork.includes("oprava"))
      );
    });

    const results = [];

    for (const company of matchingCompanies) {
      const response = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${process.env.RESEND_API_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          from: "DopytAI <onboarding@resend.dev>",
          to: [company.email],
          subject: `Nový dopyt v regióne ${data.region}`,
          html: `
            <div style="margin:0;padding:24px 10px;background:#f3f6fa;font-family:Arial,sans-serif;color:#172b4d;">
              <div style="max-width:600px;margin:0 auto;background:#ffffff;border:1px solid #e5e7eb;border-radius:16px;overflow:hidden;">

                <div style="background:#1687f8;padding:28px 24px;color:#ffffff;">
                  <div style="font-size:28px;font-weight:700;">DopytAI</div>
                  <div style="margin-top:6px;font-size:15px;">Nový dopyt vo vašom regióne</div>
                </div>

                <div style="padding:26px 24px;">
                  <h2 style="margin:0 0 20px;">
                    ${data.typ_prace || "Nový dopyt"}
                  </h2>

                  <p><strong>📍 Lokalita:</strong> ${data.lokalita || "-"}</p>
                  <p><strong>📐 Plocha:</strong> ${data.plocha || "-"} m²</p>
                  <p><strong>💰 Orientačný odhad:</strong> ${data.rozpocet || "-"}</p>

                  <div style="margin-top:24px;padding:18px;background:#eef6ff;border-radius:12px;line-height:1.6;">
                    <strong>🔒 Kontakt zákazníka je skrytý.</strong><br>
                    Prihláste sa do DopytAI a odomknite kontakt zákazníka za 25 €.
                  </div>

                  <div style="margin-top:24px;text-align:center;">
                    <a href="https://dopytai24.sk/"
                       style="display:inline-block;background:#1687f8;color:white;text-decoration:none;padding:14px 24px;border-radius:10px;font-weight:700;">
                      Zobraziť nový dopyt
                    </a>
                  </div>

                  <p style="margin-top:28px;font-size:12px;color:#6b7280;text-align:center;">
                    DopytAI – nové zákazky vo vašom regióne
                  </p>
                </div>

              </div>
            </div>
          `,
        }),
      });

      const result = await response.json();

      results.push({
        companyId: company.id,
        email: company.email,
        success: response.ok,
        result,
      });
    }

    return {
      statusCode: 200,
      body: JSON.stringify({
        success: true,
        notified: matchingCompanies.length,
        results,
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
