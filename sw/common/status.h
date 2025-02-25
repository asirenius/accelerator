#pragma once

#include "xstatus.h"
#include <string.h>

// Status Code
typedef enum {
	STATUS_SUCCESS = 0,
	STATUS_ERROR_INVALID_PARAM = -1,
	STATUS_ERROR_OVERFLOW = -2,
	STATUS_ERROR_MEMORY = -3,
	STATUS_ERROR_HARDWARE = -4,
	STATUS_ERROR_TIMEOUT = -5,
} status_t;

// Extract the filename from a path at compile time
#define FILENAME (strrchr(__FILE__, '/') ? strrchr(__FILE__, '/') + 1 : \
                 (strrchr(__FILE__, '\\') ? strrchr(__FILE__, '\\') + 1 : __FILE__))

// Simplified error logging macro - just file and line
#define LOG_ERROR(format, ...) \
    xil_printf("[%s:%d] ERROR: " format "\r\n", FILENAME, __LINE__, ##__VA_ARGS__)
