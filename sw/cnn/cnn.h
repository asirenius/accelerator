#pragma once

#include "../common/matrix.h"
#include "../common/status.h"

// Public Interface
status_t cnn_convolve(matrix_t *input, matrix_t *kernel, int stride, matrix_t *output);
status_t cnn_relu_activate(matrix_t *input, matrix_t *output);
status_t cnn_max_pool(matrix_t *input, int pool_size, matrix_t *output);
status_t cnn_forward(matrix_t *input, matrix_t *kernel, int pool_size, int stride, matrix_t *output);
