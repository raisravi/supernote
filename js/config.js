.pragma library

// Per-vault settings (pure; tests/config.test.js): defaults < .obsidian (read-only) < SuperNote settings.

var MONTHS = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
var DAYS = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];

function pad(n, w) {
    var s = String(n);
    while (s.length < w)
        s = "0" + s;
    return s;
}

// Obsidian/moment-style format: YYYY YY MMMM MMM MM M DD D dddd ddd HH H hh h mm m ss s A a, [literal].
function formatDate(fmt, d) {
    var h12 = d.getHours() % 12 === 0 ? 12 : d.getHours() % 12;
    var tokens = {
        YYYY: pad(d.getFullYear(), 4), YY: pad(d.getFullYear() % 100, 2),
        MMMM: MONTHS[d.getMonth()], MMM: MONTHS[d.getMonth()].slice(0, 3), MM: pad(d.getMonth() + 1, 2), M: String(d.getMonth() + 1),
        DD: pad(d.getDate(), 2), D: String(d.getDate()),
        dddd: DAYS[d.getDay()], ddd: DAYS[d.getDay()].slice(0, 3),
        HH: pad(d.getHours(), 2), H: String(d.getHours()), hh: pad(h12, 2), h: String(h12),
        mm: pad(d.getMinutes(), 2), m: String(d.getMinutes()), ss: pad(d.getSeconds(), 2), s: String(d.getSeconds()),
        A: d.getHours() < 12 ? "AM" : "PM", a: d.getHours() < 12 ? "am" : "pm"
    };
    return fmt.replace(/\[([^\]]*)\]|YYYY|YY|MMMM|MMM|MM|M|DD|D|dddd|ddd|HH|H|hh|h|mm|m|ss|s|A|a/g, function (m, lit) {
        return lit !== undefined ? lit : tokens[m];
    });
}

function defaults() {
    return {
        dailyFolder: "Daily", dailyFormat: "YYYY-MM-DD", dailyTemplate: "",
        templatesFolder: "Templates", attachmentsFolder: "Attachments", inboxFolder: "Inbox",
        newFileLocation: "current", newFileFolder: ""
    };
}

// "/a//./b/../c/" -> "a/b/c": no empty, "." or ".." segments (they would be rejected by the vault script).
function trimSlashes(p) {
    return String(p).split("/").filter(function (x) { return x !== "" && x !== "." && x !== ".."; }).join("/");
}

// obsidian: {daily, templates, app} = the parsed .obsidian/*.json files (any may be missing).
function merge(base, obsidian, overrides) {
    var out = {};
    for (var k in base)
        out[k] = base[k];
    var o = obsidian || {};
    function take(key, v) {
        if (typeof v === "string" && v !== "")
            out[key] = v;
    }
    if (o.daily) {
        take("dailyFolder", o.daily.folder);
        take("dailyFormat", o.daily.format);
        take("dailyTemplate", o.daily.template);
    }
    if (o.templates)
        take("templatesFolder", o.templates.folder);
    if (o.app) {
        take("attachmentsFolder", o.app.attachmentFolderPath);
        take("newFileLocation", o.app.newFileLocation);
        take("newFileFolder", o.app.newFileFolderPath);
    }
    var v = overrides || {};
    for (var key in v)
        take(key, v[key]);
    ["dailyFolder", "templatesFolder", "inboxFolder", "newFileFolder"].forEach(function (f) { out[f] = trimSlashes(out[f]); });
    return out;
}

// Folder pasted images go to, relative to the vault ("" = vault root).
function attachmentDir(cfg, noteRel) {
    var a = cfg.attachmentsFolder;
    var noteDir = noteRel && noteRel.indexOf("/") >= 0 ? noteRel.slice(0, noteRel.lastIndexOf("/")) : "";
    if (a === "/" || a === "")
        return "";
    if (a === "." || a === "./")
        return noteDir;
    if (a.indexOf("./") === 0)
        return (noteDir ? noteDir + "/" : "") + trimSlashes(a.slice(2));
    return trimSlashes(a);
}

function dailyPath(cfg, date) {
    var name = trimSlashes(formatDate(cfg.dailyFormat, date).replace(/[\\:*?"<>|]/g, "-")) + ".md";
    return cfg.dailyFolder ? cfg.dailyFolder + "/" + name : name;
}

function newNoteDir(cfg, selectedDir) {
    if (cfg.newFileLocation === "root")
        return "";
    if (cfg.newFileLocation === "folder")
        return trimSlashes(cfg.newFileFolder || "");
    return selectedDir;
}
