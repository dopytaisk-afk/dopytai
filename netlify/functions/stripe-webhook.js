
const crypto = require("crypto");
const { dorucFakturu } = require("./invoice-delivery");

// Presné adresy databáz.
// Nikdy nesmie dôjsť k zámene testovacej a ostrej platby.
const LIVE_SUPABASE_URL =
  "https://unwoolvttaljwbkgwmuy.supabase.co";

const TEST_SUPABASE_URL =
  "https://pwtvquyefpucjufvwnxp.supabase.co";

const jsonHeaders = (key) => ({
  apikey: key,
  Authorization: `Bearer ${key}`,
  "Content-Type": "application/json"
});

async function supabaseRequest(url, key, path, options = {}) {
  return fetch(
    `${url.replace(/\/$/, "")}/rest/v1/${path}`,
    {
      ...options,
      headers: {
        ...jsonHeaders(key),
        ...(options.headers || {})
      }
    }
  );
}

exports.handler = async function (event) {
  if (event.httpMethod !== "POST") {
    return {
      statusCode: 405,
      body: "Method not allowed"
    };
  }

  try {
    // 1. Overenie podpisu Stripe webhooku.
    const secret = process.env.STRIPE_WEBHOOK_SECRET;

    if (!secret) {
      throw new Error(
        "STRIPE_WEBHOOK_SECRET nie je nastavený"
      );
    }

    const signature =
      event.headers?.["stripe-signature"] ||
      event.headers?.["Stripe-Signature"];

    if (!signature) {
      return {
        statusCode: 400,
        body: "Missing Stripe signature"
      };
    }

    const entries = signature
      .split(",")
      .map((s) => s.trim());

    const timestamp = entries
      .find((s) => s.startsWith("t="))
      ?.slice(2);

    const signatures = entries
      .filter((s) => s.startsWith("v1="))
      .map((s) => s.slice(3));

    if (
      !timestamp ||
      !signatures.length ||
      !/^\d+$/.test(timestamp)
    ) {
      return {
        statusCode: 400,
        body: "Invalid Stripe signature"
      };
    }

    if (
      Math.abs(Date.now() / 1000 - Number(timestamp)) > 300
    ) {
      return {
        statusCode: 400,
        body: "Expired Stripe signature"
      };
    }

    const payload = event.isBase64Encoded
      ? Buffer.from(
          event.body || "",
          "base64"
        ).toString("utf8")
      : event.body || "";

    const expected = crypto
      .createHmac("sha256", secret)
      .update(`${timestamp}.${payload}`, "utf8")
      .digest("hex");

    const verified = signatures.some((sig) => {
      if (!/^[0-9a-f]{64}$/i.test(sig)) {
        return false;
      }

      return crypto.timingSafeEqual(
        Buffer.from(sig, "hex"),
        Buffer.from(expected, "hex")
      );
    });

    if (!verified) {
      return {
        statusCode: 400,
        body: "Invalid Stripe signature"
      };
    }

    // 2. Spracujeme iba úspešne dokončený Checkout.
    const stripeEvent = JSON.parse(payload);

    if (stripeEvent.type !== "checkout.session.completed") {
      return {
        statusCode: 200,
        body: JSON.stringify({
          received: true
        })
      };
    }

    // 3. Bezpečnostné oddelenie LIVE a TEST.
    const url = (
      process.env.SUPABASE_URL || ""
    ).replace(/\/$/, "");

    const key =
      process.env.SUPABASE_SERVICE_ROLE_KEY;

    if (!url || !key) {
      throw new Error(
        "Supabase nie je nastavený"
      );
    }

    const isLiveDatabase =
      url === LIVE_SUPABASE_URL;

    const isTestDatabase =
      url === TEST_SUPABASE_URL;

    if (!isLiveDatabase && !isTestDatabase) {
      throw new Error(
        "Neznáma Supabase databáza. Platba bola zablokovaná."
      );
    }

    // Ostrá databáza prijíma iba ostré platby.
    // Testovacia databáza prijíma iba testovacie platby.
    if (
      (isLiveDatabase && stripeEvent.livemode !== true) ||
      (isTestDatabase && stripeEvent.livemode !== false)
    ) {
      console.error(
        "BLOKOVANÁ PLATBA: nesúlad Stripe režimu a databázy",
        {
          eventId: stripeEvent.id,
          livemode: stripeEvent.livemode,
          databaseMode: isLiveDatabase
            ? "LIVE"
            : "TEST"
        }
      );

      return {
        statusCode: 400,
        body: JSON.stringify({
          error: "Stripe režim nezodpovedá databáze"
        })
      };
    }

    const session = stripeEvent.data?.object;

    // 4. Overenie platby.
    if (session?.payment_status !== "paid") {
      throw new Error(
        "Stripe platba nie je zaplatená"
      );
    }

    if (
      session.currency?.toLowerCase() !== "eur"
    ) {
      throw new Error(
        "Neplatná mena platby"
      );
    }

    const firmaId = Number(
      session.metadata?.firma_id
    );

    const amount =
      Number(session.amount_total) / 100;

    const eventId = stripeEvent.id;

    const paymentId =
      session.payment_intent || session.id;

    if (
      !Number.isSafeInteger(firmaId) ||
      firmaId <= 0 ||
      ![50, 100, 200].includes(amount) ||
      !paymentId ||
      typeof paymentId !== "string"
    ) {
      throw new Error(
        "Neplatné údaje Stripe platby"
      );
    }

    // 5. Skontrolujeme, či platba už existuje.
    const paymentPath =
      "stripe_platby?payment_id=eq." +
      encodeURIComponent(paymentId) +
      "&select=firma_id,suma,livemode";

    const check = await supabaseRequest(
      url,
      key,
      paymentPath
    );

    if (!check.ok) {
      throw new Error(
        `Kontrola platby zlyhala: ${check.status} ${await check.text()}`
      );
    }

    let payments = await check.json();

    // 6. Pripísanie kreditu.
    if (payments.length === 0) {
      const credit = await supabaseRequest(
        url,
        key,
        "rpc/pripis_kredit",
        {
          method: "POST",
          body: JSON.stringify({
            p_firma_id: firmaId,
            p_suma: amount,
            p_event_id: eventId,
            p_payment_id: paymentId,
            p_livemode: stripeEvent.livemode
          })
        }
      );

      if (
        !credit.ok &&
        credit.status !== 409
      ) {
        throw new Error(
          `Pripísanie kreditu zlyhalo: ${credit.status} ${await credit.text()}`
        );
      }

      // Overíme, že platba bola naozaj zapísaná.
      const verify = await supabaseRequest(
        url,
        key,
        paymentPath
      );

      if (!verify.ok) {
        throw new Error(
          `Overenie kreditu zlyhalo: ${verify.status}`
        );
      }

      payments = await verify.json();
    }

    // 7. Overíme firmu, sumu a režim platby.
    const validPayment = payments.some(
      (p) =>
        Number(p.firma_id) === firmaId &&
        Number(p.suma) === amount &&
        p.livemode === stripeEvent.livemode
    );

    if (!validPayment) {
      throw new Error(
        "Platba nie je správne evidovaná; faktúra sa nevytvorila"
      );
    }

    // 8. Vytvorenie faktúry.
    // SQL funkcia musí zabezpečiť, aby nevznikla duplicita.
    const invoice = await supabaseRequest(
      url,
      key,
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

    console.log(
      "Stripe payment and invoice recorded",
      {
        paymentId,
        invoiceId,
        mode: isTestDatabase
          ? "TEST"
          : "LIVE"
      }
    );

    // 9. Odosielanie faktúr.
    // Testovacie faktúry nikdy automaticky neodosielame.
    // V ostrej verzii zostáva potrebný samostatný prepínač.
    if (
      isLiveDatabase &&
      stripeEvent.livemode === true &&
      process.env.DOPYTAI_ENABLE_INVOICE_EMAIL === "true"
    ) {
      try {
        await dorucFakturu(invoiceId);
      } catch (error) {
        console.error(
          "Invoice delivery failed:",
          error
        );
      }
    }

    return {
      statusCode: 200,
      body: JSON.stringify({
        received: true
      })
    };
  } catch (error) {
    console.error(
      "Stripe webhook error:",
      error
    );

    return {
      statusCode: 500,
      body: JSON.stringify({
        error: "Webhook processing failed"
      })
    };
  }
};
