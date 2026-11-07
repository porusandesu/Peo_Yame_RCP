const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const test = require('node:test');

const html = fs.readFileSync(path.join(__dirname, '..', 'public', 'index.html'), 'utf8');

test('web demo entry has no pretend phone verification gate', () => {
  assert.match(html, /id="enterDemoMode"/);
  assert.match(html, /Demo mode/);
  assert.match(html, /Mr Lesego Lefoko/);
  assert.match(html, /LLefoko@email\.co\.bw/);
  assert.match(html, /id="webName"/);
  assert.match(html, /id="webPhone"/);
  assert.match(html, /id="webPassword"/);
  assert.doesNotMatch(html, /id="otpPanel"|Continue with OTP/);
  assert.match(html, /Shared demo profile/);
  assert.match(html, /peo-yame-128\.png/);
});

test('web dashboard JavaScript parses', () => {
  const scripts = [...html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/gi)];
  assert.ok(scripts.length > 0, 'dashboard script exists');
  for (const [, script] of scripts) new vm.Script(script, { filename: 'dashboard-inline.js' });
});
