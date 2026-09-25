# Development

## Setup

```sh
git clone <this repository> ~/Projects/DMS/plugins/supernote
cd ~/Projects/DMS/plugins/supernote
make link          # symlink into ~/.config/DankMaterialShell/plugins/supernote
make restart       # dms restart: DMS picks the plugin up
make test          # all unit + shell tests
```

You need a running DMS session for anything visual. The tests need `bash`, `jq`, `rg`, `gio`, Node 18+ (found on `PATH`
or under `~/.nvm`), and optionally `typst` / `mmdr` (their tests are skipped when unavailable). `make lint` runs
`qmllint` (Qt 6) over every QML file.

## The dev loop

| You changed | Do |
|---|---|
| `SuperNote.qml` only | `make reload` (`dms ipc call plugins reload supernote`) |
| `qml/ui/SuperNotePanel.qml` or `CaptureBox.qml` | `make reload` (loaded through a cache-busting URL) |
| any other QML file (`qml/core`, `qml/ui/components`, `qml/ui/logic`, ...) or any `js/` file | `make restart` – these are cached by URL until the shell restarts |
| `scripts/*.sh` | nothing, they run fresh each call |
| `SuperNoteSettings.qml`, `plugin.json` | `make restart` |
| before committing UI changes | `make restart && make test-ui` |

If the panel does not appear after a change, QML failed to load it: the reason is in the journal
(`journalctl --user -u dms --since -1min | grep -i supernote`); the entry file logs *"SuperNote: the panel failed to
load: ..."* with the component error. A second common cause is a stale cache: restart.

## Testing

- **Unit tests** (`tests/*.test.js`) cover the pure libraries in `js/`. `tests/load.js` loads a `.pragma library` file
  into node (it strips the pragma and emulates `.import "x.js" as X`). Results are normalized through JSON because they
  come from another VM realm. Run one with `node tests/links.test.js`.
- **Shell tests** (`tests/vault.test.sh`, `tests/render.test.sh`) run the scripts against a throw-away vault created under
  `$HOME` (`gio trash` refuses `/tmp`). `tests/run-all.sh` runs everything; `make test` calls it.
- **Test-first for pure logic**: new behaviour in `js/` gets a failing test first. Bug fixes get a regression test.
- **UI smoke test** (`make test-ui`, `tests/ui/smoke.test.sh`): drives the *running* shell through its IPC in a
  throw-away vault (open / close, dock / expand, view modes, left and right panel, tabs, palette commands, capture,
  daily note, quick-capture box, search, math and Mermaid pictures) and asserts on the `status` JSON, which includes the
  panel's real layout, on the files it produces and on the shell log (no QML errors). It takes under a minute, needs a
  DMS session (it skips itself when none is running), restores your vault and settings afterwards, and is not part of
  `make test`. `SN_UI_SKIP_RENDER=1` skips the math / Mermaid checks. To add a check, use `wait_for "<what>" '<jq
  predicate on status>'` from `tests/ui/lib.sh`; expose new state through `status` in `SuperNote.qml` when needed.
- **Everything else in QML** is checked by eye on a running shell:
  - `scripts/dev/snapshot.sh <dir>` drives the panel through its IPC in a throw-away vault (docked, sidebar, split /
    preview with math and Mermaid, window, search, capture box) and writes full-screen `grim` screenshots plus the
    `status` JSON of each state. Run it before and after a refactor and compare. Crop screenshots before sharing them:
    they contain the rest of your screen.
  - `dms ipc call supernote command <id>` runs any palette command (`palette`, `cheatsheet`, `properties`, `delete`,
    ...), which opens dialogs and overlays that have no other IPC entry.
  - Use a throw-away vault (`dms ipc call supernote vault ~/some-test-vault`), never your real notes, and switch back
    afterwards.

## Conventions

- **JS libraries are pure**: no QML types, no I/O, no `Qt.*`; take data in, return data or an *edit*
  (`{start, end, text, selStart, selEnd}`). Anything testable belongs there, not in a QML function.
- **QML layers and components**: one concern per file, a header comment saying what it owns / what its inputs are, ideally
  under ~400 lines. Components take `required property var ui`. Cross-file items are exposed as properties on the panel
  root; do not reach into another component's ids.
- **Shell scripts** validate every path (`valid_rel`, `abs_in_vault`), use `set -euo pipefail`, write atomically and
  never touch dot files. Document each verb in the file header and add a case to the shell tests, including the
  "must fail" cases.
- **Never replace an unsaved buffer**: use `safely()`; never write a note from stale text (check mtime / hash).
- **Comments** explain why, not what; keep the style of the surrounding file.
- **Commits**: imperative, present-tense subject; a body explaining the reason when it is not obvious.

## Recipes

- **Add a palette command**: an entry in `js/commands.js` (id, group, title, keys, `needsNote`), a `case` in
  `runCommand` (`qml/ui/logic/SwitcherLayer.qml`), a test in `tests/commands.test.js` if it changes the list. It is
  reachable through `dms ipc call supernote command <id>` automatically.
- **Add an IPC verb**: a function in the `IpcHandler` in `SuperNote.qml` returning a string; document it in `docs/IPC.md`.
- **Add a setting**: a `StringSetting` in `SuperNoteSettings.qml`; read it through `pluginData` (see `cfg` in
  `VaultLayer.qml` and `js/config.js`, which merges defaults < `.obsidian` < settings); document it in
  `docs/CONFIGURATION.md`.
- **Add a persisted UI flag**: read it in the owning layer's `load<Layer>State()`, write it with `writeState(key, value)`,
  document the key if it matters.
- **Add a vault-script verb**: a `case` in `scripts/supernote-vault.sh` (header comment + validation), call it with
  `vaultRun(op, args, cb)`, tests in `tests/vault.test.sh`.
- **Add a UI component**: a file in `qml/ui/components`, instantiate it in the parent (anchors between siblings are set
  at the instantiation), expose what the logic needs as a `readonly property` and re-export it up to
  `SuperNotePanel.qml` only if the logic layers need it by name.
- **Update markdown-it**: replace `vendor/markdown-it.min.js`, run `make mdit`, run the preview tests.

## Releasing

Bump `version` in `plugin.json`, add a section to `CHANGELOG.md`, tag the commit.
