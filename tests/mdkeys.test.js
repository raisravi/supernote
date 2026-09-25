const assert = require("assert");
const raw = require("./load")(__dirname + "/../js/mdkeys.js");
const j = x => (x === undefined || x === null ? x : JSON.parse(JSON.stringify(x)));
const K = new Proxy({}, { get: (_, k) => (...a) => j(raw[k](...a)) });
let passed = 0;
function test(name, fn) { try { fn(); passed++; } catch (e) { console.error("FAIL: " + name + "\n  " + e.message.split("\n").join("\n  ")); process.exitCode = 1; } }

// Qt key codes
const Key = { Return: 0x01000004, Enter: 0x01000005, Tab: 0x01000001, Backtab: 0x01000002, B: 0x42, I: 0x49, K: 0x4B, L: 0x4C, X: 0x58, C: 0x43, V: 0x56, N1: 0x31, N0: 0x30, BracketRight: 0x5D, BracketLeft: 0x5B, A: 0x41 };
const ev = (key, o) => Object.assign({ key, ctrl: false, shift: false, alt: false, text: "" }, o || {});
// run handle on "abc|def" style text ('|' caret, '«' '»' selection) and return the resulting text with markers
function run(marked, e) {
  let s, en, text;
  const a = marked.indexOf("«");
  if (a >= 0) { text = marked.replace("«", "").replace("»", ""); s = a; en = marked.indexOf("»") - 1; }
  else { s = en = marked.indexOf("|"); text = marked.replace("|", ""); }
  const ed = K.handle(text, s, en, e);
  if (!ed) return null;
  const out = text.slice(0, ed.start) + ed.text + text.slice(ed.end);
  return ed.selStart === ed.selEnd ? out.slice(0, ed.selStart) + "|" + out.slice(ed.selStart) : out.slice(0, ed.selStart) + "«" + out.slice(ed.selStart, ed.selEnd) + "»" + out.slice(ed.selEnd);
}

test("Enter continues a bullet list", () => assert.strictEqual(run("- one|", ev(Key.Return)), "- one\n- |"));
test("Enter continues a numbered list", () => assert.strictEqual(run("1. a|", ev(Key.Enter)), "1. a\n2. |"));
test("Enter continues a task and a quote", () => { assert.strictEqual(run("- [ ] t|", ev(Key.Return)), "- [ ] t\n- [ ] |"); assert.strictEqual(run("> q|", ev(Key.Return)), "> q\n> |"); });
test("Enter on an empty list item ends the list", () => assert.strictEqual(run("- a\n- |", ev(Key.Return)), "- a\n|"));
test("Enter on plain text is left to the editor (null)", () => assert.strictEqual(run("plain|", ev(Key.Return)), null));
test("Shift+Enter is never handled", () => assert.strictEqual(run("- one|", ev(Key.Return, { shift: true })), null));
test("Enter with a selection is left to the editor", () => assert.strictEqual(run("- «one»", ev(Key.Return)), null));
test("Tab indents, Shift+Tab / Backtab outdents", () => {
  assert.strictEqual(run("a|", ev(Key.Tab)), "a    |");
  assert.strictEqual(run("    a|", ev(Key.Tab, { shift: true })), "a|");
  assert.strictEqual(run("    a|", ev(Key.Backtab)), "a|");
});
test("Ctrl+] / Ctrl+[ indent and outdent", () => {
  assert.strictEqual(run("a|", ev(Key.BracketRight, { ctrl: true })), "a    |");
  assert.strictEqual(run("    a|", ev(Key.BracketLeft, { ctrl: true })), "a|");
});
test("Ctrl+B / I wrap the selection", () => {
  assert.strictEqual(run("«word»", ev(Key.B, { ctrl: true })), "**«word»**");
  assert.strictEqual(run("«word»", ev(Key.I, { ctrl: true })), "*«word»*");
});
test("Ctrl+Shift+X strikes, Ctrl+Shift+C codes", () => {
  assert.strictEqual(run("«w»", ev(Key.X, { ctrl: true, shift: true })), "~~«w»~~");
  assert.strictEqual(run("«w»", ev(Key.C, { ctrl: true, shift: true })), "`«w»`");
});
test("Ctrl+L toggles a task, Ctrl+K inserts a link", () => {
  assert.strictEqual(run("item|", ev(Key.L, { ctrl: true })), "- [ ] item|");
  assert.ok(run("«text»", ev(Key.K, { ctrl: true })).indexOf("[") >= 0);
});
test("Ctrl+1 makes a heading, Ctrl+0 clears it", () => {
  assert.strictEqual(run("title|", ev(Key.N1, { ctrl: true })), "# title|");
  assert.strictEqual(run("## title|", ev(Key.N0, { ctrl: true })), "title|");
});
test("unhandled Ctrl / Alt combos return null (paste, select all, alt-nav)", () => {
  assert.strictEqual(run("a|", ev(Key.V, { ctrl: true })), null);
  assert.strictEqual(run("a|", ev(Key.A, { ctrl: true })), null);
  assert.strictEqual(run("a|", ev(Key.B, { alt: true })), null);
  assert.strictEqual(run("a|", ev(Key.Tab, { alt: true })), null);
});
test("typing an opener auto-pairs, a closer skips over", () => {
  assert.strictEqual(run("a|", ev(0x28, { text: "(" })), "a(|)");
  assert.strictEqual(run("(x|)", ev(0x29, { text: ")" })), "(x)|");
});
test("[[ pairs to [[]]", () => assert.strictEqual(run("[|]", ev(0x5B, { text: "[" })), "[[|]]"));
test("ordinary characters are left to the editor", () => assert.strictEqual(run("a|", ev(0x62, { text: "b" })), null));
test("format(): named commands used by the toolbar", () => {
  assert.strictEqual(K.format("bold", "x", 0, 1).text, "**x**");
  assert.strictEqual(K.format("nope", "x", 0, 1), null);
});
console.log("mdkeys.js: " + passed + " passed" + (process.exitCode ? " (with failures)" : ""));
