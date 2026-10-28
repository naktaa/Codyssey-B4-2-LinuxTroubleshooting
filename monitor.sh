#!/usr/bin/env bash

set -u
export LC_ALL=C

# The original two-argument collector remains available for manual PID/CSV collection.
sample_csv() {
    local pid=$1 log_file=$2 timestamp sample cpu rss mem state status
    if ! command -v ps >/dev/null || ! command -v date >/dev/null || ! command -v sleep >/dev/null; then
        printf 'Required command missing: ps, date, or sleep\n' >&2
        return 1
    fi
    if ! ps -p "$pid" -o pid= >/dev/null 2>&1; then
        printf 'Target PID %s is not running; no log was created.\n' "$pid" >&2
        return 1
    fi
    # A repeated invocation must not replace an existing evidence file.
    set -C
    if ! exec 3>"$log_file"; then
        printf 'Cannot create new monitor log: %s\n' "$log_file" >&2
        return 1
    fi
    if ! printf 'date_local,time_local,pid,cpu_percent_lifetime,rss_kib,mem_percent_system,status\n' >&3; then
        printf 'Cannot write monitor log: %s\n' "$log_file" >&2
        return 1
    fi
    while true; do
        if ! timestamp=$(date +'%Y-%m-%d,%H:%M:%S'); then
            printf 'Cannot read the clock.\n' >&2
            return 1
        fi
        # ps %CPU is a lifetime average, not the interval top measurement.
        if sample=$(ps -p "$pid" -o %cpu=,rss=,%mem=,stat= 2>/dev/null); then
            read -r cpu rss mem state <<< "$sample"
            if [[ -z ${cpu:-} || -z ${rss:-} || -z ${mem:-} || -z ${state:-} ]]; then
                printf 'Cannot parse ps data for PID %s.\n' "$pid" >&2
                return 1
            fi
            if [[ $state == Z* || $state == X* ]]; then status=EXITED; else status=RUNNING; fi
            if ! printf '%s,%s,%s,%s,%s,%s\n' "$timestamp" "$pid" "$cpu" "$rss" "$mem" "$status" >&3; then
                printf 'Cannot write monitor log: %s\n' "$log_file" >&2
                return 1
            fi
        elif [[ ! -e /proc/$pid ]]; then
            if ! printf '%s,%s,,,,EXITED\n' "$timestamp" "$pid" >&3; then
                printf 'Cannot write monitor log: %s\n' "$log_file" >&2
                return 1
            fi
            break
        else
            printf 'Cannot read ps data for PID %s.\n' "$pid" >&2
            return 1
        fi
        [[ $status == EXITED ]] && break
        if ! sleep 1; then
            printf 'Sampling was interrupted.\n' >&2
            return 1
        fi
    done
    printf 'Monitoring ended; log: %s\n' "$log_file"
}

if (( $# == 2 )); then
    if [[ ! $1 =~ ^[1-9][0-9]*$ || -z $2 ]]; then
        printf 'Usage: %s PID NEW_LOG_FILE\n' "$0" >&2
        exit 2
    fi
    sample_csv "$1" "$2"
    exit $?
fi

if (( $# != 3 && $# != 4 )); then
    printf 'Usage: %s MEMORY_LIMIT CPU_MAX_OCCUPY MULTI_THREAD_ENABLE [SECONDS]\n' "$0" >&2
    printf '       %s PID NEW_LOG_FILE\n' "$0" >&2
    exit 2
fi
duration=${4:-60}
if [[ ! $duration =~ ^[1-9][0-9]{0,2}$ ]] || (( duration < 15 || duration > 300 )); then
    printf 'SECONDS must be an integer from 15 to 300 (default: 60).\n' >&2
    exit 2
fi
if [[ ! -f ./prepare-env.sh || ! -f ./kill-agent-leak.sh ]]; then
    printf 'Run this script from the repository root.\n' >&2
    exit 2
fi
for tool in ps top date grep tail ss kill; do
    if ! command -v "$tool" >/dev/null; then
        printf 'Required command missing: %s\n' "$tool" >&2
        exit 2
    fi
done

# proc starttime distinguishes the launched process from later PID reuse.
start_tick() {
    local stat rest
    local -a fields
    [[ -r /proc/$1/stat ]] || return 1
    IFS= read -r stat < "/proc/$1/stat" || return 1
    rest=${stat##*) }
    read -r -a fields <<< "$rest"
    (( ${#fields[@]} >= 20 )) && [[ ${fields[19]} =~ ^[0-9]+$ ]] || return 1
    printf '%s\n' "${fields[19]}"
}

pid_state() {
    local state
    if state=$(ps -p "$1" -o stat= 2>/dev/null); then
        printf '%s\n' "$state"
    elif [[ ! -e /proc/$1 ]]; then
        printf 'absent\n'
    else
        printf 'unknown\n'
    fi
}

# A PID visible after cleanup may already belong to another process.
final_pid_state() {
    local state tick
    state=$(pid_state "$1")
    if [[ $state == absent || $state == unknown ]]; then
        printf '%s\n' "$state"
    elif tick=$(start_tick "$1" 2>/dev/null); then
        if [[ $tick == "$2" ]]; then
            printf '%s (same start tick)\n' "$state"
        else
            printf 'PID reused (current state %s belongs to another process)\n' "$state"
        fi
    else
        printf 'identity unknown (PID state %s)\n' "$state"
    fi
}

sample_threads() {
    local stamp=$1 elapsed=$2 state
    state=$(pid_state "$app_pid")
    if ! printf '\n[%s | elapsed ~%ss | app PID %s state %s]\n' "$stamp" "$elapsed" "$app_pid" "$state" >&6; then return 1; fi
    if [[ $state == absent || $state == Z* || $state == X* ]]; then return 0; fi
    if [[ $state == unknown ]]; then return 1; fi
    # ps -L shows only threads of the selected app child, including wait channel.
    if ! ps -L -p "$app_pid" -o pid,tid,stat,%cpu,rss,wchan:24,comm >&6; then
        state=$(pid_state "$app_pid")
        [[ $state == absent || $state == Z* || $state == X* ]]
    fi
}

# Report one representative log line per signal without turning it into a diagnosis.
show_log_signal() {
    local label=$1 pattern=$2 matches grep_result line
    if matches=$(grep -Eih "$pattern" "${app_logs[@]}" 2>/dev/null); then
        line=$(tail -n 1 <<< "$matches") || return 1
        printf '%s: observed — %s\n' "$label" "$line" >&3
    else
        grep_result=$?
        if (( grep_result == 1 )); then
            printf '%s: no matching line found\n' "$label" >&3
        else
            printf '%s: app log read failed (grep status %s); signals may be incomplete\n' "$label" "$grep_result" >&3
            return 1
        fi
    fi
}

# Parse only the second top frame; its %CPU is measured over the one-second interval.
save_top_interval() {
    local output=$1 stamp=$2 line frame=0 pid_col=-1 cpu_col=-1 time_col=-1 index pid ppid last_required
    local expected_start observed_start identity_status state
    local -a fields
    while IFS= read -r line; do
        if [[ $line == top\ -* ]]; then ((frame += 1)); pid_col=-1; continue; fi
        read -r -a fields <<< "$line"
        if [[ ${fields[0]:-} == PID ]]; then
            pid_col=-1; cpu_col=-1; time_col=-1
            for index in "${!fields[@]}"; do
                case ${fields[index]} in
                    PID) pid_col=$index ;;
                    %CPU) cpu_col=$index ;;
                    TIME+) time_col=$index ;;
                esac
            done
            if (( frame == 2 )); then
                (( pid_col >= 0 && cpu_col >= 0 && time_col >= 0 )) || return 1
                last_required=$pid_col
                if (( cpu_col > last_required )); then last_required=$cpu_col; fi
                if (( time_col > last_required )); then last_required=$time_col; fi
                # Earlier free-form fields can shift the split columns; reject that layout.
                for ((index = 0; index <= last_required; index++)); do
                    case ${fields[index]} in
                        PID|USER|PR|NI|VIRT|RES|SHR|S|%CPU|%MEM|TIME+) ;;
                        *) return 1 ;;
                    esac
                done
            fi
            continue
        fi
        if (( frame != 2 || pid_col < 0 || cpu_col < 0 || time_col < 0 )); then continue; fi
        pid=${fields[pid_col]:-}
        [[ $pid == "$launcher_pid" || $pid == "$app_pid" ]] || continue
        if [[ ! ${fields[cpu_col]:-} =~ ^[0-9]+([.][0-9]+)?$ || ! ${fields[time_col]:-} =~ ^[0-9]+:[0-9]{2}([.][0-9]+)?$ ]]; then return 1; fi
        if [[ $pid == "$launcher_pid" ]]; then expected_start=$launcher_start; else expected_start=$app_start; fi
        if observed_start=$(start_tick "$pid" 2>/dev/null); then
            if [[ $observed_start != "$expected_start" ]]; then
                printf 'PID %s was reused after the top frame; its row is not app evidence.\n' "$pid" >&2
                return 1
            fi
            identity_status=confirmed
        else
            state=$(pid_state "$pid")
            if [[ $state != absent && $state != Z* && $state != X* ]]; then return 1; fi
            # The top row is retained, but an exited PID cannot be identified afterward.
            identity_status=unconfirmed_after_exit
        fi
        # The launch-time parent link is already known; a later ps lookup can race exit.
        if [[ $pid == "$app_pid" ]]; then ppid=$launcher_pid; else ppid=; fi
        if ! printf '%s,%s,yes,%s,%s,%s,%s,%s\n' "$stamp" "$sample_number" "$pid" "$ppid" "${fields[cpu_col]}" "${fields[time_col]}" "$identity_status" >&4; then return 1; fi
        ((cpu_rows += 1))
        if [[ $pid == "$app_pid" ]]; then
            ((app_cpu_rows += 1))
            if [[ $identity_status == unconfirmed_after_exit ]]; then ((app_cpu_unconfirmed_rows += 1)); fi
        fi
    done <<< "$output"
    (( frame >= 2 && pid_col >= 0 && cpu_col >= 0 && time_col >= 0 ))
}

interrupted=0
trap 'interrupted=130' INT
trap 'interrupted=143' TERM
if ! source ./prepare-env.sh "$1" "$2" "$3"; then
    printf 'Setup failed. No unverified PID will be signaled; inspect any printed PID and app log.\n' >&2
    exit 1
fi
launcher_start=$(start_tick "$launcher_pid") || launcher_start=
app_start=$(start_tick "$app_pid") || app_start=
if [[ -z $launcher_start || -z $app_start ]]; then
    printf 'Cannot establish both process start identities. No PID will be signaled; inspect %s.\n' "$run_dir/app.log" >&2
    exit 1
fi

summary_file=$run_dir/observation.txt
cpu_file=$run_dir/cpu-samples.csv
thread_file=$run_dir/thread-observation.txt
monitor_file=$run_dir/monitor.csv
result=0
summary_open=0
cpu_open=0
thread_open=0
set -C
if exec 3>"$summary_file"; then summary_open=1; else result=1; fi
if exec 4>"$cpu_file"; then cpu_open=1; else result=1; fi
if exec 6>"$thread_file"; then thread_open=1; else result=1; fi
if (( summary_open )) && ! printf 'Settings: MEMORY_LIMIT=%s CPU_MAX_OCCUPY=%s MULTI_THREAD_ENABLE=%s; limit=%ss\nLauncher PID=%s start=%s; app PID=%s start=%s PPID=%s\n' "$MEMORY_LIMIT" "$CPU_MAX_OCCUPY" "$MULTI_THREAD_ENABLE" "$duration" "$launcher_pid" "$launcher_start" "$app_pid" "$app_start" "$launcher_pid" >&3; then result=1; fi
if (( cpu_open )) && ! printf 'time_local,sample,first_frame_excluded,pid,ppid_at_launch,cpu_percent_interval,cpu_time,identity_status\n' >&4; then result=1; fi
if (( thread_open )) && ! printf 'App PID %s thread samples, approximately every 15 seconds. %%CPU is a lifetime average.\n' "$app_pid" >&6; then result=1; fi

monitor_pid=
cpu_rows=0
app_cpu_rows=0
app_cpu_unconfirmed_rows=0
sample_number=0
if (( result == 0 && interrupted == 0 )); then
    sample_csv "$app_pid" "$monitor_file" 3>&- 4>&- 6>&- &
    monitor_pid=$!
    SECONDS=0
    next_thread=0
    while (( SECONDS < duration && interrupted == 0 && result == 0 )); do
        current_state=$(pid_state "$app_pid")
        if [[ $current_state == absent || $current_state == Z* || $current_state == X* ]]; then break; fi
        if [[ $current_state == unknown ]]; then result=1; break; fi
        if [[ $(start_tick "$app_pid" 2>/dev/null) != "$app_start" ]]; then
            printf 'App PID identity changed during observation.\n' >&2
            result=1
            break
        fi
        if (( SECONDS >= next_thread )); then
            stamp=$(date '+%Y-%m-%d %H:%M:%S %Z') || { result=1; break; }
            if ! sample_threads "$stamp" "$SECONDS"; then result=1; break; fi
            next_thread=$((SECONDS + 15))
        fi
        # -p keeps unrelated system processes out of the captured top output.
        if ! top_output=$(top -b -d 1 -n 2 -w 512 -p "$launcher_pid" -p "$app_pid" 2>&1); then
            current_state=$(pid_state "$app_pid")
            if [[ $current_state != absent && $current_state != Z* && $current_state != X* ]]; then
                printf 'top failed: %s\n' "$top_output" >&2
                result=1
            fi
            break
        fi
        stamp=$(date '+%Y-%m-%d %H:%M:%S %Z') || { result=1; break; }
        ((sample_number += 1))
        if ! save_top_interval "$top_output" "$stamp"; then
            printf 'Cannot parse or save a top interval sample.\n' >&2
            result=1
        fi
    done
fi

cutoff_state=$(pid_state "$app_pid")
cutoff_time=$(date '+%Y-%m-%d %H:%M:%S %Z') || { cutoff_time=unknown; result=1; }
if [[ $cutoff_state == unknown ]]; then result=1; fi
if [[ $cutoff_state != absent && $cutoff_state != Z* && $cutoff_state != X* ]] &&
   [[ $(start_tick "$app_pid" 2>/dev/null) != "$app_start" ]]; then
    cutoff_state=identity_changed
    result=1
fi
if [[ -n $monitor_pid ]]; then
    stop_requested=0
    if [[ $cutoff_state == absent || $cutoff_state == Z* || $cutoff_state == X* ]]; then
        # Allow one sampling tick for a natural EXITED row before reaping.
        sleep 1 || result=1
    elif kill -0 "$monitor_pid" 2>/dev/null; then
        if kill -TERM "$monitor_pid" 2>/dev/null; then stop_requested=1; fi
    fi
    # A trapped signal may interrupt wait; obtain the collector's final status.
    while true; do
        interrupted_before=$interrupted
        if wait "$monitor_pid"; then monitor_result=0; else monitor_result=$?; fi
        if (( monitor_result != 128 + 2 && monitor_result != 128 + 15 )); then break; fi
        if (( interrupted == interrupted_before )); then break; fi
        kill -TERM "$monitor_pid" 2>/dev/null || true
    done
    if (( monitor_result != 0 && (stop_requested == 0 || monitor_result != 143) )); then result=1; fi
else
    monitor_result=not_started
fi
if ! grep -Eq ',(RUNNING|EXITED)$' "$monitor_file" 2>/dev/null; then result=1; fi
if [[ $cutoff_state == absent || $cutoff_state == Z* || $cutoff_state == X* ]] &&
   ! grep -Eq ',EXITED$' "$monitor_file" 2>/dev/null; then result=1; fi
if ! grep -Fxq 'All Boot Checks Passed!' "$run_dir/app.log" || ! grep -Fxq 'Agent READY' "$run_dir/app.log"; then result=1; fi
if (( app_cpu_rows == 0 )); then result=1; fi

if (( summary_open )); then
    printf '\nBefore cleanup: %s; app state: %s\nCollection: CSV status=%s; CPU rows=%s (app=%s, identity unconfirmed=%s)\n' "$cutoff_time" "$cutoff_state" "$monitor_result" "$cpu_rows" "$app_cpu_rows" "$app_cpu_unconfirmed_rows" >&3 || result=1
    app_logs=("$run_dir/app.log")
    if [[ -e $run_dir/agent_app.log || -L $run_dir/agent_app.log ]]; then app_logs+=("$run_dir/agent_app.log"); fi
    printf 'App log signals:\n' >&3 || result=1
    show_log_signal 'MemoryGuard limit' 'Memory limit exceeded' || result=1
    show_log_signal 'MemoryGuard self-termination' 'Self-terminating|SELF-TERMINATED' || result=1
    show_log_signal 'CpuWorker threshold (internal Load, not OS CPU)' 'CPU Threshold Violated' || result=1
    show_log_signal 'Watchdog reference (protection exit unconfirmed)' 'WATCHDOG' || result=1
    show_log_signal 'Thread WAITING/BLOCKED' 'WAITING.*BLOCKED|BLOCKED.*WAITING' || result=1
    printf 'Last app.log line before cleanup:\n' >&3 || result=1
    tail -n 1 "$run_dir/app.log" >&3 2>/dev/null || result=1
    if (( app_cpu_unconfirmed_rows > 0 )); then
        printf 'CPU rows with unconfirmed identity require separate review in cpu-samples.csv.\n' >&3 || result=1
    fi
    if (( interrupted )); then printf 'Observation interrupted; evidence is partial.\n' >&3 || result=1; fi
    if (( result )); then printf 'Collection or boot evidence incomplete.\n' >&3 || result=1; fi
fi

# Cleanup begins only after the pre-cleanup state has been written.
trap '' INT TERM
if cleanup_output=$(bash ./kill-agent-leak.sh "$launcher_pid" "$launcher_start" "$app_pid" "$app_start" 2>&1); then cleanup_result=0; else cleanup_result=$?; result=1; fi
if (( summary_open )); then
    printf '\nTool cleanup status: %s\n%s\n' "$cleanup_result" "$cleanup_output" >&3 || result=1
    printf 'Final launcher state: %s; final app state: %s\n' "$(final_pid_state "$launcher_pid" "$launcher_start")" "$(final_pid_state "$app_pid" "$app_start")" >&3 || result=1
fi
exec 3>&- 4>&- 6>&-
printf 'Evidence: %s\n' "$run_dir"
if (( interrupted )); then exit "$interrupted"; fi
if (( result )); then
    printf 'Observation or cleanup incomplete; inspect the evidence and process state.\n' >&2
    exit 1
fi
printf 'Observation completed; incident type requires evidence interpretation.\n'
