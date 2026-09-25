# SuperNote

Obsidian-style markdown vault for DMS. Notes are plain `.md` files (default vault
`~/Documents/notes`, created on first run), so Obsidian or any editor can open them.

**Status: all six milestones (vault core, markdown, navigation, organization, capture & polish, math + Mermaid).** `Super+Shift+N` now opens
SuperNote; the built-in Notepad moved to `Super+Alt+N`. Built so far: multi-vault, file tree, autosave + conflict detection, inline titles, a syntax-colored markdown editor with split/preview, tabs + history, quick switcher, wikilinks + backlinks, full-text search, tags, pins/recents, link-safe rename/move with undo, quick capture, daily notes, templates, command palette, slash menu and paste-image.

## Math and Mermaid (M6)

- **Math**: `$x^2$` inline and `$$ ... $$` blocks (one line, or several lines) render as pictures in Preview / Split. The
  syntax is LaTeX (as in Obsidian), converted by Typst's `mitex` package: `typst` must be installed; the package is
  downloaded on first use. Prices like "$5 and $6", `\$` and code spans are left alone.
- **Mermaid**: a ```` ```mermaid ```` fence renders with [`mmdr`](https://github.com/1jehuang/mermaid-rs-renderer), a
  pure-Rust Mermaid renderer (no browser, no Node). SuperNote uses `mmdr` from your `PATH` (`cargo install
  mermaid-rs-renderer`), otherwise downloads the pinned v0.3.1 release once into `~/.cache/supernote/bin/`
  (SHA-256 verified). It covers 23 diagram types (flowchart, sequence, class, state, ER, gantt, pie, mindmap, ...); the
  project is young, so a few diagrams or styles can differ from mermaid.js and unsupported ones stay code blocks.
- Pictures are rendered in the background at 2x, cached on disk by content and theme colors (so a theme change
  re-renders), and pruned after 45 days. Until one is ready - or if the tools/network are missing or the source is
  invalid - the raw text / code block is shown, and one toast per session names the problem. Everything else keeps
  working without them.
- `supernote-render.sh` is standalone (`math|mermaid|prune`, see its header); tests: `tests/render.test.sh`.

## Docked panel and window

- `Super+Shift+N` opens SuperNote **docked on the right side** of the focused screen with the left panel (files /
  search / tags) hidden. The header's left-panel button (or `Ctrl+\`, or the palette) shows it; the choice is
  remembered. `Ctrl+Shift+F`, tag clicks and `Ctrl+Shift+E` reveal it (`Ctrl+Shift+E` again, with the tree focused, hides it). Clicking outside or `Esc` closes.
- The header's expand button (or `dms ipc call supernote expand`, or the palette) detaches the panel into a **real
  window** your compositor manages (tile / move / resize), with the left panel shown; the same button docks it back
  (`dms ipc call supernote dock`). It always reopens docked.

## Use

- `Super+Shift+N` toggles SuperNote (mango + niri); `Super+Alt+N` is the built-in DMS Notepad. (Both bind
  files are DMS-managed: `dms setup` may regenerate them and restore the old `Super+Shift+N` binding.)
- `Ctrl+N` new note (in the selected folder) - `F2` edit the title (renames the file) -
  `Ctrl+S` save now - `Ctrl+Shift+E` show + focus the tree (again = hide the left panel) - `Esc` close.
- Tree (when focused): Up/Down move, Enter open/toggle, Left/Right collapse/expand,
  `F2` rename, `Delete` trash. Right-click for the context menu.
- Vault menu (top-left): switch vaults, add one via a folder chooser, remove from the list
  (files are never deleted).

## Navigation (M3)

- **Tabs**: opening a note from the tree or a link replaces the current tab (and pushes history); `Ctrl+click`
  a tree row, `Ctrl+T`, or the `+` button opens a new tab. `Ctrl+W` / middle-click closes, `Ctrl+Tab` /
  `Ctrl+Shift+Tab` (or `Ctrl+PageUp/Down`) cycle. Opening a note that is already open in another tab
  switches to it. Tabs, the active tab and each tab's cursor/scroll are restored per vault.
- **History**: `Alt+Left` / `Alt+Right` (or the arrows in the tab bar) go back / forward within a tab (last 100).
- **Quick switcher** `Ctrl+O`: fuzzy search by name or path, recent notes first, a "Create ..." row when
  nothing matches exactly; `Enter` opens, `Ctrl+Enter` opens in a new tab.
- **Wikilinks**: `[[` pops up note suggestions (`Up`/`Down`, `Enter`/`Tab` to insert, `Esc` to dismiss);
  notes whose names clash insert as `folder/Name`. `[[Note#Heading]]` links jump to the heading.
- **Right panel** (header button or `Ctrl+Shift+B`): *Outline* (click to jump), *Backlinks* (notes linking to
  this one, with the linking line), *Links* (this note's outgoing links; broken ones are dimmed, click to
  create).

## Capture & polish (M5)

- **Quick capture** `Super+Ctrl+N` (`dms ipc call supernote quick`): a small markdown box that opens instantly and works
  with the panel closed. `Enter` is a new line (lists, tasks and quotes continue; `Ctrl+B/I/K/L`, headings, `Tab`,
  auto-pair work like in the editor). `Ctrl+Enter` appends `- HH:MM text` under `## Captures` in today's daily note,
  `Ctrl+Shift+Enter` saves it as its own note in `Inbox/` (named from its first line), `Esc` cancels.
- **Scripts**: `dms ipc call supernote capture "text"`, `... clip` (captures the clipboard text), `... daily` (opens
  today's note, created from the daily template), `... search "query"`.
- **Daily notes**: header button / palette / `daily` IPC. Folder, date format and template come from the vault's
  `.obsidian/daily-notes.json` when present (never written), else the SuperNote settings, else `Daily/` + `YYYY-MM-DD`.
- **Templates** (folder `Templates/`, or `.obsidian/templates.json`): palette > *New note from template...* or
  *Insert template...* (also `/` > *Insert template*). Variables: `{{title}} {{date}} {{time}} {{date:FORMAT}}
  {{time:FORMAT}} {{cursor}}`.
- **Command palette** `Ctrl+P` (every action, fuzzy), **cheat sheet** `Ctrl+/`.
- **Slash menu**: type `/` at the start of a line: headings, lists, task, quote, code block, table, callout, divider,
  link, date, time, template.
- **Paste image** `Ctrl+V`: an image-only clipboard is saved as `Pasted image YYYYMMDDHHMMSS.png` in the attachments
  folder and `![[...]]` is inserted; other clipboards paste as text.
- **Properties**: collapsible block under the title; edit values, delete, or add frontmatter keys (`tags`/`aliases`
  take comma-separated lists).
- **Settings** (DMS Settings > Plugins > SuperNote): daily folder / format / template, templates, attachments and
  inbox folders, editor font size. Empty = use the vault's Obsidian setting, then the default.
- The temporary debug IPC hooks are gone; `dms ipc call supernote status` remains for scripting.

## Organization (M4)

- **Sidebar tabs**: *Files*, *Search*, *Tags*. `Ctrl+Shift+F` jumps to Search, `Ctrl+Shift+E` toggles the tree.
- **Search**: literal, smart-case (all lower-case = ignore case) full-text search over every note, plus fuzzy
  note-name hits on top. Results are grouped per note with the matched text in bold; click a line to open
  the note at that line. Backlinks rows also jump to the linking line.
- **Tags**: inline `#tag` and frontmatter `tags:`, nested `a/b` as a tree with counts. Click a tag to list its
  notes (nested tags included); click a `#tag` in the preview to jump here. The index is read lazily and
  incrementally (only notes whose modified time changed).
- **Pins / recents**: right-click a note > *Pin to top*, or the pin button in the header. Pinned and the six
  most recent notes sit above the tree (headers collapse).
- **Link-safe rename / move**: renaming a note or folder (F2, title edit, context menu) or *Move to...* checks
  which notes link to it. If any do you are asked *Update links* / *Rename only* / *Cancel*. Originals of
  every touched note are backed up in `~/.local/state/DankMaterialShell/plugins/supernote/backups/` (last 10);
  the vault menu has *Undo* for the last rename/move (notes edited since are left alone). Code blocks and
  inline code are never rewritten; `[[Name]]` stays bare when it still resolves, otherwise becomes a path link.

## Markdown editing (M2)

- View: `Ctrl+E` cycles Edit -> Split -> Preview (also the button bottom-right). Toolbar can be hidden
  (bottom-right `Aa` button).
- `Ctrl+B` bold - `Ctrl+I` italic - `Ctrl+Shift+X` strike - `Ctrl+Shift+C` inline code - `Ctrl+K` link -
  `Ctrl+L` toggle task - `Ctrl+1..6` heading level (`Ctrl+0` clears) - `Ctrl+]` / `Ctrl+[` or `Tab` /
  `Shift+Tab` indent / outdent.
- `Enter` continues bullets, numbers, tasks and quotes (an empty item ends the list); `(`, `[`, `{`, `` ` ``
  auto-pair (`[[` gives `[[]]`); typing a closer skips over it.
- `Ctrl+F` find, `Ctrl+H` find + replace (case / regex toggles, `Enter` = next).
- Preview: frontmatter properties block, callouts (`> [!warning] Title`), tables, code blocks, images
  (`![[pic.png]]`, `![[pic.png|300]]`, `![](path)`), note embeds (`![[Note]]`), footnotes, `==highlight==`,
  tags. Click a task box to tick it, a `[[wikilink]]` to open (or create, in the vault root) the note.
- The colored editor is a transparent text box over a colored copy of the text (monospace font keeps them
  aligned); if the two ever disagree on height it falls back to plain text automatically.

## IPC

    dms ipc call supernote toggle | open | close
    dms ipc call supernote openNote <name>
    dms ipc call supernote newNote
    dms ipc call supernote vault <path>          # add + switch
    dms ipc call supernote removeVault <path>    # forget (does not delete files)
    dms ipc call supernote viewMode edit|split|preview
    dms ipc call supernote status                # JSON, for scripting/tests
    (debug*: developer test hooks that simulate typing/rename/trash headlessly; removed at the end of milestone 5)

## Files

- `supernote-vault.sh` - all filesystem ops; every path validated to stay inside the vault,
  dot-folders (`.obsidian`, `.trash`...) ignored. Deletes use `gio trash`.
- `SuperNote.qml` - state, load/save/conflict logic, IPC (reloads with
  `dms ipc call plugins reload supernote`).
- `SuperNotePanel.qml` - UI, loaded via a cache-busting URL so it also reloads with the
  plugin reload.
- `tree.js`, `tabs.js` (tab/history model), `fuzzy.js` (switcher ranking), `markdown.js` (edit transforms,
  preview preprocessing, syntax highlighter, link helpers), `previewhtml.js` (markdown -> Qt rich text) - pure JS
  with node tests in `tests/` (`for t in tests/*.test.js; do node $t; done; bash tests/vault.test.sh`).
  **JS files are cached by QML across plugin reloads: after editing one, run `dms restart`.**
- `mdit.js` is generated by `tools/build-mdit.sh` from `vendor/markdown-it.min.js` (markdown-it 14.1.0, MIT).
