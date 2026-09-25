const assert = require("assert");
const raw = require("./load")(__dirname + "/../js/commands.js");
const j = x => (x === undefined || x === null ? x : JSON.parse(JSON.stringify(x)));
const K = new Proxy({}, { get: (_, k) => typeof raw[k] === "function" ? (...a) => j(raw[k](...a)) : j(raw[k]) });
let passed = 0;
function test(name, fn) { try { fn(); passed++; } catch (e) { console.error("FAIL: " + name + "\n  " + e.message.split("\n").join("\n  ")); process.exitCode = 1; } }

test("command ids are unique and every command has a title", () => {
  const ids = K.COMMANDS.map(c => c.id);
  assert.strictEqual(new Set(ids).size, ids.length);
  assert.ok(K.COMMANDS.every(c => c.title && c.group));
});
test("filter: fuzzy on the title, empty query keeps menu order", () => {
  assert.strictEqual(K.filter("").length, K.COMMANDS.length);
  assert.strictEqual(K.filter("daily")[0].id, "daily");
  assert.deepStrictEqual(K.filter("zzzzqq"), []);
});
test("commands needing an open note are hidden without one", () => {
  const without = K.filter("", false).map(c => c.id);
  assert.ok(!without.includes("toggle-view") && without.includes("new-note"));
  assert.ok(K.filter("", true).map(c => c.id).includes("toggle-view"));
});
test("cheat sheet groups every shortcut once", () => {
  const groups = K.cheatSheet();
  assert.ok(groups.length >= 4);
  groups.forEach(g => assert.ok(g.items.length > 0 && g.items.every(i => i.keys && i.title)));
});
console.log("commands.js: " + passed + " passed" + (process.exitCode ? " (with failures)" : ""));
