import QtQuick
import Quickshell
import Quickshell.Io
import "../../js/tree.js" as Tree
import qs.Common
import qs.Services
import qs.Modules.Plugins

// Foundation of the SuperNote controller. The controller is built as a chain of QML types, each adding one
// concern to the same object (see docs/ARCHITECTURE.md):
//
//   CoreBase -> VaultLayer -> NoteLayer -> NavLayer -> OrganizeLayer -> FileOpsLayer -> CaptureLayer
//            -> WindowLayer -> SuperNote (IPC, UI loaders)
//
// CoreBase has the identity (paths), small helpers, running processes, atomic file writes and the persisted
// state store. Layers call each other's functions freely; names resolve on the shared object at run time.
PluginComponent {
    id: root

    readonly property string pluginKey: "supernote"
    readonly property string home: Quickshell.env("HOME")
    // the plugin folder wherever it lives (a symlink into a git checkout works too)
    readonly property string pluginDir: Qt.resolvedUrl("../..").toString().replace(/^file:\/\//, "").replace(/\/$/, "")
    readonly property string vaultScript: pluginDir + "/scripts/supernote-vault.sh"
    readonly property string defaultVault: home + "/Documents/notes"

    // --- persisted UI/vault state (own file: DMS's plugin-state writer breaks after a plugin reload) ------
    readonly property StateStore store: StateStore {
        core: root
    }
    readonly property bool stateLoaded: store.loaded

    function loadState() {
        store.load();
    }

    function afterState(cb) {
        store.afterLoad(cb);
    }

    function readState(key, def) {
        return store.read(key, def);
    }

    function writeState(key, value) {
        store.write(key, value);
    }

    // --- helpers ---------------------------------------------------------------------------------------
    function clone(x) {
        return JSON.parse(JSON.stringify(x));
    }

    function toast(msg, isError) {
        if (isError)
            ToastService.showError(msg);
        else
            ToastService.showInfo(msg);
    }

    function lastLine(text) {
        const lines = (text || "").trim().split("\n");
        return lines[lines.length - 1];
    }

    function vaultName(path) {
        const parts = (path || "").split("/").filter(p => p.length > 0);
        return parts.length ? parts[parts.length - 1] : "";
    }

    function noteTitleOf(path) {
        return Tree.baseName(path);
    }

    function parentOf(path) {
        return Tree.parentOf(path);
    }

    function expandPath(p) {
        return p.startsWith("~/") ? home + p.slice(1) : p;
    }

    // --- processes and files -----------------------------------------------------------------------------
    // Run a command; done(exitCode, stdout, stderr) fires once everything has been read.
    Component {
        id: procComp
        Process {
            id: p
            property var done: null
            property string out: ""
            property string err: ""
            property int code: -1
            property int pending: 3
            function tick() {
                pending--;
                if (pending === 0) {
                    if (done)
                        done(code, out, err);
                    p.destroy();
                }
            }
            stdout: StdioCollector {
                onStreamFinished: {
                    p.out = text;
                    p.tick();
                }
            }
            stderr: StdioCollector {
                onStreamFinished: {
                    p.err = text;
                    p.tick();
                }
            }
            onExited: exitCode => {
                p.code = exitCode;
                p.tick();
            }
        }
    }

    function run(args, done) {
        procComp.createObject(root, { command: args, done: done, running: true });
    }

    function vaultRun(op, args, done) {
        run([vaultScript, op, activeVault].concat(args), done);
    }

    // Atomic write, same mechanism DMS's own notepad uses. done(ok).
    Component {
        id: writerComp
        FileView {
            property string content: ""
            property var done: null
            blockWrites: false
            atomicWrites: true
            Component.onCompleted: setText(content)
            onSaved: {
                if (done)
                    done(true);
                destroy();
            }
            onSaveFailed: {
                if (done)
                    done(false);
                destroy();
            }
        }
    }

    function writeFile(path, content, done) {
        if (content === "") {
            // FileView.setText("") never reports "saved": empty the file (atomically) by hand
            run(["sh", "-c", ": > \"$1.sntmp\" && mv -f \"$1.sntmp\" \"$1\"", "sh", path], code => {
                if (done)
                    done(code === 0);
            });
            return;
        }
        writerComp.createObject(root, { path: path, content: content, done: done });
    }
}
