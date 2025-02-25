library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity convolver_tb is
end convolver_tb;

architecture sim of convolver_tb is
    
    -- Constants
    constant CLK_PERIOD      : time    := 40 ns;
    constant INPUT_SIZE      : integer := 6;
    constant KERNEL_SIZE     : integer := 3;
    constant STRIDE          : integer := 1;
    constant DATA_WIDTH      : integer := 32;
    constant FRACTIONAL_BITS : integer := 12;
    
    -- Components
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

    -- Signals
    signal clk_i    : std_logic := '0';
    signal rst_i    : std_logic := '0';
    signal kernel_i : std_logic_vector((KERNEL_SIZE*KERNEL_SIZE*DATA_WIDTH)-1 downto 0) := (others => '0');
    
    -- Input Stream
    signal data_i   : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal valid_i  : std_logic := '0';
    signal ready_o  : std_logic;
    signal last_i   : std_logic := '0';
    
    -- Output Stream
    signal data_o   : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal valid_o  : std_logic;
    signal ready_i  : std_logic := '1';  -- Consumer always ready in this test
    signal last_o   : std_logic;
    
    signal rand_ready : std_logic_vector(7 downto 0) := (others => '0');
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
    
    -- Instantiation
    DUT: convolver
        generic map (
            INPUT_SIZE      => INPUT_SIZE,
            KERNEL_SIZE     => KERNEL_SIZE,
            STRIDE         => STRIDE,
            DATA_WIDTH     => DATA_WIDTH,
            FRACTIONAL_BITS => FRACTIONAL_BITS
        )
        port map (
            clk_i    => clk_i,
            rst_i    => rst_i,
            kernel_i => kernel_i,
            data_i   => data_i,
            valid_i  => valid_i,
            ready_o  => ready_o,
            last_i   => last_i,
            data_o   => data_o,
            valid_o  => valid_o,
            ready_i  => ready_i,
            last_o   => last_o
        );

    -- Stimulus process
    stim_proc: process
        variable input_count : integer := 0;
    begin
        -- Initial conditions
        rst_i   <= '0';
        valid_i <= '0';
        last_i  <= '0';
        wait for 100 ns;
        
        -- Reset
        rst_i <= '1';
        wait for 50 ns;
        rst_i <= '0';
        wait for 10 ns;
        
        -- Initialize kernel weights
        for i in 0 to KERNEL_SIZE*KERNEL_SIZE-1 loop
            kernel_i((i+1)*DATA_WIDTH-1 downto i*DATA_WIDTH) <= to_fixed(real(i));
        end loop;
        
        -- Stream input data
        for row in 0 to INPUT_SIZE-1 loop
            for col in 0 to INPUT_SIZE-1 loop
                -- Wait for ready
                wait until rising_edge(clk_i) and ready_o = '1';
                
                -- Set data
                data_i  <= to_fixed(real(input_count));
                valid_i <= '1';
                
                -- Set last flag on final input
                if (row = INPUT_SIZE-1) and (col = INPUT_SIZE-1) then
                    last_i <= '1';
                end if;
                
                input_count := input_count + 1;
            end loop;
        end loop;
        
        -- Reset input counter
        input_count := 0;
        
        -- Clear valid after last transfer
        wait until rising_edge(clk_i) and ready_o = '1';
        valid_i <= '0';
        last_i  <= '0';
        
        -- Wait for completion
        wait for CLK_PERIOD * (KERNEL_SIZE*KERNEL_SIZE + 10);
        
        -- Stream input data
        for row in 0 to INPUT_SIZE-1 loop
            for col in 0 to INPUT_SIZE-1 loop
                -- Wait for ready
                wait until rising_edge(clk_i) and ready_o = '1';
                
                -- Set data
                data_i  <= to_fixed(real(input_count));
                valid_i <= '1';
                
                -- Set last flag on final input
                if (row = INPUT_SIZE-1) and (col = INPUT_SIZE-1) then
                    last_i <= '1';
                end if;
                
                input_count := input_count + 1;
            end loop;
        end loop;
        
        -- Clear valid after last transfer
        wait until rising_edge(clk_i) and ready_o = '1';
        valid_i <= '0';
        last_i  <= '0';
        
        -- Wait for completion
        wait for CLK_PERIOD * (KERNEL_SIZE*KERNEL_SIZE + 10);       
 
        sim_done <= true;
        wait;
    end process;
    
    -- Monitor process
    monitor_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if valid_o = '1' and ready_i = '1' then
                report "Valid output: " & real'image(to_real(data_o));
            end if;
            
            if last_o = '1' and valid_o = '1' and ready_i = '1' then
                report "Convolution complete";
            end if;
        end if;
    end process;
    
    backpressure_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                ready_i    <= '0';
                rand_ready <= (others => '0');
            else
                rand_ready <= rand_ready(6 downto 0) & (rand_ready(7) xnor rand_ready(5));
                ready_i    <= rand_ready(0);
            end if;
        end if;
    end process;

end architecture sim;