#!/usr/bin/env bash
# Drive the running SuperNote through its IPC and screenshot each state, for before/after comparison while refactoring
# or for the README screenshots. Uses a throwaway vault under $HOME and puts the default vault back afterwards.
#
#   scripts/dev/snapshot.sh <outdir>            full-screen grim captures + status JSON of every state
#
# Needs a running DMS session (niri/mango) and: dms, grim, jq. Screenshots contain whatever else is on screen: crop
# them before sharing (see docs/DEVELOPMENT.md).
set -uo pipefail
OUT=${1:?usage: snapshot.sh <outdir>}
mkdir -p "$OUT"
V=$HOME/sn-snap-vault
ipc() { dms ipc call supernote "$@"; }
shot() { sleep "${2:-2}"; grim "$OUT/$1.png"; }

rm -rf "$V"; mkdir -p "$V/Projects" "$V/Templates" "$V/Daily"
cat > "$V/Welcome.md" <<'MD'
---
status: draft
tags: [demo, project/alpha]
---
# Welcome

A note with **bold**, a [[Plan]] link, a #inline-tag and a task list:

- [ ] first
- [x] second

Inline math $x^2 + y^2 = z^2$ and a block:

$$
\int_0^\infty e^{-x^2}\,dx = \frac{\sqrt{\pi}}{2}
$$

```mermaid
graph TD
  A[Start] --> B{Ok?}
  B -->|yes| C[Done]
  B -->|no| A
```

> [!note] Callout
> Body text
MD
printf '# Plan\n\nSee [[Welcome]].\n\n#project/alpha\n' > "$V/Projects/Plan.md"
printf '# {{title}}\n{{date}}{{cursor}}\n' > "$V/Templates/Note.md"

ipc close >/dev/null 2>&1; sleep 1
ipc vault "$V" >/dev/null; sleep 3
ipc openNote Welcome >/dev/null; sleep 2
ipc viewMode edit >/dev/null

ipc status | jq -S . > "$OUT/status-initial.json"
ipc open >/dev/null;             shot 01-docked-edit 2.5
ipc sidebar >/dev/null;          shot 02-docked-sidebar 1.5
ipc sidebar >/dev/null
ipc viewMode split >/dev/null;   shot 03-docked-split 2.5
ipc viewMode preview >/dev/null; shot 04-docked-preview 9
ipc expand >/dev/null;           shot 05-window-preview 4
ipc viewMode edit >/dev/null;    shot 06-window-edit 2
ipc search plan >/dev/null;      shot 07-window-search 3
ipc dock >/dev/null;             shot 08-docked-again 2
ipc close >/dev/null;            sleep 1
ipc quick >/dev/null;            shot 09-capture-box 2
ipc quick >/dev/null;            sleep 1
ipc status | jq -S . > "$OUT/status-final.json"

ipc close >/dev/null 2>&1
ipc vault "$HOME/Documents/notes" >/dev/null; sleep 2
ipc removeVault "$V" >/dev/null
rm -rf "$V"
echo "snapshots in $OUT: $(ls "$OUT" | wc -l) files"
