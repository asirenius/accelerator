library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pooler is
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
end entity pooler;

architecture rtl of pooler is

    -- Constants
    constant MIN_VALUE : std_logic_vector(DATA_WIDTH-1 downto 0) := (DATA_WIDTH-1 => '1', others => '0'); -- Minimum value

    -- Internal Bus
    type input_t is array (0 to POOL_SIZE) of std_logic_vector(DATA_WIDTH-1 downto 0);
    signal input : input_t;
    
    type result_t is array (0 to POOL_SIZE-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
    signal result : result_t;

    -- Registers
    signal data  : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal valid : std_logic;
    signal last  : std_logic;

    -- Counters
    signal row_counter : unsigned(31 downto 0);
    signal col_counter : unsigned(31 downto 0);
    
    -- Signals
    signal ready  : std_logic;
    signal enable : std_logic;

begin

    -- Set Initial Value
    input(0) <= MIN_VALUE;

    -- Configure Signals
    ready  <= ready_i or not valid;
    enable <= ready and valid_i;

    -- Generate Pipeline
    gen_pipeline: for stage in 0 to POOL_SIZE-1 generate

        -- Constants
        constant NUM_CRS : integer := POOL_SIZE-1;

        -- Compute Registers
        type crs_t is array (0 to NUM_CRS-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
        signal crs : crs_t;

        -- MAX Procedure
        procedure max(
            signal a_i : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            signal b_i : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            signal y_o : out std_logic_vector(DATA_WIDTH-1 downto 0)) is
        begin
            if signed(a_i) > signed(b_i) then
                y_o <= a_i;
            else
                y_o <= b_i;
            end if;
        end procedure;

    begin

        -- Compute Process
        compute: process(clk_i)
        begin
            if rising_edge(clk_i) then
                if rst_i = '1' then
                    for i in 0 to NUM_CRS-1 loop
                        crs(i) <= (others => '0');
                    end loop;
                else
                    if enable = '1' then
                        max(data_i, input(stage), crs(0)); -- Initial stage
                        for i in 1 to NUM_CRS-1 loop 
                            max(data_i, crs(i-1), crs(i)); -- Middle stages
                        end loop;
                    end if;
                end if;
            end if;
        end process compute;

        -- Output Stage
        max(data_i, crs(NUM_CRS-1), result(stage));

    end generate;
    
    -- Generate Shift Registers
    gen_srs: for stage in 0 to POOL_SIZE-2 generate
   
        -- Constants
        constant NUM_SRS : integer := INPUT_SIZE-POOL_SIZE+1;
        
        -- Shift Registers
        type srs_t is array (0 to NUM_SRS-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
        signal srs : srs_t;
        
    begin
        
        -- Shift Register Process
        sr: process(clk_i)
        begin
            if rising_edge(clk_i) then
                if rst_i = '1' then
                    for i in 0 to NUM_SRS-1 loop
                        srs(i) <= (others => '0');
                    end loop;
                else
                    if enable = '1' then
                        srs(0) <= result(stage);
                        for i in 1 to NUM_SRS-1 loop
                            srs(i) <= srs(i-1);
                        end loop;
                    end if;
                end if;
            end if;
        end process sr;
        
        -- Output Assignment
        input(stage+1) <= srs(NUM_SRS-1);
        
    end generate;

    -- Controller
    ctrl: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                data        <= (others => '0');
                valid       <= '0';
                last        <= '0';
                row_counter <= (others => '0');
                col_counter <= (others => '0');
            else
                if enable = '1' then -- Valid 
                
                    -- Defaults
                    data  <= result(POOL_SIZE-1);
                    valid <= '0';
                    last  <= '0';

                    -- Update counters
                    col_counter <= col_counter + 1;
                    if (col_counter = INPUT_SIZE-1) then
                        row_counter <= row_counter + 1;
                        col_counter <= (others => '0');
                    end if;

                    -- Set valid
                    if ((row_counter - 1) mod POOL_SIZE = 0 and (col_counter - 1) mod POOL_SIZE = 0) then
                        valid <= '1';
                    end if;
            
                    -- Set last and end computation
                    if (row_counter = INPUT_SIZE - 1 and col_counter = INPUT_SIZE - 1) then
                        last  <= '1';
                        row_counter <= (others => '0');
                        col_counter <= (others => '0');
                    end if;
                
                elsif ready_i = '1' then
                    data  <= (others => '0');
                    valid <= '0';
                    last  <= '0';
                end if;

            end if;
        end if;
    end process ctrl;
    
    -- Output Assignements
    data_o  <= data;
    valid_o <= valid;
    last_o  <= last;
    ready_o <= ready;
    
end architecture rtl;