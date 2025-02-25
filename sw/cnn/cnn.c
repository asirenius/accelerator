#include "cnn.h"

#include "xil_printf.h"

#include "../common/fixed.h"
#include "../hal/config.h"

static status_t relu_fp(fixed_point_t x, fixed_point_t* result) {
    if (!result) {
    	LOG_ERROR("NULL result pointer");
        return STATUS_ERROR_INVALID_PARAM;
    }

    if (x > 0) {
        *result = x;
    } else {
        fixed_point_t zero;
        status_t status = int_to_fixed(0, &zero);
        if (status != STATUS_SUCCESS) {
        	LOG_ERROR("Could not convert zero to fixed point");
            return status;
        }
        *result = zero;
    }
    return STATUS_SUCCESS;
}

status_t cnn_convolve(matrix_t *input, matrix_t *kernel, int stride, matrix_t *output) {
    if (!input || !kernel || !output) {
    	LOG_ERROR("NULL pointer(s)");
        return STATUS_ERROR_INVALID_PARAM;
    }
    if (stride <= 0) {
        LOG_ERROR("Invalid stride %d", stride);
        return STATUS_ERROR_INVALID_PARAM;
    }

    status_t status;
    fixed_point_t in_val, kern_val, prod, sum, tmp;
    int rows = (input->rows - kernel->rows) / stride + 1;
    int cols = (input->cols - kernel->cols) / stride + 1;

    for (int i = 0; i < rows; i++) {
        for (int j = 0; j < cols; j++) {

            status = int_to_fixed(0, &sum);
            if (status != STATUS_SUCCESS) {
            	LOG_ERROR("Could not convert zero to fixed point");
                return status;
            }

            for (int ki = 0; ki < kernel->rows; ki++) {
                for (int kj = 0; kj < kernel->cols; kj++) {
                    status = matrix_get(input, i * stride + ki, j * stride + kj, &in_val);
                    if (status != STATUS_SUCCESS) {
                        LOG_ERROR("Could not read input at position %d,%d", i * stride + ki, j * stride + kj);
                        return status;
                    }

                    status = matrix_get(kernel, ki, kj, &kern_val);
                    if (status != STATUS_SUCCESS) {
                        LOG_ERROR("Could not read kernel at position %d,%d", ki, kj);
                        return status;
                    }

                    status = fixed_multiply(in_val, kern_val, &prod);
                    if (status != STATUS_SUCCESS) {
                        LOG_ERROR("Multiplication error at position %d,%d", ki, kj);
                        return status;
                    }

                    tmp = sum;
                    status = fixed_add(prod, tmp, &sum);
                    if (status != STATUS_SUCCESS) {
                        LOG_ERROR("Addition error at position %d,%d", ki, kj);
                        return status;
                    }
                }
            }

            status = matrix_set(output, i, j, sum);
            if (status != STATUS_SUCCESS) {
                LOG_ERROR("Could not write result to position %d,%d", i, j);
                return status;
            }
        }
    }

    return STATUS_SUCCESS;
}

status_t cnn_relu_activate(matrix_t *input, matrix_t *output) {
    if (!input || !output) {
    	LOG_ERROR("NULL matrix pointer");
        return STATUS_ERROR_INVALID_PARAM;
    }

    status_t status;
    fixed_point_t val, result;

    for (int i = 0; i < input->rows; i++) {
        for (int j = 0; j < input->cols; j++) {
            status = matrix_get(input, i, j, &val);
            if (status != STATUS_SUCCESS) {
            	LOG_ERROR("Could not read input at position %d,%d", i, j);
                return status;
            }

            status = relu_fp(val, &result);
            if (status != STATUS_SUCCESS) {
            	LOG_ERROR("Operation failed at position %d,%d", i, j);
                return status;
            }

            status = matrix_set(output, i, j, result);
            if (status != STATUS_SUCCESS) {
            	LOG_ERROR("Could not write result to position %d,%d", i, j);
                return status;
            }
        }
    }
    return STATUS_SUCCESS;
}

status_t cnn_max_pool(matrix_t *input, int pool_size, matrix_t *output) {
    if (!input || !output) {
    	LOG_ERROR("NULL pointer(s)");
        return STATUS_ERROR_INVALID_PARAM;
    }

    if (pool_size <= 0) {
    	LOG_ERROR("Invalid pool size %d", pool_size);
        return STATUS_ERROR_INVALID_PARAM;
    }

    int rows = input->rows / pool_size;
    int cols = input->cols / pool_size;
    status_t status;

    for (int i = 0; i < rows; i++) {
        for (int j = 0; j < cols; j++) {
            fixed_point_t max = FIXED_POINT_MIN;
            for (int pi = 0; pi < pool_size; pi++) {
                for (int pj = 0; pj < pool_size; pj++) {
                	fixed_point_t val;
                    status = matrix_get(input, i * pool_size + pi, j * pool_size + pj, &val);
                    if (status != STATUS_SUCCESS) {
                    	LOG_ERROR("Could not read value at position %d,%d", i * pool_size + pi, j * pool_size + pj);
                        return status;
                    }
                    if (val > max) max = val;
                }
            }
            status = matrix_set(output, i, j, max);
            if (status != STATUS_SUCCESS) {
            	LOG_ERROR("Could not write result to position %d,%d", i, j);
                return status;
            }
        }
    }
    return STATUS_SUCCESS;
}

status_t cnn_forward(matrix_t *input, matrix_t *kernel, int pool_size, int stride, matrix_t *output) {
    if (!input || !kernel || !output) {
    	LOG_ERROR("NULL pointer(s)");
        return STATUS_ERROR_INVALID_PARAM;
    }

    if (pool_size <= 0 || stride <= 0) {
    	LOG_ERROR("Invalid parameters pool size %d stride %d", pool_size, stride);
        return STATUS_ERROR_INVALID_PARAM;
    }

    status_t status;

    // Calculate intermediate dimensions
    int conv_rows = (input->rows - kernel->rows) / stride + 1;
    int conv_cols = (input->cols - kernel->cols) / stride + 1;

    // Create intermediate matrices
    matrix_t *conv_out = matrix_create(conv_rows, conv_cols);
    if (!conv_out) {
    	LOG_ERROR("Could not create output matrix for convolution");
        return STATUS_ERROR_MEMORY;
    }

    matrix_t *relu_out = matrix_create(conv_rows, conv_cols);
    if (!relu_out) {
    	LOG_ERROR("Could not create output matrix for ReLU");
        matrix_destroy(conv_out);
        return STATUS_ERROR_MEMORY;
    }

    // Convolution
    status = cnn_convolve(input, kernel, STRIDE, conv_out);
    if (status != STATUS_SUCCESS) {
    	LOG_ERROR("Convolution operation failed");
        matrix_destroy(conv_out);
        matrix_destroy(relu_out);
        return status;
    }

    // ReLU
    status = cnn_relu_activate(conv_out, relu_out);
    if (status != STATUS_SUCCESS) {
    	LOG_ERROR("ReLU operation failed");
        matrix_destroy(conv_out);
        matrix_destroy(relu_out);
        return status;
    }

    // Max Pooling
    status = cnn_max_pool(relu_out, POOL_SIZE, output);
    if (status != STATUS_SUCCESS) {
    	LOG_ERROR("Max pooling operation failed");
        matrix_destroy(conv_out);
        matrix_destroy(relu_out);
        return status;
    }

    // Cleanup
    matrix_destroy(conv_out);
    matrix_destroy(relu_out);

    return STATUS_SUCCESS;
}

