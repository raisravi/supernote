#!/usr/bin/env bash
# Run every test suite: node unit tests (pure JS libraries) and shell tests (vault + render scripts).
# node is looked up on PATH, then in ~/.nvm (this machine keeps it there).
set -uo pipefail
cd "$(dirname "$0")/.."

NODE=$(command -v node || true)
if [[ -z $NODE ]]; then
  NODE=$(ls -d "$HOME"/.nvm/versions/node/*/bin/node 2>/dev/null | tail -n1 || true)
fi
[[ -n $NODE ]] || { echo "node not found: install Node 18+ (only used to run the unit tests)"; exit 2; }

fail=0
for t in tests/*.test.js; do
  out=$("$NODE" "$t" 2>&1); rc=$?
  printf '%s\n' "$(printf '%s\n' "$out" | tail -n1)"
  [[ $rc -eq 0 ]] || { fail=1; printf '%s\n' "$out" | head -n 20; }
done
for t in tests/*.test.sh; do
  out=$(bash "$t" 2>&1); rc=$?
  printf '%s\n' "$(printf '%s\n' "$out" | tail -n1)"
  [[ $rc -eq 0 ]] || { fail=1; printf '%s\n' "$out" | head -n 20; }
done
exit $fail
