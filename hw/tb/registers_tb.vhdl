library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity registers_tb is
end registers_tb;

architecture sim of registers_tb is

    -- Constants
    constant CLK_PERIOD    : time    := 10 ns;
    constant DATA_WIDTH    : integer := 32;
    constant ADDR_WIDTH    : integer := 8;
    constant NUM_REGISTERS : integer := 9;
   
    -- Components
    component registers is
        generic (
            DATA_WIDTH	  : integer	:= 32;
            ADDR_WIDTH	  : integer	:= 8;
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
    signal clk_i     : std_logic := '0';
    signal rstn_i    : std_logic := '0';
    signal awaddr_i  : std_logic_vector(ADDR_WIDTH-1 downto 0) := (others => '0');
    signal awprot_i  : std_logic_vector(2 downto 0) := (others => '0');
    signal awvalid_i : std_logic := '0';
    signal awready_o : std_logic;
    signal wdata_i   : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal wstrb_i   : std_logic_vector((DATA_WIDTH/8)-1 downto 0) := (others => '1');
    signal wvalid_i  : std_logic := '0';
    signal wready_o  : std_logic;
    signal bresp_o   : std_logic_vector(1 downto 0);
    signal bvalid_o  : std_logic;
    signal bready_i  : std_logic := '0';
    signal araddr_i  : std_logic_vector(ADDR_WIDTH-1 downto 0) := (others => '0');
    signal arprot_i  : std_logic_vector(2 downto 0) := (others => '0');
    signal arvalid_i : std_logic := '0';
    signal arready_o : std_logic;
    signal rdata_o   : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal rresp_o   : std_logic_vector(1 downto 0);
    signal rvalid_o  : std_logic;
    signal rready_i  : std_logic := '0';
   
    -- Simulation control
    signal sim_done : boolean := false;
   
    -- Helper function for displaying values
    function to_string(slv : std_logic_vector) return string is
        variable str : string(1 to slv'length) := (others => '0');
    begin
        for i in slv'length downto 1 loop
            case slv(i-1) is
                when '0' => str(slv'length-i+1) := '0';
                when '1' => str(slv'length-i+1) := '1';
                when others => str(slv'length-i+1) := 'X';
            end case;
        end loop;
        return str;
    end function;
   
    -- Helper procedure for writing to register
    procedure write_register(
        signal clk      : in  std_logic;
        signal awaddr   : out std_logic_vector(ADDR_WIDTH-1 downto 0);
        signal awvalid  : out std_logic;
        signal wdata    : out std_logic_vector(DATA_WIDTH-1 downto 0);
        signal wvalid   : out std_logic;
        signal bready   : out std_logic;
        addr            : in  integer;
        data            : in  std_logic_vector(DATA_WIDTH-1 downto 0)
        ) is
            constant TIMEOUT : time := 1 us;
            variable timeout_count : time := 0 ns;
        begin
            -- Set up address and data
            report "Write procedure: Setting up signals";
            awaddr <= std_logic_vector(to_unsigned(addr, ADDR_WIDTH));
            wdata <= data;
            awvalid <= '1';
            wvalid <= '1';
            bready <= '1';
            wait until rising_edge(clk);
            
            -- Wait for ready signals with timeout
            while (not (awready_o = '1' and wready_o = '1')) and (timeout_count < TIMEOUT) loop
                wait until rising_edge(clk);
                timeout_count := timeout_count + CLK_PERIOD;
            end loop;
            
            if timeout_count >= TIMEOUT then
                report "Write procedure: Timeout waiting for ready signals" severity warning;
                return;
            end if;
        
            report "Write procedure: Got ready signals";
            wait until rising_edge(clk);
            
            -- Clear signals
            awvalid <= '0';
            wvalid <= '0';
            
            -- Wait for response with timeout
            timeout_count := 0 ns;
            while (not bvalid_o = '1') and (timeout_count < TIMEOUT) loop
                wait until rising_edge(clk);
                timeout_count := timeout_count + CLK_PERIOD;
            end loop;
            
            if timeout_count >= TIMEOUT then
                report "Write procedure: Timeout waiting for write response" severity warning;
                return;
            end if;
        
            report "Write procedure: Transaction complete";
            wait until rising_edge(clk);
            bready <= '0';
        end procedure;
   
    -- Helper procedure for reading from register
    procedure read_register(
        signal clk      : in  std_logic;
        signal araddr   : out std_logic_vector(ADDR_WIDTH-1 downto 0);
        signal arvalid  : out std_logic;
        signal rready   : out std_logic;
        addr            : in  integer
    ) is
    begin
        -- Set up address
        araddr <= std_logic_vector(to_unsigned(addr, ADDR_WIDTH));
        arvalid <= '1';
        rready <= '1';
        wait until rising_edge(clk);
        
        -- Wait for ready signal
        wait until arready_o = '1';
        wait until rising_edge(clk);
        
        -- Clear valid signal
        arvalid <= '0';
        
        -- Wait for data
        wait until rvalid_o = '1';
        wait until rising_edge(clk);
        rready <= '0';
    end procedure;
   
begin
    
   -- Clock generation
   clk_gen: process
   begin
       while not sim_done loop
           clk_i <= '0';
           wait for CLK_PERIOD/2;
           clk_i <= '1';
           wait for CLK_PERIOD/2;
       end loop;
       wait;
   end process;
   
   -- DUT instantiation
   DUT: registers
       generic map (
           DATA_WIDTH    => DATA_WIDTH,
           ADDR_WIDTH    => ADDR_WIDTH,
           NUM_REGISTERS => NUM_REGISTERS
       )
       port map (
           clk_i     => clk_i,
           rstn_i    => rstn_i,
           awaddr_i  => awaddr_i,
           awprot_i  => awprot_i,
           awvalid_i => awvalid_i,
           awready_o => awready_o,
           wdata_i   => wdata_i,
           wstrb_i   => wstrb_i,
           wvalid_i  => wvalid_i,
           wready_o  => wready_o,
           bresp_o   => bresp_o,
           bvalid_o  => bvalid_o,
           bready_i  => bready_i,
           araddr_i  => araddr_i,
           arprot_i  => arprot_i,
           arvalid_i => arvalid_i,
           arready_o => arready_o,
           rdata_o   => rdata_o,
           rresp_o   => rresp_o,
           rvalid_o  => rvalid_o,
           rready_i  => rready_i
       );
       
   -- Stimulus process
    stim_proc: process
    begin
        -- Initial reset
        report "Starting reset sequence";
        rstn_i <= '0';
        wait for CLK_PERIOD * 5;
        rstn_i <= '1';
        wait for CLK_PERIOD * 2;
        report "Reset sequence complete";
        
        -- Write to first register (reg0)
        report "Writing to register 0";
        write_register(clk_i, awaddr_i, awvalid_i, wdata_i, wvalid_i, bready_i,
                      0, x"12345678");
        report "Write to register 0 complete";
        wait for CLK_PERIOD * 2;
        
        -- Read from first register
        report "Reading from register 0";
        read_register(clk_i, araddr_i, arvalid_i, rready_i, 0);
        
        -- Report read value
        if rvalid_o = '1' then
            report "Read value (reg0): " & integer'image(to_integer(unsigned(rdata_o)));
        end if;
       
       wait for CLK_PERIOD * 2;
       
       -- Write to last register (reg8)
       write_register(clk_i, awaddr_i, awvalid_i, wdata_i, wvalid_i, bready_i,
                     32, x"87654321");
       wait for CLK_PERIOD * 2;
       
       -- Read from last register
       read_register(clk_i, araddr_i, arvalid_i, rready_i, 32);
       
       -- Report read value
       if rvalid_o = '1' then
           report "Read value: " & to_string(rdata_o);
       end if;
       
       wait for CLK_PERIOD * 2;
       
       -- End simulation
       wait for CLK_PERIOD * 10;
       sim_done <= true;
       wait;
   end process;

end architecture;