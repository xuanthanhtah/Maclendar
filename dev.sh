#!/bin/zsh

set -euo pipefail

project_root="${0:A:h}"
cd "$project_root"

source_snapshot() {
  find Sources Tests -type f \( -name '*.swift' -o -name 'Package.swift' \) -print \
    | LC_ALL=C sort \
    | xargs stat -f '%m %N' \
    | shasum \
    | awk '{print $1}'
}

watch_loop() {
  local last_snapshot current_snapshot app_pid watcher_pid exit_code

  while true; do
    last_snapshot="$(source_snapshot)"
    print "Starting CalendarApp... (changes will restart it)"

    swift run &
    app_pid=$!

    (
      while kill -0 "$app_pid" 2>/dev/null; do
        sleep 1
        current_snapshot="$(source_snapshot)"
        if [[ "$current_snapshot" != "$last_snapshot" ]]; then
          print "Source change detected. Restarting..."
          kill "$app_pid" 2>/dev/null || true
          break
        fi
      done
    ) &
    watcher_pid=$!

    exit_code=0
    if ! wait "$app_pid"; then
      exit_code=$?
    fi

    kill "$watcher_pid" 2>/dev/null || true
    wait "$watcher_pid" 2>/dev/null || true

    current_snapshot="$(source_snapshot)"
    if [[ "$current_snapshot" == "$last_snapshot" ]]; then
      if [[ "$exit_code" -eq 0 ]]; then
        print "App exited cleanly. Stop the watcher or run again to relaunch."
        exit 0
      fi

      print "Run failed. Waiting for source changes before retrying..."
      sleep 2
    fi
  done
}

if [[ "${1:-}" == "--once" ]]; then
  swift run
else
  watch_loop
fi