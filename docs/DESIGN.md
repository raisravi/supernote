# Design decisions

The decisions behind SuperNote, condensed from the original planning sessions. Each is a choice that is not obvious
from the code.

## Goal

Replace DMS's built-in Notepad (`Super+Shift+N`, a scratchpad of hidden `.txt` files) with an Obsidian-like markdown
editor over a plain-file vault. It lives in a plugin so DMS updates cannot overwrite it.

## Product decisions

| Topic | Decision | Why |
|---|---|---|
| Storage | plain `.md` files in user-chosen vaults, default `~/Documents/notes` | Obsidian / git / any editor keep working |
| Where it opens | docked panel on the right, sidebar hidden; *expand* moves it into a real floating window | quick to summon and dismiss; the window is there when you want a workspace |
| Editor | monospace source editor with a colored underlay, plus a rendered Preview and a Split view | QML cannot style ranges inside an editable text box, so a true live preview is impossible; an aligned colored copy behind a transparent editor is the closest (with an automatic plain-text fallback if the two ever disagree on height) |
| Links | Obsidian rules: `[[Name]]` matches by file name anywhere, `folder/Name` for duplicates, `#heading`, `\|alias`; clicking a missing link creates it in the vault root | familiar, predictable |
| Rename / move | confirm dialog *Update links / Rename only / Cancel*; originals backed up; undo | rewriting many of the user's files needs a safety net |
| Tabs | tabs with per-tab history, no split panes | enough for a side panel |
| Sidebar | Files / Search / Tags, hidden by default when docked; collapsible right panel (Outline / Backlinks / Links) | keeps the docked panel usable at ~500 px |
| Capture | a separate quick-capture box; `Enter` is a new line (markdown), `Ctrl+Enter` daily note, `Ctrl+Shift+Enter` Inbox note | fast capture without opening the panel; multi-line markdown notes |
| Obsidian compatibility | daily notes, templates and attachment settings are read from `.obsidian`, never written | works with an existing vault without touching its config |
| Shortcuts | fixed, Obsidian defaults | no keymap UI to maintain |
| Math and Mermaid | rendered to cached PNGs by external tools (`typst` + `mitex`, `mmdr`); raw text until a picture exists | Qt has no WebEngine here; the core must not depend on them |
| Out of scope | graph view, sync, plugins | |

## Technical decisions

- **One controller object, built from layers** (see [ARCHITECTURE.md](ARCHITECTURE.md)): the state is tightly shared, so
  focused files that extend each other beat a dozen cross-referencing services.
- **Pure JS for logic**: testable in node without a shell; QML stays glue.
- **All filesystem work in one bash script** with path validation: easy to test on a temp vault and to audit.
- **No file watchers**: inotify watches are exhausted on the target machine; external changes are detected on reopen and
  before saving (mtime).
- **Own state file**: DMS's per-plugin state writer stops working after a plugin reload.
- **Mermaid without a browser**: headless Chrome was heavy (two launches per diagram, sandbox / profile trouble). `mmdr`
  is a single pure-Rust binary; the cost is younger diagram coverage.
- **No index cache**: `find` / `ripgrep` per operation are fast enough for thousands of notes; tags are indexed lazily
  by mtime.
- **Autosave** one second after typing, on tab switch and on close; a conflict banner instead of silent overwrites.

## History

Built in six milestones (vault core, markdown, navigation, organization, capture & polish, math + Mermaid), then the
docked panel and markdown quick capture, then this repository and its code organization. See [CHANGELOG](../CHANGELOG.md).
