
exports.handler = async () => {
  // DopytAI - GDPR kontrola
  // Tento režim nič nemaže ani neupravuje.

  const supabaseUrl = process.env.SUPABASE_URL;
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

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
