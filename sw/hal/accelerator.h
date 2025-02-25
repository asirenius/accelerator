#pragma once

#include "../common/matrix.h"
#include "../common/status.h"
#include "config.h"

// Public Interface
status_t accelerator_init(void);
status_t accelerator_cleanup(void);
status_t accelerator_set_kernel(matrix_t *kernel);
status_t accelerator_compute(matrix_t *input, matrix_t *output);
