library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ring_bus_pack.all;

package rbus_pack is
-- added by FA
constant RNG_CH_DSP : integer := 0;
constant RNG_CH_GPS : integer := 1;
type rbus_dev_o_t is record
  d : std_logic_vector(8 downto 0);
  v,bsy : boolean;
  ch : integer range 0 to 8;
end record;
type rbus_dev_i_t is record
  d : std_logic_vector(8 downto 0);
  v,ack : boolean;
end record;
component rbus_adp is
  generic (OWN_CH : integer := RNG_CH_GPS); -- default
  port (clk    : in  std_logic;
        rst    : in  std_logic;
--        sw_rst : in  boolean;
        ring_i : in  rbus_9b;
        ring_o : out rbus_9b;
        dev_o  : in  rbus_dev_o_t; -- from device
        dev_i  : out rbus_dev_i_t); --  to device
end component;

end package;
