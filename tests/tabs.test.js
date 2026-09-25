const assert = require("assert");
const raw = require("./load")(__dirname + "/../js/tabs.js");
const j = x => (x === undefined || x === null ? x : JSON.parse(JSON.stringify(x)));
const T = new Proxy({}, { get: (_, k) => (...a) => j(raw[k](...a)) });
let passed = 0;
function test(name, fn) { try { fn(); passed++; } catch (e) { console.error("FAIL: " + name + "\n  " + e.message.split("\n").join("\n  ")); process.exitCode = 1; } }
const rels = s => s.tabs.map(t => t.rel);

test("init: one empty tab", () => { const s = T.init(); assert.deepStrictEqual(rels(s), [""]); assert.strictEqual(s.active, 0); });
test("open into an empty tab fills it, no history", () => {
  const s = T.open(T.init(), "a.md", false);
  assert.deepStrictEqual(rels(s), ["a.md"]); assert.deepStrictEqual(s.tabs[0].back, []);
});
test("open replaces the active tab and pushes history, clears forward", () => {
  let s = T.open(T.init(), "a.md", false);
  s = T.open(s, "b.md", false);
  assert.deepStrictEqual(rels(s), ["b.md"]); assert.deepStrictEqual(s.tabs[0].back, ["a.md"]);
  s = T.back(s); s = T.open(s, "c.md", false);
  assert.deepStrictEqual(s.tabs[0].fwd, []);
});
test("history is capped at 100 entries (oldest dropped)", () => {
  let s = T.open(T.init(), "n0.md", false);
  for (let i = 1; i <= 130; i++) s = T.open(s, "n" + i + ".md", false);
  assert.strictEqual(s.tabs[0].back.length, 100);
  assert.strictEqual(s.tabs[0].back[99], "n129.md"); assert.strictEqual(s.tabs[0].back[0], "n30.md");
});
test("open with newTab adds a tab after the active one and activates it", () => {
  let s = T.open(T.init(), "a.md", false); s = T.open(s, "b.md", true); s = T.open(s, "c.md", true);
  assert.deepStrictEqual(rels(s), ["a.md", "b.md", "c.md"]); assert.strictEqual(s.active, 2);
  s = T.activate(s, 0); s = T.open(s, "x.md", true);
  assert.deepStrictEqual(rels(s), ["a.md", "x.md", "b.md", "c.md"]); assert.strictEqual(s.active, 1);
});
test("opening a note that is already open in another tab just activates that tab", () => {
  let s = T.open(T.init(), "a.md", false); s = T.open(s, "b.md", true);
  s = T.open(s, "a.md", false);
  assert.deepStrictEqual(rels(s), ["a.md", "b.md"]); assert.strictEqual(s.active, 0);
});
test("opening the current note again changes nothing", () => {
  const s = T.open(T.init(), "a.md", false);
  assert.deepStrictEqual(T.open(s, "a.md", false), s);
});
test("open with empty rel is a no-op", () => assert.deepStrictEqual(T.open(T.init(), "", false), T.init()));
test("close: active moves to the neighbour that takes its place", () => {
  let s = T.open(T.init(), "a.md", false); s = T.open(s, "b.md", true); s = T.open(s, "c.md", true); s = T.activate(s, 1);
  s = T.close(s, 1);
  assert.deepStrictEqual(rels(s), ["a.md", "c.md"]); assert.strictEqual(s.active, 1);
  s = T.close(s, 1); assert.deepStrictEqual(rels(s), ["a.md"]); assert.strictEqual(s.active, 0);
});
test("close: closing a tab before the active one keeps the same tab active", () => {
  let s = T.open(T.init(), "a.md", false); s = T.open(s, "b.md", true); s = T.open(s, "c.md", true);
  s = T.close(s, 0);
  assert.deepStrictEqual(rels(s), ["b.md", "c.md"]); assert.strictEqual(s.active, 1);
});
test("close last tab leaves one empty tab", () => {
  let s = T.open(T.init(), "a.md", false); s = T.close(s, 0);
  assert.deepStrictEqual(s, T.init());
});
test("cycle wraps both ways", () => {
  let s = T.open(T.init(), "a.md", false); s = T.open(s, "b.md", true); s = T.open(s, "c.md", true);
  assert.strictEqual(T.cycle(s, 1).active, 0); assert.strictEqual(T.cycle(T.activate(s, 0), -1).active, 2);
});
test("back / forward walk the history", () => {
  let s = T.open(T.init(), "a.md", false); s = T.open(s, "b.md", false); s = T.open(s, "c.md", false);
  s = T.back(s); assert.strictEqual(s.tabs[0].rel, "b.md");
  s = T.back(s); assert.strictEqual(s.tabs[0].rel, "a.md");
  assert.deepStrictEqual(T.back(s), s);
  s = T.forward(s); s = T.forward(s); assert.strictEqual(s.tabs[0].rel, "c.md");
  assert.deepStrictEqual(T.forward(s), s);
});
test("canBack / canForward", () => {
  let s = T.open(T.init(), "a.md", false); s = T.open(s, "b.md", false);
  assert.strictEqual(T.canBack(s), true); assert.strictEqual(T.canForward(s), false);
  s = T.back(s); assert.strictEqual(T.canBack(s), false); assert.strictEqual(T.canForward(s), true);
});
test("remap: renames follow files and folders in rel, back and forward", () => {
  let s = T.open(T.init(), "Work/a.md", false); s = T.open(s, "Work/b.md", false); s = T.back(s);
  s = T.remap(s, "Work", "Job");
  assert.strictEqual(s.tabs[0].rel, "Job/a.md"); assert.deepStrictEqual(s.tabs[0].fwd, ["Job/b.md"]);
  s = T.remap(s, "Job/a.md", "Job/z.md"); assert.strictEqual(s.tabs[0].rel, "Job/z.md");
  assert.strictEqual(T.remap(s, "Jobs", "X").tabs[0].rel, "Job/z.md");
});
test("removePath closes tabs for a trashed note or folder and scrubs history", () => {
  let s = T.open(T.init(), "keep.md", false); s = T.open(s, "Work/a.md", true); s = T.open(s, "Work/b.md", true); s = T.open(s, "other.md", true);
  s = T.open(s, "Work/c.md", false);   // other.md tab now has history entry other.md
  s = T.removePath(s, "Work");
  assert.deepStrictEqual(rels(s), ["keep.md", "Work/c.md"].filter(r => !r.startsWith("Work/")));
  assert.ok(s.tabs.every(t => t.back.concat(t.fwd).every(r => !r.startsWith("Work/"))));
  assert.ok(s.active >= 0 && s.active < s.tabs.length);
});
test("prune drops missing notes, dedupes, keeps a valid active index", () => {
  const s0 = { tabs: [{ rel: "a.md", back: ["gone.md", "b.md"], fwd: [] }, { rel: "gone.md", back: [], fwd: [] }, { rel: "a.md", back: [], fwd: [] }], active: 1 };
  const s = T.prune(s0, ["a.md", "b.md"]);
  assert.deepStrictEqual(rels(s), ["a.md"]); assert.deepStrictEqual(s.tabs[0].back, ["b.md"]); assert.strictEqual(s.active, 0);
  assert.deepStrictEqual(T.prune({ tabs: [{ rel: "x.md", back: [], fwd: [] }], active: 0 }, []), T.init());
});
test("addEmpty inserts an empty tab after the active one; no-op when the active tab is already empty", () => {
  let s = T.open(T.init(), "a.md", false); s = T.open(s, "b.md", true); s = T.activate(s, 0);
  s = T.addEmpty(s);
  assert.deepStrictEqual(rels(s), ["a.md", "", "b.md"]); assert.strictEqual(s.active, 1);
  assert.deepStrictEqual(T.addEmpty(s), s);
  assert.deepStrictEqual(T.addEmpty(T.init()), T.init());
});
test("setView / activeView remember a per-tab view", () => {
  let s = T.open(T.init(), "a.md", false); s = T.setView(s, { cursor: 5, scroll: 30 });
  assert.deepStrictEqual(T.activeView(s), { cursor: 5, scroll: 30 });
  s = T.open(s, "b.md", false); assert.strictEqual(T.activeView(s), null);   // navigating clears the view
});
test("normalize repairs garbage from a hand-edited state file", () => {
  assert.deepStrictEqual(T.normalize(null), T.init());
  assert.deepStrictEqual(T.normalize({ tabs: "x", active: 9 }), T.init());
  const s = T.normalize({ tabs: [{ rel: "a.md" }, 5, { rel: 3 }], active: 7 });
  assert.deepStrictEqual(rels(s), ["a.md"]); assert.strictEqual(s.active, 0);
});
console.log("tabs.js: " + passed + " passed" + (process.exitCode ? " (with failures)" : ""));
