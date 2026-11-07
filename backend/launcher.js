const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");

let failureReported = false;

function reportStartupFailure(error) {
  if (failureReported) return;
  failureReported = true;

  const code = error && typeof error === "object" ? error.code : undefined;
  const detail = error && typeof error === "object" && error.stack ? error.stack : String(error);
  const port = Number(error && typeof error === "object" ? error.port : undefined) || Number(process.env.PORT) || 3000;
  const friendly = code === "EADDRINUSE"
    ? `Port ${port} is already in use. Close the other storage monitor window and try again.`
    : "Peo Yame could not start. Check that your Windows account can save app data, then try again.";
  const logFile = path.join(os.tmpdir(), "peo-yame-backend-startup.log");

  console.error(`\n${friendly}\n`);
  console.error(detail);
  try {
    fs.appendFileSync(logFile, `${new Date().toISOString()}\n${friendly}\n${detail}\n\n`);
    console.error(`\nStartup details saved to: ${logFile}`);
  } catch (_) {
    // Keep the visible error even if Windows blocks the optional log write.
  }

  if (process.platform === "win32" && process.stdin.isTTY) {
    console.error("\nPress Enter to close this window.");
    process.stdin.resume();
    process.stdin.once("data", () => process.exit(1));
  } else {
    process.exit(1);
  }
}

process.on("uncaughtException", reportStartupFailure);
process.on("unhandledRejection", reportStartupFailure);

try {
  require("./server");
} catch (error) {
  reportStartupFailure(error);
}
