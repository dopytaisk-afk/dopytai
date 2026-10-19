"use strict";

const fs = require("node:fs");
const path = require("node:path");
const { PDFDocument, rgb } = require("pdf-lib");
const fontkit = require("@pdf-lib/fontkit");

// Údaje dodávateľa zachované z pôvodnej testovacej faktúry.
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
  const font = await pdf.embedFont(
    fs.readFileSync(fontPath),
    { subset: true }
  );

  const page = pdf.addPage([595.28, 841.89]);

  const blue = rgb(0.10, 0.33, 0.75);
  const dark = rgb(0.13, 0.18, 0.25);
  const gray = rgb(0.40, 0.45, 0.52);
  const light = rgb(0.94, 0.97, 1);
  const border = rgb(0.85, 0.88, 0.92);
  const white = rgb(1, 1, 1);

  const measure = (value, size) =>
    font.widthOfTextAtSize(String(value ?? ""), size);

  function text(value, x, y, size = 10, color = dark) {
    page.drawText(String(value ?? ""), {
      x,
      y,
      size,
      font,
      color,
    });
  }

  function rightText(value, right, y, size = 10, color = dark) {
    const s = String(value ?? "");
    text(s, right - measure(s, size), y, size, color);
  }

  // Automatické zalamovanie textu podľa skutočnej šírky písma.
  function wrap(value, maxWidth, size) {
    const words = String(value ?? "")
      .replace(/\s+/g, " ")
      .trim()
      .split(" ")
      .filter(Boolean);

    const lines = [];
    let current = "";

    for (const word of words) {
      const candidate = current
        ? current + " " + word
        : word;

      if (measure(candidate, size) <= maxWidth) {
        current = candidate;
        continue;
      }

      if (current) {
        lines.push(current);
      }

      current = "";

      for (const char of word) {
        if (
          measure(current + char, size) > maxWidth &&
          current
        ) {
          lines.push(current);
          current = char;
        } else {
          current += char;
        }
      }
    }

    if (current) {
      lines.push(current);
    }

    return lines.length ? lines : [""];
  }

  function fittedLines(value, x, y, width, opts = {}) {
    const size = opts.size ?? 10;
    const leading = opts.leading ?? 15;
    const color = opts.color ?? dark;
    const maxLines = opts.maxLines ?? 3;

    const lines = wrap(value, width, size);

    if (lines.length > maxLines) {
      // Dlhý údaj nesmie prekryť ďalšiu sekciu faktúry.
      throw new Error(
        "Príliš dlhý údaj na faktúre: " +
        String(value).slice(0, 60)
      );
    }

    lines.forEach((line, i) => {
      text(line, x, y - i * leading, size, color);
    });
  }

  function line(y) {
    page.drawLine({
      start: { x: 45, y },
      end: { x: 550, y },
      thickness: 0.7,
      color: border,
    });
  }

  // HLAVIČKA
  text("DopytAI", 45, 779, 26, blue);

  rightText("FAKTÚRA", 550, 784, 18);

  rightText(
    `Číslo: ${faktura.cislo}`,
    550,
    760,
    9,
    gray
  );

  line(739);

  // DODÁVATEĽ
  text("DODÁVATEĽ", 45, 710, 11, blue);

  fittedLines(DODAVATEL.nazov, 45, 687, 220, {
    size: 11,
    maxLines: 1,
  });

  text(DODAVATEL.ulica, 45, 669);
  text(DODAVATEL.mesto, 45, 652);
  text(`IČO: ${DODAVATEL.ico}`, 45, 635);
  text(`DIČ: ${DODAVATEL.dic}`, 45, 618);
  text("Nie je platiteľ DPH", 45, 601, 9, gray);

  // ODBERATEĽ
  text("ODBERATEĽ", 310, 710, 11, blue);

  fittedLines(
    faktura.odberatel_nazov,
    310,
    687,
    238,
    {
      size: 10,
      leading: 13,
      maxLines: 2,
    }
  );

  fittedLines(
    faktura.odberatel_ulica || "",
    310,
    656,
    238,
    {
      size: 9,
      maxLines: 1,
    }
  );

  fittedLines(
    `${faktura.odberatel_psc || ""} ${faktura.odberatel_mesto || ""}`,
    310,
    640,
    238,
    {
      size: 9,
      maxLines: 1,
    }
  );

  text(
    `IČO: ${faktura.odberatel_ico || "—"}`,
    310,
    624,
    9
  );

  text(
    `DIČ: ${faktura.odberatel_dic || "—"}`,
    310,
    608,
    9
  );

  fittedLines(
    faktura.odberatel_email || "",
    310,
    590,
    238,
    {
      size: 8,
      maxLines: 1,
      color: gray,
    }
  );

  line(570);

  // PLATOBNÉ INFORMÁCIE
  text("Dátum vystavenia", 45, 540, 9, gray);
  text(datum(faktura.datum_vystavenia), 45, 521, 11);

  text("Dátum dodania", 190, 540, 9, gray);
  text(datum(faktura.datum_dodania), 190, 521, 11);

  text("Spôsob úhrady", 335, 540, 9, gray);
  text("Platobná karta – Stripe", 335, 521, 10);

  // TABUĽKA POLOŽIEK
  page.drawRectangle({
    x: 45,
    y: 472,
    width: 505,
    height: 30,
    color: light,
  });

  text("POLOŽKA", 57, 483, 9, blue);
  rightText("SUMA", 537, 483, 9, blue);

  const popis =
    faktura.popis ||
    "Predplatený kredit na sprístupnenie stavebných dopytov";

  fittedLines(popis, 57, 448, 362, {
    size: 10,
    leading: 15,
    maxLines: 4,
  });

  rightText(peniaze(suma), 537, 448, 11);

  line(378);

  // SÚHRN PLATIEB
  text("Celková suma", 315, 347, 11);

  rightText(
    peniaze(suma),
    537,
    347,
    13,
    blue
  );

  text("Uhradené", 315, 319, 10);

  rightText(
    peniaze(suma),
    537,
    319,
    10
  );

  line(302);

  text("Zostáva uhradiť", 315, 282, 11);

  rightText(
    "0,00 €",
    537,
    282,
    12,
    blue
  );

  // OZNAČENIE UHRADENÉ
  page.drawRectangle({
    x: 45,
    y: 274,
    width: 130,
    height: 31,
    color: blue,
  });

  text("UHRADENÉ", 66, 284, 11, white);

  line(251);

  fittedLines(
    "Platba bola prijatá prostredníctvom platobnej brány Stripe.",
    45,
    225,
    505,
    {
      size: 9,
      color: gray,
      maxLines: 2,
    }
  );

  // PÄTIČKA
  line(127);

  text(
    "Ďakujeme, že využívate DopytAI.",
    45,
    100,
    11,
    blue
  );

  return Buffer.from(await pdf.save());
}

// BEZPEČNOSTNÁ POISTKA
// Verejná URL nesmie vytvárať faktúry.
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
