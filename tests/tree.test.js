const assert = require("assert");
const raw = require("./load")(__dirname + "/../js/tree.js");
const j = x => JSON.parse(JSON.stringify(x)); // vm realm arrays differ in prototype
const T = { buildRows: (...a) => j(raw.buildRows(...a)), parentOf: raw.parentOf, baseName: raw.baseName, ancestors: (...a) => j(raw.ancestors(...a)), remapPath: raw.remapPath, sideRows: (...a) => j(raw.sideRows(...a)) };

const entries = [
  { type: "file", path: "zeta.md", mtime: 5 },
  { type: "dir", path: "Work", mtime: 0 },
  { type: "file", path: "Work/plan b.md", mtime: 9 },
  { type: "file", path: "Work/Plan A.md", mtime: 1 },
  { type: "dir", path: "Work/Sub", mtime: 0 },
  { type: "file", path: "Work/Sub/deep.md", mtime: 2 },
  { type: "file", path: "Alpha.md", mtime: 7 },
  { type: "dir", path: "archive", mtime: 0 },
];

// collapsed: folders first (case-insens), then notes A->Z, extension stripped
let rows = T.buildRows(entries, {}, false);
assert.deepStrictEqual(rows.map(r => r.name), ["archive", "Work", "Alpha", "zeta"]);
assert.ok(rows.every(r => r.depth === 0));

// expanded Work (+ Sub): nested, folders before notes at each level
rows = T.buildRows(entries, { Work: true, "Work/Sub": true }, false);
assert.deepStrictEqual(rows.map(r => r.path), ["archive", "Work", "Work/Sub", "Work/Sub/deep.md", "Work/Plan A.md", "Work/plan b.md", "Alpha.md", "zeta.md"]);
assert.deepStrictEqual(rows.map(r => r.depth), [0, 0, 1, 2, 1, 1, 0, 0]);
assert.strictEqual(rows[1].expanded, true);
assert.strictEqual(rows[0].expanded, false);

// by modified: notes newest first, folders still first
rows = T.buildRows(entries, {}, true);
assert.deepStrictEqual(rows.map(r => r.name), ["archive", "Work", "Alpha", "zeta"].slice(0, 2).concat(["Alpha", "zeta"]));
rows = T.buildRows(entries, { Work: true }, true);
assert.deepStrictEqual(rows.filter(r => r.depth === 1 && r.type === "file").map(r => r.name), ["plan b", "Plan A"]);

// attachments are indexed by the vault script but never shown in the tree
rows = T.buildRows(entries.concat([{ type: "attachment", path: "Attachments/pic.png", mtime: 1 }, { type: "attachment", path: "Work/x.jpg", mtime: 1 }]), { Work: true }, false);
assert.ok(rows.every(r => r.type !== "attachment"));
assert.strictEqual(rows.length, T.buildRows(entries, { Work: true }, false).length);

// helpers
assert.strictEqual(T.parentOf("a/b/c.md"), "a/b");
assert.strictEqual(T.parentOf("c.md"), "");
assert.strictEqual(T.baseName("a/My Note.md"), "My Note");
assert.deepStrictEqual(T.ancestors("a/b/c.md"), ["a/b", "a"]);
assert.strictEqual(T.remapPath("Work/Plan A.md", "Work", "Job"), "Job/Plan A.md");
assert.strictEqual(T.remapPath("Workshop/x.md", "Work", "Job"), "Workshop/x.md");
assert.strictEqual(T.remapPath("Work", "Work", "Job"), "Job");

// ---- pinned / recent sections ----
{
  const tree = [{ path: "a.md", name: "a", type: "file", depth: 0 }];
  const exists = { "a.md": 1, "Work/Plan.md": 1, "b.md": 1, "c.md": 1 };
  const kinds = rows => rows.map(r => r.type + (r.key ? ":" + r.key : "") + (r.type === "pin" || r.type === "recent" ? ":" + r.path : ""));
  assert.deepStrictEqual(kinds(T.sideRows(tree, [], [], {}, exists)), ["file"], "no pins/recents -> plain tree");
  const open = { pins: true, recent: true };
  assert.deepStrictEqual(kinds(T.sideRows(tree, ["Work/Plan.md"], ["b.md", "Work/Plan.md", "c.md"], open, exists)),
    ["hdr:pins", "pin:Work/Plan.md", "hdr:recent", "recent:b.md", "recent:c.md", "hdr:files", "file"], "recents skip pinned notes");
  assert.deepStrictEqual(kinds(T.sideRows(tree, ["Work/Plan.md"], ["b.md"], { pins: false, recent: false }, exists)),
    ["hdr:pins", "hdr:recent", "hdr:files", "file"], "collapsed sections keep only headers");
  assert.deepStrictEqual(kinds(T.sideRows(tree, ["gone.md"], ["gone2.md"], open, exists)), ["file"], "missing notes are dropped");
  const r = T.sideRows(tree, ["Work/Plan.md"], [], open, exists);
  assert.deepStrictEqual([r[1].name, r[1].hint], ["Plan", "Work"]);
  assert.strictEqual(r[0].count, 1);
  const many = Array.from({ length: 12 }, (_, i) => "n" + i + ".md");
  const ex2 = {}; many.forEach(m => ex2[m] = 1);
  assert.strictEqual(T.sideRows(tree, [], many, open, ex2).filter(x => x.type === "recent").length, 6, "recent list is capped");
}

console.log("tree.js: all tests passed");
