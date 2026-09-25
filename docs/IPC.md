# IPC reference

SuperNote registers the IPC target `supernote` with DMS. Every verb is called as

```sh
dms ipc call supernote <verb> [argument]
```

and prints one line of text. Verbs that need the vault (or the state file) wait for it to be ready, so they are safe
to call right after start-up. The panel opens on the focused screen.

| Verb | Argument | Does |
|---|---|---|
| `toggle` | – | open the panel if closed, close it otherwise (prints `opened` / `closed`) |
| `open` / `close` | – | open (docked) / close the panel |
| `expand` | – | open the panel as a real window |
| `dock` | – | dock the window back to the right side |
| `sidebar` | – | toggle the left panel for the current mode (prints `sidebar shown` / `sidebar hidden`) |
| `openNote` | `<name>` | open the note whose name or path matches (case-insensitive, `.md` optional) |
| `newNote` | – | create a note in the selected folder and focus its title |
| `daily` | – | open today's daily note, creating it from the daily template |
| `quick` | – | toggle the quick-capture box |
| `capture` | `<text>` | append `- HH:MM text` to today's daily note (panel closed or open) |
| `clip` | – | capture the current clipboard text like `capture` |
| `search` | `<query>` | open the panel on the Search tab with the query filled in |
| `command` | `<id>` | run a palette command in the panel (ids below) |
| `viewMode` | `edit` / `split` / `preview` | set the view mode |
| `vault` | `<path>` | add the folder as a vault (if new) and switch to it (`~` is expanded) |
| `removeVault` | `<path>` | forget a vault (its files are never deleted) |
| `status` | – | JSON snapshot for scripts and tests |

`command` ids (see `js/commands.js`): `new-note`, `new-from-template`, `insert-template`, `daily`, `capture`,
`switcher`, `rename`, `pin`, `delete`, `toggle-view`, `right-panel`, `toggle-sidebar`, `expand-window`, `toolbar`,
`properties`, `search`, `tags`, `files`, `back`, `forward`, `new-tab`, `close-tab`, `find`, `replace`, `undo-rename`,
`add-vault`, `palette`, `cheatsheet`. Commands that need an open note do nothing without one.

## `status`

```json
{"visible": true, "vault": "/home/ravi/Documents/notes", "vaults": ["/home/ravi/Documents/notes"],
 "note": "Daily/2026-09-25.md", "dirty": false, "conflict": false,
 "entries": 42, "rows": 9, "bufferLength": 1830, "viewMode": "edit"}
```

## Examples

```sh
# capture from anywhere, e.g. a shell alias or a launcher entry
dms ipc call supernote capture "call the dentist"

# capture the current selection (Wayland primary selection)
dms ipc call supernote capture "$(wl-paste --primary)"

# jump straight into a search
dms ipc call supernote search "TODO"

# a status bar item that shows whether a note has unsaved edits
dms ipc call supernote status | jq -r 'if .dirty then "unsaved" else "saved" end'
```

Key bindings are ordinary compositor binds that spawn these calls; see
[CONFIGURATION.md](CONFIGURATION.md#key-bindings).
