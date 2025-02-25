library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity fma_tb is
end fma_tb;

architecture sim of fma_tb is

    -- Constants
    constant CLK_PERIOD      : time    := 10 ns;
    constant DATA_WIDTH      : integer := 32;
    constant FRACTIONAL_BITS : integer := 12;

    -- Components
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

    -- Clock and Reset
    signal clk_i : std_logic := '0';
    signal rst_i : std_logic := '1';
    signal cen_i : std_logic := '0';

    -- DUT Signals
    signal a_i : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal b_i : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal c_i : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal y_o : std_logic_vector(DATA_WIDTH-1 downto 0);

    -- Helper Functions
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
    clk_i <= not clk_i after CLK_PERIOD/2;

    -- Instantiation
    fma_inst: fma
    generic map (
        DATA_WIDTH      => DATA_WIDTH,
        FRACTIONAL_BITS => FRACTIONAL_BITS
    )
    port map (
        clk_i => clk_i,
        rst_i => rst_i,
        cen_i => cen_i,
        a_i => a_i,
        b_i => b_i,
        c_i => c_i,
        y_o => y_o
    );

    -- Stimulus process
    stim_proc: process
    begin
        wait for CLK_PERIOD/2;
        
        -- Reset sequence
        rst_i <= '1';
        cen_i <= '0';
        wait for CLK_PERIOD * 2;
        rst_i <= '0';
        wait for CLK_PERIOD;

        -- Enable
        cen_i <= '1';
        
        a_i <= to_fixed(1.5);
        b_i <= to_fixed(2.0);
        c_i <= to_fixed(0.5);
        wait for CLK_PERIOD;

        a_i <= to_fixed(1.0);
        b_i <= to_fixed(1.0);
        c_i <= to_fixed(1.0);
        wait for CLK_PERIOD;

        a_i <= to_fixed(-2.5);
        b_i <= to_fixed(1.5);
        c_i <= to_fixed(0.0);
        wait for CLK_PERIOD;

        a_i <= to_fixed(-0.5);
        b_i <= to_fixed(-0.5);
        c_i <= to_fixed(0.25);
        wait for CLK_PERIOD;
       
        a_i <= to_fixed(149.2);
        b_i <= to_fixed(149.1);
        c_i <= to_fixed(149.3);
        wait for CLK_PERIOD;
        
        a_i <= to_fixed(259.9);
        b_i <= to_fixed(-149.5);
        c_i <= to_fixed(-550.4);
        wait for CLK_PERIOD;
        
        a_i <= to_fixed(-220.2);
        b_i <= to_fixed(-331.3);
        c_i <= to_fixed(5000.1);
        wait for CLK_PERIOD;
        
        -- Disable computation
        cen_i <= '0';
        wait for CLK_PERIOD * 2;

        wait;
    end process;

end architecture;