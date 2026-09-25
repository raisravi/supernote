.pragma library
.import "config.js" as Config

// Quick capture helpers (pure; tests/capture.test.js).

var SECTION = "## Captures";

// Append "- HH:MM text" under "## Captures" (created at the end when missing).
function appendCapture(text, line, date) {
    var lines = line.split("\n");
    var entry = ["- " + Config.formatDate("HH:mm", date) + " " + lines[0]].concat(lines.slice(1).map(function (l) { return "  " + l; }));
    var all = text === "" ? [] : text.replace(/\n$/, "").split("\n");
    var fence = null;
    var start = -1;
    for (var i = 0; i < all.length; i++) {
        var f = /^\s*(```+|~~~+)/.exec(all[i]);
        if (f) {
            fence = fence ? (f[1].charAt(0) === fence ? null : fence) : f[1].charAt(0);
            continue;
        }
        if (!fence && all[i].trim() === SECTION) {
            start = i;
            break;
        }
    }
    if (start < 0) {
        if (all.length && all[all.length - 1].trim() !== "")
            all.push("");
        all.push(SECTION);
        return all.concat(entry).join("\n") + "\n";
    }
    var end = all.length;
    for (var k = start + 1; k < all.length; k++) {
        if (/^#{1,2}\s/.test(all[k])) {
            end = k;
            break;
        }
    }
    var at = start + 1;
    for (var n = start + 1; n < end; n++)
        if (all[n].trim() !== "")
            at = n + 1;
    all.splice.apply(all, [at, 0].concat(entry));
    return all.join("\n") + "\n";
}

// File name for a note captured on its own: the first line, stripped to something filename-safe.
function inboxTitle(text, date) {
    var first = "";
    text.split("\n").some(function (l) {
        if (l.trim() !== "") {
            first = l;
            return true;
        }
        return false;
    });
    var t = first.replace(/^#+\s*/, "").replace(/[*_`\[\]]/g, "").replace(/[\/\\:*?"<>|]/g, " ").replace(/\s+/g, " ").trim().replace(/^\.+/, "").slice(0, 60).trim();
    return t || "Capture " + Config.formatDate("YYYY-MM-DD HHmm", date);
}
