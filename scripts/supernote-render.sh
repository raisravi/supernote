#!/usr/bin/env bash
# SuperNote math / Mermaid renderer: turns source text into a transparent 2x PNG (cached by the caller).
#
#   math    <srcfile> <out.png> <fg #rrggbb> <display 0|1>      LaTeX via typst + the mitex package
#   mermaid <srcfile> <out.png> <fg #rrggbb> <dark 0|1>         mmdr (pure-Rust Mermaid renderer)
#   prune                                                        delete cached pictures older than 45 days
#
# Prints "<width> <height>" (pixels) of the picture. The first math run downloads the mitex package (typst);
# Mermaid needs `mmdr` on PATH (cargo install mermaid-rs-renderer) or downloads a pinned release once into the
# cache dir; both are then offline.
set -euo pipefail

CACHE=${SN_CACHE:-$HOME/.cache/supernote/render}
# mmdr (mermaid-rs-renderer, pure Rust, no browser): PATH first, else a pinned + checksum-verified release binary.
MMDR_VERSION=0.3.1
MMDR_URL=${SN_MMDR_URL:-https://github.com/1jehuang/mermaid-rs-renderer/releases/download/v$MMDR_VERSION/mmdr-x86_64-unknown-linux-gnu.tar.gz}
MMDR_SHA256=${SN_MMDR_SHA256:-e1da47b758769bff21b82a480fad640a3b893a90fc0dc321551486f8b50c7200}
MAX_SRC_BYTES=20000
MAX_PX_W=6000
MAX_PX_H=5000

die() { echo "error: $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "$1 is not installed"; }

valid_color() { [[ ${1:-} =~ ^#[0-9a-fA-F]{6}$ ]] || die "bad color"; }

finish() { # <png> -> prints dimensions (refuses absurdly large pictures)
  [[ -s $1 ]] || die "nothing was rendered"
  local d w h
  d=$(magick identify -format '%w %h' "$1[0]")
  read -r w h <<< "$d"
  if (( w > MAX_PX_W || h > MAX_PX_H )); then rm -f "$1"; die "the picture would be too large"; fi
  printf '%s\n' "$d"
}

check_src() { [[ $(stat -c %s -- "$1") -le $MAX_SRC_BYTES ]] || die "source is too long to render"; }

# Path of a usable mmdr: $SN_MMDR, PATH, or the pinned release (downloaded once, SHA-256 verified).
find_mmdr() {
  if [[ -n ${SN_MMDR:-} ]]; then [[ -x $SN_MMDR ]] || die "SN_MMDR is not executable"; echo "$SN_MMDR"; return; fi
  command -v mmdr && return
  local bin=$CACHE/bin/mmdr-$MMDR_VERSION
  if [[ -x $bin ]]; then echo "$bin"; return; fi
  need curl; need tar
  [[ $(uname -m) == x86_64 && $(uname -s) == Linux ]] || die "no mmdr found: run 'cargo install mermaid-rs-renderer'"
  local tmp; tmp=$(mktemp -d "$CACHE/tmp-XXXXXX")
  curl -fsSL -m 120 -o "$tmp/mmdr.tgz" "$MMDR_URL" || { rm -rf "$tmp"; die "could not download mmdr (or run 'cargo install mermaid-rs-renderer')"; }
  if [[ $(sha256sum "$tmp/mmdr.tgz" | cut -d' ' -f1) != "$MMDR_SHA256" ]]; then rm -rf "$tmp"; die "the mmdr download does not match the pinned checksum"; fi
  tar -xzf "$tmp/mmdr.tgz" -C "$tmp" ./mmdr 2>/dev/null && [[ -f $tmp/mmdr ]] || { rm -rf "$tmp"; die "unexpected mmdr archive"; }
  mkdir -p "$CACHE/bin"; chmod +x "$tmp/mmdr"; mv -f "$tmp/mmdr" "$bin"; rm -rf "$tmp"
  echo "$bin"
}

cmd=${1:-}; shift || true
mkdir -p "$CACHE"

case $cmd in
  math)
    src=${1:-}; out=${2:-}; fg=${3:-}; display=${4:-0}
    [[ -f $src && -n $out ]] || die "usage: math <srcfile> <out.png> <fg> <display>"
    valid_color "$fg"; need typst; need magick; check_src "$src"
    if [[ -s $out ]]; then finish "$out"; exit 0; fi
    # top/bottom edge "bounds": stacked fractions and limits are not cropped to the font's cap height / baseline
    # sizes are a little above the preview's 16 px body text: Typst's math font looks smaller than the sans body font
    if [[ $display == 1 ]]; then body='#mitex(sys.inputs.src)'; size=15pt; else body='$#mimath(sys.inputs.src)$'; size=13.5pt; fi
    tmp=$(mktemp "$CACHE/tmp-XXXXXX.png")
    trap 'rm -f "$tmp" "$tmp.err"' EXIT
    # stdin -> stdout: the snap-packaged typst cannot read or write hidden folders like ~/.cache
    if ! printf '#import "@preview/mitex:0.2.7": *\n#set page(width: auto, height: auto, margin: 3pt, fill: none)\n#set text(size: %s, fill: rgb("%s"), top-edge: "bounds", bottom-edge: "bounds")\n%s\n' "$size" "$fg" "$body" \
        | timeout -k 2 25 typst compile --format png --ppi 192 --input "src=$(cat "$src")" - - > "$tmp" 2> "$tmp.err"; then
      msg=$(grep -m1 '^error' "$tmp.err" || true); rm -f "$tmp.err"; die "${msg:-typst failed}"
    fi
    rm -f "$tmp.err"
    mv -f "$tmp" "$out"; trap - EXIT
    finish "$out"
    ;;

  mermaid)
    src=${1:-}; out=${2:-}; dark=${4:-1}
    [[ -f $src && -n $out ]] || die "usage: mermaid <srcfile> <out.png> <fg> <dark>"
    valid_color "${3:-}"; need magick; need jq; check_src "$src"
    if [[ -s $out ]]; then finish "$out"; exit 0; fi
    mmdr=$(find_mmdr)
    work=$(mktemp -d "$CACHE/tmp-XXXXXX")
    trap 'rm -rf "$work"' EXIT
    if [[ $dark == 1 ]]; then theme=dark; else theme=default; fi
    # transparent background: the preview supplies its own; the built-in dark/default themes carry the colors
    printf '{"themeVariables":{"background":"transparent"}}\n' > "$work/cfg.json"
    # natural size first (also validates the syntax), then render at 2x for crisp HiDPI
    if ! size=$(timeout -k 2 20 "$mmdr" -i "$src" --size 2> "$work/err"); then
      die "mermaid could not draw this diagram: $(head -n1 "$work/err" | sed 's/^error: *//')"
    fi
    dims=$(jq -r '"\((.width * 2 | ceil)) \((.height * 2 | ceil))"' <<< "$size" 2>/dev/null) || die "mmdr gave no size"
    read -r w2 h2 <<< "$dims"
    [[ $w2 =~ ^[0-9]+$ && $h2 =~ ^[0-9]+$ && $w2 -gt 0 && $h2 -gt 0 ]] || die "mmdr gave a bad size"
    if (( w2 > MAX_PX_W || h2 > MAX_PX_H )); then die "the picture would be too large"; fi
    timeout -k 2 20 "$mmdr" -i "$src" -o "$work/out.png" -e png -t "$theme" -c "$work/cfg.json" -w "$w2" -H "$h2" 2> "$work/err" \
      || die "mermaid could not draw this diagram: $(head -n1 "$work/err" | sed 's/^error: *//')"
    mv -f "$work/out.png" "$out"
    finish "$out"
    ;;

  prune)
    find "$CACHE" -maxdepth 1 -type f -name '*.png' -mtime +45 -delete 2>/dev/null || true
    rm -f "$CACHE/mermaid.min.js"   # left over from the Chrome-based renderer
    find "$CACHE" -maxdepth 1 -name 'tmp-*' -mmin +30 -exec rm -rf {} + 2>/dev/null || true
    # keep at most the 800 newest pictures
    find "$CACHE" -maxdepth 1 -type f -name '*.png' -printf '%T@ %p\n' 2>/dev/null | sort -rn | tail -n +801 | cut -d' ' -f2- | while IFS= read -r f; do rm -f -- "$f"; done
    ;;

  *)
    die "usage: $(basename "$0") {math|mermaid|prune} ..."
    ;;
esac
