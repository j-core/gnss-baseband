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
use work.gpsif_sub_pack.all;

--         Code Freq.(Fco):                1.023 MHz, 1023 / 1.023MHz = 1 ms
--      Carrier Freq.(Fc ):  1540*Fco = 1575.42  MHz (used by analog part)
--    1st Local Freq.(Fl ): 96*16*Fco = 1571.328 MHz (used by analog part)
--     Sampling Freq.(Fs ):    16*Fco =   16.368 MHz, dt = 1/Fs, 16,368 samples/ms
-- Intermediate Freq.(IF ):     4*Fco =    4.092 MHz, Fc - Fl

-- Doppler Shift: Max +-10kHz/s, +-200Hz/20ms

package gpsif_pack is

constant GPSIF_TARGET_BUS_WIDTH : natural := 32;

constant GPSIF_NC_BITS : natural :=  3;
constant GPSIF_NC_MAX  : natural :=  6;
constant GPSIF_ND_MAX  : natural := 31;
constant GPSIF_RD_MAX  : natural :=  7; -- fixed to 7 now
constant GPSIF_RW_MAX  : natural := (GPSIF_ND_MAX+1)*(GPSIF_RD_MAX+1)-1;
constant GPSIF_WA_MAX  : natural := (GPSIF_RW_MAX+1)/8-1;
constant GPSIF_CA_BITS : natural := 10;
constant GPSIF_SFT_RNG : natural := 2**(GPSIF_CA_BITS+4);

function itov(X, N : integer) return std_logic_vector;
function vtoi(X : std_logic_vector) return integer;
function vtoui(X : std_logic_vector) return integer;
function to_bit(b : boolean) return std_logic;

--- sincos -------------------------------------------------------------------
constant GPSIF_ANGLE_BITS : natural :=30; -- More than 1 rotation can be discarded.
constant GPSIF_ANGLE_INDX : natural := 6; -- scaled by 2**ANGLE_INDX/2PI (PI=>32, range is 0 to 63)
constant GPSIF_SINCOS_MAX : natural := 5; -- scaled by 2**(SINCOSBITS-1) ( 1=>32, range is 0 to 32)
constant GPSIF_CRRMIX_MAX : natural := GPSIF_SINCOS_MAX+ 2; -- (-32*3   to 32*3) to signed here
constant GPSIF_SUMREG_MAX : natural := GPSIF_CRRMIX_MAX+ 3; -- (-32*3*8 to 32*3*8)
constant GPSIF_ACMREG_MAX : natural := GPSIF_SUMREG_MAX+11; -- 1ms*16*1023samples

subtype gpsif_angle_reg_t is std_logic_vector(GPSIF_ANGLE_BITS-1 downto 0);
subtype gpsif_angle_t     is           ufixed(GPSIF_ANGLE_BITS-1 downto 0);
subtype gpsif_angle_a_t   is integer range 0 to GPSIF_NC_MAX;
subtype gpsif_carrmix_t is integer range -(2**GPSIF_CRRMIX_MAX) to 2**GPSIF_CRRMIX_MAX; -- -96 to 96

type gpsif_carrmix_o_t is record
  i,q : gpsif_carrmix_t; -- -96 to 96 (32*3 = 96, X"A0" to X"60")
end record;

type gpsif_carrmix_i_t is record
  angle : ufixed(GPSIF_ANGLE_INDX-1 downto 0);
  d     : std_logic_vector(       1 downto 0); -- 00: 1, 01: 3, 10:-1, 11:-3
end record;

function gpsif_carrmix(a : gpsif_carrmix_i_t)  return gpsif_carrmix_o_t;
function gpsif_sin_6b (a : ufixed(3 downto 0)) return ufixed;
function gpsif_mul    (a : ufixed(1 downto 0); b : std_logic_vector(1 downto 0);
                     s,c : ufixed(GPSIF_SINCOS_MAX downto 0)) return gpsif_carrmix_t;

--- sumreg --------------------------------------------------------------------
subtype gpsif_sum_d_t is integer range -(2**GPSIF_SUMREG_MAX) to 2**GPSIF_SUMREG_MAX; -- -768 to 768 (X"500" to X"300")

type gpsif_sum_t is record
   i,q : gpsif_sum_d_t;
end record;

--- C/A code -------------------------------------------------------------------
subtype gpsif_sftca_reg_t is std_logic_vector(GPSIF_CA_BITS*2-1 downto 0);
subtype gpsif_sftca_a_t   is integer range 0 to GPSIF_NC_MAX * 2 + 1;
subtype gpsif_sft_t       is ufixed(GPSIF_CA_BITS+3 downto 0);
subtype gpsif_cnt1ms_t    is ufixed(GPSIF_CA_BITS   downto 0);

--- acmreg --------------------------------------------------------------------
constant GPSIF_REG_PER_CH : natural := 6;
constant GPSIF_ACMREG_NUM : natural := (GPSIF_NC_MAX+1)*GPSIF_REG_PER_CH;

subtype gpsif_acm_a_t   is integer range 0 to GPSIF_ACMREG_NUM/2 -1;
subtype gpsif_acm_d_t   is integer range -(2**GPSIF_ACMREG_MAX) to 2**GPSIF_ACMREG_MAX-1;
subtype gpsif_acm_reg_t is std_logic_vector  (GPSIF_ACMREG_MAX downto 0);

--- regfile --------------------------------------------------------------------
type gpsif_regin_angle_t is record
  wd   : gpsif_angle_reg_t;
  we   : std_logic;
  a    : gpsif_angle_a_t;
end record;

type gpsif_regin_sftca_t is record
  wd   : gpsif_sftca_reg_t;
  we   : std_logic;
  wa   : gpsif_sftca_a_t;
  ra   : gpsif_sftca_a_t;
end record;

type gpsif_regin_acm_t is record
  a    : gpsif_acm_a_t;
  wd   : gpsif_acm_reg_t;
  we   : std_logic;
  bs   : std_logic;
end record;

type gpsif_regfile_i_t is record
  pnco  : gpsif_regin_angle_t;
  angle : gpsif_regin_angle_t;
  sftca : gpsif_regin_sftca_t;
  sftca_obs : gpsif_regin_sftca_t;
  acm   : gpsif_regin_acm_t;
  buf   : gpsif_regin_acm_t;
end record;

type gpsif_regfile_o_t is record
  pnco  : gpsif_angle_reg_t;
  angle : gpsif_angle_reg_t;
  sftca : gpsif_sftca_reg_t;
  sftca_obsv : gpsif_sftca_reg_t;
  acm   : gpsif_acm_reg_t;
  buf   : gpsif_acm_reg_t;
end record;

component gpsif_regfile is port (
  clk : in  std_logic;
  rst : in  std_logic;
  bi  : in  bist_scan_t;
  bo  : out bist_scan_t;
  a   : in  gpsif_regfile_i_t;
  y   : out gpsif_regfile_o_t);
end component;

--- gpsif --------------------------------------------------------------------
subtype gpsif_rw_t is integer range 0 to GPSIF_RW_MAX;
subtype gpsif_wa_t is integer range 0 to GPSIF_WA_MAX;

subtype gpsif_buf_rw_t is integer range 0 to 31;
subtype gpsif_buf_wa_t is integer range 0 to  3;
subtype gpsif_int_t    is std_logic_vector(3 downto 0);

type gpsif_cntl_t is record
  vld    : std_logic;
  ovr    : std_logic;
  bndry  : boolean;
  err    : boolean;
  lst    : boolean;
end record;
type gpsif_o_t is record
  ra     : gpsif_rw_t;
  sr     : std_logic_vector(21 downto 0);
  cntl   : gpsif_cntl_t;
  odd    : boolean;
  rst    : boolean;
  int_en : gpsif_int_t;
end record;

type gpsif_buf_ct_t is record
  ra    : gpsif_buf_rw_t;
  inittm : std_logic;
  blsp1bit : std_logic;
  blsp2bit : std_logic;
end record;
type gpsif_time_t is record
  seq    : std_logic_vector(7 downto 0);
  nsec   : unsigned(23 downto 0);
  setnsec : std_logic;
  mscnt   : std_logic;
  d       : std_logic_vector(1 downto 0);
  wa      : gpsif_wa_t;
end record;

-- sft & pnco update command format
-- 31    : write dma channel & sft value
-- 30-29 : sft  value update type ( NOP, INC, PLS, MNS )
-- 28    : pnco value     inc. or not
-- 27    : sft  inc. code set  or not
-- 26-24 : sft  inc. code (not a value itself)
-- 23    : pnco inc. code set  or not
-- 22-20 : pnco inc. code (not a value itself)
-- 19-14 : dma channel
-- 13- 0 : sft

subtype gpsif_sft_fld_t is std_logic_vector(30 downto 29);
subtype gpsif_sft_inc_t is std_logic_vector(26 downto 24);
subtype gpsif_pncoinc_t is std_logic_vector(22 downto 20);

type gpsif_src_t      is ( IO_PIN, CPU_BUS, BITL_BUS1, BITL_BUS2 );
type gpsif_sft_typ_t  is ( NOP, pad, SKP, AGN );
type gpsif_sft_chg_t  is ( NOP, INC, PLS, MNS );
-- Channel mode encoding
-- (2): TRK or not
-- (1): VLD ODD, IDL or ACQ
-- (0): VLD EVN
-- 00-: IDL, 01-: ACQ, 100: TRK & not VLD, 101: TRK & VLD EVN, 110: TRK & VLD ODD, 111: TRK & VLD both (fail to read)
type gpsif_st_t is record
  mode : std_logic_vector(2 downto 0);
  run  : boolean;
  pnco : boolean; -- pnco increment by this.inc
  sft  : gpsif_sft_chg_t;
end record;
type gpsif_sft_st_t is record
  chg : gpsif_sft_chg_t;
  typ : gpsif_sft_typ_t;
  ext : boolean;
end record;
type gpsif_ch_st_t is array (0 to GPSIF_NC_MAX) of gpsif_st_t;
type gpsif_inc_t is record
  sft  : std_logic_vector(2 downto 0);
  pnco : std_logic_vector(2 downto 0);
end record;
subtype gpsif_ch_t is std_logic_vector(GPSIF_NC_BITS-1 downto 0);
constant GPSIF_NC_END : gpsif_ch_t := (others => '0');
constant DBG_2MS_MAX : natural := 2**12 -1;
subtype gpsif_dbg2ms_t is integer range 0 to DBG_2MS_MAX;
type gpsif_dbg_st_t is ( DBG_IDL, DBG_RDY, DBG_RUN );

type gpsif_reg_t is record
-- config
  src     : gpsif_src_t;
  src_bls : std_logic; -- 0:2bits/spl 1:1bit/spl
  inc     : gpsif_inc_t;
  int_en  : gpsif_int_t;
-- state
  sft     : gpsif_sft_st_t;
  st      : gpsif_ch_st_t;
-- delayed info.
  ready   : boolean; -- input data is ready (scope data is stable)
  bndry   : boolean; -- at 1ms boundary of carier mix channel
  even    : boolean; -- 1st half of 16 cycles
  acm_lst : boolean; -- at 1ms boundary of accumulating channel
  acm_en  : boolean; -- enable accumulation
  scp_chg : boolean; -- ND scope is changed by SHIFT change
  rst_en  : boolean; -- SW reset enable
-- counters
  ch      : gpsif_ch_t;
  rd      : integer range 0 to GPSIF_RD_MAX;
  nd      : integer range 0 to GPSIF_ND_MAX;
  cnt1ms  : gpsif_cnt1ms_t;
  odd_ms  : integer range 0 to 1; -- even/odd ms
-- latched values
  sum  : gpsif_sum_t;
  add  : gpsif_sum_t;
  code : std_logic_vector(2 downto 0);
-- output
  dma_req : std_logic_vector(DMA_CH_NUM_LOG downto 0);
  ack     : std_logic;
  ra      : gpsif_rw_t;
  inittm  : std_logic_vector(1 downto 0);
-- for debug
  dbg_st   : gpsif_dbg_st_t;
  dbg_strt : integer range 0 to 2**24 -1;
  dbg_a    : integer range 0 to 255;
  dbg2ms   : gpsif_dbg2ms_t;
end record;

constant GPSIF_REG_RESET : gpsif_reg_t := (
    src     => IO_PIN, src_bls => '0',
    inc     => (others => (others => '0')), int_en => (others => '0'),
    st      => (others => (mode => (others => '0'), sft => NOP, pnco => false, run => false)),
    sft     => (chg => NOP, typ => NOP, ext => false),
    ready   => false, bndry  => false, even    => false, acm_lst => false, acm_en  => false,
    scp_chg => false, rst_en => false,
    ch      =>  GPSIF_NC_END,
    rd      =>  GPSIF_RD_MAX,
    nd      =>  GPSIF_ND_MAX,
    cnt1ms  => (1 => '0', others => '1'), -- 2045 = 7fd
    odd_ms  =>  1, -- start from all 1
    sum     => (others => 0),
    add     => (others => 0),
    code    => (others => '0'),
    dma_req => (others => '0'),
    ack     => '0',
    ra      => GPSIF_RW_MAX,
    inittm  => (others => '0'),
    dbg_st  => DBG_IDL, dbg_strt => 0, dbg_a => 0, dbg2ms => DBG_2MS_MAX );

type gpsif_i_t is record
  d     : std_logic_vector(1 downto 0);
  wa    : gpsif_wa_t;
end record;
type gpsif_tgt_i_t is record
  en,wr: std_logic;
     a : std_logic_vector( 9 downto 2);
     d : std_logic_vector(31 downto 0);
end record;
type gpsif_tgt_reg_t is record -- for slower bus_clk than clk
     wr: std_logic;
     a : std_logic_vector( 9 downto 2);
     d : std_logic_vector(31 downto 0);
end record;
type gpsif_buf_i_t is record
  d     : std_logic_vector(1 downto 0);
  wa    : gpsif_buf_wa_t;
end record;

type gpsif_buf_t is array (0 to 31) of std_logic_vector(1 downto 0);

type gpsif_time_rt_t is record
  nsec     : unsigned (23 downto 0);
  nsec_cap : unsigned (23 downto 0);
  round_s  : integer range 0 to 20;
  round_l  : integer range 0 to 2386;
  pps_dly  : std_logic_vector (3 downto 0);
  inittm   : std_logic;
  cnt1ms_g : gpsif_cnt1ms_t;
  cnt1msup_g : std_logic;
end record;
type gpsif_buf_reg_t is record
  d      : gpsif_buf_t;
  wa     : gpsif_buf_rw_t;
end record;
type gpsif_time_reg_t is record
  rt     : gpsif_time_rt_t;
end record;
type gpsif_buf_sync_t is record
  wa_dly : gpsif_buf_wa_t;
  wa_out : gpsif_buf_wa_t;
end record;
type gpsif_time_sync_t is record
  ppss_dly : std_logic_vector (2 downto 0);
  nsec     : unsigned (23 downto 0);
  cnt1msup_g : std_logic;
  setnsec  : std_logic;
  packetwd : std_logic_vector (15 downto 0);
  packetwa : integer range 0 to 31;
  packetwe : std_logic;
  wa_comm     : integer range 0 to 64; -- 2bit sample max 32, 1 bit sample max 64
  wa_commwait : integer range 0 to 63;
  inittmc1 : std_logic_vector(1 downto 0);
  inittmc2 : integer range 0 to 64;
  inittmc3  : std_logic;
  pon_state : std_logic;
  rt     : gpsif_time_rt_t;
end record;

constant gpsif_time_rt_RESET : gpsif_time_rt_t := (nsec => (others => '0'),
  nsec_cap => (others => '0'), round_s => 0, round_l => 0, pps_dly => "0000",
  inittm => '0', cnt1ms_g => (others => '0'), cnt1msup_g => '0' );
constant gpsif_buf_reg_RESET  : gpsif_buf_reg_t  := (d => (others => (others => '0')), wa => 0 );
constant gpsif_buf_sync_RESET : gpsif_buf_sync_t := (wa_dly => 0, wa_out => 0);
constant gpsif_time_reg_RESET  : gpsif_time_reg_t  := (rt => gpsif_time_rt_RESET );
constant gpsif_time_sync_RESET : gpsif_time_sync_t := (ppss_dly => "000",
  nsec => (others => '0'), cnt1msup_g => '0', setnsec => '0',
  packetwd => x"0000", packetwa => 31, packetwe => '1',
  wa_comm => 64, wa_commwait => 0 ,
  inittmc1 => "00", inittmc2 => 0, inittmc3 => '0', pon_state => '1',
  rt => gpsif_time_rt_RESET );

component gpsif_buf is port (
   clk : in std_logic;
   rst : in std_logic;
   -- port
   gps_clk : in std_logic;
   gps_d   : in std_logic_vector(1 downto 0);
   a       : in  gpsif_buf_ct_t;
   y       : out gpsif_buf_i_t;
   waf     : out gpsif_buf_rw_t );
end component;

component gpsif_time is port (
   clk : in std_logic;
   rst : in std_logic;
   -- port
   gps_clk : in std_logic;
   gps_d   : in std_logic_vector(1 downto 0);
   a       : in  gpsif_buf_ct_t;
   waf     : in  gpsif_buf_rw_t;
   ppsdds  : in  std_logic;
   blgps   : in  blgps_t;
   y       : out gpsif_time_t );
end component;

component gpsif is
generic ( GPSIF_NC : integer := 7;
     ANGLE_INI_OLD : boolean := false );
port (
  clk     : in  std_logic;
  rst     : in  std_logic;
  bi      : in  bist_scan_t;
  bo      : out bist_scan_t;
  ring_i  : in  rbus_9b; -- to monitor ring bus
  ring_o  : in  rbus_9b; -- to monitor ring bus
  tgt_o   : out cpu_data_i_t;
  tgt_i   : in  gpsif_tgt_i_t;
  dev_o   : out rbus_dev_o_t;
  dev_i   : in  rbus_dev_i_t;
  buf_io  : in  gpsif_buf_i_t;
  time_i  : in  gpsif_time_t;
  ra_io   : out gpsif_buf_ct_t;
  buf_bus : in  gpsif_i_t;
  gpsif_o : out gpsif_o_t;
  dma     : out dma_req_t );
end component;

component gpsif_db is port (
  clk     : in  std_logic;
  rst     : in  std_logic;
  bi      : in  bist_scan_t;
  bo      : out bist_scan_t;
  db_i    : in  cpu_data_o_t;
  db_o    : out cpu_data_i_t;
  tgt_o   : in  cpu_data_i_t;
  tgt_i   : out gpsif_tgt_i_t;
  time_i  : in  gpsif_time_t;
  intrpt  : out std_logic;
  a       : in  gpsif_o_t;
  y       : out gpsif_i_t);
end component;

end package;

package body gpsif_pack is

function itov(X, N : integer) return std_logic_vector is
begin
  return std_logic_vector(to_signed(X,N));
end itov;

function vtoi(X : std_logic_vector) return integer is
variable v : std_logic_vector(X'high - X'low downto 0) := X;
begin
  return to_integer(signed(v));
end vtoi;

function vtoui(X : std_logic_vector) return integer is
variable v : std_logic_vector(X'high - X'low downto 0) := X;
begin
  return to_integer(unsigned(v));
end vtoui;
function to_bit(b : boolean) return std_logic is
begin
  if b then return '1';
  else      return '0'; end if;
end to_bit;

function gpsif_carrmix(a : gpsif_carrmix_i_t) return gpsif_carrmix_o_t is
   alias     a_q : ufixed(1 downto 0) is a.angle(a.angle'high downto a.angle'high-1);
   variable ca_q : ufixed(2 downto 0);
   alias     a_1 : ufixed(a.angle'high-2 downto 0) is a.angle(a.angle'high-2 downto 0); -- 1st quadrant angle
   variable ca_1 : ufixed(a.angle'high   downto 0);
   variable y    : gpsif_carrmix_o_t;
   variable s, c : ufixed(GPSIF_SINCOS_MAX downto 0);
begin
   ca_q := 1    + a_q;
   ca_1 := "00" & a_1;
   ca_1 := 2**a_1'length - ca_1(a_1'length downto 0);

   s := gpsif_sin_6b( a_1); -- sin of 1st quadrant
   c := gpsif_sin_6b(ca_1(a_1'range)); -- cos(a_1) = sin(scaled(PI/2) - a_1) = sin(ca_1)
   if ca_1(ca_1'high-1)='1' then c := "100000"; -- to make cos(0) := 32
   end if;
   y.i := gpsif_mul( a_q,            a.d, s, c); --  c is sin of 2nd quadrant
   y.q := gpsif_mul(ca_q(a_q'range), a.d, s, c);
   return y;
end gpsif_carrmix;

function gpsif_sin_6b(a : ufixed(3 downto 0)) return ufixed is

-- special to 6b output & 4b angle of 1st quadrant
-- angle : 0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15
-- sin   : 0  3  6  9 12 15 18 21 23 25 27 29 30 31 32 32
-- cos   : 0 32 32 31 30 29 27 25 23 21 18 15 12  9  6  3 : sin(16 - angle), cos(0) must be corrected to 32 after the function.

variable x1,x2 : ufixed(4 downto 0);
variable y     : ufixed(5 downto 0);
begin
   if    a(3)='0' then x1 := a & '0'; x2 := "0" & a; -- 2x + x = 3x
   elsif a(2)='0' then x1 := a & '0'; x2 := "00111"; -- 2x + 7
   elsif a(1)='0' then x1 := "10010"; x2 := "0" & a; -- 18 + x
   else                x1 := "10010"; x2 := "01110"; -- 18 +14 = 32
   end if;
   y := x1 + x2;
   return y;
end gpsif_sin_6b;


function gpsif_mul(a : ufixed(1 downto 0); b : std_logic_vector(1 downto 0);
                s, c : ufixed(GPSIF_SINCOS_MAX downto 0)) return gpsif_carrmix_t is

-- quadrant I  II  III IV
-- sin      s   c  -s  -c : s is sin of 1st quadrant
-- cos      c  -s  -c   s : c is cos of 1st quadrant

  variable sc,sc4,y : ufixed(GPSIF_CRRMIX_MAX downto 0);
  variable ci,dummy : std_logic;
begin
  ci := '1'; -- for other than *(+1) case
  case a(0) is
    when '0' => sc := ("00" & s); sc4 := (s & "00"); -- 1st, 3rd quadrant
    when '1' => sc := ("00" & c); sc4 := (c & "00"); -- 2nd, 4th quadrant
    when others =>
  end case;
  case (a(1) xor b(1)) is
    when '0' => -- same sign
      case b(0) is
        when '0' => ci := '0';    sc4 := (others => '0'); -- *(+1)
        when '1' => sc := not sc;                         -- *(+3) ( 3 =  4 - 1)
        when others =>
      end case;
    when '1' => -- different sign
      case b(0) is
        when '0' => sc := not sc; sc4 := (others => '0'); -- *(-1)
        when '1' =>               sc4 := not sc4;         -- *(-3) (-3 = -4 + 1)
        when others =>
      end case;
    when others =>
  end case;
  add_carry(sc, sc4, ci, y, dummy);
  return vtoi(to_slv(y));
end gpsif_mul;

end gpsif_pack;
