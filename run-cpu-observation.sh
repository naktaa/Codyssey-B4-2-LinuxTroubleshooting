#!/usr/bin/env bash

if [[ ${BASH_SOURCE[0]} != "$0" ]]; then
    printf 'Run this with: bash ./run-cpu-observation.sh MEMORY_LIMIT CPU_MAX_OCCUPY MULTI_THREAD_ENABLE [SECONDS]\n' >&2
    return 2
fi

set -u
export LC_ALL=C
if (( $# != 3 && $# != 4 )); then
    printf 'Usage: bash ./run-cpu-observation.sh MEMORY_LIMIT CPU_MAX_OCCUPY MULTI_THREAD_ENABLE [SECONDS]\n' >&2
    exit 2
fi
duration=${4:-60}
if [[ ! $duration =~ ^[1-9][0-9]{0,2}$ ]] || (( duration < 15 || duration > 300 )); then
    printf 'SECONDS must be an integer from 15 to 300 (default: 60).\n' >&2
    exit 2
fi
if [[ ! -f ./prepare-env.sh || ! -f ./monitor.sh ]]; then
    printf 'Run this script from the repository root.\n' >&2
    exit 2
fi
for tool in ps top date grep; do
    if ! command -v "$tool" >/dev/null; then
        printf 'Required command missing: %s\n' "$tool" >&2
        exit 2
    fi
done

interrupted=0
trap 'interrupted=130; wait_interrupted=1' INT
trap 'interrupted=143; wait_interrupted=1' TERM
if ! source ./prepare-env.sh "$1" "$2" "$3"; then
    printf 'Setup failed; inspect the printed app PID, port and log before retrying.\n' >&2
    exit 1
fi
if (( interrupted )); then
    printf 'Interrupted; the app may remain alive: launcher=%s child=%s log=%s\n' "$launcher_pid" "$app_pid" "$run_dir/app.log" >&2
    exit "$interrupted"
fi

scope_file=$run_dir/process-scope.log
top_file=$run_dir/top-scope.csv
monitor_file=$run_dir/monitor.csv
# Refuse to overwrite even in a newly created run directory.
set -C
if ! exec 3>"$scope_file"; then
    printf 'Cannot create %s; app PIDs may remain: %s %s.\n' "$scope_file" "$launcher_pid" "$app_pid" >&2
    exit 1
fi
if ! exec 4>"$top_file"; then
    printf 'Cannot create %s; app PIDs may remain: %s %s.\n' "$top_file" "$launcher_pid" "$app_pid" >&2
    exit 1
fi
if ! printf 'Settings: MEMORY_LIMIT=%s CPU_MAX_OCCUPY=%s MULTI_THREAD_ENABLE=%s\nLauncher PID: %s  Selected child PID: %s\nDuration: %s seconds, approximately 1 second per sample\nFirst top frame is excluded from interval comparisons.\nUse PID/PPID/start times to identify app descendants; unrelated processes are not app CPU evidence.\n' \
    "$MEMORY_LIMIT" "$CPU_MAX_OCCUPY" "$MULTI_THREAD_ENABLE" "$launcher_pid" "$app_pid" "$duration" >&3 ||
   ! printf 'time_local,frame,first_frame,pid,cpu_percent,cpu_time\n' >&4; then
    printf 'Cannot write observation headers; app PIDs may remain: %s %s.\n' "$launcher_pid" "$app_pid" >&2
    exit 1
fi

bash ./monitor.sh "$app_pid" "$monitor_file" 3>&- 4>&- &
monitor_pid=$!
# exec makes top the direct child, avoiding an untracked filter/pipeline process.
coproc CPU_TOP { exec top -b -d 1 -n "$((duration + 1))" -w 512 3>&- 4>&-; }
# Bash can unset coproc variables at exit: save its PID and duplicate its read FD now.
top_pid=$!
result=0
if [[ -z ${CPU_TOP[0]:-} ]] || ! exec 5<&"${CPU_TOP[0]}"; then
    printf 'Cannot open the top output stream.\n' >&2
    result=1
fi
frame=0
rows=0
pid_column=-1
cpu_column=-1
time_column=-1
declare -A parents=() expected_pids=() observed_pids=()
launcher_sample=0
app_sample=0

# Validate after all rows in a frame, including the final frame at EOF.
check_frame_scope() {
    local expected_pid
    for expected_pid in "${!expected_pids[@]}"; do
        if [[ -z ${observed_pids[$expected_pid]:-} ]]; then
            printf 'Frame %s lacks app-related PID %s present in ps; top may be filtered or sampling times differ.\n' "$frame" "$expected_pid" >&2
            return 1
        fi
    done
    # The first frame is not an interval sample; unrelated rows cannot satisfy these checks.
    if (( frame > 1 )); then
        if [[ -n ${expected_pids[$launcher_pid]:-} && -n ${observed_pids[$launcher_pid]:-} ]]; then launcher_sample=1; fi
        if [[ -n ${expected_pids[$app_pid]:-} && -n ${observed_pids[$app_pid]:-} ]]; then app_sample=1; fi
    fi
    return 0
}

printf 'Observing launcher %s and selected child %s for about %s seconds. Evidence: %s\n' "$launcher_pid" "$app_pid" "$duration" "$run_dir"
while (( result == 0 && interrupted == 0 )); do
    # A timeout or signal must not be mistaken for successful end-of-file.
    if IFS= read -r -t 5 line <&5; then
        read -r -a fields <<< "$line"
    else
        read_result=$?
        if (( read_result != 1 && interrupted == 0 )); then
            printf 'Top output read failed or timed out (status %s).\n' "$read_result" >&2
            result=1
        fi
        break
    fi
    if [[ $line == top\ -* ]]; then
        pid_column=-1
    fi
    header=0
    # A process's COMMAND may itself contain the word PID; do not treat that as a header.
    if (( pid_column < 0 )) || [[ ! ${fields[pid_column]:-} =~ ^[0-9]+$ ]]; then
        for index in "${!fields[@]}"; do
            if [[ ${fields[index]} == PID ]]; then header=1; break; fi
        done
    fi
    if (( header )); then
        if ! check_frame_scope; then result=1; break; fi
        pid_column=-1
        cpu_column=-1
        time_column=-1
        for index in "${!fields[@]}"; do
            case ${fields[index]} in
                PID) pid_column=$index ;;
                %CPU) cpu_column=$index ;;
                TIME+) time_column=$index ;;
            esac
        done
        if (( pid_column < 0 || cpu_column < 0 || time_column < 0 )); then
            printf 'Top header lacks PID, %%CPU or TIME+; cannot collect this layout.\n' >&2
            result=1
            break
        fi
        last_required=$pid_column
        if (( cpu_column > last_required )); then last_required=$cpu_column; fi
        if (( time_column > last_required )); then last_required=$time_column; fi
        # Only known single-token fields may precede required values; ENVIRON/COMMAND can contain spaces.
        for ((index = 0; index <= last_required; index++)); do
            case ${fields[index]} in
                PID|USER|PR|NI|VIRT|RES|SHR|S|%CPU|%MEM|TIME+) ;;
                *)
                    printf 'Unsupported top field before required columns; cannot safely save this layout.\n' >&2
                    result=1
                    break ;;
            esac
        done
        if (( result )); then break; fi
        ((frame += 1))
        if ! stamp=$(date '+%Y-%m-%d %H:%M:%S %Z') ||
           ! snapshot=$(ps -e -o pid,ppid,lstart,cputime,stat,comm --forest) ||
           ! printf '\n========== %s | frame %s ==========\n' "$stamp" "$frame" >&3 ||
           ! printf '%s\n' "$snapshot" >&3; then
            printf 'Cannot save the process relationship snapshot.\n' >&2
            result=1
            break
        fi
        parents=()
        expected_pids=()
        observed_pids=()
        while read -r snapshot_pid snapshot_ppid remainder; do
            if [[ $snapshot_pid =~ ^[1-9][0-9]*$ && $snapshot_ppid =~ ^[0-9]+$ ]]; then
                parents[$snapshot_pid]=$snapshot_ppid
            fi
        done <<< "$snapshot"
        # Walk this snapshot's parent links only; retain lstart in the raw ps evidence for PID reuse review.
        for snapshot_pid in "${!parents[@]}"; do
            ancestor=$snapshot_pid
            while [[ -n ${parents[$ancestor]:-} ]]; do
                if [[ $ancestor == "$launcher_pid" || $ancestor == "$app_pid" ]]; then
                    expected_pids[$snapshot_pid]=1
                    break
                fi
                ancestor=${parents[$ancestor]}
            done
        done
        continue
    fi
    if (( pid_column >= 0 )) && [[ ${fields[pid_column]:-} =~ ^[0-9]+$ ]]; then
        if [[ ! ${fields[cpu_column]:-} =~ ^[0-9]+([.][0-9]+)?$ ||
              ! ${fields[time_column]:-} =~ ^[0-9]+:[0-9]{2}([.][0-9]{2})?$ ]]; then
            printf 'Unsupported top CPU or TIME+ value; observation is partial.\n' >&2
            result=1
            break
        fi
        # Store only these fields: COMMAND may contain arguments in the user's top configuration.
        if ! printf '%s,%s,%s,%s,%s,%s\n' "$stamp" "$frame" "$((frame == 1))" \
            "${fields[pid_column]}" "${fields[cpu_column]}" "${fields[time_column]}" >&4; then
            printf 'Cannot write the filtered top sample.\n' >&2
            result=1
            break
        fi
        observed_pids[${fields[pid_column]}]=1
        ((rows += 1))
    fi
done
if (( result == 0 && interrupted == 0 )); then
    if ! check_frame_scope; then result=1; fi
fi

# Stop/reap only our collectors; never signal the app or its launcher.
for collector_pid in "$top_pid" "$monitor_pid"; do
    stop_requested=0
    collector_state=$(ps -p "$collector_pid" -o stat= 2>/dev/null) || collector_state=
    if [[ -n $collector_state && $collector_state != Z* && $collector_state != X* ]]; then
        if kill -TERM "$collector_pid" 2>/dev/null; then stop_requested=1; fi
    fi
    # A trapped signal interrupts wait; retry to obtain the child's actual exit status.
    while true; do
        wait_interrupted=0
        if wait "$collector_pid"; then collector_result=0; else collector_result=$?; fi
        if (( wait_interrupted == 0 )); then break; fi
        if kill -TERM "$collector_pid" 2>/dev/null; then stop_requested=1; fi
    done
    if (( collector_result != 0 && (stop_requested == 0 || collector_result != 143) )); then
        printf 'Collector PID %s failed (status %s).\n' "$collector_pid" "$collector_result" >&2
        result=1
    fi
done
# Close the duplicated pipe only after reaping top, so cleanup cannot induce SIGPIPE.
exec 5<&- 3>&- 4>&-
if (( frame != duration + 1 || rows == 0 )); then
    printf 'Top collection incomplete: frames=%s, expected=%s, rows=%s.\n' "$frame" "$((duration + 1))" "$rows" >&2
    result=1
fi
if (( launcher_sample == 0 || app_sample == 0 )); then
    printf 'No valid interval sample for launcher or selected app PID; collection is incomplete.\n' >&2
    result=1
fi
if ! grep -Eq ',(RUNNING|EXITED)$' "$monitor_file" 2>/dev/null; then
    printf 'No monitor status samples saved in %s.\n' "$monitor_file" >&2
    result=1
fi
if ! grep -Fxq 'All Boot Checks Passed!' "$run_dir/app.log" ||
   ! grep -Fxq 'Agent READY' "$run_dir/app.log"; then
    printf 'Boot success markers missing from %s.\n' "$run_dir/app.log" >&2
    result=1
fi
printf 'Evidence directory: %s\nApp was not stopped. Check these PIDs and port 15034 before another run:\n' "$run_dir"
ps -p "$launcher_pid" -p "$app_pid" -o pid,ppid,stat,etime,comm || true
if (( interrupted )); then
    printf 'Interrupted; evidence is partial.\n' >&2
    exit "$interrupted"
fi
if (( result )); then
    printf 'Observation incomplete; inspect partial files and any live app process.\n' >&2
    exit 1
fi
printf 'Observation finished for the app PIDs checked in ps; top filters were not reset. CPU spike and protection policy still require evidence interpretation.\n'
