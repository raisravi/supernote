const assert = require("assert");
const raw = require("./load")(__dirname + "/../js/markdown.js");
const j = x => (x === undefined || x === null ? x : JSON.parse(JSON.stringify(x)));

let passed = 0;
function test(name, fn) {
  try { fn(); passed++; } catch (e) { console.error("FAIL: " + name + "\n  " + e.message.split("\n").join("\n  ")); process.exitCode = 1; }
}

const notes = { "Note A": "Note A.md", "B": "sub/B.md" };
const embeds = { "Note A": "embedded body\n![[B]]\n- [ ] inner task" };
const ctx = {
  vaultAbs: "/v",
  noteDir: "",
  resolveNote: n => notes[n] || null,
  resolveAsset: (n, dir) => ({ "pic.png": "Attachments/pic.png", "my pic.png": "Attachments/my pic.png", "img/x.png": (dir ? dir + "/" : "") + "img/x.png" })[n] || null,
  getEmbed: n => (n in embeds ? embeds[n] : null),
};
const R = (text, c) => j(raw.renderPreview(text, Object.assign({}, ctx, c || {})));
const md = (text, c) => R(text, c).markdown;

// ---------- frontmatter ----------
test("frontmatter stripped, props returned", () => {
  const r = R("---\ntitle: T\n---\n# Hi");
  assert.deepStrictEqual(r.props, [{ key: "title", value: "T" }]);
  assert.strictEqual(r.markdown.trim(), "# Hi");
});

// ---------- wikilinks ----------
test("wikilink -> sn-note link", () => assert.strictEqual(md("see [[Note A]]."), "see [Note A](sn-note:Note%20A)."));
test("wikilink names with parentheses stay a valid link", () => assert.strictEqual(md("[[a (b)]]"), "[a (b)](sn-note:a%20%28b%29)"));
test("wikilink alias", () => assert.strictEqual(md("[[Note A|the note]]"), "[the note](sn-note:Note%20A)"));
test("wikilink heading", () => assert.strictEqual(md("[[Note A#Intro]]"), "[Note A > Intro](sn-note:Note%20A#Intro)"));
test("wikilink inside inline code untouched", () => assert.strictEqual(md("`[[Note A]]` and [[B]]"), "`[[Note A]]` and [B](sn-note:B)"));
test("fenced code untouched", () => assert.strictEqual(md("```\n[[Note A]] #tag\n```"), "```\n[[Note A]] #tag\n```"));

// ---------- tags ----------
test("tag -> sn-tag link", () => assert.strictEqual(md("a #alpha b"), "a [#alpha](sn-tag:alpha) b"));
test("nested tag", () => assert.strictEqual(md("#proj/x"), "[#proj/x](sn-tag:proj%2Fx)"));
test("heading marker and urls are not tags", () => assert.strictEqual(md("# Title\nhttp://a.b/#frag"), "# Title\nhttp://a.b/#frag"));

// ---------- tasks ----------
test("task -> clickable glyph carrying original line number", () => assert.strictEqual(md("- [ ] a\n- [x] b").split("\n")[0], "- [☐](sn-task:0) a"));
test("checked task glyph", () => assert.strictEqual(md("- [ ] a\n- [x] b").split("\n")[1], "- [☑](sn-task:1) b"));
test("task line numbers account for frontmatter", () => assert.strictEqual(md("---\na: b\n---\n- [ ] x"), "- [☐](sn-task:3) x"));

// ---------- callouts ----------
test("callout with title (hard break after the title)", () => assert.strictEqual(md("> [!warning] Careful\n> body"), "> **⚠ Careful**  \n> body"));
test("callout without title uses type", () => assert.strictEqual(md("> [!note]\n> body").split("\n")[0], "> **ⓘ Note**  "));
test("plain blockquote untouched", () => assert.strictEqual(md("> just a quote"), "> just a quote"));
test("consecutive quote lines keep their line breaks", () => assert.strictEqual(md("> a\n> b\n> c"), "> a  \n> b  \n> c"));

// ---------- footnotes ----------
test("footnotes: superscript refs + definitions list, defs removed from body", () => {
  const out = md("Text[^a] more[^b].\n\n[^a]: First.\n[^b]: Second.");
  assert.ok(out.startsWith("Text¹ more²."), out);
  assert.ok(!/\[\^a\]:/.test(out));
  assert.ok(/1\. First\./.test(out) && /2\. Second\./.test(out), out);
});
test("footnote without definition keeps ref text sane", () => assert.strictEqual(md("x[^q]"), "x[^q]"));

// ---------- images ----------
test("embed image by name", () => assert.strictEqual(md("![[pic.png]]"), "![pic.png](file:///v/Attachments/pic.png)"));
test("embed image with size suffix keeps the size in the alt (renderer turns it into a width)", () => assert.strictEqual(md("![[pic.png|300]]"), "![pic.png|300](file:///v/Attachments/pic.png)"));
test("markdown image resolved to file url, spaces encoded", () => assert.strictEqual(md("![a](my%20pic.png)"), "![a](file:///v/Attachments/my%20pic.png)"));
test("markdown image relative to note dir", () => assert.strictEqual(md("![a](img/x.png)", { noteDir: "sub" }), "![a](file:///v/sub/img/x.png)"));
test("remote image untouched", () => assert.strictEqual(md("![a](https://x.io/a.png)"), "![a](https://x.io/a.png)"));
test("missing image embed -> placeholder", () => assert.strictEqual(md("![[nope.png]]"), "*[missing image: nope.png]*"));

// ---------- note embeds ----------
test("note embed -> blockquote with body, tasks not toggleable", () => {
  const out = md("before\n\n![[Note A]]\n\nafter");
  assert.ok(out.includes("> **Note A**"), out);
  assert.ok(out.includes("> embedded body"), out);
  assert.ok(!out.includes("sn-task"), "embedded tasks must not be toggleable: " + out);
  assert.ok(out.includes("[B](sn-note:B)"), "nested embed degrades to a link: " + out);
});
test("unloaded embed -> link fallback", () => assert.strictEqual(md("![[Later]]"), "[Later](sn-note:Later)"));

// ---------- highlight ----------
test("==highlight== becomes private markers for the renderer", () => assert.strictEqual(md("a ==b== c"), "a \uE000b\uE001 c"));
test("== inside code is left alone", () => assert.strictEqual(md("`a == b == c`"), "`a == b == c`"));
test("== in a fence is left alone", () => assert.strictEqual(md("```\na == b == c\n```"), "```\na == b == c\n```"));

// ---------- line breaks ----------
test("single newlines in a paragraph become hard breaks", () => assert.strictEqual(md("one\ntwo\n\nthree"), "one  \ntwo\n\nthree"));
test("no hard break before a list or in lists/headings", () => {
  assert.strictEqual(md("intro\n- a\n- b"), "intro\n- a\n- b");
  assert.strictEqual(md("# H\ntext"), "# H\ntext");
});

// ---------- highlighter ----------
const C = { heading: "#h", bold: "#b", italic: "#i", code: "#c", codeBlock: "#cb", link: "#l", wikilink: "#w", tag: "#t", quote: "#q", marker: "#m", dim: "#d", strike: "#s", task: "#k", highlight: "#y" };
const H = text => raw.highlightHtml(text, C);
const decode = s => s.replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&amp;/g, "&");
const strip = h => decode(h.replace(/<[^>]+>/g, ""));

const corpus = [
  "", "plain text", "# Heading one\n## Two", "**bold** and *it* and _it2_ and ~~gone~~", "`code` and ``a`b``",
  "- [ ] task\n- [x] done\n1. one\n2) two", "> quote\n> > nested", "```js\nconst a = 1 < 2 && 3 > 1;\n```\nafter",
  "[[Wiki|alias]] ![[img.png]] [link](http://x.io?a=1&b=2) #tag/sub", "---\ntitle: x\n---\n# body", "unclosed **bold and `code",
  "a<b>c</b> &amp; &lt; <script>alert(1)</script>", "tab\tsep  trailing  ", "emoji 😀 ünïcode — dash", "snake_case_name and 2*3*4", "line1\r\nline2",
  "***", "___", "==mark== [^1] foot", "  indented `x`", "#notag? # nope #ok",
];
test("highlight: visible text is preserved exactly (alignment invariant)", () => {
  for (const t of corpus) assert.strictEqual(strip(H(t)), t.replace(/&/g, "&").toString(), "corpus item: " + JSON.stringify(t));
});
test("highlight: headings colored + bold", () => { const h = H("# Title"); assert.ok(h.includes("color:#h") && h.includes("<b>"), h); });
test("highlight: bold token", () => { const h = H("a **b** c"); assert.ok(/<b><span style="color:#b">\*\*b\*\*<\/span><\/b>/.test(h), h); });
test("highlight: inline code", () => assert.ok(H("x `y` z").includes("color:#c")));
test("highlight: fenced block lines use codeBlock color, delimiters included", () => {
  const h = H("```\nboth\n```");
  assert.strictEqual((h.match(/color:#cb/g) || []).length, 3, h);
});
test("highlight: nothing inside a fence is tokenized", () => assert.ok(!H("```\n**x** #t\n```").includes("color:#b")));
test("highlight: wikilink, link, tag, task", () => {
  const h = H("[[A]] [b](c) #t\n- [ ] x");
  assert.ok(h.includes("color:#w") && h.includes("color:#l") && h.includes("color:#t") && h.includes("color:#k"), h);
});
test("highlight: frontmatter dimmed", () => assert.ok(H("---\na: b\n---\nx").includes("color:#d")));
test("highlight: snake_case is not italic", () => assert.ok(!H("snake_case_name").includes("color:#i")));
test("highlight: html-like text is escaped", () => assert.ok(!H("<script>").includes("<script>")));

test("highlight: fuzz - visible text always equals input (3000 random markdown-ish strings)", () => {
  const alphabet = ["*", "_", "`", "#", "[", "]", "(", ")", "!", "~", "=", ">", "-", "+", "1", ".", " ", " ", "\n", "\n", "a", "b", "<", "&", "\t", "|", "^", ":", "x", "😀"];
  let seed = 12345;
  const rnd = n => { seed = (seed * 1103515245 + 12345) & 0x7fffffff; return seed % n; };
  for (let i = 0; i < 3000; i++) {
    let t = "";
    const len = rnd(60);
    for (let k = 0; k < len; k++) t += alphabet[rnd(alphabet.length)];
    assert.strictEqual(strip(H(t)), t, "input: " + JSON.stringify(t));
    raw.renderPreview(t, ctx); // must never throw
  }
});

// ---- math + mermaid ----
{
  const calls = [];
  const dctx = kind => Object.assign({}, ctx, {
    diagram: (k, src, display) => { calls.push([k, src, display]); return kind === "ready" ? { url: "file:///c/" + k + calls.length + ".png", w: 80 } : null; }
  });
  const md = (text, kind) => raw.renderPreview(text, dctx(kind || "ready")).markdown;
  test("inline math becomes an image (alt carries the width)", () => {
    calls.length = 0;
    assert.strictEqual(md("a $x^2$ b"), "a ![math|80](file:///c/math1.png) b");
    assert.deepStrictEqual(j(calls), [["math", "x^2", false]]);
  });
  test("inline math not ready yet is shown as a code chip (styled source)", () => assert.strictEqual(md("a $x^2$ b", "pending"), "a `$x^2$` b"));
  test("a $$ block not ready yet is shown as a code block", () => {
    assert.strictEqual(md("$$\na = b\nc = d\n$$", "pending"), "```tex\n$$\na = b\nc = d\n$$\n```");
    assert.strictEqual(md("$$a$$", "pending"), "```tex\n$$\na\n$$\n```");
  });
  test("pending math is only restyled when a renderer exists", () => assert.strictEqual(raw.renderPreview("a $x$ b\n\n$$y$$", ctx).markdown, "a $x$ b\n\n$$y$$"));
  test("mermaid inside a blockquote / callout becomes an image", () => {
    calls.length = 0;
    assert.strictEqual(md("> [!note] Flow\n> ```mermaid\n> graph TD\n>  A-->B\n> ```\n> after"), "> **ⓘ Flow**  \n> ![mermaid|80](file:///c/mermaid1.png)  \n> after");
    assert.deepStrictEqual(j(calls), [["mermaid", "graph TD\n A-->B", true]]);
  });
  test("mermaid in a blockquote not ready stays as it is", () => assert.strictEqual(md("> ```mermaid\n> graph TD\n> ```", "pending"), "> ```mermaid  \n> graph TD  \n> ```"));
  test("prices and lone dollars are not math", () => {
    calls.length = 0;
    assert.strictEqual(md("costs $5 and $6 today"), "costs $5 and $6 today");
    assert.strictEqual(md("a $ b $ c"), "a $ b $ c");
    assert.strictEqual(calls.length, 0);
  });
  test("escaped dollars are literal", () => { calls.length = 0; assert.strictEqual(md("\\$x\\$"), "\\$x\\$"); assert.strictEqual(calls.length, 0); });
  test("math inside inline code is untouched", () => { calls.length = 0; assert.strictEqual(md("`$x$`"), "`$x$`"); assert.strictEqual(calls.length, 0); });
  test("several inline formulas on a line", () => { calls.length = 0; md("$a$ and $b$"); assert.deepStrictEqual(j(calls.map(c => c[1])), ["a", "b"]); });
  test("$$ block on one line", () => {
    calls.length = 0;
    assert.strictEqual(md("before\n\n$$\\frac{a}{b}$$\n\nafter"), "before\n\n![math|80](file:///c/math1.png)\n\nafter");
    assert.deepStrictEqual(j(calls), [["math", "\\frac{a}{b}", true]]);
  });
  test("$$ block over several lines", () => {
    calls.length = 0;
    const out = md("$$\na = b\nc = d\n$$\nnext");
    assert.strictEqual(out.split("\n")[0].trim(), "![math|80](file:///c/math1.png)");
    assert.deepStrictEqual(j(calls), [["math", "a = b\nc = d", true]]);
    assert.ok(out.indexOf("next") > 0);
  });
  test("$$...$$ inside a line is display math", () => {
    calls.length = 0;
    assert.strictEqual(md("so $$E = mc^2$$ holds"), "so ![math|80](file:///c/math1.png) holds");
    assert.deepStrictEqual(j(calls), [["math", "E = mc^2", true]]);
  });
  test("two $$ blocks on a line are two formulas, not one garbled one", () => {
    calls.length = 0;
    md("$$a$$ and $$b$$");
    assert.deepStrictEqual(j(calls.map(c => c[1])), ["a", "b"]);
  });
  test("currency-looking spans are not math", () => {
    calls.length = 0;
    assert.strictEqual(md("it was $5 and 5$ total"), "it was $5 and 5$ total");
    assert.strictEqual(md("$5 or 6$ each"), "$5 or 6$ each");
    assert.strictEqual(calls.length, 0);
    md("$2^n$ and $5 + 3$");
    assert.deepStrictEqual(j(calls.map(c => c[1])), ["2^n", "5 + 3"]);
  });
  test("a ~~~ fence is not closed by a ``` fence", () => {
    calls.length = 0;
    const t = "~~~mermaid\ngraph TD\n```\nA-->B\n~~~";
    md(t);
    assert.deepStrictEqual(j(calls), [["mermaid", "graph TD\n```\nA-->B", true]]);
  });
  test("an unclosed $$ block is left alone", () => { calls.length = 0; assert.strictEqual(md("$$\nx"), "$$  \nx"); assert.strictEqual(calls.length, 0); });
  test("math inside a code fence is untouched", () => { calls.length = 0; md("```\n$x$\n$$y$$\n```"); assert.strictEqual(calls.length, 0); });
  test("mermaid fence becomes an image", () => {
    calls.length = 0;
    assert.strictEqual(md("```mermaid\ngraph TD\n A-->B\n```"), "![mermaid|80](file:///c/mermaid1.png)");
    assert.deepStrictEqual(j(calls), [["mermaid", "graph TD\n A-->B", true]]);
  });
  test("mermaid not ready stays a code block", () => assert.strictEqual(md("```mermaid\ngraph TD\n```", "pending"), "```mermaid\ngraph TD\n```"));
  test("other fences are not diagrams", () => { calls.length = 0; md("```js\nlet a = $x$;\n```"); assert.strictEqual(calls.length, 0); });
  test("without ctx.diagram nothing changes", () => assert.strictEqual(raw.renderPreview("a $x$ b\n\n$$y$$", ctx).markdown, "a $x$ b\n\n$$y$$"));
  test("embedded notes render their math too", () => {
    calls.length = 0;
    const c = Object.assign({}, dctx("ready"), { getEmbed: () => "inside $z$" });
    raw.renderPreview("![[Note A]]", c);
    assert.deepStrictEqual(j(calls.map(x => x[1])), ["z"]);
  });
}

console.log("markdown.js (preview/highlight): " + passed + " passed" + (process.exitCode ? " (with failures)" : ""));
