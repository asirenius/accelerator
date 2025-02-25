#pragma once

#include "status.h"

// Format configuration
#define FIXED_POINT_BITS 12
#define FIXED_POINT_SCALE (1 << FIXED_POINT_BITS)
#define FIXED_POINT_MAX ((1LL << 31) - 1)
#define FIXED_POINT_MIN (-(1LL << 31))

// Fixed-point type (Q20.12 format)
typedef int32_t fixed_point_t;

// Conversion functions
status_t float_to_fixed(float value, fixed_point_t *result);
status_t fixed_to_float(fixed_point_t value, float *result);
status_t int_to_fixed(int value, fixed_point_t *result);
status_t fixed_to_int(fixed_point_t value, int *result);

// Arithmetic functions
status_t fixed_multiply(fixed_point_t a, fixed_point_t b, fixed_point_t *result);
status_t fixed_add(fixed_point_t a, fixed_point_t b, fixed_point_t *result);

// Utility
void fixed_print(fixed_point_t value);

// Random generation
status_t fixed_random(float min_val, float max_val, fixed_point_t *result);
