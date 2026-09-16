const crypto = require("crypto");

exports.handler = async function (event) {
  if (event.httpMethod !== "POST") {
    return {
      statusCode: 405,
      body: "Method not allowed"
    };
  }

  try {
    const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;

    if (!webhookSecret) {
      throw new Error("STRIPE_WEBHOOK_SECRET nie je nastavený.");
    }

    const signature = event.headers["stripe-signature"];

    if (!signature) {
      return {
        statusCode: 400,
        body: "Missing Stripe signature"
      };
    }

    const parts = signature.split(",");
    const timestampPart = parts.find(p => p.startsWith("t="));
    const signatureParts = parts.filter(p => p.startsWith("v1="));

    if (!timestampPart || signatureParts.length === 0) {
      return {
        statusCode: 400,
        body: "Invalid Stripe signature"
      };
    }

    const timestamp = timestampPart.substring(2);
    const payload = event.body || "";
    const signedPayload = `${timestamp}.${payload}`;

    const expectedSignature = crypto
      .createHmac("sha256", webhookSecret)
      .update(signedPayload, "utf8")
      .digest("hex");

    const verified = signatureParts.some(part => {
      const receivedSignature = part.substring(3);

      if (receivedSignature.length !== expectedSignature.length) {
        return false;
      }

      return crypto.timingSafeEqual(
        Buffer.from(receivedSignature, "hex"),
        Buffer.from(expectedSignature, "hex")
      );
    });

    if (!verified) {
      return {
        statusCode: 400,
        body: "Invalid Stripe signature"
      };
    }

    const stripeEvent = JSON.parse(payload);

    if (stripeEvent.type === "checkout.session.completed") {
      const session = stripeEvent.data.object;

      console.log("Stripe Checkout completed:", {
        id: session.id,
        amount_total: session.amount_total,
        currency: session.currency,
        payment_status: session.payment_status
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
      body: JSON.stringify({ error: "Invalid webhook request" })
    };
  }
};
