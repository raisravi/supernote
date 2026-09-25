const assert = require("assert");
const raw = require("./load")(__dirname + "/../js/previewhtml.js");
let passed = 0;
function test(name, fn) { try { fn(); passed++; } catch (e) { console.error("FAIL: " + name + "\n  " + e.message.split("\n").join("\n  ")); process.exitCode = 1; } }

const C = { link: "#lnk", highlight: "#hl1", mono: "Fira Code", codeText: "#c1", codeBg: "#c2", quoteBar: "#q1", border: "#b1", headBg: "#h1",
  calloutNote: "#n1", calloutWarn: "#w1", calloutDanger: "#d1", calloutOk: "#o1", calloutTip: "#t1" };
const H = md => raw.renderHtml(md, C);

test("links keep their href (sn-note / sn-task / http)", () => {
  const h = H("[a](sn-note:X) [☐](sn-task:3) [w](https://x.io)");
  assert.ok(h.includes('<a href="sn-note:X">a</a>'), h);
  assert.ok(h.includes('<a href="sn-task:3">☐</a>'), h);
  assert.ok(h.includes('<a href="https://x.io">w</a>'), h);
});
test("raw html in notes is escaped, never passed through", () => {
  const h = H("hi <script>alert(1)</script> <b>x</b>");
  assert.ok(!h.includes("<script>") && !h.includes("<b>x</b>"), h);
  assert.ok(h.includes("&lt;script&gt;"), h);
});
test("file:// image urls survive", () => assert.ok(H("![a](file:///v/my%20pic.png)").includes('src="file:///v/my%20pic.png"')));
test("image size suffix in alt becomes a width attribute", () => {
  const h = H("![pic.png|300](file:///v/a.png)");
  assert.ok(/<img src="file:\/\/\/v\/a\.png" alt="pic\.png" width="300">/.test(h), h);
});
test("image without size has no width attribute", () => assert.ok(!/width=/.test(H("![a](file:///v/a.png)")) || !H("![a](file:///v/a.png)").includes('<img src="file:///v/a.png" alt="a" width')));
test("fenced code -> shaded table cell, content escaped", () => {
  const h = H("```js\nconst x = 1 < 2;\n```");
  assert.ok(h.includes('bgcolor="#c2"') && h.includes("1 &lt; 2") && h.includes("Fira Code"), h);
  assert.ok(!h.includes("<code"), h);
});
test("inline code is styled", () => {
  const h = H("use `npm i` now");
  assert.ok(h.includes('font-family:Fira Code') && h.includes("color:#c1") && h.includes("npm i"), h);
  assert.ok(!h.includes("<code"), h);
});
test("blockquote -> bar + content cell; nesting gives two bars", () => {
  const one = H("> quoted");
  assert.ok(one.includes('bgcolor="#q1"') && one.includes("quoted"), one);
  const two = H("> a\n>\n> > b");
  assert.strictEqual((two.match(/bgcolor="#q1"/g) || []).length, 2, two);
});
test("callout tints by type icon", () => {
  assert.ok(H("> **⚠ Careful**  \n> body").includes('bgcolor="#w1"'));
  assert.ok(H("> **✖ Boom**  \n> body").includes('bgcolor="#d1"'));
  assert.ok(H("> **✔ Yay**  \n> body").includes('bgcolor="#o1"'));
  assert.ok(H("> **ⓘ Note**  \n> body").includes('bgcolor="#n1"'));
  assert.ok(!H("> **ⓘ Note**  \n> body").includes('bgcolor="#q1"'));
});
test("tables get borders and shaded headers", () => {
  const h = H("| a | b |\n|---|---|\n| 1 | 2 |");
  assert.ok(h.includes('border="1"') && h.includes('bgcolor="#h1"') && h.includes("border-color:#b1"), h);
});
test("output carries a style block (colored links without underline, tighter paragraphs)", () => {
  const h = H("text");
  assert.ok(h.startsWith("<style>") && h.includes("text-decoration"), h.slice(0, 120));
  assert.ok(/a \{[^}]*color: #lnk/.test(h), h.slice(0, 160));
});
test("highlight markers become a shaded span", () => {
  const h = H("a \uE000hot\uE001 b");
  assert.ok(h.includes('background-color:#hl1">hot</span>'), h);
  assert.ok(!h.includes("\uE000") && !h.includes("\uE001"), h);
});
test("headings, lists, emphasis render", () => {
  const h = H("# T\n\n- a\n- b\n\n**b** *i* ~~s~~");
  assert.ok(h.includes("<h1>T</h1>") && h.includes("<li>a</li>") && h.includes("<strong>b</strong>") && h.includes("<em>i</em>") && h.includes("<s>s</s>"), h);
});
test("never throws on hostile input", () => {
  for (const t of ["", "[", "![](", "> > > >", "```", "| |", "\u0000", "<" .repeat(500), "[a](" + "(".repeat(200)]) H(t);
});

console.log("previewhtml.js: " + passed + " passed" + (process.exitCode ? " (with failures)" : ""));
