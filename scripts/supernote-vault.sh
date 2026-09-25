#!/usr/bin/env bash
# SuperNote vault operations. All paths are relative to the vault root and validated
# to stay inside it; dot-files/folders (.obsidian, .trash, ...) are never touched.
#
#   init   <vault>                        create the vault (+ Welcome.md if empty)
#   list   <vault>                        JSON array of {type: dir|file|attachment, path, mtime, size}
#   create <vault> <dir> [name]           new empty note, unique name -> prints rel path
#   mkdir  <vault> <dir> <name>           new folder, unique name    -> prints rel path
#   rename <vault> <rel> <newname>        rename in place            -> prints new rel path
#   trash  <vault> <rel>                  move to the system trash (gio)
#   mtime  <vault> <rel>                  epoch seconds of a note
#   backlinks <vault> <rel>               notes linking to <rel>: [{path,line,text}]
#   search <vault> <query>                literal, smart-case full-text search: [{path,line,text}] (max 300)
#   readmany <vault> <rel>...             {rel: {t: text, h: sha256}} for readable UTF-8 notes (> 2 MB skipped)
#   candidates <vault> <term>...          notes that mention [[...term...]]: ["rel", ...]
#   apply <vault> <plan.json>             link-safe rename/move: plan {from, to, writes:[{path,text,base}]} (base = sha256 the
#                                         text was derived from; a changed file aborts the apply);
#                                         backs the touched files up, prints the backup dir
#   obsidian-config <vault>               {daily, templates, app} from .obsidian/*.json (read-only; {} when absent)
#   read <vault> <rel>                    print a note (validated, must stay inside the vault)
#   put <vault> <rel> <srcfile> [new]     write a note (creates folders inside the vault, atomic);
#                                         with "new" an existing note is left alone (exit 3)
#   paste-image <vault> <dir> <name>      save the clipboard image (wl-paste) as <dir>/<name>.png -> rel path
#   undo <vault> <backupdir>              revert an apply; prints {restored, skipped}
set -euo pipefail

die() { echo "error: $*" >&2; exit 1; }

vault_root() {
  [[ -n ${1:-} ]] || die "vault path required"
  mkdir -p "$1"
  realpath "$1"
}

# valid_rel <rel> [allow_empty]: relative, no '..', no dot-segments, no control chars
valid_rel() {
  local rel=$1 allow_empty=${2:-}
  if [[ -z $rel || $rel == "." ]]; then
    [[ -n $allow_empty ]] && return 0
    die "empty path"
  fi
  [[ $rel != /* ]] || die "path must be relative"
  [[ $rel != *$'\n'* && $rel != *$'\t'* ]] || die "bad characters in path"
  local seg
  IFS='/' read -ra segs <<< "$rel"
  for seg in "${segs[@]}"; do
    [[ -n $seg && $seg != "." && $seg != ".." ]] || die "bad path segment"
    [[ $seg != .* ]] || die "hidden paths are not allowed"
  done
}

# abs_in_vault <root> <rel>: resolved absolute path, guaranteed inside root
abs_in_vault() {
  local root=$1 rel=$2 abs
  valid_rel "$rel" allow_empty
  if [[ -z $rel || $rel == "." ]]; then printf '%s\n' "$root"; return; fi
  abs=$(realpath -m "$root/$rel")
  [[ $abs == "$root"/* ]] || die "path escapes the vault"
  printf '%s\n' "$abs"
}

valid_name() {
  local n=$1
  [[ -n $n && ${#n} -le 200 ]] || die "invalid name"
  [[ $n != . && $n != .. && $n != .* && $n != *. && $n != " "* && $n != *" " ]] || die "invalid name"
  [[ $n != *[/\\:*?\"\<\>\|]* ]] || die 'name cannot contain / \ : * ? " < > |'
  [[ $n != *[[:cntrl:]]* ]] || die "invalid name"
}

# unique_path <dir> <base> <ext> -> first free "<base><ext>", "<base> 2<ext>", ...
unique_path() {
  local dir=$1 base=$2 ext=$3 n=2 cand
  cand="$dir/$base$ext"
  while [[ -e $cand ]]; do cand="$dir/$base $n$ext"; n=$((n + 1)); done
  printf '%s\n' "$cand"
}

rel_of() { local root=$1 abs=$2; printf '%s\n' "${abs#"$root"/}"; }

cmd=${1:-}; shift || true
case $cmd in
  init)
    root=$(vault_root "${1:-}")
    if [[ -z $(find "$root" -mindepth 1 -maxdepth 1 -not -name '.*' -print -quit) ]]; then
      cat > "$root/Welcome.md" <<'MD'
# Welcome to SuperNote

Your notes live here as plain Markdown files, so any editor (or Obsidian) can open them.

- Create a note with **Ctrl+N**, rename it by editing the title above the text.
- Notes autosave as you type.
- Change or add vaults from the vault menu in the header.

Happy writing!
MD
    fi
    printf '%s\n' "$root"
    ;;

  list)
    root=$(vault_root "${1:-}")
    find "$root" -mindepth 1 \( -name '.*' -prune \) -o \
      \( -type d -printf 'd\t%P\t0\t0\n' \) -o \
      \( -type f -iname '*.md' -printf 'f\t%P\t%T@\t%s\n' \) -o \
      \( -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.gif' -o -iname '*.webp' -o -iname '*.svg' -o -iname '*.bmp' -o -iname '*.avif' \) -printf 'a\t%P\t%T@\t%s\n' \) 2>/dev/null \
      | jq -R -s -c 'split("\n") | map(select(length > 0) | split("\t")) | map({type: (if .[0] == "d" then "dir" elif .[0] == "a" then "attachment" else "file" end), path: .[1], mtime: (.[2] | tonumber | floor), size: (.[3] | tonumber)})'
    ;;

  create)
    root=$(vault_root "${1:-}"); dir=${2:-}; name=${3:-Untitled}
    valid_name "$name"
    d=$(abs_in_vault "$root" "$dir")
    [[ -d $d ]] || die "no such folder"
    f=$(unique_path "$d" "$name" ".md")
    : > "$f"
    rel_of "$root" "$f"
    ;;

  mkdir)
    root=$(vault_root "${1:-}"); dir=${2:-}; name=${3:-}
    valid_name "$name"
    d=$(abs_in_vault "$root" "$dir")
    [[ -d $d ]] || die "no such folder"
    f=$(unique_path "$d" "$name" "")
    mkdir "$f"
    rel_of "$root" "$f"
    ;;

  rename)
    root=$(vault_root "${1:-}"); rel=${2:-}; new=${3:-}
    abs=$(abs_in_vault "$root" "$rel")
    [[ -e $abs ]] || die "no such file"
    new=${new%.md}
    valid_name "$new"
    if [[ -d $abs ]]; then dest="$(dirname "$abs")/$new"; else dest="$(dirname "$abs")/$new.md"; fi
    [[ $dest == "$abs" ]] && { rel_of "$root" "$abs"; exit 0; }
    [[ ! -e $dest ]] || die "\"$new\" already exists"
    mv -n -- "$abs" "$dest"
    rel_of "$root" "$dest"
    ;;

  trash)
    root=$(vault_root "${1:-}"); rel=${2:-}
    abs=$(abs_in_vault "$root" "$rel")
    [[ -e $abs && $abs != "$root" ]] || die "nothing to trash"
    gio trash -- "$abs"
    ;;

  backlinks)
    root=$(vault_root "${1:-}"); rel=${2:-}
    abs=$(abs_in_vault "$root" "$rel"); [[ -f $abs ]] || die "no such note"
    name=$(basename "$abs" .md)
    esc_re() { printf '%s' "$1" | sed -E 's/[][(){}.^$*+?|\\\/-]/\\&/g'; }
    esc=$(esc_re "$name")
    # Link targets that can only mean this note: bare name, or any trailing folder path of it
    # (a/sub/Name.md is reachable as Name, sub/Name and a/sub/Name).
    prefixes=""; dir=$(dirname "$rel")
    while [[ $dir != . && $dir != / && -n $dir ]]; do
      prefixes+="$(esc_re "$dir")/|"
      [[ $dir == */* ]] && dir=${dir#*/} || dir=.
    done
    prefixes=${prefixes%|}
    pre=""; [[ -n $prefixes ]] && pre="(?:$prefixes)?"
    pat='\[\['"$pre$esc"'(?:\.md)?(?:#[^\]|\n]*)?(?:\|[^\]\n]*)?\]\]'
    rc=0
    hits=$(rg --json -i --no-ignore --glob '*.md' --glob '!**/.*' -e "$pat" -- "$root" 2>/dev/null) || rc=$?
    (( rc <= 1 )) || die "search failed"
    printf '%s\n' "$hits" \
      | jq -c --arg root "$root/" --arg self "$rel" 'select(.type=="match" and .data.path.text != null) | {path:(.data.path.text|ltrimstr($root)), line:.data.line_number, text:((.data.lines.text // "")|rtrimstr("\n"))} | select(.path != $self)' \
      | jq -s -c '.[0:500]'
    ;;

  search)
    root=$(vault_root "${1:-}"); q=${2:-}
    [[ -n $q ]] || { echo '[]'; exit 0; }
    rc=0
    hits=$(rg --json -F -S --no-ignore --glob '*.md' --glob '!**/.*' -m 20 -e "$q" -- "$root" 2>/dev/null) || rc=$?
    (( rc <= 1 )) || die "search failed"
    printf '%s\n' "$hits" \
      | jq -c --arg root "$root/" 'select(.type=="match" and .data.path.text != null) | {path:(.data.path.text|ltrimstr($root)), line:.data.line_number, text:((.data.lines.text // "")|rtrimstr("\n"))}' \
      | jq -s -c '.[0:300]'
    ;;

  readmany)
    root=$(vault_root "${1:-}"); shift || true
    for rel in "$@"; do
      abs=$(abs_in_vault "$root" "$rel")
      [[ -f $abs ]] || continue
      [[ $(stat -c %s -- "$abs") -le 2097152 ]] || continue
      iconv -f UTF-8 -t UTF-8 -- "$abs" >/dev/null 2>&1 || continue   # rewriting non-UTF-8 text would corrupt it
      jq -n -c --arg p "$rel" --arg h "$(sha256sum -- "$abs" | cut -d' ' -f1)" --rawfile t "$abs" '{($p): {t: $t, h: $h}}'
    done | jq -s -c 'add // {}'
    ;;

  candidates)
    root=$(vault_root "${1:-}"); shift || true
    [[ $# -gt 0 ]] || { echo '[]'; exit 0; }
    alt=""
    if [[ $# -gt 40 ]]; then set -- ""; fi   # too many names for one regex: every note with a link is a candidate
    for t in "$@"; do alt+="$(printf '%s' "$t" | sed -E 's/[][(){}.^$*+?|\\\/-]/\\&/g')|"; done
    alt=${alt%|}
    [[ -n $alt ]] || alt=""
    rc=0
    hits=$(cd "$root" && rg -l -i --no-ignore --glob '*.md' --glob '!**/.*' -e '\[\[[^\]\n]*(?:'"$alt"')' -- . 2>/dev/null) || rc=$?
    (( rc <= 1 )) || die "search failed"
    printf '%s\n' "$hits" | sed 's|^\./||' | jq -R -s -c 'split("\n") | map(select(length > 0))'
    ;;

  apply)
    root=$(vault_root "${1:-}"); plan=${2:-}
    [[ -f $plan ]] || die "no plan"
    from=$(jq -r '.from' "$plan"); to=$(jq -r '.to' "$plan")
    afrom=$(abs_in_vault "$root" "$from"); ato=$(abs_in_vault "$root" "$to")
    [[ -e $afrom && $afrom != "$root" ]] || die "no such file"
    [[ ! -e $ato ]] || die "\"$(basename "$to")\" already exists"
    valid_name "$(basename "$to" .md)"
    [[ -d $(dirname "$ato") ]] || die "no such folder"
    [[ -d $afrom && $ato == "$afrom"/* ]] && die "cannot move a folder into itself"
    state=${SN_STATE:-$HOME/.local/state/DankMaterialShell/plugins/supernote}
    bk="$state/backups/$(date +%s%N)"
    mkdir -p "$bk/files"
    n=$(jq '.writes | length' "$plan")
    for ((i = 0; i < n; i++)); do
      rel=$(jq -r ".writes[$i].path" "$plan"); abs=$(abs_in_vault "$root" "$rel")
      [[ -f $abs ]] || die "no such note: $rel"
      want=$(jq -r ".writes[$i].base // empty" "$plan")
      if [[ -n $want && $(sha256sum -- "$abs" | cut -d' ' -f1) != "$want" ]]; then
        rm -rf -- "$bk"; die "\"$rel\" changed while the rename was being prepared; try again"
      fi
      mkdir -p "$bk/files/$(dirname "$rel")"; cp -p -- "$abs" "$bk/files/$rel"
    done
    restore_all() {
      local r
      while IFS= read -r r; do cp -p -- "$bk/files/$r" "$root/$r"; done < <(jq -r '.writes[].path' "$plan")
    }
    shas="{}"
    for ((i = 0; i < n; i++)); do
      rel=$(jq -r ".writes[$i].path" "$plan"); abs="$root/$rel"
      tmp=$(mktemp "$abs.snXXXXXX")
      chmod --reference="$abs" -- "$tmp" 2>/dev/null || true
      if ! jq -j ".writes[$i].text" "$plan" > "$tmp" || ! mv -f -- "$tmp" "$abs"; then
        rm -f "$tmp"; restore_all; die "could not write $rel"
      fi
      shas=$(jq -c --arg p "$rel" --arg h "$(sha256sum -- "$abs" | cut -d' ' -f1)" '. + {($p): $h}' <<< "$shas")
    done
    if ! mv -n -- "$afrom" "$ato" || [[ -e $afrom || ! -e $ato ]]; then restore_all; die "could not move"; fi
    jq -n -c --arg from "$from" --arg to "$to" --argjson sha "$shas" '{from:$from, to:$to, sha:$sha}' > "$bk/manifest.json"
    ls -1d "$state"/backups/*/ 2>/dev/null | head -n -10 | while IFS= read -r old; do rm -rf -- "$old"; done
    printf '%s\n' "$bk"
    ;;

  undo)
    root=$(vault_root "${1:-}"); bk=${2:-}
    state=${SN_STATE:-$HOME/.local/state/DankMaterialShell/plugins/supernote}
    bk=$(realpath -m -- "$bk")
    [[ $bk == "$state"/backups/* && -f $bk/manifest.json ]] || die "nothing to undo"
    from=$(jq -r '.from' "$bk/manifest.json"); to=$(jq -r '.to' "$bk/manifest.json")
    afrom=$(abs_in_vault "$root" "$from"); ato=$(abs_in_vault "$root" "$to")
    [[ -e $ato ]] || die "the renamed note is gone; cannot undo"
    [[ ! -e $afrom ]] || die "\"$(basename "$from")\" exists again; cannot undo"
    mv -n -- "$ato" "$afrom"
    [[ -e $afrom && ! -e $ato ]] || die "could not move it back"
    restored=0; skipped=0
    while IFS= read -r rel; do
      abs=$(abs_in_vault "$root" "$rel")
      want=$(jq -r --arg p "$rel" '.sha[$p]' "$bk/manifest.json")
      if [[ -f $abs && $(sha256sum -- "$abs" | cut -d' ' -f1) == "$want" ]]; then
        cp -p -- "$bk/files/$rel" "$abs"; restored=$((restored + 1))
      else
        skipped=$((skipped + 1))
      fi
    done < <(jq -r '.sha | keys[]' "$bk/manifest.json")
    rm -rf -- "$bk"
    jq -n -c --argjson r "$restored" --argjson s "$skipped" '{restored:$r, skipped:$s}'
    ;;

  obsidian-config)
    root=$(vault_root "${1:-}")
    out="{}"
    for pair in daily:daily-notes templates:templates app:app; do
      key=${pair%%:*}; f="$root/.obsidian/${pair#*:}.json"
      [[ -f $f ]] || continue
      if merged=$(jq -c --arg k "$key" --slurpfile v "$f" '. + {($k): $v[0]}' <<< "$out" 2>/dev/null); then out=$merged; fi
    done
    printf '%s\n' "$out"
    ;;

  put)
    root=$(vault_root "${1:-}"); rel=${2:-}; src=${3:-}
    valid_rel "$rel"
    [[ $rel == *.md ]] || die "notes end in .md"
    valid_name "$(basename "$rel" .md)"
    [[ -f $src ]] || die "no source"
    abs=$(abs_in_vault "$root" "$rel")
    if [[ ${4:-} == new && -e $abs ]]; then echo "error: already exists" >&2; exit 3; fi
    mkdir -p -- "$(dirname "$abs")"
    [[ $(realpath "$(dirname "$abs")") == "$root" || $(realpath "$(dirname "$abs")") == "$root"/* ]] || die "path escapes the vault"
    tmp=$(mktemp "$abs.snXXXXXX")
    if [[ -e $abs ]]; then chmod --reference="$abs" -- "$tmp" 2>/dev/null || true; fi
    if [[ ${4:-} == new ]]; then
      # ln fails when the target exists: creation is atomic even if something else races us
      chmod 644 -- "$tmp"
      if cp -- "$src" "$tmp" && ln -- "$tmp" "$abs" 2>/dev/null; then rm -f "$tmp"; else rm -f "$tmp"; echo "error: already exists" >&2; exit 3; fi
    else
      cp -- "$src" "$tmp" && mv -f -- "$tmp" "$abs" || { rm -f "$tmp"; die "could not write"; }
    fi
    printf '%s\n' "$rel"
    ;;

  read)
    root=$(vault_root "${1:-}"); rel=${2:-}
    valid_rel "$rel"
    abs=$(abs_in_vault "$root" "$rel")
    [[ -f $abs ]] || die "no such note"
    cat -- "$abs"
    ;;

  paste-image)
    root=$(vault_root "${1:-}"); dir=${2:-}; name=${3:-}
    valid_name "$name"
    d=$(abs_in_vault "$root" "$dir")
    mkdir -p -- "$d"
    [[ $(realpath "$d") == "$root" || $(realpath "$d") == "$root"/* ]] || die "path escapes the vault"
    f=$(unique_path "$d" "$name" ".png")
    types=$(wl-paste --list-types 2>/dev/null || true)
    if grep -qx 'image/png' <<< "$types"; then
      wl-paste --type image/png > "$f" 2>/dev/null || true
    elif t=$(grep -m1 '^image/' <<< "$types") && [[ -n $t ]]; then
      wl-paste --type "$t" 2>/dev/null | magick - "png:$f" 2>/dev/null || true
    fi
    if [[ ! -s $f ]]; then rm -f "$f"; die "no image on the clipboard"; fi
    rel_of "$root" "$f"
    ;;

  mtime)
    root=$(vault_root "${1:-}"); rel=${2:-}
    abs=$(abs_in_vault "$root" "$rel")
    stat -c %Y -- "$abs"
    ;;

  *)
    die "usage: $(basename "$0") {init|list|create|mkdir|rename|trash|mtime|backlinks|search|readmany|read|candidates|apply|undo|obsidian-config|put|paste-image} <vault> ..."
    ;;
esac
