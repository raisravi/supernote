#!/usr/bin/env bash
# Shell tests for supernote-render.sh (math needs typst + network once for the mitex package; mermaid needs
# mmdr on PATH or network once for the pinned release). Missing tools are reported as skipped, not failed.
set -uo pipefail
R="$(cd "$(dirname "$0")/.." && pwd)/scripts/supernote-render.sh"
T=$(mktemp -d)
export SN_CACHE="$T/cache"
trap 'rm -rf "$T"' EXIT
pass=0; fail=0; skip=0
check() { if [[ "$2" == "$3" ]]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $1"; echo "  expected: $2"; echo "  actual:   $3"; fi; }
fails() { if "$@" >/dev/null 2>&1; then fail=$((fail + 1)); echo "FAIL: expected failure: $*"; else pass=$((pass + 1)); fi; }

printf '\\frac{a}{b} + \\sum_{i=0}^n x_i' > "$T/f.tex"
if command -v typst >/dev/null && command -v magick >/dev/null && dims=$("$R" math "$T/f.tex" "$T/m.png" '#e6e6e6' 1 2>/dev/null); then
  check "math: prints 'W H'" "1" "$([[ $dims =~ ^[0-9]+\ [0-9]+$ ]] && echo 1 || echo 0)"
  check "math: the PNG exists with those dimensions" "$(magick identify -format '%w %h' "$T/m.png")" "$dims"
  inline=$("$R" math "$T/f.tex" "$T/i.png" '#e6e6e6' 0)
  check "math: inline is flatter than display" "1" "$([[ ${inline##* } -lt ${dims##* } ]] && echo 1 || echo 0)"
  check "math: an existing picture is reused (same dims, no rerun)" "$dims" "$("$R" math "$T/f.tex" "$T/m.png" '#e6e6e6' 1)"
  printf '\\frac{' > "$T/bad.tex"
  fails "$R" math "$T/bad.tex" "$T/bad.png" '#e6e6e6' 0
  check "math: a failed render leaves no file behind" "0" "$(ls "$T" | grep -c '^bad.png$')"
  check "math: no temp files left in the cache" "0" "$(ls "$SN_CACHE" | grep -c '^tmp-')"
  fails "$R" math "$T/f.tex" "$T/x.png" 'red' 0
else
  skip=$((skip + 1)); echo "skip: math (typst/magick/network unavailable)"
fi

printf 'graph TD\n  A[Start] --> B{Ok?}\n  B -->|yes| C[Done]' > "$T/g.mmd"
if dims=$("$R" mermaid "$T/g.mmd" "$T/d.png" '#e6e6e6' 1 2>/dev/null); then
  check "mermaid: prints 'W H'" "1" "$([[ $dims =~ ^[0-9]+\ [0-9]+$ ]] && echo 1 || echo 0)"
  check "mermaid: the PNG exists with those dimensions" "$(magick identify -format '%w %h' "$T/d.png")" "$dims"
  check "mermaid: rendered at 2x (wider than the natural size)" "1" "$([[ ${dims% *} -gt 200 ]] && echo 1 || echo 0)"
  check "mermaid: transparent background" "0" "$(magick "$T/d.png" -format '%[fx:p{0,0}.a]' info:)"
  light=$("$R" mermaid "$T/g.mmd" "$T/l.png" '#111111' 0)
  check "mermaid: the light theme renders too" "1" "$([[ $light =~ ^[0-9]+\ [0-9]+$ ]] && echo 1 || echo 0)"
  printf 'graph TD\n  A -->' > "$T/bad.mmd"
  fails "$R" mermaid "$T/bad.mmd" "$T/bad2.png" '#e6e6e6' 1
  printf 'not a diagram' > "$T/bad3.mmd"
  fails "$R" mermaid "$T/bad3.mmd" "$T/bad3.png" '#e6e6e6' 1
  check "mermaid: a syntax error leaves no file behind" "0" "$(ls "$T" | grep -c '^bad[23].png$')"
  printf 'graph TD\n  A["<b>x & y</b>"] --> B' > "$T/esc.mmd"
  check "mermaid: html-special characters in labels are handled" "1" "$("$R" mermaid "$T/esc.mmd" "$T/e.png" '#e6e6e6' 0 >/dev/null 2>&1 && echo 1 || echo 0)"
  check "mermaid: no temp files left in the cache" "0" "$(ls "$SN_CACHE" | grep -c '^tmp-')"
else
  skip=$((skip + 1)); echo "skip: mermaid (no mmdr on PATH and no network)"
fi
# a download that fails its checksum must not be installed (forces the download path with an empty PATH lookup)
if command -v curl >/dev/null; then
  echo fake > "$T/fake.tgz"
  SN_CACHE="$T/dl" SN_MMDR_URL="file://$T/fake.tgz" SN_MMDR_SHA256=0000 PATH="/usr/bin:/bin" bash -c '
    command -v mmdr >/dev/null && exit 3   # mmdr on the system path: nothing to test
    "$0" mermaid "$1" "$2/x.png" "#e6e6e6" 1' "$R" "$T/g.mmd" "$T" >/dev/null 2>&1
  rc=$?
  if [[ $rc -ne 3 ]]; then
    check "mermaid: a download failing its checksum fails" "1" "$([[ $rc -ne 0 ]] && echo 1 || echo 0)"
    check "mermaid: ... and no binary is kept" "0" "$(ls "$T/dl/bin" 2>/dev/null | wc -l)"
  fi
fi
fails "$R" bogus
touch -d '60 days ago' "$SN_CACHE/old.png" 2>/dev/null; touch "$SN_CACHE/new.png"
"$R" prune
check "prune: removes old pictures only" "new.png" "$(ls "$SN_CACHE" | grep '\.png$' | grep -v '^tmp' | grep -E '^(old|new)\.png$' | paste -sd,)"

echo "render.test.sh: $pass passed, $fail failed, $skip skipped"; [[ $fail -eq 0 ]]
