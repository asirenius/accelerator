library ieee;
use ieee.std_logic_1164.all;

entity relu is
    generic (
        DATA_WIDTH : integer := 32
    );
    port (
        data_i : in std_logic_vector(DATA_WIDTH-1 downto 0);
        data_o : out std_logic_vector(DATA_WIDTH-1 downto 0)
    );
end entity relu;

architecture dataflow of relu is
begin

    data_o <= data_i when (data_i(DATA_WIDTH-1) = '0') else (others => '0'); 

end architecture dataflow;
