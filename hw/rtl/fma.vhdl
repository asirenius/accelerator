library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fma is
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
end entity fma;

architecture dataflow of fma is

    -- Constants
    constant TRUNCATE_MSB : integer := DATA_WIDTH + FRACTIONAL_BITS - 1;
    constant TRUNCATE_LSB : integer := FRACTIONAL_BITS;

    -- Registers
    signal product : signed(2*DATA_WIDTH-1 downto 0);
    
    -- Signals
    signal sum : signed(2*DATA_WIDTH-1 downto 0);

begin

    -- Compute Process
    calc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                product <= (others => '0');
            else
                if cen_i = '1' then

                    -- Multiplication
                    product <= signed(a_i) * signed(b_i);

                end if;
            end if;
        end if;
    end process calc;

    -- Addition
    sum <= product + shift_left(resize(signed(c_i), 2*DATA_WIDTH), FRACTIONAL_BITS);
    
    -- Truncation
    y_o <= std_logic_vector(sum(TRUNCATE_MSB downto TRUNCATE_LSB));

end architecture dataflow;