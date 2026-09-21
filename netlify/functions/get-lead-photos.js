exports.handler = async function (event) {
  if (event.httpMethod !== "POST") {
    return {
      statusCode: 405,
      body: JSON.stringify({ error: "Method not allowed" })
    };
  }

  try {
    const supabaseUrl = process.env.SUPABASE_URL;
    const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error("Supabase nie je nastaveny.");
    }

    const body = JSON.parse(event.body || "{}");
    const firmaId = Number(body.firma_id);
    const dopytId = Number(body.dopyt_id);

    if (
      !Number.isInteger(firmaId) ||
      firmaId <= 0 ||
      !Number.isInteger(dopytId) ||
      dopytId <= 0
    ) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: "Neplatne udaje." })
      };
    }

    // Overíme, že firma má tento dopyt skutočne odomknutý
    const unlockResponse = await fetch(
      `${supabaseUrl}/rest/v1/odomknute_dopyty?firma_id=eq.${firmaId}&dopyt_id=eq.${dopytId}&select=dopyt_id`,
      {
        headers: {
          apikey: supabaseServiceKey,
          Authorization: `Bearer ${supabaseServiceKey}`
        }
      }
    );

    if (!unlockResponse.ok) {
      throw new Error("Nepodarilo sa overit zakupenie dopytu.");
    }

    const unlocked = await unlockResponse.json();

    if (!Array.isArray(unlocked) || unlocked.length === 0) {
      return {
        statusCode: 403,
        body: JSON.stringify({ error: "Firma nema tento dopyt odomknuty." })
      };
    }

    // Získame cesty fotografií uložené pri dopyte
    const leadResponse = await fetch(
      `${supabaseUrl}/rest/v1/dopyty?id=eq.${dopytId}&select=fotky`,
      {
        headers: {
          apikey: supabaseServiceKey,
          Authorization: `Bearer ${supabaseServiceKey}`
        }
      }
    );

    if (!leadResponse.ok) {
      throw new Error("Nepodarilo sa nacitat fotografie.");
    }

    const leads = await leadResponse.json();
    const photos =
      Array.isArray(leads) &&
      leads.length > 0 &&
      Array.isArray(leads[0].fotky)
        ? leads[0].fotky
        : [];

    const signedPhotos = [];

    // Pre každú fotku vytvoríme dočasný odkaz platný 10 minút
    for (const path of photos) {
      const signedResponse = await fetch(
        `${supabaseUrl}/storage/v1/object/sign/dopyt-fotky/${encodeURIComponent(path).replace(/%2F/g, "/")}`,
        {
          method: "POST",
          headers: {
            apikey: supabaseServiceKey,
            Authorization: `Bearer ${supabaseServiceKey}`,
            "Content-Type": "application/json"
          },
          body: JSON.stringify({
            expiresIn: 600
          })
        }
      );

      if (!signedResponse.ok) {
        throw new Error("Nepodarilo sa vytvorit odkaz na fotografiu.");
      }

      const signed = await signedResponse.json();

      if (signed.signedURL) {
        const url = signed.signedURL.startsWith("http")
          ? signed.signedURL
          : `${supabaseUrl}/storage/v1${signed.signedURL}`;

        signedPhotos.push(url);
      }
    }

    return {
      statusCode: 200,
      headers: {
        "Content-Type": "application/json",
        "Cache-Control": "no-store"
      },
      body: JSON.stringify({
        photos: signedPhotos
      })
    };

  } catch (error) {
    console.error("get-lead-photos:", error);

    return {
      statusCode: 500,
      body: JSON.stringify({
        error: "Fotografie sa nepodarilo nacitat."
      })
    };
  }
};
