#include "dma.h"

#include "xil_cache.h"
#include "xil_exception.h"
#include "xil_printf.h"

// Forward declarations
static status_t setup_intr_system(XScuGic *intc_instance_ptr, XAxiDma *axi_dma_ptr, u16 tx_intr_id, u16 rx_intr_id);
static void disable_intr_system(XScuGic *intc_instance_ptr, u16 tx_intr_id, u16 rx_intr_id);
static void tx_intr_handler(void *callback);
static void rx_intr_handler(void *callback);

// Hardware state
static XAxiDma axi_dma;
static XScuGic interrupt_controller;
static volatile u32 tx_done;
static volatile u32 rx_done;

status_t dma_init() {

	// Fetch DMA configuration
	XAxiDma_Config *config = XAxiDma_LookupConfig(DMA_DEV_ID);
	if (!config) {
		LOG_ERROR("No DMA configuration found for device %d", DMA_DEV_ID);
		return STATUS_ERROR_HARDWARE;
	}

	// Initialize DMA engine
	int status = XAxiDma_CfgInitialize(&axi_dma, config);
	if (status != XST_SUCCESS) {
		LOG_ERROR("DMA initialization error");
		return STATUS_ERROR_HARDWARE;
	}

	// Ensure DMA is configured in simple transfer mode
	if (XAxiDma_HasSg(&axi_dma)) {
		LOG_ERROR("DMA configured for scatter-gather");
		return STATUS_ERROR_HARDWARE;
	}

	// Set up interrupt system
	status = setup_intr_system(&interrupt_controller, &axi_dma, TX_INTR_ID, RX_INTR_ID);
	if (status != XST_SUCCESS) {
		LOG_ERROR("Interrupt system setup error");
		return status;
	}

	// Toggle interrupts
	XAxiDma_IntrDisable(&axi_dma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DMA_TO_DEVICE);
	XAxiDma_IntrDisable(&axi_dma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DEVICE_TO_DMA);
	XAxiDma_IntrEnable(&axi_dma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DMA_TO_DEVICE);
	XAxiDma_IntrEnable(&axi_dma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DEVICE_TO_DMA);

	return STATUS_SUCCESS;
}

status_t dma_cleanup(void) {
	disable_intr_system(&interrupt_controller, TX_INTR_ID, RX_INTR_ID);
	return STATUS_SUCCESS;
}

status_t dma_transfer(void *tx_data_ptr, u32 tx_data_size, void *rx_data_ptr, u32 rx_data_size) {
    // Initialize flags
    tx_done = 0;
    rx_done = 0;

    // Flush the buffers before DMA transfer
    Xil_DCacheFlushRange((UINTPTR)tx_data_ptr, tx_data_size);
    Xil_DCacheFlushRange((UINTPTR)rx_data_ptr, rx_data_size);

    // Configure DMA to receive data from hardware
    int status = XAxiDma_SimpleTransfer(&axi_dma, (UINTPTR)rx_data_ptr, rx_data_size, XAXIDMA_DEVICE_TO_DMA);
    if (status != XST_SUCCESS) {
        LOG_ERROR("RX DMA transfer setup error");
        return STATUS_ERROR_HARDWARE;
    }

    // Send data to hardware for processing
    status = XAxiDma_SimpleTransfer(&axi_dma, (UINTPTR)tx_data_ptr, tx_data_size, XAXIDMA_DMA_TO_DEVICE);
    if (status != XST_SUCCESS) {
        LOG_ERROR("TX DMA transfer error");
        return STATUS_ERROR_HARDWARE;
    }

    // Wait for transmission complete
    status = Xil_WaitForEventSet(POLL_TIMEOUT_COUNTER, 1, &tx_done);
    if (status != XST_SUCCESS) {
        LOG_ERROR("TX completion timeout");
        return STATUS_ERROR_HARDWARE;
    }

    // Wait for reception complete
    status = Xil_WaitForEventSet(POLL_TIMEOUT_COUNTER, 1, &rx_done);
    if (status != XST_SUCCESS) {
        LOG_ERROR("RX completion timeout");
        return STATUS_ERROR_HARDWARE;
    }

    // Invalidate receive buffer
    Xil_DCacheInvalidateRange((UINTPTR)rx_data_ptr, rx_data_size);

    return STATUS_SUCCESS;
}

static void tx_intr_handler(void *callback) {
	XAxiDma *axi_dma_inst = (XAxiDma *)callback;

	// Read and acknowledge pending interrupts
	u32 irq_status = XAxiDma_IntrGetIrq(axi_dma_inst, XAXIDMA_DMA_TO_DEVICE);
	XAxiDma_IntrAckIrq(axi_dma_inst, irq_status, XAXIDMA_DMA_TO_DEVICE);

	// Early exit if no interrupts are active
	if (!(irq_status & XAXIDMA_IRQ_ALL_MASK)) {
		return;
	}

	// If error bit is set, need to reset the DMA engine
	if ((irq_status & XAXIDMA_IRQ_ERROR_MASK)) {

		// Reset DMA engine
		XAxiDma_Reset(axi_dma_inst);

		// Wait until reset is done
		int time_out = RESET_TIMEOUT_COUNTER;
		while (time_out) {
			if (XAxiDma_ResetIsDone(axi_dma_inst)) {
				break;
			}
			time_out -= 1;
		}
		return;
	}

	// If IOC (Interrupt On Complete) bit set, transfer is done
	if ((irq_status & XAXIDMA_IRQ_IOC_MASK)) {
		tx_done = 1;
	}
}

static void rx_intr_handler(void *callback) {
	XAxiDma *axi_dma_inst = (XAxiDma *)callback;

	// Read and acknowledge pending interrupts
	u32 irq_status = XAxiDma_IntrGetIrq(axi_dma_inst, XAXIDMA_DEVICE_TO_DMA);
	XAxiDma_IntrAckIrq(axi_dma_inst, irq_status, XAXIDMA_DEVICE_TO_DMA);

	// Early exit if no interrupts are active
	if (!(irq_status & XAXIDMA_IRQ_ALL_MASK)) {
		return;
	}

	// If error bit is set, need to reset the DMA engine
	if ((irq_status & XAXIDMA_IRQ_ERROR_MASK)) {

		// Reset DMA engine
		XAxiDma_Reset(axi_dma_inst);

		// Wait until reset is done
		int time_out = RESET_TIMEOUT_COUNTER;
		while (time_out) {
			if (XAxiDma_ResetIsDone(axi_dma_inst)) {
				break;
			}
			time_out -= 1;
		}
		return;
	}

	// If IOC (Interrupt On Complete) bit set, transfer is done
	if ((irq_status & XAXIDMA_IRQ_IOC_MASK)) {
		rx_done = 1;
	}
}

static status_t setup_intr_system(XScuGic *intc_instance_ptr, XAxiDma *axi_dma_ptr, u16 tx_intr_id, u16 rx_intr_id) {

	// Initialize the Generic Interrupt Controller (GIC)
	XScuGic_Config *intc_config = XScuGic_LookupConfig(INTC_DEVICE_ID);
	if (NULL == intc_config) {
		LOG_ERROR("No GIC configuration found");
		return STATUS_ERROR_HARDWARE;
	}

	// Configure the GIC with base address and configuration data
	int status = XScuGic_CfgInitialize(intc_instance_ptr, intc_config, intc_config->CpuBaseAddress);
	if (status != XST_SUCCESS) {
		LOG_ERROR("GIC initialization error");
		return STATUS_ERROR_HARDWARE;
	}

	// Set up interrupt priorities and triggers
	XScuGic_SetPriorityTriggerType(intc_instance_ptr, tx_intr_id, 0xA0, 0x3);
	XScuGic_SetPriorityTriggerType(intc_instance_ptr, rx_intr_id, 0xA0, 0x3);

	// Connect TX interrupt handler to the GIC
	status = XScuGic_Connect(intc_instance_ptr, tx_intr_id,(Xil_InterruptHandler)tx_intr_handler, axi_dma_ptr);
	if (status != XST_SUCCESS) {
		LOG_ERROR("ITX interrupt connection error");
		return STATUS_ERROR_HARDWARE;
	}

	// Connect RX interrupt handler to the GIC
	status = XScuGic_Connect(intc_instance_ptr, rx_intr_id, (Xil_InterruptHandler)rx_intr_handler, axi_dma_ptr);
	if (status != XST_SUCCESS) {
		LOG_ERROR("RX interrupt connection error");
		return STATUS_ERROR_HARDWARE;
	}

	// Enable the interrupts in the GIC
	XScuGic_Enable(intc_instance_ptr, tx_intr_id);
	XScuGic_Enable(intc_instance_ptr, rx_intr_id);

	// Initialize exception handling
	Xil_ExceptionInit();

	// Register GIC handler for interrupt exceptions
	Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT, (Xil_ExceptionHandler)XScuGic_InterruptHandler, (void *)intc_instance_ptr);

	// Enable exceptions
	Xil_ExceptionEnable();

	return STATUS_SUCCESS;
}

static void disable_intr_system(XScuGic *intc_instance_ptr, u16 tx_intr_id, u16 rx_intr_id) {
	XScuGic_Disconnect(intc_instance_ptr, tx_intr_id);
	XScuGic_Disconnect(intc_instance_ptr, rx_intr_id);
}
