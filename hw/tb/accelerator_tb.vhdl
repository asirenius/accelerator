library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity accelerator_tb is
end accelerator_tb;

architecture sim of accelerator_tb is

    -- Constants
    constant CLK_PERIOD      : time    := 10 ns;
    constant INPUT_SIZE      : integer := 6;
    constant KERNEL_SIZE     : integer := 3;
    constant STRIDE          : integer := 1;
    constant POOL_SIZE       : integer := 2;
    constant DATA_WIDTH      : integer := 32;
    constant FRACTIONAL_BITS : integer := 12;
    constant ADDR_WIDTH      : integer := 6;
    constant NUM_REGISTERS   : integer := 9;
    
    -- Test data constants
    type kernel_array is array (0 to KERNEL_SIZE*KERNEL_SIZE-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
    type input_array is array (0 to INPUT_SIZE*INPUT_SIZE-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
    
    constant KERNEL_DATA : kernel_array := (
        X"0000585A", X"FFFF80D3", X"00002522",  -- Row 1
        X"000078DB", X"FFFFC25B", X"000075CF",  -- Row 2
        X"00005614", X"000065E2", X"0000683B"   -- Row 3
    );
    
    constant INPUT_DATA : input_array := (
        X"FFFFE0C5", X"FFFFDF2A", X"0000484E", X"FFFFD3D9", X"00004BBE", X"FFFF9548",  -- Row 1
        X"0000567D", X"000065BE", X"00004E9D", X"FFFFB37A", X"FFFFC273", X"FFFF95F4",  -- Row 2
        X"FFFFD781", X"FFFF9E83", X"00001902", X"000038DB", X"00000BD7", X"FFFF9318",  -- Row 3
        X"00007B14", X"00002E01", X"0000669E", X"0000248E", X"00000CDF", X"FFFFD056",  -- Row 4
        X"00002420", X"FFFFA9F6", X"FFFFCB0C", X"FFFFC4CB", X"000058DC", X"FFFFD3D0",  -- Row 5
        X"000077EE", X"00001F2A", X"0000200B", X"FFFFD034", X"00003B7B", X"00006598"   -- Row 6
    );
    
    -- Component Declaration
    component accelerator is
        generic (
            INPUT_SIZE      : integer := 6;
            KERNEL_SIZE     : integer := 3;
            STRIDE          : integer := 1;
            POOL_SIZE      : integer := 2;
            DATA_WIDTH      : integer := 32;
            FRACTIONAL_BITS : integer := 12;
            ADDR_WIDTH     : integer := 8;
            NUM_REGISTERS  : integer := 9
        );
        port (
            clk_i  : in std_logic;
            rstn_i : in std_logic;
    
            -- AXI4-Lite Slave Interface
            s_axi_awaddr  : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
            s_axi_awprot  : in  std_logic_vector(2 downto 0);
            s_axi_awvalid : in  std_logic;
            s_axi_awready : out std_logic;
            s_axi_wdata   : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            s_axi_wstrb   : in  std_logic_vector((DATA_WIDTH/8)-1 downto 0);
            s_axi_wvalid  : in  std_logic;
            s_axi_wready  : out std_logic;
            s_axi_bresp   : out std_logic_vector(1 downto 0);
            s_axi_bvalid  : out std_logic;
            s_axi_bready  : in  std_logic;
            s_axi_araddr  : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
            s_axi_arprot  : in  std_logic_vector(2 downto 0);
            s_axi_arvalid : in  std_logic;
            s_axi_arready : out std_logic;
            s_axi_rdata   : out std_logic_vector(DATA_WIDTH-1 downto 0);
            s_axi_rresp   : out std_logic_vector(1 downto 0);
            s_axi_rvalid  : out std_logic;
            s_axi_rready  : in  std_logic;
    
            -- AXI4-Stream Slave Interface
            s_axis_tready : out std_logic;
            s_axis_tdata  : in std_logic_vector(DATA_WIDTH-1 downto 0);
            s_axis_tstrb  : in std_logic_vector((DATA_WIDTH/8)-1 downto 0);
            s_axis_tlast  : in std_logic;
            s_axis_tvalid : in std_logic;
    
            -- AXI4-Stream Master Interface
            m_axis_tvalid : out std_logic;
            m_axis_tdata  : out std_logic_vector(DATA_WIDTH-1 downto 0);
            m_axis_tstrb  : out std_logic_vector((DATA_WIDTH/8)-1 downto 0);
            m_axis_tlast  : out std_logic;
            m_axis_tready : in std_logic
        );
    end component accelerator;

    -- Signals
    signal clk_i   : std_logic := '0';
    signal rstn_i  : std_logic := '0';
    
    -- AXI-Lite Signals
    signal s_axi_awaddr  : std_logic_vector(ADDR_WIDTH-1 downto 0) := (others => '0');
    signal s_axi_awprot  : std_logic_vector(2 downto 0) := (others => '0');
    signal s_axi_awvalid : std_logic := '0';
    signal s_axi_awready : std_logic;
    signal s_axi_wdata   : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal s_axi_wstrb   : std_logic_vector((DATA_WIDTH/8)-1 downto 0) := (others => '1');
    signal s_axi_wvalid  : std_logic := '0';
    signal s_axi_wready  : std_logic;
    signal s_axi_bresp   : std_logic_vector(1 downto 0);
    signal s_axi_bvalid  : std_logic;
    signal s_axi_bready  : std_logic := '0';
    signal s_axi_araddr  : std_logic_vector(ADDR_WIDTH-1 downto 0) := (others => '0');
    signal s_axi_arprot  : std_logic_vector(2 downto 0) := (others => '0');
    signal s_axi_arvalid : std_logic := '0';
    signal s_axi_arready : std_logic;
    signal s_axi_rdata   : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal s_axi_rresp   : std_logic_vector(1 downto 0);
    signal s_axi_rvalid  : std_logic;
    signal s_axi_rready  : std_logic := '0';
    
    -- AXI-Stream Signals
    signal s_axis_tready : std_logic;
    signal s_axis_tdata  : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal s_axis_tstrb  : std_logic_vector((DATA_WIDTH/8)-1 downto 0) := (others => '1');
    signal s_axis_tlast  : std_logic := '0';
    signal s_axis_tvalid : std_logic := '0';
    signal m_axis_tvalid : std_logic;
    signal m_axis_tdata  : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal m_axis_tstrb  : std_logic_vector((DATA_WIDTH/8)-1 downto 0);
    signal m_axis_tlast  : std_logic;
    signal m_axis_tready : std_logic := '1';
    
    signal sim_done : boolean := false;

    -- Helper functions
    function to_fixed(real_num : real) return std_logic_vector is
       variable scaled_num : integer;
    begin
       scaled_num := integer(real_num * real(2**FRACTIONAL_BITS));
       return std_logic_vector(to_signed(scaled_num, DATA_WIDTH));
    end function;
    
    function to_real(fixed_num : std_logic_vector) return real is
    begin
       return real(to_integer(signed(fixed_num))) / real(2**FRACTIONAL_BITS);
    end function;

    -- Helper procedures
    procedure write_register(
        signal clk      : in  std_logic;
        signal awaddr   : out std_logic_vector(ADDR_WIDTH-1 downto 0);
        signal awvalid  : out std_logic;
        signal wdata    : out std_logic_vector(DATA_WIDTH-1 downto 0);
        signal wvalid   : out std_logic;
        signal bready   : out std_logic;
        addr           : in  integer;
        data           : in  std_logic_vector(DATA_WIDTH-1 downto 0)
    ) is
    begin
        -- Address phase
        awaddr <= std_logic_vector(to_unsigned(addr, ADDR_WIDTH));
        awvalid <= '1';
        wait until rising_edge(clk) and s_axi_awready = '1';
        awvalid <= '0';
        
        -- Data phase
        wdata <= data;
        wvalid <= '1';
        wait until rising_edge(clk) and s_axi_wready = '1';
        wvalid <= '0';
        
        -- Response phase
        bready <= '1';
        wait until rising_edge(clk) and s_axi_bvalid = '1';
        wait until rising_edge(clk);
        bready <= '0';
    end procedure;
    
    procedure read_register(
        signal clk      : in  std_logic;
        signal araddr   : out std_logic_vector(ADDR_WIDTH-1 downto 0);
        signal arvalid  : out std_logic;
        signal rready   : out std_logic;
        addr           : in  integer
    ) is
    begin
        araddr <= std_logic_vector(to_unsigned(addr, ADDR_WIDTH));
        arvalid <= '1';
        rready <= '1';
        wait until rising_edge(clk) and s_axi_arready = '1';
        arvalid <= '0';
        wait until s_axi_rvalid = '1';
        wait until rising_edge(clk);
        rready <= '0';
    end procedure;

begin

    -- Clock generation
    clk_proc: process
    begin
        while not sim_done loop
            clk_i <= '0';
            wait for CLK_PERIOD/2;
            clk_i <= '1';
            wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process;

    -- Instantiation
    DUT: accelerator
        generic map (
            INPUT_SIZE      => INPUT_SIZE,
            KERNEL_SIZE     => KERNEL_SIZE,
            STRIDE          => STRIDE,
            POOL_SIZE       => POOL_SIZE,
            DATA_WIDTH      => DATA_WIDTH,
            FRACTIONAL_BITS => FRACTIONAL_BITS,
            ADDR_WIDTH      => ADDR_WIDTH,
            NUM_REGISTERS   => NUM_REGISTERS
        )
        port map (
            clk_i         => clk_i,
            rstn_i        => rstn_i,
            s_axi_awaddr  => s_axi_awaddr,
            s_axi_awprot  => s_axi_awprot,
            s_axi_awvalid => s_axi_awvalid,
            s_axi_awready => s_axi_awready,
            s_axi_wdata   => s_axi_wdata,
            s_axi_wstrb   => s_axi_wstrb,
            s_axi_wvalid  => s_axi_wvalid,
            s_axi_wready  => s_axi_wready,
            s_axi_bresp   => s_axi_bresp,
            s_axi_bvalid  => s_axi_bvalid,
            s_axi_bready  => s_axi_bready,
            s_axi_araddr  => s_axi_araddr,
            s_axi_arprot  => s_axi_arprot,
            s_axi_arvalid => s_axi_arvalid,
            s_axi_arready => s_axi_arready,
            s_axi_rdata   => s_axi_rdata,
            s_axi_rresp   => s_axi_rresp,
            s_axi_rvalid  => s_axi_rvalid,
            s_axi_rready  => s_axi_rready,
            s_axis_tready => s_axis_tready,
            s_axis_tdata  => s_axis_tdata,
            s_axis_tstrb  => s_axis_tstrb,
            s_axis_tlast  => s_axis_tlast,
            s_axis_tvalid => s_axis_tvalid,
            m_axis_tvalid => m_axis_tvalid,
            m_axis_tdata  => m_axis_tdata,
            m_axis_tstrb  => m_axis_tstrb,
            m_axis_tlast  => m_axis_tlast,
            m_axis_tready => m_axis_tready
        );

    -- Stimulus process
    stim_proc: process
    begin
        -- Reset
        rstn_i <= '0';
        wait for CLK_PERIOD * 5;
        rstn_i <= '1';
        wait for CLK_PERIOD * 2;

        -- Configure kernel weights through registers
        for i in 0 to KERNEL_SIZE*KERNEL_SIZE-1 loop
            write_register(clk_i, s_axi_awaddr, s_axi_awvalid, s_axi_wdata,
                         s_axi_wvalid, s_axi_bready, i*(DATA_WIDTH/8),
                         KERNEL_DATA(i));
        end loop;

        wait for CLK_PERIOD * 10;

        -- Stream input data
        for i in 0 to INPUT_SIZE*INPUT_SIZE-1 loop
            wait until rising_edge(clk_i) and s_axis_tready = '1';
            
            s_axis_tdata <= INPUT_DATA(i);
            s_axis_tvalid <= '1';
            
            if i = (INPUT_SIZE*INPUT_SIZE-1) then
                s_axis_tlast <= '1';
            end if;
            
            wait for CLK_PERIOD;
        end loop;

        s_axis_tvalid <= '0';
        s_axis_tlast <= '0';

        -- Wait for processing completion
        wait for CLK_PERIOD * 50;
        
        sim_done <= true;
        wait;
    end process;

    -- Monitor process for outputs
    monitor_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if m_axis_tvalid = '1' and m_axis_tready = '1' then
                report "Output data: " & real'image(to_real(m_axis_tdata));
            end if;
        end if;
    end process;

end architecture;