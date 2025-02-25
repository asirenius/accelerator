library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity accelerator is
	generic (
		INPUT_SIZE      : integer := 6;
		KERNEL_SIZE     : integer := 3;
		STRIDE          : integer := 1;
		POOL_SIZE	    : integer := 2;
		DATA_WIDTH      : integer := 32;
		FRACTIONAL_BITS : integer := 12;
		ADDR_WIDTH	    : integer := 6;
		NUM_REGISTERS   : integer := 9
	);
	port (
		clk_i  : in std_logic;
		rstn_i : in std_logic;

		-- AXI4-Lite Slave Interface
		s_axi_awaddr  : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
		s_axi_awprot  : in  std_logic_vector(2 downto 0);
		s_axi_awvalid : in  std_logic;
		s_axi_awready : out std_logic;
		s_axi_wdata	  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
		s_axi_wstrb	  : in  std_logic_vector((DATA_WIDTH/8)-1 downto 0);
		s_axi_wvalid  : in  std_logic;
		s_axi_wready  : out std_logic;
		s_axi_bresp	  : out std_logic_vector(1 downto 0);
		s_axi_bvalid  : out std_logic;
		s_axi_bready  : in  std_logic;
		s_axi_araddr  : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
		s_axi_arprot  : in  std_logic_vector(2 downto 0);
		s_axi_arvalid : in  std_logic;
		s_axi_arready : out std_logic;
		s_axi_rdata	  : out std_logic_vector(DATA_WIDTH-1 downto 0);
		s_axi_rresp	  : out std_logic_vector(1 downto 0);
		s_axi_rvalid  : out std_logic;
		s_axi_rready  : in  std_logic;

		-- AXI4-Stream Slave Interface
		s_axis_tready  : out std_logic;
		s_axis_tdata   : in std_logic_vector(DATA_WIDTH-1 downto 0);
		s_axis_tstrb   : in std_logic_vector((DATA_WIDTH/8)-1 downto 0);
		s_axis_tlast   : in std_logic;
		s_axis_tvalid  : in std_logic;

		-- AXI4-Stream Master Interface
		m_axis_tvalid  : out std_logic;
		m_axis_tdata   : out std_logic_vector(DATA_WIDTH-1 downto 0);
		m_axis_tstrb   : out std_logic_vector((DATA_WIDTH/8)-1 downto 0);
		m_axis_tlast   : out std_logic;
		m_axis_tready  : in std_logic
	);
end entity accelerator;

architecture rtl of accelerator is

	-- Convolver Declaration
	component convolver is
		generic (
			INPUT_SIZE      : integer := 6;
			KERNEL_SIZE     : integer := 3;
			STRIDE          : integer := 1;
			DATA_WIDTH      : integer := 32;
			FRACTIONAL_BITS : integer := 12
		);
		port (
			clk_i        : in  std_logic;
			rst_i        : in  std_logic;
			
			-- Kernel
			kernel_i : in  std_logic_vector((KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH)-1 downto 0);
			
			-- Input Stream Interface
			data_i  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
			valid_i : in  std_logic;
			ready_o : out std_logic;
			last_i  : in  std_logic;
			
			-- Output Stream Interface
			data_o  : out std_logic_vector(DATA_WIDTH-1 downto 0);
			valid_o : out std_logic;
			ready_i : in  std_logic;
			last_o  : out std_logic
		);
	end component convolver;

	-- ReLU Declaration
	component relu is
		generic (
			DATA_WIDTH : integer := 32
		);
		port (
			data_i : in std_logic_vector(DATA_WIDTH-1 downto 0);
			data_o : out std_logic_vector(DATA_WIDTH-1 downto 0)
		);
	end component relu;

	-- Pooler Declaration
	component pooler is
		generic (
			INPUT_SIZE : integer := 6;
			POOL_SIZE  : integer := 2;
			DATA_WIDTH : integer := 32
		);
		port (
			clk_i   : in  std_logic;
			rst_i   : in  std_logic;
			data_i  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
			valid_i : in  std_logic;
			ready_o : out std_logic;
			last_i  : in  std_logic;
			data_o  : out std_logic_vector(DATA_WIDTH-1 downto 0);
			valid_o : out std_logic;
			ready_i : in  std_logic;
			last_o  : out std_logic
		);
	end component pooler;

	-- Registers Declaration
	component registers is
		generic (
			DATA_WIDTH	  : integer	:= 32;
			ADDR_WIDTH	  : integer	:= 6;
			NUM_REGISTERS : integer := 9
		);
		port (
			clk_i     : in  std_logic;
			rstn_i    : in  std_logic;
	
			--  Write Address Interface
			awaddr_i  : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
			awprot_i  : in  std_logic_vector(2 downto 0);
			awvalid_i : in  std_logic;
			awready_o : out std_logic;
	
			-- Write Data Interface
			wdata_i	  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
			wstrb_i	  : in  std_logic_vector((DATA_WIDTH/8)-1 downto 0);
			wvalid_i  : in  std_logic;
			wready_o  : out std_logic;
	
			-- Write Response Interface
			bresp_o	  : out std_logic_vector(1 downto 0);
			bvalid_o  : out std_logic;
			bready_i  : in  std_logic;
	
			-- Read Address Interface
			araddr_i  : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
			arprot_i  : in  std_logic_vector(2 downto 0);
			arvalid_i : in  std_logic;
			arready_o : out std_logic;
	
			-- Read Data Interface
			rdata_o	  : out std_logic_vector(DATA_WIDTH-1 downto 0);
			rresp_o	  : out std_logic_vector(1 downto 0);
			rvalid_o  : out std_logic;
			rready_i  : in  std_logic;
	
			-- Output Interface
			kernel_o  : out std_logic_vector(DATA_WIDTH*NUM_REGISTERS-1 downto 0)
		);
	end component registers;

	-- Signals
	signal convolver_data_o   : std_logic_vector(DATA_WIDTH-1 downto 0);
	signal convolver_valid_o  : std_logic;
	signal convolver_last_o   : std_logic;
	signal relu_data_o        : std_logic_vector(DATA_WIDTH-1 downto 0);
	signal pooler_ready_o     : std_logic;
	signal registers_kernel_o : std_logic_vector(DATA_WIDTH*NUM_REGISTERS-1 downto 0);

begin

	convolver_inst: convolver
		generic map (
			INPUT_SIZE      => INPUT_SIZE,
			KERNEL_SIZE     => KERNEL_SIZE,
			STRIDE          => STRIDE,
			DATA_WIDTH      => DATA_WIDTH,
			FRACTIONAL_BITS => FRACTIONAL_BITS
		)
		port map (
			clk_i    => clk_i,
			rst_i    => not rstn_i,
			kernel_i => registers_kernel_o,
			data_i   => s_axis_tdata,
			valid_i  => s_axis_tvalid,
			ready_o  => s_axis_tready,
			last_i   => s_axis_tlast,
			data_o   => convolver_data_o,
			valid_o  => convolver_valid_o,
			ready_i  => pooler_ready_o,
			last_o   => convolver_last_o
		);

	relu_inst: relu
		generic map (
			DATA_WIDTH => DATA_WIDTH
		)
		port map (
			data_i => convolver_data_o,
			data_o => relu_data_o
		);

	pooler_inst: pooler
		generic map (
			INPUT_SIZE => (INPUT_SIZE-KERNEL_SIZE+1)/STRIDE,
			POOL_SIZE  => POOL_SIZE,
			DATA_WIDTH => DATA_WIDTH
		)
		port map (
			clk_i   => clk_i,
			rst_i   => not rstn_i,
			data_i  => relu_data_o,
			valid_i => convolver_valid_o,
			ready_o => pooler_ready_o,
			last_i  => convolver_last_o,
			data_o  => m_axis_tdata,
			valid_o => m_axis_tvalid,
			ready_i => m_axis_tready,
			last_o  => m_axis_tlast
		);

	registers_inst: registers
		generic map (
			DATA_WIDTH    => DATA_WIDTH,
			ADDR_WIDTH    => ADDR_WIDTH,
			NUM_REGISTERS => NUM_REGISTERS
		)
		port map (
			clk_i     => clk_i,
			rstn_i    => rstn_i,
			awaddr_i  => s_axi_awaddr,
			awprot_i  => s_axi_awprot,
			awvalid_i => s_axi_awvalid,
			awready_o => s_axi_awready,
			wdata_i   => s_axi_wdata,
			wstrb_i   => s_axi_wstrb,
			wvalid_i  => s_axi_wvalid,
			wready_o  => s_axi_wready,
			bresp_o   => s_axi_bresp,
			bvalid_o  => s_axi_bvalid,
			bready_i  => s_axi_bready,
			araddr_i  => s_axi_araddr,
			arprot_i  => s_axi_arprot,
			arvalid_i => s_axi_arvalid,
			arready_o => s_axi_arready,
			rdata_o   => s_axi_rdata,
			rresp_o   => s_axi_rresp,
			rvalid_o  => s_axi_rvalid,
			rready_i  => s_axi_rready,
			kernel_o  => registers_kernel_o
		);

end rtl;
