const assert = require("assert");
const rawC = require("./load")(__dirname + "/../js/capture.js");
const rawT = require("./load")(__dirname + "/../js/templates.js");
const j = x => (x === undefined || x === null ? x : JSON.parse(JSON.stringify(x)));
const C = new Proxy({}, { get: (_, k) => (...a) => j(rawC[k](...a)) });
const T = new Proxy({}, { get: (_, k) => (...a) => j(rawT[k](...a)) });
let passed = 0;
function test(name, fn) { try { fn(); passed++; } catch (e) { console.error("FAIL: " + name + "\n  " + e.message.split("\n").join("\n  ")); process.exitCode = 1; } }
const D = new Date(2026, 8, 4, 7, 5, 9);

// ---- templates ----
test("title/date/time variables", () => assert.deepStrictEqual(T.apply("# {{title}}\n{{date}} {{time}}", { title: "Plan", date: D }), { text: "# Plan\n2026-09-04 07:05", cursor: -1 }));
test("formatted date/time", () => assert.strictEqual(T.apply("{{date:dddd}} / {{time:HH.mm.ss}}", { title: "x", date: D }).text, "Friday / 07.05.09"));
test("cursor marker is removed and its offset reported", () => assert.deepStrictEqual(T.apply("a {{cursor}}b", { title: "x", date: D }), { text: "a b", cursor: 2 }));
test("only the first cursor marker counts; others vanish", () => assert.deepStrictEqual(T.apply("{{cursor}}x{{cursor}}", { title: "x", date: D }), { text: "x", cursor: 0 }));
test("unknown variables are left as they are", () => assert.strictEqual(T.apply("{{nope}} {{Title}}", { title: "T", date: D }).text, "{{nope}} {{Title}}"));
test("cursor offset accounts for earlier substitutions", () => assert.strictEqual(T.apply("{{title}}{{cursor}}", { title: "Hello", date: D }).cursor, 5));

// ---- capture ----
test("append to an empty note creates the Captures section", () => assert.strictEqual(C.appendCapture("", "buy milk", D), "## Captures\n- 07:05 buy milk\n"));
test("append to a note without the section adds it at the end", () => assert.strictEqual(C.appendCapture("# Day\ntext\n", "idea", D), "# Day\ntext\n\n## Captures\n- 07:05 idea\n"));
test("append inside an existing section, after its last item", () => {
  const t = "# Day\n\n## Captures\n- 06:00 first\n\n## Notes\nbody\n";
  assert.strictEqual(C.appendCapture(t, "second", D), "# Day\n\n## Captures\n- 06:00 first\n- 07:05 second\n\n## Notes\nbody\n");
});
test("section at the end of file without trailing newline", () => assert.strictEqual(C.appendCapture("## Captures\n- 06:00 a", "b", D), "## Captures\n- 06:00 a\n- 07:05 b\n"));
test("multi-line captures indent continuation lines", () => assert.strictEqual(C.appendCapture("", "one\ntwo", D), "## Captures\n- 07:05 one\n  two\n"));
test("a Captures heading inside a code fence is ignored", () => assert.ok(C.appendCapture("```\n## Captures\n```\n", "x", D).endsWith("\n\n## Captures\n- 07:05 x\n")));
test("empty section gets its first item directly below the heading", () => assert.strictEqual(C.appendCapture("## Captures\n\n## Other\n", "x", D), "## Captures\n- 07:05 x\n\n## Other\n"));
test("inboxTitle: first line, markdown noise and illegal characters stripped", () => assert.strictEqual(C.inboxTitle("\n## Call: *Sam* / [[Bob]]?\nmore", D), "Call Sam Bob"));
test("inboxTitle: capped at 60 chars", () => assert.ok(C.inboxTitle("x".repeat(200), D).length <= 60));
test("inboxTitle: falls back to a timestamp", () => assert.strictEqual(C.inboxTitle("???", D), "Capture 2026-09-04 0705"));
console.log("capture.js/templates.js: " + passed + " passed" + (process.exitCode ? " (with failures)" : ""));
