const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const test = require("node:test");

test("web dashboard inline scripts are valid JavaScript", () => {
  const html = fs.readFileSync(path.join(__dirname, "..", "public", "index.html"), "utf8");
  const scripts = [...html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/gi)]
    .map((match) => match[1].trim())
    .filter(Boolean);
  assert.ok(scripts.length > 0, "dashboard contains inline JavaScript");
  scripts.forEach((script, index) => new vm.Script(script, { filename: `dashboard-inline-${index + 1}.js` }));
});
