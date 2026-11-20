"use strict";
// Spustenie lokalne: node tests/trade-routing.test.js
const assert = require("node:assert/strict");
const { tradeForDemand, companyMatchesDemand } = require("../netlify/functions/_shared/trade-types");

const trades = [
  "Sadrokartón", "Elektroinštalácie", "Vodoinštalácie", "Kúrenie",
  "Klimatizácie", "Murárske práce", "Fasády a zateplenie",
  "Maliarske práce", "Obklady a dlažby", "Podlahy",
  "Okná a dvere", "Tesárske práce", "Hydroizolácie",
  "Zámková dlažba", "Ploty a brány", "Zemné práce",
  "Rekonštrukcie kúpeľní", "Betonárske práce"
];
const roofs = ["Nová strecha", "Rekonštrukcia strechy", "Oprava / zatekanie"];
for (const type of roofs) {
  assert.equal(tradeForDemand(type), "Strechy");
  assert.equal(companyMatchesDemand("Strechy", type), true);
  assert.equal(companyMatchesDemand("Sadrokartón", type), false);
}
for (const type of trades) {
  assert.equal(tradeForDemand(type), type);
  assert.equal(companyMatchesDemand(type, type), true);
  assert.equal(companyMatchesDemand("Strechy", type), false);
}
assert.equal(companyMatchesDemand("Neznáme remeslo", "Neznáme remeslo"), false);
assert.equal(companyMatchesDemand(null, "Vodoinštalácie"), false);
assert.equal(companyMatchesDemand("Vodoinštalácie", null), false);
console.log("OK: 19 remesiel, whitelist, zamietnutie nespravneho remesla");
