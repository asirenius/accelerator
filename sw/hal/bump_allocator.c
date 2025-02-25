#include "bump_allocator.h"

#include "xil_cache.h"
#include "xil_printf.h"

#define MEMORY_ALIGNMENT CACHE_LINE_SIZE

// State
typedef struct {
    uint32_t next_free;
    uint32_t total_allocated;
    int initialized;
} allocator_state_t;

static allocator_state_t allocator_state;

static uint32_t align_up(uint32_t size) {
    return (size + MEMORY_ALIGNMENT - 1) & ~(MEMORY_ALIGNMENT - 1);
}

static int is_aligned(uintptr_t addr) {
    return (addr & (MEMORY_ALIGNMENT - 1)) == 0;
}

status_t allocator_init(void) {
    if (!is_aligned(MATRIX_MEM_BASE)) {
    	LOG_ERROR("Memory base address 0x%08X not aligned to %d bytes", MATRIX_MEM_BASE, MEMORY_ALIGNMENT);
        return STATUS_ERROR_INVALID_PARAM;
    }

    allocator_state.next_free = MATRIX_MEM_BASE;
    allocator_state.total_allocated = 0;
    allocator_state.initialized = 1;

    return STATUS_SUCCESS;
}

void* allocator_alloc(size_t size) {
    if (!allocator_state.initialized) {
        LOG_ERROR("Allocator not initialized");
        return NULL;
    }

    if (size == 0) {
        LOG_ERROR("Zero size allocation requested");
        return NULL;
     }

    size_t aligned_size = align_up(size);

    if (aligned_size < size) {
    	LOG_ERROR("Size overflow during alignment");
        return NULL;
    }

    if (allocator_state.total_allocated + aligned_size > MATRIX_MEM_SIZE) {
    	LOG_ERROR("Out of memory (requested: %u, available: %u)", aligned_size, MATRIX_MEM_SIZE - allocator_state.total_allocated);
        return NULL;
    }

    void* ptr = (void*)allocator_state.next_free;
    allocator_state.next_free += aligned_size;
    allocator_state.total_allocated += aligned_size;

    Xil_DCacheInvalidateRange((UINTPTR)ptr, aligned_size);

    return ptr;
}

void allocator_free(void* ptr) {
    // No operation. Memory can be reclaimed using memory_reset()
}

void allocator_reset(void) {
    allocator_state.next_free = MATRIX_MEM_BASE;
    allocator_state.total_allocated = 0;
}

uint32_t allocator_get_used(void) {
    return allocator_state.total_allocated;
}

uint32_t allocator_get_available(void) {
    return MATRIX_MEM_SIZE - allocator_state.total_allocated;
}
