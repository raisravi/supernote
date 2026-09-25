#!/usr/bin/env bash
# Shell tests for supernote-vault.sh against a throwaway vault (kept under $HOME so gio trash works).
set -uo pipefail
S="$(cd "$(dirname "$0")/.." && pwd)/scripts/supernote-vault.sh"
V=$(mktemp -d -p "$HOME" .sn-vault-test-XXXX)/vault
trap 'rm -rf "$(dirname "$V")"' EXIT
pass=0; fail=0
check() { # desc expected actual
  if [[ "$2" == "$3" ]]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $1"; echo "  expected: $2"; echo "  actual:   $3"; fi
}
fails() { # desc cmd... : expect non-zero exit
  if "$@" >/dev/null 2>&1; then fail=$((fail + 1)); echo "FAIL: expected failure: $*"; else pass=$((pass + 1)); fi
}

"$S" init "$V" >/dev/null
check "init writes Welcome.md" "Welcome.md" "$(ls "$V")"

# ---- create / mkdir / rename / list ----
check "create" "Untitled.md" "$("$S" create "$V" "")"
check "create is unique" "Untitled 2.md" "$("$S" create "$V" "")"
check "mkdir" "Work" "$("$S" mkdir "$V" "" "Work")"
check "create in folder" "Work/Plan.md" "$("$S" create "$V" "Work" "Plan")"
check "rename note" "My Note.md" "$("$S" rename "$V" "Untitled.md" "My Note")"
check "rename folder" "Job" "$("$S" rename "$V" "Work" "Job")"
check "list has the renamed folder's note" "Job/Plan.md" "$("$S" list "$V" | jq -r '.[] | select(.path=="Job/Plan.md") | .path')"
fails "$S" rename "$V" "Untitled 2.md" "My Note"
mkdir -p "$V/.obsidian" "$V/Attachments"; echo x > "$V/.obsidian/h.md"; : > "$V/Attachments/pic.PNG"; echo t > "$V/notes.txt"
check "list: attachments indexed, hidden + non-notes skipped" "attachment:Attachments/pic.PNG" "$("$S" list "$V" | jq -r '.[] | select(.type=="attachment") | .type + ":" + .path')"
check "list: no hidden entries" "0" "$("$S" list "$V" | jq '[.[] | select(.path | test("^\\.|/\\."))] | length')"

# ---- path safety ----
for bad in "../x" "/etc/passwd" ".obsidian/h.md" "a/../../b" "a/./b"; do fails "$S" mtime "$V" "$bad"; done
fails "$S" create "$V" "" "../evil"; fails "$S" create "$V" "" ".hidden"; fails "$S" create "$V" "" 'a:b'
ln -s /etc "$V/lnk"; fails "$S" mtime "$V" "lnk/passwd"

# ---- trash ----
"$S" create "$V" "" "ZZ probe" >/dev/null
"$S" trash "$V" "ZZ probe.md" >/dev/null 2>&1
check "trash removes it from the vault" "0" "$("$S" list "$V" | jq '[.[] | select(.path=="ZZ probe.md")] | length')"
rm -f "$HOME/.local/share/Trash/files/ZZ probe"* "$HOME/.local/share/Trash/info/ZZ probe"*.trashinfo

# ---- backlinks ----
rm -f "$V/lnk"
printf 'target body\nself [[Target]]\n' > "$V/Target.md"
printf 'one [[Target]]\n' > "$V/A.md"
printf 'x\nsee [[Target|alias]] and [[Target#Sec]]\n' > "$V/B.md"
mkdir -p "$V/Sub"; printf '![[Target]]\n' > "$V/Sub/C.md"
printf '[[Target Two]] and [[Big Target]]\n' > "$V/D.md"
printf 'lower [[target]]\n' > "$V/E.md"
printf 'path form [[Sub/Target]]\n' > "$V/F.md"
printf '[[Target]]\n' > "$V/.obsidian/hidden.md"
printf '`[[Target]]` in code is still text to grep\n' > "$V/G.md"
got=$("$S" backlinks "$V" "Target.md" | jq -r '[.[].path] | sort | join(",")')
check "backlinks: files linking to Target (any link form, case-insensitive, no self/hidden/near-misses/other folders)" "A.md,B.md,E.md,G.md,Sub/C.md" "$got"
check "backlinks: line numbers and text" "2|x|see [[Target|alias]] and [[Target#Sec]]" "$("$S" backlinks "$V" "Target.md" | jq -r '.[] | select(.path=="B.md") | "\(.line)|x|\(.text)"')"
printf '[[Note (1)]] [[a.b]]\n' > "$V/H.md"
printf 'x\n' > "$V/Note (1).md"; printf 'x\n' > "$V/a.b.md"
check "backlinks: regex characters in names are literal" "H.md" "$("$S" backlinks "$V" "Note (1).md" | jq -r '[.[].path] | join(",")')"
check "backlinks: dot is literal" "H.md" "$("$S" backlinks "$V" "a.b.md" | jq -r '[.[].path] | join(",")')"
check "backlinks: none -> empty array" "[]" "$("$S" backlinks "$V" "A.md" | jq -c '.')"
fails "$S" backlinks "$V" "../x.md"


# duplicates: a path-form link only counts for the note it names; [[Name.md]] counts
mkdir -p "$V/p" "$V/q"; printf 'x\n' > "$V/p/Dup.md"; printf 'x\n' > "$V/q/Dup.md"
printf '[[p/Dup]]\n' > "$V/L1.md"; printf '[[q/Dup]]\n' > "$V/L2.md"; printf '[[Dup.md]]\n' > "$V/L3.md"
check "backlinks: path form only for its own note; bare and .md forms for both" "L1.md,L3.md" "$("$S" backlinks "$V" "p/Dup.md" | jq -r '[.[].path] | sort | join(",")')"
check "backlinks: other duplicate" "L2.md,L3.md" "$("$S" backlinks "$V" "q/Dup.md" | jq -r '[.[].path] | sort | join(",")')"
# cap at 500 without a broken pipe
printf 'x\n' > "$V/Many.md"; for i in $(seq 1 600); do printf '[[Many]]\n' > "$V/m$i.md"; done
check "backlinks: capped at 500, still valid JSON" "500" "$("$S" backlinks "$V" "Many.md" | jq 'length')"

# ---- search / readmany / candidates ----
export SN_STATE="$(dirname "$V")/state"
S2="$(dirname "$V")/v2"; "$S" init "$S2" >/dev/null; rm -f "$S2/Welcome.md"
mkdir -p "$S2/Sub"; printf 'alpha Beta.gamma\nno hit\nBETA again\n' > "$S2/n1.md"; printf 'beta lower\n' > "$S2/Sub/n2.md"; printf 'beta hidden\n' > "$S2/.hid.md"
check "search: literal + smart case (lower-case query ignores case), hidden skipped" "Sub/n2.md:1,n1.md:1,n1.md:3" "$("$S" search "$S2" "beta" | jq -r '[.[] | "\(.path):\(.line)"] | sort_by(if startswith("Sub") then 0 else 1 end) | join(",")')"
check "search: upper-case query is exact" "n1.md:3" "$("$S" search "$S2" "BETA" | jq -r '[.[] | "\(.path):\(.line)"] | join(",")')"
check "search: regex chars are literal" "n1.md:1" "$("$S" search "$S2" "Beta.gamma" | jq -r '[.[] | "\(.path):\(.line)"] | join(",")')"
check "search: no hit -> []" "[]" "$("$S" search "$S2" "zzzz" | jq -c .)"
check "search: text is returned" "alpha Beta.gamma" "$("$S" search "$S2" "gamma" | jq -r '.[0].text')"
check "readmany: existing notes only, text + sha" '["n1.md","alpha Beta.gamma\nno hit\nBETA again\n",64]' "$("$S" readmany "$S2" n1.md missing.md | jq -c '[keys[0], .["n1.md"].t, (.["n1.md"].h | length)]')"
printf '\xff\xfe bad\n' > "$S2/bin.md"
check "readmany: non-UTF-8 notes are skipped (never rewritten)" "{}" "$("$S" readmany "$S2" bin.md | jq -c .)"
fails "$S" readmany "$S2" "../x.md"
printf 'link [[Target Note]] and x\n' > "$S2/L.md"; printf 'plain\n' > "$S2/P.md"
check "candidates: notes mentioning the term inside [[ ]]" '["L.md"]' "$("$S" candidates "$S2" "Target Note" | jq -c .)"

# ---- apply (link-safe rename/move) + undo ----
A="$(dirname "$V")/v3"; "$S" init "$A" >/dev/null; rm -f "$A/Welcome.md"; mkdir -p "$A/Job"
printf 'self [[Old]]\n' > "$A/Old.md"; printf 'see [[Old]]\n' > "$A/Ref.md"; printf 'keep\n' > "$A/Job/Plan.md"
plan="$(dirname "$V")/plan.json"
hr=$(sha256sum "$A/Ref.md" | cut -d' ' -f1); ho=$(sha256sum "$A/Old.md" | cut -d' ' -f1)
jq -n -c --arg hr "$hr" --arg ho "$ho" '{from:"Old.md", to:"New.md", writes:[{path:"Ref.md", text:"see [[New]]\n", base:$hr},{path:"Old.md", text:"self [[New]]\n", base:$ho}]}' > "$plan"
bk=$("$S" apply "$A" "$plan")
check "apply: renamed" "New.md" "$(ls "$A" | grep -v Job | grep -v Ref | head -1)"
check "apply: linking note rewritten" "see [[New]]" "$(cat "$A/Ref.md")"
check "apply: moved note carries its own rewrite" "self [[New]]" "$(cat "$A/New.md")"
check "apply: originals are backed up" "see [[Old]]" "$(cat "$bk/files/Ref.md")"
printf 'edited later\n' >> "$A/Ref.md"
check "undo: restores untouched files, skips ones edited since" '{"restored":1,"skipped":1}' "$("$S" undo "$A" "$bk" | jq -c .)"
check "undo: name is back" "Old.md" "$(ls "$A" | grep '^Old')"
check "undo: edited file is left alone" "see [[New]]
edited later" "$(cat "$A/Ref.md")"
check "undo: self-link restored" "self [[Old]]" "$(cat "$A/Old.md")"
fails "$S" undo "$A" "$bk"
jq -n -c '{from:"Old.md", to:"Job/Plan.md", writes:[]}' > "$plan"; fails "$S" apply "$A" "$plan"
jq -n -c '{from:"Old.md", to:"../x.md", writes:[]}' > "$plan"; fails "$S" apply "$A" "$plan"
jq -n -c '{from:"Old.md", to:"Job/Moved.md", writes:[{path:"nope.md", text:"x"}]}' > "$plan"; fails "$S" apply "$A" "$plan"
check "apply: a failed plan changes nothing" "Old.md" "$(ls "$A" | grep '^Old')"
jq -n -c '{from:"Job", to:"Job/Inner", writes:[]}' > "$plan"; fails "$S" apply "$A" "$plan"
jq -n -c '{from:"Old.md", to:"Job/Moved.md", writes:[]}' > "$plan"; "$S" apply "$A" "$plan" >/dev/null
check "apply: move into a folder" "Job/Moved.md" "$(cd "$A" && ls Job/Moved.md)"
# stale plan: a file edited after planning aborts the whole apply; undo only accepts our backups
jq -n -c '{from:"Job/Moved.md", to:"Z.md", writes:[{path:"Ref.md", text:"x", base:"deadbeef"}]}' > "$plan"
before=$(cat "$A/Ref.md"); fails "$S" apply "$A" "$plan"
check "apply: stale plan changes nothing" "$before" "$(cat "$A/Ref.md")"
check "apply: stale plan leaves the note in place" "Job/Moved.md" "$(cd "$A" && ls Job/Moved.md)"
mkdir -p "$(dirname "$V")/fake"; echo '{"from":"a","to":"b","sha":{}}' > "$(dirname "$V")/fake/manifest.json"
fails "$S" undo "$A" "$(dirname "$V")/fake"
# ---- obsidian-config / put ----
O="$(dirname "$V")/v4"; "$S" init "$O" >/dev/null
check "obsidian-config: none -> {}" "{}" "$("$S" obsidian-config "$O" | jq -c .)"
mkdir -p "$O/.obsidian"; echo '{"folder":"Journal","format":"YYYY-MM-DD"}' > "$O/.obsidian/daily-notes.json"; echo 'not json' > "$O/.obsidian/app.json"; echo '{"attachmentFolderPath":"assets"}' > "$O/.obsidian/templates.json"
check "obsidian-config: reads what parses, ignores the rest" '{"daily":{"folder":"Journal","format":"YYYY-MM-DD"},"templates":{"attachmentFolderPath":"assets"}}' "$("$S" obsidian-config "$O" | jq -c .)"
check "obsidian-config: never writes inside .obsidian" "app.json daily-notes.json templates.json" "$(ls "$O/.obsidian" | paste -sd' ')"
src="$(dirname "$V")/src.md"; printf 'hello\n' > "$src"
check "put: creates folders and the note" "Daily/2026/x.md" "$("$S" put "$O" "Daily/2026/x.md" "$src")"
check "put: content" "hello" "$(cat "$O/Daily/2026/x.md")"
printf 'again\n' > "$src"; "$S" put "$O" "Daily/2026/x.md" "$src" >/dev/null
check "put: overwrites atomically" "again" "$(cat "$O/Daily/2026/x.md")"
printf 'first\n' > "$src"; rc=0; "$S" put "$O" "Daily/2026/x.md" "$src" new >/dev/null 2>&1 || rc=$?
check "put new: an existing note is left alone (exit 3)" "3|again" "$rc|$(cat "$O/Daily/2026/x.md")"
check "put new: creates when absent" "N.md" "$("$S" put "$O" "N.md" "$src" new)"
fails "$S" put "$O" "../x.md" "$src"; fails "$S" put "$O" ".hidden/x.md" "$src"; fails "$S" put "$O" "a/b.txt" "$src"; fails "$S" put "$O" "a/b:c.md" "$src"
ln -s /tmp "$O/esc"; fails "$S" put "$O" "esc/x.md" "$src"
check "read: prints a note" "again" "$("$S" read "$O" "Daily/2026/x.md")"
fails "$S" read "$O" "../x.md"; fails "$S" read "$O" "esc/passwd"; fails "$S" read "$O" "missing.md"
check "put new: the file it makes is world-readable like other notes" "644" "$(stat -c %a "$O/N.md")"
fails "$S" paste-image "$O" "Attachments" "../x"
echo "vault.test.sh: $pass passed, $fail failed"; [[ $fail -eq 0 ]]
