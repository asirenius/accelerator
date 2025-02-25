library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity convolver is
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
end entity convolver;

architecture rtl of convolver is

    -- Functions
    function to_std_logic(b : boolean) return std_logic is
    begin
        if b then
            return '1';
        else
            return '0';
        end if;
    end function;
  
    -- Componenets
    component fma is
        generic (
            DATA_WIDTH      : integer := 32;
            FRACTIONAL_BITS : integer := 12
        );
        port (
            clk_i : in  std_logic;
            rst_i : in  std_logic;
            cen_i : in  std_logic;
            a_i   : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            b_i   : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            c_i   : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            y_o   : out std_logic_vector(DATA_WIDTH-1 downto 0)
        );
    end component fma;
  
    -- Types
    type weights_t is array (0 to KERNEL_SIZE*KERNEL_SIZE-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
    signal weights : weights_t;
    
    -- States
    type state_t is (PROCESSING, DONE);
    signal state : state_t;

    -- Internal Bus
    type input_t is array (0 to KERNEL_SIZE-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
    signal input : input_t;
    
    type result_t is array (0 to KERNEL_SIZE-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
    signal result : result_t;

    -- Registers
    signal valid : std_logic;
    signal last  : std_logic;

    -- Counters
    signal row_counter : unsigned(31 downto 0);
    signal col_counter : unsigned(31 downto 0);
    
    -- Signals
    signal enable : std_logic;
    signal ready  : std_logic;

begin
    
    -- Configure weights
    weights_gen: for i in 0 to KERNEL_SIZE*KERNEL_SIZE-1 generate
        weights(i) <= kernel_i((i + 1)*DATA_WIDTH-1 downto (i)*DATA_WIDTH);
    end generate;

    -- Set Initial Value
    input(0) <= (others => '0');

    -- Configure Internal Signals
    ready  <= ready_i or not valid;
    enable <= ready and valid_i;

    -- Generate Pipeline
    gen_pipeline: for stage in 0 to KERNEL_SIZE-1 generate

        -- Constants
        constant NUM_CRS : integer := KERNEL_SIZE-1;
        constant TRUNCATE_MSB : integer := DATA_WIDTH + FRACTIONAL_BITS - 1;
        constant TRUNCATE_LSB : integer := FRACTIONAL_BITS;

        -- Compute Registers
        type crs_t is array (0 to NUM_CRS-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
        signal crs : crs_t;
        
        -- Signals
        type y_t is array (0 to KERNEL_SIZE-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
        signal y : y_t;

    begin

        -- Generate FMAs
        fma_gen: for i in 0 to KERNEL_SIZE-1 generate

            -- First Stage
            f_gen: if i = 0 generate
                f_fma_inst: fma
                    generic map (
                        DATA_WIDTH      => DATA_WIDTH,
                        FRACTIONAL_BITS => FRACTIONAL_BITS
                    )
                    port map (
                        clk_i => clk_i,
                        rst_i => rst_i,
                        cen_i => enable,
                        a_i   => data_i,
                        b_i   => weights(KERNEL_SIZE*stage+i),
                        c_i   => input(stage),
                        y_o   => y(i)
                    );
            end generate;

            -- Middle Stages
            m_gen: if i > 0 and i < KERNEL_SIZE-1 generate
                m_fma_inst: fma
                    generic map (
                        DATA_WIDTH      => DATA_WIDTH,
                        FRACTIONAL_BITS => FRACTIONAL_BITS
                    )
                    port map (
                        clk_i => clk_i,
                        rst_i => rst_i,
                        cen_i => enable,
                        a_i   => data_i,
                        b_i   => weights(KERNEL_SIZE*stage+i),
                        c_i   => crs(i-i),
                        y_o   => y(i)
                    );
            end generate;     

            -- Last Stage
            l_gen: if i = KERNEL_SIZE-1 generate
                l_fma_inst: fma
                    generic map (
                        DATA_WIDTH      => DATA_WIDTH,
                        FRACTIONAL_BITS => FRACTIONAL_BITS
                    )
                    port map (
                        clk_i => clk_i,
                        rst_i => rst_i,
                        cen_i => enable,
                        a_i   => data_i,
                        b_i   => weights(KERNEL_SIZE*(stage+1)-1),
                        c_i   => crs(i-1),
                        y_o   => y(i)
                    );
            end generate;

        end generate;

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
                        for i in 0 to NUM_CRS-1 loop
                            crs(i) <= y(i);                           
                        end loop;
                    end if;
                end if;
            end if;
        end process compute;

        -- Output stage
        result(stage) <= y(KERNEL_SIZE-1);

    end generate;

    -- Generate Shift Registers
    gen_srs: for stage in 0 to KERNEL_SIZE-2 generate

        -- Constants
        constant NUM_SRS : integer := INPUT_SIZE-KERNEL_SIZE+1;
        
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
                valid       <= '0';
                last        <= '0';
                row_counter <= (others => '0');
                col_counter <= (others => '0');
            else
                if enable = '1' then
            
                    -- Defaults
                    valid <= '0';
                    last  <= '0';
    
                    -- Update counter
                    col_counter <= col_counter + 1;
                    if (col_counter = INPUT_SIZE-1) then
                        row_counter <= row_counter + 1;
                        col_counter <= (others => '0');
                    end if;
    
                    -- Set valid
                    if (row_counter >= KERNEL_SIZE-1 and col_counter >= KERNEL_SIZE-1 and (row_counter - KERNEL_SIZE + 1) mod STRIDE = 0 and (col_counter - KERNEL_SIZE + 1) mod STRIDE = 0) then
                        valid <= '1';
                    end if;
            
                    -- Set last
                    if (row_counter = INPUT_SIZE - STRIDE and col_counter = INPUT_SIZE - STRIDE) then
                        last  <= '1';
                    end if;
    
                    -- End computation
                    if (row_counter = INPUT_SIZE-1 and col_counter = INPUT_SIZE-1) then
                        row_counter <= (others => '0');
                        col_counter <= (others => '0');
                    end if;
                    
                elsif ready_i = '1' then
                    valid <= '0';
                    last  <= '0';
                end if;
                
            end if;
        end if;
    end process ctrl;

    -- Output Process (Compensate for pipeline delay)
    process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                data_o  <= (others => '0');
                valid_o <= '0';
                last_o  <= '0';
            else
                if enable = '1' or ready_i = '1' then
                    data_o  <= result(KERNEL_SIZE-1);
                    valid_o <= valid;
                    last_o  <= last;
                end if;
            end if;
        end if;        
    end process;

    -- Output Assignements
    ready_o <= ready;

end architecture rtl;