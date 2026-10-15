
"use strict";

const json = (statusCode, data) => ({
  statusCode,
  headers: {
    "Content-Type": "application/json; charset=utf-8",
    "Cache-Control": "no-store"
  },
  body: JSON.stringify(data)
});

exports.handler = async function (event) {
  if (event.httpMethod !== "POST") {
    return json(405, { error: "Method not allowed" });
  }

  try {
    const stripeKey = process.env.STRIPE_SECRET_KEY;
    const supabaseUrl = (process.env.SUPABASE_URL || "").replace(/\/$/, "");
    const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

    if (!stripeKey || !supabaseUrl || !serviceKey) {
      throw new Error("Chýba konfigurácia platby alebo overenia firmy.");
    }

    const authHeader =
      event.headers?.authorization || event.headers?.Authorization || "";

    const match = /^Bearer\s+(.+)$/i.exec(authHeader);

    if (!match || !match[1]) {
      return json(401, {
        error: "Najprv sa prihláste do firemného účtu."
      });
    }

    const token = match[1].trim();
    const body = JSON.parse(event.body || "{}");
    const amount = Number(body.amount);

    if (![50, 100, 200].includes(amount)) {
      return json(400, { error: "Neplatná suma." });
    }

    // Overenie prihláseného používateľa cez Supabase.
    const userResponse = await fetch(`${supabaseUrl}/auth/v1/user`, {
      headers: {
        apikey: serviceKey,
        Authorization: `Bearer ${token}`
      }
    });

    if (!userResponse.ok) {
  console.error("Supabase auth failed", {
    status: userResponse.status,
    supabaseProject: new URL(supabaseUrl).hostname
  });

  return json(401, {
    error: "Prihlásenie sa nepodarilo overiť."
  });
}

    const user = await userResponse.json();

    if (!user?.id) {
      return json(401, {
        error: "Nepodarilo sa overiť používateľa."
      });
    }

    // ID firmy zisťujeme na serveri.
    const companyResponse = await fetch(
      `${supabaseUrl}/rest/v1/firmy?auth_user_id=eq.${encodeURIComponent(user.id)}&select=id&limit=2`,
      {
        headers: {
          apikey: serviceKey,
          Authorization: `Bearer ${serviceKey}`
        }
      }
    );

    if (!companyResponse.ok) {
      console.error("Supabase company lookup failed", {
  status: companyResponse.status,
  response: (await companyResponse.text()).slice(0, 500)
});
      throw new Error("Overenie firmy v databáze zlyhalo.");
    }

    const companies = await companyResponse.json();

    if (!Array.isArray(companies) || companies.length !== 1) {
      return json(403, {
        error: "K účtu sa nepodarilo jednoznačne priradiť firmu."
      });
    }

    const firmaId = Number(companies[0].id);

    if (!Number.isSafeInteger(firmaId) || firmaId <= 0) {
      return json(403, {
        error: "Neplatný firemný účet."
      });
    }

    const params = new URLSearchParams();

    params.append("metadata[firma_id]", String(firmaId));
    params.append("mode", "payment");
    params.append("payment_method_types[0]", "card");
    params.append("line_items[0][price_data][currency]", "eur");

    params.append(
      "line_items[0][price_data][product_data][name]",
      `DopytAI kredit ${amount} €`
    );

    params.append(
      "line_items[0][price_data][unit_amount]",
      String(amount * 100)
    );

    params.append("line_items[0][quantity]", "1");

    params.append(
      "success_url",
      "https://dopytai24.sk/?payment=success&session_id={CHECKOUT_SESSION_ID}"
    );

    params.append(
      "cancel_url",
      "https://dopytai24.sk/?payment=cancel"
    );

    const response = await fetch(
      "https://api.stripe.com/v1/checkout/sessions",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${stripeKey}`,
          "Content-Type": "application/x-www-form-urlencoded"
        },
        body: params.toString()
      }
    );

    const session = await response.json();

    if (!response.ok || !session.url) {
      console.error(
        "Stripe checkout error",
        response.status,
        session?.error?.type
      );

      return json(502, {
        error: "Platbu sa nepodarilo vytvoriť. Skúste to znova."
      });
    }

    return json(200, { url: session.url });

  } catch (error) {
    console.error("Checkout error:", error);

    return json(500, {
      error: "Platbu sa nepodarilo vytvoriť."
    });
  }
};
