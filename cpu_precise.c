#define _POSIX_C_SOURCE 200809L

#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <math.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>

typedef struct {
    char stamp[40];
    double elapsed;
    double interval;
    double percent;
    char state;
} Row;

typedef struct {
    FILE *file;
    Row pending;
    double sum;
    int has_pending;
} CsvGroup;

static volatile sig_atomic_t stopped = 0;

static void on_signal(int sig) {
    (void)sig;
    stopped = 1;
}

static double seconds(struct timespec t) {
    return (double)t.tv_sec + (double)t.tv_nsec / 1000000000.0;
}

static void advance(struct timespec *t, long milliseconds) {
    t->tv_nsec += (milliseconds % 1000) * 1000000L;
    t->tv_sec += milliseconds / 1000 + t->tv_nsec / 1000000000L;
    t->tv_nsec %= 1000000000L;
}

/* /proc supplies identity only; CPU time comes from the process clock. */
static int process_identity(pid_t pid, unsigned long long *starttime, char *state) {
    char path[64], line[8192];
    snprintf(path, sizeof(path), "/proc/%ld/stat", (long)pid);
    FILE *f = fopen(path, "r");
    if (!f) return -1;
    int ok = fgets(line, sizeof(line), f) != NULL;
    fclose(f);
    if (!ok) { errno = EIO; return -1; }

    char *close_paren = strrchr(line, ')');
    if (!close_paren || close_paren[1] != ' ') { errno = EINVAL; return -1; }
    char *save = NULL;
    int field = 3;
    char *part = strtok_r(close_paren + 2, " \n", &save);
    int found_state = 0, found_start = 0;
    while (part) {
        if (field == 3) {
            *state = part[0];
            found_state = 1;
        } else if (field == 22) {
            char *end = NULL;
            errno = 0;
            unsigned long long v = strtoull(part, &end, 10);
            if (errno || end == part || *end != '\0') { errno = EINVAL; return -1; }
            *starttime = v;
            found_start = 1;
            break;
        }
        field++;
        part = strtok_r(NULL, " \n", &save);
    }
    if (!found_state || !found_start) { errno = EINVAL; return -1; }
    return 0;
}

static void usage(const char *program) {
    fprintf(stderr,
            "Usage: %s PID [--expected-start TICK] [--interval-ms 100] [--duration SECONDS] [--csv FILE --csv-1s FILE] [--quiet]\n"
            "  --interval-ms : 10..2000 milliseconds (default: 100)\n"
            "  --duration    : observation duration in seconds, 0 = until exit/Ctrl+C\n"
            "  --quiet       : no success output\n", program);
}

static int parse_long(const char *s, long *value) {
    char *end = NULL;
    errno = 0;
    long n = strtol(s, &end, 10);
    if (errno || end == s || *end != '\0') return -1;
    *value = n;
    return 0;
}

static int parse_duration(const char *s, double *value) {
    char *end = NULL;
    errno = 0;
    double n = strtod(s, &end);
    if (errno || end == s || *end != '\0' || !isfinite(n) || n < 0) return -1;
    *value = n;
    return 0;
}

static int parse_start(const char *s, unsigned long long *value) {
    char *end = NULL;
    errno = 0;
    unsigned long long n = strtoull(s, &end, 10);
    if (errno || end == s || *end != '\0') return -1;
    *value = n;
    return 0;
}

static FILE *open_csv(const char *path) {
    int fd = open(path, O_WRONLY | O_CREAT | O_EXCL, 0644);
    if (fd == -1) return NULL;
    FILE *file = fdopen(fd, "w");
    if (!file) close(fd);
    return file;
}

static int write_pending(CsvGroup *group, pid_t pid, int last) {
    Row *row = &group->pending;
    if (fprintf(group->file, "\"%s\",%ld,%.2f,%.2f,%.2f,%c,",
                row->stamp, (long)pid, row->elapsed, row->interval,
                row->percent, row->state) < 0) return -1;
    if (last && fprintf(group->file, "%.2f", group->sum) < 0) return -1;
    if (fputc('\n', group->file) == EOF) return -1;
    if (last && fputc('\n', group->file) == EOF) return -1;
    return fflush(group->file) == 0 ? 0 : -1;
}

/* Delay each positive row until the next sample identifies the group end. */
static int record_sample(CsvGroup *group, pid_t pid, const Row *row) {
    if (row->percent > 0) {
        if (group->has_pending && write_pending(group, pid, 0)) return -1;
        group->pending = *row;
        group->sum += row->percent;
        group->has_pending = 1;
    } else if (group->has_pending) {
        if (write_pending(group, pid, 1)) return -1;
        group->sum = 0;
        group->has_pending = 0;
    }
    return 0;
}

static int make_row(Row *row, double start_wall, double last_wall,
                    double last_cpu, double now_wall, double now_cpu, char state) {
    row->elapsed = now_wall - start_wall;
    row->interval = now_wall - last_wall;
    double delta_cpu = now_cpu - last_cpu;
    if (row->interval <= 0 || delta_cpu < 0) return -1;
    struct timespec realtime;
    struct tm local;
    if (clock_gettime(CLOCK_REALTIME, &realtime) ||
        !localtime_r(&realtime.tv_sec, &local) ||
        !strftime(row->stamp, sizeof(row->stamp), "%Y-%m-%d %H:%M:%S", &local)) return -1;
    size_t length = strlen(row->stamp);
    snprintf(row->stamp + length, sizeof(row->stamp) - length,
             ",%03ld", realtime.tv_nsec / 1000000L);
    row->percent = 100.0 * delta_cpu / row->interval;
    row->state = state;
    return 0;
}

int main(int argc, char **argv) {
    if (argc < 2) { usage(argv[0]); return 2; }
    long requested_pid, interval_ms = 100;
    double duration = 0;
    const char *csv_path = NULL, *csv_1s_path = NULL;
    unsigned long long expected_start = 0;
    int has_expected_start = 0, quiet = 0;
    if (parse_long(argv[1], &requested_pid) || requested_pid <= 0 || requested_pid > INT_MAX) {
        usage(argv[0]); return 2;
    }
    pid_t pid = (pid_t)requested_pid;
    for (int i = 2; i < argc; i++) {
        if (!strcmp(argv[i], "--interval-ms") && i + 1 < argc) {
            if (parse_long(argv[++i], &interval_ms) || interval_ms < 10 || interval_ms > 2000) {
                usage(argv[0]); return 2;
            }
        } else if (!strcmp(argv[i], "--duration") && i + 1 < argc) {
            if (parse_duration(argv[++i], &duration)) { usage(argv[0]); return 2; }
        } else if (!strcmp(argv[i], "--expected-start") && i + 1 < argc) {
            if (parse_start(argv[++i], &expected_start)) { usage(argv[0]); return 2; }
            has_expected_start = 1;
        } else if (!strcmp(argv[i], "--csv") && i + 1 < argc) {
            csv_path = argv[++i];
        } else if (!strcmp(argv[i], "--csv-1s") && i + 1 < argc) {
            csv_1s_path = argv[++i];
        } else if (!strcmp(argv[i], "--quiet")) {
            quiet = 1;
        } else {
            usage(argv[0]); return 2;
        }
    }
    if ((csv_path && !csv_1s_path) || (!csv_path && csv_1s_path) ||
        (csv_path && !strcmp(csv_path, csv_1s_path))) {
        usage(argv[0]); return 2;
    }

    unsigned long long original_start = 0, current_start = 0;
    char state = '?';
    if (process_identity(pid, &original_start, &state) ||
        state == 'Z' || state == 'X' || state == 'x' ||
        (has_expected_start && original_start != expected_start)) {
        fprintf(stderr, "PID %ld is absent, exited, or does not match the expected start tick.\n", requested_pid);
        return 1;
    }
    clockid_t cpu_clock;
    int status = clock_getcpuclockid(pid, &cpu_clock);
    if (status) {
        fprintf(stderr, "clock_getcpuclockid: %s\n", strerror(status));
        return 1;
    }

    struct timespec wall, cpu;
    if (clock_gettime(CLOCK_MONOTONIC, &wall) || clock_gettime(cpu_clock, &cpu)) {
        perror("clock_gettime"); return 1;
    }
    if (process_identity(pid, &current_start, &state) || current_start != original_start ||
        state == 'Z' || state == 'X' || state == 'x') {
        fprintf(stderr, "PID %ld changed before CPU collection began.\n", requested_pid);
        return 1;
    }

    char auto_csv[512], auto_csv_1s[512];
    if (!csv_path) {
        struct timespec rt;
        struct tm local;
        char stamp[32];
        if (clock_gettime(CLOCK_REALTIME, &rt) || !localtime_r(&rt.tv_sec, &local) ||
            !strftime(stamp, sizeof(stamp), "%Y%m%d-%H%M%S", &local)) {
            fprintf(stderr, "Cannot create default CSV names.\n"); return 1;
        }
        struct stat st;
        const char *folder = stat("runs", &st) == 0 && S_ISDIR(st.st_mode) ? "runs" : ".";
        int n0 = snprintf(auto_csv, sizeof(auto_csv), "%s/cpu-precise-%ld-%s-%09ld-0.1s.csv",
                          folder, requested_pid, stamp, rt.tv_nsec);
        int n1 = snprintf(auto_csv_1s, sizeof(auto_csv_1s), "%s/cpu-precise-%ld-%s-%09ld-1s.csv",
                          folder, requested_pid, stamp, rt.tv_nsec);
        if (n0 < 0 || (size_t)n0 >= sizeof(auto_csv) ||
            n1 < 0 || (size_t)n1 >= sizeof(auto_csv_1s)) {
            fprintf(stderr, "Default CSV path is too long.\n"); return 1;
        }
        csv_path = auto_csv;
        csv_1s_path = auto_csv_1s;
    }
    CsvGroup short_group = {0}, one_group = {0};
    short_group.file = open_csv(csv_path);
    if (!short_group.file) { perror("Cannot create 0.1s CSV"); return 1; }
    one_group.file = open_csv(csv_1s_path);
    if (!one_group.file) {
        perror("Cannot create 1s CSV");
        fclose(short_group.file);
        return 1;
    }
    const char *header = "timestamp_local,pid,elapsed_s,interval_s,cpu_percent_interval,state,group_percent_sum\n";
    if (fputs(header, short_group.file) == EOF || fflush(short_group.file) ||
        fputs(header, one_group.file) == EOF || fflush(one_group.file)) {
        fprintf(stderr, "Cannot write CPU CSV headers.\n");
        fclose(short_group.file);
        fclose(one_group.file);
        return 1;
    }

    struct sigaction action = {0};
    action.sa_handler = on_signal;
    sigemptyset(&action.sa_mask);
    if (sigaction(SIGINT, &action, NULL) || sigaction(SIGTERM, &action, NULL)) {
        perror("sigaction");
        fclose(short_group.file);
        fclose(one_group.file);
        return 1;
    }

    double start_wall = seconds(wall), previous_wall = start_wall;
    double previous_cpu = seconds(cpu), one_wall = start_wall, one_cpu = previous_cpu;
    struct timespec wake = wall;
    int failed = 0;
    const char *reason = "signal received";
    if (!quiet) printf("PID=%ld | interval=%ldms | CSVs: %s, %s\n",
                       requested_pid, interval_ms, csv_path, csv_1s_path);

    while (!stopped) {
        advance(&wake, interval_ms);
        int ret;
        do { ret = clock_nanosleep(CLOCK_MONOTONIC, TIMER_ABSTIME, &wake, NULL); }
        while (ret == EINTR && !stopped);
        if (stopped) break;
        if (ret) {
            fprintf(stderr, "clock_nanosleep: %s\n", strerror(ret));
            failed = 1; reason = "sleep error"; break;
        }
        if (process_identity(pid, &current_start, &state)) {
            if (errno != ENOENT && errno != ESRCH) {
                perror("Cannot verify process identity");
                failed = 1;
            }
            reason = "process disappeared"; break;
        }
        if (current_start != original_start) {
            fprintf(stderr, "PID %ld was reused during CPU collection.\n", requested_pid);
            failed = 1; reason = "PID reused"; break;
        }
        if (state == 'Z' || state == 'X' || state == 'x') {
            reason = "process exited"; break;
        }
        struct timespec now_wall_ts, now_cpu_ts;
        if (clock_gettime(CLOCK_MONOTONIC, &now_wall_ts)) {
            perror("Cannot read monotonic clock");
            failed = 1; reason = "clock unavailable"; break;
        }
        if (clock_gettime(cpu_clock, &now_cpu_ts)) {
            if (errno == ESRCH) {
                reason = "process disappeared"; break;
            }
            perror("Cannot read process CPU clock");
            failed = 1; reason = "clock unavailable"; break;
        }
        if (process_identity(pid, &current_start, &state)) {
            if (errno != ENOENT && errno != ESRCH) {
                perror("Cannot verify process identity after CPU sample");
                failed = 1;
            }
            reason = "process ended during sample"; break;
        }
        if (current_start != original_start) {
            fprintf(stderr, "PID %ld was reused during CPU collection.\n", requested_pid);
            failed = 1; reason = "PID reused"; break;
        }
        if (state == 'Z' || state == 'X' || state == 'x') {
            reason = "process ended during sample"; break;
        }
        double now_wall = seconds(now_wall_ts), now_cpu = seconds(now_cpu_ts);
        Row row;
        if (make_row(&row, start_wall, previous_wall, previous_cpu,
                     now_wall, now_cpu, state)) {
            fprintf(stderr, "Invalid 0.1s CPU sample.\n");
            failed = 1; reason = "invalid sample"; break;
        }
        if (record_sample(&short_group, pid, &row)) {
            perror("Cannot write 0.1s CSV");
            failed = 1; reason = "CSV write error"; break;
        }
        if (now_wall - one_wall >= 1.0) {
            if (make_row(&row, start_wall, one_wall, one_cpu,
                         now_wall, now_cpu, state)) {
                fprintf(stderr, "Invalid 1s CPU sample.\n");
                failed = 1; reason = "invalid sample"; break;
            }
            if (record_sample(&one_group, pid, &row)) {
                perror("Cannot write 1s CSV");
                failed = 1; reason = "CSV write error"; break;
            }
            one_wall = now_wall;
            one_cpu = now_cpu;
        }
        previous_wall = now_wall;
        previous_cpu = now_cpu;
        if (duration > 0 && now_wall - start_wall >= duration) {
            reason = "duration reached"; break;
        }
    }

    /* Only completed 1s samples enter that CSV; flush its pending group as-is. */
    Row zero = {.percent = 0};
    if (record_sample(&short_group, pid, &zero)) {
        fprintf(stderr, "Cannot flush final 0.1s CPU group.\n");
        failed = 1;
    }
    if (record_sample(&one_group, pid, &zero)) {
        fprintf(stderr, "Cannot flush final 1s CPU group.\n");
        failed = 1;
    }
    if (!quiet) printf("Summary: %s | CSVs: %s, %s\n", reason, csv_path, csv_1s_path);
    if (fclose(short_group.file)) { perror("Cannot close 0.1s CSV"); failed = 1; }
    if (fclose(one_group.file)) { perror("Cannot close 1s CSV"); failed = 1; }
    return failed ? 1 : 0;
}
