
const { PDFDocument, StandardFonts, rgb } = require("pdf-lib");

exports.handler = async function (event) {
  // Zatiaľ nedovolíme verejne spúšťať vystavovanie faktúr.
  // Funkciu neskôr bezpečne prepojíme so Stripe webhookom.
  if (event.httpMethod !== "POST") {
    return {
      statusCode: 405,
      body: "Method not allowed",
    };
  }

  return {
    statusCode: 403,
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      error: "Generovanie faktúr zatiaľ nie je aktivované.",
    }),
  };
};

// Pomocná funkcia na vytvorenie PDF.
// Zatiaľ nie je dostupná cez verejnú URL.
async function vytvorPdfFaktury() {
  const pdf = await PDFDocument.create();
  const strana = pdf.addPage([595, 842]);
  const font = await pdf.embedFont(StandardFonts.Helvetica);

  strana.drawText("DopytAI - faktura", {
    x: 50,
    y: 780,
    size: 22,
    font,
    color: rgb(0.1, 0.3, 0.7),
  });

  return Buffer.from(await pdf.save());
}

module.exports.vytvorPdfFaktury = vytvorPdfFaktury;
