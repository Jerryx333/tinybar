// Sample one process from outside the app; build/run via scripts/benchmark.sh.
// Reads proc_pid_rusage snapshots with PID start-time checks; never captures other apps.
// Requires macOS Command Line Tools. CPU units verified with --self-check before use.
#include <libproc.h>
#include <sys/resource.h>
#include <time.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <errno.h>
#include <string.h>
#include <math.h>
#include <mach/mach_time.h>

static double monotonic(void) { struct timespec t; if (clock_gettime(CLOCK_MONOTONIC, &t)) { perror("clock_gettime"); exit(1); } return t.tv_sec + t.tv_nsec / 1e9; }
static struct rusage_info_v4 sample(pid_t pid) {
    struct rusage_info_v4 r = {0};
    if (proc_pid_rusage(pid, RUSAGE_INFO_V4, (rusage_info_t *)&r)) { perror("proc_pid_rusage"); exit(1); }
    return r;
}
static double cpu(struct rusage_info_v4 r) {
    mach_timebase_info_data_t scale;
    if (mach_timebase_info(&scale) != KERN_SUCCESS || scale.denom == 0) { fputs("Invalid timebase\n", stderr); exit(1); }
    return ((double)r.ri_user_time + r.ri_system_time) * scale.numer / scale.denom / 1e9;
}
static double self_cpu(void) { struct rusage r; if (getrusage(RUSAGE_SELF, &r)) { perror("getrusage"); exit(1); } return r.ru_utime.tv_sec + r.ru_utime.tv_usec/1e6 + r.ru_stime.tv_sec + r.ru_stime.tv_usec/1e6; }
int main(int argc, char **argv) {
    if (argc == 2 && !strcmp(argv[1], "--self-check")) {
        double a = self_cpu(), b = cpu(sample(getpid())), end = monotonic() + 0.3;
        while (monotonic() < end) { for (volatile int i = 0; i < 10000; ++i) {} }
        double expected = self_cpu() - a, measured = cpu(sample(getpid())) - b;
        fprintf(stderr, "CPU unit check: getrusage=%.6fs proc_pid_rusage=%.6fs\n", expected, measured);
        return expected > 0.1 && fabs(expected - measured) / expected < 0.03 ? 0 : 1;
    }
    char *end1 = NULL, *end2 = NULL;
    if (argc != 3) { fputs("Usage: measure PID SECONDS | --self-check\n", stderr); return 64; }
    errno = 0;
    long pid = strtol(argv[1], &end1, 10);
    double duration = strtod(argv[2], &end2);
    if (errno || !end1 || *end1 || !end2 || *end2 || pid <= 0 || pid > INT32_MAX || !isfinite(duration) || duration < 1 || duration > 3600) { fputs("Invalid PID or duration (1–3600s)\n", stderr); return 64; }
    struct rusage_info_v4 first = sample((pid_t)pid), current = first;
    uint64_t peak_rss = first.ri_resident_size, peak_footprint = first.ri_phys_footprint;
    double start = monotonic(), elapsed = 0;
    while (elapsed < duration) {
        double pause = fmin(1, duration - elapsed);
        struct timespec remaining = {(time_t)pause, (long)((pause - floor(pause))*1e9)};
        while (nanosleep(&remaining, &remaining)) { if (errno != EINTR) { perror("nanosleep"); return 1; } }
        current = sample((pid_t)pid);
        if (current.ri_proc_start_abstime != first.ri_proc_start_abstime) { fputs("Process identity changed\n", stderr); return 1; }
        if (current.ri_resident_size > peak_rss) peak_rss = current.ri_resident_size;
        if (current.ri_phys_footprint > peak_footprint) peak_footprint = current.ri_phys_footprint;
        elapsed = monotonic() - start;
    }
    double delta = cpu(current) - cpu(first);
    printf("{\n  \"elapsed_seconds\": %.6f,\n  \"cpu_seconds\": %.9f,\n  \"cpu_percent_one_core\": %.6f,\n  \"rss_bytes\": %llu,\n  \"peak_sampled_rss_bytes\": %llu,\n  \"physical_footprint_bytes\": %llu,\n  \"peak_sampled_footprint_bytes\": %llu,\n  \"lifetime_peak_footprint_bytes\": %llu,\n  \"package_idle_wakeups\": %llu\n}\n", elapsed, delta, delta/elapsed*100,
        (unsigned long long)current.ri_resident_size, (unsigned long long)peak_rss,
        (unsigned long long)current.ri_phys_footprint, (unsigned long long)peak_footprint,
        (unsigned long long)current.ri_lifetime_max_phys_footprint,
        (unsigned long long)(current.ri_pkg_idle_wkups-first.ri_pkg_idle_wkups));
    return 0;
}
