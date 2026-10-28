#!/usr/bin/env python3
"""Watch actual Linux process CPU time from /proc/<PID>/stat.

Examples:
    python3 cpu_live.py 12345
    python3 cpu_live.py 12345 --interval 0.2 --duration 35
    python3 cpu_live.py 12345 --interval 0.2 --csv cpu-live.csv
"""

import argparse
import csv
import os
import sys
import time
from datetime import datetime
from pathlib import Path


def read_process(pid: int, ticks_per_second: int):
    """Return (start_ticks, cpu_seconds, state) for a Linux process."""
    with open(f"/proc/{pid}/stat", encoding="utf-8") as f:
        stat = f.read()

    # comm (field 2) is in parentheses and may itself contain spaces or ')'.
    end_comm = stat.rfind(")")
    if end_comm < 0:
        raise ValueError("Invalid /proc/PID/stat format")
    fields = stat[end_comm + 2:].split()  # Starts at field 3: state
    state = fields[0]
    utime = int(fields[11])  # Field 14
    stime = int(fields[12])  # Field 15
    start_ticks = int(fields[19])  # Field 22, detects PID reuse
    return start_ticks, (utime + stime) / ticks_per_second, state


def main():
    parser = argparse.ArgumentParser(
        description="Live Linux process CPU usage, calculated from /proc/PID/stat."
    )
    parser.add_argument("pid", type=int, help="Target process PID (not launcher PID)")
    parser.add_argument(
        "--interval", type=float, default=0.2,
        help="Sampling interval in seconds (default: 0.2)",
    )
    parser.add_argument(
        "--duration", type=float, default=0.0,
        help="Total monitoring time in seconds; 0 means until Ctrl+C (default: 0)",
    )
    parser.add_argument(
        "--csv", type=Path,
        help="Optional CSV output path. Existing files will not be overwritten.",
    )
    args = parser.parse_args()

    if args.pid <= 0:
        parser.error("pid must be a positive integer")
    if not 0.05 <= args.interval <= 60:
        parser.error("--interval must be between 0.05 and 60 seconds")
    if args.duration < 0:
        parser.error("--duration cannot be negative")

    try:
        ticks = os.sysconf("SC_CLK_TCK")
        identity, prev_cpu, state = read_process(args.pid, ticks)
    except FileNotFoundError:
        parser.exit(1, f"PID {args.pid} does not exist.\n")
    except (PermissionError, OSError, ValueError) as exc:
        parser.exit(1, f"Cannot read PID {args.pid}: {exc}\n")

    if state in ("Z", "X", "x"):
        parser.exit(1, f"PID {args.pid} is already exited ({state}).\n")

    writer = None
    output = None
    if args.csv is not None:
        try:
            output = args.csv.open("x", newline="", encoding="utf-8")
        except OSError as exc:
            parser.exit(1, f"Cannot create CSV: {exc}\n")
        writer = csv.writer(output)
        writer.writerow([
            "timestamp", "pid", "elapsed_s", "interval_s",
            "cpu_delta_s", "cpu_percent", "cpu_total_s", "state",
        ])

    begin = prev_wall = time.monotonic()
    first_cpu = prev_cpu
    max_cpu = 0.0
    samples = 0
    reason = "finished"

    print(f"PID={args.pid} | interval={args.interval:g}s | "
          f"duration={'Ctrl+C' if args.duration == 0 else f'{args.duration:g}s'} "
          f"| CLK_TCK={ticks}", flush=True)
    print("TIME       ELAPSED(s) CPU(%) CPU_DELTA(s) CPU_TOTAL(s) STATE", flush=True)

    try:
        while True:
            elapsed_before_sleep = time.monotonic() - begin
            if args.duration > 0:
                remaining = args.duration - elapsed_before_sleep
                if remaining <= 0:
                    reason = "duration reached"
                    break
                sleep_time = min(args.interval, remaining)
            else:
                sleep_time = args.interval

            time.sleep(sleep_time)
            now = time.monotonic()
            try:
                current_identity, current_cpu, state = read_process(args.pid, ticks)
            except FileNotFoundError:
                reason = "process disappeared"
                break
            except (PermissionError, OSError, ValueError) as exc:
                reason = f"read error: {exc}"
                break

            if current_identity != identity:
                reason = "PID reused (different process start time)"
                break

            delta_wall = now - prev_wall
            delta_cpu = max(0.0, current_cpu - prev_cpu)
            cpu_percent = 100.0 * delta_cpu / delta_wall
            elapsed = now - begin
            stamp = datetime.now().astimezone().isoformat(timespec="milliseconds")
            print(
                f"{datetime.now().strftime('%H:%M:%S')} "
                f"{elapsed:10.2f} {cpu_percent:6.1f} "
                f"{delta_cpu:12.3f} {current_cpu:12.3f} {state}",
                flush=True,
            )
            if writer is not None:
                writer.writerow([
                    stamp, args.pid, f"{elapsed:.3f}", f"{delta_wall:.3f}",
                    f"{delta_cpu:.3f}", f"{cpu_percent:.2f}",
                    f"{current_cpu:.3f}", state,
                ])
                output.flush()

            samples += 1
            max_cpu = max(max_cpu, cpu_percent)
            prev_cpu = current_cpu
            prev_wall = now
            if state in ("Z", "X", "x"):
                reason = f"process exited ({state})"
                break
    except KeyboardInterrupt:
        reason = "stopped by Ctrl+C"
    finally:
        if output is not None:
            output.close()

    wall = max(0.0, prev_wall - begin)
    accumulated_cpu = max(0.0, prev_cpu - first_cpu)
    average = 100.0 * accumulated_cpu / wall if wall > 0 else 0.0
    print("\n--- Summary ---")
    print(f"Reason: {reason}")
    print(f"Samples: {samples}")
    print(f"Observed wall time: {wall:.2f}s")
    print(f"CPU time used: {accumulated_cpu:.3f}s")
    print(f"Average CPU: {average:.2f}% (one CPU core = 100%)")
    print(f"Maximum sampled CPU: {max_cpu:.2f}%")
    if args.csv is not None:
        print(f"CSV: {args.csv}")

    return 1 if reason.startswith("read error:") or reason.startswith("PID reused") else 0


if __name__ == "__main__":
    sys.exit(main())
