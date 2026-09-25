const assert = require("assert");
const raw = require("./load")(__dirname + "/../js/slash.js");
const j = x => (x === undefined || x === null ? x : JSON.parse(JSON.stringify(x)));
const S = new Proxy({}, { get: (_, k) => (...a) => j(raw[k](...a)) });
let passed = 0;
function test(name, fn) { try { fn(); passed++; } catch (e) { console.error("FAIL: " + name + "\n  " + e.message.split("\n").join("\n  ")); process.exitCode = 1; } }
const D = new Date(2026, 8, 4, 7, 5, 9);

test("context: '/' at line start", () => assert.deepStrictEqual(S.context("hello\n/", 7), { start: 6, query: "" }));
test("context: query after the slash", () => assert.deepStrictEqual(S.context("/hea", 4), { start: 0, query: "hea" }));
test("context: indented slash (inside a list) still counts", () => assert.deepStrictEqual(S.context("  /task", 7), { start: 2, query: "task" }));
test("context: not after other text (a/b, urls)", () => { assert.strictEqual(S.context("a /", 3), null); assert.strictEqual(S.context("http://x", 8), null); });
test("context: whitespace in the query closes it", () => assert.strictEqual(S.context("/a b", 4), null));
test("context: caret before the slash", () => assert.strictEqual(S.context("/x", 0), null));
test("filter: empty query lists everything in menu order", () => { const r = S.filter(""); assert.ok(r.length >= 12); assert.strictEqual(r[0].id, "h1"); });
test("filter: matches title and keywords", () => {
  assert.strictEqual(S.filter("todo")[0].id, "task");
  assert.strictEqual(S.filter("head")[0].id, "h1");
  assert.deepStrictEqual(S.filter("zzzz"), []);
});
test("apply: heading replaces the slash command", () => assert.deepStrictEqual(S.apply("/h2", 3, "h2", { start: 0, query: "h2" }, D), { text: "## ", cursor: 3 }));
test("apply: keeps text around the command and the indent", () => assert.deepStrictEqual(S.apply("a\n  /task\nb", 9, "task", { start: 4, query: "task" }, D), { text: "a\n  - [ ] \nb", cursor: 10 }));
test("apply: code block puts the caret inside", () => {
  const r = S.apply("/code", 5, "code", { start: 0, query: "code" }, D);
  assert.strictEqual(r.text, "```\n\n```");
  assert.strictEqual(r.cursor, 4);
});
test("apply: table", () => {
  const r = S.apply("/table", 6, "table", { start: 0, query: "table" }, D);
  assert.ok(r.text.startsWith("| Column 1 | Column 2 |\n| --- | --- |"));
});
test("apply: callout", () => assert.deepStrictEqual(S.apply("/callout", 8, "callout", { start: 0, query: "callout" }, D), { text: "> [!note]\n> ", cursor: 12 }));
test("apply: date and time use the given moment", () => {
  assert.strictEqual(S.apply("/date", 5, "date", { start: 0, query: "date" }, D).text, "2026-09-04");
  assert.strictEqual(S.apply("/time", 5, "time", { start: 0, query: "time" }, D).text, "07:05");
});
test("apply: wikilink puts the caret between the brackets", () => assert.deepStrictEqual(S.apply("/link", 5, "link", { start: 0, query: "link" }, D), { text: "[[]]", cursor: 2 }));
test("apply: unknown id changes nothing but removes the command", () => assert.deepStrictEqual(S.apply("/x", 2, "nope", { start: 0, query: "x" }, D), { text: "", cursor: 0 }));
console.log("slash.js: " + passed + " passed" + (process.exitCode ? " (with failures)" : ""));
