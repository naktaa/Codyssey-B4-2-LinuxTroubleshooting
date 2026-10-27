#!/usr/bin/env bash

if [[ ${BASH_SOURCE[0]} != "$0" ]]; then
    printf 'Run this script with bash, not source.\n' >&2
    return 2
fi
if (( $# != 3 && $# != 4 )); then
    printf 'Usage: bash ./run-deadlock-observation.sh MEMORY_LIMIT CPU_MAX_OCCUPY MULTI_THREAD_ENABLE [SECONDS]\n' >&2
    exit 2
fi
if [[ ! -f ./monitor.sh ]]; then
    printf 'Run this script from the repository root.\n' >&2
    exit 2
fi
exec bash ./monitor.sh "$@"
