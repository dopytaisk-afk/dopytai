
exports.handler = async () => {
  // DopytAI - GDPR kontrola
  // Tento režim nič nemaže ani neupravuje.

 
const supabaseUrl = process.env.SUPABASE_URL;
const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const resendKey = process.env.RESEND_API_KEY;


  if (!supabaseUrl || !serviceKey) {
    return {
      statusCode: 500,
      body: JSON.stringify({
        error: "Chýba konfigurácia Supabase."
      })
    };
  }

  
const cutoff = new Date();
cutoff.setUTCFullYear(cutoff.getUTCFullYear() - 1);
cutoff.setUTCDate(cutoff.getUTCDate() + 30);
const dnesJePondelok = new Date().getUTCDay() === 1;


  try {
    const url = new URL(
      supabaseUrl + "/rest/v1/dopyty"
    );

   
url.searchParams.set("select", "id,created_at,stav,fotky");
    url.searchParams.set("created_at", "lt." + cutoff.toISOString());
    url.searchParams.set("anonymizovane_at", "is.null");
 url.searchParams.set("order", "created_at.asc");
    url.searchParams.set("limit", "100");

    const response = await fetch(url.toString(), {
      headers: {
        apikey: serviceKey,
        Authorization: "Bearer " + serviceKey
      }
    });

    if (!response.ok) {
      throw new Error("Kontrola databázy zlyhala.");
    }

    const demands = await response.json();

    // GDPR upozornenie - iba pondelok, bez mazania
    if (dnesJePondelok && demands.length > 0) {
      if (!resendKey) {
        throw new Error("Chýba RESEND_API_KEY");
      }

      const zoznam = demands.map(d =>
        `Dopyt ID ${d.id} | Vytvorený: ${d.created_at}`
      ).join("\n");

      const emailResponse = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${resendKey}`,
          "Content-Type": "application/json"
        },
        body: JSON.stringify({
          from: "DopytAI <info@dopytai24.sk>",
          to: ["info@dopytai24.sk"],
          subject: "DopytAI - GDPR upozornenie na kontrolu údajov",
          text:
            "Nasledujúce dopyty sa blížia ku koncu 12-mesačnej lehoty " +
            "alebo ju už prekročili:\n\n" +
            zoznam +
            "\n\nSkontrolujte ich osobné údaje a fotografie. " +
            "Po ručnom vyčistení vyplňte anonymizovane_at. " +
            "Tento e-mail nič automaticky nemaže."
        })
      });

      if (!emailResponse.ok) {
        throw new Error(`Odoslanie GDPR e-mailu zlyhalo: ${emailResponse.status}`);
      }

      console.log("GDPR upozornenie úspešne odoslané.");
    }

    console.log("GDPR kontrola DopytAI:", {
      hranica: cutoff.toISOString(),
      pocet: demands.length,
     
      dopyty: demands.map(d => d.id)
    });

    return {
      statusCode: 200,
      body: JSON.stringify({
        
rezim: "LEN_KONTROLA",
hranica: cutoff.toISOString(),
pocet: demands.length,
pocet_fotografii: demands.reduce(
  (sum, d) => sum + (Array.isArray(d.fotky) ? d.fotky.length : 0),
  0
),
dopyty: demands.map(d => d.id)

      })
    };

  } catch (error) {
    console.error("GDPR kontrola zlyhala:", error.message);

    return {
      statusCode: 500,
      body: JSON.stringify({
        error: "Nepodarilo sa vykonať GDPR kontrolu."
      })
    };
  }
};
