# Changelog

## 0.6.0

### Changed
- **Own repository and code organization.** The plugin moved to its own git repository with a `js/`, `scripts/`, `qml/`,
  `tests/`, `docs/` layout. `SuperNote.qml` (about 2000 lines) is now a chain of focused layers in `qml/core` plus
  `StateStore` and `RenderService`; `SuperNotePanel.qml` (about 3300 lines) is a window host with 22 components in
  `qml/ui/components`, a logic chain in `qml/ui/logic` and two widgets. Behavior is unchanged apart from the fixes below.
- **Mermaid renders with `mmdr`** (pure Rust) instead of headless Chrome: from `PATH`, or a pinned SHA-256-verified
  download. Chrome and mermaid.js are no longer used.
- Documentation: README plus `docs/` (usage, IPC, configuration, architecture, development, rendering, design).

### Added
- **Settings page**: where new notes go (`newFileLocation` / `newFileFolder`) and the formatting-toolbar switch; date formats gain `Do`, `DDD`, `dd`, `d`, `E`, `W`/`WW`, `GGGG`/`gggg`, `Q`.
- **Follow wikilinks in the editor**: `Ctrl+click` or `Ctrl+Enter` on a `[[link]]` (`Md.linkAt`, unit-tested).
- `dms ipc call supernote command <id>`: run a palette command in the panel (also useful for testing).
- `Command palette` entry in the palette; `Makefile` (`test`, `lint`, `reload`, `restart`, `link`, `mdit`);
  `tests/run-all.sh`; `scripts/dev/snapshot.sh`.

### Fixed
- List-valued frontmatter (`tags: [a, b]`) showed as garbage in the properties editor.
- Overlays (cheat sheet, switcher, dialogs) no longer survive closing and reopening the panel.
- The panel logs the load error when its QML fails to load.

## 0.5.0

- **Docked right panel** with the left panel hidden by default; *expand* opens a real floating window; `expand`, `dock`
  and `sidebar` IPC verbs; `Ctrl+\` toggles the left panel and `Ctrl+Shift+E` toggles the file tree.
- **Quick capture**: `Enter` is a new line with markdown editing (list continuation, formatting shortcuts, auto-pair);
  `Ctrl+Enter` adds to the daily note, `Ctrl+Shift+Enter` saves an Inbox note. Shared, unit-tested key handling
  (`js/mdkeys.js`).
- **Math and Mermaid** in the preview (typst + mitex; Mermaid via headless Chrome at the time): asynchronous cached
  pictures, retries, size and time limits, checksum-pinned tools.
- Fixes: empty files could never finish saving (empty daily note, emptying a note); capture queue could wedge when
  the vault failed to open; several safety fixes from code review.

## Earlier milestones

- **Capture & polish**: quick capture box (`Super+Ctrl+N`), daily notes, templates with variables, paste image,
  `capture` / `clip` / `daily` IPC, command palette, slash menu, cheat sheet, properties editor, `.obsidian`
  compatibility, settings page.
- **Organization**: full-text search, nested tags, pins and recents, link-safe rename / move with backup and undo.
- **Navigation**: tabs with history, quick switcher, wikilinks with completion, backlinks, outline, right panel.
- **Vault and markdown**: vault script, file tree, autosave with conflict detection, syntax-colored editor,
  toolbar, split / preview, find / replace, multi-vault.
