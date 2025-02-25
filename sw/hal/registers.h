#pragma once

#include "../common/status.h"

status_t registers_write(u32 index, u32 value);
status_t registers_read(u32 index, u32 *value_ptr);
