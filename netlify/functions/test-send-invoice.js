"use strict";

const { dorucFakturu } = require("./invoice-delivery");

exports.handler = async function (event) {
  // Tento test sa nesmie spustiť cez bežný prehliadač.
  if (event.httpMethod !== "POST") {
    return {
      statusCode: 405,
      body: "Method not allowed"
    };
  }

  // Kontrola testovacej databázy.
  const testUrl =
    "https://pwtvquyefpucjufvwnxp.supabase.co";

  const actualUrl =
    (process.env.SUPABASE_URL || "").replace(/\/$/, "");

  if (actualUrl !== testUrl) {
    return {
      statusCode: 403,
      body: "Povolena je iba testovacia databaza."
    };
  }

  // Zatial nic neodosielame.
  return {
    statusCode: 200,
    body: JSON.stringify({
      ok: true,
      test: "Pripraveny",
      fakturaId: 8,
      prostredie: process.env.CONTEXT || "nezname",
      emailOdoslany: false
    })
  };
};
