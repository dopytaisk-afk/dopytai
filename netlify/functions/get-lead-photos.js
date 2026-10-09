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
    const authHeader = event.headers.authorization || event.headers.Authorization || "";
const token = authHeader.replace(/^Bearer\s+/i, "").trim();

if (!token) {
  return {
    statusCode: 401,
    body: JSON.stringify({ error: "Firma nie je prihlásená." })
  };
}

const userResponse = await fetch(`${supabaseUrl}/auth/v1/user`, {
  headers: {
    apikey: supabaseServiceKey,
    Authorization: `Bearer ${token}`
  }
});

if (!userResponse.ok) {
  return {
    statusCode: 401,
    body: JSON.stringify({ error: "Neplatné alebo vypršané prihlásenie." })
  };
}

const user = await userResponse.json();
    const firmaId = Number(body.firma_id);
    const dopytId = Number(body.dopyt_id);
const companyResponse = await fetch(
  `${supabaseUrl}/rest/v1/firmy?id=eq.${firmaId}&auth_user_id=eq.${encodeURIComponent(user.id)}&select=id,region,stav,typ_prace`,
    headers: {
      apikey: supabaseServiceKey,
      Authorization: `Bearer ${supabaseServiceKey}`
    }
  }
);

if (!companyResponse.ok) {
  throw new Error("Nepodarilo sa overit firmu.");
}

const companies = await companyResponse.json();

if (!Array.isArray(companies) || companies.length !== 1) {
  return {
    statusCode: 403,
    body: JSON.stringify({ error: "Nemate pristup k tejto firme." })
  };
}
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

   

    // Získame cesty fotografií uložené pri dopyte
    const leadResponse = await fetch(
    `${supabaseUrl}/rest/v1/dopyty?id=eq.${dopytId}&select=id,fotky,stav,region`,
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
    if (!Array.isArray(leads) || leads.length !== 1) {
  return {
    statusCode: 404,
    body: JSON.stringify({ error: "Dopyt neexistuje." })
  };
}

const company = companies[0];
const lead = leads[0];

if (company.stav !== "aktivna") {
  return {
    statusCode: 403,
    body: JSON.stringify({ error: "Firma nie je aktivna." })
  };
}
const unlockResponse = await fetch(
  `${supabaseUrl}/rest/v1/odomknute_dopyty?dopyt_id=eq.${dopytId}&select=firma_id`,
  {
    headers: {
      apikey: supabaseServiceKey,
      Authorization: `Bearer ${supabaseServiceKey}`
    }
  }
);

if (!unlockResponse.ok) {
  throw new Error("Nepodarilo sa overit pristup k dopytu.");
}

const unlocks = await unlockResponse.json();

const purchasedByCompany = unlocks.some(
  item => Number(item.firma_id) === firmaId
);

const availableToBuy =
  lead.stav === "novy" &&
  unlocks.length === 0 &&
  lead.region &&
  company.region &&
  lead.region.trim().toLowerCase() === company.region.trim().toLowerCase();

if (!purchasedByCompany && !availableToBuy) {
  return {
    statusCode: 403,
    body: JSON.stringify({
      error: "K fotografiam tohto dopytu nemate pristup."
    })
  };
}
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
