const assert = require("assert");
const raw = require("./load")(__dirname + "/../js/links.js");
const j = x => (x === undefined || x === null ? x : JSON.parse(JSON.stringify(x)));
const L = new Proxy({}, { get: (_, k) => (...a) => j(raw[k](...a)) });
let passed = 0;
function test(name, fn) { try { fn(); passed++; } catch (e) { console.error("FAIL: " + name + "\n  " + e.message.split("\n").join("\n  ")); process.exitCode = 1; } }

const vault = ["Old.md", "Other.md", "a/Deep.md", "a/Old2.md", "Job/Plan.md", "Job/Sub/Note.md"];
// rewrite text when `moves` happen in `vault`
function rw(text, moves) {
  const oldMap = raw.buildIndex(vault);
  const moved = vault.map(p => moves[p] || p);
  return j(raw.rewrite(text, oldMap, moves, moved));
}

test("buildIndex/resolve: bare, path and partial-path forms, case-insensitive", () => {
  const m = raw.buildIndex(["a/Deep.md", "Top.md"]);
  assert.strictEqual(raw.resolve(m, "deep"), "a/Deep.md");
  assert.strictEqual(raw.resolve(m, "a/Deep"), "a/Deep.md");
  assert.strictEqual(raw.resolve(m, "Top.md"), "Top.md");
  assert.strictEqual(raw.resolve(m, "nope"), null);
  const p = raw.buildIndex(["x/sub/Name.md"]);
  assert.strictEqual(raw.resolve(p, "sub/Name"), "x/sub/Name.md");
});
test("duplicate basenames: the shortest / alphabetically first path wins the bare form", () => {
  const m = raw.buildIndex(["q/Dup.md", "p/Dup.md"]);
  assert.strictEqual(raw.resolve(m, "Dup"), "p/Dup.md");
  assert.strictEqual(raw.resolve(m, "q/Dup"), "q/Dup.md");
});
test("rename: bare link follows", () => assert.deepStrictEqual(rw("see [[Old]] now", { "Old.md": "New.md" }), { text: "see [[New]] now", count: 1 }));
test("rename keeps heading, alias and embed marker", () => assert.strictEqual(rw("![[Old#H|x]] [[old|y]]", { "Old.md": "New.md" }).text, "![[New#H|x]] [[New|y]]"));
test("rename keeps a .md suffix", () => assert.strictEqual(rw("[[Old.md]]", { "Old.md": "New.md" }).text, "[[New.md]]"));
test("links to other notes are untouched", () => assert.deepStrictEqual(rw("[[Other]] [[a/Deep]]", { "Old.md": "New.md" }), { text: "[[Other]] [[a/Deep]]", count: 0 }));
test("path-form link follows a rename", () => assert.strictEqual(rw("[[a/Old2]]", { "a/Old2.md": "a/Fresh.md" }).text, "[[a/Fresh]]"));
test("path-form link follows a move", () => assert.strictEqual(rw("[[a/Old2]]", { "a/Old2.md": "Job/Old2.md" }).text, "[[Job/Old2]]"));
test("bare link survives a move that keeps the name", () => assert.deepStrictEqual(rw("[[Old2]]", { "a/Old2.md": "Job/Old2.md" }), { text: "[[Old2]]", count: 0 }));
test("bare link becomes path-form when the new bare name would point at another note", () => {
  // Plan -> z/Deep.md; a/Deep.md (shallower alphabetically) keeps the bare name "Deep"
  assert.strictEqual(rw("[[Plan]]", { "Job/Plan.md": "z/Deep.md" }).text, "[[z/Deep]]");
});
test("shortest path wins the bare name deterministically", () => {
  assert.strictEqual(raw.resolve(raw.buildIndex(["q/x/Dup.md", "z/Dup.md", "Dup.md"]), "dup"), "Dup.md");
  assert.strictEqual(raw.resolve(raw.buildIndex(["z/Dup.md", "q/Dup.md"]), "dup"), "q/Dup.md");
});
test("partial-path link keeps its depth", () => assert.strictEqual(rw("[[Sub/Note]]", { "Job/Sub/Note.md": "Job/Sub/Renamed.md" }).text, "[[Sub/Renamed]]"));
test("folder rename rewrites path-form links to every note inside", () => {
  const r = rw("[[Job/Plan]] and [[Job/Sub/Note#h]]", { "Job/Plan.md": "Work/Plan.md", "Job/Sub/Note.md": "Work/Sub/Note.md" });
  assert.deepStrictEqual(r, { text: "[[Work/Plan]] and [[Work/Sub/Note#h]]", count: 2 });
});
test("code fences and inline code are left alone", () => {
  const t = "[[Old]]\n```\n[[Old]]\n```\n`[[Old]]` [[Old]]";
  assert.deepStrictEqual(rw(t, { "Old.md": "New.md" }), { text: "[[New]]\n```\n[[Old]]\n```\n`[[Old]]` [[New]]", count: 2 });
});
test("frontmatter links are rewritten", () => assert.strictEqual(rw("---\nrelated: \"[[Old]]\"\n---\nx", { "Old.md": "New.md" }).text, "---\nrelated: \"[[New]]\"\n---\nx"));
test("unresolved links stay as they are", () => assert.deepStrictEqual(rw("[[Ghost]]", { "Old.md": "New.md" }), { text: "[[Ghost]]", count: 0 }));
test("no moves -> no change", () => assert.deepStrictEqual(rw("[[Old]]", {}), { text: "[[Old]]", count: 0 }));
test("candidates: files that may link to the moved notes (by base name and path)", () => {
  const c = j(raw.moveTerms({ "Job/Sub/Note.md": "Work/Sub/Note.md", "Old.md": "New.md" }));
  assert.deepStrictEqual(c.slice().sort(), ["Note", "Old"]);
});
console.log("links.js: " + passed + " passed" + (process.exitCode ? " (with failures)" : ""));
