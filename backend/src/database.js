import Database from "better-sqlite3-multiple-ciphers";
import fs from "node:fs";
import path from "node:path";

const SQLITE_HEADER = Buffer.from("SQLite format 3\0");

export function openDatabase(filename, keyHex = process.env.PEO_YAME_DB_KEY) {
  if (!/^[a-f0-9]{64}$/i.test(keyHex || "")) {
    throw new Error("PEO_YAME_DB_KEY must contain a 256-bit hex key.");
  }

  const key = Buffer.from(keyHex, "hex");
  const exists = fs.existsSync(filename) && fs.statSync(filename).size > 0;
  const header = Buffer.alloc(SQLITE_HEADER.length);
  if (exists) {
    const fd = fs.openSync(filename, "r");
    try {
      fs.readSync(fd, header, 0, header.length, 0);
    } finally {
      fs.closeSync(fd);
    }
  }
  const legacyPlaintext = exists && header.equals(SQLITE_HEADER);
  const db = new Database(filename);

  try {
    if (legacyPlaintext) {
      db.rekey(key);
    } else {
      db.key(key);
    }
    db.prepare("SELECT count(*) FROM sqlite_master").get();
    db.pragma("journal_mode = WAL");
    db.pragma("foreign_keys = ON");
    return db;
  } catch (error) {
    db.close();
    throw new Error("Could not open the encrypted Peo Yame database. Check the key or restore a valid backup.", { cause: error });
  } finally {
    key.fill(0);
  }
}

export function databasePath(dataDir) {
  return path.join(dataDir, "peo-yame.sqlite");
}
