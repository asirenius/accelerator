library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity relu_tb is
end entity relu_tb;

architecture sim of relu_tb is

    -- Components
    component relu is
        generic (
            DATA_WIDTH : integer := 32
        );
        port (
            data_i : in std_logic_vector(DATA_WIDTH-1 downto 0);
            data_o : out std_logic_vector(DATA_WIDTH-1 downto 0)
        );
    end component relu;

    -- Signals
    signal data_i : std_logic_vector(31 downto 0);
    signal data_o : std_logic_vector(31 downto 0);
    
    -- Procedure to check values
    procedure check(
        signal input : out std_logic_vector(31 downto 0);
        signal output : in  std_logic_vector(31 downto 0);
        test_input    : in integer;
        test_name     : in string
    ) is
        variable expected : std_logic_vector(31 downto 0);
    begin
        -- Set input
        input <= std_logic_vector(to_signed(test_input, 32));
        
        -- Calculate expected output
        if test_input < 0 then
            expected := (others => '0');
        else
            expected := std_logic_vector(to_signed(test_input, 32));
        end if;
        
        -- Wait for propagation
        wait for 10 ns;
        
        -- Check result
        assert output = expected
            report test_name & " failed!" & 
                  " Input: " & integer'image(test_input) &
                  " Expected: " & integer'image(to_integer(signed(expected))) &
                  " Got: " & integer'image(to_integer(signed(output)))
            severity error;
    end procedure;

    type test_array is array (natural range <>) of integer;
    constant test_values : test_array := (0, 42, -42, 2147483647, -2147483648, 1, -1);

begin

    -- Instantiation
    DUT: relu
        port map (
            data_i => data_i,
            data_o => data_o
        );
        
    -- Stimulus process
    stim_proc: process
    begin
        -- Loop through test values
        for i in test_values'range loop
            check(data_i, data_o, test_values(i), "Test case " & integer'image(i));
            wait for 10 ns;
        end loop;
       
        -- End of simulation
        wait;
    end process;

end architecture sim;