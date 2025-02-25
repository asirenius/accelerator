#pragma once

#include "fixed.h"
#include "status.h"

// Matrix type with continuous memory layout
typedef struct {
	int rows;
	int cols;
	fixed_point_t *data;
} matrix_t;

// Creation and destruction
matrix_t* matrix_create(int rows, int cols);
void matrix_destroy(matrix_t *mat);

// Basic operations
status_t matrix_set(matrix_t *mat, int row, int col, fixed_point_t val);
status_t matrix_get(const matrix_t *mat, int row, int col, fixed_point_t *val);

// Utility functions
status_t matrix_initialize(matrix_t *mat);
status_t matrix_randomize(matrix_t *mat, float min_val, float max_val);
status_t matrix_print(const matrix_t* mat, const char* name);
status_t matrix_compare(const matrix_t *mat1, const matrix_t *mat2, int *result);
