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
      if (session.payment_status !== "paid") {
  throw new Error("Stripe platba nie je zaplatena.");
}
     const firmaId = Number(session.metadata?.firma_id);
     const amount = Number(session.amount_total) / 100;
      if (!Number.isInteger(firmaId) || firmaId <= 0 || ![50, 100, 200].includes(amount)) {
  throw new Error("Neplatné údaje Stripe platby.");
}
      const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

      if (!supabaseUrl || !supabaseServiceKey) {
  throw new Error("Supabase nie je nastaveny.");
}
const eventId = stripeEvent.id;
const paymentId = session.payment_intent || session.id;      
 const checkResponse = await fetch(  
`${supabaseUrl}/rest/v1/stripe_platby?event_id=eq.${encodeURIComponent(eventId)}&select=event_id`,
   {
    headers: {
      "apikey": supabaseServiceKey,
      "Authorization": `Bearer ${supabaseServiceKey}`,
      "Content-Type": "application/json"
    },
   }
   ):
      if (!checkResponse.ok) {
       throw new Error(`Kontrola Stripe platby zlyhala: ${checkResponse.status}`);
      }
    const existing = await checkResponse.json();
      if (existing.length > 0) {
     return { statusCode: 200, body: "Udalosť už bola spracovaná." };
      }
     const response = await fetch(

  `${supabaseUrl}/rest/v1/rpc/pripis_kredit`,
  {
    method: "POST",
    headers: {
      "apikey": supabaseServiceKey,
      "Authorization": `Bearer ${supabaseServiceKey}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      p_firma_id: firmaId,
      p_suma: amount,
      p_event_id: eventId,
      p_payment_id: paymentId
    })
  }
);

if (!response.ok) {
  const text = await response.text();
  throw new Error(`Supabase chyba: ${response.status} ${text}`);
}
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
