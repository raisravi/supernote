#!/usr/bin/env bash
# Helpers for the UI smoke tests: drive the live SuperNote through `dms ipc call supernote ...` and assert on the
# `status` JSON (which includes the panel's real layout, see docs/IPC.md). Sourced by tests/ui/*.test.sh.

pass=0; fail=0; skip=0

ipc() { dms ipc call supernote "$@"; }
status() { ipc status 2>/dev/null; }
# field <jq expression>: value of an expression on the current status
field() { status | jq -r "$1" 2>/dev/null; }

ok() { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); echo "FAIL: $1"; [[ -n ${2:-} ]] && echo "  $2"; }

check() { # description expected actual
  if [[ "$2" == "$3" ]]; then ok; else bad "$1" "expected: $2 / actual: $3"; fi
}

# wait_for <description> <jq predicate on status> [timeout seconds]: passes as soon as the predicate is true
wait_for() {
  local desc=$1 pred=$2 timeout=${3:-8} i=0 last=""
  while (( i * 2 < timeout * 10 )); do
    last=$(status)
    if [[ $(jq -r "($pred) | tostring" <<< "$last" 2>/dev/null) == true ]]; then ok; return 0; fi
    sleep 0.2; i=$((i + 1))
  done
  bad "$desc" "predicate never became true: $pred; last status: $(jq -c . <<< "$last" 2>/dev/null | cut -c1-400)"
  return 1
}

wait_file() { # description path-glob [timeout]
  local desc=$1 glob=$2 timeout=${3:-10} i=0
  while (( i * 2 < timeout * 10 )); do
    # shellcheck disable=SC2086
    if compgen -G "$glob" >/dev/null; then ok; return 0; fi
    sleep 0.2; i=$((i + 1))
  done
  bad "$desc" "no file matching $glob"
  return 1
}

skip_note() { skip=$((skip + 1)); echo "skip: $1"; }

summary() { # name
  echo "$1: $pass passed, $fail failed, $skip skipped"
  [[ $fail -eq 0 ]]
}
