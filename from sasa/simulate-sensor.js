// simulate-sensor.js
// Stands in for the physical Arduino + DHT22 + GSM module while it isn't
// built yet. It posts a reading to the backend every few seconds, the same
// way the real hardware eventually will over its GSM/SMS or WiFi link.
//
// Run alongside the server:  npm run simulate
// Swap this file out for real firmware/gateway code once hardware exists -
// nothing else in the backend or dashboard needs to change, since they only
// depend on the POST /api/readings contract, not on where the data comes from.

const API_URL = process.env.API_URL || 'http://localhost:3000/api/readings';
const COMMODITY = process.env.COMMODITY || 'tomato';
const INTERVAL_MS = 4000;

let temperature = 11.5;
let humidity = 82;

function drift(value, amount, min, max) {
  const next = value + (Math.random() - 0.5) * amount;
  return Math.min(max, Math.max(min, next));
}

async function sendReading() {
  temperature = +drift(temperature, 0.7, 4, 34).toFixed(1);
  humidity = +drift(humidity, 1.4, 45, 99).toFixed(1);

  try {
    const res = await fetch(API_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        site: 'bay-2',
        commodity: COMMODITY,
        temperature,
        humidity,
      }),
    });
    const data = await res.json();
    const alertNote = data.alert ? ` -> ALERT (${data.alert.level}): ${data.alert.message}` : '';
    console.log(`Sent ${temperature}°C / ${humidity}%RH${alertNote}`);
  } catch (err) {
    console.error('Failed to send reading:', err.message);
  }
}

console.log(`Simulating sensor for "${COMMODITY}" -> POST ${API_URL} every ${INTERVAL_MS / 1000}s`);
setInterval(sendReading, INTERVAL_MS);
sendReading();
