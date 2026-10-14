const API_BASE_URL = (process.env.API_BASE_URL || "http://localhost:3000").replace(/\/$/, "");
const SITE = process.env.SITE || "bay-2";
const INTERVAL_MS = Number(process.env.INTERVAL_MS) || 5000;

function rounded(value) {
  return Math.round(value * 10) / 10;
}

async function sendReading() {
  try {
    const statusResponse = await fetch(`${API_BASE_URL}/api/status`);
    if (!statusResponse.ok) throw new Error(`Status request returned ${statusResponse.status}`);
    const { threshold } = await statusResponse.json();
    const tempRange = threshold.maxTemp - threshold.minTemp;
    const humidityRange = threshold.maxHumidity - threshold.minHumidity;
    const temperature = rounded(
      (threshold.minTemp + threshold.maxTemp) / 2 + (Math.random() - 0.5) * tempRange * 0.1,
    );
    const humidity = rounded(
      (threshold.minHumidity + threshold.maxHumidity) / 2 + (Math.random() - 0.5) * humidityRange * 0.1,
    );

    const response = await fetch(`${API_BASE_URL}/api/readings`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        site: SITE,
        commodity: threshold.commodity,
        temperature,
        humidity,
      }),
    });
    const result = await response.json();
    if (!response.ok) throw new Error(result.error || `Reading request returned ${response.status}`);
    console.log(
      `${result.reading.commodity}: ${result.reading.temperature}°C / ${result.reading.humidity}% RH`,
    );
  } catch (error) {
    console.error(`Sensor simulation failed: ${error.message}`);
  }
}

console.log(`Sensor simulator posting to ${API_BASE_URL}/api/readings every ${INTERVAL_MS / 1000}s`);
sendReading();
setInterval(sendReading, INTERVAL_MS);
