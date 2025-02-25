#include "accelerator.h"

#include "xil_printf.h"

#include "dma.h"
#include "registers.h"

status_t accelerator_init(void) {
    return dma_init();
}

status_t accelerator_cleanup(void) {
    return dma_cleanup();
}

status_t accelerator_set_kernel(matrix_t *kernel) {
	if (!kernel) {
    	LOG_ERROR("NULL pointer");
        return STATUS_ERROR_INVALID_PARAM;
	}

    if (kernel->rows != KERNEL_SIZE || kernel->cols != KERNEL_SIZE) {
    	LOG_ERROR("Invalid kernel dimensions %dx%d", kernel->rows, kernel->cols);
        return STATUS_ERROR_INVALID_PARAM;
    }

    // Write kernel values to hardware registers
    for (int i = 0; i < kernel->rows; i++) {
        for (int j = 0; j < kernel->cols; j++) {
            fixed_point_t val;
            status_t status = matrix_get(kernel, i, j, &val);
            if (status != STATUS_SUCCESS) {
            	LOG_ERROR("Could not read kernel value at %d,%d", i, j);
                return status;
            }

            status = registers_write(i * kernel->cols + j, val);
            if (status != STATUS_SUCCESS) {
            	LOG_ERROR("Could not write to register %d", i * kernel->cols + j);
                return status;
            }
        }
    }
    return STATUS_SUCCESS;
}

status_t accelerator_compute(matrix_t *input, matrix_t *output) {
    status_t status;

    // Send the packet
    status = dma_transfer(input->data,
    					  input->rows * input->cols * sizeof(fixed_point_t),
					   	  output->data,
						  output->rows * output->cols * sizeof(fixed_point_t));
    if (status != STATUS_SUCCESS) {
        LOG_ERROR("Transfer error");
        return status;
    }

    return STATUS_SUCCESS;
}
