const crypto = require("node:crypto");
const { verifyAuthenticatorCode } = require("./authenticator");

const SESSION_DAYS = 7;
const PASSWORD_BYTES = 32;
const PASSWORD_COST = 16384;
const PASSWORD_BLOCK_SIZE = 8;
const PASSWORD_PARALLELISM = 1;
const SESSION_WINDOW_MS = 15 * 60 * 1000;
const MAX_FAILED_LOGINS = 5;
const UNKNOWN_ACCOUNT_SALT = "peo-yame-unknown-account-salt";

function normalizePhone(value) {
  const digits = String(value || "").replace(/\D/g, "");
  const local = digits.startsWith("267") ? digits.slice(3) : digits;
  if (!/^\d{8}$/.test(local)) throw new TypeError("Enter an 8-digit Botswana mobile number.");
  return `+267${local}`;
}

function normalizeEmail(value) {
  if (value == null || String(value).trim() === "") return null;
  const email = String(value).trim().toLowerCase();
  if (email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    throw new TypeError("Enter a valid email address.");
  }
  return email;
}

function tokenHash(token) {
  return crypto.createHash("sha256").update(token).digest("hex");
}

function publicFarmer(record) {
  if (!record) return null;
  return {
    id: record.id,
    name: record.name,
    phone: record.phone,
    email: record.email || "",
    createdAt: record.createdAt,
  };
}

function makePasswordHash(password, salt) {
  return crypto.scryptSync(password, salt, PASSWORD_BYTES, {
    N: PASSWORD_COST,
    r: PASSWORD_BLOCK_SIZE,
    p: PASSWORD_PARALLELISM,
    maxmem: 64 * 1024 * 1024,
  }).toString("hex");
}

function createFarmerAuth(database, { now = () => Date.now() } = {}) {
  const failedLogins = new Map();

  function issueSession(farmer) {
    const token = crypto.randomBytes(32).toString("base64url");
    const expiresAt = new Date(now() + SESSION_DAYS * 24 * 60 * 60 * 1000).toISOString();
    database.createSession(tokenHash(token), farmer.id, expiresAt);
    return { token, expiresAt, farmer: publicFarmer(farmer) };
  }

  function blocked(key) {
    const state = failedLogins.get(key);
    if (!state) return false;
    if (state.until <= now()) {
      failedLogins.delete(key);
      return false;
    }
    return state.count >= MAX_FAILED_LOGINS;
  }

  function noteFailure(key) {
    const current = failedLogins.get(key);
    if (!current || current.until <= now()) {
      failedLogins.set(key, { count: 1, until: now() + SESSION_WINDOW_MS });
      return;
    }
    current.count += 1;
    if (current.count >= MAX_FAILED_LOGINS) current.until = now() + SESSION_WINDOW_MS;
  }

  function register({ phone, name, password, email }) {
    const normalizedPhone = normalizePhone(phone);
    const normalizedEmail = normalizeEmail(email);
    const cleanName = String(name || "").trim().replace(/\s+/g, " ");
    if (cleanName.length < 2 || cleanName.length > 80) throw new TypeError("Enter your name (2 to 80 characters).");
    if (typeof password !== "string" || password.length < 10 || password.length > 128) {
      throw new TypeError("Use a password that is at least 10 characters long.");
    }
    if (database.farmerByPhone(normalizedPhone)) {
      const error = new Error("An account already uses that phone number. Sign in instead.");
      error.status = 409;
      throw error;
    }
    if (normalizedEmail && database.farmerByEmail(normalizedEmail)) {
      const error = new Error("An account already uses that email address.");
      error.status = 409;
      throw error;
    }

    const salt = crypto.randomBytes(16).toString("hex");
    const farmer = database.createFarmer({
      phone: normalizedPhone,
      name: cleanName,
      email: normalizedEmail,
      passwordSalt: salt,
      passwordHash: makePasswordHash(password, salt),
    });
    return issueSession(farmer);
  }

  function login({ phone, email, password, authenticatorCode, clientKey = "unknown" }) {
    const normalizedPhone = phone ? normalizePhone(phone) : null;
    const normalizedEmail = !normalizedPhone ? normalizeEmail(email) : null;
    if (!normalizedPhone && !normalizedEmail) throw new TypeError("Enter your phone number or email address.");
    const key = `${clientKey}:${normalizedPhone || normalizedEmail}`;
    if (blocked(key)) {
      const error = new Error("Too many sign-in attempts. Wait 15 minutes and try again.");
      error.status = 429;
      throw error;
    }

    const farmer = normalizedPhone ? database.farmerByPhone(normalizedPhone) : database.farmerByEmail(normalizedEmail);
    const candidate = makePasswordHash(
      typeof password === "string" ? password : "",
      farmer?.password_salt || UNKNOWN_ACCOUNT_SALT,
    );
    const matches = farmer && typeof password === "string" && /^[0-9a-f]{64}$/i.test(farmer.password_hash)
      ? crypto.timingSafeEqual(Buffer.from(candidate, "hex"), Buffer.from(farmer.password_hash, "hex"))
      : false;
    if (!matches) {
      noteFailure(key);
      const error = new Error("Phone number or password is incorrect.");
      error.status = 401;
      throw error;
    }

    const secret = database.authenticatorForFarmer(farmer.id);
    if (secret && !verifyAuthenticatorCode(secret, authenticatorCode, now())) {
      noteFailure(key);
      const error = new Error("Enter the current code from your authenticator app.");
      error.status = 401;
      throw error;
    }

    failedLogins.delete(key);
    return issueSession(farmer);
  }

  return {
    register,
    login,
    tokenHash,
    publicFarmer,
    farmerForToken: (token) => token ? database.farmerForSession(tokenHash(token)) : null,
    logout: (token) => token ? database.deleteSession(tokenHash(token)) : undefined,
    issueSessionForFarmer: (farmerId) => {
      const farmer = database.farmerById(farmerId);
      if (!farmer) return null;
      return issueSession(farmer);
    },
  };
}

module.exports = { createFarmerAuth, normalizePhone, normalizeEmail };
