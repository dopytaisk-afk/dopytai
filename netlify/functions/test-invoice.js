
const { vytvorPdfFaktury } = require("./generate-invoice");

exports.handler = async function (event) {
  if (event.httpMethod !== "GET") {
    return {
      statusCode: 405,
      body: "Method not allowed",
    };
  }

  try {
    const faktura = {
      cislo: "TEST-2026-0001",
      suma: 50,
      datum_vystavenia: "2026-10-13",
      datum_dodania: "2026-10-13",
      odberatel_nazov: "Test DopytAI",
      odberatel_ulica: "Testovacia 12",
      odberatel_psc: "010 01",
      odberatel_mesto: "Bystrica",
      odberatel_ico: "12345678",
      odberatel_dic: "1234567890",
      odberatel_email: "test@example.com",
      popis: "Predplatený kredit na sprístupnenie stavebných dopytov"
    };

    const pdf = await vytvorPdfFaktury(faktura);

    return {
      statusCode: 200,
      isBase64Encoded: true,
      headers: {
        "Content-Type": "application/pdf",
        "Content-Disposition": 'inline; filename="test-faktura-dopytai.pdf"',
        "Cache-Control": "no-store"
      },
      body: pdf.toString("base64")
    };
  } catch (error) {
    console.error("Chyba testovacej faktúry:", error.message);

    return {
      statusCode: 500,
      body: "Nepodarilo sa vytvoriť testovaciu PDF faktúru."
    };
  }
};
