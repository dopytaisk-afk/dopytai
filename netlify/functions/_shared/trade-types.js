"use strict";

// Jeden zoznam typov dopytov pre Netlify notifikacie a fotky.
// Firma moze vidiet/kupit dopyt rovnakeho remesla odkialkolvek zo SR.
// REGION sa vyhodnocuje iba pri EMAILOVYCH notifikaciach.
const ROOF_LEADS = new Set([
  "Nová strecha", "Rekonštrukcia strechy", "Oprava / zatekanie"
]);
const OTHER_TRADES = new Set([
  "Sadrokartón", "Elektroinštalácie", "Vodoinštalácie",
  "Kúrenie", "Klimatizácie", "Murárske práce",
  "Fasády a zateplenie", "Maliarske práce", "Obklady a dlažby",
  "Podlahy", "Okná a dvere", "Tesárske práce",
  "Hydroizolácie", "Zámková dlažba", "Ploty a brány",
  "Zemné práce", "Rekonštrukcie kúpeľní", "Betonárske práce"
]);

function tradeForDemand(value) {
  const type = typeof value === "string" ? value.trim() : "";
  if (ROOF_LEADS.has(type)) return "Strechy";
  return OTHER_TRADES.has(type) ? type : null;
}

function companyMatchesDemand(companyTrade, demandTrade) {
  const required = tradeForDemand(demandTrade);
  return required !== null &&
    typeof companyTrade === "string" &&
    companyTrade.trim() === required;
}

module.exports = { tradeForDemand, companyMatchesDemand };
