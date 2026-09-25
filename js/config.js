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

function ordinal(n) {
    var v = n % 100;
    if (v >= 11 && v <= 13)
        return n + "th";
    return n + (["th", "st", "nd", "rd"][n % 10] || "th");
}

// ISO 8601 week number and week-year of a date.
function isoWeek(d) {
    var t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
    var day = t.getUTCDay() || 7;
    t.setUTCDate(t.getUTCDate() + 4 - day);            // the Thursday of this week decides the year
    var yearStart = new Date(Date.UTC(t.getUTCFullYear(), 0, 1));
    return { week: Math.ceil(((t - yearStart) / 86400000 + 1) / 7), year: t.getUTCFullYear() };
}

function dayOfYear(d) {
    return Math.round((Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()) - Date.UTC(d.getFullYear(), 0, 0)) / 86400000);
}

// Obsidian/moment-style format: YYYY YY GGGG gggg MMMM MMM MM M Do DDDD DDD DD D dddd ddd dd d E WW W Q
// HH H hh h mm m ss s A a, and [literal text].
function formatDate(fmt, d) {
    var h12 = d.getHours() % 12 === 0 ? 12 : d.getHours() % 12;
    var iso = isoWeek(d);
    var doy = dayOfYear(d);
    var tokens = {
        YYYY: pad(d.getFullYear(), 4), YY: pad(d.getFullYear() % 100, 2), GGGG: String(iso.year), gggg: String(iso.year),
        MMMM: MONTHS[d.getMonth()], MMM: MONTHS[d.getMonth()].slice(0, 3), MM: pad(d.getMonth() + 1, 2), M: String(d.getMonth() + 1),
        Do: ordinal(d.getDate()), DDDD: pad(doy, 3), DDD: String(doy), DD: pad(d.getDate(), 2), D: String(d.getDate()),
        dddd: DAYS[d.getDay()], ddd: DAYS[d.getDay()].slice(0, 3), dd: DAYS[d.getDay()].slice(0, 2), d: String(d.getDay()),
        E: String(d.getDay() || 7), WW: pad(iso.week, 2), W: String(iso.week), Q: String(Math.floor(d.getMonth() / 3) + 1),
        HH: pad(d.getHours(), 2), H: String(d.getHours()), hh: pad(h12, 2), h: String(h12),
        mm: pad(d.getMinutes(), 2), m: String(d.getMinutes()), ss: pad(d.getSeconds(), 2), s: String(d.getSeconds()),
        A: d.getHours() < 12 ? "AM" : "PM", a: d.getHours() < 12 ? "am" : "pm"
    };
    return fmt.replace(/\[([^\]]*)\]|YYYY|YY|GGGG|gggg|MMMM|MMM|MM|M|Do|DDDD|DDD|DD|D|dddd|ddd|dd|d|E|WW|W|Q|HH|H|hh|h|mm|m|ss|s|A|a/g, function (m, lit) {
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
