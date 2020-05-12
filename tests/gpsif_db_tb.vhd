library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_textio.all;
use ieee.numeric_std.all;
use std.textio.all;

use work.cpu2j0_pack.all;
use work.test_pkg.all;
use work.bist_pack.all;
use work.gpsif_pack.all;

entity gpsif_db_tb is
end entity;

architecture tb of gpsif_db_tb is
  signal clk             : std_logic := '0';
  signal rst             : std_logic := '1';
  shared variable ENDSIM : boolean   := false;

  signal dma  : dma_req_t;
  signal db_i : cpu_data_o_t := NULL_DATA_O;
  signal db_o : cpu_data_i_t;

  function read(addr : std_logic_vector(7 downto 0))
  return cpu_data_o_t is
    variable r : cpu_data_o_t := NULL_DATA_O;
  begin
    r.en := '1';
    r.rd := '1';
    r.a := x"00000" & "00" & addr & "00";
    return r;
  end;

  function write(addr : std_logic_vector(7 downto 0);
                 data : std_logic_vector(31 downto 0);
                 we : std_logic_vector(3 downto 0) := "1111")
  return cpu_data_o_t is
    variable w : cpu_data_o_t := NULL_DATA_O;
  begin
    w.en := '1';
    w.wr := '1';
    w.a := x"00000" & "00" & addr & "00";
    w.d := data;
    w.we := we;
    return w;
  end;

  function sign_extend28(x : std_logic_vector(31 downto 0))
    return std_logic_vector is
  begin
    return x(27) & x(27) & x(27) & x(27) & x(27 downto 0);
  end function;

  procedure check_channel(
    signal clk : in std_logic;
    signal db_i : out cpu_data_o_t;
    signal db_o : in cpu_data_i_t;
    constant ch : integer;
    constant ei : integer;
    constant eq : integer;
    constant pi : integer;
    constant pq : integer;
    constant li : integer;
    constant lq : integer) is
  begin
    db_i <= read(std_logic_vector(to_unsigned(16#40#, 8) + to_unsigned(ch*8  , 8)));
    wait until clk = '1' and clk'event and db_o.ack = '1';
    test_equal(to_integer(signed(sign_extend28(db_o.d))), ei, "E_I(" & integer'image(ch) & ")");
    db_i <= NULL_DATA_O;
    wait until clk = '1' and clk'event;

    db_i <= read(std_logic_vector(to_unsigned(16#40#, 8) + to_unsigned(ch*8+1, 8)));
    wait until clk = '1' and clk'event and db_o.ack = '1';
    test_equal(to_integer(signed(sign_extend28(db_o.d))), eq, "E_Q(" & integer'image(ch) & ")");
    db_i <= NULL_DATA_O;
    wait until clk = '1' and clk'event;

    db_i <= read(std_logic_vector(to_unsigned(16#40#, 8) + to_unsigned(ch*8+2, 8)));
    wait until clk = '1' and clk'event and db_o.ack = '1';
    test_equal(to_integer(signed(sign_extend28(db_o.d))), pi, "P_I(" & integer'image(ch) & ")");
    db_i <= NULL_DATA_O;
    wait until clk = '1' and clk'event;

    db_i <= read(std_logic_vector(to_unsigned(16#40#, 8) + to_unsigned(ch*8+3, 8)));
    wait until clk = '1' and clk'event and db_o.ack = '1';
    test_equal(to_integer(signed(sign_extend28(db_o.d))), pq, "P_Q(" & integer'image(ch) & ")");
    db_i <= NULL_DATA_O;
    wait until clk = '1' and clk'event;

    db_i <= read(std_logic_vector(to_unsigned(16#40#, 8) + to_unsigned(ch*8+4, 8)));
    wait until clk = '1' and clk'event and db_o.ack = '1';
    test_equal(to_integer(signed(sign_extend28(db_o.d))), li, "L_I(" & integer'image(ch) & ")");
    db_i <= NULL_DATA_O;
    wait until clk = '1' and clk'event;

    db_i <= read(std_logic_vector(to_unsigned(16#40#, 8) + to_unsigned(ch*8+5, 8)));
    wait until clk = '1' and clk'event and db_o.ack = '1';
    test_equal(to_integer(signed(sign_extend28(db_o.d))), lq, "L_Q(" & integer'image(ch) & ")");
    db_i <= NULL_DATA_O;
    wait until clk = '1' and clk'event;
  end procedure;

begin
    clk_gen : process
    begin
      if ENDSIM = false then
        clk <= '0';
        wait for 5 ns;
        clk <= '1';
        wait for 5 ns;
      else
        wait;
      end if;
    end process;

    dma_if_chk : process
    variable LI : line;
    begin
      if ENDSIM = false then
          wait until clk = '1' and clk'event;
          if dma.req(6) = '1' then
              write(LI, "DMA req. of ch #" & integer'image(to_integer(unsigned(dma.req(5 downto 0)))));
              writeline(output, LI);
          end if;
      else
        wait;
      end if;
    end process;

  g : configuration work.gpsif_top_sim
    port map (
      clk => clk,
      rst => rst,
      bi => BIST_SCAN_NOP,
      bo => open,
      db_i => db_i,
      db_o => db_o);

  process
    variable write_more : boolean := false;
    file FI        : TEXT open read_mode is "tests/input.txt";
    variable LI    : line;
    variable input : std_logic_vector(31 downto 0);
    variable data  : std_logic_vector(31 downto 0);
    variable input_count : integer := 0;
  begin
    test_plan(36, "gpsif_db_tb");
    wait until clk = '1' and clk'event;
    wait until clk = '0' and clk'event;
    wait until clk = '1' and clk'event;
    wait until clk = '0' and clk'event;
    rst <= '0';

    wait until clk = '1' and clk'event;
    wait until clk = '1' and clk'event;

    -- write SFT
    db_i <= write(x"00", x"00002ba4");
    wait until clk = '1' and clk'event and db_o.ack = '1';
    db_i <= write(x"01", x"00003182");
    wait until clk = '1' and clk'event and db_o.ack = '1';
    db_i <= write(x"02", x"00002e54");
    wait until clk = '1' and clk'event and db_o.ack = '1';
    db_i <= write(x"03", x"00001640");
    wait until clk = '1' and clk'event and db_o.ack = '1';
    db_i <= write(x"04", x"00002a51");
    wait until clk = '1' and clk'event and db_o.ack = '1';
    db_i <= write(x"05", x"00003097");
    wait until clk = '1' and clk'event and db_o.ack = '1';
    db_i <= NULL_DATA_O;

    -- write g2sft
    db_i <= write(x"08", x"00000006");
    wait until clk = '1' and clk'event and db_o.ack = '1';
    db_i <= write(x"09", x"0000041c");
    wait until clk = '1' and clk'event and db_o.ack = '1';
    db_i <= write(x"0a", x"0000080b");
    wait until clk = '1' and clk'event and db_o.ack = '1';
    db_i <= write(x"0b", x"00000c64");
    wait until clk = '1' and clk'event and db_o.ack = '1';
    db_i <= write(x"0c", x"00001200");
    wait until clk = '1' and clk'event and db_o.ack = '1';
    db_i <= write(x"0d", x"000014d2");
    wait until clk = '1' and clk'event and db_o.ack = '1';
    db_i <= NULL_DATA_O;

    -- write PNCO
    db_i <= write(x"10", x"00016058");
    wait until clk = '1' and clk'event and db_o.ack = '1';
    db_i <= write(x"11", x"fffe1f88");
    wait until clk = '1' and clk'event and db_o.ack = '1';
    db_i <= write(x"12", x"0000e038");
    wait until clk = '1' and clk'event and db_o.ack = '1';
    db_i <= write(x"13", x"ffff5fd8");
    wait until clk = '1' and clk'event and db_o.ack = '1';
    db_i <= write(x"14", x"fffbbef0");
    wait until clk = '1' and clk'event and db_o.ack = '1';
    db_i <= write(x"15", x"ffffdff8");
    wait until clk = '1' and clk'event and db_o.ack = '1';

    input_loop: while true loop
      -- loop until status register allows input write
      write_ready: while true loop
        db_i <= read(x"80");
        wait until clk = '1' and clk'event and db_o.ack = '1';
        db_i <= NULL_DATA_O;
        data := db_o.d;
        if data(0) = '1' then
          exit write_ready;
        end if;
      end loop;

      input := x"00000000";
      for j in 0 to 15 loop -- Read 32b data from 16 lines of 2b data
        if endfile(FI) then
          exit input_loop;
        end if;
        readline(FI, LI);
        read(LI, input(31 - 2*j downto 30 - 2*j));
      end loop;

      -- Wait for 20 cycles between writing input data to test delays in input
      -- arrival
      if input_count > 22 then
        for i in 1 to 50 loop
          wait until clk = '1' and clk'event;
        end loop;
      else
        input_count := input_count + 1;
      end if;

      db_i <= write(x"81", input);
      wait until clk = '1' and clk'event and db_o.ack = '1';
      db_i <= NULL_DATA_O;
      wait until clk = '1' and clk'event;
    end loop;
    wait until clk = '1' and clk'event;

    -- Check that same values seen in the waveform at the end of the gpsif_tb
    check_channel(clk, db_i, db_o, 0, 13270, 7002, 19082, 42342, 21452, 25808);
    check_channel(clk, db_i, db_o, 1, 19610, -33416, 28814, -42980, 17464, -26782);
    check_channel(clk, db_i, db_o, 2, 31701, -1218, 39655, 2086, 13683, 578);
    check_channel(clk, db_i, db_o, 3, 18756, 3118, 33526, 1452, 8116, -17806);
    check_channel(clk, db_i, db_o, 4, 41, 16785, -12169, 10099, -9071, 593);
    check_channel(clk, db_i, db_o, 5, -2038, -1740, 8074, 23868, -6866, 22632);
--    check_channel(clk, db_i, db_o, 6, -27648, -18944, -18304, -15872, -5120, -7168);

    wait until clk = '1' and clk'event;
    wait until clk = '1' and clk'event;
    wait until clk = '1' and clk'event;
    test_finished("done");
    ENDSIM := true;
    wait;
  end process;
end architecture;
