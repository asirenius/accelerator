#include "xil_printf.h"

#include "cnn/cnn.h"
#include "hal/accelerator.h"
#include "hal/bump_allocator.h"
#include "utils/benchmark.h"

#define BENCH_ITERATIONS 100

int main(void) {
    status_t status;
    benchmark_t hw_bench, sw_bench;
    int compare_result;
    matrix_t *input, *kernel, *hw_output, *sw_output;

    // Initialize memory manager
    status = allocator_init();
    if (status != STATUS_SUCCESS) {
        xil_printf("Memory initialization failed\r\n");
        return XST_FAILURE;
    }

    // Initialize hardware
    status = accelerator_init();
    if (status != STATUS_SUCCESS) {
        xil_printf("Hardware initialization failed\r\n");
        return XST_FAILURE;
    }

    // Reset benchmarks
    benchmark_reset(&hw_bench);
    benchmark_reset(&sw_bench);

    // Run benchmark iterations
    for(int i = 0; i < BENCH_ITERATIONS; i++) {

    	//
    	// Generate Test Data
    	//

    	// Reset allocator
    	allocator_reset();

        // Create input matrix
        input = matrix_create(INPUT_SIZE, INPUT_SIZE);
        if (!input) {
            xil_printf("Failed to create input matrix\r\n");
            return XST_FAILURE;
        }


        // Create kernel matrix
        kernel = matrix_create(KERNEL_SIZE, KERNEL_SIZE);
        if (!kernel) {
            xil_printf("Failed to create kernel matrix\r\n");
            matrix_destroy(input);
            return XST_FAILURE;
        }

        // Create output matrix for hardware
        hw_output = matrix_create(OUTPUT_SIZE, OUTPUT_SIZE);
        if (!hw_output) {
            matrix_destroy(kernel);
            matrix_destroy(input);
            xil_printf("Failed to create hardware output matrix\r\n");
            return XST_FAILURE;
        }

        // Create output matrix for software
        sw_output = matrix_create(OUTPUT_SIZE, OUTPUT_SIZE);
        if (!sw_output) {
            matrix_destroy(kernel);
            matrix_destroy(input);
            matrix_destroy(hw_output);
            xil_printf("Failed to create software output matrix\r\n");
            return XST_FAILURE;
        }

        // Randomize input matrix
        status = matrix_randomize(input, -1.0f, 1.0f);
        if (status != STATUS_SUCCESS) {
            xil_printf("Failed to randomize input matrix\r\n");
            goto cleanup;
        }

        // Randomize kernel matrix
        status = matrix_randomize(kernel, -1.0f, 1.0f);
        if (status != STATUS_SUCCESS) {
            xil_printf("Failed to randomize kernel matrix\r\n");
            goto cleanup;
        }

        //
        // Hardware Benchmark
        //

        // Start counter
        benchmark_start(&hw_bench, "Hardware CNN");

        // Configure hardware with kernel
        status = accelerator_set_kernel(kernel);
        if (status != STATUS_SUCCESS) {
            xil_printf("Failed to set kernel in hardware\r\n");
            goto cleanup;
        }

        // Hardware computation
        status = accelerator_compute(input, hw_output);
        if (status != STATUS_SUCCESS) {
            xil_printf("Hardware computation failed\r\n");
            goto cleanup;
        }

        // Stop counter
        benchmark_stop(&hw_bench);

        //
        // Software Benchmark
        //

        // Start counter
        benchmark_start(&sw_bench, "Software CNN");

        // Software computation
        status = cnn_forward(input, kernel, 2, 1, sw_output);
        if (status != STATUS_SUCCESS) {
            xil_printf("Software computation failed\r\n");
            goto cleanup;
        }

        // Stop counter
        benchmark_stop(&sw_bench);

        //
        // Comparison
        //

        // Compare results
        status = matrix_compare(hw_output, sw_output, &compare_result);
        if (status != STATUS_SUCCESS) {
            xil_printf("Result comparison failed\r\n");
            goto cleanup;
        }

        // Break on error
        if (compare_result != 0) {
            xil_printf("Output mismatch detected (Iteration %d)\r\n", i);
            status = matrix_print(hw_output, "HW Output");
            if (status != STATUS_SUCCESS) {
                goto cleanup;
            }
            status = matrix_print(sw_output, "SW Output");
            if (status != STATUS_SUCCESS) {
                goto cleanup;
            }
            goto cleanup;
        }

        // Destroy matrices
        matrix_destroy(kernel);
        matrix_destroy(input);
        matrix_destroy(hw_output);
        matrix_destroy(sw_output);

    }

    // Print benchmark results
    benchmark_print(&hw_bench);
    benchmark_print(&sw_bench);
    benchmark_compare(&hw_bench, &sw_bench);

cleanup:
    accelerator_cleanup();

    return (status == STATUS_SUCCESS) ? 0 : 1;
}
