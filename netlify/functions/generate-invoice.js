
const fs = require("node:fs");
const path = require("node:path");
const { PDFDocument, rgb } = require("pdf-lib");
const fontkit = require("@pdf-lib/fontkit");

const DODAVATEL = {
  nazov: "Miroslav Chovanec",
  ulica: "Biela 44",
  mesto: "027 05 Zázrivá",
  ico: "55830846",
  dic: "1120943296",
};

function peniaze(suma) {
  return Number(suma).toLocaleString("sk-SK", {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }) + " €";
}

function datum(hodnota) {
  const d = new Date(hodnota);
  if (Number.isNaN(d.getTime())) {
    throw new Error("Neplatný dátum faktúry");
  }
  return new Intl.DateTimeFormat("sk-SK", {
    timeZone: "Europe/Bratislava",
  }).format(d);
}

async function vytvorPdfFaktury(faktura) {
  if (!faktura || typeof faktura !== "object") {
    throw new Error("Chýbajú údaje faktúry");
  }

  const suma = Number(faktura.suma);
  if (!Number.isFinite(suma) || suma <= 0) {
    throw new Error("Neplatná suma faktúry");
  }

  if (!faktura.cislo || !faktura.odberatel_nazov) {
    throw new Error("Chýba číslo faktúry alebo odberateľ");
  }

  const pdf = await PDFDocument.create();
  pdf.registerFontkit(fontkit);

  const fontPath = path.join(__dirname, "Roboto-Regular.ttf");
  const fontBytes = fs.readFileSync(fontPath);
  const font = await pdf.embedFont(fontBytes, { subset: true });

  const page = pdf.addPage([595.28, 841.89]);
  const blue = rgb(0.10, 0.33, 0.75);
  const dark = rgb(0.13, 0.18, 0.25);
  const gray = rgb(0.40, 0.45, 0.52);
  const light = rgb(0.94, 0.97, 1);

  function text(hodnota, x, y, size = 10, color = dark) {
    page.drawText(String(hodnota ?? ""), {
      x, y, size, font, color,
      maxWidth: 495,
    });
  }

  function line(y) {
    page.drawLine({
      start: { x: 45, y },
      end: { x: 550, y },
      thickness: 0.7,
      color: rgb(0.85, 0.88, 0.92),
    });
  }

  // Hlavička
  text("DopytAI", 45, 780, 26, blue);
  text("FAKTÚRA", 430, 780, 18, dark);
  text(`Číslo: ${faktura.cislo}`, 370, 758, 10);
  line(740);

  // Dodávateľ
  text("DODÁVATEĽ", 45, 710, 11, blue);
  text(DODAVATEL.nazov, 45, 687, 12);
  text(DODAVATEL.ulica, 45, 670);
  text(DODAVATEL.mesto, 45, 653);
  text(`IČO: ${DODAVATEL.ico}`, 45, 636);
  text(`DIČ: ${DODAVATEL.dic}`, 45, 619);
  text("Nie je platiteľ DPH", 45, 602);

  // Odberateľ
  text("ODBERATEĽ", 310, 710, 11, blue);
  text(faktura.odberatel_nazov, 310, 687, 12);
  text(faktura.odberatel_ulica || "", 310, 670);
  text(
    `${faktura.odberatel_psc || ""} ${faktura.odberatel_mesto || ""}`,
    310, 653
  );
  text(`IČO: ${faktura.odberatel_ico || "—"}`, 310, 636);
  text(`DIČ: ${faktura.odberatel_dic || "—"}`, 310, 619);
  text(faktura.odberatel_email || "", 310, 602, 9);

  line(580);

  // Dátumy a platba
  text("Dátum vystavenia:", 45, 551);
  text(datum(faktura.datum_vystavenia), 180, 551);

  text("Dátum dodania:", 45, 532);
  text(datum(faktura.datum_dodania), 180, 532);

  text("Spôsob úhrady:", 310, 551);
  text("Platobná karta – Stripe", 410, 551, 9);

  text("Stav:", 310, 532);
  text("UHRADENÉ", 410, 532, 10, blue);

  // Položka
  page.drawRectangle({
    x: 45, y: 457, width: 505, height: 40,
    color: light,
  });

  text("Popis položky", 55, 472, 10, blue);
  text("Suma", 490, 472, 10, blue);

  text(
    faktura.popis ||
      "Predplatený kredit na sprístupnenie stavebných dopytov",
    55, 432, 9
  );
  text(peniaze(suma), 475, 409, 11);

  line(391);

  // Súhrn
  text("Celková suma:", 315, 358, 12);
  text(peniaze(suma), 470, 358, 12, blue);

  text("Uhradené:", 315, 332, 10);
  text(peniaze(suma), 470, 332, 10);

  text("Zostáva uhradiť:", 315, 306, 10);
  text("0,00 €", 470, 306, 11, blue);

  line(275);

  text(
    "Platba bola prijatá prostredníctvom platobnej brány Stripe.",
    45, 246, 9, gray
  );

  text(
    "Ďakujeme, že využívate DopytAI.",
    45, 100, 11, blue
  );

  return Buffer.from(await pdf.save());
}

// Bezpečnostná poistka:
// Verejná URL zatiaľ NESMIE vytvárať faktúry.
exports.handler = async function (event) {
  if (event.httpMethod !== "POST") {
    return {
      statusCode: 405,
      body: "Method not allowed",
    };
  }

  return {
    statusCode: 403,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
    },
    body: JSON.stringify({
      error: "Vystavovanie faktúr zatiaľ nie je aktivované.",
    }),
  };
};

exports.vytvorPdfFaktury = vytvorPdfFaktury;
