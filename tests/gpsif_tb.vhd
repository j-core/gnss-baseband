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

entity gpsif_tb is
end entity;

architecture tb of gpsif_tb is
    constant clk_tgl       : time    :=  4.0    ns; -- for 125    MHz
--  constant clk_tgl       : time    :=  5.3333 ns; -- for  93.75 MHz
--  constant clk_tgl       : time    :=  5.454  ns; -- for 5.5x gps clk MHz
--  constant clk_tgl       : time    :=  5.714  ns; -- for  87.5  MHz
--  constant clk_tgl       : time    :=  8      ns; -- for  62.5  MHz
--  constant bus_tgl       : time    :=  8.0    ns; -- for  62.5  MHz
    constant bus_tgl       : time    :=  4.0    ns; -- for 125    MHz
  constant gps_tgl       : time    := 30.547 ns; -- for 16.368 MHz
  constant ppsdds_tgl    : time    := 30000.0 ns; -- actual 1Hz, accelating test
  constant INTERVAL      : natural := 4; -- 32b/4cycles = 1Byte/cycle is the maximum input speed for gpsif
  constant exe_cycles    : natural := 32736;    -- running 2ms @16.368Ms/s
  constant ANGLE_INI_OLD : boolean := false;
  constant GPSIF_NC      : natural := 7;
  constant ACQ_TEST      : boolean := false;
  constant SKIP_TEST     : boolean := false;

  signal gps_clk         : std_logic := '0';
  signal gps_d           : std_logic_vector(1 downto 0) := "00";
  signal clk             : std_logic := '0';
  signal rst             : std_logic := '1';
  signal ppsdds          : std_logic := '0';
  signal blgps           : blgps_t   := NULL_BLGPS;
  signal intrpt          : std_logic := '0';
  signal bus_clk         : std_logic := '0';
  shared variable ENDSIM : boolean   := false;

  signal dma  : dma_req_t;
  signal db_i : cpu_data_o_t := NULL_DATA_O;
  signal db_o : cpu_data_i_t;

begin
    clk_gen : process
    begin
      if ENDSIM = false then
        clk <= '1'; wait for clk_tgl;
        clk <= '0'; wait for clk_tgl;
      else          wait;
      end if;
    end process;

    bus_clk_gen : process
    begin
      if ENDSIM = false then
        bus_clk <= '1'; wait for bus_tgl;
        bus_clk <= '0'; wait for bus_tgl;
      else              wait;
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
      bus_clk => bus_clk,
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
  variable LI    : line;
  variable input : std_logic_vector(31 downto 0);
  variable last  : std_logic_vector(31 downto 0) := (others => '0');
  variable sft_chg : integer range 0 to 1023 := 256;
  variable sft_ini : integer range 0 to 1023 := 256;
  variable set_inc : std_logic_vector(6 downto 0) := (others => '1');
  begin
    wait until bus_clk = '1' and bus_clk'event;
    wait until bus_clk = '1' and bus_clk'event;
    rst <= '0';
    wait until clk = '1' and clk'event;
    wait until clk = '1' and clk'event;

    test_plan((GPSIF_NC+6)*6, "gpsif_tb");
    -- write PNCO
    -- Values after increment will be for expected values.
    db_i <= ('1',x"ABCC0040",'0','1',x"F",x"00006058"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1'; -- inc
    db_i <= ('1',x"ABCC0044",'0','1',x"F",x"fffd1f88"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1'; -- inc
    db_i <= ('1',x"ABCC0048",'0','1',x"F",x"ffffe038"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1'; -- inc
    db_i <= ('1',x"ABCC004c",'0','1',x"F",x"fffe5fd8"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1'; -- plus - minus*4 - inc
    db_i <= ('1',x"ABCC0050",'0','1',x"F",x"fffabef0"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1'; -- inc
    db_i <= ('1',x"ABCC0054",'0','1',x"F",x"fffedff8"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1'; -- minus
    db_i <= ('1',x"ABCC0058",'0','1',x"F",x"fffedff8"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1'; -- minus
    db_i <= NULL_DATA_O;
    -- write SFT
    db_i <= ('1',x"ABCC0000",'0','1',x"F",x"00002b98"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1'; -- inc
    db_i <= ('1',x"ABCC0004",'0','1',x"F",x"00007176"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1'; -- inc
    db_i <= ('1',x"ABCC0008",'0','1',x"F",x"0000ae48"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1'; -- inc
    db_i <= ('1',x"ABCC000c",'0','1',x"F",x"0000d637"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1'; -- plus - minus*4 - inc
    db_i <= ('1',x"ABCC0010",'0','1',x"F",x"00012a45"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1'; -- inc
    db_i <= ('1',x"ABCC0014",'0','1',x"F",x"00017090"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1'; -- minus
    db_i <= ('1',x"ABCC0018",'0','1',x"F",x"0001b090"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1'; -- minus
    db_i <= NULL_DATA_O;
    -- write g2sft
    db_i <= ('1',x"ABCC0020",'0','1',x"F",x"00000006"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1';
    db_i <= ('1',x"ABCC0024",'0','1',x"F",x"0000001c"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1';
    db_i <= ('1',x"ABCC0028",'0','1',x"F",x"0000000b"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1';
    db_i <= ('1',x"ABCC002c",'0','1',x"F",x"00000064"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1';
    db_i <= ('1',x"ABCC0030",'0','1',x"F",x"00000200"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1';
    db_i <= ('1',x"ABCC0034",'0','1',x"F",x"000000d2"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1';
    db_i <= ('1',x"ABCC0038",'0','1',x"F",x"000000d2"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1';
    db_i <= NULL_DATA_O;
    -- correct SFT, increment PNCO
    db_i <= ('1',x"ABCC000c",'0','1',x"F",x"c0000000"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1'; -- plus - minus*4 - inc
    db_i <= ('1',x"ABCC0014",'0','1',x"F",x"f0000000"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1'; -- minus
    db_i <= ('1',x"ABCC0018",'0','1',x"F",x"f0000000"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1'; -- minus
    db_i <= ('1',x"ABCC0000",'0','1',x"F",x"bcf00000"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1'; -- inc 4, 1kHz
    db_i <= ('1',x"ABCC0004",'0','1',x"F",x"b0000000"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1'; -- inc
    db_i <= ('1',x"ABCC0008",'0','1',x"F",x"b0000000"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1'; -- inc
    db_i <= ('1',x"ABCC0010",'0','1',x"F",x"b0000000"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1'; -- inc

    for j in 1 to  4 loop
        for i in 1 to  17 loop     db_i <= NULL_DATA_O; wait until gps_clk = '1' and gps_clk'event;                    end loop;
                                                        wait until bus_clk = '1' and bus_clk'event; -- adjust timing to bus_clk
    db_i <= ('1',x"ABCC000c",'0','1',x"F",x"e0000000"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1'; end loop; -- plus - minus*4 - inc
        for i in 1 to  19 loop     db_i <= NULL_DATA_O; wait until gps_clk = '1' and gps_clk'event;                    end loop;
                                                        wait until bus_clk = '1' and bus_clk'event; -- adjust timing to bus_clk
    db_i <= ('1',x"ABCC000c",'0','1',x"F",x"b0000000"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1';
    db_i <= NULL_DATA_O;
    -- Wait for end of execution
    for i in 1 to exe_cycles loop                       wait until gps_clk = '1' and gps_clk'event; chk_dma_req(dma);  end loop;
                                                        wait until bus_clk = '1' and bus_clk'event; -- adjust timing to bus_clk
    -- Check that same values seen in the waveform at the end of the gpsif_tb
    if ANGLE_INI_OLD then check_channel(bus_clk, db_o, db_i, 0, 13270,   7002, 19082, 42342, 21452, 25808);
    if(GPSIF_NC > 1) then check_channel(bus_clk, db_o, db_i, 1, 19610, -33416, 28814,-42980, 17464,-26782); end if;
    if(GPSIF_NC > 2) then check_channel(bus_clk, db_o, db_i, 2, 31701,  -1218, 39655,  2086, 13683,   578); end if;
    if(GPSIF_NC > 3) then check_channel(bus_clk, db_o, db_i, 3, 18756,   3118, 33526,  1452,  8116,-17806); end if;
    if(GPSIF_NC > 4) then check_channel(bus_clk, db_o, db_i, 4,    41,  16785,-12169, 10099, -9071,   593); end if;
    if(GPSIF_NC > 5) then check_channel(bus_clk, db_o, db_i, 5, -2038,  -1740,  8074, 23868, -6866, 22632); end if;
    if(GPSIF_NC > 6) then check_channel(bus_clk, db_o, db_i, 6, -2038,  -1740,  8074, 23868, -6866, 22632); end if;
    else                  check_channel(bus_clk, db_o, db_i, 0, -7067,  13225,-42327, 19061,-25709, 21447);
    if(GPSIF_NC > 1) then check_channel(bus_clk, db_o, db_i, 1, 33477,  19603, 43079, 28829, 26827, 17517); end if;
    if(GPSIF_NC > 2) then check_channel(bus_clk, db_o, db_i, 2,  1206,  31727, -2054, 39687,  -562, 13701); end if;
    if(GPSIF_NC > 3) then check_channel(bus_clk, db_o, db_i, 3, -3137,  18763, -1443, 33571, 17805,  8119); end if;
    if(GPSIF_NC > 4) then check_channel(bus_clk, db_o, db_i, 4,-16875,     59,-10147,-12217,  -477, -9121); end if;
    if(GPSIF_NC > 5) then check_channel(bus_clk, db_o, db_i, 5,  1743,  -2041,-23865,  8079,-22653, -6869); end if;
    if(GPSIF_NC > 6) then check_channel(bus_clk, db_o, db_i, 6,  1743,  -2041,-23865,  8079,-22653, -6869); end if; end if;
    wait until bus_clk = '1' and bus_clk'event;
    wait until bus_clk = '1' and bus_clk'event;

-- Reset to test the mode of CPU bus input
    db_i <= ('1',x"ABCC0060",'0','1',x"F",x"00000001"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1';
    -- write PNCO
    db_i <= ('1',x"ABCC0040",'0','1',x"F",x"00006058"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1'; -- plus
    db_i <= ('1',x"ABCC0044",'0','1',x"F",x"fffd1f88"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1'; -- minus
    db_i <= ('1',x"ABCC0048",'0','1',x"F",x"0000e038"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1';
    db_i <= ('1',x"ABCC004c",'0','1',x"F",x"ffff5fd8"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1';
    db_i <= ('1',x"ABCC0050",'0','1',x"F",x"fffbbef0"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1';
    db_i <= ('1',x"ABCC0054",'0','1',x"F",x"ffffdff8"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1';
    db_i <= NULL_DATA_O;
    -- write SFT
    db_i <= ('1',x"ABCC0000",'0','1',x"F",x"00000007"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1'; -- plus
    db_i <= ('1',x"ABCC0004",'0','1',x"F",x"00000011"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1'; -- minus
    db_i <= ('1',x"ABCC0008",'0','1',x"F",x"0000ae4c"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1';
    db_i <= ('1',x"ABCC000c",'0','1',x"F",x"0000d638"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1';
    db_i <= ('1',x"ABCC0010",'0','1',x"F",x"00012a49"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1';
    db_i <= ('1',x"ABCC0014",'0','1',x"F",x"0001708f"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1';
    db_i <= NULL_DATA_O;
    -- write g2sft
    db_i <= ('1',x"ABCC0020",'0','1',x"F",x"00000006"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1'; -- plus - minus
    db_i <= ('1',x"ABCC0024",'0','1',x"F",x"0000001c"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1'; -- minus - plus
    db_i <= ('1',x"ABCC0028",'0','1',x"F",x"0000000b"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1';
    db_i <= ('1',x"ABCC002c",'0','1',x"F",x"00000064"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1';
    db_i <= ('1',x"ABCC0030",'0','1',x"F",x"00000200"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1';
    db_i <= ('1',x"ABCC0034",'0','1',x"F",x"000000d2"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1';
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
      db_i <= ('1',x"ABCC0204",'0','1',x"F",input); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1'; chk_dma_req(dma);
-- loop until status register allows input write
      write_ready: while true loop
        db_i <= ('1',x"ABCC0200",'1','0',x"F",x"00000000"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1'; chk_dma_req(dma);
        db_i <= NULL_DATA_O;
        if db_o.d(0) = '1' then
          exit write_ready;
        elsif sft_chg > 0 then
              sft_chg := sft_chg -1;
           if sft_chg = 128 then
            -- SFT +- 1
            db_i <= ('1',x"ABCC0000",'0','1',x"F",x"c0000000"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1'; -- plus
            db_i <= ('1',x"ABCC0004",'0','1',x"F",x"e0000000"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1'; -- minus
            db_i <= NULL_DATA_O;
           elsif sft_chg = 0 then
             -- SFT -+ 1
             db_i <= ('1',x"ABCC0000",'0','1',x"F",x"e0000000"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1'; -- minus
             db_i <= ('1',x"ABCC0004",'0','1',x"F",x"c0000000"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1'; -- plus
             db_i <= NULL_DATA_O;
           end if;
        elsif sft_ini > 0 then
              sft_ini := sft_ini -1;
           if sft_ini = 0 then
            -- write SFT
            db_i <= ('1',x"ABCC0000",'0','1',x"F",x"00002b8c"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1';
            db_i <= ('1',x"ABCC0004",'0','1',x"F",x"0000716a"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1';
            db_i <= ('1',x"ABCC0000",'0','1',x"F",x"baf00000"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1'; -- inc 16, inc 1kHz
            db_i <= ('1',x"ABCC0004",'0','1',x"F",x"b0000000"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1'; -- inc 16, inc 1kHz
            db_i <= ('1',x"ABCC0020",'0','1',x"F",x"00000006"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1'; -- reset C/A code
            db_i <= ('1',x"ABCC0024",'0','1',x"F",x"0000001c"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1'; -- reset C/A code
            db_i <= NULL_DATA_O;
           end if;
        end if;
      end loop;
      for j in 1 to INTERVAL-2 loop
          wait until bus_clk = '1' and bus_clk'event; chk_dma_req(dma);
      end loop;
    end loop;
    -- Check that same values seen in the waveform at the end of the gpsif_tb
    if ANGLE_INI_OLD then check_channel(bus_clk, db_o, db_i, 0, 13270,   7002, 19082, 42342, 21452, 25808);
    if(GPSIF_NC > 1) then check_channel(bus_clk, db_o, db_i, 1, 19610, -33416, 28814,-42980, 17464,-26782); end if;
    if(GPSIF_NC > 2) then check_channel(bus_clk, db_o, db_i, 2, 31701,  -1218, 39655,  2086, 13683,   578); end if;
    if(GPSIF_NC > 3) then check_channel(bus_clk, db_o, db_i, 3, 18756,   3118, 33526,  1452,  8116,-17806); end if;
    if(GPSIF_NC > 4) then check_channel(bus_clk, db_o, db_i, 4,    41,  16785,-12169, 10099, -9071,   593); end if;
    if(GPSIF_NC > 5) then check_channel(bus_clk, db_o, db_i, 5, -2038,  -1740,  8074, 23868, -6866, 22632); end if;
    else                  check_channel(bus_clk, db_o, db_i, 0, -7067,  13225,-42327, 19061,-25709, 21447);
    if(GPSIF_NC > 1) then check_channel(bus_clk, db_o, db_i, 1, 33477,  19603, 43079, 28829, 26827, 17517); end if;
    if(GPSIF_NC > 2) then check_channel(bus_clk, db_o, db_i, 2,  1206,  31727, -2054, 39687,  -562, 13701); end if;
    if(GPSIF_NC > 3) then check_channel(bus_clk, db_o, db_i, 3, -3137,  18763, -1443, 33571, 17805,  8119); end if;
    if(GPSIF_NC > 4) then check_channel(bus_clk, db_o, db_i, 4,-16875,     59,-10147,-12217,  -477, -9121); end if;
    if(GPSIF_NC > 5) then check_channel(bus_clk, db_o, db_i, 5,  1743,  -2041,-23865,  8079,-22653, -6869); end if; end if;

-- dump signals
    for i in 1 to 256 loop
        db_i <= ('1',x"ABCC0080",'1','0',x"F",x"00000000"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1';
        db_i <= ('1',x"ABCC00a0",'1','0',x"F",x"00000000"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1';
        db_i <= ('1',x"ABCC00c0",'1','0',x"F",x"00000000"); wait until bus_clk = '1' and bus_clk'event and db_o.ack = '1';
    end loop;
    db_i <= NULL_DATA_O;

    test_finished("done");
    ENDSIM := true;
    wait;
  end process;

end architecture;
