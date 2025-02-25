#include "registers.h"

#include "xil_io.h"
#include "config.h"

status_t registers_write(u32 index, u32 value) {
	Xil_Out32(ACCELERATOR_BASEADDR + (index * REG_OFFSET), value);
	return STATUS_SUCCESS;
}

status_t registers_read(u32 index, u32 *value_ptr) {
	*value_ptr = Xil_In32(ACCELERATOR_BASEADDR + (index * REG_OFFSET));
	return STATUS_SUCCESS;
}
