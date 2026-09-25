.pragma library
.import "config.js" as Config

// Template variables: {{title}} {{date}} {{time}} {{date:FORMAT}} {{time:FORMAT}} {{cursor}}.
// -> {text, cursor}: cursor is the offset of the first {{cursor}} (or -1).
function apply(template, vars) {
    var out = "";
    var cursor = -1;
    var pos = 0;
    var re = /\{\{(title|date|time|cursor)(?::([^}]*))?\}\}/g;
    var m;
    while ((m = re.exec(template)) !== null) {
        out += template.slice(pos, m.index);
        pos = m.index + m[0].length;
        if (m[1] === "title")
            out += vars.title;
        else if (m[1] === "date")
            out += Config.formatDate(m[2] || "YYYY-MM-DD", vars.date);
        else if (m[1] === "time")
            out += Config.formatDate(m[2] || "HH:mm", vars.date);
        else if (cursor < 0)
            cursor = out.length;
    }
    return { text: out + template.slice(pos), cursor: cursor };
}
