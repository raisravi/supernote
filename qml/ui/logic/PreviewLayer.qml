import QtQuick
import qs.Common
import "../../../js/markdown.js" as Md
import "../../../js/previewhtml.js" as Html

// Panel logic, part 6: markdown preview (HTML, colors, links, math/Mermaid pictures).
SwitcherLayer {
    id: ui

    property string previewHtml: ""
    property var previewProps: []

    readonly property var previewColors: ({
            link: Theme.primary.toString(),
            highlight: tint(Theme.warning),
            mono: Theme.monoFontFamily,
            codeText: Theme.secondary.toString(),
            codeBg: Theme.surfaceContainerHigh.toString(),
            quoteBar: Theme.outline.toString(),
            border: Theme.outline.toString(),
            headBg: Theme.surfaceContainerHigh.toString(),
            calloutNote: tint(Theme.primary),
            calloutWarn: tint(Theme.warning),
            calloutDanger: tint(Theme.error),
            calloutOk: tint(Theme.success),
            calloutTip: tint(Theme.secondary)
        })

    onPreviewColorsChanged: refreshPreview()

    function previewCtx() {
        return {
            vaultAbs: core.activeVault,
            noteDir: core.parentOf(core.noteRel),
            resolveNote: n => core.resolveNote(n),
            resolveAsset: (n, d) => core.resolveAsset(n, d),
            getEmbed: n => core.getEmbed(n),
            diagram: (kind, src, display) => core.render.diagram(kind, src, display, Math.max(200, previewFlick.width - 64))
        };
    }

    function refreshPreview() {
        if (core.viewMode === "edit" || !core.noteRel) {
            return;
        }
        core.render.beginPass();
        const r = Md.renderPreview(core.buffer, previewCtx());
        previewHtml = Html.renderHtml(r.markdown, previewColors);
        previewProps = r.props.map(p => ({ key: p.key, text: Array.isArray(p.value) ? p.value.join(", ") : String(p.value) }));
    }

    readonly property Timer previewTimer: Timer {
        interval: 150
        onTriggered: ui.refreshPreview()
    }

    function safeDecode(t) {
        try {
            return decodeURIComponent(t);
        } catch (e) {
            return t;
        }
    }

    function handleLink(link) {
        if (link.indexOf("sn-task:") === 0) {
            core.toggleTaskLine(parseInt(link.slice(8), 10));
        } else if (link.indexOf("sn-note:") === 0) {
            const parts = link.slice(8).split("#");
            core.openLink(safeDecode(parts[0]), parts.length > 1 ? safeDecode(parts[1]) : "");
        } else if (link.indexOf("sn-tag:") === 0) {
            core.showTag(safeDecode(link.slice(7)));
        } else if (/^https?:\/\//.test(link)) {
            Qt.openUrlExternally(link);
        }
    }

    // a math / Mermaid picture became available: refresh the preview
    readonly property int pictureSerial: core.render.serial

    onPictureSerialChanged: {
        if (core.viewMode !== "edit")
            previewTimer.restart();
    }
}
