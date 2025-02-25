#include "benchmark.h"

#include "xparameters.h"
#include <stdio.h>

#define COUNTS_PER_USECOND (XPAR_CPU_CORTEXA9_CORE_CLOCK_FREQ_HZ / 1000000)

void benchmark_start(benchmark_t *b, char *name) {
    b->name = name;
    XTime_GetTime(&b->start);
}

void benchmark_stop(benchmark_t *b) {
    XTime_GetTime(&b->end);
    b->iterations++;
    b->total_time_us += (b->end - b-> start) / (double)COUNTS_PER_USECOND;
    b->avg_time_us = b->total_time_us / b->iterations;
}

void benchmark_reset(benchmark_t *b) {
    b->iterations = 0;
    b->total_time_us = 0;
    b->avg_time_us = 0;
}

void benchmark_print(benchmark_t *b) {
    printf("\nBenchmark Results for %s:\n", b->name);
    printf("  Iterations:   %d\n", b->iterations);
    printf("  Total time:   %.2f us\n", b->total_time_us);
    printf("  Average time: %.2f us\n", b->avg_time_us);
}

void benchmark_compare(benchmark_t *hwb, benchmark_t *swb) {
    double speedup = swb->avg_time_us / hwb->avg_time_us;

    printf("\nPerformance Comparison:\n");
    printf("  %s: %.2f us\n", hwb->name, hwb->avg_time_us);
    printf("  %s: %.2f us\n", swb->name, swb->avg_time_us);
    printf("  Speedup: %2.fx\n", speedup);
}

double benchmark_get_throughput_mbps(benchmark_t *b, int data_size) {
    return ((data_size * 8.0) / b->avg_time_us) * 1.0;
}
