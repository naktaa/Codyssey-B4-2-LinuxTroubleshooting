#!/usr/bin/env bash

if [[ ${BASH_SOURCE[0]} != "$0" ]]; then
    printf 'Run this script with: bash ./run-memory-observation.sh MEMORY_LIMIT CPU_MAX_OCCUPY MULTI_THREAD_ENABLE\n' >&2
    return 2
fi

set -u
export LC_ALL=C

if (( $# != 3 )); then
    printf 'Usage: bash ./run-memory-observation.sh MEMORY_LIMIT CPU_MAX_OCCUPY MULTI_THREAD_ENABLE\n' >&2
    exit 2
fi
if [[ ! -f ./prepare-env.sh || ! -f ./monitor.sh ]]; then
    printf 'Run this script from the repository root.\n' >&2
    exit 2
fi
for tool in awk date grep head tail ss; do
    if ! command -v "$tool" >/dev/null; then
        printf 'Required command missing: %s\n' "$tool" >&2
        exit 2
    fi
done

# Value ranges (MEMORY_LIMIT/CPU_MAX_OCCUPY/MULTI_THREAD_ENABLE) and HOME/AGENT_HOME
# are validated inside prepare-env.sh; this script only passes the arguments through.
if ! source ./prepare-env.sh "$1" "$2" "$3"; then
    printf 'Setup failed; inspect any PID, log path, and port printed above before retrying.\n' >&2
    exit 1
fi

csv="$run_dir/monitor.csv"
printf '\n=== MEMORY_LIMIT=%s MB, CPU_MAX_OCCUPY=%s%%, MULTI_THREAD_ENABLE=%s ===\n' \
    "$MEMORY_LIMIT" "$CPU_MAX_OCCUPY" "$MULTI_THREAD_ENABLE"
printf 'Evidence: run_dir=%s launcher_pid=%s app_pid=%s\n' "$run_dir" "$launcher_pid" "$app_pid"

result=0

# monitor.sh samples until the app reaches EXITED, then returns on its own.
if ! bash ./monitor.sh "$app_pid" "$csv"; then
    printf 'Monitoring failed. Inspect %s and the live processes.\n' "$run_dir" >&2
    exit 1
fi

first_running=$(awk -F, '$7 == "RUNNING" {print $1 " " $2; exit}' "$csv")
exit_observed=$(awk -F, '$7 == "EXITED" {print $1 " " $2; exit}' "$csv")
if [[ -z $first_running || -z $exit_observed ]]; then
    printf 'No complete RUNNING-to-EXITED observation was recorded in %s.\n' "$csv" >&2
    exit 1
fi
# Compare the same observation points; launch_local precedes the child start.
start_epoch=$(date -d "$first_running" +%s) || exit 1
end_epoch=$(date -d "$exit_observed" +%s) || exit 1
if (( end_epoch < start_epoch )); then
    printf 'The observation interval in %s is invalid.\n' "$csv" >&2
    exit 1
fi
max_rss=$(awk -F, 'NR > 1 && $7 == "RUNNING" && $5 ~ /^[0-9]+$/ && $5 + 0 > max {max = $5 + 0}
    END {print max + 0}' "$csv") || exit 1
if (( max_rss == 0 )); then
    printf 'No RSS samples were recorded in %s.\n' "$csv" >&2
    exit 1
fi

printf 'Observed interval: %s to %s (%s seconds; CSV sample times)\n' \
    "$first_running" "$exit_observed" "$((end_epoch - start_epoch))"
printf 'Highest sampled RSS: %s KiB\n' "$max_rss"
printf 'CSV sample rows (header, first, every tenth, EXITED):\n'
if ! awk -F, 'NR == 1 || NR == 2 || (NR > 2 && NR % 10 == 0) || $7 == "EXITED"' "$csv"; then
    result=1
fi
printf 'Initial app log lines (check boot):\n'
if ! head -n 25 "$run_dir/app.log"; then
    result=1
fi
printf 'Final app log lines (confirm the actual termination cause):\n'
if ! tail -n 15 "$run_dir/app.log"; then
    result=1
fi

# Identifying a child PID and collecting CSV rows do not prove app boot.
# MemoryGuard may terminate a successfully booted app later in this test.
if ! grep -Fxq 'All Boot Checks Passed!' "$run_dir/app.log" ||
   ! grep -Fxq 'Agent READY' "$run_dir/app.log"; then
    printf 'Boot success markers are missing from %s.\n' "$run_dir/app.log" >&2
    result=1
fi

# EXITED can be observed while a parent is still winding down. Wait briefly for
# both processes and the fixed port, but never terminate them ourselves.
settled=0
for attempt in 1 2 3 4 5; do
    child_state=$(ps -p "$app_pid" -o stat= 2>/dev/null) || child_state=
    launcher_state=$(ps -p "$launcher_pid" -o stat= 2>/dev/null) || launcher_state=
    if ! listeners=$(ss -H -ltn '( sport = :15034 )'); then
        printf 'Could not check port 15034.\n' >&2
        result=1
        break
    fi
    if [[ ( -z $child_state || $child_state == Z* || $child_state == X* ) &&
          ( -z $launcher_state || $launcher_state == Z* || $launcher_state == X* ) &&
          -z $listeners ]]; then
        settled=1
        break
    fi
    sleep 1 || { result=1; break; }
done

printf 'Evidence: %s, %s\n' "$run_dir/app.log" "$csv"
printf 'Process state after observation (an absent PID or Z/X means application work has ended):\n'
ps -p "$launcher_pid" -p "$app_pid" -o pid,ppid,stat,etime,args || true
printf 'Port 15034 listeners:\n'
ss -H -ltn '( sport = :15034 )' || printf 'Could not check port 15034.\n' >&2
printf 'The app was not stopped by this script. Check these PIDs and the port before another run.\n'

if (( settled == 0 )); then
    printf 'A process or port 15034 is still active; check PID %s and %s.\n' "$app_pid" "$launcher_pid" >&2
    result=1
fi
if (( result != 0 )); then
    printf 'Observation incomplete; inspect the evidence and any live app process.\n' >&2
    exit 1
fi
printf 'Observation finished; review the saved CSV and app log before drawing a conclusion.\n'
