#pragma once

#include <stdint.h>
#include "xtime_l.h"

typedef struct {
    const char* name;
    XTime start;
    XTime end;
    int iterations;
    double total_time_us;
    double avg_time_us;
} benchmark_t;

// Core functions
void benchmark_start(benchmark_t *b, char *name);
void benchmark_stop(benchmark_t *b);
void benchmark_reset(benchmark_t *b);

// Results handling
void benchmark_print(benchmark_t *b);
void benchmark_compare(benchmark_t *hwb, benchmark_t *swb);

// Utility
double benchmark_get_time_us(benchmark_t *b);
double benchmark_get_avg_time_us(benchmark_t *b);
double benchmark_get_throughput_mbps(benchmark_t *b, int data_size);
