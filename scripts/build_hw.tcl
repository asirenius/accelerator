
# Check arguments
if { $argc != 6 } {
    puts "Error: Incorrect number of arguments"
    puts "Usage: vivado -mode batch -source build_hw.tcl -tclargs <INPUT_SIZE> <KERNEL_SIZE>"
    exit 1
}

# Read arguments
set INPUT_SIZE [lindex $argv 0]
set KERNEL_SIZE [lindex $argv 1]
set STRIDE [lindex $argv 2]
set POOL_SIZE [lindex $argv 3]
set DATA_WIDTH [lindex $argv 4]
set FRACTIONAL_BITS [lindex $argv 5]

# Calculations
set NUM_REGISTERS [expr {$KERNEL_SIZE * $KERNEL_SIZE}]
set ADDR_LSB [expr {$DATA_WIDTH/32 + 1}]
set OPT_MEM_ADDR_BITS [expr {ceil(log($NUM_REGISTERS)/log(2))}]
set ADDR_WIDTH [expr {$ADDR_LSB + $OPT_MEM_ADDR_BITS}]

# Board Repository
set_param board.repoPaths [list "$::env(HOME)/.Xilinx/Vivado/2024.2/xhub/board_store/xilinx_board_store"]

# Project name
set PROJECT "hw_M${INPUT_SIZE}_K${KERNEL_SIZE}_S${STRIDE}_P${POOL_SIZE}_Q${DATA_WIDTH}-${FRACTIONAL_BITS}"

# Setup directories
set ROOT_DIR "[file normalize [file dirname [info script]]]/.."
set CONSTS_DIR "$ROOT_DIR/hw/constraints"
set RTL_DIR "$ROOT_DIR/hw/rtl"

# Setup build directories
set BUILD_DIR "$ROOT_DIR/build"
set TEMP_DIR "$BUILD_DIR/temp"
set XSA_DIR "$BUILD_DIR/platforms/"

# Create directories
file mkdir $BUILD_DIR
file mkdir $TEMP_DIR
file mkdir $XSA_DIR

# Clean up existing project
file delete -force $TEMP_DIR
file mkdir $TEMP_DIR

# Create the project
create_project $PROJECT $TEMP_DIR -part xc7z020clg400-1

# Set project properties
set_property board_part digilentinc.com:arty-z7-20:part0:1.1 [current_project]

# Specify target language
set_property target_language VHDL [current_project]

# Import constraints
import_files -fileset constrs_1 -force -norecurse $CONSTS_DIR/Arty-Z7-20.xdc

# Import RTL sources
import_files -norecurse [glob $RTL_DIR/*.vhd*]

# Update compile order
update_compile_order -fileset sources_1

# Create block design
create_bd_design "design_1"

# Update compile order
update_compile_order -fileset sources_1

# Add Zynq Processing System
create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0

# Block Automation for Zynq Processing System
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 -config {make_external "FIXED_IO, DDR" apply_board_preset "1" Master "Disable" Slave "Disable" }  [get_bd_cells processing_system7_0]

# Configure Zynq Processing System
set_property -dict [list \
  CONFIG.PCW_IRQ_F2P_INTR {1} \
  CONFIG.PCW_USE_FABRIC_INTERRUPT {1} \
  CONFIG.PCW_USE_S_AXI_HP0 {1} \
] [get_bd_cells processing_system7_0]

# Add Accelerator
create_bd_cell -type module -reference accelerator accelerator_0

# Add DMA
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_0

# Add Concat
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_0

# Configure DMA
set_property CONFIG.c_sg_include_stscntrl_strm {0} [get_bd_cells axi_dma_0]
set_property CONFIG.c_include_sg {0} [get_bd_cells axi_dma_0]
set_property CONFIG.c_sg_length_width {23} [get_bd_cells axi_dma_0]

# Automation 1
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master {/processing_system7_0/M_AXI_GP0} Slave {/accelerator_0/s_axi} ddr_seg {Auto} intc_ip {New AXI SmartConnect} master_apm {0}}  [get_bd_intf_pins accelerator_0/s_axi]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master {/processing_system7_0/M_AXI_GP0} Slave {/axi_dma_0/S_AXI_LITE} ddr_seg {Auto} intc_ip {New AXI SmartConnect} master_apm {0}}  [get_bd_intf_pins axi_dma_0/S_AXI_LITE]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master {/axi_dma_0/M_AXI_MM2S} Slave {/processing_system7_0/S_AXI_HP0} ddr_seg {Auto} intc_ip {New AXI Interconnect} master_apm {0}}  [get_bd_intf_pins processing_system7_0/S_AXI_HP0]

# Automation 2
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {Auto} Clk_slave {/processing_system7_0/FCLK_CLK0 (100 MHz)} Clk_xbar {/processing_system7_0/FCLK_CLK0 (100 MHz)} Master {/axi_dma_0/M_AXI_S2MM} Slave {/processing_system7_0/S_AXI_HP0} ddr_seg {Auto} intc_ip {/axi_mem_intercon} master_apm {0}}  [get_bd_intf_pins axi_dma_0/M_AXI_S2MM]

# Accelerator Interface -> DMA Interfaces
connect_bd_intf_net [get_bd_intf_pins accelerator_0/s_axis] [get_bd_intf_pins axi_dma_0/M_AXIS_MM2S]
connect_bd_intf_net [get_bd_intf_pins accelerator_0/m_axis] [get_bd_intf_pins axi_dma_0/S_AXIS_S2MM]

# Accelerator Clock and Reset -> PS Clock and Reset
connect_bd_net [get_bd_pins accelerator_0/clk_i] [get_bd_pins processing_system7_0/FCLK_CLK0]
connect_bd_net [get_bd_pins accelerator_0/rstn_i] [get_bd_pins rst_ps7_0_100M/peripheral_aresetn]

# DMA Interupts -> Concat -> PS
connect_bd_net [get_bd_pins axi_dma_0/mm2s_introut] [get_bd_pins xlconcat_0/In0]
connect_bd_net [get_bd_pins axi_dma_0/s2mm_introut] [get_bd_pins xlconcat_0/In1]
connect_bd_net [get_bd_pins xlconcat_0/dout] [get_bd_pins processing_system7_0/IRQ_F2P]

# Configure Accelerator
set_property CONFIG.INPUT_SIZE $INPUT_SIZE [get_bd_cells accelerator_0]
set_property CONFIG.KERNEL_SIZE $KERNEL_SIZE [get_bd_cells accelerator_0]
set_property CONFIG.STRIDE $STRIDE [get_bd_cells accelerator_0]
set_property CONFIG.POOL_SIZE $POOL_SIZE [get_bd_cells accelerator_0]
set_property CONFIG.DATA_WIDTH $DATA_WIDTH [get_bd_cells accelerator_0]
set_property CONFIG.FRACTIONAL_BITS $FRACTIONAL_BITS [get_bd_cells accelerator_0]
set_property CONFIG.ADDR_WIDTH $ADDR_WIDTH [get_bd_cells accelerator_0]
set_property CONFIG.NUM_REGISTERS $NUM_REGISTERS [get_bd_cells accelerator_0]

# Validate design
validate_bd_design

# Save design
save_bd_design

# Make Hardware Wrapper
make_wrapper -files [get_files $TEMP_DIR/${PROJECT}.srcs/sources_1/bd/design_1/design_1.bd] -top
add_files -norecurse $TEMP_DIR/${PROJECT}.gen/sources_1/bd/design_1/hdl/design_1_wrapper.vhd

# Update compile order
update_compile_order -fileset sources_1

# Set as top
# Disabling source management mode.  This is to allow the top design properties to be set without GUI intervention.
set_property source_mgmt_mode None [current_project]
set_property top design_1_wrapper [current_fileset]
# Re-enabling previously disabled source management mode.
set_property source_mgmt_mode All [current_project]

# Update compile order
update_compile_order -fileset sources_1

# Launch synthesis
launch_runs synth_1
wait_on_run synth_1

# Launch implementation
launch_runs impl_1
wait_on_run impl_1

# Generate bitstream
launch_runs impl_1 -to_step write_bitstream
wait_on_run impl_1

# Export hardware platform
write_hw_platform -fixed -include_bit -force -file $XSA_DIR/$PROJECT.xsa