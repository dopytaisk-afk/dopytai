
const crypto = require("crypto");
const { dorucFakturu } = require("./invoice-delivery");

const TEST_SUPABASE_URL =
  "https://pwtvquyefpucjufvwnxp.supabase.co";

const LIVE_SUPABASE_URL =
  "https://unwoolvttaljwbkgwmuy.supabase.co";

function response(statusCode, body) {
  return {
    statusCode,
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body)
  };
}

function supabaseHeaders(key) {
  return {
    apikey: key,
    Authorization: `Bearer ${key}`,
    "Content-Type": "application/json"
  };
}

async function supabaseRequest(url, key, path, options = {}) {
  return fetch(`${url.replace(/\/$/, "")}/rest/v1/${path}`, {
    ...options,
    headers: {
      ...supabaseHeaders(key),
      ...(options.headers || {})
    }
  });
}

function getEnvironment() {
  const paymentEnv = process.env.DOPYTAI_PAYMENT_ENV;
  const url = (process.env.SUPABASE_URL || "").replace(/\/$/, "");
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  const stripeKey = process.env.STRIPE_SECRET_KEY;

  if (!url || !key || !stripeKey) {
    throw new Error("Chýba konfigurácia platobného prostredia.");
  }

  if (paymentEnv === "live") {
    if (
      url !== LIVE_SUPABASE_URL ||
      !stripeKey.startsWith("sk_live_")
    ) {
      throw new Error("Nesprávna konfigurácia produkčného webhooku.");
    }

    return {
      url,
      key,
      livemode: true,
      allowInvoiceEmail: true
    };
  }

  if (paymentEnv === "test") {
    if (
      url !== TEST_SUPABASE_URL ||
      !stripeKey.startsWith("sk_test_")
    ) {
      throw new Error("Nesprávna konfigurácia testovacieho webhooku.");
    }

    return {
      url,
      key,
      livemode: false,
      allowInvoiceEmail: true
    };
  }

  throw new Error("Nepovolené platobné prostredie.");
}

function verifyStripeSignature(event, secret) {
  const signature =
    event.headers?.["stripe-signature"] ||
    event.headers?.["Stripe-Signature"];

  if (!signature) {
    throw new Error("Chýba Stripe podpis");
  }

  const entries = signature.split(",").map(s => s.trim());

  const timestamp = entries
    .find(s => s.startsWith("t="))
    ?.slice(2);

  const signatures = entries
    .filter(s => s.startsWith("v1="))
    .map(s => s.slice(3));

  if (
    !timestamp ||
    !/^\d+$/.test(timestamp) ||
    signatures.length === 0
  ) {
    throw new Error("Neplatný Stripe podpis");
  }

  if (
    Math.abs(Date.now() / 1000 - Number(timestamp)) > 300
  ) {
    throw new Error("Stripe podpisu vypršala platnosť");
  }

  const payload = event.isBase64Encoded
    ? Buffer.from(event.body || "", "base64").toString("utf8")
    : event.body || "";

  const expected = crypto
    .createHmac("sha256", secret)
    .update(`${timestamp}.${payload}`, "utf8")
    .digest("hex");

  const verified = signatures.some(sig => {
    if (!/^[0-9a-f]{64}$/i.test(sig)) return false;

    return crypto.timingSafeEqual(
      Buffer.from(sig, "hex"),
      Buffer.from(expected, "hex")
    );
  });

  if (!verified) {
    throw new Error("Stripe podpis nesúhlasí");
  }

  return JSON.parse(payload);
}

async function getPayments(url, key, paymentId) {
  const check = await supabaseRequest(
    url,
    key,
    `stripe_platby?payment_id=eq.${encodeURIComponent(paymentId)}&select=firma_id,suma,livemode`
  );

  if (!check.ok) {
    throw new Error(
      `Kontrola platby zlyhala: ${check.status} ${await check.text()}`
    );
  }

  return check.json();
}

exports.handler = async function(event) {
  if (event.httpMethod !== "POST") {
    return response(405, { error: "Method not allowed" });
  }

  try {
    const secret = process.env.STRIPE_WEBHOOK_SECRET;

    if (!secret) {
      throw new Error("STRIPE_WEBHOOK_SECRET nie je nastavený");
    }

    const stripeEvent = verifyStripeSignature(event, secret);

    if (stripeEvent.type !== "checkout.session.completed") {
      return response(200, { received: true });
    }

    const env = getEnvironment();

    // Ostra platba patri len do ostrej databazy.
    // Testovacia platba patri len do testovacej databazy.
    if (stripeEvent.livemode !== env.livemode) {
      console.error("Stripe prostredie nesúhlasí", {
        context: process.env.CONTEXT,
        eventLivemode: stripeEvent.livemode
      });

      return response(400, {
        error: "Nesprávne prostredie platby"
      });
    }

    const session = stripeEvent.data?.object;

    if (session?.object !== "checkout.session") {
      throw new Error("Neplatný typ Stripe objektu");
    }

    if (session.mode !== "payment") {
      throw new Error("Nepodporovaný typ platby");
    }

    if (session.payment_status !== "paid") {
      throw new Error("Stripe platba nie je zaplatená");
    }

    if (session.currency?.toLowerCase() !== "eur") {
      throw new Error("Neplatná mena platby");
    }

    const firmaId = Number(session.metadata?.firma_id);
    const amount = Number(session.amount_total) / 100;
    const eventId = stripeEvent.id;
    const paymentId = session.payment_intent || session.id;

    if (
      !Number.isSafeInteger(firmaId) ||
      firmaId <= 0 ||
     
![25, 50, 100, 200].includes(amount) ||

      !eventId ||
      !paymentId
    ) {
      throw new Error("Neplatné údaje Stripe platby");
    }

    let payments = await getPayments(
      env.url,
      env.key,
      paymentId
    );

    if (payments.length === 0) {
      const credit = await supabaseRequest(
        env.url,
        env.key,
        "rpc/pripis_kredit",
        {
          method: "POST",
          body: JSON.stringify({
            p_firma_id: firmaId,
            p_suma: amount,
            p_event_id: eventId,
            p_payment_id: paymentId,
            p_livemode: env.livemode
          })
        }
      );

      // Konflikt moze znamenat, ze platba uz bola
      // spracovana. Overime skutocny zaznam.
      if (!credit.ok && credit.status !== 409) {
        throw new Error(
          `Pripísanie kreditu zlyhalo: ${credit.status} ${await credit.text()}`
        );
      }

      payments = await getPayments(
        env.url,
        env.key,
        paymentId
      );
    }

    const validPayment = payments.some(p =>
      Number(p.firma_id) === firmaId &&
      Number(p.suma) === amount &&
      p.livemode === env.livemode
    );

    if (!validPayment) {
      throw new Error(
        "Platba nie je správne evidovaná; faktúra sa nevytvorila"
      );
    }

    // Vytvorenie faktury je chranene unikatnym
    // Stripe payment ID v databaze.
    const invoice = await supabaseRequest(
      env.url,
      env.key,
      "rpc/vytvor_fakturu",
      {
        method: "POST",
        body: JSON.stringify({
          p_firma_id: firmaId,
          p_event_id: eventId,
          p_payment_id: paymentId,
          p_suma: amount
        })
      }
    );

    if (!invoice.ok) {
      throw new Error(
        `Vytvorenie faktúry zlyhalo: ${invoice.status} ${await invoice.text()}`
      );
    }

    const invoiceId = await invoice.json();

    console.log("Stripe payment and invoice recorded", {
      context: process.env.CONTEXT,
      livemode: env.livemode,
      paymentId,
      invoiceId
    });

    // Testovacie faktury zatial nikdy neposielame.
    // Ostre odosielanie zostava ovladane prepinacom.
    if (
      env.allowInvoiceEmail &&
      process.env.DOPYTAI_ENABLE_INVOICE_EMAIL === "true"
    ) {
      try {
        await dorucFakturu(invoiceId);
      } catch (error) {
        console.error("Invoice delivery failed:", error);
      }
    }

    return response(200, {
      received: true,
      test: !env.livemode
    });

  } catch (error) {
    console.error("Stripe webhook error:", error);

    return response(500, {
      error: "Webhook processing failed"
    });
  }
};
