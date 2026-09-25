.pragma library
.import "mdit.js" as MdIt

// Markdown -> Qt rich-text HTML for the preview pane. Rich text (unlike Text.MarkdownText) honors
// Text.linkColor, and lets us shade code/quotes/callouts/tables and size images.
// Raw HTML in notes is escaped (html:false); link schemes are handled by the UI, not the parser.

var md = null;

function parser() {
    if (!md) {
        md = MdIt.markdownit({ html: false, linkify: false, typographer: false, breaks: false });
        md.validateLink = function () { return true; };
    }
    return md;
}

var CALLOUT_KIND = {
    "ⓘ": "calloutNote", "≡": "calloutNote", "☐": "calloutNote", "❝": "calloutNote", "?": "calloutNote", "◆": "calloutNote",
    "⚠": "calloutWarn", "‼": "calloutWarn",
    "✖": "calloutDanger", "✱": "calloutDanger",
    "✔": "calloutOk",
    "✦": "calloutTip"
};

function renderHtml(markdown, c) {
    var html;
    try {
        html = parser().render(markdown || "");
    } catch (e) {
        html = "<p>" + String(markdown).replace(/&/g, "&amp;").replace(/</g, "&lt;") + "</p>";
    }

    // tables (before quotes/code wrappers introduce their own <table>)
    html = html.replace(/<table>/g, '<table border="1" cellspacing="0" cellpadding="6" style="border-color:' + c.border + '">');
    html = html.replace(/<th>/g, '<th bgcolor="' + c.headBg + '">').replace(/<th style=/g, '<th bgcolor="' + c.headBg + '" style=');

    // fenced code blocks -> shaded cell
    html = html.replace(/<pre><code(?: class="[^"]*")?>([\s\S]*?)<\/code><\/pre>/g, function (_, body) {
        return '<table width="100%" cellspacing="0" cellpadding="10"><tr><td bgcolor="' + c.codeBg + '"><pre style="font-family:' + c.mono + '; margin:0; color:' + c.codeText + '">' + body + "</pre></td></tr></table>";
    });
    // inline code
    html = html.replace(/<code>([\s\S]*?)<\/code>/g, function (_, body) {
        return '<span style="font-family:' + c.mono + "; color:" + c.codeText + "; background-color:" + c.codeBg + '">' + body + "</span>";
    });

    // callouts (first line bold starts with an icon) get a tint; plain quotes get a bar
    html = html.replace(/<blockquote>(\s*<p><strong>)([^\s<])/g, function (all, mid, icon) {
        var kind = CALLOUT_KIND[icon];
        if (!kind)
            return all;
        return '<table width="100%" cellspacing="0" cellpadding="10"><tr><td bgcolor="' + c[kind] + '">' + mid + icon;
    });
    html = html.replace(/<blockquote>/g, '<table width="100%" cellspacing="0" cellpadding="0"><tr><td width="4" bgcolor="' + c.quoteBar + '"></td><td width="10"></td><td>');
    html = html.replace(/<\/blockquote>/g, "</td></tr></table>");

    // images: "name|300" alt suffix -> width
    html = html.replace(/<img src="([^"]*)" alt="([^"]*)"( title="[^"]*")?>/g, function (_, src, alt, title) {
        var m = /^(.*?)\|(\d+)$/.exec(alt);
        return '<img src="' + src + '" alt="' + (m ? m[1] : alt) + '"' + (m ? ' width="' + m[2] + '"' : "") + (title || "") + ">";
    });

    // highlight markers (put there by markdown.js, safe inside/around any inline markup)
    html = html.replace(/\uE000/g, '<span style="background-color:' + c.highlight + '">').replace(/\uE001/g, "</span>");

    return "<style>a { color: " + c.link + "; text-decoration: none; } p { margin-top: 0px; margin-bottom: 8px; } li { margin-bottom: 2px; } h1, h2, h3 { margin-top: 14px; margin-bottom: 6px; }</style>" + html;
}
