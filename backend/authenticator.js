const crypto = require("node:crypto");

const BASE32_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";

function encodeBase32(buffer) {
  let bits = 0;
  let value = 0;
  let output = "";
  for (const byte of buffer) {
    value = (value << 8) | byte;
    bits += 8;
    while (bits >= 5) {
      output += BASE32_ALPHABET[(value >>> (bits - 5)) & 31];
      bits -= 5;
      value &= (1 << bits) - 1;
    }
  }
  if (bits) output += BASE32_ALPHABET[(value << (5 - bits)) & 31];
  return output;
}

function decodeBase32(secret) {
  let bits = 0;
  let value = 0;
  const bytes = [];
  for (const character of String(secret).toUpperCase().replace(/=+$/g, "")) {
    const digit = BASE32_ALPHABET.indexOf(character);
    if (digit < 0) throw new TypeError("Invalid authenticator setup key.");
    value = (value << 5) | digit;
    bits += 5;
    if (bits >= 8) {
      bytes.push((value >>> (bits - 8)) & 255);
      bits -= 8;
      value &= (1 << bits) - 1;
    }
  }
  if (bits >= 5) throw new TypeError("Invalid authenticator setup key.");
  return Buffer.from(bytes);
}

function authenticatorCode(secret, timestamp = Date.now()) {
  const counter = Math.floor(timestamp / 30000);
  const message = Buffer.alloc(8);
  message.writeBigUInt64BE(BigInt(counter));
  const digest = crypto.createHmac("sha1", decodeBase32(secret)).update(message).digest();
  const offset = digest[digest.length - 1] & 15;
  const number = (digest.readUInt32BE(offset) & 0x7fffffff) % 1000000;
  return String(number).padStart(6, "0");
}

function verifyAuthenticatorCode(secret, code, timestamp = Date.now()) {
  if (!secret || !/^\d{6}$/.test(String(code || ""))) return false;
  const supplied = Buffer.from(String(code));
  for (const offset of [-30000, 0, 30000]) {
    const expected = Buffer.from(authenticatorCode(secret, timestamp + offset));
    if (crypto.timingSafeEqual(supplied, expected)) return true;
  }
  return false;
}

module.exports = { encodeBase32, authenticatorCode, verifyAuthenticatorCode };
