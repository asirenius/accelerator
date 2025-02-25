#!/bin/bash

# Source Vivado settings
source /tools/Xilinx/Vivado/2024.2/settings64.sh

# Create build directory
mkdir -p build/vivado/

# Change directory
cd build/vivado/

# Define parameter arrays
declare -a INPUT_SIZES=(4 8 16 32 64 128 256 512 1024)
declare -a KERNEL_SIZES=(3)
declare -a STRIDES=(1)
declare -a POOL_SIZES=(2)
declare -a DATA_WIDTHS=(32)
declare -a FRACTIONAL_BITS=(12)

# Loop through parameters
for I in "${INPUT_SIZES[@]}"; do
    for K in "${KERNEL_SIZES[@]}"; do
        for S in "${STRIDES[@]}"; do
            for P in "${POOL_SIZES[@]}"; do
                for D in "${DATA_WIDTHS[@]}"; do
                    for F in "${FRACTIONAL_BITS[@]}"; do
                        echo "Running build with ($I $K $S $P $D $F)"
                        source /tools/Xilinx/Vivado/2024.2/settings64.sh && vivado -mode batch -source ../../scripts/build_hw.tcl -tclargs $I $K $S $P $D $F
                    done
                done
            done
        done

   done
done