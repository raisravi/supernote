#!/usr/bin/env bash
# UI smoke test for a RUNNING SuperNote (DMS session required). It drives the panel through its IPC in a throw-away
# vault and asserts on the `status` JSON, on files it produces and on the shell's log. It takes about a minute, moves the
# panel around and switches vaults; it restores your vault and settings afterwards (Ctrl+C is safe too). Don't type into
# SuperNote while it runs.
#
#   make test-ui                       (or: bash tests/ui/smoke.test.sh)
#   SN_UI_SKIP_RENDER=1 make test-ui   skip the math / Mermaid checks (no typst / mmdr / network)
set -uo pipefail
cd "$(dirname "$0")"
# shellcheck source=lib.sh
source ./lib.sh

if ! command -v dms >/dev/null || ! ipc status >/dev/null 2>&1; then
  echo "smoke.test.sh: skipped (no running DMS with SuperNote; try 'make restart')"
  exit 0
fi

V=$(mktemp -d -p "$HOME" .sn-ui-smoke-XXXX)
TODAY=$(date +%F)
START=$(date '+%Y-%m-%d %H:%M:%S')

# The plugin only loads its saved settings (vault list, view mode, ...) the first time it opens (`ensureState`); read
# right after a `dms restart`, `status` reports pre-load defaults ("" vault, no vaults list, ...) rather than the
# user's real settings. Open-then-close once, unconditionally, before reading "the current state" to capture and
# restore, so a first-ever run right after a restart can't mistake those defaults for real settings and "restore"
# the user into an empty/bogus vault.
ipc open >/dev/null 2>&1; sleep 1; ipc close >/dev/null 2>&1

INIT=$(status)
INIT_VAULT=$(jq -r .vault <<< "$INIT")
INIT_VIEW=$(jq -r .viewMode <<< "$INIT")
INIT_TOOLBAR=$(jq -r .toolbar <<< "$INIT")
INIT_RIGHT=$(jq -r .rightPanel <<< "$INIT")
INIT_SIDEBAR=$(jq -r 'if .window == "dock" then .sidebar else null end' <<< "$INIT")   # the docked panel's own setting

restore() {
  trap - EXIT INT TERM
  ipc close >/dev/null 2>&1
  ipc dock >/dev/null 2>&1
  [[ $INIT_SIDEBAR != null && $(field .sidebar) != "$INIT_SIDEBAR" ]] && ipc sidebar >/dev/null 2>&1
  [[ $(field .toolbar) != "$INIT_TOOLBAR" ]] && ipc command toolbar >/dev/null 2>&1
  [[ $(field .rightPanel) != "$INIT_RIGHT" ]] && ipc command right-panel >/dev/null 2>&1
  ipc viewMode "$INIT_VIEW" >/dev/null 2>&1
  # never restore into an empty/bogus vault (see the note above) - if we somehow still don't have a real one, leave
  # whatever vault the fixture-vault removal below settles on rather than corrupt the vault list with ""
  [[ -n $INIT_VAULT ]] && ipc vault "$INIT_VAULT" >/dev/null 2>&1
  sleep 1
  ipc removeVault "$V" >/dev/null 2>&1
  rm -rf "$V"
}
trap restore EXIT INT TERM

# ---- fixture vault --------------------------------------------------------------------------------------------
mkdir -p "$V/Projects" "$V/Templates"
cat > "$V/A.md" <<'MD'
---
tags: [demo, project/alpha]
---
# Note A

A link to [[B]], a #inline-tag and inline math $x^2 + y^2 = z^2$.

$$
\frac{a}{b} + \sum_{i=0}^n x_i
$$

```mermaid
graph TD
  A[Start] --> B{Ok?}
  B -->|yes| C[Done]
```

hello smoke
MD
printf '# Note B\n\nback to [[A]]\n' > "$V/B.md"
printf '# {{title}}\n{{date}}{{cursor}}\n' > "$V/Templates/T.md"

# ---- vault + panel ------------------------------------------------------------------------------------------------
ipc vault "$V" >/dev/null
wait_for "the fixture vault becomes active with its 4 entries" ".vault == \"$V\" and .entries >= 4" 10

ipc dock >/dev/null
[[ $(field .sidebar) == true ]] && ipc sidebar >/dev/null
ipc viewMode edit >/dev/null
ipc open >/dev/null
wait_for "the panel opens docked and loads" '.visible and .panel.state == "ready" and .panel.visible and .panel.mode == "dock"' 10 || { echo "the panel did not load: nothing else can be tested"; summary "ui smoke"; exit 1; }
# the docked width is whatever the user has it set to (drag / Alt+ / Alt-); not assumed to be the 500px default
W0=$(field .panel.width)
check "the docked panel has a plausible width" 1 "$([[ $W0 -ge 360 ]] && echo 1 || echo 0)"
check "the left panel starts hidden" 0 "$(field .panel.sidebarWidth)"

ipc openNote A >/dev/null
wait_for "openNote A opens A.md" '.note == "A.md" and .bufferLength > 100 and (.dirty | not)' 8
wait_for "the editor fills the docked width" ".panel.editorWidth == $W0 and .panel.editorVisible and (.panel.previewVisible | not)" 5

# ---- view modes --------------------------------------------------------------------------------------------------------
ipc viewMode split >/dev/null
wait_for "split shows editor and preview" '.panel.editorVisible and .panel.previewVisible' 5
ipc viewMode preview >/dev/null
wait_for "preview hides the editor" '(.panel.editorVisible | not) and .panel.previewVisible' 5
ipc viewMode edit >/dev/null
wait_for "edit hides the preview" '.panel.editorVisible and (.panel.previewVisible | not)' 5
ipc viewMode bogus >/dev/null
check "an invalid view mode is ignored" edit "$(field .viewMode)"

# ---- left panel, tabs, right panel, commands ---------------------------------------------------------------------
ipc sidebar >/dev/null
wait_for "the left panel opens 280 px wide" '.sidebar and .panel.sidebarWidth == 280 and .panel.editorWidth < 300' 5
ipc command tags >/dev/null
wait_for "the tags tab is selected" '.sidebarTab == "tags"' 5
ipc command files >/dev/null
ipc sidebar >/dev/null
wait_for "the left panel closes again" '(.sidebar | not) and .panel.sidebarWidth == 0' 5

ipc command right-panel >/dev/null
wait_for "the right panel opens" '.rightPanel and .panel.rightPanelWidth == 300' 5
ipc command right-panel >/dev/null
wait_for "the right panel closes" '(.rightPanel | not) and .panel.rightPanelWidth == 0' 5

# resizing the docked panel (widen-panel/narrow-panel commands; Alt+ / Alt- do the same in the real UI, which
# cannot be driven from here). Round-trips exactly back to W0 so a real user's saved width is never left changed;
# skipped near the minimum width, where narrow-panel would clamp instead of moving by a full step.
if (( W0 - 40 >= 360 )); then
  ipc command narrow-panel >/dev/null
  wait_for "narrow-panel shrinks the panel by one step" ".panel.width == $((W0 - 40))" 5
  ipc command widen-panel >/dev/null
  wait_for "widen-panel grows it back to the starting width" ".panel.width == $W0" 5
else
  skip_note "panel resize (already within one step of the minimum width)"
fi

ipc command new-tab >/dev/null
wait_for "a second tab opens" '.tabs == 2' 5
ipc command close-tab >/dev/null
wait_for "and closes" '.tabs == 1' 5

ipc command toolbar >/dev/null
wait_for "the toolbar toggles off" ".toolbar == ($INIT_TOOLBAR | not)" 5
ipc command toolbar >/dev/null
wait_for "and back" ".toolbar == $INIT_TOOLBAR" 5

# overlays that have no other IPC: they must open without breaking the panel (checked again through the log below)
for c in palette cheatsheet properties find replace; do
  ipc command "$c" >/dev/null
  sleep 0.4
  check "command $c leaves the panel open" true "$(field '.panel.visible')"
done
ipc close >/dev/null; sleep 0.5; ipc open >/dev/null
wait_for "reopening resets the overlays and keeps the note" '.visible and .note == "A.md"' 8
ipc command properties >/dev/null   # it was opened above: toggle it back

# ---- expand to a window and back ------------------------------------------------------------------------------------
ipc expand >/dev/null
wait_for "expand makes a real window" '.window == "window" and .panel.mode == "window" and .panel.visible and .panel.width > 700' 10
ipc dock >/dev/null
wait_for "dock returns to the right side" '.window == "dock" and .panel.width == 500 and .panel.visible' 10

# ---- notes, capture, daily --------------------------------------------------------------------------------------------
ipc capture "ui smoke capture" >/dev/null
wait_file "capture writes the daily note" "$V/Daily/$TODAY.md" 12
sleep 1
check "the capture text is in the daily note" 1 "$(grep -c 'ui smoke capture' "$V/Daily/$TODAY.md" 2>/dev/null || echo 0)"
ipc daily >/dev/null
wait_for "daily opens today's note" ".note == \"Daily/$TODAY.md\"" 10

ipc quick >/dev/null
wait_for "the quick capture box opens" '.captureBox' 5
ipc quick >/dev/null
wait_for "and closes" '(.captureBox | not)' 5

ipc newNote >/dev/null
wait_for "newNote creates and opens an Untitled note (in the selected folder)" '.note | test("Untitled")' 10

ipc search hello >/dev/null
wait_for "search opens the search tab" '.sidebar and .sidebarTab == "search"' 8
ipc command files >/dev/null

# ---- math and Mermaid pictures ------------------------------------------------------------------------------------------
if [[ -n ${SN_UI_SKIP_RENDER:-} ]] || ! command -v typst >/dev/null; then
  skip_note "math / Mermaid pictures (SN_UI_SKIP_RENDER or no typst)"
else
  ipc openNote A >/dev/null
  wait_for "A.md is open again" '.note == "A.md"' 8
  ipc viewMode preview >/dev/null
  wait_for "math and the diagram render into pictures" '.renders.ok >= 3 and .renders.error == 0 and .renders.pending == 0' 45
  ipc viewMode edit >/dev/null
fi

# ---- back to a clean state ------------------------------------------------------------------------------------------------
ipc close >/dev/null
wait_for "close hides the panel" '(.visible | not)' 5

# ---- the shell log stays clean --------------------------------------------------------------------------------------------
if command -v journalctl >/dev/null; then
  errs=$(journalctl --user -u dms --since "$START" 2>/dev/null | grep -ciE 'SuperNote: the panel failed|TypeError|ReferenceError|is not a function|Type .* unavailable|Cannot read propert')
  check "no QML errors were logged while the test ran" 0 "${errs:-0}"
else
  skip_note "log check (no journalctl)"
fi

summary "ui smoke"
