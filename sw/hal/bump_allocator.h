#pragma once

#include "../common/status.h"
#include "config.h"

/**
 * Simple bump allocator for matrix operations
 * Allocates memory sequentially from a fixed memory pool.
 * Memory can only be reset in bulk, not freed individually.
 */

// Public Interface
status_t allocator_init(void);
void *allocator_alloc(size_t size);
void allocator_free(void *ptr);
void allocator_reset(void);

// Utility
uint32_t allocator_get_used(void);
uint32_t allocator_get_available(void);
