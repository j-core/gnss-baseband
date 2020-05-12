library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_textio.all;
use ieee.numeric_std.all;
use std.textio.all;

use work.cpu2j0_pack.all;
use work.ring_bus_pack.all;
use work.test_pkg.all;
use work.bist_pack.all;
use work.gpsif_pack.all;
use work.gpsif_sub_pack.all;
use work.gpsif_tb_pack.all;

entity gpsif_tb_gpsob is
end entity;

architecture tb of gpsif_tb_gpsob is
  constant clk_tgl       : time    :=  5.71 ns; -- for 87.5 MHz
  constant gps_tgl       : time    := 30.55 ns; -- for 16.368 MHz
  constant ppsdds_tgl    : time    := 30000.0 ns; -- actual 1Hz, accelating test
  constant INTERVAL      : natural := 4; -- 32b/4cycles = 1Byte/cycle is the maximum input speed for gpsif
  constant exe_cycles    : natural := 250000;   -- running 2ms @125MHz
  constant ANGLE_INI_OLD : boolean := false;
  constant GPSIF_NC      : natural := 5;
  constant ACQ_TEST      : boolean := false;
  constant SKIP_TEST     : boolean := false;

  signal gps_clk         : std_logic := '0';
  signal gps_d           : std_logic_vector(1 downto 0) := "00";
  signal clk             : std_logic := '0';
  signal rst             : std_logic := '1';
  signal blgps           : blgps_t   := NULL_BLGPS;
  signal ppsdds          : std_logic := '0';
  signal intrpt          : std_logic := '0';
  shared variable ENDSIM : boolean   := false;

  signal dma  : dma_req_t;
  signal db_i : cpu_data_o_t := NULL_DATA_O;
  signal db_o : cpu_data_i_t;
  signal i_bl_control : integer;

begin
    clk_gen : process
    begin
      if ENDSIM = false then
        clk <= '0'; wait for clk_tgl;
        clk <= '1'; wait for clk_tgl;
      else          wait;
      end if;
    end process;

    gps_clk_gen : process
    begin
      if ENDSIM = false then
        gps_clk <= '0'; wait for gps_tgl;
        gps_clk <= '1'; wait for gps_tgl;
      else              wait;
      end if;
    end process;

    ppsdds_gen : process
    begin
      if ENDSIM = false then
        ppsdds <= '0'; wait for ppsdds_tgl;
        ppsdds <= '1'; wait for ppsdds_tgl;
      else             wait;
      end if;
    end process;

  g : configuration work.gpsif_top_sim
    generic map ( GPSIF_NC => GPSIF_NC,
             ANGLE_INI_OLD => ANGLE_INI_OLD )
    port map (
      clk     => clk,
      rst     => rst,
      gps_clk => gps_clk,
      gps_d   => gps_d,
      ppsdds  => ppsdds,
      blgps   => blgps,
      dma     => dma,
      intrpt  => intrpt,
      bi      => BIST_SCAN_NOP,
      bo      => open,
      ring_i  => RBUS_IDLE_9B,
      ring_o  => open,
      db_i => db_i,
      db_o => db_o);


  data_input : process
    file FI        : TEXT open read_mode is "tests/input.txt";
    variable LI    : line;
    variable input : std_logic_vector(1 downto 0);
  begin
    -- gps signal input
    input_loop: while true loop
        if endfile(FI) then
            exit input_loop;
        end if;
        readline(FI, LI);
        read(LI, input(1 downto 0));
        gps_d <= input;
        wait until gps_clk = '1' and gps_clk'event;
    end loop;
    wait;
  end process;

  process
  file FI        : TEXT open read_mode is "tests/input2.txt";
  file FI_ACQ    : TEXT open read_mode is "tests/input_acq.txt";
  file FI_SKIP0  : TEXT open read_mode is "tests/input3072_0.txt";
  file FI_SKIP1  : TEXT open read_mode is "tests/input3072_1.txt";
  file FI_SKIP2  : TEXT open read_mode is "tests/input3072_2.txt";
  variable LI    : line;
  variable input : std_logic_vector(31 downto 0);
  variable last  : std_logic_vector(31 downto 0) := (others => '0');
  variable sft_chg : integer range 0 to 1023 := 256;
  variable sft_ini : integer range 0 to 1023 := 256;
  variable set_inc : std_logic_vector(6 downto 0) := (others => '1');
  begin
    wait until clk = '1' and clk'event;
    wait until clk = '1' and clk'event;
    rst <= '0';
    wait until clk = '1' and clk'event;
    wait until clk = '1' and clk'event;
-------------------------------- shift INC test --------------------------------
    if SKIP_TEST then
-- Reset to test the mode of CPU bus input
    db_i <= ('1',x"ABCC0060",'0','1',x"F",x"0000003d"); wait until clk = '1' and clk'event and db_o.ack = '1'; -- set interrupt enable
    db_i <= ('1',x"ABCC0040",'0','1',x"F",x"00000000"); wait until clk = '1' and clk'event and db_o.ack = '1'; -- write PNCO
 -- write SFT w/ -24 INC
    db_i <= ('1',x"ABCC0000",'0','1',x"F",x"2d003fef"); wait until clk = '1' and clk'event and db_o.ack = '1'; -- 1022*16 +15
    db_i <= ('1',x"ABCC0004",'0','1',x"F",x"2d000000"); wait until clk = '1' and clk'event and db_o.ack = '1'; -- 0
    db_i <= ('1',x"ABCC0008",'0','1',x"F",x"2d000008"); wait until clk = '1' and clk'event and db_o.ack = '1'; -- 8
    db_i <= ('1',x"ABCC000c",'0','1',x"F",x"2d000010"); wait until clk = '1' and clk'event and db_o.ack = '1'; -- 16
    db_i <= ('1',x"ABCC0010",'0','1',x"F",x"2d000017"); wait until clk = '1' and clk'event and db_o.ack = '1'; -- 23
    db_i <= ('1',x"ABCC0014",'0','1',x"F",x"2d000018"); wait until clk = '1' and clk'event and db_o.ack = '1'; -- 24
    db_i <= ('1',x"ABCC0018",'0','1',x"F",x"2d000019"); wait until clk = '1' and clk'event and db_o.ack = '1'; -- 25

    db_i <= ('1',x"ABCC0020",'0','1',x"F",x"00000006"); wait until clk = '1' and clk'event and db_o.ack = '1';
    db_i <= ('1',x"ABCC0024",'0','1',x"F",x"0000001c"); wait until clk = '1' and clk'event and db_o.ack = '1';
    db_i <= ('1',x"ABCC0028",'0','1',x"F",x"0000000b"); wait until clk = '1' and clk'event and db_o.ack = '1';
    db_i <= ('1',x"ABCC002c",'0','1',x"F",x"00000064"); wait until clk = '1' and clk'event and db_o.ack = '1';
    db_i <= ('1',x"ABCC0030",'0','1',x"F",x"00000200"); wait until clk = '1' and clk'event and db_o.ack = '1';
    db_i <= ('1',x"ABCC0034",'0','1',x"F",x"000000d2"); wait until clk = '1' and clk'event and db_o.ack = '1';
    db_i <= ('1',x"ABCC0038",'0','1',x"F",x"00000000"); wait until clk = '1' and clk'event and db_o.ack = '1';
    db_i <= NULL_DATA_O;
    input_loop_0: while true loop
      input := x"00000000";
      for j in 0 to 15 loop -- Read 32b data from 16 lines of 2b data
        if endfile(FI_SKIP0) then
          exit input_loop_0;
        end if;
        readline(FI_SKIP0, LI);
        read(LI, input(31 - 2*j downto 30 - 2*j));
      end loop;
      db_i <= ('1',x"ABCC0204",'0','1',x"F",input); wait until clk = '1' and clk'event and db_o.ack = '1';
-- loop until status register allows input write
      write_ready_0: while true loop
        db_i <= ('1',x"ABCC0200",'1','0',x"F",x"00000000"); wait until clk = '1' and clk'event and db_o.ack = '1';
        db_i <= NULL_DATA_O;
-- Change from -24 to +24 during RUN
        if (db_o.d(8)  and set_inc(0)) = '1' then db_i <= ('1',x"ABCC0000",'0','1',x"F",x"ab000000"); wait until clk = '1' and clk'event and db_o.ack = '1'; set_inc(0) := '0'; end if; -- 1021*16 + 7
        if (db_o.d(9)  and set_inc(1)) = '1' then db_i <= ('1',x"ABCC0004",'0','1',x"F",x"ab000000"); wait until clk = '1' and clk'event and db_o.ack = '1'; set_inc(1) := '0'; end if; -- 1021*16 + 8
        if (db_o.d(10) and set_inc(2)) = '1' then db_i <= ('1',x"ABCC0008",'0','1',x"F",x"ab000000"); wait until clk = '1' and clk'event and db_o.ack = '1'; set_inc(2) := '0'; end if; -- 1022*16
        if (db_o.d(11) and set_inc(3)) = '1' then db_i <= ('1',x"ABCC000c",'0','1',x"F",x"ab000000"); wait until clk = '1' and clk'event and db_o.ack = '1'; set_inc(3) := '0'; end if; -- 1022*16 + 8
        if (db_o.d(12) and set_inc(4)) = '1' then db_i <= ('1',x"ABCC0010",'0','1',x"F",x"ab000000"); wait until clk = '1' and clk'event and db_o.ack = '1'; set_inc(4) := '0'; end if; -- 1022*16 +15
        if (db_o.d(13) and set_inc(5)) = '1' then db_i <= ('1',x"ABCC0014",'0','1',x"F",x"ab000000"); wait until clk = '1' and clk'event and db_o.ack = '1'; set_inc(5) := '0'; end if; -- 0
        if (db_o.d(14) and set_inc(6)) = '1' then db_i <= ('1',x"ABCC0018",'0','1',x"F",x"ab000000"); wait until clk = '1' and clk'event and db_o.ack = '1'; set_inc(6) := '0'; end if; -- 1;
                                                  db_i <= NULL_DATA_O;
        if db_o.d(0)  = '1' then exit write_ready_0; end if;
      end loop;
      if intrpt = '1' then test_comment("Interrupt Occured."); end if;
      if last /= db_o.d then hwrite(LI, db_o.d); writeline(output, LI);
         last := db_o.d; test_comment("        " & time'image(now)); end if;
      for j in 1 to INTERVAL-2 loop
          wait until clk = '1' and clk'event;
      end loop;
    end loop;
-- Reset again for more test
    db_i <= ('1',x"ABCC0060",'0','1',x"F",x"0000003d"); wait until clk = '1' and clk'event and db_o.ack = '1';
    db_i <= ('1',x"ABCC0040",'0','1',x"F",x"00000000"); wait until clk = '1' and clk'event and db_o.ack = '1'; -- write PNCO
 -- write SFT w/ -16/-8 INC
    db_i <= ('1',x"ABCC000c",'0','1',x"F",x"2e000007"); wait until clk = '1' and clk'event and db_o.ack = '1'; --  7, -16
    db_i <= ('1',x"ABCC0010",'0','1',x"F",x"2e00000f"); wait until clk = '1' and clk'event and db_o.ack = '1'; -- 15, -16
    db_i <= ('1',x"ABCC0014",'0','1',x"F",x"2e000010"); wait until clk = '1' and clk'event and db_o.ack = '1'; -- 16, -16
    db_i <= ('1',x"ABCC0018",'0','1',x"F",x"2e000011"); wait until clk = '1' and clk'event and db_o.ack = '1'; -- 17, -16

    db_i <= ('1',x"ABCC002c",'0','1',x"F",x"00000064"); wait until clk = '1' and clk'event and db_o.ack = '1';
    db_i <= ('1',x"ABCC0030",'0','1',x"F",x"00000200"); wait until clk = '1' and clk'event and db_o.ack = '1';
    db_i <= ('1',x"ABCC0034",'0','1',x"F",x"000000d2"); wait until clk = '1' and clk'event and db_o.ack = '1';
    db_i <= ('1',x"ABCC0038",'0','1',x"F",x"00000000"); wait until clk = '1' and clk'event and db_o.ack = '1';
    db_i <= NULL_DATA_O;
    set_inc := (others => '1');
    input_loop_1: while true loop
      input := x"00000000";
      for j in 0 to 15 loop -- Read 32b data from 16 lines of 2b data
        if endfile(FI_SKIP1) then
          exit input_loop_1;
        end if;
        readline(FI_SKIP1, LI);
        read(LI, input(31 - 2*j downto 30 - 2*j));
      end loop;
      db_i <= ('1',x"ABCC0204",'0','1',x"F",input); wait until clk = '1' and clk'event and db_o.ack = '1';
-- loop until status register allows input write
      write_ready_1: while true loop
        db_i <= ('1',x"ABCC0200",'1','0',x"F",x"00000000"); wait until clk = '1' and clk'event and db_o.ack = '1';
        db_i <= NULL_DATA_O;
-- Change from -8/-16 to +8/+16 during RUN
        if (db_o.d(11) and set_inc(3)) = '1' then db_i <= ('1',x"ABCC000c",'0','1',x"F",x"aa000000"); wait until clk = '1' and clk'event and db_o.ack = '1'; set_inc(3) := '0'; end if; -- 1022*16 + 7
        if (db_o.d(12) and set_inc(4)) = '1' then db_i <= ('1',x"ABCC0010",'0','1',x"F",x"aa000000"); wait until clk = '1' and clk'event and db_o.ack = '1'; set_inc(4) := '0'; end if; -- 1022*16 +15
        if (db_o.d(13) and set_inc(5)) = '1' then db_i <= ('1',x"ABCC0014",'0','1',x"F",x"aa000000"); wait until clk = '1' and clk'event and db_o.ack = '1'; set_inc(5) := '0'; end if; -- 0
        if (db_o.d(14) and set_inc(6)) = '1' then db_i <= ('1',x"ABCC0018",'0','1',x"F",x"aa000000"); wait until clk = '1' and clk'event and db_o.ack = '1'; set_inc(6) := '0'; end if; -- 1;
                                                  db_i <= NULL_DATA_O;
        if db_o.d(0)  = '1' then exit write_ready_1; end if;
      end loop;
      if intrpt = '1' then test_comment("Interrupt Occured."); end if;
      if last /= db_o.d then hwrite(LI, db_o.d); writeline(output, LI);
         last := db_o.d; test_comment("        " & time'image(now)); end if;
      for j in 1 to INTERVAL-2 loop
          wait until clk = '1' and clk'event;
      end loop;
    end loop;
-- Reset again for more test
    db_i <= ('1',x"ABCC0060",'0','1',x"F",x"0000003d"); wait until clk = '1' and clk'event and db_o.ack = '1';
    db_i <= ('1',x"ABCC0040",'0','1',x"F",x"00000000"); wait until clk = '1' and clk'event and db_o.ack = '1'; -- write PNCO
 -- write SFT w/ -16/-8 INC
    db_i <= ('1',x"ABCC0000",'0','1',x"F",x"2f000007"); wait until clk = '1' and clk'event and db_o.ack = '1'; --  7, - 8
    db_i <= ('1',x"ABCC0004",'0','1',x"F",x"2f000008"); wait until clk = '1' and clk'event and db_o.ack = '1'; --  8, - 8
    db_i <= ('1',x"ABCC0008",'0','1',x"F",x"2f000009"); wait until clk = '1' and clk'event and db_o.ack = '1'; --  9, - 8

    db_i <= ('1',x"ABCC0020",'0','1',x"F",x"00000006"); wait until clk = '1' and clk'event and db_o.ack = '1';
    db_i <= ('1',x"ABCC0024",'0','1',x"F",x"0000001c"); wait until clk = '1' and clk'event and db_o.ack = '1';
    db_i <= ('1',x"ABCC0028",'0','1',x"F",x"0000000b"); wait until clk = '1' and clk'event and db_o.ack = '1';
    db_i <= NULL_DATA_O;
    set_inc := (others => '1');
    input_loop_2: while true loop
      input := x"00000000";
      for j in 0 to 15 loop -- Read 32b data from 16 lines of 2b data
        if endfile(FI_SKIP2) then
          exit input_loop_2;
        end if;
        readline(FI_SKIP2, LI);
        read(LI, input(31 - 2*j downto 30 - 2*j));
      end loop;
      db_i <= ('1',x"ABCC0204",'0','1',x"F",input); wait until clk = '1' and clk'event and db_o.ack = '1';
-- loop until status register allows input write
      write_ready_2: while true loop
        db_i <= ('1',x"ABCC0200",'1','0',x"F",x"00000000"); wait until clk = '1' and clk'event and db_o.ack = '1';
        db_i <= NULL_DATA_O;
-- Change from -8/-16 to +8/+16 during RUN
        if (db_o.d(8)  and set_inc(0)) = '1' then db_i <= ('1',x"ABCC0000",'0','1',x"F",x"a9000000"); wait until clk = '1' and clk'event and db_o.ack = '1'; set_inc(0) := '0'; end if; -- 1022*16 + 15
        if (db_o.d(9)  and set_inc(1)) = '1' then db_i <= ('1',x"ABCC0004",'0','1',x"F",x"a9000000"); wait until clk = '1' and clk'event and db_o.ack = '1'; set_inc(1) := '0'; end if; -- 0
        if (db_o.d(10) and set_inc(2)) = '1' then db_i <= ('1',x"ABCC0008",'0','1',x"F",x"a9000000"); wait until clk = '1' and clk'event and db_o.ack = '1'; set_inc(2) := '0'; end if; -- 1
                                                  db_i <= NULL_DATA_O;
        if db_o.d(0)  = '1' then exit write_ready_2; end if;
      end loop;
      if intrpt = '1' then test_comment("Interrupt Occured."); end if;
      if last /= db_o.d then hwrite(LI, db_o.d); writeline(output, LI);
         last := db_o.d; test_comment("        " & time'image(now)); end if;
      for j in 1 to INTERVAL-2 loop
          wait until clk = '1' and clk'event;
      end loop;
    end loop;
------------------------------- Acquisition test -------------------------------
    elsif ACQ_TEST then
-- Reset to test the mode of CPU bus input
    db_i <= ('1',x"ABCC0060",'0','1',x"F",x"4002003d"); wait until clk = '1' and clk'event and db_o.ack = '1'; -- Debug enable
    db_i <= ('1',x"ABCC0040",'0','1',x"F",x"00000000"); wait until clk = '1' and clk'event and db_o.ack = '1'; -- write PNCO
    db_i <= NULL_DATA_O;
    db_i <= ('1',x"ABCC0000",'0','1',x"F",x"00003fe8"); wait until clk = '1' and clk'event and db_o.ack = '1'; -- write SFT
    db_i <= NULL_DATA_O;
    db_i <= ('1',x"ABCC0020",'0','1',x"F",x"80000000"); wait until clk = '1' and clk'event and db_o.ack = '1'; -- -- write g2sft, MSB=1 for acquisition
    db_i <= NULL_DATA_O;
    for i in 1 to 2046 loop
      input := x"00000000";
      for j in 0 to 15 loop -- Read 32b data from 16 lines of 2b data
        readline(FI_ACQ, LI);
        read(LI, input(31 - 2*j downto 30 - 2*j));
      end loop;
      db_i <= ('1',x"ABCC0204",'0','1',x"F",input); wait until clk = '1' and clk'event and db_o.ack = '1';
      if i = 1008 then
        db_i <= ('1',x"ABCC0000",'0','1',x"F",x"90f00000"); wait until clk = '1' and clk'event and db_o.ack = '1'; -- inc 1kHz
        db_i <= NULL_DATA_O;
      end if;
-- loop until status register allows input write
      write_ready_acq: while true loop
        db_i <= ('1',x"ABCC0200",'1','0',x"F",x"00000000"); wait until clk = '1' and clk'event and db_o.ack = '1';
        db_i <= NULL_DATA_O;
        if db_o.d(0) = '1' then
          exit write_ready_acq;
        end if;
      end loop;
      for j in 1 to INTERVAL-2 loop
        wait until clk = '1' and clk'event;
      end loop;
    end loop;
--------------------------------- Tracking test --------------------------------
    else
    test_plan(GPSIF_NC*6*2, "gpsif_tb");
    -- write PNCO
    -- Values after increment will be for expected values.
    -- gps over bitlink reset

    -- switch 2 bits pre sample --
    db_i <= ('1',x"ABCC0060",'0','1',x"F",x"00000002"); wait until clk = '1' and clk'event and db_o.ack = '1';
    -- switch 1 bit  pre sample --
--  db_i <= ('1',x"ABCC0060",'0','1',x"F",x"00000102"); wait until clk = '1' and clk'event and db_o.ack = '1';

    -- gps over bitlink reset
    db_i <= ('1',x"ABCC0040",'0','1',x"F",x"00006058"); wait until clk = '1' and clk'event and db_o.ack = '1'; -- inc
    db_i <= ('1',x"ABCC0044",'0','1',x"F",x"fffd1f88"); wait until clk = '1' and clk'event and db_o.ack = '1'; -- inc
    db_i <= ('1',x"ABCC0048",'0','1',x"F",x"ffffe038"); wait until clk = '1' and clk'event and db_o.ack = '1'; -- inc
    db_i <= ('1',x"ABCC004c",'0','1',x"F",x"fffe5fd8"); wait until clk = '1' and clk'event and db_o.ack = '1'; -- plus - minus*4 - inc
    db_i <= ('1',x"ABCC0050",'0','1',x"F",x"fffabef0"); wait until clk = '1' and clk'event and db_o.ack = '1'; -- inc
    db_i <= ('1',x"ABCC0054",'0','1',x"F",x"fffedff8"); wait until clk = '1' and clk'event and db_o.ack = '1'; -- minus
    db_i <= ('1',x"ABCC0058",'0','1',x"F",x"fffedff8"); wait until clk = '1' and clk'event and db_o.ack = '1'; -- minus
    db_i <= NULL_DATA_O;
    -- write SFT
    db_i <= ('1',x"ABCC0000",'0','1',x"F",x"00002b98"); wait until clk = '1' and clk'event and db_o.ack = '1'; -- inc
    db_i <= ('1',x"ABCC0004",'0','1',x"F",x"00007176"); wait until clk = '1' and clk'event and db_o.ack = '1'; -- inc
    db_i <= ('1',x"ABCC0008",'0','1',x"F",x"0000ae48"); wait until clk = '1' and clk'event and db_o.ack = '1'; -- inc
    db_i <= ('1',x"ABCC000c",'0','1',x"F",x"0000d637"); wait until clk = '1' and clk'event and db_o.ack = '1'; -- plus - minus*4 - inc
    db_i <= ('1',x"ABCC0010",'0','1',x"F",x"00012a45"); wait until clk = '1' and clk'event and db_o.ack = '1'; -- inc
    db_i <= ('1',x"ABCC0014",'0','1',x"F",x"00017090"); wait until clk = '1' and clk'event and db_o.ack = '1'; -- minus
    db_i <= ('1',x"ABCC0018",'0','1',x"F",x"0001b090"); wait until clk = '1' and clk'event and db_o.ack = '1'; -- minus
    db_i <= NULL_DATA_O;
    -- write g2sft
    db_i <= ('1',x"ABCC0020",'0','1',x"F",x"00000006"); wait until clk = '1' and clk'event and db_o.ack = '1';
    db_i <= ('1',x"ABCC0024",'0','1',x"F",x"0000001c"); wait until clk = '1' and clk'event and db_o.ack = '1';
    db_i <= ('1',x"ABCC0028",'0','1',x"F",x"0000000b"); wait until clk = '1' and clk'event and db_o.ack = '1';
    db_i <= ('1',x"ABCC002c",'0','1',x"F",x"00000064"); wait until clk = '1' and clk'event and db_o.ack = '1';
    db_i <= ('1',x"ABCC0030",'0','1',x"F",x"00000200"); wait until clk = '1' and clk'event and db_o.ack = '1';
    db_i <= ('1',x"ABCC0034",'0','1',x"F",x"000000d2"); wait until clk = '1' and clk'event and db_o.ack = '1';
    db_i <= ('1',x"ABCC0038",'0','1',x"F",x"000000d2"); wait until clk = '1' and clk'event and db_o.ack = '1';
    db_i <= NULL_DATA_O;
    -- correct SFT, increment PNCO
    db_i <= ('1',x"ABCC000c",'0','1',x"F",x"c0000000"); wait until clk = '1' and clk'event and db_o.ack = '1'; -- plus - minus*4 - inc
    db_i <= ('1',x"ABCC0014",'0','1',x"F",x"f0000000"); wait until clk = '1' and clk'event and db_o.ack = '1'; -- minus
    db_i <= ('1',x"ABCC0018",'0','1',x"F",x"f0000000"); wait until clk = '1' and clk'event and db_o.ack = '1'; -- minus
    db_i <= ('1',x"ABCC0000",'0','1',x"F",x"bcf00000"); wait until clk = '1' and clk'event and db_o.ack = '1'; -- inc 4, 1kHz
    db_i <= ('1',x"ABCC0004",'0','1',x"F",x"b0000000"); wait until clk = '1' and clk'event and db_o.ack = '1'; -- inc
    db_i <= ('1',x"ABCC0008",'0','1',x"F",x"b0000000"); wait until clk = '1' and clk'event and db_o.ack = '1'; -- inc
    db_i <= ('1',x"ABCC0010",'0','1',x"F",x"b0000000"); wait until clk = '1' and clk'event and db_o.ack = '1'; -- inc

    for j in 1 to  4 loop
        for i in 1 to 131 loop     db_i <= NULL_DATA_O; wait until clk = '1' and clk'event;                    end loop;
    db_i <= ('1',x"ABCC000c",'0','1',x"F",x"e0000000"); wait until clk = '1' and clk'event and db_o.ack = '1'; end loop; -- plus - minus*4 - inc
        for i in 1 to 145 loop     db_i <= NULL_DATA_O; wait until clk = '1' and clk'event;                    end loop;
    db_i <= ('1',x"ABCC000c",'0','1',x"F",x"b0000000"); wait until clk = '1' and clk'event and db_o.ack = '1';
    db_i <= NULL_DATA_O;
    -- Wait for end of execution
    for i in 1 to exe_cycles loop                       wait until clk = '1' and clk'event; chk_dma_req(dma);  end loop;
    -- Check that same values seen in the waveform at the end of the gpsif_tb
    if ANGLE_INI_OLD then check_channel(clk, db_o, db_i, 0, 13270,   7002, 19082, 42342, 21452, 25808);
    if(GPSIF_NC > 1) then check_channel(clk, db_o, db_i, 1, 19610, -33416, 28814,-42980, 17464,-26782); end if;
    if(GPSIF_NC > 2) then check_channel(clk, db_o, db_i, 2, 31701,  -1218, 39655,  2086, 13683,   578); end if;
    if(GPSIF_NC > 3) then check_channel(clk, db_o, db_i, 3, 18756,   3118, 33526,  1452,  8116,-17806); end if;
    if(GPSIF_NC > 4) then check_channel(clk, db_o, db_i, 4,    41,  16785,-12169, 10099, -9071,   593); end if;
    if(GPSIF_NC > 5) then check_channel(clk, db_o, db_i, 5, -2038,  -1740,  8074, 23868, -6866, 22632); end if;
    if(GPSIF_NC > 6) then check_channel(clk, db_o, db_i, 6, -2038,  -1740,  8074, 23868, -6866, 22632); end if;
    else                  check_channel(clk, db_o, db_i, 0, -7067,  13225,-42327, 19061,-25709, 21447);
    if(GPSIF_NC > 1) then check_channel(clk, db_o, db_i, 1, 33477,  19603, 43079, 28829, 26827, 17517); end if;
    if(GPSIF_NC > 2) then check_channel(clk, db_o, db_i, 2,  1206,  31727, -2054, 39687,  -562, 13701); end if;
    if(GPSIF_NC > 3) then check_channel(clk, db_o, db_i, 3, -3137,  18763, -1443, 33571, 17805,  8119); end if;
    if(GPSIF_NC > 4) then check_channel(clk, db_o, db_i, 4,-16875,     59,-10147,-12217,  -477, -9121); end if;
    if(GPSIF_NC > 5) then check_channel(clk, db_o, db_i, 5,  1743,  -2041,-23865,  8079,-22653, -6869); end if;
    if(GPSIF_NC > 6) then check_channel(clk, db_o, db_i, 6,  1743,  -2041,-23865,  8079,-22653, -6869); end if; end if;
    wait until clk = '1' and clk'event;
    wait until clk = '1' and clk'event;

-- Reset to test the mode of CPU bus input
    db_i <= ('1',x"ABCC0060",'0','1',x"F",x"00000001"); wait until clk = '1' and clk'event and db_o.ack = '1';
    -- write PNCO
    db_i <= ('1',x"ABCC0040",'0','1',x"F",x"00006058"); wait until clk = '1' and clk'event and db_o.ack = '1'; -- plus
    db_i <= ('1',x"ABCC0044",'0','1',x"F",x"fffd1f88"); wait until clk = '1' and clk'event and db_o.ack = '1'; -- minus
    db_i <= ('1',x"ABCC0048",'0','1',x"F",x"0000e038"); wait until clk = '1' and clk'event and db_o.ack = '1';
    db_i <= ('1',x"ABCC004c",'0','1',x"F",x"ffff5fd8"); wait until clk = '1' and clk'event and db_o.ack = '1';
    db_i <= ('1',x"ABCC0050",'0','1',x"F",x"fffbbef0"); wait until clk = '1' and clk'event and db_o.ack = '1';
    db_i <= ('1',x"ABCC0054",'0','1',x"F",x"ffffdff8"); wait until clk = '1' and clk'event and db_o.ack = '1';
    db_i <= NULL_DATA_O;
    -- write SFT
    db_i <= ('1',x"ABCC0000",'0','1',x"F",x"00000007"); wait until clk = '1' and clk'event and db_o.ack = '1'; -- plus
    db_i <= ('1',x"ABCC0004",'0','1',x"F",x"00000011"); wait until clk = '1' and clk'event and db_o.ack = '1'; -- minus
    db_i <= ('1',x"ABCC0008",'0','1',x"F",x"0000ae4c"); wait until clk = '1' and clk'event and db_o.ack = '1';
    db_i <= ('1',x"ABCC000c",'0','1',x"F",x"0000d638"); wait until clk = '1' and clk'event and db_o.ack = '1';
    db_i <= ('1',x"ABCC0010",'0','1',x"F",x"00012a49"); wait until clk = '1' and clk'event and db_o.ack = '1';
    db_i <= ('1',x"ABCC0014",'0','1',x"F",x"0001708f"); wait until clk = '1' and clk'event and db_o.ack = '1';
    db_i <= NULL_DATA_O;
    -- write g2sft
    db_i <= ('1',x"ABCC0020",'0','1',x"F",x"00000006"); wait until clk = '1' and clk'event and db_o.ack = '1'; -- plus - minus
    db_i <= ('1',x"ABCC0024",'0','1',x"F",x"0000001c"); wait until clk = '1' and clk'event and db_o.ack = '1'; -- minus - plus
    db_i <= ('1',x"ABCC0028",'0','1',x"F",x"0000000b"); wait until clk = '1' and clk'event and db_o.ack = '1';
    db_i <= ('1',x"ABCC002c",'0','1',x"F",x"00000064"); wait until clk = '1' and clk'event and db_o.ack = '1';
    db_i <= ('1',x"ABCC0030",'0','1',x"F",x"00000200"); wait until clk = '1' and clk'event and db_o.ack = '1';
    db_i <= ('1',x"ABCC0034",'0','1',x"F",x"000000d2"); wait until clk = '1' and clk'event and db_o.ack = '1';
    db_i <= NULL_DATA_O;
    input_loop: while true loop
      input := x"00000000";
      for j in 0 to 15 loop -- Read 32b data from 16 lines of 2b data
        if endfile(FI) then
          exit input_loop;
        end if;
        readline(FI, LI);
        read(LI, input(31 - 2*j downto 30 - 2*j));
      end loop;
      db_i <= ('1',x"ABCC0204",'0','1',x"F",input); wait until clk = '1' and clk'event and db_o.ack = '1'; chk_dma_req(dma);
-- loop until status register allows input write
      write_ready: while true loop
        db_i <= ('1',x"ABCC0200",'1','0',x"F",x"00000000"); wait until clk = '1' and clk'event and db_o.ack = '1'; chk_dma_req(dma);
        db_i <= NULL_DATA_O;
        if db_o.d(0) = '1' then
          exit write_ready;
        elsif sft_chg > 0 then
              sft_chg := sft_chg -1;
           if sft_chg = 128 then
            -- SFT +- 1
            db_i <= ('1',x"ABCC0000",'0','1',x"F",x"c0000000"); wait until clk = '1' and clk'event and db_o.ack = '1'; -- plus
            db_i <= ('1',x"ABCC0004",'0','1',x"F",x"e0000000"); wait until clk = '1' and clk'event and db_o.ack = '1'; -- minus
            db_i <= NULL_DATA_O;
           elsif sft_chg = 0 then
             -- SFT -+ 1
             db_i <= ('1',x"ABCC0000",'0','1',x"F",x"e0000000"); wait until clk = '1' and clk'event and db_o.ack = '1'; -- minus
             db_i <= ('1',x"ABCC0004",'0','1',x"F",x"c0000000"); wait until clk = '1' and clk'event and db_o.ack = '1'; -- plus
             db_i <= NULL_DATA_O;
           end if;
        elsif sft_ini > 0 then
              sft_ini := sft_ini -1;
           if sft_ini = 0 then
            -- write SFT
            db_i <= ('1',x"ABCC0000",'0','1',x"F",x"00002b8c"); wait until clk = '1' and clk'event and db_o.ack = '1';
            db_i <= ('1',x"ABCC0004",'0','1',x"F",x"0000716a"); wait until clk = '1' and clk'event and db_o.ack = '1';
            db_i <= ('1',x"ABCC0000",'0','1',x"F",x"baf00000"); wait until clk = '1' and clk'event and db_o.ack = '1'; -- inc 16, inc 1kHz
            db_i <= ('1',x"ABCC0004",'0','1',x"F",x"b0000000"); wait until clk = '1' and clk'event and db_o.ack = '1'; -- inc 16, inc 1kHz
            db_i <= ('1',x"ABCC0020",'0','1',x"F",x"00000006"); wait until clk = '1' and clk'event and db_o.ack = '1'; -- reset C/A code
            db_i <= ('1',x"ABCC0024",'0','1',x"F",x"0000001c"); wait until clk = '1' and clk'event and db_o.ack = '1'; -- reset C/A code
            db_i <= NULL_DATA_O;
           end if;
        end if;
      end loop;
      for j in 1 to INTERVAL-2 loop
          wait until clk = '1' and clk'event; chk_dma_req(dma);
      end loop;
    end loop;
    -- Check that same values seen in the waveform at the end of the gpsif_tb
    if ANGLE_INI_OLD then check_channel(clk, db_o, db_i, 0, 13270,   7002, 19082, 42342, 21452, 25808);
    if(GPSIF_NC > 1) then check_channel(clk, db_o, db_i, 1, 19610, -33416, 28814,-42980, 17464,-26782); end if;
    if(GPSIF_NC > 2) then check_channel(clk, db_o, db_i, 2, 31701,  -1218, 39655,  2086, 13683,   578); end if;
    if(GPSIF_NC > 3) then check_channel(clk, db_o, db_i, 3, 18756,   3118, 33526,  1452,  8116,-17806); end if;
    if(GPSIF_NC > 4) then check_channel(clk, db_o, db_i, 4,    41,  16785,-12169, 10099, -9071,   593); end if;
    if(GPSIF_NC > 5) then check_channel(clk, db_o, db_i, 5, -2038,  -1740,  8074, 23868, -6866, 22632); end if;
    else                  check_channel(clk, db_o, db_i, 0, -7067,  13225,-42327, 19061,-25709, 21447);
    if(GPSIF_NC > 1) then check_channel(clk, db_o, db_i, 1, 33477,  19603, 43079, 28829, 26827, 17517); end if;
    if(GPSIF_NC > 2) then check_channel(clk, db_o, db_i, 2,  1206,  31727, -2054, 39687,  -562, 13701); end if;
    if(GPSIF_NC > 3) then check_channel(clk, db_o, db_i, 3, -3137,  18763, -1443, 33571, 17805,  8119); end if;
    if(GPSIF_NC > 4) then check_channel(clk, db_o, db_i, 4,-16875,     59,-10147,-12217,  -477, -9121); end if;
    if(GPSIF_NC > 5) then check_channel(clk, db_o, db_i, 5,  1743,  -2041,-23865,  8079,-22653, -6869); end if; end if;
    end if;
-- dump signals
    for i in 1 to 256 loop
        db_i <= ('1',x"ABCC0080",'1','0',x"F",x"00000000"); wait until clk = '1' and clk'event and db_o.ack = '1';
        db_i <= ('1',x"ABCC00a0",'1','0',x"F",x"00000000"); wait until clk = '1' and clk'event and db_o.ack = '1';
        db_i <= ('1',x"ABCC00c0",'1','0',x"F",x"00000000"); wait until clk = '1' and clk'event and db_o.ack = '1';
    end loop;
    db_i <= NULL_DATA_O;

    test_finished("done");
    ENDSIM := true;
    wait;
  end process;

  gpsov_blink_packet : process
    variable tmp_10bit :  std_logic_vector(9 downto 0);
    file FI3       : TEXT open read_mode is "tests/input3.txt";
    variable LI    : line;
    variable input : std_logic_vector(31 downto 0);
    variable packet_mode : integer; -- 1 / 2 <-> 1bit 2bits/
  begin
--  ----------------------
--  packet_mode := 1;
--  ----------------------
    packet_mode := 2;
--  ----------------------

    blgps <= NULL_BLGPS;
    wait until rst = '0';
    wait for clk_tgl * 40; 
    wait until clk = '1';
    for i in 0 to 8191 loop
      i_bl_control <= i;
      tmp_10bit := std_logic_vector(to_unsigned(i, 10));
      -- ---------------------
      for j in 0 to 15 loop
        readline(FI3, LI);
        read(LI, input(31 - 2*j downto 30 - 2*j));
        if(( j mod 4) = 3) then
          blgps.en <= '1';

          if   (i = 560) then blgps.tick <= '1';
          elsif(i = 576) then blgps.tick <= '0';
          end if;

          if(packet_mode = 2) then --        2 bits per sample --
               blgps.a(5 downto 2) <= tmp_10bit(3 downto 0) ;
          else                     --        1 bits per sample --
               blgps.a(4 downto 2) <= tmp_10bit(2 downto 0) ;
               blgps.a(5         ) <= '0';                    end if;
          -- switch end 

          case (j / 4) is
            when 0 => blgps.a(1 downto 0) <= "00"; 
            when 1 => blgps.a(1 downto 0) <= "01"; 
            when 2 => blgps.a(1 downto 0) <= "10"; 
            when 3 => blgps.a(1 downto 0) <= "11"; 
          end case;

          blgps.d  <= input (7 + (30 - 2*j) downto 30 - 2*j);
          --  ex. j=3, bitpos = 31:24, j=15, bitpos =7:0
 
          wait until clk = '1';
        -- ---------------------
          blgps.en <= '0';
          blgps.a  <= (others => '0');
          blgps.d  <= (others => '0');
          for j in 1 to 6 loop 
            wait until clk = '1';
          end loop;
        end if;
      end loop;
      -- ---------------------
      if((tmp_10bit(3 downto 0) = "1111") and (packet_mode = 2)) or
        ((tmp_10bit(2 downto 0) =  "111") and (packet_mode = 1)) then
    -- ----------------------------------------
    -- switch 2 bits per sample --
        if(packet_mode = 2) then
          wait for clk_tgl * 1841; end if;
          -- 2bit sample wait calc 
          -- 256 sample (pin time - cpu time)
          -- pin time = (256 / 16368) x 1ms  = 15640.3 ns
          -- cpu time (as vector input) 
          --  11.42857 ns x (7 * 64) = 5120.0 ns
          -- pin time - cpu time = 10520.3 ns (= 1841.00 * (11.42857 / 2))
    -- ----------------------------------------
    -- switch 1 bit  per sample --
        if(packet_mode = 1) then
          wait for clk_tgl * 2289; end if;
          -- 1bit sample wait calc 
          -- 256 sample (pin time - cpu time)
          -- pin time = (256 / 16368) x 1ms  = 15640.3 ns
          -- cpu time (as vector input) 
          --  11.42857 ns x (7 * 32) = 2560.0 ns
          -- pin time - cpu time = 13080.3 ns (= 2289.1  * (11.42857 / 2))
        wait until clk = '1';
    -- ----------------------------------------
      end if;
    end loop;
  end process;

end architecture;
