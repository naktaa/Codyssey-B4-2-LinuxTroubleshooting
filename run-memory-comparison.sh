#!/usr/bin/env bash

if [[ ${BASH_SOURCE[0]} != "$0" ]]; then
    printf 'Run this script with: bash ./run-memory-comparison.sh\n' >&2
    return 2
fi

set -u

# Change only these values for the two runs. Keep the other settings equal.
BEFORE_MEMORY_LIMIT=128
AFTER_MEMORY_LIMIT=256
CPU_LIMIT=80
MULTI_THREAD=false
AGENT_HOME_DIR="${HOME:-}/agent-leak-lab"

if [[ ! -f ./prepare-env.sh || ! -f ./monitor.sh ]]; then
    printf 'Run this script from the repository root.\n' >&2
    exit 2
fi
if [[ -z ${HOME:-} || $AGENT_HOME_DIR != /* ]]; then
    printf 'HOME must be set and AGENT_HOME_DIR must be an absolute path.\n' >&2
    exit 2
fi
for limit in "$BEFORE_MEMORY_LIMIT" "$AFTER_MEMORY_LIMIT"; do
    if [[ ! $limit =~ ^[0-9]{2,3}$ ]] || (( 10#$limit < 50 || 10#$limit > 512 )); then
        printf 'Both memory limits must be integers from 50 to 512 MB.\n' >&2
        exit 2
    fi
done
if [[ $BEFORE_MEMORY_LIMIT == "$AFTER_MEMORY_LIMIT" ]]; then
    printf 'Use two different memory limits for the comparison.\n' >&2
    exit 2
fi
if [[ ! $CPU_LIMIT =~ ^[0-9]{2,3}$ ]] || (( 10#$CPU_LIMIT < 10 || 10#$CPU_LIMIT > 100 )); then
    printf 'CPU_LIMIT must be an integer from 10 to 100 percent.\n' >&2
    exit 2
fi
case "$MULTI_THREAD" in
    true|false|1|0|yes|no) ;;
    *) printf 'MULTI_THREAD must be true/false, 1/0, or yes/no.\n' >&2; exit 2 ;;
esac
for tool in awk grep head tail tee mktemp mkdir; do
    if ! command -v "$tool" >/dev/null; then
        printf 'Required command missing: %s\n' "$tool" >&2
        exit 2
    fi
done

# A subshell keeps each run's PID and exported settings separate from the next.
run_case() (
    local label=$1 limit=$2 csv first_running exit_observed start_epoch end_epoch max_rss
    local child_state launcher_state listeners attempt

    export AGENT_HOME="$AGENT_HOME_DIR"
    export MEMORY_LIMIT="$limit" CPU_MAX_OCCUPY="$CPU_LIMIT" MULTI_THREAD_ENABLE="$MULTI_THREAD"
    printf '\n=== %s: MEMORY_LIMIT=%s MB, CPU_MAX_OCCUPY=%s%%, MULTI_THREAD_ENABLE=%s ===\n' \
        "$label" "$MEMORY_LIMIT" "$CPU_MAX_OCCUPY" "$MULTI_THREAD_ENABLE"

    if ! source ./prepare-env.sh; then
        printf '%s setup failed; the next run will not start. Inspect any PID and log path printed above.\n' "$label" >&2
        return 1
    fi

    csv="$run_dir/monitor.csv"
    printf 'Evidence: run_dir=%s launcher_pid=%s app_pid=%s\n' "$run_dir" "$launcher_pid" "$app_pid"
    if ! bash ./monitor.sh "$app_pid" "$csv"; then
        printf '%s monitoring failed; the next run will not start. Inspect %s and the live processes.\n' "$label" "$run_dir" >&2
        return 1
    fi

    first_running=$(awk -F, '$7 == "RUNNING" {print $1 " " $2; exit}' "$csv")
    exit_observed=$(awk -F, '$7 == "EXITED" {print $1 " " $2; exit}' "$csv")
    if [[ -z $first_running || -z $exit_observed ]]; then
        printf '%s has no complete RUNNING-to-EXITED observation; the next run will not start.\n' "$label" >&2
        return 1
    fi
    # Compare the same observation points; launch_local precedes the child start.
    start_epoch=$(date -d "$first_running" +%s) || return 1
    end_epoch=$(date -d "$exit_observed" +%s) || return 1
    if (( end_epoch < start_epoch )); then
        printf '%s has an invalid observation interval; the next run will not start.\n' "$label" >&2
        return 1
    fi
    max_rss=$(awk -F, 'NR > 1 && $7 == "RUNNING" && $5 ~ /^[0-9]+$/ && $5 + 0 > max {max = $5 + 0}
        END {print max + 0}' "$csv") || return 1
    if (( max_rss == 0 )); then
        printf '%s has no RSS samples; the next run will not start.\n' "$label" >&2
        return 1
    fi
    printf 'Observed interval: %s to %s (%s seconds; CSV sample times)\n' \
        "$first_running" "$exit_observed" "$((end_epoch - start_epoch))"
    printf 'Highest sampled RSS: %s KiB\n' "$max_rss"
    printf 'CSV sample rows (header, first, every tenth, EXITED):\n'
    if ! awk -F, 'NR == 1 || NR == 2 || (NR > 2 && NR % 10 == 0) || $7 == "EXITED"' "$csv"; then
        return 1
    fi
    printf 'Initial app log lines (check boot):\n'
    if ! head -n 25 "$run_dir/app.log"; then
        return 1
    fi
    printf 'Final app log lines (confirm the actual termination cause):\n'
    if ! tail -n 15 "$run_dir/app.log"; then
        return 1
    fi
    # Identifying a child PID and collecting CSV rows do not prove app boot.
    # MemoryGuard may terminate a successfully booted app later in this test.
    if ! grep -Fxq 'All Boot Checks Passed!' "$run_dir/app.log" ||
       ! grep -Fxq 'Agent READY' "$run_dir/app.log"; then
        printf '%s boot success markers are missing in %s; the next run will not start.\n' \
            "$label" "$run_dir/app.log" >&2
        return 1
    fi

    # EXITED can be observed while a parent is still winding down. Wait briefly
    # for both processes and the fixed port, but never terminate them ourselves.
    for attempt in 1 2 3 4 5; do
        child_state=$(ps -p "$app_pid" -o stat= 2>/dev/null) || child_state=
        launcher_state=$(ps -p "$launcher_pid" -o stat= 2>/dev/null) || launcher_state=
        if ! listeners=$(ss -H -ltn '( sport = :15034 )'); then
            printf 'Could not check port 15034; the next run will not start.\n' >&2
            return 1
        fi
        if [[ ( -z $child_state || $child_state == Z* || $child_state == X* ) &&
              ( -z $launcher_state || $launcher_state == Z* || $launcher_state == X* ) &&
              -z $listeners ]]; then
            return 0
        fi
        if ! sleep 1; then
            return 1
        fi
    done
    printf 'A process or port 15034 is still active; the next run will not start. Check PID %s and %s.\n' \
        "$app_pid" "$launcher_pid" >&2
    return 1
)

run_root=$PWD/runs
if ! mkdir -p "$run_root"; then
    printf 'Cannot create the runs directory; no experiment was started.\n' >&2
    exit 1
fi
if ! comparison_dir=$(mktemp -d "$run_root/comparison-XXXXXX"); then
    printf 'Cannot create a unique comparison directory; no experiment was started.\n' >&2
    exit 1
fi
comparison_log=$comparison_dir/output.log
# The private, unique directory and noclobber creation preserve earlier logs.
if ! (set -C; : > "$comparison_log"); then
    printf 'Cannot create comparison log: %s; no experiment was started.\n' "$comparison_log" >&2
    exit 1
fi

run_comparison() {
    printf 'comparison_log=%s\nbefore_memory=%s after_memory=%s cpu_limit=%s multi_thread=%s agent_home=%s\n' \
        "$comparison_log" "$BEFORE_MEMORY_LIMIT" "$AFTER_MEMORY_LIMIT" "$CPU_LIMIT" "$MULTI_THREAD" "$AGENT_HOME_DIR" |
        tee -a "$comparison_log"
    pipeline_status=("${PIPESTATUS[@]}")
    experiment_status=${pipeline_status[0]}
    log_status=${pipeline_status[1]}
    if (( log_status != 0 )); then
        printf 'Cannot save comparison settings to %s; no experiment was started.\n' "$comparison_log" >&2
        return 1
    fi
    if (( experiment_status != 0 )); then
        return 1
    fi

    # Finish each tee pipeline before starting the next app. PIPESTATUS must
    # be captured immediately, before another command overwrites its values.
    run_case before "$BEFORE_MEMORY_LIMIT" 2>&1 | tee -a "$comparison_log"
    pipeline_status=("${PIPESTATUS[@]}")
    experiment_status=${pipeline_status[0]}
    log_status=${pipeline_status[1]}
    if (( log_status != 0 )); then
        printf 'Cannot save before output to %s; the after run will not start.\n' "$comparison_log" >&2
        return 1
    fi
    if (( experiment_status != 0 )); then
        return 1
    fi

    run_case after "$AFTER_MEMORY_LIMIT" 2>&1 | tee -a "$comparison_log"
    pipeline_status=("${PIPESTATUS[@]}")
    experiment_status=${pipeline_status[0]}
    log_status=${pipeline_status[1]}
    if (( log_status != 0 )); then
        printf 'Cannot save after output to %s.\n' "$comparison_log" >&2
        return 1
    fi
    if (( experiment_status != 0 )); then
        return 1
    fi
}

experiment_status=0
log_status=0
if run_comparison; then
    final_status=0
else
    final_status=1
fi
if (( final_status == 0 )); then
    summary='Both runs ended. Compare their logs and CSV files before drawing a conclusion.'
    if ! printf '\n%s\n' "$summary" >> "$comparison_log"; then
        printf 'Cannot save comparison summary to %s; final_exit_code=1\n' "$comparison_log" >&2
        exit 1
    fi
    printf '\n%s\n' "$summary"
fi
final_line="experiment_exit_code=$experiment_status log_exit_code=$log_status final_exit_code=$final_status"
if ! printf '%s\n' "$final_line" >> "$comparison_log"; then
    printf 'Cannot save final status to %s; final_exit_code=1\n' "$comparison_log" >&2
    exit 1
fi
printf '%s\ncomparison_log=%s\n' "$final_line" "$comparison_log"
exit "$final_status"
