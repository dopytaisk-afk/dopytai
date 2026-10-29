
"use strict";

const crypto = require("crypto");

const reply = (statusCode, body) => ({
  statusCode,
  headers: { "Content-Type": "application/json; charset=utf-8" },
  body: JSON.stringify(body)
});

const escapeHtml = (value) =>
  String(value ?? "").replace(/[&<>"']/g, (char) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;",
    '"': "&quot;", "'": "&#39;"
  })[char]);

const sameSecret = (received, expected) => {
  if (!received || !expected) return false;
  const a = crypto.createHash("sha256").update(received).digest();
  const b = crypto.createHash("sha256").update(expected).digest();
  return crypto.timingSafeEqual(a, b);
};

const isUuid = (value) =>
  typeof value === "string" &&
  /^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i.test(value);

exports.handler = async (event) => {
  if (event.httpMethod !== "POST") {
    return reply(405, { error: "Method not allowed" });
  }

  const secret = process.env.DOPYTAI_VERIFICATION_SECRET;
  const url = process.env.SUPABASE_URL?.replace(/\/$/, "");
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  const resendKey = process.env.RESEND_API_KEY;
  const verificationBase = process.env.TEST_VERIFICATION_URL;

  if (!secret || !url || !key || !resendKey || !verificationBase) {
    return reply(503, { error: "Chyba serverova konfiguracia" });
  }

  const receivedSecret = event.headers?.["x-verification-secret"] ||
    event.headers?.["X-Verification-Secret"] || "";
  if (!sameSecret(String(receivedSecret), secret)) {
    return reply(401, { error: "Unauthorized" });
  }

  // Overime URL pred rezervaciou, aby zla konfiguracia neblokovala dopyt.
  let verificationUrl;
  try {
    verificationUrl = new URL(verificationBase);
    if (verificationUrl.protocol !== "https:") throw new Error("HTTPS required");
  } catch {
    return reply(503, { error: "Neplatna overovacia adresa" });
  }

  const dbHeaders = {
    apikey: key,
    Authorization: `Bearer ${key}`,
    "Content-Type": "application/json"
  };
  const rpc = async (name, body) => {
    const response = await fetch(`${url}/rest/v1/rpc/${name}`, {
      method: "POST",
      headers: dbHeaders,
      body: JSON.stringify(body)
    });
    if (!response.ok) throw new Error(`RPC ${name}: HTTP ${response.status}`);
    return response.json();
  };

  let leadId;
  try {
    const payload = JSON.parse(event.body || "{}");
    leadId = Number(payload.dopyt_id);
    if (!Number.isSafeInteger(leadId) || leadId <= 0) {
      return reply(400, { error: "Neplatne ID dopytu" });
    }
  } catch {
    return reply(400, { error: "Neplatne telo poziadavky" });
  }

  try {
    const response = await fetch(
      `${url}/rest/v1/dopyty?select=id,email,typ_prace,lokalita,popis,odhad_ceny,stav&id=eq.${leadId}`,
      { headers: { apikey: key, Authorization: `Bearer ${key}` } }
    );
    if (!response.ok) return reply(502, { error: "Databaza nie je dostupna" });
    const leads = await response.json();
    const lead = leads[0];
    if (!lead || lead.stav !== "caka_na_overenie") {
      return reply(409, { error: "Dopyt necaka na overenie" });
    }
    if (typeof lead.email !== "string" ||
        !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(lead.email)) {
      return reply(400, { error: "Neplatny email zakaznika" });
    }

    // Jeden atomicky krok v DB: token + rezervacia odoslania.
    const preparation = await rpc("server_zacni_overovaci_email_v3", {
      p_dopyt_id: leadId
    });
    if (preparation === null) {
      return reply(409, { error: "Email je uz rezervovany alebo odoslany" });
    }
    const token = preparation?.token;
    const attemptId = preparation?.attempt_id;
    if (typeof token !== "string" || !/^[0-9a-f]{64}$/.test(token) ||
        !isUuid(attemptId)) {
      // Neopakujeme: vysledok rezervacie je neisty.
      return reply(502, { error: "Neplatna odpoved databazy" });
    }

    const link = new URL(verificationUrl.toString());
    link.searchParams.set("id", String(leadId));
    link.searchParams.set("token", token);

    const work = escapeHtml(lead.typ_prace || "Strecha");
    const location = escapeHtml(lead.lokalita || "-");
    const description = String(lead.popis || "");
    const area = escapeHtml(
      (description.match(/Plocha:\s*([\d.,]+)\s*m²/i) || [])[1] || "-"
    );
    const estimate =
      (description.match(/Odhad:\s*([^\n]*)/) || [])[1]?.trim() ||
      "Odhad sa pripravuje";

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

    let sent;
    try {
      sent = await fetch("https://api.resend.com/emails", {
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
    } catch (error) {
      // Pri strate spojenia mohol Resend email prijat.
      // Rezervaciu neuvolnujeme a token nemenime.
      console.error("Neisty vysledok odoslania Resend:", error.message);
      return reply(502, { error: "Vysledok odoslania je neisty" });
    }

    if (!sent.ok) {
      let errorSaved = false;
      try {
        errorSaved = (await rpc("server_zaznamenaj_chybu_emailu_v2", {
          p_dopyt_id: leadId,
          p_attempt_id: attemptId,
          p_error: `Resend HTTP ${sent.status}`
        })) === true;
      } catch (error) {
        console.error("Zapis chyby Resend zlyhal:", error.message);
      }

      // Iba explicitne odmietnute poziadavky (nie vypadok ani HTTP 5xx).
      if (errorSaved && [400, 422].includes(sent.status)) {
        try {
          const released = await rpc("server_uvolni_overovaci_email_v2", {
            p_dopyt_id: leadId,
            p_attempt_id: attemptId
          });
          if (released !== true) console.error("Rezervacia nebola uvolnena");
        } catch (error) {
          console.error("Uvolnenie rezervacie zlyhalo:", error.message);
        }
      }
      return reply(502, { error: "Email sa nepodarilo odoslat" });
    }

    const resendResult = await sent.json().catch(() => null);
    const resendId = resendResult?.id;
    if (typeof resendId !== "string" || !resendId.trim()) {
      // Resend mohol spravu prijat. Neskusame odoslat znova.
      console.error("Resend nevratil ID prijatej spravy");
      return reply(502, { error: "Email prijaty, ale chyba identifikator" });
    }

    try {
      const marked = await rpc("server_oznac_overovaci_email_odoslany_v3", {
        p_dopyt_id: leadId,
        p_attempt_id: attemptId,
        p_resend_id: resendId
      });
      if (marked !== true) {
        console.error("Odoslanie sa nepodarilo zaznamenat v databaze");
        return reply(502, { error: "Email prijaty, evidencia zlyhala" });
      }
    } catch (error) {
      console.error("Zaznamenanie odoslania zlyhalo:", error.message);
      return reply(502, { error: "Email prijaty, evidencia zlyhala" });
    }

    return reply(200, { success: true });
  } catch (error) {
    console.error("Verification email server error:", error.message);
    return reply(500, { error: "Internal server error" });
  }
};
