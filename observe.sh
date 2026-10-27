#!/usr/bin/env bash

if [[ ${BASH_SOURCE[0]} != "$0" ]]; then
    printf 'Run this script with bash, not source.\n' >&2
    return 2
fi

# Accept the former mode spelling, but evidence is now selected by observations.
if (( $# == 4 || $# == 5 )); then
    case $1 in
        memory|cpu|deadlock)
            printf 'The former mode argument is ignored; collecting common evidence.\n' >&2
            shift ;;
    esac
fi
if (( $# != 3 && $# != 4 )); then
    printf 'Usage: bash ./observe.sh [memory|cpu|deadlock] MEMORY_LIMIT CPU_MAX_OCCUPY MULTI_THREAD_ENABLE [SECONDS]\n' >&2
    exit 2
fi
if [[ ! -f ./monitor.sh ]]; then
    printf 'Run this script from the repository root.\n' >&2
    exit 2
fi
exec bash ./monitor.sh "$@"
