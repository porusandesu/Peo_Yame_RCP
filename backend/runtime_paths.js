const os = require("node:os");
const path = require("node:path");

const appDirectory = process.pkg ? path.dirname(process.execPath) : __dirname;
const dataDirectory = process.env.APP_DATA_DIR || (
  process.pkg && process.platform === "win32"
    ? path.join(process.env.LOCALAPPDATA || os.homedir(), "Peo Yame", "data")
    : path.join(appDirectory, "data")
);

module.exports = { appDirectory, dataDirectory };
