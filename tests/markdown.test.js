const assert = require("assert");
const raw = require("./load")(__dirname + "/../js/markdown.js");
const j = x => (x === undefined || x === null ? x : JSON.parse(JSON.stringify(x))); // vm realm -> main realm
const M = new Proxy({}, { get: (_, k) => (...a) => j(raw[k](...a)) });

let passed = 0;
function test(name, fn) {
  try { fn(); passed++; } catch (e) { console.error("FAIL: " + name + "\n  " + e.message.split("\n").join("\n  ")); process.exitCode = 1; }
}
const apply = (text, ed) => text.slice(0, ed.start) + ed.text + text.slice(ed.end);
// "abc|def" style: '|' = caret, '«' '»' = selection
function parse(s) {
  const a = s.indexOf("«"), b = s.indexOf("»"), c = s.indexOf("|");
  if (a >= 0 && b > a) return { text: s.replace("«", "").replace("»", ""), s: a, e: b - 1 };
  return { text: s.replace("|", ""), s: c, e: c };
}
function show(text, ed) {
  const t = apply(text, ed);
  const s = ed.selStart, e = ed.selEnd;
  return s === e ? t.slice(0, s) + "|" + t.slice(s) : t.slice(0, s) + "«" + t.slice(s, e) + "»" + t.slice(e);
}
const run = (fn, input, ...args) => { const p = parse(input); const ed = fn(p.text, p.s, p.e, ...args); return ed ? show(p.text, ed) : null; };

// ---------- wrapSelection ----------
test("wrap: empty selection inserts pair, caret inside", () => assert.strictEqual(run(M.wrapSelection, "ab|cd", "**", "**"), "ab**|**cd"));
test("wrap: selection gets wrapped, stays selected", () => assert.strictEqual(run(M.wrapSelection, "a«bc»d", "**", "**"), "a**«bc»**d"));
test("wrap: unwrap when surrounded", () => assert.strictEqual(run(M.wrapSelection, "a**«bc»**d", "**", "**"), "a«bc»d"));
test("wrap: unwrap when selection includes markers", () => assert.strictEqual(run(M.wrapSelection, "a«**bc**»d", "**", "**"), "a«bc»d"));
test("wrap: italic single char markers", () => assert.strictEqual(run(M.wrapSelection, "«x»", "*", "*"), "*«x»*"));
test("wrap: bold selection inside italic markers is not confused", () => assert.strictEqual(run(M.wrapSelection, "*«x»*", "**", "**"), "***«x»***"));

// ---------- setHeading ----------
const heading = (input, level) => run(M.setHeading, input, level);
test("heading: adds level", () => assert.strictEqual(heading("ti|tle", 2), "## ti|tle"));
test("heading: replaces other level", () => assert.strictEqual(heading("# ti|tle", 3), "### ti|tle"));
test("heading: same level toggles off", () => assert.strictEqual(heading("## ti|tle", 2), "ti|tle"));
test("heading: level 0 removes", () => assert.strictEqual(heading("### ti|tle", 0), "ti|tle"));
test("heading: only current line", () => assert.strictEqual(heading("a\nb|b\nc", 1), "a\n# b|b\nc"));
test("heading: multi-line selection", () => assert.strictEqual(heading("«a\nb»\nc", 2), "## «a\n## b»\nc"));

// ---------- toggleTask ----------
const task = input => run(M.toggleTask, input);
test("task: plain line becomes task", () => assert.strictEqual(task("buy m|ilk"), "- [ ] buy m|ilk"));
test("task: bullet becomes task", () => assert.strictEqual(task("- it|em"), "- [ ] it|em"));
test("task: numbered item becomes task", () => assert.strictEqual(task("1. it|em"), "1. [ ] it|em"));
test("task: unchecked -> checked", () => assert.strictEqual(task("- [ ] it|em"), "- [x] it|em"));
test("task: checked -> unchecked", () => assert.strictEqual(task("- [x] it|em"), "- [ ] it|em"));
test("task: keeps indent", () => assert.strictEqual(task("  - it|em"), "  - [ ] it|em"));
test("task: empty line", () => assert.strictEqual(task("|"), "- [ ] |"));

// ---------- indentLines ----------
test("indent: list item", () => assert.strictEqual(run(M.indentLines, "- a|b", 1), "    - a|b"));
test("indent: outdent list item", () => assert.strictEqual(run(M.indentLines, "    - a|b", -1), "- a|b"));
test("indent: outdent partial (2 spaces)", () => assert.strictEqual(run(M.indentLines, "  - a|b", -1), "- a|b"));
test("indent: outdent tab", () => assert.strictEqual(run(M.indentLines, "\t- a|b", -1), "- a|b"));
test("indent: outdent nothing to remove", () => assert.strictEqual(run(M.indentLines, "- a|b", -1), "- a|b"));
test("indent: plain line, no selection, inserts 4 spaces at caret", () => assert.strictEqual(run(M.indentLines, "he|llo", 1), "he    |llo"));
test("indent: multi-line selection indents every line", () => assert.strictEqual(run(M.indentLines, "«a\nb»", 1), "«    a\n    b»"));

// ---------- continueList ----------
const cont = input => { const p = parse(input); const ed = M.continueList(p.text, p.s); return ed ? show(p.text, ed) : null; };
test("enter: bullet continues", () => assert.strictEqual(cont("- one|"), "- one\n- |"));
test("enter: star bullet continues", () => assert.strictEqual(cont("* one|"), "* one\n* |"));
test("enter: number increments", () => assert.strictEqual(cont("3. three|"), "3. three\n4. |"));
test("enter: paren number increments", () => assert.strictEqual(cont("1) one|"), "1) one\n2) |"));
test("enter: task continues unchecked", () => assert.strictEqual(cont("- [x] done|"), "- [x] done\n- [ ] |"));
test("enter: keeps indent", () => assert.strictEqual(cont("    - nested|"), "    - nested\n    - |"));
test("enter: empty item exits list", () => assert.strictEqual(cont("- one\n- |"), "- one\n|"));
test("enter: empty nested item outdents", () => assert.strictEqual(cont("- a\n    - |"), "- a\n- |"));
test("enter: empty task item exits", () => assert.strictEqual(cont("- [ ] |"), "|"));
test("enter: splits mid-line and carries the rest", () => assert.strictEqual(cont("- ab|cd"), "- ab\n- |cd"));
test("enter: blockquote continues", () => assert.strictEqual(cont("> quote|"), "> quote\n> |"));
test("enter: empty quote exits", () => assert.strictEqual(cont("> a\n> |"), "> a\n|"));
test("enter: plain line -> null (default behaviour)", () => assert.strictEqual(cont("plain|"), null));
test("enter: caret inside the marker -> null", () => assert.strictEqual(cont("-| item"), null));
test("enter: number list continues in the middle of a document", () => assert.strictEqual(cont("x\n1. a|\ny"), "x\n1. a\n2. |\ny"));

// ---------- pairInput ----------
const pair = (input, ch) => { const p = parse(input); const ed = M.pairInput(p.text, p.s, p.e, ch); return ed ? show(p.text, ed) : null; };
test("pair: ( inserts pair", () => assert.strictEqual(pair("a|", "("), "a(|)"));
test("pair: [ inserts pair", () => assert.strictEqual(pair("|", "["), "[|]"));
test("pair: [ inside [] makes [[]]", () => assert.strictEqual(pair("[|]", "["), "[[|]]"));
test("pair: wraps selection", () => assert.strictEqual(pair("a«bc»d", "("), "a(«bc»)d"));
test("pair: closer skips over existing closer", () => assert.strictEqual(pair("(a|)", ")"), "(a)|"));
test("pair: closer with nothing to skip -> null", () => assert.strictEqual(pair("a|", ")"), null));
test("pair: no pairing right before a word char", () => assert.strictEqual(pair("|word", "("), null));
test("pair: backtick pairs", () => assert.strictEqual(pair("|", "`"), "`|`"));
test("pair: other chars -> null", () => assert.strictEqual(pair("|", "a"), null));

// ---------- togglePrefix (bullet / quote from the toolbar) ----------
test("prefix: adds bullet", () => assert.strictEqual(run(M.togglePrefix, "ab|c", "- "), "- ab|c"));
test("prefix: removes bullet when present", () => assert.strictEqual(run(M.togglePrefix, "- ab|c", "- "), "ab|c"));
test("prefix: quote on multiple lines", () => assert.strictEqual(run(M.togglePrefix, "«a\nb»", "> "), "> «a\n> b»"));
test("prefix: mixed lines -> only lines lacking it get it", () => assert.strictEqual(run(M.togglePrefix, "«- a\nb»", "- "), "«- a\n- b»"));
test("prefix: keeps indent", () => assert.strictEqual(run(M.togglePrefix, "  x|", "- "), "  - x|"));

// ---------- insertLink ----------
test("link: selection becomes text, url selected", () => assert.strictEqual(run(M.insertLink, "a«bc»d"), "a[bc](«url»)d"));
test("link: no selection", () => assert.strictEqual(run(M.insertLink, "a|b"), "a[|](url)b"));
test("link: selected url becomes the target", () => assert.strictEqual(run(M.insertLink, "«https://x.io»"), "[|](https://x.io)"));

// ---------- headings / tags / frontmatter ----------
test("headings: levels, lines, fences ignored", () => {
  const h = M.extractHeadings("# A\ntext\n```\n# not\n```\n## B\n");
  assert.deepStrictEqual(h.map(x => [x.level, x.text, x.line]), [[1, "A", 0], [2, "B", 5]]);
});
test("headings: frontmatter ignored", () => assert.deepStrictEqual(M.extractHeadings("---\n# no\n---\n# yes").map(x => x.text), ["yes"]));
test("tags: inline, nested, unique, not headings/code/urls", () => {
  const t = M.extractTags("# Title\nhello #alpha and #proj/x, again #alpha\n`#code` http://a.b/#frag\n```\n#fenced\n```\n");
  assert.deepStrictEqual(t.sort(), ["alpha", "proj/x"]);
});
test("tags: frontmatter list and inline forms", () => {
  assert.deepStrictEqual(M.extractTags("---\ntags: [one, two]\n---\nx").sort(), ["one", "two"]);
  assert.deepStrictEqual(M.extractTags("---\ntags:\n  - a\n  - b/c\n---\nx").sort(), ["a", "b/c"]);
});
test("frontmatter: parse scalars, lists, body offset", () => {
  const fm = M.parseFrontmatter("---\ntitle: Hello\ntags: [a, b]\nlist:\n  - x\n  - y\n---\nbody\nmore");
  assert.deepStrictEqual(fm.props, [{ key: "title", value: "Hello" }, { key: "tags", value: ["a", "b"] }, { key: "list", value: ["x", "y"] }]);
  assert.strictEqual(fm.body, "body\nmore");
  assert.strictEqual(fm.bodyLine, 7);
});
test("frontmatter: none -> untouched", () => {
  const fm = M.parseFrontmatter("# T\ntext");
  assert.deepStrictEqual(fm.props, []); assert.strictEqual(fm.body, "# T\ntext"); assert.strictEqual(fm.bodyLine, 0);
});
test("frontmatter: unclosed is not frontmatter", () => assert.strictEqual(M.parseFrontmatter("---\na: b\nno end").props.length, 0));

// ---------- find / replace ----------
test("find: case-insensitive default", () => assert.deepStrictEqual(M.findAll("Foo foo FOO", "foo", {}), [{ start: 0, end: 3 }, { start: 4, end: 7 }, { start: 8, end: 11 }]));
test("find: case-sensitive", () => assert.deepStrictEqual(M.findAll("Foo foo", "foo", { caseSensitive: true }), [{ start: 4, end: 7 }]));
test("find: regex", () => assert.deepStrictEqual(M.findAll("a1 b22", "\\d+", { regex: true }), [{ start: 1, end: 2 }, { start: 4, end: 6 }]));
test("find: literal chars are escaped when not regex", () => assert.strictEqual(M.findAll("a.b axb", "a.b", {}).length, 1));
test("find: bad regex -> no matches, no throw", () => assert.deepStrictEqual(M.findAll("abc", "(", { regex: true }), []));
test("find: empty query -> none", () => assert.deepStrictEqual(M.findAll("abc", "", {}), []));
test("replaceAll: count and text", () => assert.deepStrictEqual(M.replaceAll("a-a-a", "a", "b", {}), { text: "b-b-b", count: 3 }));
test("replaceAll: literal replacement ($ not special)", () => assert.strictEqual(M.replaceAll("x", "x", "$&", {}).text, "$&"));
test("replaceAll: regex groups", () => assert.strictEqual(M.replaceAll("ab", "(a)(b)", "$2$1", { regex: true }).text, "ba"));

// ---------- checkbox toggle from preview ----------
test("toggleCheckboxAtLine: unchecked -> checked", () => assert.strictEqual(M.toggleCheckboxAtLine("a\n- [ ] x\nb", 1), "a\n- [x] x\nb"));
test("toggleCheckboxAtLine: checked -> unchecked", () => assert.strictEqual(M.toggleCheckboxAtLine("- [X] x", 0), "- [ ] x"));
test("toggleCheckboxAtLine: not a task -> unchanged", () => assert.strictEqual(M.toggleCheckboxAtLine("- x", 0), "- x"));

// ---------- links: extraction, [[ autocomplete, heading lookup ----------
test("extractLinks: wikilinks with heading/alias/embed, in order", () => {
  const l = M.extractLinks("a [[A]] b [[B#Sec|shown]] c ![[C]]");
  assert.deepStrictEqual(l.map(x => [x.name, x.heading, x.alias, x.embed]), [["A", "", "", false], ["B", "Sec", "shown", false], ["C", "", "", true]]);
});
test("extractLinks: line numbers", () => assert.deepStrictEqual(M.extractLinks("x\n\n[[A]]").map(x => x.line), [2]));
test("extractLinks: ignores code and frontmatter, trims names, skips empty", () => {
  const l = M.extractLinks("---\nrelated: [[FM]]\n---\n`[[Inline]]` [[ Real ]] [[]]\n```\n[[Fenced]]\n```");
  assert.deepStrictEqual(l.map(x => x.name), ["Real"]);
});
test("linkContext: inside an unfinished [[", () => {
  assert.deepStrictEqual(M.linkContext("see [[Pro", 9), { start: 6, query: "Pro" });
  assert.deepStrictEqual(M.linkContext("[[", 2), { start: 2, query: "" });
  assert.deepStrictEqual(M.linkContext("[[a]] [[b", 9), { start: 8, query: "b" });
});
test("linkContext: works with the auto-paired closing brackets after the caret", () => assert.deepStrictEqual(M.linkContext("[[ab]]", 4), { start: 2, query: "ab" }));
test("linkContext: null when finished, aliased, heading-part, multi-line or plain text", () => {
  assert.strictEqual(M.linkContext("[[a]] b", 7), null);
  assert.strictEqual(M.linkContext("[[a|b", 5), null);
  assert.strictEqual(M.linkContext("[[a#b", 5), null);
  assert.strictEqual(M.linkContext("[[a\nb", 5), null);
  assert.strictEqual(M.linkContext("no links", 4), null);
});
test("completeLink: replaces the query and steps past the auto-paired ]]", () => {
  const p = parse("see [[Pro|]]"); const ed = M.completeLink(p.text, p.s, "Project");
  assert.strictEqual(show(p.text, ed), "see [[Project]]|");
});
test("completeLink: adds ]] when missing, tolerates a single ]", () => {
  let p = parse("see [[Pro|"); assert.strictEqual(show(p.text, M.completeLink(p.text, p.s, "Project")), "see [[Project]]|");
  p = parse("[[Pro|]"); assert.strictEqual(show(p.text, M.completeLink(p.text, p.s, "Project")), "[[Project]]|");
});
test("completeLink: null outside a link", () => assert.strictEqual(M.completeLink("plain", 5, "X"), null));
test("headingOffset: finds a heading case-insensitively, ignores fences", () => {
  assert.strictEqual(M.headingOffset("# Intro\ntext\n## Deep  Dive\n", "deep dive"), 13);
  assert.strictEqual(M.headingOffset("```\n# Not\n```\n", "not"), -1);
  assert.strictEqual(M.headingOffset("# A", "missing"), -1);
});


// ---- properties editing ----
{
  const sp = (...a) => M.setProperty(...a);
  test("setProperty: replaces a scalar value in place", () => assert.strictEqual(sp("---\ntitle: Old\nx: 1\n---\nbody", "title", "New"), "---\ntitle: New\nx: 1\n---\nbody"));
  test("setProperty: adds a missing key before the closing fence", () => assert.strictEqual(sp("---\na: 1\n---\nbody", "b", "2"), "---\na: 1\nb: 2\n---\nbody"));
  test("setProperty: creates frontmatter when there is none", () => assert.strictEqual(sp("body\n", "status", "draft"), "---\nstatus: draft\n---\nbody\n"));
  test("setProperty: list values are written inline and replace block lists", () => assert.strictEqual(sp("---\ntags:\n  - a\n  - b\nz: 1\n---\n", "tags", ["x", "y z"]), "---\ntags: [x, y z]\nz: 1\n---\n"));
  test("setProperty: values needing quotes are quoted", () => {
    assert.strictEqual(sp("---\na: 1\n---\n", "a", "x: y"), '---\na: "x: y"\n---\n');
    assert.strictEqual(sp("---\na: 1\n---\n", "a", "#tag"), '---\na: "#tag"\n---\n');
  });
  test("setProperty: round-trips through parseFrontmatter", () => {
    const t = sp("---\na: 1\n---\nb", "tags", ["p", "q"]);
    assert.deepStrictEqual(JSON.parse(JSON.stringify(M.parseFrontmatter(t).props.find(x => x.key === "tags").value)), ["p", "q"]);
  });
  test("removeProperty: drops the key (and its list lines)", () => assert.strictEqual(M.removeProperty("---\ntags:\n  - a\nz: 1\n---\nb", "tags"), "---\nz: 1\n---\nb"));
  test("removeProperty: removing the last key removes the block", () => assert.strictEqual(M.removeProperty("---\nz: 1\n---\nbody", "z"), "body"));
  test("removeProperty: missing key / no frontmatter is a no-op", () => { assert.strictEqual(M.removeProperty("x", "a"), "x"); assert.strictEqual(M.removeProperty("---\na: 1\n---\n", "b"), "---\na: 1\n---\n"); });
}
// ---- linkAt: the wikilink under a text offset ----
{
  const at = (marked) => { const o = marked.indexOf("|"); return M.linkAt(marked.replace("|", ""), o); };
  test("linkAt: inside a link", () => assert.deepStrictEqual(at("see [[No|te]] now"), { name: "Note", heading: "", alias: "", embed: false }));
  test("linkAt: on the brackets counts", () => { assert.strictEqual(at("|[[Note]]").name, "Note"); assert.strictEqual(at("[[Note]]|").name, "Note"); });
  test("linkAt: heading and alias", () => assert.deepStrictEqual(M.linkAt("[[Note#Sec|al]]", 3), { name: "Note", heading: "Sec", alias: "al", embed: false }));
  test("linkAt: embeds are reported as such", () => assert.strictEqual(at("![[Note|]]").embed, true));
  test("linkAt: outside any link", () => { assert.strictEqual(at("a| [[Note]]"), null); assert.strictEqual(at("[[Note]] b|c"), null); });
  test("linkAt: second link on a line", () => assert.strictEqual(M.linkAt("[[A]] and [[B|b]]", 13).name, "B"));
  test("linkAt: code spans and fences do not count", () => {
    assert.strictEqual(at("`[[No|te]]`"), null);
    assert.strictEqual(M.linkAt("```\n[[Note]]\n```", 6), null);
  });
  test("linkAt: link on a later line", () => assert.strictEqual(M.linkAt("first\nsee [[Note]]", 12).name, "Note"));
  test("linkAt: empty target is not a link", () => assert.strictEqual(at("[[|]]"), null));
}

console.log("markdown.js (editing/extraction/find): " + passed + " passed" + (process.exitCode ? " (with failures)" : ""));
