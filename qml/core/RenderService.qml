import QtQuick
import qs.Common
import "../../js/render.js" as Render

// Math and Mermaid pictures for the preview. The preview asks `diagram()` for a picture: it gets {url, w} once
// one exists on disk, otherwise null and a background render is queued (`serial` bumps when it lands, so the
// preview re-renders). Pictures are rendered by scripts/supernote-render.sh (typst / mmdr) at 2x and cached by
// content + theme colors under ~/.cache/supernote/render. Nothing else depends on this service working.
QtObject {
    id: service

    required property var core      // run(), writeFile(), toast(), lastLine(), pluginDir

    readonly property string script: core.pluginDir + "/scripts/supernote-render.sh"
    readonly property string dir: core.home + "/.cache/supernote/render"

    property int serial: 0          // bumps when a picture becomes available
    property int epoch: 0           // bumped by each preview pass: queued jobs from older passes are dropped
    property int passCount: 0       // new formulas requested in the current pass (capped)

    property var cache: ({})        // key -> {state: pending|ok|error, url, px, err, at}; mutated in place
    property var queue: []
    property var running: ({ math: 0, mermaid: 0 })
    property var warned: ({})       // one toast per kind until a render of that kind succeeds again
    property int jobs: 0

    function beginPass() {
        epoch++;
        passCount = 0;
    }

    // maxWidth: widest picture to show (0 = no limit). Returns {url, w} or null.
    function diagram(kind, src, display, maxWidth) {
        if (src.length > 20000)
            return null;   // too long to render (the script refuses it as well)
        const s = Theme.surface;
        const f = Theme.surfaceText;
        const style = { display: !!display, fg: Render.hex(f.r, f.g, f.b), dark: Render.isDark(s.r, s.g, s.b) };
        const key = Render.key(kind, src, style);
        const e = cache[key];
        if (e && e.state === "ok")
            return { url: e.url, w: Render.shownWidth(e.px, maxWidth || 0) };
        // failures are retried after a while (tools installed, network back); pending ones are already queued
        if (e && e.state === "pending") {
            queue.forEach(j => {
                if (j.key === key)
                    j.epoch = epoch;   // still on screen: keep it queued through the new pass
            });
            return null;
        }
        if (e && Date.now() - e.at < 60000)
            return null;
        if (passCount >= 40)
            return null;   // a note with hundreds of formulas fills in over several passes
        passCount++;
        cache[key] = { state: "pending" };
        queue = queue.concat([{ key: key, kind: kind, src: src, style: style, epoch: epoch }]);
        pump();
        return null;
    }

    function pump() {
        const limit = { math: 2, mermaid: 1 };
        // jobs for text that is no longer in the preview (typed over since) are dropped, not rendered
        const stale = queue.filter(j => j.epoch !== epoch);
        stale.forEach(j => delete cache[j.key]);
        const fresh = queue.filter(j => j.epoch === epoch);
        const started = { math: running.math, mermaid: running.mermaid };
        const rest = [];
        fresh.forEach(job => {
            if (started[job.kind] < limit[job.kind]) {
                started[job.kind]++;
                runJob(job);
            } else {
                rest.push(job);
            }
        });
        queue = rest;
    }

    function runJob(job) {
        running[job.kind]++;
        const srcFile = Paths.strip(Paths.state) + "/plugins/supernote.render" + (++jobs) + ".src";
        const out = dir + "/" + job.key + ".png";
        const finish = (ok, px, err) => {
            running[job.kind]--;
            cache[job.key] = ok ? { state: "ok", url: "file://" + out, px: px } : { state: "error", err: err, at: Date.now() };
            if (ok) {
                warned[job.kind] = false;   // a later failure is worth a new heads-up
            } else if (!warned[job.kind]) {
                warned[job.kind] = true;
                core.toast("Could not render " + job.kind + ": " + err, true);
            }
            core.run(["rm", "-f", srcFile], () => {});
            if (ok)
                serial++;
            pump();
        };
        core.writeFile(srcFile, job.src, wrote => {
            if (!wrote) {
                finish(false, 0, "could not write the source");
                return;
            }
            const arg = job.kind === "math" ? (job.style.display ? "1" : "0") : (job.style.dark ? "1" : "0");
            core.run([script, job.kind, srcFile, out, job.style.fg, arg], (code, stdout, stderr) => {
                const dims = Render.parseDims(stdout);
                if (code === 0 && dims)
                    finish(true, dims.w, "");
                else
                    finish(false, 0, core.lastLine(stderr).replace(/^error:\s*/, "") || "render failed");
            });
        });
    }

    // How many pictures are ready / rendering / failed (for the IPC status).
    function counts() {
        const c = { ok: 0, pending: 0, error: 0 };
        for (const key in cache)
            c[cache[key].state]++;
        return c;
    }

    // Forget failed renders so the next preview pass tries them again (after installing typst / mmdr, or coming online).
    function retryFailed() {
        for (const key in cache)
            if (cache[key].state === "error")
                delete cache[key];
        warned = ({});
        serial++;
    }

    // Old pictures are pruned once per start.
    function prune() {
        core.run([script, "prune"], () => {});
    }
}
