#!/usr/bin/env bash

if [[ ${BASH_SOURCE[0]} != "$0" ]]; then
    printf 'Run this script with: bash ./run-deadlock-observation.sh MEMORY_LIMIT CPU_MAX_OCCUPY MULTI_THREAD_ENABLE [SECONDS]\n' >&2
    return 2
fi

set -u

if (( $# != 3 && $# != 4 )); then
    printf 'Usage: bash ./run-deadlock-observation.sh MEMORY_LIMIT CPU_MAX_OCCUPY MULTI_THREAD_ENABLE [SECONDS]\n' >&2
    exit 2
fi
duration=${4:-60}
if [[ ! $duration =~ ^[1-9][0-9]*$ ]] || (( duration < 15 || duration > 300 || duration % 15 != 0 )); then
    printf 'SECONDS must be a multiple of 15 from 15 to 300 (default: 60).\n' >&2
    exit 2
fi
if [[ ! -f ./prepare-env.sh || ! -f ./monitor.sh ]]; then
    printf 'Run this script from the repository root.\n' >&2
    exit 2
fi
for tool in ps date sleep tail grep ss; do
    if ! command -v "$tool" >/dev/null; then
        printf 'Required command missing: %s\n' "$tool" >&2
        exit 2
    fi
done

# The sourced launcher supplies the child PID and a unique evidence directory.
if ! source ./prepare-env.sh "$1" "$2" "$3"; then
    printf 'Setup failed. Inspect any PID, log path, and port printed above before retrying.\n' >&2
    exit 1
fi

observation_file=$run_dir/thread-observation.txt
monitor_file=$run_dir/monitor.csv
set -C
if ! exec 3>"$observation_file"; then
    printf 'Cannot create %s; the app may still be running (child PID %s, launcher PID %s).\n' \
        "$observation_file" "$app_pid" "$launcher_pid" >&2
    exit 1
fi

if ! printf 'Settings: MEMORY_LIMIT=%s MB, CPU_MAX_OCCUPY=%s%%, MULTI_THREAD_ENABLE=%s\nChild PID: %s  Launcher PID: %s\nRun directory: %s\nObservation: %s seconds, every 15 seconds\n' \
    "$MEMORY_LIMIT" "$CPU_MAX_OCCUPY" "$MULTI_THREAD_ENABLE" "$app_pid" "$launcher_pid" "$run_dir" "$duration" >&3; then
    printf 'Cannot write %s; the app may still be running.\n' "$observation_file" >&2
    exit 1
fi

bash ./monitor.sh "$app_pid" "$monitor_file" &
monitor_pid=$!
interrupted=0
result=0
natural_exit=0
trap 'interrupted=130; wait_interrupted=1' INT
trap 'interrupted=143; wait_interrupted=1' TERM
printf 'Observing child PID %s for up to %s seconds. Evidence: %s\n' "$app_pid" "$duration" "$run_dir"

for ((elapsed = 0; elapsed < duration; elapsed += 15)); do
    if (( interrupted )); then
        result=$interrupted
        break
    fi
    state=$(ps -p "$app_pid" -o stat= 2>/dev/null) || state=
    if [[ -z $state || $state == Z* || $state == X* ]]; then
        natural_exit=1
        break
    fi
    if ! stamp=$(date '+%Y-%m-%d %H:%M:%S %Z'); then
        printf 'Cannot read the clock.\n' >&2
        result=1
        break
    fi
    if ! printf '\n========== %s | elapsed ~%ss ==========\n[Process]\n' "$stamp" "$elapsed" >&3; then
        printf 'Cannot write the observation file.\n' >&2
        result=1
        break
    fi
    if ! ps -p "$app_pid" -o pid,ppid,etime,stat,%cpu,rss,args >&3; then
        state=$(ps -p "$app_pid" -o stat= 2>/dev/null) || state=
        if [[ -z $state || $state == Z* || $state == X* ]]; then
            natural_exit=1
        else
            result=1
            printf 'Cannot record the process sample for PID %s.\n' "$app_pid" >&2
        fi
        break
    fi
    if ! printf '\n[Threads]\n' >&3 ||
       ! ps -L -p "$app_pid" -o pid,tid,stat,%cpu,rss,wchan:24,comm >&3; then
        state=$(ps -p "$app_pid" -o stat= 2>/dev/null) || state=
        if [[ -z $state || $state == Z* || $state == X* ]]; then
            natural_exit=1
        else
            result=1
            printf 'Cannot record the thread sample for PID %s.\n' "$app_pid" >&2
        fi
        break
    fi
    if ! printf '\n[Last 8 app.log lines]\n' >&3 ||
       ! tail -n 8 "$run_dir/app.log" >&3; then
        printf 'Cannot record the last app log lines.\n' >&2
        result=1
        break
    fi
    state=$(ps -p "$app_pid" -o stat= 2>/dev/null) || state=
    if [[ -z $state || $state == Z* || $state == X* ]]; then
        natural_exit=1
        break
    fi
    if ! sleep 15; then
        if (( interrupted )); then result=$interrupted; else result=1; fi
        break
    fi
done

# Stop only the monitor started here; never signal the workload or its launcher.
if (( natural_exit == 0 )); then
    state=$(ps -p "$app_pid" -o stat= 2>/dev/null) || state=
    if [[ -z $state || $state == Z* || $state == X* ]]; then natural_exit=1; fi
fi
stop_requested=0
if (( natural_exit == 0 )); then
    monitor_state=$(ps -p "$monitor_pid" -o stat= 2>/dev/null) || monitor_state=
    if [[ -n $monitor_state && $monitor_state != Z* && $monitor_state != X* ]]; then
        if kill -TERM "$monitor_pid" 2>/dev/null; then stop_requested=1; fi
    fi
fi
# A trapped signal interrupts wait; retry to retain the monitor's actual status.
while true; do
    wait_interrupted=0
    if wait "$monitor_pid"; then
        monitor_result=0
    else
        monitor_result=$?
    fi
    if (( wait_interrupted == 0 )); then break; fi
    if kill -TERM "$monitor_pid" 2>/dev/null; then stop_requested=1; fi
done
# Only a TERM sent here may account for a nonzero monitor status.
if (( monitor_result != 0 && (stop_requested == 0 || monitor_result != 143) )); then
    printf 'CSV monitoring failed with status %s; inspect %s.\n' "$monitor_result" "$monitor_file" >&2
    result=1
fi
if ! grep -Eq ',(RUNNING|EXITED)$' "$monitor_file" 2>/dev/null; then
    printf 'No CSV status samples were saved in %s.\n' "$monitor_file" >&2
    result=1
fi
if (( natural_exit == 1 && stop_requested == 0 && monitor_result == 0 )); then
    printf 'The app exited during observation; monitor.csv should contain EXITED.\n'
fi
if ! grep -Fxq 'All Boot Checks Passed!' "$run_dir/app.log" ||
   ! grep -Fxq 'Agent READY' "$run_dir/app.log"; then
    printf 'Boot success markers are missing from %s.\n' "$run_dir/app.log" >&2
    result=1
fi
exec 3>&-
trap - INT TERM

printf 'Evidence: %s, %s, %s\n' "$run_dir/app.log" "$monitor_file" "$observation_file"
printf 'Process state after observation (an absent PID or Z/X means application work has ended):\n'
ps -p "$launcher_pid" -p "$app_pid" -o pid,ppid,stat,etime,args || true
printf 'Port 15034 listeners:\n'
if ! ss -H -ltn '( sport = :15034 )'; then
    printf 'Could not check port 15034.\n' >&2
    result=1
fi
printf 'The app was not stopped by this script. Check these PIDs and the port before another run.\n'
if (( interrupted )); then
    printf 'Observation interrupted; collected evidence is partial.\n' >&2
    exit "$interrupted"
fi
if (( result != 0 )); then
    printf 'Observation incomplete; inspect the evidence and any live app process.\n' >&2
    exit 1
fi
printf 'Observation interval ended; compare the saved evidence before diagnosing a deadlock.\n'
