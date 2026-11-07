const test = require("node:test");
const assert = require("node:assert/strict");
const { encodeBase32, authenticatorCode, verifyAuthenticatorCode } = require("../authenticator");

const rfcSecret = "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ";

test("base32 encodes setup keys for authenticator apps", () => {
  assert.equal(encodeBase32(Buffer.from("12345678901234567890")), rfcSecret);
});

test("TOTP matches the RFC SHA-1 test vector", () => {
  assert.equal(authenticatorCode(rfcSecret, 59000), "287082");
  assert.equal(authenticatorCode(rfcSecret, 1111111109000), "081804");
});

test("authenticator accepts current and adjacent time-step codes", () => {
  const time = 59000;
  assert.equal(verifyAuthenticatorCode(rfcSecret, "287082", time), true);
  assert.equal(verifyAuthenticatorCode(rfcSecret, authenticatorCode(rfcSecret, time + 30000), time), true);
  assert.equal(verifyAuthenticatorCode(rfcSecret, "000000", time), false);
});
