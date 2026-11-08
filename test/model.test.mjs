import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";

const src = readFileSync(new URL("../Model.js", import.meta.url), "utf8").replace(/^\.pragma library\s*$/m, "");
const M = {};
vm.runInNewContext(src, M);

const up = JSON.stringify({
  addr: "10.0.0.1:8000", proxy_reachable: true,
  system: { want: "proxy", tunnel: true, dns: true, ssh: true },
  tor: { active: true, exit_want: "proxy", exit: "proxy", control: true, rotate: 20 },
});

test("parseStatus reads every field", () => {
  const s = M.parseStatus(up);
  assert.equal(s.ok, true);
  assert.equal(s.addr, "10.0.0.1:8000");
  assert.equal(s.reachable, true);
  assert.equal(s.want, "proxy");
  assert.equal(s.tunnel, true);
  assert.equal(s.torActive, true);
  assert.equal(s.exit, "proxy");
  assert.equal(s.rotate, 20);
});

test("parseStatus rejects garbage", () => {
  assert.equal(M.parseStatus("not json").ok, false);
  assert.equal(M.parseStatus("").ok, false);
});

test("parseStatus coerces wrong types", () => {
  const s = M.parseStatus(JSON.stringify({ addr: 5, system: { tunnel: "yes" }, tor: { rotate: "x" } }));
  assert.equal(s.ok, true);
  assert.equal(s.addr, "");
  assert.equal(s.tunnel, false);
  assert.equal(s.rotate, 0);
  assert.equal(s.want, "normal");
});

test("parseStatus caps a long address", () => {
  assert.ok(M.parseStatus(JSON.stringify({ addr: "a".repeat(5000) })).addr.length <= 260);
});

test("barIcon: normal, proxy, proxy down, unknown", () => {
  const s = M.parseStatus(up);
  assert.equal(M.barIcon(s), "󰒍");
  assert.equal(M.barIcon({ ...s, want: "normal", tunnel: false }), "󰖟");
  assert.equal(M.barIcon({ ...s, reachable: false }), "󰀦");
  assert.equal(M.barIcon(M.parseStatus("")), "󰀦");
});

test("escapeMarkup neutralises tags and entities", () => {
  assert.equal(M.escapeMarkup('<img src="x">&'), "&lt;img src=&quot;x&quot;&gt;&amp;");
});

test("tooltip never carries raw markup from the address", () => {
  const s = M.parseStatus(JSON.stringify({ addr: "<img src=x>" }));
  assert.ok(!M.tooltip(s).includes("<img"));
});

test("stripAnsi removes colour codes", () => {
  assert.equal(M.stripAnsi("\u001b[31m✘ no proxy address\u001b[0m"), "✘ no proxy address");
});

test("rotateArgs", () => {
  assert.deepEqual(Array.from(M.rotateArgs("")), ["tor", "rotate", "off"]);
  assert.deepEqual(Array.from(M.rotateArgs(" 0 ")), ["tor", "rotate", "off"]);
  assert.deepEqual(Array.from(M.rotateArgs("off")), ["tor", "rotate", "off"]);
  assert.deepEqual(Array.from(M.rotateArgs(" 20 ")), ["tor", "rotate", "20"]);
});

test("addrArgs keeps the text as one argument", () => {
  assert.deepEqual(Array.from(M.addrArgs(" 1.2.3.4:80;reboot ")), ["addr", "1.2.3.4:80;reboot"]);
});
