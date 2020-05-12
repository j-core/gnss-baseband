library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.fixed_pkg.all;
use work.rf_pack.all;
use work.bist_pack.all;
use work.cpu2j0_pack.all;
use work.ring_bus_pack.all;
use work.rbus_pack.all;

package gpsif_sub_pack is

-- Copy from dma_pkg.vhd, and change name to avoid conflict
-- Direct reference by "use work.dma_pack.all;" causes error.
constant DMA_CH_NUM_LOG : natural := 6;
type dma_req_t is record
  req : std_logic_vector(DMA_CH_NUM_LOG downto 0);
end record;

constant NULL_DMA_REQ : dma_req_t := ( req => (others => '0') );

type blgps_t is record
  en    : std_logic;
  a     : std_logic_vector( 5 downto 0);
  d     : std_logic_vector( 7 downto 0);
  tick  : std_logic;
end record;

constant NULL_BLGPS : blgps_t := ( en => '0', a => (others => '0'),
  d => x"00", tick => '0' );

end package;

package body gpsif_sub_pack is

end gpsif_sub_pack;
