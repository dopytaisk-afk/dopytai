exports.handler = async function (event) {
  if (event.httpMethod !== "POST") {
    return {
      statusCode: 405,
      body: JSON.stringify({ error: "Method not allowed" })
    };
  }

  try {
    const stripeSecretKey = process.env.STRIPE_SECRET_KEY;

    if (!stripeSecretKey) {
      throw new Error("STRIPE_SECRET_KEY nie je nastavený.");
    }

    const body = JSON.parse(event.body || "{}");
    const amount = Number(body.amount);
   const firmaId = Number(body.firma_id); 

    // Povolené balíky kreditu v eurách
    const allowedAmounts = [50, 100, 200];

    if (!allowedAmounts.includes(amount)) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: "Neplatná suma." })
      };
    }
    if (!Number.isInteger(firmaId) || firmaId <= 0) {
  return {
    statusCode: 400,
    body: JSON.stringify({ error: "Neplatná firma." })
  };
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
      "https://sparkly-choux-e2b050.netlify.app/?payment=success"
    );

    params.append(
      "cancel_url",
      "https://sparkly-choux-e2b050.netlify.app/?payment=cancel"
    );

    const response = await fetch(
      "https://api.stripe.com/v1/checkout/sessions",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${stripeSecretKey}`,
          "Content-Type": "application/x-www-form-urlencoded"
        },
        body: params.toString()
      }
    );

    const session = await response.json();

    if (!response.ok) {
      console.error("Stripe error:", session);

      return {
        statusCode: response.status,
        body: JSON.stringify({
          error: session?.error?.message || "Stripe platbu sa nepodarilo vytvoriť."
        })
      };
    }

    return {
      statusCode: 200,
      body: JSON.stringify({
        url: session.url
      })
    };
  } catch (error) {
    console.error("Checkout error:", error);

    return {
      statusCode: 500,
      body: JSON.stringify({
        error: "Platbu sa nepodarilo vytvoriť."
      })
    };
  }
};
