#pragma once

#include "xparameters.h"

// Memory Map
#define DDR_BASE_ADDR         XPAR_PS7_DDR_0_S_AXI_BASEADDR
#define MEM_BASE_ADDR        (DDR_BASE_ADDR + 0x1000000)

// Memory Regions
#define MATRIX_MEM_BASE      (MEM_BASE_ADDR + 0x00500000)
#define MATRIX_MEM_SIZE       0x04000000  // 64MB

// DMA Configuration
#define DMA_DEV_ID            XPAR_AXIDMA_0_DEVICE_ID
#define DMA_BASE_ADDR         XPAR_AXI_DMA_0_BASEADDR

// Accelerator Configuration
#define ACCELERATOR_BASEADDR  XPAR_ACCELERATOR_0_BASEADDR
#define REG_OFFSET            0x4

// Cache Configuration
#define CACHE_LINE_SIZE       64

// Interrupt Configuration
#define INTC_DEVICE_ID        XPAR_SCUGIC_SINGLE_DEVICE_ID
#define RX_INTR_ID            XPAR_FABRIC_AXIDMA_0_S2MM_INTROUT_VEC_ID
#define TX_INTR_ID            XPAR_FABRIC_AXIDMA_0_MM2S_INTROUT_VEC_ID

// Timeout Configuration
#define RESET_TIMEOUT_COUNTER 10000
#define POLL_TIMEOUT_COUNTER  1000000U

// CNN Parameters
#define INPUT_SIZE            128
#define KERNEL_SIZE           3
#define STRIDE 				  1
#define POOL_SIZE			  2
#define OUTPUT_SIZE        (((INPUT_SIZE - KERNEL_SIZE) / STRIDE + 1) / POOL_SIZE)
#define NUMBER_OF_REGS       (KERNEL_SIZE * KERNEL_SIZE)
