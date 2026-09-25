const assert = require("assert");
const raw = require("./load")(__dirname + "/../js/search.js");
const j = x => (x === undefined || x === null ? x : JSON.parse(JSON.stringify(x)));
const S = new Proxy({}, { get: (_, k) => (...a) => j(raw[k](...a)) });
let passed = 0;
function test(name, fn) { try { fn(); passed++; } catch (e) { console.error("FAIL: " + name + "\n  " + e.message.split("\n").join("\n  ")); process.exitCode = 1; } }

test("matchRanges: literal, every occurrence", () => assert.deepStrictEqual(S.matchRanges("a.b a.b", "a.b"), [[0, 3], [4, 7]]));
test("matchRanges: smart case - lower-case query ignores case", () => assert.deepStrictEqual(S.matchRanges("Foo foo", "foo"), [[0, 3], [4, 7]]));
test("matchRanges: smart case - upper-case in the query is exact", () => assert.deepStrictEqual(S.matchRanges("Foo foo", "Foo"), [[0, 3]]));
test("matchRanges: empty query / no match", () => { assert.deepStrictEqual(S.matchRanges("abc", ""), []); assert.deepStrictEqual(S.matchRanges("abc", "z"), []); });
test("matchRanges: overlapping candidates do not overlap in the result", () => assert.deepStrictEqual(S.matchRanges("aaaa", "aa"), [[0, 2], [2, 4]]));
test("snippet: short lines are untouched", () => assert.deepStrictEqual(S.snippet("hello world", [[6, 11]], 40), { text: "hello world", ranges: [[6, 11]] }));
test("snippet: long lines are windowed around the first match with ellipses, ranges shifted", () => {
  const line = "x".repeat(100) + "NEEDLE" + "y".repeat(100);
  const r = S.snippet(line, [[100, 106]], 40);
  assert.ok(r.text.length <= 42 && r.text.startsWith("…") && r.text.endsWith("…"));
  assert.strictEqual(r.text.slice(r.ranges[0][0], r.ranges[0][1]), "NEEDLE");
});
test("snippet: leading whitespace is trimmed and ranges follow", () => {
  const r = S.snippet("    - item foo", [[11, 14]], 40);
  assert.strictEqual(r.text, "- item foo");
  assert.strictEqual(r.text.slice(r.ranges[0][0], r.ranges[0][1]), "foo");
});
test("snippetHtml: escapes and marks matches", () => {
  const h = S.snippetHtml("a <b> foo", "foo", "#ff0", 40);
  assert.strictEqual(h, 'a &lt;b&gt; <b><font color="#ff0">foo</font></b>');
});
test("group: by file in first-seen order", () => {
  const g = S.group([{ path: "b.md", line: 2, text: "x" }, { path: "a.md", line: 1, text: "y" }, { path: "b.md", line: 5, text: "z" }]);
  assert.deepStrictEqual(g.map(x => [x.path, x.matches.length]), [["b.md", 2], ["a.md", 1]]);
});
test("flatRows: file header then its matches; collapsed files hide matches", () => {
  const g = S.group([{ path: "a.md", line: 1, text: "x" }, { path: "a.md", line: 3, text: "y" }, { path: "b.md", line: 2, text: "z" }]);
  assert.deepStrictEqual(S.flatRows(g, {}).map(r => r.kind), ["file", "match", "match", "file", "match"]);
  assert.deepStrictEqual(S.flatRows(g, { "a.md": true }).map(r => r.kind), ["file", "file", "match"]);
  assert.strictEqual(S.flatRows(g, {})[0].count, 2);
});
console.log("search.js: " + passed + " passed" + (process.exitCode ? " (with failures)" : ""));
