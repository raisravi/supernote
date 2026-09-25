const assert = require("assert");
const raw = require("./load")(__dirname + "/../js/fuzzy.js");
const j = x => (x === undefined || x === null ? x : JSON.parse(JSON.stringify(x)));
const F = new Proxy({}, { get: (_, k) => (...a) => j(raw[k](...a)) });
let passed = 0;
function test(name, fn) { try { fn(); passed++; } catch (e) { console.error("FAIL: " + name + "\n  " + e.message.split("\n").join("\n  ")); process.exitCode = 1; } }
const names = (items, q) => F.rank(items.map(n => ({ name: n, path: n + ".md" })), q).map(r => r.item.name);

test("match: subsequence, case-insensitive", () => assert.ok(F.match("prj", "Project Plan")));
test("match: no match -> null", () => { assert.strictEqual(F.match("xyz", "Project"), null); assert.strictEqual(F.match("pjr", "Project"), null); });
test("match: positions point at the matched letters", () => assert.deepStrictEqual(F.match("pp", "Project Plan").positions, [0, 8]));
test("match: empty query matches everything with no positions", () => assert.deepStrictEqual(F.match("", "abc"), { score: 0, positions: [] }));
test("prefix match beats a mid-word match", () => assert.deepStrictEqual(names(["Beta alpha", "Alpha"], "alp"), ["Alpha", "Beta alpha"]));
test("word-start initials beat mid-word letters", () => assert.strictEqual(names(["Apple Pie", "Project Plan"], "pp")[0], "Project Plan"));
test("consecutive run beats scattered letters", () => assert.strictEqual(names(["a_b_c_d", "abcd"], "abcd")[0], "abcd"));
test("shorter name wins on otherwise equal matches", () => assert.deepStrictEqual(names(["Notes long name", "Notes"], "notes"), ["Notes", "Notes long name"]));
test("non-matches are dropped", () => assert.deepStrictEqual(names(["Alpha", "Beta"], "zz"), []));
test("empty query keeps the caller's order", () => assert.deepStrictEqual(names(["b", "a", "c"], ""), ["b", "a", "c"]));
test("falls back to the path when only the folder matches", () => {
  const r = F.rank([{ name: "Plan", path: "Work/Plan.md" }, { name: "Other", path: "Misc/Other.md" }], "work");
  assert.deepStrictEqual(r.map(x => x.item.name), ["Plan"]);
  assert.deepStrictEqual(r[0].positions, []);   // highlight positions only apply to the name
});
test("name matches outrank path-only matches", () => {
  const r = F.rank([{ name: "Misc", path: "Project/Misc.md" }, { name: "Project", path: "Project.md" }], "project");
  assert.strictEqual(r[0].item.name, "Project");
});
test("stable for equal scores", () => assert.deepStrictEqual(names(["aa", "ab"], "a").slice().sort(), ["aa", "ab"]));
test("limit caps the result count", () => assert.strictEqual(F.rank(Array.from({ length: 50 }, (_, i) => ({ name: "n" + i, path: "n" + i + ".md" })), "n", 10).length, 10));
console.log("fuzzy.js: " + passed + " passed" + (process.exitCode ? " (with failures)" : ""));
