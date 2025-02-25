#include "fixed.h"

#include "xtime_l.h"
#include "xil_printf.h"

static u32 rand_seed = 1;

// Forward declarations
static u32 random_u32(void);
static float random_float(void);

status_t float_to_fixed(float value, fixed_point_t *result) {
	if (!result) {
		LOG_ERROR("NULL pointer");
		return STATUS_ERROR_INVALID_PARAM;
	}

	// Check for overflow
	float max_val = (float)FIXED_POINT_MAX / FIXED_POINT_SCALE;
	float min_val = (float)FIXED_POINT_MIN / FIXED_POINT_SCALE;
	if (value > max_val || value < min_val) {
		LOG_ERROR("Value out of range");
		return STATUS_ERROR_OVERFLOW;
	}

	*result = (fixed_point_t)(value * FIXED_POINT_SCALE);
    return STATUS_SUCCESS;
}


status_t fixed_to_float(fixed_point_t value, float* result) {
    if (!result) {
    	LOG_ERROR("NULL pointer");
        return STATUS_ERROR_INVALID_PARAM;
    }

    *result = ((float)value) / FIXED_POINT_SCALE;
    return STATUS_SUCCESS;
}


status_t int_to_fixed(int value, fixed_point_t* result) {
    if (!result) {
    	LOG_ERROR("NULL pointer");
        return STATUS_ERROR_INVALID_PARAM;
    }

    // Check for overflow
    if (value > (FIXED_POINT_MAX >> FIXED_POINT_BITS) ||
        value < (FIXED_POINT_MIN >> FIXED_POINT_BITS)) {
    	LOG_ERROR("Value %d out of range", value);
        return STATUS_ERROR_OVERFLOW;
    }

    *result = (fixed_point_t)(value << FIXED_POINT_BITS);
    return STATUS_SUCCESS;
}

status_t fixed_to_int(fixed_point_t value, int* result) {
    if (!result) {
    	LOG_ERROR("NULL pointer");
        return STATUS_ERROR_INVALID_PARAM;
    }

    *result = (int)(value >> FIXED_POINT_BITS);
    return STATUS_SUCCESS;
}

status_t fixed_multiply(fixed_point_t a, fixed_point_t b, fixed_point_t* result) {
    if (!result) {
    	LOG_ERROR("NULL pointer");
        return STATUS_ERROR_INVALID_PARAM;
    }

    // Use 64-bit intermediate
    int64_t temp = ((int64_t)a * (int64_t)b) >> FIXED_POINT_BITS;

    // Check for overflow
    if (temp > FIXED_POINT_MAX || temp < FIXED_POINT_MIN) {
    	LOG_ERROR("Result overflow");
        return STATUS_ERROR_OVERFLOW;
    }

    *result = (fixed_point_t)temp;
    return STATUS_SUCCESS;
}

status_t fixed_add(fixed_point_t a, fixed_point_t b, fixed_point_t* result) {
    if (!result) {
    	LOG_ERROR("NULL pointer");
        return STATUS_ERROR_INVALID_PARAM;
    }

    // Use 64-bit intermediate
    int64_t temp = (int64_t)a + (int64_t)b;

    // Check for overflow
    if (temp > FIXED_POINT_MAX || temp < FIXED_POINT_MIN) {
    	LOG_ERROR("Result overflow");
        return STATUS_ERROR_OVERFLOW;
    }

    *result = (fixed_point_t)temp;
    return STATUS_SUCCESS;
}

void fixed_print(fixed_point_t value) {
	int32_t integer_part = value / (1 << 12);
	int32_t fractional_part = ((value % (1 << 12)) * 1000) >> 12;

	if (value >= 0) {
		xil_printf("%d.%03d", integer_part, fractional_part);
	} else {
		xil_printf("-%d.%03d", -integer_part, -fractional_part);
	}
}

status_t fixed_random(float min_val, float max_val, fixed_point_t *result) {
    if (!result) {
        LOG_ERROR("NULL pointer");
        return STATUS_ERROR_INVALID_PARAM;
    }

    if (min_val > max_val) {
        LOG_ERROR("min_val (%f) > max_val (%f)", min_val, max_val);
        return STATUS_ERROR_INVALID_PARAM;
    }

    // Initialize seed if not done
    if (rand_seed == 1) {
        XTime time;
        XTime_GetTime(&time);
        rand_seed = (u32)(time & 0xFFFFFFFF);
    }

    float rand_val = min_val + (max_val - min_val) * random_float();
    return float_to_fixed(rand_val, result);
}

static u32 random_u32(void) {
    rand_seed ^= rand_seed << 13;
    rand_seed ^= rand_seed >> 17;
    rand_seed ^= rand_seed << 5;
    return rand_seed;
}

static float random_float(void) {
    return (float)random_u32() / (float)0xFFFFFFFF;
}
