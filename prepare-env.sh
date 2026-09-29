#!/usr/bin/env bash

# Sourcing keeps the app PID and evidence directory in the caller's shell.
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    printf 'Run this in the repository root with: source ./prepare-env.sh\n' >&2
    exit 2
fi

codyssey_prepare_env() {
    local tool architecture selected_binary agent_home key_file listeners account_uid run_root
    local selected_memory selected_cpu selected_threads run_stamp new_run_dir launch_local
    local existing_pid children attempt

    for tool in id uname ps date sleep mktemp ss cmp mkdir; do
        if ! command -v "$tool" >/dev/null; then
            printf 'Required command missing: %s\n' "$tool" >&2
            return 1
        fi
    done

    # Both the launcher and its child can outlive a failed setup attempt.
    for existing_pid in "${app_pid:-}" "${launcher_pid:-}"; do
        if [[ $existing_pid =~ ^[1-9][0-9]*$ ]] && ps -p "$existing_pid" -o pid= >/dev/null 2>&1; then
            printf 'PID %s is still present; inspect it before starting another run.\n' "$existing_pid" >&2
            return 1
        fi
    done

    if [[ $(uname -s) != Linux ]]; then
        printf 'Run this inside the Linux machine.\n' >&2
        return 1
    fi

    account_uid=$(id -u) || return 1
    if [[ $account_uid == 0 ]]; then
        printf 'Use a non-root Linux account.\n' >&2
        return 1
    fi

    architecture=$(uname -m) || return 1
    case "$architecture" in
        x86_64) selected_binary=./agent-app-leak/agent-leak-app-x86 ;;
        aarch64|arm64) selected_binary=./agent-app-leak/agent-leak-app-arm64 ;;
        *) printf 'Unsupported Linux architecture: %s\n' "$architecture" >&2; return 1 ;;
    esac
    if [[ ! -x $selected_binary ]]; then
        printf 'Binary is missing or not executable: %s\n' "$selected_binary" >&2
        return 1
    fi

    if ! listeners=$(ss -H -ltn '( sport = :15034 )'); then
        printf 'Cannot check port 15034 with ss.\n' >&2
        return 1
    fi
    if [[ -n $listeners ]]; then
        printf 'Port 15034 is already listening; inspect it before starting the app.\n' >&2
        return 1
    fi

    selected_memory=${MEMORY_LIMIT:-256}
    selected_cpu=${CPU_MAX_OCCUPY:-80}
    selected_threads=${MULTI_THREAD_ENABLE:-false}
    if [[ ! $selected_memory =~ ^[0-9]{2,3}$ ]] || (( 10#$selected_memory < 50 || 10#$selected_memory > 512 )); then
        printf 'MEMORY_LIMIT must be an integer from 50 to 512 MB.\n' >&2
        return 1
    fi
    if [[ ! $selected_cpu =~ ^[0-9]{2,3}$ ]] || (( 10#$selected_cpu < 10 || 10#$selected_cpu > 100 )); then
        printf 'CPU_MAX_OCCUPY must be an integer from 10 to 100 percent.\n' >&2
        return 1
    fi
    case "$selected_threads" in
        true|false|1|0|yes|no) ;;
        *) printf 'MULTI_THREAD_ENABLE must be true/false, 1/0, or yes/no.\n' >&2; return 1 ;;
    esac

    if [[ -z ${AGENT_HOME:-} && -z ${HOME:-} ]]; then
        printf 'Set HOME or AGENT_HOME before preparing the environment.\n' >&2
        return 1
    fi
    agent_home=${AGENT_HOME:-$HOME/agent-leak-lab}
    run_root=$PWD/runs
    key_file=$agent_home/api_keys/secret.key
    if ! mkdir -p "$agent_home/upload_files" "$agent_home/api_keys" "$run_root"; then
        printf 'Cannot create required directories under %s or %s.\n' "$agent_home" "$run_root" >&2
        return 1
    fi
    if [[ ! -w $agent_home/upload_files || ! -w $agent_home/api_keys || ! -w $run_root ]]; then
        printf 'Required directories are not writable under %s or %s.\n' "$agent_home" "$run_root" >&2
        return 1
    fi

    # Only create the public test key when no file or symlink is present.
    if [[ ! -e $key_file && ! -L $key_file ]]; then
        if ! (set -C; printf '%s' 'agent_api_key_test' > "$key_file"); then
            printf 'Cannot create the test key: %s\n' "$key_file" >&2
            return 1
        fi
    fi
    if ! printf '%s' 'agent_api_key_test' | cmp -s - "$key_file"; then
        printf 'Existing key differs from the public test value or cannot be read: %s\n' "$key_file" >&2
        return 1
    fi

    run_stamp=$(date +%Y-%m-%d_%H-%M-%S) || return 1
    if ! new_run_dir=$(mktemp -d "$run_root/run-$run_stamp-XXXXXX"); then
        printf 'Cannot create a new evidence directory under %s.\n' "$run_root" >&2
        return 1
    fi
    launch_local=$(date +'%Y-%m-%d %H:%M:%S') || return 1
    if ! printf 'launch_local=%s\n' "$launch_local" > "$new_run_dir/app.log"; then
        printf 'Cannot create the app log in %s.\n' "$new_run_dir" >&2
        return 1
    fi

    # Export only after the evidence files are ready; the app inherits these values.
    export AGENT_HOME="$agent_home"
    export AGENT_PORT=15034
    export AGENT_UPLOAD_DIR="$agent_home/upload_files"
    export AGENT_KEY_PATH="$agent_home/api_keys"
    export AGENT_LOG_DIR="$new_run_dir"
    export MEMORY_LIMIT="$selected_memory"
    export CPU_MAX_OCCUPY="$selected_cpu"
    export MULTI_THREAD_ENABLE="$selected_threads"
    binary=$selected_binary
    run_dir=$new_run_dir
    "$binary" >> "$run_dir/app.log" 2>&1 &
    launcher_pid=$!
    app_pid=

    # The provided executable starts a child that holds the growing RSS.
    for attempt in 1 2 3 4 5; do
        if ! ps -p "$launcher_pid" -o pid= >/dev/null 2>&1; then
            printf 'Launcher PID %s exited before its child was identified; inspect %s.\n' "$launcher_pid" "$run_dir/app.log" >&2
            return 1
        fi
        children=$(ps --ppid "$launcher_pid" -o pid= 2>/dev/null) || children=
        if [[ $children =~ ^[[:space:]]*([0-9]+)[[:space:]]*$ ]]; then
            app_pid=${BASH_REMATCH[1]}
            if ! ps -p "$app_pid" -o pid,ppid,stat,rss,args; then
                printf 'Child PID %s exited; inspect %s.\n' "$app_pid" "$run_dir/app.log" >&2
                return 1
            fi
            printf 'Started (boot unverified): launcher PID=%s, monitored PID=%s, log=%s\n' "$launcher_pid" "$app_pid" "$run_dir/app.log"
            return 0
        fi
        if [[ -n $children ]]; then
            printf 'Launcher PID %s has multiple children; select a target manually. Log: %s\n' "$launcher_pid" "$run_dir/app.log" >&2
            return 1
        fi
        sleep 1 || return 1
    done

    printf 'No child appeared under launcher PID %s; inspect %s.\n' "$launcher_pid" "$run_dir/app.log" >&2
    return 1
}

if codyssey_prepare_env; then
    unset -f codyssey_prepare_env
    return 0
else
    printf 'Preparation failed. Shell PID and log path values may be from an earlier run; they do not confirm a successful new run. Check the error and actual process state before continuing.\n' >&2
    unset -f codyssey_prepare_env
    return 1
fi
