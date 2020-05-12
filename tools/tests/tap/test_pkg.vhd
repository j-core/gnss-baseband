-- Copyright © 2010 Wesley J. Landaker <wjl@icecavern.net>
-- 
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.

-- 
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
-- 
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.

-- Output is standard TAP (Test Anything Protocol) version 13
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;

package test_pkg is

  function remove_eol(s : string) return string;
  procedure init;
  procedure test_redirect(filename : string);
  procedure test_plan(tests : natural; directive : string := "");
  procedure test_abort(reason : string);
  procedure test_finished(directive : string := "");
  procedure test_comment (message : string);
  procedure test_comment_fail (actual,expected : std_logic_vector);
  procedure test_pass (description : string := ""; directive : string := "");
  procedure test_fail (description : string := ""; directive : string := "");
  procedure test_ok   (result : boolean; description : string := ""; directive : string := "");
  procedure test_equal(actual, expected : integer; description : string := ""; directive : string := "");

  procedure test_equal(actual, expected : std_logic_vector; description : string := ""; directive : string := "");
  procedure test_equal(actual, expected : std_logic; description : string := ""; directive : string := "");
  function slv(i,s : integer) return std_logic_vector;
  function slv(i : integer) return std_logic_vector;
end package;



package body test_pkg is

  file test_output : text;
  shared variable initialized : boolean := false;
  shared variable have_plan : boolean := false;
  shared variable last_test_number : natural := 0;

  function slv(i,s : integer) return std_logic_vector is
   variable r : std_logic_vector(s-1 downto 0);
 begin
   r := std_logic_vector(to_signed(i, s));
   return r;
 end function slv;

  function slv(i : integer) return std_logic_vector is
 begin
   return slv(i, 32);
 end function slv;
   
  function remove_eol(s : string) return string is
    variable s_no_eol : string(s'range);
  begin
    for i in s'range loop
      case s(i) is
        when LF | CR => s_no_eol(i) := '_';
        when others  => s_no_eol(i) := s(i);
      end case;
    end loop;
    return s_no_eol;
  end function;

  function make_safe (s : string) return string is
    variable s_no_hash : string(s'range);
  begin
    for i in s'range loop
      case s(i) is
        when '#'    => s_no_hash(i) := '_';
        when others => s_no_hash(i) := s(i);
      end case;
    end loop;
    return remove_eol(s_no_hash);
  end function;

  procedure init is
    variable l : line;
  begin
    if initialized then
      return;
    end if;
    initialized := true;
    write(l, string'("TAP version 13"));
    writeline(output, l);
  end procedure;

  procedure test_redirect(filename : string) is
  begin
    init;
  end procedure;

  procedure test_plan(tests : natural; directive : string := "") is
    variable l : line;
  begin
    init;
    have_plan := true;
    write(l, string'("1.."));
    write(l, tests);
    if directive'length > 0 then
      write(l, " # " & remove_eol(directive));
    end if;
    writeline(output, l);
  end procedure;

  procedure test_abort(reason : string) is
    variable l : line;
  begin
    init;
    write(l, "Bail out! " & remove_eol(reason));
    writeline(test_output, l);
    assert false
      report "abort called"
      severity failure;
  end procedure;

  procedure test_finished (directive : string := "") is
  begin
    if not have_plan then
      test_plan(last_test_number, directive);
    elsif directive'length > 0 then
      test_comment("1.." & integer'image(last_test_number) & " # " & directive);
    else
      test_comment("1.." & integer'image(last_test_number));
    end if;
  end procedure;

  procedure test_comment (message : string) is
    variable l : line;
  begin
    init;
    write(l, '#');
    if message'length > 0 then
      write(l, " " & remove_eol(message));
    end if;
    writeline(output, l);
  end procedure;

  procedure test_comment_fail (actual,expected : std_logic_vector) is
    variable l : line;
  begin
    init;
    if actual'length mod 4 = 0 and expected'length mod 4 = 0 then
      write(l, string'("# actual is x"));
      hwrite(l, actual);
      write(l, string'(" expected is x"));
      hwrite(l,expected);
    else
      write(l, string'("# actual is "));
      write(l, actual);
      write(l, string'(" expected is "));
      write(l,expected);
    end if;
    writeline(output, l);
  end procedure;

  procedure result (status : string; description : string; directive : string) is
    variable l : line;
  begin
    init;
    last_test_number := last_test_number + 1;
    write(l, status & " ");
    write(l, last_test_number);
    if description'length > 0 then
      write(l, " " & make_safe(description));
    end if;
    if directive'length > 0 then
      write(l, " # " & remove_eol(directive));
    end if;
    writeline(output, l);
  end procedure;

  procedure test_pass (description : string := ""; directive : string := "") is
  begin
    result("ok", description, directive);
  end procedure;

  procedure test_fail (description : string := ""; directive : string := "") is
  begin
    result("not ok", description, directive);
  end procedure;

  procedure test_ok (result : boolean; description : string := ""; directive : string := "") is
  begin
    if result then
      test_pass(description, directive);
    else
      test_fail(description, directive);
    end if;
  end procedure;

  procedure test_equal(actual, expected : integer; description : string := ""; directive : string := "") is
    variable ok : boolean := actual = expected;
  begin
    test_ok(ok, description, directive);
    if not ok then
      test_comment("actual = " & integer'image(actual) & ", expected = " & integer'image(expected));
    end if;
  end procedure;

  procedure test_equal(actual, expected : std_logic_vector;
                      description : string := ""; directive : string := "") is
    variable ok : boolean := actual = expected;
  begin
    if actual'length /= expected'length then
      test_comment_fail(actual,expected);
      test_comment("vector length mismatch");
      test_ok(false, description, directive);
    else
      test_ok(ok, description, directive);
      if not ok then
        test_comment_fail(actual,expected);
      end if;
    end if;
  end procedure;

  procedure test_equal(actual, expected : std_logic; description : string := ""; directive : string := "") is
    variable ok : boolean := actual = expected;
  begin
    test_ok(ok, description, directive);
  end procedure;

end package body;
