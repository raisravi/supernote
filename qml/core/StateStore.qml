import QtQuick
import qs.Common

// Persisted UI/vault state: one JSON file (~/.local/state/DankMaterialShell/plugins/supernote.state.json),
// read once at startup, written (debounced) on every change. Keys are owned by the layers that use them.
QtObject {
    id: store

    required property var core      // for run() and writeFile()

    readonly property string file: Paths.strip(Paths.state) + "/plugins/supernote.state.json"
    property var data: ({})
    property bool loaded: false
    property var waiting: []

    function load() {
        core.run(["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && cat \"$1\" 2>/dev/null || true", "sh", file], (code, out) => {
            try {
                data = JSON.parse(out);
            } catch (e) {
                data = {};
            }
            loaded = true;
            const queued = waiting;
            waiting = [];
            queued.forEach(f => f());
        });
    }

    // Run cb once the file has been read (immediately when it already has).
    function afterLoad(cb) {
        if (loaded)
            cb();
        else
            waiting = waiting.concat([cb]);
    }

    function read(key, def) {
        const v = data[key];
        return v === undefined || v === null ? def : JSON.parse(JSON.stringify(v));
    }

    function write(key, value) {
        data[key] = value;
        timer.restart();
    }

    function flush() {
        core.writeFile(file, JSON.stringify(data, null, 2), ok => {
            if (!ok)
                console.warn("SuperNote: could not write", file);
        });
    }

    readonly property Timer timer: Timer {
        interval: 400
        onTriggered: store.flush()
    }
}
