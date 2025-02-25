#pragma once

#include "xaxidma.h"
#include "xscugic.h"
#include "xil_util.h"

#include "../common/status.h"
#include "config.h"

// Public Interface
status_t dma_init();
status_t dma_cleanup(void);
status_t dma_transfer(void *TxDataPtr, u32 TxDataSize, void *RxDataPtr, u32 RxDataSize);
