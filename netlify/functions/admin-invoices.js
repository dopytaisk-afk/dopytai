"use strict";

const ADMIN_IDS = {
  "https://pwtvquyefpucjufvwnxp.supabase.co":
    "a0a78a0f-7427-45b0-96a3-fecd0c9c331e",

  "https://unwoolvttaljwbkgwmuy.supabase.co":
    "e09de937-a475-4dd8-b494-bf9345ae8de4"
};

const json = (statusCode, data) => ({
  statusCode,
  headers: {
    "Content-Type": "application/json; charset=utf-8",
    "Cache-Control": "no-store"
  },
  body: JSON.stringify(data)
});

exports.handler = async (event) => {
  if (event.httpMethod !== "GET") {
    return json(405, { error: "Nepovolená metóda." });
  }

  try {
    const url = (process.env.SUPABASE_URL || "").replace(/\/$/, "");
    const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
    const adminId = ADMIN_IDS[url];

    if (!url || !key || !adminId) {
      return json(500, { error: "Chýba konfigurácia administrácie." });
    }

    const authorization =
      event.headers.authorization || event.headers.Authorization || "";

    const tokenMatch = authorization.match(/^Bearer\s+(.+)$/i);

    if (!tokenMatch) {
      return json(401, { error: "Najskôr sa prihláste ako administrátor." });
    }

    // Supabase overí platnosť prihlasovacieho tokenu.
    const userResponse = await fetch(`${url}/auth/v1/user`, {
      headers: {
        apikey: key,
        Authorization: `Bearer ${tokenMatch[1]}`
      }
    });

    if (!userResponse.ok) {
      return json(401, { error: "Prihlásenie je neplatné alebo vypršalo." });
    }

    const user = await userResponse.json();

    // Porovnávame overené ID používateľa, nie e-mail z prehliadača.
    if (!user.id || user.id !== adminId) {
      return json(403, { error: "Nemáte oprávnenie na faktúry." });
    }

    const headers = {
      apikey: key,
      Authorization: `Bearer ${key}`
    };

    const invoiceId = event.queryStringParameters?.id;

    // Stiahnutie konkrétneho PDF.
    if (invoiceId !== undefined) {
      const id = Number(invoiceId);

      if (!Number.isSafeInteger(id) || id <= 0) {
        return json(400, { error: "Neplatné ID faktúry." });
      }

      const invoiceResponse = await fetch(
        `${url}/rest/v1/faktury?id=eq.${id}` +
        `&select=id,cislo_faktury,pdf_cesta&limit=1`,
        { headers }
      );

      if (!invoiceResponse.ok) {
        throw new Error("Nepodarilo sa vyhľadať faktúru.");
      }

      const invoices = await invoiceResponse.json();
      const invoice = invoices[0];

      if (!invoice) {
        return json(404, { error: "Faktúra neexistuje." });
      }

      if (!invoice.pdf_cesta) {
        return json(404, {
          error: "PDF tejto faktúry zatiaľ nie je dostupné."
        });
      }

      const path = String(invoice.pdf_cesta);

      // PDF musí patriť k požadovanej faktúre.
      if (
        !path.startsWith(`${id}/`) ||
        !path.endsWith(".pdf") ||
        path.includes("..") ||
        path.includes("\\")
      ) {
        return json(500, { error: "Neplatná cesta k PDF." });
      }

      const storagePath = path
        .split("/")
        .map(encodeURIComponent)
        .join("/");

      const pdfResponse = await fetch(
        `${url}/storage/v1/object/faktury/${storagePath}`,
        { headers }
      );

      if (!pdfResponse.ok) {
        return json(404, { error: "PDF sa nepodarilo načítať." });
      }

      const pdf = Buffer.from(await pdfResponse.arrayBuffer());

      const fileName = `DopytAI-faktura-${id}.pdf`;

      return {
        statusCode: 200,
        isBase64Encoded: true,
        headers: {
          "Content-Type": "application/pdf",
          "Content-Disposition": `attachment; filename="${fileName}"`,
          "Cache-Control": "no-store",
          "X-Content-Type-Options": "nosniff"
        },
        body: pdf.toString("base64")
      };
    }

    // Zoznam vystavených faktúr.
    const listResponse = await fetch(
      `${url}/rest/v1/faktury?` +
      `select=id,cislo_faktury,odberatel_nazov,suma,mena,` +
      `datum_vystavenia,stav,pdf_cesta,odoslane_at` +
      `&order=id.desc&limit=200`,
      { headers }
    );

    if (!listResponse.ok) {
      throw new Error("Nepodarilo sa načítať zoznam faktúr.");
    }

    const invoices = await listResponse.json();

    return json(200, {
      invoices: invoices.map(invoice => ({
        id: invoice.id,
        cislo_faktury: invoice.cislo_faktury,
        odberatel_nazov: invoice.odberatel_nazov,
        suma: invoice.suma,
        mena: invoice.mena,
        datum_vystavenia: invoice.datum_vystavenia,
        stav: invoice.stav,
        odoslane_at: invoice.odoslane_at,
        has_pdf: Boolean(invoice.pdf_cesta)
      }))
    });

  } catch (error) {
    console.error("Admin invoices:", error.message);

    return json(500, {
      error: "Nepodarilo sa spracovať požiadavku na faktúry."
    });
  }
};
