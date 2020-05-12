--------------------------------------------------------------------------------
-- Brief GPSIF Spec.                   Written on Aug. 23, 2017 by Fumio Arakawa
--------------------------------------------------------------------------------
--------- Address map (32b address, 4 byte stride for channel address) ---------
-- abcc0000          : Base address on CPU bus
-- abcc0000 +  ch    : C/A code shift, PNCO inc., DMA channel
-- abcc0020 +  ch    : G2 shift & Acquisition mode, Channel activation
-- abcc0040 +  ch    : PNCO
-- abcc0060          : S/W reset
-- abcc0100 +8*ch +N : Output buffer (N: 0-5 for EI,EQ,PI,PQ,LI,LQ)
-- abcc0200          : GPSIF status
-- abcc0204          : Input buffer from CPU bus

-------------------------------- Bit assignment --------------------------------
-- 1. S/W reset
--    31    : 0
--     8    : bitlink case sample bit mode
--             0: 2 bits/sample. 1: 1 bit sample
--     1- 0 : input mode (
--            00: from I/O port, 01: from CPU bus, 10: from bitlink
--   (Currently, other bits are used to dump signals for debug on FPGA)
-- 2. Channel Initialization
--  1. C/A code shift (direct, inc./plus/minus), PNCO inc., DMA channel
--    31    : direct write of C/A code shift & DMA channel (0: Enable, 1: Disable)
--    30-29 : C/A code shift update type ( NOP, INC, PLS, MNS )
--    28    : PNCO update         (0: Disable, 1: Enable)
--    27    : shift inc. code set (0: Disable, 1: Enable)
--    26-24 : shift inc. code
--           000 : + 1     100 : + 4
--           001 : + 8     101 : -24
--           010 : +16     110 : -16
--           011 : +24     111 : - 8
--    23    : PNCO  inc. code set (0: Disable, 1: Enable)
--    22-20 : PNCO  inc. code
--           000 :   1     100 :  16
--           001 :   2     101 :  32
--           010 :   4     110 :  64
--           011 :   8     111 : 128
--    19-14 : DMA channel
--    13- 0 : C/A code shift (for direct write)
--  2. PNCO direct write
--    28- 0 : PNCO (28 bit signed number, HW ignores bit 31-30)
--  3. G2 shift & Acquisition mode
--    31    : Acquisition mode (0: Disable, 1: Enable)
--     9- 0 : G2 shift
--  4. GPSIF status register
--    29-16 : Channel status (0:IDL, 1:ACQ, 2:RDY, 3:VLD)
--                       23-22 : #3
--         29-28 : #6    21-20 : #2
--         27-26 : #5    19-18 : #1
--         25-24 : #4    17-16 : #0
--    14- 8 : Channel is running or not (0:ready, 1:run)
--                          11 : #3
--            14 : #6       10 : #2
--            13 : #5        9 : #1
--            12 : #4        8 : #0
--        0 : Input buffer status (0:BUSY, 1:FILL)

-------------------------------- control by S/W --------------------------------
-- 1. S/W reset

-- S/W reset initializes GPSIF.
--  - Input mode is specified by bit 31, and 0 & 1 correspond to from I/O port & CPU bus.
--  - All of channels are set to IDL.
--  - Input buffer is cleared by initializing read scope & write pointers.
--  - Reset 1-ms counter that counts number of data of 1023*16 for 1 ms.
--   (The counter consists of common higher 11-bit one that skips 1023*2 and 1023*2+1,
--    and lower 3-bit one just to count 8 for each 8 data processing.)

-- 2. Each Channel initialization and updates

-- For Tracking
-- 1) Direct write of C/A code shift of acquired satellite
--    The value is the 1-ms counter value corresponding to the last data of the 1-ms period of the acquired satellite.
-- 2) Direct write of PNCO of the acquired satellite
-- 3) Write of G2 shift of the acquired satellite w/ disabling acquisition. The write makes the channel RDY.
--    The initialized channel starts running after the higher 11-bits of the C/A code shift and the 1-ms counter match.
-- 4) Write PLS/MNS mode if C/A code shift is to be adjusted with +-1
--     (H/W adjust the shift as early as possible w/ keeping carrier NCO phase.)
-- 5) Write new PNCO if it is to be adjusted.
--     (H/W changes the PNCO as early as possible. The carrier NCO phase is naturally kept.)

-- For Serial Acquisition (Not use acquisition mode)
-- 1) Direct write of initial C/A code shift of each channel
-- 2) Direct write of initial PNCO
-- 3) Write of G2 shift of a satellite w/ disabling acquisition. The write makes the channel RDY.
-- 4) Increment PNCO to scan Doppler shift range of +-10 kHz
--     (H/W initializes carrier NCO phase to 0 when it increment the PNCO.
--      Then, each evaluation starts w/ the same carrier NCO phase.)
-- 5) Increment C/A code shift to scan all the shift range
--     (H/W increment the PNCO and C/A code shift at the 1-ms boundary of the channel.
--      So, the control must be done during the last 1-ms evaluation of the channel.)
-- 6) Write of G2 shift of another satellite w/ disabling acquisition.

-- For FFT Acquisition (Use acquisition mode)
-- 1) Direct write of initial PNCO
-- 2) Set acquisition mode enable. The write makes the channel RDY. (G2 shift is not used)
-- 3) The initialized channel starts running when the 1-ms counter becomes 0.
--     (The initial values of C/A code shift and 1-ms counter matches, and the next counter value is 0.)
-- 4) Increment PNCO to scan Doppler shift range of +-10 kHz

-- 3. Data input

-- From I/O port
-- 1) Write data w/ setting bit 31 to be 0 to S/W reset address.
--    Default input mode is to use I/O port. Nothing is to be done after H/W reset.
-- From CPU bus
-- 1) Write data w/ setting bit 31 to be 1 to S/W reset address.
-- 2) CPU bus master reads GPSIF status register to check input buffer status BUSY or not, and
--    wait until the status becomes FILL.
-- 3) After it becomes FILL, the CPU bus master writes 16*32 bits of data.
--    Input cycles must be more than 56 (7ch*8cycles) per 16 CPU bus operations for 7 channel case.
--    Is is safe to write data every 4 cycles or less. (4*16 = 64 > 56)

-- 4. Read evaluation result

-- By CPU bus master
-- 1) CPU bus master checks each channel status by reading GPSIF status register.
-- 2) If the status is VLD, it reads valid results in output buffers.
--  - The results of each channel are six data of EI,EQ,PI,PQ,LI, and LQ.
--    H/W changes the status to RDY after reading the LQ.
--    So, the LQ should be read last.
--  - GPSIF has output buffers that is separated from accumulating buffers.
--    Then, the results in the output buffers are valid for 1 ms.
--  - H/W set the fail flag of each channel
--    when H/W observes a read access while the status is RDY (read-before-write),
--    or H/W writes a new result while the status is VLD (write-before-read).
--     (Currently, the fail bits are not assigned to GPSIF status register yet.)
-- By DMAC
-- 1) When DMAC get the DMA channel number from GPSIF, it reads the results.
--  - GPSIF output the DMA channel assigned to each channel to DMAC when the results of the channel become valid.
--    So, the DMAC does not have to check the output validity.

--------------------------------- H/W behavior ---------------------------------
-- 0. H/W reset
-- H/W reset initializes GPSIF. Default input mode is from I/O port. The others are the same as the S/W reset.

-- 2. Input buffer write
-- From I/O port, GPSIF has a buffer consisting of 4 sets of 8 data. The write uses a special clock synchronized
-- to the I/O port. So, the write pointer and write enable signal are clocked by the special clock. The GPSIF
-- processing is faster than the input write. So, the write is always possible. The higher 2 bits of the write
-- pointer is passed to main body of the GPSIF. For an asynchronous pass, the 2 bits changes with a sequence of
-- 00 => 01 => 11 => 10 => 00. Then, the 2-bit code is always correct even when the signal change timing is
-- slightly different. (Avoiding 01 => 10 or 10 => 01 is important.)

-- From CPU bus, the GPSIF has a buffer consisting of 32 sets of 8 data assuming a 512 bit packet for the data.
-- GPSIF clear the input buffer status bit of the GPSIF status register to show it is BUSY when the write pointer
-- returns to 0, until read scope pointer points the last scope. CPU bus master must wait until the bit is set
-- for writing new input data. Since the last scope consists of the last and first 8 data and the processing of
-- the scope requires 7*8 = 56 cycles, and 512 bit buffer filling takes 512/32 = 16 CPU bus operations, the bus
-- master must not issue the last input data write within the 56 cycles. Is is safe to write data every 4 cycles
-- or less. Assuming future data input from ring bus, it takes 512/8 = 64 ring bus cycles or more, and no
-- restriction is necessary to keep the input data.

-- 3. Input buffer read by GPSIF H/W
-- Input buffer is divided into multiple sets of 8 data, and two consecutive sets are specified by the read scope
-- pointer as a current input data scope. Then, a 4-bit read pointer that is lower 4 bits of C/A code shift of each
-- channel can specify any 8 data in the scope. So, all the channels can share the input buffer with different C/A
-- code shift. However, this is not true when the C/A code shift changes. The direct write is for initialization,
-- and it must be done while the channel is IDL. The change by INC/PLS mode requires a scope skip to ignore data
-- between the last and new 1 ms. For negative INC, HW skips data of 1022*16 + (negative)INC. If the new shift can
-- use the same scope, HW does not skip the scope. For MNS mode, HW uses the same scope twice if the scope is
-- changed. If the read scope reaches to the writing entry of the input buffer, GPSIF stall processing of the data.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use work.gpsif_pack.all;
use work.gpsif_sub_pack.all;
use work.cpu2j0_pack.all;
use work.ring_bus_pack.all;
use work.rbus_pack.all;
use work.bist_pack.all;
use work.util_pack.all;
use work.attr_pack.all;

entity gpsif_top is
  generic (   GPSIF_NC : integer := 7;
         ANGLE_INI_OLD : boolean := false );
  port (
    clk     : in std_logic;
    rst     : in std_logic;
    gps_clk : in std_logic;
    gps_d   : in std_logic_vector(1 downto 0);
    ppsdds  : in std_logic;
    blgps   : in blgps_t;
    dma     : out dma_req_t;
    intrpt  : out std_logic;
    bi      : in  bist_scan_t;
    bo      : out bist_scan_t;
    ring_i  : in  rbus_9b;
    ring_o  : out rbus_9b;
    bus_clk : in std_logic;
    db_i    : in  cpu_data_o_t;
    db_o    : out cpu_data_i_t );
  attribute soc_port_irq of intrpt : signal is true;
end entity;

architecture arch of gpsif_top is
  -- gpsif ports
  signal tgt_o    : cpu_data_i_t;
  signal tgt_i    : gpsif_tgt_i_t;
  signal dev_i    : rbus_dev_i_t;
  signal dev_o    : rbus_dev_o_t;
  signal buf_io   : gpsif_buf_i_t;
  signal ra_io    : gpsif_buf_ct_t;
  signal buf_bus  : gpsif_i_t;
  signal buf_waf  : gpsif_buf_rw_t;
  signal time_i   : gpsif_time_t;
  signal gpsif_o  : gpsif_o_t;
  signal bs0      : bist_scan_t;
  signal gps_clkbf : std_logic;
  signal ring_o_dbg : rbus_9b;

begin
    ring_o <= ring_o_dbg;
    g : gpsif
    generic map ( GPSIF_NC => GPSIF_NC,
             ANGLE_INI_OLD => ANGLE_INI_OLD )
    port map (
        clk      => clk,
        rst      => rst,
        bi       => bi,
        bo       => bs0,
        ring_i   => ring_i,     -- to monitor ring bus
        ring_o   => ring_o_dbg, -- to monitor ring bus
        tgt_o    => tgt_o,
        tgt_i    => tgt_i,
        dev_o    => dev_o, -- output to ring bus
        dev_i    => dev_i, -- input from ring bus
        buf_io   => buf_io, -- wp(write pointer), sgin, magnitude
        time_i   => time_i,
        ra_io    => ra_io,
        buf_bus  => buf_bus,
        gpsif_o  => gpsif_o, -- rp(read pointer)
        dma      => dma
    );
    a : rbus_adp
    port map (
        clk      => clk,
        rst      => rst,
--        sw_rst   => gpsif_o.rst,
        ring_i   => ring_i,
--        ring_o   => ring_o,
        ring_o   => ring_o_dbg,
        dev_o    => dev_o,
        dev_i    => dev_i
    );
    b : gpsif_buf
    port map (
        clk      => clk,
        rst      => rst,
        gps_clk  => gps_clkbf,
        gps_d    => gps_d,
        a        => ra_io,
        y        => buf_io,
        waf      => buf_waf
    );
    c : gpsif_db
      port map (
        clk      => bus_clk,
        rst      => rst,
        bi       => bs0,
        bo       => bo,
        db_i     => db_i,
        db_o     => db_o,
        tgt_o    => tgt_o,
        tgt_i    => tgt_i,
        time_i   => time_i,
        intrpt   => intrpt,
        a        => gpsif_o,
        y        => buf_bus
    );
    d : global_buffer
      port map (
        i        => gps_clk,
        o        => gps_clkbf
    );
    e : gpsif_time
    port map (
        clk      => clk,
        rst      => rst,
        gps_clk  => gps_clkbf,
        gps_d    => gps_d,
        a        => ra_io,
        waf      => buf_waf,
        ppsdds   => ppsdds,
        blgps    => blgps,
        y        => time_i
    );

end architecture;
