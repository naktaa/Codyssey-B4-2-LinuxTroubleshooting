#!/usr/bin/env bash

set -u
export LC_ALL=C

for tool in ps kill sleep ss id readlink; do
    if ! command -v "$tool" >/dev/null; then
        printf 'Required command missing: %s\n' "$tool" >&2
        exit 1
    fi
done

uid=$(id -u) || exit 1
declare -a targets=() starts=() executables=()
result=0

# The start tick is field 22 of /proc/PID/stat, after the parenthesized name.
identity() {
    local pid=$1 expected_start=$2 expected_exe=$3 stat rest owner exe
    local -a fields
    [[ -e /proc/$pid ]] || return 1
    [[ -r /proc/$pid/stat ]] || return 2
    if ! IFS= read -r stat < "/proc/$pid/stat"; then
        [[ -e /proc/$pid ]] && return 2 || return 1
    fi
    rest=${stat##*) }
    read -r -a fields <<< "$rest"
    (( ${#fields[@]} >= 20 )) && [[ ${fields[19]} =~ ^[0-9]+$ ]] || return 2
    [[ ${fields[0]} != Z && ${fields[0]} != X ]] || return 1
    owner=$(ps -p "$pid" -o uid= 2>/dev/null) || return 2
    owner=${owner//[[:space:]]/}
    [[ $owner == "$uid" && ${fields[19]} == "$expected_start" ]] || return 2
    if [[ -n $expected_exe ]]; then
        exe=$(readlink -- "/proc/$pid/exe" 2>/dev/null) || return 2
        [[ $exe == "$expected_exe" ]] || return 2
    fi
}

if (( $# == 0 )); then
    declare -a binaries=()
    for binary in ./agent-app-leak/agent-leak-app-x86 ./agent-app-leak/agent-leak-app-arm64; do
        if [[ -e $binary ]]; then
            resolved=$(readlink -f -- "$binary") || exit 1
            binaries+=("$resolved")
        fi
    done
    if (( ${#binaries[@]} == 0 )); then
        printf 'Run this from the repository root; app binaries are missing.\n' >&2
        exit 2
    fi
    if ! listing=$(ps -u "$uid" -o pid=); then
        printf 'Cannot list processes for UID %s.\n' "$uid" >&2
        exit 1
    fi
    while read -r pid; do
        [[ $pid =~ ^[1-9][0-9]*$ ]] || continue
        exe=$(readlink -- "/proc/$pid/exe" 2>/dev/null) || continue
        for binary in "${binaries[@]}"; do
            if [[ $exe == "$binary" ]]; then
                if IFS= read -r stat < "/proc/$pid/stat"; then
                    rest=${stat##*) }
                    read -r -a fields <<< "$rest"
                    if (( ${#fields[@]} >= 20 )) && [[ ${fields[19]} =~ ^[0-9]+$ ]]; then
                        targets+=("$pid")
                        starts+=("${fields[19]}")
                        executables+=("$binary")
                    fi
                fi
                break
            fi
        done
    done <<< "$listing"
    if (( ${#targets[@]} )); then
        printf 'Manual candidates (same UID and exact repository binary; other runs may be included):\n'
        for i in "${!targets[@]}"; do
            printf '  PID %s start %s executable %s\n' "${targets[i]}" "${starts[i]}" "${executables[i]}"
        done
        if [[ ! -t 0 ]]; then
            printf 'Manual cleanup requires interactive confirmation.\n' >&2
            exit 2
        fi
        if ! read -r -p 'Terminate these processes? [y/N] ' answer; then exit 2; fi
        [[ $answer == y || $answer == Y ]] || exit 2
    else
        printf 'No process from this repository binary was found for UID %s.\n' "$uid"
    fi
elif (( $# == 4 )); then
    for value in "$@"; do
        if [[ ! $value =~ ^[1-9][0-9]*$ ]]; then
            printf 'Usage: %s [LAUNCHER_PID LAUNCHER_START CHILD_PID CHILD_START]\n' "$0" >&2
            exit 2
        fi
    done
    [[ $1 != "$3" ]] || { printf 'Launcher and child PID must differ.\n' >&2; exit 2; }
    targets=("$1" "$3")
    starts=("$2" "$4")
    executables=('' '')
else
    printf 'Usage: %s [LAUNCHER_PID LAUNCHER_START CHILD_PID CHILD_START]\n' "$0" >&2
    exit 2
fi

# The selected list never expands to newly started apps while waiting.
for i in "${!targets[@]}"; do
    if identity "${targets[i]}" "${starts[i]}" "${executables[i]}"; then
        if ! kill -TERM "${targets[i]}" 2>/dev/null; then
            printf 'Cannot send TERM to PID %s.\n' "${targets[i]}" >&2
            result=1
        fi
    else
        state=$?
        if (( state == 2 )); then
            printf 'PID %s identity changed or could not be checked; no signal sent.\n' "${targets[i]}" >&2
            result=1
        fi
    fi
done

for ((second = 0; second < 5; second++)); do
    remaining=0
    for i in "${!targets[@]}"; do
        if identity "${targets[i]}" "${starts[i]}" "${executables[i]}"; then remaining=1; fi
    done
    (( remaining == 0 )) && break
    sleep 1 || result=1
done

for i in "${!targets[@]}"; do
    if identity "${targets[i]}" "${starts[i]}" "${executables[i]}"; then
        printf 'PID %s remained after TERM; sending KILL.\n' "${targets[i]}" >&2
        if ! kill -KILL "${targets[i]}" 2>/dev/null; then result=1; fi
    else
        state=$?
        if (( state == 2 )); then result=1; fi
    fi
done

sleep 1 || result=1
for i in "${!targets[@]}"; do
    if identity "${targets[i]}" "${starts[i]}" "${executables[i]}"; then
        printf 'PID %s remains after cleanup signals.\n' "${targets[i]}" >&2
        result=1
    else
        state=$?
        if (( state == 2 )); then result=1; fi
    fi
done

# Port occupancy is evidence, not permission to target another process.
for ((second = 0; second < 5; second++)); do
    if ! listeners=$(ss -H -ltn '( sport = :15034 )'); then
        printf 'Cannot check port 15034 with ss.\n' >&2
        exit 1
    fi
    if [[ -z $listeners ]]; then
        if (( result )); then exit 1; fi
        printf 'Port 15034 is free.\n'
        exit 0
    fi
    sleep 1 || result=1
done
printf 'Port 15034 is still listening; no additional process was selected.\n' >&2
exit 1
