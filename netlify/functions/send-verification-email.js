
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

const sameSecret = (a, b) => {
  if (!a || !b) return false;
  const x = crypto.createHash("sha256").update(a).digest();
  const y = crypto.createHash("sha256").update(b).digest();
  return crypto.timingSafeEqual(x, y);
};

exports.handler = async (event) => {
  if (event.httpMethod !== "POST") {
    return reply(405, { error: "Method not allowed" });
  }

  // Samostatné testovacie nastavenia.
 const secret = process.env.DOPYTAI_VERIFICATION_SECRET;
const url = process.env.SUPABASE_URL;
const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
const resendKey = process.env.RESEND_API_KEY;

  if (!secret || !url || !key || !resendKey) {
    return reply(503, { error: "Testovacia konfiguracia chyba" });
  }

  if (!sameSecret(
    String(event.headers?.["x-verification-secret"] || ""),
    secret
  )) {
    return reply(401, { error: "Unauthorized" });
  }

  try {
    const data = JSON.parse(event.body || "{}");
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

    // Údaje zákazníka čítame z testovacej databázy.
    const response = await fetch(
      `${url.replace(/\/$/, "")}/rest/v1/dopyty` +
      `?select=id,email,typ_prace,lokalita,popis,odhad_ceny,stav` +
      `&id=eq.${leadId}`,
      {
        headers: {
          apikey: key,
          Authorization: `Bearer ${key}`
        }
      }
    );

    if (!response.ok) {
      return reply(502, { error: "Databaza nie je dostupna" });
    }

    const rows = await response.json();
    const lead = rows[0];

    if (!lead || lead.stav !== "caka_na_overenie") {
      return reply(409, { error: "Dopyt necaka na overenie" });
    }

    if (
      typeof lead.email !== "string" ||
      !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(lead.email)
    ) {
      return reply(400, { error: "Neplatny email zakaznika" });
    }

    // Overovací odkaz smeruje do testovacieho prostredia.
    // Jeho presnú adresu nastavíme pri integrácii.
    const verificationBase =
      process.env.TEST_VERIFICATION_URL;

    if (!verificationBase) {
      return reply(503, { error: "Overovacia adresa chyba" });
    }

    const link = new URL(verificationBase);
    if (link.protocol !== "https:") {
      return reply(503, { error: "Neplatna overovacia adresa" });
    }

    link.searchParams.set("id", String(leadId));
    link.searchParams.set("token", token);

    const work = escapeHtml(lead.typ_prace || "Strecha");
    const location = escapeHtml(lead.lokalita || "-");
    const description = String(lead.popis || "");

    const area = escapeHtml(
      (description.match(/Plocha:\s*([\d.,]+)\s*m²/i) || [])[1] || "-"
    );

    const estimate = lead.odhad_ceny == null
      ? "Odhad sa pripravuje"
      : `${Number(lead.odhad_ceny).toLocaleString("sk-SK")} €`;

    const html = `
      <div style="background:#f3f7fc;padding:30px 12px;
                  font-family:Arial,sans-serif;color:#10294d;">
        <div style="max-width:600px;margin:auto;background:white;
                    border:1px solid #dce7f3;border-radius:18px;
                    overflow:hidden;">
          <div style="padding:26px;background:#087cf0;color:white;">
            <div style="font-size:30px;font-weight:bold;">⌂ DopytAI</div>
            <div style="margin-top:8px;">Váš dopyt na strechu</div>
          </div>

          <div style="padding:28px 24px;">
            <h2>Potvrďte svoj dopyt</h2>
            <p>Dobrý deň,</p>
            <p>ďakujeme, že ste využili DopytAI.
               Pripravili sme pre vás orientačný odhad ceny.</p>

            <div style="background:#edf6ff;padding:22px;
                        border-radius:12px;text-align:center;">
              <div style="font-size:13px;color:#527092;">
                ORIENTAČNÁ CENA REALIZÁCIE
              </div>
              <div style="font-size:30px;font-weight:bold;
                          color:#087cf0;margin-top:10px;">
                ${escapeHtml(estimate)}
              </div>
              <p style="font-size:12px;color:#667788;">
                Konečná cena závisí od stavu strechy,
                materiálu a rozsahu prác.
              </p>
            </div>

            <h3>Váš dopyt</h3>
            <p><b>Typ práce:</b> ${work}</p>
            <p><b>Plocha:</b> ${area} m²</p>
            <p><b>Lokalita:</b> ${location}</p>

            <div style="margin-top:26px;padding:22px;
                        background:#f5f9ff;border-radius:12px;">
              <h3 style="text-align:center;">
                Potvrďte svoju e-mailovú adresu
              </h3>
              <p style="text-align:center;">
                Po potvrdení sprístupníme váš dopyt
                remeselníkom.
              </p>
              <a href="${escapeHtml(link.toString())}"
                 style="display:block;text-align:center;
                        background:#087cf0;color:white;
                        text-decoration:none;padding:17px;
                        border-radius:10px;font-weight:bold;">
                Potvrdiť e-mail a aktivovať dopyt
              </a>
            </div>

            <p style="font-size:12px;color:#667788;
                      margin-top:25px;">
              Odkaz platí 24 hodín. Ak ste dopyt nevytvorili,
              e-mail ignorujte.
            </p>
          </div>
        </div>
      </div>
    `;

    const sent = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${resendKey}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        from: "DopytAI <info@dopytai24.sk>",
        to: [lead.email],
        subject: "DopytAI – potvrďte svoj dopyt a pozrite si cenu",
        html
      })
    });

    if (!sent.ok) {
      return reply(502, { error: "Email sa nepodarilo odoslat" });
    }

    return reply(200, { success: true });
  } catch (error) {
    console.error("Verification email error:", error.message);
    return reply(500, { error: "Internal server error" });
  }
};
