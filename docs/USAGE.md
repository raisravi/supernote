# Using SuperNote

Shortcuts are hard-coded to Obsidian's defaults where Obsidian has one. `Ctrl+/` (or the palette entry *Keyboard
shortcuts*) shows the live list.

## The panel

`Super+Shift+N` opens the panel **docked on the right side** of the focused screen, below the bar. The left panel
(files / search / tags) is hidden by default: use the header's left-panel button, `Ctrl+\`, or the palette to show it;
the choice is remembered. Anything that lives in the left panel (`Ctrl+Shift+F`, clicking a `#tag`, `Ctrl+Shift+E`)
shows it for you. `Esc` (with nothing else open) or a click outside closes the panel; the note, tabs and scroll
position are kept.

The header's *expand* button (also `dms ipc call supernote expand` and the palette) moves the same panel into a **real
window** that your compositor tiles, moves and resizes, with the left panel shown. The same button docks it back. The
panel always reopens docked.

**Resizing the docked panel**: drag its left edge (the cursor turns into a resize handle), or `Alt++` / `Alt+-`
(`Alt+=` works the same as `Alt++`) to grow or shrink it by a step. Double-click the handle, or the palette's
*Reset the docked panel's width*, to go back to the default. The width is remembered; it only applies while docked
(the expanded window is resized by your compositor as usual).

Header, left to right: vault menu, new note, today's daily note, new folder / sort by modified / refresh (left panel
only), pin the open note, toggle the right panel, toggle the left panel, expand / dock, close.

## Vaults

A vault is a folder of markdown files. The default is `~/Documents/notes`, created with a `Welcome.md` on first run.
The vault menu (top-left) switches vaults, removes one from the list (files are never deleted) and opens another
folder through a chooser. Hidden folders (`.obsidian`, `.trash`, ...) are never listed or touched.

Notes autosave one second after you stop typing and when you switch notes or close the panel. If a note changes on
disk while you have unsaved edits (a sync tool, another editor) a banner offers *Keep my edits* or *Reload from disk*
instead of overwriting either side.

## Notes and folders

- `Ctrl+N` creates `Untitled.md` in the selected folder (or the folder set by `.obsidian`'s *new file location*) with
  the cursor in the title; edit the title and press `Enter`: the file is renamed.
- `F2` edits the title of the open note. In the tree: `F2` rename, `Delete` move to the trash (`gio trash`, after a
  confirmation), right-click for *New note here*, *New folder here*, *Rename*, *Pin to top*, *Move to...*, *Delete*.
- **Renaming or moving** a note or folder that other notes link to asks *Update links* / *Rename only* / *Cancel*.
  Updated links keep their heading, alias and embed marker; code blocks and inline code are never rewritten. The
  originals of every touched note are backed up, and the vault menu has *Undo* for the last rename / move (notes you
  edited since are left alone).
- **Pinned** notes and the six most recent notes sit above the tree (the section headers collapse).

## Tabs and navigation

- Opening a note from the tree or a link replaces the current tab and pushes history; `Ctrl+click` a tree row, `Ctrl+T`
  or the `+` button opens a new tab. `Ctrl+W` or a middle click closes, `Ctrl+Tab` / `Ctrl+Shift+Tab` cycle.
  A note that is already open in another tab is switched to.
- `Alt+Left` / `Alt+Right` (or the arrows in the tab bar) go back / forward inside a tab (last 100).
- **Quick switcher** `Ctrl+O`: fuzzy search by name or path, recent notes first, a *Create ...* row when nothing matches
  exactly. `Enter` opens, `Ctrl+Enter` opens in a new tab.
- **Command palette** `Ctrl+P`: every action, fuzzy. Also *New note from template...*, *Insert template...*.
- **Right panel** (`Ctrl+Shift+B`): *Outline* (click to jump), *Backlinks* (with the linking line, click to jump),
  *Links* (this note's outgoing links; broken ones are dimmed and create the note when clicked).

## Writing

- `Ctrl+E` cycles **Edit → Split → Preview**. The formatting toolbar can be hidden from the palette.
- Shortcuts: `Ctrl+B` bold, `Ctrl+I` italic, `Ctrl+Shift+X` strikethrough, `Ctrl+Shift+C` inline code, `Ctrl+K` link,
  `Ctrl+L` toggle task, `Ctrl+1`…`6` heading level (`Ctrl+0` clears), `Tab` / `Shift+Tab` or `Ctrl+]` / `Ctrl+[`
  indent / outdent, `Ctrl+S` save now.
- `Enter` continues bullets, numbers, tasks and quotes (an empty item ends the list). `(`, `[`, `{` and `` ` `` auto-pair
  (`[[` gives `[[]]`); typing the closer skips over it.
- **Wikilinks**: `[[` opens note suggestions (`Up`/`Down`, `Enter`/`Tab` insert, `Esc` dismiss); notes whose names clash
  insert as `folder/Name`. `[[Note#Heading]]` and `[[Note|alias]]` work. Follow a link with `Ctrl+click` or
  `Ctrl+Enter` (caret on the link) in the editor, or a plain click in the Preview; a link to a note that does not
  exist creates it in the vault root.
- **Slash menu**: `/` at the start of a line lists headings, bullet / numbered list, task, quote, code block, table,
  callout, divider, link, today's date, current time and *Insert template...*.
- **Find** `Ctrl+F`, **replace** `Ctrl+H` (case and regex toggles, `Enter` = next).
- **Paste image** `Ctrl+V`: an image-only clipboard is saved as `Pasted image YYYYMMDDHHMMSS.png` in the attachments
  folder and `![[...]]` is inserted; any other clipboard content pastes as text.
- **Properties**: the collapsible *Properties* block under the title edits the frontmatter: change a value, remove a
  key, or add one at the bottom (`tags`, `aliases` and `cssclasses` take comma-separated lists).

### Preview

GitHub-flavoured markdown (tables, task lists, strikethrough), callouts (`> [!warning] Title`), footnotes,
`==highlight==`, images (`![[pic.png]]`, `![[pic.png|300]]`, `![](path)`), note embeds (`![[Note]]`, one level),
frontmatter as a properties box, `#tags` (click to browse them), and rendered **math** (`$x^2$`, `$$...$$`) and
**Mermaid** diagrams (see [RENDERING.md](RENDERING.md)). Click a task box to tick it.

## Search and tags

The left panel's tabs are *Files*, *Search*, *Tags*.

- **Search** (`Ctrl+Shift+F`): literal, smart-case (all lower-case ignores case) full-text search over every note, plus
  fuzzy note-name hits on top. Results are grouped by note with the match in bold; click a line to open the note at
  that line.
- **Tags**: inline `#tag` (not inside code) and frontmatter `tags:`, nested as `parent/child` with counts. Click a tag
  to list the notes that carry it or a nested tag. The index is read lazily and incrementally.

## Capture

- **Quick capture** `Super+Ctrl+N` opens a small markdown box that works with the panel closed. `Enter` is a new line
  (lists, tasks and quotes continue; `Ctrl+B/I/K/L`, headings, `Tab` and auto-pairing work as in the editor).
  `Ctrl+Enter` appends `- HH:MM text` under `## Captures` in today's daily note, `Ctrl+Shift+Enter` saves the text as
  its own note in `Inbox/` (named from its first line), `Esc` cancels.
- **Daily note**: the header button, the palette or `dms ipc call supernote daily`. Folder, date format and template
  come from `.obsidian/daily-notes.json` when the vault has one, else the SuperNote settings, else `Daily/` and
  `YYYY-MM-DD`.
- **Templates** live in `Templates/` (or the folder from `.obsidian/templates.json`). Variables: `{{title}}`,
  `{{date}}`, `{{time}}`, `{{date:FORMAT}}`, `{{time:FORMAT}}` (moment-style formats, `[literal]` text) and
  `{{cursor}}` (where the caret lands).
- From scripts: `supernote capture "text"`, `supernote clip` (captures the clipboard text). See [IPC.md](IPC.md).
