#!/usr/bin/env bash

set -u
export LC_ALL=C

if [[ $# -ne 2 ]]; then
    printf 'Usage: %s PID NEW_LOG_FILE\n' "$0" >&2
    exit 2
fi

if [[ ! $1 =~ ^[1-9][0-9]*$ || -z $2 ]]; then
    printf 'Usage: %s PID NEW_LOG_FILE\n' "$0" >&2
    exit 2
fi

pid=$1
log_file=$2

if ! command -v ps >/dev/null || ! command -v date >/dev/null || ! command -v sleep >/dev/null; then
    printf 'Required command missing: ps, date, or sleep\n' >&2
    exit 1
fi

if ! ps -p "$pid" -o pid= >/dev/null 2>&1; then
    printf 'Target PID %s is not running; no log was created.\n' "$pid" >&2
    exit 1
fi

# noclobber prevents a repeated run from replacing evidence with the same path.
set -C
if ! exec 3>"$log_file"; then
    printf 'Cannot create new monitor log: %s\n' "$log_file" >&2
    exit 1
fi

if ! printf 'date_local,time_local,pid,cpu_percent_lifetime,rss_kib,mem_percent_system,status\n' >&3; then
    printf 'Cannot write monitor log: %s\n' "$log_file" >&2
    exit 1
fi

while true; do
    if ! timestamp=$(date +'%Y-%m-%d,%H:%M:%S'); then
        printf 'Cannot read the clock.\n' >&2
        exit 1
    fi

    # ps reports a lifetime CPU average; read the four fixed columns in order.
    if sample=$(ps -p "$pid" -o %cpu=,rss=,%mem=,stat= 2>/dev/null); then
        read -r cpu rss mem state <<< "$sample"
        if [[ -z ${cpu:-} || -z ${rss:-} || -z ${mem:-} || -z ${state:-} ]]; then
            printf 'Cannot parse ps data for PID %s.\n' "$pid" >&2
            exit 1
        fi

        # A zombie still has a PID, but it is no longer doing application work.
        if [[ $state == Z* || $state == X* ]]; then
            status=EXITED
        else
            status=RUNNING
        fi

        if ! printf '%s,%s,%s,%s,%s,%s\n' "$timestamp" "$pid" "$cpu" "$rss" "$mem" "$status" >&3; then
            printf 'Cannot write monitor log: %s\n' "$log_file" >&2
            exit 1
        fi
    elif [[ ! -e /proc/$pid ]]; then
        if ! printf '%s,%s,,,,EXITED\n' "$timestamp" "$pid" >&3; then
            printf 'Cannot write monitor log: %s\n' "$log_file" >&2
            exit 1
        fi
        break
    else
        printf 'Cannot read ps data for PID %s.\n' "$pid" >&2
        exit 1
    fi

    [[ $status == EXITED ]] && break
    if ! sleep 1; then
        printf 'Sampling was interrupted.\n' >&2
        exit 1
    fi
done

printf 'Monitoring ended; log: %s\n' "$log_file"
