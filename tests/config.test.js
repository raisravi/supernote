const assert = require("assert");
const raw = require("./load")(__dirname + "/../js/config.js");
const j = x => (x === undefined || x === null ? x : JSON.parse(JSON.stringify(x)));
const C = new Proxy({}, { get: (_, k) => (...a) => j(raw[k](...a)) });
let passed = 0;
function test(name, fn) { try { fn(); passed++; } catch (e) { console.error("FAIL: " + name + "\n  " + e.message.split("\n").join("\n  ")); process.exitCode = 1; } }
const D = new Date(2026, 8, 4, 7, 5, 9); // Fri 4 Sep 2026 07:05:09 local

test("formatDate: numeric tokens", () => assert.strictEqual(C.formatDate("YYYY-MM-DD HH:mm:ss", D), "2026-09-04 07:05:09"));
test("formatDate: short forms", () => assert.strictEqual(C.formatDate("YY/M/D H:m", D), "26/9/4 7:5"));
test("formatDate: names", () => assert.strictEqual(C.formatDate("dddd, MMMM D", D), "Friday, September 4"));
test("formatDate: short names", () => assert.strictEqual(C.formatDate("ddd MMM", D), "Fri Sep"));
test("formatDate: [literal] text is kept", () => assert.strictEqual(C.formatDate("[Week of] YYYY", D), "Week of 2026"));
test("formatDate: 12-hour clock", () => assert.strictEqual(C.formatDate("hh:mm A", new Date(2026, 0, 1, 15, 4)), "03:04 PM"));
test("formatDate: unknown letters pass through", () => assert.strictEqual(C.formatDate("YYYY-MM-DD_x", D), "2026-09-04_x"));
test("defaults", () => {
  const d = C.defaults();
  assert.deepStrictEqual([d.dailyFolder, d.dailyFormat, d.templatesFolder, d.attachmentsFolder, d.inboxFolder], ["Daily", "YYYY-MM-DD", "Templates", "Attachments", "Inbox"]);
});
test("merge: obsidian values override defaults", () => {
  const m = C.merge(C.defaults(), { daily: { folder: "Journal/", format: "DD-MM-YYYY", template: "Templates/Day" }, templates: { folder: "Tpl" }, app: { attachmentFolderPath: "assets" } }, {});
  assert.deepStrictEqual([m.dailyFolder, m.dailyFormat, m.dailyTemplate, m.templatesFolder, m.attachmentsFolder], ["Journal", "DD-MM-YYYY", "Templates/Day", "Tpl", "assets"]);
});
test("merge: plugin settings override obsidian; empty ones do not", () => {
  const m = C.merge(C.defaults(), { daily: { folder: "Journal" } }, { dailyFolder: "Mine", inboxFolder: "" });
  assert.deepStrictEqual([m.dailyFolder, m.inboxFolder], ["Mine", "Inbox"]);
});
test("merge: missing/blank obsidian config changes nothing", () => assert.deepStrictEqual(C.merge(C.defaults(), null, null), C.defaults()));
test("merge: folders are normalised (no leading/trailing slash)", () => assert.strictEqual(C.merge(C.defaults(), { daily: { folder: "/Journal/2026/" } }, {}).dailyFolder, "Journal/2026"));
test("merge: dot segments and doubled slashes are dropped", () => assert.strictEqual(C.merge(C.defaults(), { daily: { folder: "./a//b/../c/" } }, {}).dailyFolder, "a/b/c"));
test("dailyPath: characters a note name cannot have become dashes", () => assert.strictEqual(C.dailyPath({ dailyFolder: "D", dailyFormat: "YYYY-MM-DD HH:mm" }, D), "D/2026-09-04 07-05.md"));
test("attachmentDir: named folder, vault root, same folder, subfolder of the note's folder", () => {
  assert.strictEqual(C.attachmentDir({ attachmentsFolder: "assets" }, "a/n.md"), "assets");
  assert.strictEqual(C.attachmentDir({ attachmentsFolder: "/" }, "a/n.md"), "");
  assert.strictEqual(C.attachmentDir({ attachmentsFolder: "./" }, "a/n.md"), "a");
  assert.strictEqual(C.attachmentDir({ attachmentsFolder: "./files" }, "a/n.md"), "a/files");
  assert.strictEqual(C.attachmentDir({ attachmentsFolder: "./files" }, "n.md"), "files");
});
test("dailyPath: folder + formatted name", () => assert.strictEqual(C.dailyPath({ dailyFolder: "Daily", dailyFormat: "YYYY-MM-DD" }, D), "Daily/2026-09-04.md"));
test("dailyPath: formats with slashes make sub folders; empty folder = root", () => assert.strictEqual(C.dailyPath({ dailyFolder: "", dailyFormat: "YYYY/MM/DD" }, D), "2026/09/04.md"));
test("newNoteDir: current folder / root / fixed folder", () => {
  assert.strictEqual(C.newNoteDir({ newFileLocation: "current" }, "A/B"), "A/B");
  assert.strictEqual(C.newNoteDir({ newFileLocation: "root" }, "A/B"), "");
  assert.strictEqual(C.newNoteDir({ newFileLocation: "folder", newFileFolder: "Inbox" }, "A"), "Inbox");
  assert.strictEqual(C.newNoteDir({}, "A"), "A");
});
console.log("config.js: " + passed + " passed" + (process.exitCode ? " (with failures)" : ""));
