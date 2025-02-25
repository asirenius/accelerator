#include "matrix.h"

#include "xil_printf.h"

#include "../hal/bump_allocator.h"

matrix_t* matrix_create(int rows, int cols) {
    if (rows <= 0 || cols <= 0) {
    	LOG_ERROR("Invalid dimensions %dx%d", rows, cols);
        return NULL;
    }

    // Allocate matrix structure from direct memory
    matrix_t* mat = (matrix_t*)allocator_alloc(sizeof(matrix_t));
    if (!mat) {
        LOG_ERROR("Could not allocate matrix structure");
        return NULL;
    }

    // Allocate data array from direct memory
    mat->data = (fixed_point_t*)allocator_alloc(rows * cols * sizeof(fixed_point_t));
    if (!mat->data) {
        LOG_ERROR("Could not allocate matrix data");
        allocator_free(mat);
        return NULL;
    }

    mat->rows = rows;
    mat->cols = cols;
    return mat;
}

void matrix_destroy(matrix_t* mat) {
    if (!mat) return;

    if (mat->data) {
        allocator_free(mat->data);
    }
    allocator_free(mat);
}

status_t matrix_set(matrix_t* mat, int row, int col, fixed_point_t val) {
	if (!mat) {
    	LOG_ERROR("NULL pointer");
        return STATUS_ERROR_INVALID_PARAM;
	}

    if (row < 0 || row >= mat->rows || col < 0 || col >= mat->cols) {
    	LOG_ERROR("Invalid element %d,%d Dimensions %dx%d", row, col, mat->rows, mat->cols);
        return STATUS_ERROR_INVALID_PARAM;
    }

    mat->data[row * mat->cols + col] = val;
    return STATUS_SUCCESS;
}

status_t matrix_get(const matrix_t* mat, int row, int col, fixed_point_t* val) {
	if (!mat || !val) {
    	LOG_ERROR("NULL pointer(s)");
        return STATUS_ERROR_INVALID_PARAM;
	}

    if (row < 0 || row >= mat->rows || col < 0 || col >= mat->cols) {
    	LOG_ERROR("Invalid element %d,%d Dimensions %dx%d", row, col, mat->rows, mat->cols);
        return STATUS_ERROR_INVALID_PARAM;
    }

    *val = mat->data[row * mat->cols + col];
    return STATUS_SUCCESS;
}

status_t matrix_initialize(matrix_t* mat) {
    if (!mat) {
    	LOG_ERROR("NULL pointer");
        return STATUS_ERROR_INVALID_PARAM;
    }

    for (int i = 0; i < mat->rows; i++) {
        for (int j = 0; j < mat->cols; j++) {
            fixed_point_t val;
            status_t status = int_to_fixed(i * mat->cols + j, &val);
            if (status != STATUS_SUCCESS) {
            	LOG_ERROR("Conversion error at position %d,%d", i, j);
                return status;
            }

            status = matrix_set(mat, i, j, val);
            if (status != STATUS_SUCCESS) {
            	LOG_ERROR("Set error at position %d,%d", i, j);
                return status;
            }
        }
    }
    return STATUS_SUCCESS;
}

status_t matrix_randomize(matrix_t *mat, float min_val, float max_val) {
    if (!mat) {
        LOG_ERROR("NULL pointer");
        return STATUS_ERROR_INVALID_PARAM;
    }

    for (int i = 0; i < mat->rows; i++) {
        for (int j = 0; j < mat->cols; j++) {
            fixed_point_t rand_val;
            status_t status = fixed_random(min_val, max_val, &rand_val);
            if (status != STATUS_SUCCESS) {
                LOG_ERROR("Could not generate random value at position %d,%d", i, j);
                return status;
            }

            status = matrix_set(mat, i, j, rand_val);
            if (status != STATUS_SUCCESS) {
                LOG_ERROR("Could not set value at position %d,%d", i, j);
                return status;
            }
        }
    }

    return STATUS_SUCCESS;
}

status_t matrix_print(const matrix_t* mat, const char* name) {
    if (!mat || !name) {
        LOG_ERROR("NULL pointer(s)");
        return STATUS_ERROR_INVALID_PARAM;
    }

    xil_printf("\r\n%s (%dx%d):\r\n", name, mat->rows, mat->cols);

    for (int i = 0; i < mat->rows; i++) {
        for (int j = 0; j < mat->cols; j++) {
            fixed_point_t val;
            status_t status = matrix_get(mat, i, j, &val);
            if (status != STATUS_SUCCESS) {
                LOG_ERROR("Could not get value at position %d,%d", i, j);
                return status;
            }

            xil_printf(" ");
            fixed_print(val);
            xil_printf(" (%08X)", val);
            xil_printf("\t");
        }
        xil_printf("\r\n");
    }
    return STATUS_SUCCESS;
}

status_t matrix_compare(const matrix_t* m1, const matrix_t* m2, int* result) {
	if (!m1 || !m2 || !result) {
		LOG_ERROR("NULL pointer(s)");
		return STATUS_ERROR_INVALID_PARAM;
	}

    if (m1->rows != m2->rows || m1->cols != m2->cols) {
    	LOG_ERROR("Size mismatch %dx%d, %dx%d", m1->rows, m1->cols, m2->rows, m2->cols);
        return STATUS_ERROR_INVALID_PARAM;
    }

    fixed_point_t val1, val2;

    *result = 0;

    for (int i = 0; i < m1->rows; i++) {
        for (int j = 0; j < m1->cols; j++) {
            status_t status = matrix_get(m1, i, j, &val1);
            if (status != STATUS_SUCCESS) {
            	LOG_ERROR("Could not get value from first matrix at %d,%d", i, j);
                return status;
            }

            status = matrix_get(m2, i, j, &val2);
            if (status != STATUS_SUCCESS) {
            	LOG_ERROR("Could not get value from second matrix at %d,%d", i, j);
                return status;
            }

            if (val1 != val2) {
                *result = 1;
                return STATUS_SUCCESS;
            }
        }
    }

    return STATUS_SUCCESS;
}
