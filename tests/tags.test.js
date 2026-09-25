const assert = require("assert");
const raw = require("./load")(__dirname + "/../js/tags.js");
const j = x => (x === undefined || x === null ? x : JSON.parse(JSON.stringify(x)));
const T = new Proxy({}, { get: (_, k) => (...a) => j(raw[k](...a)) });
let passed = 0;
function test(name, fn) { try { fn(); passed++; } catch (e) { console.error("FAIL: " + name + "\n  " + e.message.split("\n").join("\n  ")); process.exitCode = 1; } }

const idx = { "a.md": ["project", "project/alpha"], "b.md": ["project/beta", "idea"], "c.md": ["Idea"], "d.md": [] };
const brief = rows => rows.map(r => r.tag + ":" + r.count + (r.hasChildren ? (r.expanded ? "-" : "+") : "") + "@" + r.depth);

test("top-level tags with note counts including nested ones; case-insensitive merge", () => {
  assert.deepStrictEqual(brief(T.rows(idx, {})), ["idea:2@0", "project:2+@0"]);
});
test("expanding a parent shows its children indented", () => {
  assert.deepStrictEqual(brief(T.rows(idx, { project: true })), ["idea:2@0", "project:2-@0", "project/alpha:1@1", "project/beta:1@1"]);
});
test("a parent that only exists via children is still listed (no note tagged 'x' itself)", () => {
  const r = T.rows({ "a.md": ["x/y/z"] }, { x: true, "x/y": true });
  assert.deepStrictEqual(brief(r), ["x:1-@0", "x/y:1-@1", "x/y/z:1@2"]);
});
test("row name is the last segment, display spelling is the first seen", () => {
  const r = T.rows({ "a.md": ["Work/Plan"] }, { work: true });
  assert.deepStrictEqual(r.map(x => x.name), ["Work", "Plan"]);
});
test("notesFor: notes with the tag or any nested tag, sorted", () => {
  assert.deepStrictEqual(T.notesFor(idx, "project"), ["a.md", "b.md"]);
  assert.deepStrictEqual(T.notesFor(idx, "project/alpha"), ["a.md"]);
  assert.deepStrictEqual(T.notesFor(idx, "IDEA"), ["b.md", "c.md"]);
  assert.deepStrictEqual(T.notesFor(idx, "nope"), []);
});
test("notesFor does not treat a prefix of a segment as a parent", () => assert.deepStrictEqual(T.notesFor({ "a.md": ["projects"] }, "project"), []));
test("filter narrows to tags containing the text (and keeps their parents visible)", () => {
  assert.deepStrictEqual(brief(T.rows(idx, {}, "alp")), ["project:2-@0", "project/alpha:1@1"]);
});
test("empty index -> no rows", () => assert.deepStrictEqual(T.rows({}, {}), []));
console.log("tags.js: " + passed + " passed" + (process.exitCode ? " (with failures)" : ""));
