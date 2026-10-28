#!/usr/bin/env python3
"""Measure a Linux process's CPU time over 0.1- and 1-second intervals.

Examples:
    python3 cpu_live.py 12345
    python3 cpu_live.py 12345 --duration 35
    python3 cpu_live.py 12345 --csv runs/xxx/cpu-live-0.1s.csv --csv-1s runs/xxx/cpu-live-1s.csv
    python3 cpu_live.py 12345 --quiet

CSVs are saved automatically under runs/ (if it exists) unless paths are set.
Existing evidence files are never overwritten.
"""

import argparse
import csv
import os
import sys
import time
from datetime import datetime
from pathlib import Path


def read_process(pid, ticks_per_second):
    with open(f"/proc/{pid}/stat", encoding="utf-8") as f:
        stat = f.read()
    # Field 2, comm, is enclosed in parentheses and can contain spaces.
    close = stat.rfind(")")
    if close < 0:
        raise ValueError("Invalid /proc/PID/stat format")
    fields = stat[close + 2:].split()  # index 0 corresponds to field 3.
    state = fields[0]
    utime = int(fields[11])  # field 14
    stime = int(fields[12])  # field 15
    start_ticks = int(fields[19])  # field 22, for detecting PID reuse
    return start_ticks, (utime + stime) / ticks_per_second, state


def run():
    parser = argparse.ArgumentParser(
        description="Live Linux process CPU usage from /proc/PID/stat, with CSV logging."
    )
    parser.add_argument("pid", type=int, help="Application worker PID (not launcher PID)")
    parser.add_argument(
        "--duration", type=float, default=0.0,
        help="Stop after this many seconds; 0 means until Ctrl+C or process exit",
    )
    parser.add_argument(
        "--csv", type=Path,
        help="0.1-second CSV path. Default: runs/ if present, otherwise current directory",
    )
    parser.add_argument(
        "--csv-1s", type=Path,
        help="1-second CSV path. Default: runs/ if present, otherwise current directory",
    )
    parser.add_argument(
        "--quiet", action="store_true", help="Hide individual samples (still save CSV)"
    )
    args = parser.parse_args()

    if args.pid <= 0:
        parser.error("pid must be a positive integer")
    if args.duration < 0:
        parser.error("--duration cannot be negative")

    try:
        ticks = os.sysconf("SC_CLK_TCK")
        identity, first_cpu, state = read_process(args.pid, ticks)
    except FileNotFoundError:
        parser.exit(1, f"PID {args.pid} does not exist.\n")
    except (PermissionError, OSError, ValueError, IndexError) as exc:
        parser.exit(1, f"Cannot read PID {args.pid}: {exc}\n")
    if state in ("Z", "X", "x"):
        parser.exit(1, f"PID {args.pid} is already exited ({state}).\n")

    if args.csv is None or args.csv_1s is None:
        suffix = datetime.now().strftime("%Y%m%d-%H%M%S-%f")
        base = Path("runs") if Path("runs").is_dir() else Path(".")
    csv_path = args.csv or base / f"cpu-live-{args.pid}-{suffix}-0.1s.csv"
    csv_1s_path = args.csv_1s or base / f"cpu-live-{args.pid}-{suffix}-1s.csv"
    if csv_path == csv_1s_path:
        parser.error("0.1-second and 1-second CSV paths must differ")
    try:
        # Exclusive creation; do not overwrite existing experiment logs.
        output = csv_path.open("x", newline="", encoding="utf-8")
    except OSError as exc:
        parser.exit(1, f"Cannot create CSV {csv_path}: {exc}\n")

    try:
        output_1s = csv_1s_path.open("x", newline="", encoding="utf-8")
    except OSError as exc:
        output.close()
        parser.exit(1, f"Cannot create CSV {csv_1s_path}: {exc}\n")

    with output, output_1s:
        writer = csv.writer(output)
        writer_1s = csv.writer(output_1s)
        header = ["timestamp_local", "pid", "elapsed_s", "interval_s", "cpu_percent_interval", "state"]
        writer.writerow(header)
        writer_1s.writerow(header)
        output.flush()
        output_1s.flush()

        begin = prev_wall = time.monotonic()
        prev_cpu = first_cpu
        one_wall = begin
        one_cpu = first_cpu
        samples_01 = samples_1s = 0
        max_cpu_01 = max_cpu_1s = 0.0
        reason = "finished"

        print(
            f"PID={args.pid} | intervals=0.1s,1s | "
            f"duration={'Ctrl+C' if args.duration == 0 else f'{args.duration:g}s'} "
            f"| CLK_TCK={ticks}"
        )
        print(f"CSVs: {csv_path}, {csv_1s_path}", flush=True)
        if not args.quiet:
            print("TIME                    WINDOW ELAPSED(s) CPU(%) STATE", flush=True)

        try:
            while True:
                elapsed_before_sleep = time.monotonic() - begin
                if args.duration > 0:
                    remaining = args.duration - elapsed_before_sleep
                    if remaining <= 0:
                        reason = "duration reached"
                        break
                    sleep_seconds = min(0.1, remaining)
                else:
                    sleep_seconds = 0.1

                time.sleep(sleep_seconds)
                now = time.monotonic()
                try:
                    current_identity, current_cpu, state = read_process(args.pid, ticks)
                except FileNotFoundError:
                    reason = "process disappeared"
                    break
                except (PermissionError, OSError, ValueError, IndexError) as exc:
                    reason = f"read error: {exc}"
                    break
                if current_identity != identity:
                    reason = "PID reused (different process start time)"
                    break

                elapsed = now - begin
                delta_wall = now - prev_wall
                cpu_percent = max(0.0, 100.0 * (current_cpu - prev_cpu) / delta_wall)
                stamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S,%f")[:-3]
                if cpu_percent > 0:
                    writer.writerow([stamp, args.pid, f"{elapsed:.3f}", f"{delta_wall:.3f}",
                                     f"{cpu_percent:.2f}", state])
                    output.flush()  # Preserve observations if the app exits abruptly.
                    samples_01 += 1
                    max_cpu_01 = max(max_cpu_01, cpu_percent)
                    if not args.quiet:
                        print(f"{stamp}  0.1s {elapsed:10.2f} {cpu_percent:6.1f} {state}", flush=True)

                # Keep a separate baseline: this is a measured ~1s CPU delta, not a rolling average.
                one_interval = now - one_wall
                if one_interval >= 1.0:
                    one_percent = max(0.0, 100.0 * (current_cpu - one_cpu) / one_interval)
                    if one_percent > 0:
                        writer_1s.writerow([stamp, args.pid, f"{elapsed:.3f}", f"{one_interval:.3f}",
                                            f"{one_percent:.2f}", state])
                        output_1s.flush()
                        samples_1s += 1
                        max_cpu_1s = max(max_cpu_1s, one_percent)
                        if not args.quiet:
                            print(f"{stamp}  1.0s {elapsed:10.2f} {one_percent:6.1f} {state}", flush=True)
                    one_wall = now
                    one_cpu = current_cpu

                prev_cpu = current_cpu
                prev_wall = now
                if state in ("Z", "X", "x"):
                    reason = f"process exited ({state})"
                    break
        except KeyboardInterrupt:
            reason = "stopped by Ctrl+C"

    wall = max(0.0, prev_wall - begin)
    used_cpu = max(0.0, prev_cpu - first_cpu)
    avg_cpu = used_cpu / wall * 100 if wall > 0 else 0.0
    print("\n--- Summary ---")
    print(f"Reason: {reason}")
    print(f"Recorded nonzero samples: 0.1s={samples_01}, 1s={samples_1s}")
    print(f"Observed wall time: {wall:.2f}s")
    print(f"CPU time used: {used_cpu:.3f}s")
    print(f"Average CPU: {avg_cpu:.2f}% (one CPU core = 100%)")
    print(f"Maximum sampled CPU: 0.1s={max_cpu_01:.2f}%, 1s={max_cpu_1s:.2f}%")
    print(f"CSVs: {csv_path}, {csv_1s_path}")
    return 1 if reason.startswith("read error:") or reason.startswith("PID reused") else 0


if __name__ == "__main__":
    sys.exit(run())
