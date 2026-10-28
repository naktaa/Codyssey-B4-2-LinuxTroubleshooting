
#!/usr/bin/env bash

set -u

if [[ $# -ne 1 || ! "$1" =~ ^[0-9]+$ ]]; then
    echo "사용법: $0 <PID>" >&2
    exit 1
fi

pid="$1"
proc_dir="/proc/$pid"

if [[ ! -d "$proc_dir/task" ]]; then
    echo "PID $pid 프로세스가 없거나 접근할 수 없습니다." >&2
    exit 1
fi

show_file() {
    local label="$1"
    local file="$2"
    local output

    printf '%s\n' "$label"

    if output=$(cat -- "$file" 2>&1); then
        printf '%s\n' "${output:-'(내용 없음)'}"
    else
        printf '(조회 실패) %s\n' "$output"
    fi
}

printf '=== Deadlock thread snapshot ===\n'
printf 'Time: %s\nPID: %s\n\n' \
    "$(date '+%Y-%m-%d %H:%M:%S.%3N %z')" "$pid"

echo "[Thread summary]"
ps -L -p "$pid" -o pid,tid,stat,pcpu,wchan:32,comm || true

found=0

for task_dir in "$proc_dir"/task/[0-9]*; do
    [[ -d "$task_dir" ]] || continue
    found=1

    tid="${task_dir##*/}"

    printf '\n========== TID %s ==========\n' "$tid"

    show_file '[Thread name]' "$task_dir/comm"
    show_file '[Wait channel]' "$task_dir/wchan"
    show_file '[Current syscall]' "$task_dir/syscall"
    show_file '[Kernel call stack]' "$task_dir/stack"
done

if [[ $found -eq 0 ]]; then
    echo "스레드 목록을 읽을 수 없습니다." >&2
    exit 1
fi

echo
echo "[참고] /proc/.../stack은 커널 콜스택입니다."

