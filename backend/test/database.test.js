import { test } from "node:test";
import assert from "node:assert/strict";
import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import Database from "better-sqlite3-multiple-ciphers";
import { openDatabase } from "../src/database.js";

test("migrates plaintext SQLite, encrypts data, and requires the original key", (t) => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), "peo-yame-encryption-"));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  const filename = path.join(directory, "legacy.sqlite");
  const legacy = new Database(filename);
  legacy.exec("CREATE TABLE legacy_marker(value TEXT NOT NULL); INSERT INTO legacy_marker VALUES('private farmer data');");
  legacy.close();
  assert.equal(fs.readFileSync(filename).subarray(0, 16).toString(), "SQLite format 3\0");

  const key = crypto.randomBytes(32).toString("hex");
  const encrypted = openDatabase(filename, key);
  assert.equal(encrypted.prepare("SELECT value FROM legacy_marker").get().value, "private farmer data");
  encrypted.close();

  const stored = fs.readFileSync(filename);
  assert.notEqual(stored.subarray(0, 16).toString(), "SQLite format 3\0");
  assert.equal(stored.includes(Buffer.from("private farmer data")), false);
  assert.throws(() => openDatabase(filename, crypto.randomBytes(32).toString("hex")));
  const reopened = openDatabase(filename, key);
  assert.equal(reopened.prepare("SELECT value FROM legacy_marker").get().value, "private farmer data");
  reopened.close();

  const backupPath = path.join(directory, "backup.sqlite");
  fs.copyFileSync(filename, backupPath);
  const backup = openDatabase(backupPath, key);
  assert.equal(backup.prepare("SELECT value FROM legacy_marker").get().value, "private farmer data");
  backup.close();
});
