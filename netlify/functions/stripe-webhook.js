exports.handler = async function (event) {
  if (event.httpMethod !== "POST") {
    return {
      statusCode: 405,
      body: "Method not allowed"
    };
  }

  try {
    const stripeEvent = JSON.parse(event.body || "{}");

    if (stripeEvent.type === "checkout.session.completed") {
      const session = stripeEvent.data?.object;

      console.log("Stripe Checkout completed:", {
        id: session?.id,
        amount_total: session?.amount_total,
        currency: session?.currency,
        payment_status: session?.payment_status
      });
    }

    return {
      statusCode: 200,
      body: JSON.stringify({ received: true })
    };

  } catch (error) {
    console.error("Stripe webhook error:", error);

    return {
      statusCode: 400,
      body: JSON.stringify({ error: "Invalid webhook payload" })
    };
  }
};
