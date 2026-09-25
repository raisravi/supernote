const assert = require("assert");
const raw = require("./load")(__dirname + "/../js/render.js");
const j = x => (x === undefined || x === null ? x : JSON.parse(JSON.stringify(x)));
const R = new Proxy({}, { get: (_, k) => (...a) => j(raw[k](...a)) });
let passed = 0;
function test(name, fn) { try { fn(); passed++; } catch (e) { console.error("FAIL: " + name + "\n  " + e.message.split("\n").join("\n  ")); process.exitCode = 1; } }

test("key: deterministic and file-name safe", () => {
  const a = R.key("math", "x^2", { display: true, fg: "#e6e6e6", dark: true });
  assert.strictEqual(a, R.key("math", "x^2", { display: true, fg: "#e6e6e6", dark: true }));
  assert.ok(/^math-[0-9a-f]{16}$/.test(a), a);
});
test("key: any input change gives another key", () => {
  const base = { display: false, fg: "#111111", dark: false };
  const k = R.key("math", "a", base);
  assert.notStrictEqual(k, R.key("math", "b", base));
  assert.notStrictEqual(k, R.key("mermaid", "a", base));
  assert.notStrictEqual(k, R.key("math", "a", { display: true, fg: "#111111", dark: false }));
  assert.notStrictEqual(k, R.key("math", "a", { display: false, fg: "#222222", dark: false }));
  assert.notStrictEqual(k, R.key("math", "a", { display: false, fg: "#111111", dark: true }));
});
test("key: separator ambiguity (kind|src boundaries) does not collide", () => {
  const s = { display: false, fg: "#000000", dark: false };
  assert.notStrictEqual(R.key("math", "1|x", s), R.key("math", "1", Object.assign({}, s, { fg: "x#000000" })));
});
test("hex: 0..1 channels -> #rrggbb", () => { assert.strictEqual(R.hex(1, 0, 0.5), "#ff0080"); assert.strictEqual(R.hex(0, 0, 0), "#000000"); });
test("isDark: by luminance", () => { assert.strictEqual(R.isDark(0.1, 0.1, 0.12), true); assert.strictEqual(R.isDark(0.95, 0.95, 0.95), false); assert.strictEqual(R.isDark(1, 0, 0), true); });
test("shownWidth: 2x render is displayed at half size, clamped to the pane", () => {
  assert.strictEqual(R.shownWidth(300, 0), 150);
  assert.strictEqual(R.shownWidth(2000, 600), 600);
  assert.strictEqual(R.shownWidth(301, 0), 151);
  assert.strictEqual(R.shownWidth(1, 0), 1);
});
test("parseDims: 'W H' from the render script", () => {
  assert.deepStrictEqual(R.parseDims("261 93\n"), { w: 261, h: 93 });
  assert.strictEqual(R.parseDims("nonsense"), null);
  assert.strictEqual(R.parseDims("0 10"), null);
});
console.log("render.js: " + passed + " passed" + (process.exitCode ? " (with failures)" : ""));
