
const crypto = require("crypto");

const reply = (statusCode, body) => ({
  statusCode,
  headers: {
    "Content-Type": "application/json; charset=utf-8"
  },
  body: JSON.stringify(body)
});

const escapeHtml = (value) =>
  String(value ?? "").replace(/[&<>"']/g, (char) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#39;"
  })[char]);

exports.handler = async (event) => {
  if (event.httpMethod !== "POST") {
    return reply(405, { error: "Method not allowed" });
  }

  const secret = process.env.DOPYTAI_WEBHOOK_SECRET;
  const supplied =
    event.headers?.["x-dopytai-secret"] ||
    event.headers?.["X-Dopytai-Secret"] ||
    "";

  if (
    !secret ||
    !supplied ||
    !crypto.timingSafeEqual(
      crypto.createHash("sha256").update(String(secret)).digest(),
      crypto.createHash("sha256").update(String(supplied)).digest()
    )
  ) {
    return reply(401, { error: "Unauthorized" });
  }

  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  const resendKey = process.env.RESEND_API_KEY;
 const siteUrl = process.env.BRANCH === "overenie-emailu"
  ? "https://overenie-emailu--sparkly-choux-e2b050.netlify.app/"
  : "https://dopytai24.sk/";

  if (!url || !key || !resendKey) {
    return reply(500, { error: "Missing server configuration" });
  }

  const headers = {
    apikey: key,
    Authorization: `Bearer ${key}`,
    "Content-Type": "application/json"
  };

  const base = url.replace(/\/$/, "");

  const db = async (path, options = {}) => {
    const response = await fetch(`${base}/rest/v1/${path}`, {
      ...options,
      headers: { ...headers, ...(options.headers || {}) }
    });

    const raw = await response.text();
    let value;

    try {
      value = raw ? JSON.parse(raw) : null;
    } catch {
      value = raw;
    }

    if (!response.ok) {
      throw new Error(
        `Database error ${response.status}: ${String(raw).slice(0, 180)}`
      );
    }

    return value;
  };

  try {
    const payload = JSON.parse(event.body || "{}");

   if (
  payload.type !== "UPDATE" ||
  payload.table !== "dopyty" ||
  payload.schema !== "public" ||
  payload.record?.stav !== "novy" ||
  payload.old_record?.stav !== "caka_na_overenie"
) {
  return reply(200, {
    skipped: "Nie je to potvrdenie emailu"
  });
}

    const leadId = Number(payload.record?.id);

    if (!Number.isSafeInteger(leadId) || leadId <= 0) {
      return reply(400, { error: "Invalid lead ID" });
    }

    const leads = await db(
`dopyty?select=id,created_at,region,lokalita,typ_prace,odhad_ceny,cena_dopytu,stav,popis&id=eq.${leadId}`
    );

    if (!Array.isArray(leads) || leads.length !== 1) {
      return reply(404, { error: "Lead not found" });
    }

   const lead = leads[0];

if (lead.stav !== "novy") {
  return reply(200, {
    skipped: "Dopyt este nie je overeny"
  });
}



    if (!lead.region) {
      return reply(200, { skipped: "Missing region" });
    }

    const companies = await db(
      `firmy?select=id,email,region,typ_prace,stav&region=eq.${encodeURIComponent(lead.region)}&stav=in.(aktivna,akt%C3%ADvna)`
    );

    const work = String(lead.typ_prace || "").toLowerCase();

    const matching = companies.filter((company) => {
      const companyWork = String(company.typ_prace || "").toLowerCase();

      return (
        company.email &&
        companyWork.includes("strech") &&
        (
          work.includes("strech") ||
          work.includes("nová") ||
          work.includes("rekonštrukcia") ||
          work.includes("oprava")
        )
      );
    });

    const safeWork = escapeHtml(lead.typ_prace || "Nový dopyt");
    const safeLocation = escapeHtml(lead.lokalita || "-");
 const safeArea = escapeHtml((String(lead.popis || "").match(/Plocha:\s*(\d+(?:[.,]\d+)?)\s*m²/i) || [])[1] || "-");
   const priceMatch = String(lead.popis || "")
  .match(/(?:^|\n)Odhad:\s*([^\r\n]+)/i);

const priceRange = priceMatch?.[1]?.trim();

const safeBudget = escapeHtml(
  priceRange ||
  (lead.odhad_ceny == null
    ? "-"
    : `${Number(lead.odhad_ceny).toLocaleString("sk-SK")} €`)
);
const safeUnlockPrice = escapeHtml(
  lead.cena_dopytu == null
    ? "cenu uvedenú na stránke"
    : `${Number(lead.cena_dopytu).toLocaleString("sk-SK")} €`
);
    let sent = 0;
    let failed = 0;

    for (const company of matching) {
      const claimed = await db("rpc/rezervuj_upozornenie", {
        method: "POST",
        body: JSON.stringify({
          p_dopyt_id: leadId,
          p_firma_id: company.id
        })
      });

      if (claimed !== true) continue;

      try {
        const response = await fetch(
          "https://api.resend.com/emails",
          {
            method: "POST",
            headers: {
              Authorization: `Bearer ${resendKey}`,
              "Content-Type": "application/json"
            },
            body: JSON.stringify({
              from: "DopytAI <info@dopytai24.sk>",
              to: [company.email],
              subject: `Nový dopyt v regióne ${String(lead.region).replace(/[\r\n]/g, " ")}`,
              html: `
                <div style="margin:0;padding:24px 10px;background:#f3f6fa;font-family:Arial,sans-serif;color:#172b4d;">
                  <div style="max-width:600px;margin:0 auto;background:#ffffff;border:1px solid #e5e7eb;border-radius:16px;overflow:hidden;">
                    <div style="background:#1687f8;padding:28px 24px;color:#ffffff;">
                      <div style="font-size:28px;font-weight:700;">DopytAI</div>
                      <div style="margin-top:6px;font-size:15px;">Nový dopyt vo vašom regióne</div>
                    </div>
                    <div style="padding:26px 24px;">
                      <h2 style="margin:0 0 20px;">${safeWork}</h2>
                      <p><strong>📍 Lokalita:</strong> ${safeLocation}</p>
                      <p><strong>📐 Plocha:</strong> ${safeArea} m²</p>
                      <p><strong>💰 Orientačný odhad:</strong> ${safeBudget}</p>
                      <div style="margin-top:24px;padding:18px;background:#eef6ff;border-radius:12px;line-height:1.6;">
                        <strong>🔒 Kontakt zákazníka je skrytý.</strong><br>
                        Prihláste sa do DopytAI a odomknite kontakt zákazníka za ${safeUnlockPrice}.
                      </div>
                      <div style="margin-top:24px;text-align:center;">
                       <a href="${escapeHtml(siteUrl)}"
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
              `
            })
          }
        );

        if (!response.ok) {
          throw new Error(`Resend HTTP ${response.status}`);
        }

        sent++;
          } catch (error) {
        failed++;

        console.error(
          "Email send failed for company ID:",
          company.id,
          error.message
        );
      }
    }

    if (failed) {
      return reply(500, {
        sent,
        failed,
        error: "Some notifications failed"
      });
    }

    return reply(200, { sent, failed: 0 });
  } catch (error) {
    console.error(
      "Secure demand notification failed:",
      error.message
    );

    return reply(500, {
      error: "Notification processing failed"
    });
  }
};
