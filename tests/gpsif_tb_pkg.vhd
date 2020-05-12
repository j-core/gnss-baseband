library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_textio.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use std.textio.all;

use work.cpu2j0_pack.all;
use work.gpsif_pack.all;
use work.gpsif_sub_pack.all;
use work.test_pkg.all;

package gpsif_tb_pack is
    procedure chk_dma_req(dma : dma_req_t);
    procedure check_equal(
      signal clk  : in  std_logic;
      signal db_o : in  cpu_data_i_t;
      signal db_i : out cpu_data_o_t;
      constant val,ch,ofs : integer;
      constant typ        : string);
    procedure check_channel(
      signal clk  : in  std_logic;
      signal db_o : in  cpu_data_i_t;
      signal db_i : out cpu_data_o_t;
      constant ch,ei,eq,pi,pq,li,lq : integer);
end package;

package body gpsif_tb_pack is

  procedure chk_dma_req(dma : dma_req_t) is
      variable LI : line;
  begin
      if dma.req(6) = '1' then
          write(LI, "DMA req. of ch #" & integer'image(to_integer(unsigned(dma.req(5 downto 0)))));
          writeline(output, LI);
      end if;
  end procedure;

  procedure check_equal(
    signal clk  : in  std_logic;
    signal db_o : in  cpu_data_i_t;
    signal db_i : out cpu_data_o_t;
    constant val,ch,ofs : integer;
    constant typ        : string) is
  begin
    db_i <= ('1',(std_logic_vector(to_unsigned(ch*8 + ofs,30)) & "00") or x"ABCC0100",'1','0',x"F",x"00000000");
    wait until clk = '1' and clk'event and db_o.ack = '1';
    test_equal(to_integer(signed(db_o.d)),val, typ & "(" & integer'image(ch) & ")");
  end procedure;

  procedure check_channel(
    signal clk  : in  std_logic;
    signal db_o : in  cpu_data_i_t;
    signal db_i : out cpu_data_o_t;
    constant ch,ei,eq,pi,pq,li,lq : integer) is
  begin
    check_equal(clk,db_o,db_i,ei,ch,0,"E_I");
    check_equal(clk,db_o,db_i,eq,ch,1,"E_Q");
    check_equal(clk,db_o,db_i,pi,ch,2,"P_I");
    check_equal(clk,db_o,db_i,pq,ch,3,"P_Q");
    check_equal(clk,db_o,db_i,li,ch,4,"L_I");
    check_equal(clk,db_o,db_i,lq,ch,5,"L_Q");
    db_i <= NULL_DATA_O; wait until clk = '1' and clk'event;
  end procedure;

end gpsif_tb_pack;
