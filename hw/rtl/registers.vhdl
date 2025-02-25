library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity registers is
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
end entity registers;

architecture rtl of registers is

	-- Constants
	constant ADDR_LSB          : integer := (DATA_WIDTH/32) + 1;
	constant OPT_MEM_ADDR_BITS : integer := integer(ceil(log2(real(NUM_REGISTERS))));

	-- Write Channel Registers
	signal awaddr    : std_logic_vector(ADDR_WIDTH-1 downto 0);
	signal awready   : std_logic;
	signal wready    : std_logic;
	signal bresp     : std_logic_vector(1 downto 0);
	signal bvalid    : std_logic;

	-- Read Channel Registers
	signal araddr    : std_logic_vector(ADDR_WIDTH-1 downto 0);
	signal arready   : std_logic;
	signal rresp     : std_logic_vector(1 downto 0);
	signal rvalid    : std_logic;

	-- Pointer
	signal reg_addr : std_logic_vector(ADDR_LSB + OPT_MEM_ADDR_BITS - 1 downto ADDR_LSB);
	
	-- Register File
	type reg_array_t is array (natural range 0 to NUM_REGISTERS-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
    signal regs     : reg_array_t;

	-- Write State Machine
	type write_state_t is (WADDR, WDATA);
	signal write_state : write_state_t;
	
	-- Read State Machine
	type read_state_t is (RADDR, RDATA);
	signal read_state  : read_state_t;

begin

	-- I/O Connections Assignments
	awready_o <= awready;
	wready_o  <= wready;
	bresp_o	  <= bresp;
	bvalid_o  <= bvalid;
	arready_o <= arready;
	rresp_o	  <= rresp;
	rvalid_o  <= rvalid;
	
	-- Address Decoder
	addr_decode: process(awvalid_i, awaddr_i, awaddr)
	begin
		if awvalid_i = '1' then
			reg_addr <= awaddr_i(ADDR_LSB + OPT_MEM_ADDR_BITS - 1 downto ADDR_LSB);
		else
			reg_addr <= awaddr(ADDR_LSB + OPT_MEM_ADDR_BITS - 1 downto ADDR_LSB);
		end if;
	end process addr_decode;

	-- Kernel Mapping
    k_map: process(regs)
    begin
        for i in 0 to NUM_REGISTERS-1 loop
            kernel_o((i+1)*DATA_WIDTH-1 downto i*DATA_WIDTH) <= regs(i);
        end loop;
    end process k_map;

	-- Write State Machine
	write_fsm: process(clk_i)
	begin
		if rising_edge(clk_i) then
			if rstn_i = '0' then
				awready     <= '0';
				wready      <= '0';
				bvalid      <= '0';
				bresp       <= (others => '0');
				write_state <= WADDR;
			else
				case write_state is
					when WADDR =>
						awready <= '1';
						wready  <= '1';
						if awvalid_i = '1' and awready = '1' then
							awaddr <= awaddr_i;
							if wvalid_i = '1' then
								bvalid <= '1';
							else
								awready <= '0';
								write_state <= WDATA;
							end if;
						end if;
						if bready_i = '1' and bvalid = '1' then
							bvalid <= '0';
						end if;
					when WDATA =>
						if wvalid_i = '1' then
							write_state <= WADDR;
							bvalid <= '1';
							awready <= '1';
						elsif bready_i = '1' and bvalid = '1' then
							bvalid <= '0';
						end if;
				end case;
			end if;
		end if;
	end process write_fsm;

	-- Write Logic
	reg_write: process(clk_i)
		variable reg_index: integer;
	begin
		if rising_edge(clk_i) then
			if rstn_i = '0' then
				for i in 0 to NUM_REGISTERS-1 loop
					regs(i) <= (others => '0');
				end loop;
			else
				if (wvalid_i = '1') then
					reg_index := to_integer(unsigned(reg_addr));
					if reg_index < NUM_REGISTERS then
						for byte_index in 0 to (DATA_WIDTH/8-1) loop
							if wstrb_i(byte_index) = '1' then
								regs(reg_index)(byte_index*8+7 downto byte_index*8) <= wdata_i(byte_index*8+7 downto byte_index*8);
							end if;
						end loop;
					end if;
				end if;
			end if;
		end if;
	end process reg_write;

	-- Read State Machine
	read_fsm: process(clk_i)
	begin
		if rising_edge(clk_i) then
			if rstn_i = '0' then
				arready    <= '0';
				rvalid     <= '0';
				rresp      <= (others => '0');
				read_state <= RADDR;
			else
				case read_state is
					when RADDR =>
						arready <= '1';
						if arvalid_i = '1' and arready = '1' then
							arready    <= '0';
							rvalid     <= '1';
							araddr     <= araddr_i;
							read_state <= RDATA;
						end if;
					when RDATA =>
						if rvalid = '1' and rready_i = '1' then
							rvalid     <= '0';
							arready	   <= '1';
							read_state <= RADDR;
						end if;
				end case;
			end if;
		end if;
	end process read_fsm;
	
	-- Read Logic
    reg_read: process(araddr, regs)
		variable reg_index : integer; 
	begin
		reg_index := to_integer(unsigned(araddr(ADDR_LSB + OPT_MEM_ADDR_BITS - 1 downto ADDR_LSB)));

		if reg_index < NUM_REGISTERS then
			rdata_o <= regs(reg_index);
		else
			rdata_o <= (others => '0');
		end if;
	end process reg_read;

end rtl;
