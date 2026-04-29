-- Automatically generated VHDL-93
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;
use std.textio.all;
use work.all;
use work.i2s_to_stream_types.all;

entity i2s_to_stream is
  port(-- clock
       clk            : in std_logic;
       -- reset
       resetn         : in std_logic;
       -- clock
       bclk           : in std_logic;
       -- reset
       i2s_rst        : in std_logic;
       lrclk          : in boolean;
       si             : in std_logic;
       axis_hp_tdata  : in std_logic_vector(47 downto 0);
       axis_hp_tvalid : in boolean;
       axis_li_tready : in boolean;
       so             : out std_logic;
       axis_hp_tready : out boolean;
       axis_li_tdata  : out std_logic_vector(47 downto 0);
       axis_li_tvalid : out boolean;
       axis_li_tlast  : out boolean);
end;

architecture structural of i2s_to_stream is
  -- src/ADAU1761.hs:82:1-9
  signal sampleCount               : unsigned(14 downto 0) := to_unsigned(0,15);
  -- src/ADAU1761.hs:82:1-9
  signal li_valid                  : boolean;
  -- src/ADAU1761.hs:82:1-9
  signal x1                        : signed(23 downto 0);
  -- src/ADAU1761.hs:82:1-9
  signal y                         : signed(23 downto 0);
  -- src/I2S.hs:(31,1)-(35,19)
  signal \c$isEof_app_arg\         : boolean := false;
  -- src/I2S.hs:(31,1)-(35,19)
  signal \c$f1_app_arg\            : unsigned(5 downto 0) := to_unsigned(0,6);
  signal result_0                  : unsigned(5 downto 0);
  signal \c$app_arg\               : i2s_to_stream_types.array_of_std_logic(0 to 23);
  signal \c$app_arg_0\             : i2s_to_stream_types.array_of_std_logic_vector_1(0 to 23);
  signal \c$app_arg_1\             : i2s_to_stream_types.array_of_std_logic(0 to 23);
  signal \c$app_arg_2\             : i2s_to_stream_types.array_of_std_logic_vector_1(0 to 23);
  signal result_1                  : i2s_to_stream_types.array_of_std_logic(0 to 63);
  signal result_2                  : std_logic;
  -- src/I2S.hs:(31,1)-(35,19)
  signal p                         : i2s_to_stream_types.Tup2 := (Tup2_sel0_signed_0 => to_signed(0,24), Tup2_sel1_signed_1 => to_signed(0,24));
  -- src/I2S.hs:(31,1)-(35,19)
  signal f1                        : unsigned(5 downto 0);
  -- src/I2S.hs:(31,1)-(35,19)
  signal isEof                     : boolean;
  signal result_3                  : i2s_to_stream_types.Tup3;
  signal \c$case_scrut\            : i2s_to_stream_types.Tup2_0;
  signal \c$app_arg_3\             : i2s_to_stream_types.Tup2;
  signal val                       : i2s_to_stream_types.Tup2;
  signal \c$app_arg_4\             : i2s_to_stream_types.index_4;
  signal addr                      : i2s_to_stream_types.index_4;
  signal addr_0                    : i2s_to_stream_types.index_4;
  signal \c$app_arg_5\             : boolean;
  signal \c$app_arg_6\             : boolean;
  signal \c$app_arg_7\             : i2s_to_stream_types.Tup2;
  signal val_0                     : i2s_to_stream_types.Tup2;
  signal \c$app_arg_8\             : i2s_to_stream_types.index_4;
  signal addr_1                    : i2s_to_stream_types.index_4;
  signal addr_2                    : i2s_to_stream_types.index_4;
  signal \c$app_arg_9\             : boolean;
  signal \c$app_arg_10\            : boolean;
  signal t                         : i2s_to_stream_types.RamOp;
  signal result_4                  : i2s_to_stream_types.RamOp;
  signal b                         : boolean;
  signal ds1                       : i2s_to_stream_types.Tup2;
  signal a1                        : i2s_to_stream_types.Tup2;
  signal ptr                       : std_logic_vector(2 downto 0);
  signal \ptr'\                    : std_logic_vector(2 downto 0);
  signal \c$ptr'_app_arg\          : std_logic_vector(2 downto 0);
  signal \bin'\                    : std_logic_vector(2 downto 0);
  signal bin                       : std_logic_vector(2 downto 0);
  signal \c$bin'_app_arg\          : std_logic_vector(0 downto 0);
  signal inc                       : boolean;
  signal \c$bin'_case_alt\         : std_logic_vector(0 downto 0);
  signal flag                      : boolean;
  signal eta9                      : i2s_to_stream_types.Tup3_0 := ( Tup3_0_sel0_std_logic_vector_0 => std_logic_vector'("000")
, Tup3_0_sel1_std_logic_vector_1 => std_logic_vector'("000")
, Tup3_0_sel2_boolean => false );
  signal \c$ds2_app_arg\           : std_logic_vector(2 downto 0);
  signal s_ptr                     : std_logic_vector(2 downto 0);
  signal eta10                     : i2s_to_stream_types.Tup2_1;
  signal \c$eta10_app_arg\         : boolean;
  signal \c$app_arg_11\            : std_logic_vector(2 downto 0) := std_logic_vector'("000");
  signal result_5                  : std_logic_vector(2 downto 0) := std_logic_vector'("000");
  signal ptr_0                     : std_logic_vector(2 downto 0);
  signal \ptr'_0\                  : std_logic_vector(2 downto 0);
  signal \c$ptr'_app_arg_0\        : std_logic_vector(2 downto 0);
  signal \bin'_0\                  : std_logic_vector(2 downto 0);
  signal bin_0                     : std_logic_vector(2 downto 0);
  signal \c$bin'_app_arg_0\        : std_logic_vector(0 downto 0);
  signal \c$bin'_case_alt_0\       : std_logic_vector(0 downto 0);
  signal flag_0                    : boolean;
  signal ds3                       : i2s_to_stream_types.Tup3_0 := ( Tup3_0_sel0_std_logic_vector_0 => std_logic_vector'("000")
, Tup3_0_sel1_std_logic_vector_1 => std_logic_vector'("000")
, Tup3_0_sel2_boolean => true );
  signal \c$app_arg_12\            : std_logic_vector(2 downto 0) := std_logic_vector'("000");
  signal result_6                  : std_logic_vector(2 downto 0) := std_logic_vector'("000");
  signal result_7                  : i2s_to_stream_types.Maybe;
  -- src/ADAU1761.hs:82:1-9
  signal b_0                       : boolean;
  -- src/ADAU1761.hs:82:1-9
  signal hp_ready                  : boolean;
  -- src/ADAU1761.hs:82:1-9
  signal \c$ds1_app_arg\           : std_logic_vector(47 downto 0);
  -- src/ADAU1761.hs:82:1-9
  signal \c$ds1_app_arg_0\         : boolean;
  signal result_8                  : i2s_to_stream_types.Tup3;
  signal \c$case_scrut_0\          : i2s_to_stream_types.Tup2_0;
  signal \c$app_arg_13\            : i2s_to_stream_types.Tup2;
  signal val_1                     : i2s_to_stream_types.Tup2;
  signal \c$app_arg_14\            : i2s_to_stream_types.index_4;
  signal addr_3                    : i2s_to_stream_types.index_4;
  signal addr_4                    : i2s_to_stream_types.index_4;
  signal \c$app_arg_15\            : boolean;
  signal \c$app_arg_16\            : boolean;
  signal \c$app_arg_17\            : i2s_to_stream_types.Tup2;
  signal val_2                     : i2s_to_stream_types.Tup2;
  signal \c$app_arg_18\            : i2s_to_stream_types.index_4;
  signal addr_5                    : i2s_to_stream_types.index_4;
  signal addr_6                    : i2s_to_stream_types.index_4;
  signal \c$app_arg_19\            : boolean;
  signal \c$app_arg_20\            : boolean;
  signal t_0                       : i2s_to_stream_types.RamOp;
  signal result_9                  : i2s_to_stream_types.RamOp;
  signal b_1                       : boolean;
  signal ds1_0                     : i2s_to_stream_types.Tup2;
  signal a1_0                      : i2s_to_stream_types.Tup2;
  signal ptr_1                     : std_logic_vector(2 downto 0);
  signal \ptr'_1\                  : std_logic_vector(2 downto 0);
  signal \c$ptr'_app_arg_1\        : std_logic_vector(2 downto 0);
  signal \bin'_1\                  : std_logic_vector(2 downto 0);
  signal bin_1                     : std_logic_vector(2 downto 0);
  signal \c$bin'_app_arg_1\        : std_logic_vector(0 downto 0);
  signal inc_0                     : boolean;
  signal \c$bin'_case_alt_1\       : std_logic_vector(0 downto 0);
  signal flag_1                    : boolean;
  signal eta9_0                    : i2s_to_stream_types.Tup3_0 := ( Tup3_0_sel0_std_logic_vector_0 => std_logic_vector'("000")
, Tup3_0_sel1_std_logic_vector_1 => std_logic_vector'("000")
, Tup3_0_sel2_boolean => false );
  signal \c$ds2_app_arg_0\         : std_logic_vector(2 downto 0);
  signal s_ptr_0                   : std_logic_vector(2 downto 0);
  signal eta10_0                   : i2s_to_stream_types.Tup2_1;
  signal \c$eta10_app_arg_0\       : boolean;
  signal \c$app_arg_21\            : std_logic_vector(2 downto 0) := std_logic_vector'("000");
  signal result_10                 : std_logic_vector(2 downto 0) := std_logic_vector'("000");
  signal ptr_2                     : std_logic_vector(2 downto 0);
  signal \ptr'_2\                  : std_logic_vector(2 downto 0);
  signal \c$ptr'_app_arg_2\        : std_logic_vector(2 downto 0);
  signal \bin'_2\                  : std_logic_vector(2 downto 0);
  signal bin_2                     : std_logic_vector(2 downto 0);
  signal \c$bin'_case_alt_2\       : std_logic_vector(0 downto 0);
  signal flag_2                    : boolean;
  signal ds3_0                     : i2s_to_stream_types.Tup3_0 := ( Tup3_0_sel0_std_logic_vector_0 => std_logic_vector'("000")
, Tup3_0_sel1_std_logic_vector_1 => std_logic_vector'("000")
, Tup3_0_sel2_boolean => true );
  signal \c$app_arg_22\            : std_logic_vector(2 downto 0) := std_logic_vector'("000");
  signal result_11                 : std_logic_vector(2 downto 0) := std_logic_vector'("000");
  -- src/I2S.hs:(13,1)-(17,46)
  signal b_2                       : boolean;
  signal result_12                 : i2s_to_stream_types.Maybe;
  -- src/I2S.hs:(13,1)-(17,46)
  signal sr                        : i2s_to_stream_types.array_of_std_logic(0 to 63) := i2s_to_stream_types.array_of_std_logic'( '0'
                                       , '0'
                                       , '0'
                                       , '0'
                                       , '0'
                                       , '0'
                                       , '0'
                                       , '0'
                                       , '0'
                                       , '0'
                                       , '0'
                                       , '0'
                                       , '0'
                                       , '0'
                                       , '0'
                                       , '0'
                                       , '0'
                                       , '0'
                                       , '0'
                                       , '0'
                                       , '0'
                                       , '0'
                                       , '0'
                                       , '0'
                                       , '0'
                                       , '0'
                                       , '0'
                                       , '0'
                                       , '0'
                                       , '0'
                                       , '0'
                                       , '0'
                                       , '0'
                                       , '0'
                                       , '0'
                                       , '0'
                                       , '0'
                                       , '0'
                                       , '0'
                                       , '0'
                                       , '0'
                                       , '0'
                                       , '0'
                                       , '0'
                                       , '0'
                                       , '0'
                                       , '0'
                                       , '0'
                                       , '0'
                                       , '0'
                                       , '0'
                                       , '0'
                                       , '0'
                                       , '0'
                                       , '0'
                                       , '0'
                                       , '0'
                                       , '0'
                                       , '0'
                                       , '0'
                                       , '0'
                                       , '0'
                                       , '0'
                                       , '0' );
  signal \c$case_alt\              : i2s_to_stream_types.array_of_std_logic_vector_1(0 to 23);
  signal \c$app_arg_23\            : std_logic_vector(23 downto 0);
  signal \c$case_alt_0\            : i2s_to_stream_types.array_of_std_logic_vector_1(0 to 23);
  signal \c$app_arg_24\            : std_logic_vector(23 downto 0);
  -- src/I2S.hs:25:1-14
  signal x1_0                      : i2s_to_stream_types.array_of_std_logic(0 to 23);
  -- src/I2S.hs:25:1-14
  signal x1_1                      : i2s_to_stream_types.array_of_std_logic(0 to 23);
  signal result_13                 : i2s_to_stream_types.Tup2;
  -- src/I2S.hs:(13,1)-(17,46)
  signal \c$sr_app_arg\            : i2s_to_stream_types.array_of_std_logic(0 to 63);
  -- src/I2S.hs:(13,1)-(17,46)
  signal \c$b_app_arg\             : boolean := false;
  signal \c$vec\                   : std_logic_vector(23 downto 0);
  signal \c$vec_0\                 : std_logic_vector(23 downto 0);
  signal \c$shI\                   : signed(63 downto 0);
  signal \c$shI_0\                 : signed(63 downto 0);
  signal \c$shI_1\                 : signed(63 downto 0);
  signal \c$shI_2\                 : signed(63 downto 0);
  signal x1_projection_1_1         : i2s_to_stream_types.Tup2_2;
  signal \c$vec_1\                 : i2s_to_stream_types.array_of_std_logic(0 to 62);
  signal x1_projection_1           : i2s_to_stream_types.Tup2_3;
  signal x1_projection_2_3         : i2s_to_stream_types.Tup2_4;
  signal \c$vec_2\                 : i2s_to_stream_types.array_of_std_logic(0 to 30);
  signal x1_projection_2           : i2s_to_stream_types.Tup2_5;
  signal \c$vec_3\                 : i2s_to_stream_types.array_of_std_logic(0 to 64);
  signal \c$sr_app_arg_projection\ : i2s_to_stream_types.Tup2_6;
  signal result                    : i2s_to_stream_types.Tup5;

begin
  result <= ( Tup5_sel0_std_logic => result_2
            , Tup5_sel1_boolean_0 => hp_ready
            , Tup5_sel2_std_logic_vector => std_logic_vector'(std_logic_vector'(((std_logic_vector(y)))) & std_logic_vector'(((std_logic_vector(x1)))))
            , Tup5_sel3_boolean_1 => li_valid
            , Tup5_sel4_boolean_2 => sampleCount = to_unsigned(32767,15) );

  -- register begin
  sampleCount_register : process(clk,resetn)
  begin
    if resetn =  '0'  then
      sampleCount <= to_unsigned(0,15);
    elsif rising_edge(clk) then
      if li_valid then
        sampleCount <= (sampleCount + to_unsigned(1,15));
      end if;
    end if;
  end process;
  -- register end

  li_valid <= not result_8.Tup3_sel1_boolean_0;

  x1 <= result_8.Tup3_sel0_Tup2.Tup2_sel0_signed_0;

  y <= result_8.Tup3_sel0_Tup2.Tup2_sel1_signed_1;

  -- delay begin
  cisEof_app_arg_delay : process(bclk)
  begin
    if rising_edge(bclk) then
      \c$isEof_app_arg\ <= lrclk;
    end if;
  end process;
  -- delay end

  -- register begin
  cf1_app_arg_register : process(bclk,i2s_rst)
  begin
    if i2s_rst =  '0'  then
      \c$f1_app_arg\ <= to_unsigned(0,6);
    elsif rising_edge(bclk) then
      \c$f1_app_arg\ <= result_0;
    end if;
  end process;
  -- register end

  result_0 <= to_unsigned(0,6) when isEof else
              f1;

  -- map begin
  r_map : for i in \c$app_arg\'range generate
  begin
    \c$app_arg\(i) <= \c$app_arg_0\(i)(0);


  end generate;
  -- map end

  \c$vec\ <= ((std_logic_vector(p.Tup2_sel1_signed_1)));

  -- unconcatBitVector begin
  unconcatBitVectorIter_loop : for i_0 in \c$app_arg_0\'range generate
    \c$app_arg_0\(\c$app_arg_0\'high - i_0) <= \c$vec\(((i_0 * 1) + 1 - 1) downto (i_0 * 1));
  end generate;
  -- unconcatBitVector end

  -- map begin
  r_map_0 : for i_1 in \c$app_arg_1\'range generate
  begin
    \c$app_arg_1\(i_1) <= \c$app_arg_2\(i_1)(0);


  end generate;
  -- map end

  \c$vec_0\ <= ((std_logic_vector(p.Tup2_sel0_signed_0)));

  -- unconcatBitVector begin
  unconcatBitVectorIter_loop_0 : for i_2 in \c$app_arg_2\'range generate
    \c$app_arg_2\(\c$app_arg_2\'high - i_2) <= \c$vec_0\(((i_2 * 1) + 1 - 1) downto (i_2 * 1));
  end generate;
  -- unconcatBitVector end

  result_1 <= i2s_to_stream_types.array_of_std_logic'(std_logic'('0') & i2s_to_stream_types.array_of_std_logic'(i2s_to_stream_types.array_of_std_logic'(\c$app_arg_1\) & i2s_to_stream_types.array_of_std_logic'((i2s_to_stream_types.array_of_std_logic'(i2s_to_stream_types.array_of_std_logic'((i2s_to_stream_types.array_of_std_logic'(0 to 7-1 =>  ('0') ))) & i2s_to_stream_types.array_of_std_logic'(i2s_to_stream_types.array_of_std_logic'(std_logic'('0') & i2s_to_stream_types.array_of_std_logic'(i2s_to_stream_types.array_of_std_logic'(\c$app_arg\) & i2s_to_stream_types.array_of_std_logic'((i2s_to_stream_types.array_of_std_logic'(0 to 7-1 =>  ('0') )))))))))));

  -- index begin
  indexVec : block
    signal vec_index : integer range 0 to 64-1;
  begin
    vec_index <= to_integer((signed(std_logic_vector(resize(result_0,64)))))
    -- pragma translate_off
                 mod 64
    -- pragma translate_on
                 ;
    result_2 <= result_1(vec_index);
  end block;
  -- index end

  -- register begin
  p_register : process(bclk,i2s_rst)
  begin
    if i2s_rst =  '0'  then
      p <= (Tup2_sel0_signed_0 => to_signed(0,24), Tup2_sel1_signed_1 => to_signed(0,24));
    elsif rising_edge(bclk) then
      if isEof then
        p <= result_3.Tup3_sel0_Tup2;
      end if;
    end if;
  end process;
  -- register end

  f1 <= \c$f1_app_arg\ + to_unsigned(1,6);

  isEof <= (not lrclk) and \c$isEof_app_arg\;

  result_3 <= ( Tup3_sel0_Tup2 => \c$case_scrut\.Tup2_0_sel0_Tup2_0
              , Tup3_sel1_boolean_0 => flag_0
              , Tup3_sel2_boolean_1 => flag );

  ADAU1761_topEntity_trueDualPortBlockRamWrapper_ccase_scrut : entity ADAU1761_topEntity_trueDualPortBlockRamWrapper
    port map
      ( result => \c$case_scrut\
      , clkA   => bclk
      , enA    => \c$app_arg_10\
      , weA    => \c$app_arg_9\
      , addrA  => \c$app_arg_8\
      , datA   => \c$app_arg_7\
      , clkB   => clk
      , enB    => \c$app_arg_6\
      , weB    => \c$app_arg_5\
      , addrB  => \c$app_arg_4\
      , datB   => \c$app_arg_3\ );

  with (result_4(51 downto 50)) select
    \c$app_arg_3\ <= val when "01",
                     i2s_to_stream_types.Tup2'(signed'(0 to 23 => '-'), signed'(0 to 23 => '-')) when others;

  val <= i2s_to_stream_types.Tup2'(i2s_to_stream_types.fromSLV(result_4(47 downto 0)));

  with (result_4(51 downto 50)) select
    \c$app_arg_4\ <= addr_0 when "00",
                     addr when "01",
                     i2s_to_stream_types.index_4'(0 to 1 => '-') when others;

  addr <= i2s_to_stream_types.index_4'(i2s_to_stream_types.fromSLV(result_4(49 downto 48)));

  addr_0 <= i2s_to_stream_types.index_4'(i2s_to_stream_types.fromSLV(result_4(49 downto 48)));

  with (result_4(51 downto 50)) select
    \c$app_arg_5\ <= true when "01",
                     false when others;

  with (result_4(51 downto 50)) select
    \c$app_arg_6\ <= false when "10",
                     true when others;

  with (t(51 downto 50)) select
    \c$app_arg_7\ <= val_0 when "01",
                     i2s_to_stream_types.Tup2'(signed'(0 to 23 => '-'), signed'(0 to 23 => '-')) when others;

  val_0 <= i2s_to_stream_types.Tup2'(i2s_to_stream_types.fromSLV(t(47 downto 0)));

  with (t(51 downto 50)) select
    \c$app_arg_8\ <= addr_2 when "00",
                     addr_1 when "01",
                     i2s_to_stream_types.index_4'(0 to 1 => '-') when others;

  addr_1 <= i2s_to_stream_types.index_4'(i2s_to_stream_types.fromSLV(t(49 downto 48)));

  addr_2 <= i2s_to_stream_types.index_4'(i2s_to_stream_types.fromSLV(t(49 downto 48)));

  with (t(51 downto 50)) select
    \c$app_arg_9\ <= true when "01",
                     false when others;

  with (t(51 downto 50)) select
    \c$app_arg_10\ <= false when "10",
                      true when others;

  t <= std_logic_vector'("00" & (std_logic_vector(unsigned((std_logic_vector(resize(unsigned(\bin'_0\),2)))))) & "------------------------------------------------");

  result_4 <= std_logic_vector'("01" & (std_logic_vector(unsigned((std_logic_vector(resize(unsigned(bin),2)))))) & ((std_logic_vector(ds1.Tup2_sel0_signed_0)
               & std_logic_vector(ds1.Tup2_sel1_signed_1)))) when b else
              std_logic_vector'("10" & "--------------------------------------------------");

  b <= (not flag) and \c$eta10_app_arg\;

  with (result_7(48 downto 48)) select
    ds1 <= i2s_to_stream_types.Tup2'(signed'(0 to 23 => '-'), signed'(0 to 23 => '-')) when "0",
           a1 when others;

  a1 <= i2s_to_stream_types.Tup2'(i2s_to_stream_types.fromSLV(result_7(47 downto 0)));

  ptr <= eta9.Tup3_0_sel1_std_logic_vector_1;

  \ptr'\ <= \c$ptr'_app_arg\ xor \bin'\;

  \c$shI\ <= to_signed(1,64);

  cptr_app_arg_shiftR : block
    signal sh : natural;
  begin
    sh <=
        -- pragma translate_off
        natural'high when (\c$shI\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI\);
    \c$ptr'_app_arg\ <= std_logic_vector(shift_right(unsigned(\bin'\),sh))
        -- pragma translate_off
        when (to_signed(1,64) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \bin'\ <= std_logic_vector(unsigned(bin) + unsigned((std_logic_vector'(std_logic_vector'(std_logic_vector'("00")) & std_logic_vector'((\c$bin'_app_arg\))))));

  bin <= eta9.Tup3_0_sel0_std_logic_vector_0;

  \c$bin'_app_arg\ <= \c$bin'_case_alt\ when inc else
                      std_logic_vector'("0");

  inc <= eta10.Tup2_1_sel1_boolean;

  \c$bin'_case_alt\ <= std_logic_vector'("0") when flag else
                       std_logic_vector'("1");

  flag <= eta9.Tup3_0_sel2_boolean;

  -- register begin
  eta9_register : process(clk,resetn)
  begin
    if resetn =  '0'  then
      eta9 <= ( Tup3_0_sel0_std_logic_vector_0 => std_logic_vector'("000")
  , Tup3_0_sel1_std_logic_vector_1 => std_logic_vector'("000")
  , Tup3_0_sel2_boolean => false );
    elsif rising_edge(clk) then
      eta9 <= ( Tup3_0_sel0_std_logic_vector_0 => \bin'\
  , Tup3_0_sel1_std_logic_vector_1 => \ptr'\
  , Tup3_0_sel2_boolean => \ptr'\ = (std_logic_vector'(std_logic_vector'((not (\c$ds2_app_arg\(2 downto 1)))) & std_logic_vector'((\c$ds2_app_arg\(0 downto 0))))) );
    end if;
  end process;
  -- register end

  \c$ds2_app_arg\ <= s_ptr;

  s_ptr <= eta10.Tup2_1_sel0_std_logic_vector;

  eta10 <= ( Tup2_1_sel0_std_logic_vector => result_5
           , Tup2_1_sel1_boolean => \c$eta10_app_arg\ );

  with (result_7(48 downto 48)) select
    \c$eta10_app_arg\ <= false when "0",
                         true when others;

  -- register begin
  capp_arg_11_register : process(clk,resetn)
  begin
    if resetn =  '0'  then
      \c$app_arg_11\ <= std_logic_vector'("000");
    elsif rising_edge(clk) then
      \c$app_arg_11\ <= (ptr_0);
    end if;
  end process;
  -- register end

  -- register begin
  result_5_register : process(clk,resetn)
  begin
    if resetn =  '0'  then
      result_5 <= std_logic_vector'("000");
    elsif rising_edge(clk) then
      result_5 <= \c$app_arg_11\;
    end if;
  end process;
  -- register end

  ptr_0 <= ds3.Tup3_0_sel1_std_logic_vector_1;

  \ptr'_0\ <= \c$ptr'_app_arg_0\ xor \bin'_0\;

  \c$shI_0\ <= to_signed(1,64);

  cptr_app_arg_0_shiftR : block
    signal sh_0 : natural;
  begin
    sh_0 <=
        -- pragma translate_off
        natural'high when (\c$shI_0\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_0\);
    \c$ptr'_app_arg_0\ <= std_logic_vector(shift_right(unsigned(\bin'_0\),sh_0))
        -- pragma translate_off
        when (to_signed(1,64) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \bin'_0\ <= std_logic_vector(unsigned(bin_0) + unsigned((std_logic_vector'(std_logic_vector'(std_logic_vector'("00")) & std_logic_vector'((\c$bin'_app_arg_0\))))));

  bin_0 <= ds3.Tup3_0_sel0_std_logic_vector_0;

  \c$bin'_app_arg_0\ <= \c$bin'_case_alt_0\ when \c$ds1_app_arg_0\ else
                        std_logic_vector'("0");

  \c$bin'_case_alt_0\ <= std_logic_vector'("0") when flag_0 else
                         std_logic_vector'("1");

  flag_0 <= ds3.Tup3_0_sel2_boolean;

  -- register begin
  ds3_register : process(bclk,i2s_rst)
  begin
    if i2s_rst =  '0'  then
      ds3 <= ( Tup3_0_sel0_std_logic_vector_0 => std_logic_vector'("000")
  , Tup3_0_sel1_std_logic_vector_1 => std_logic_vector'("000")
  , Tup3_0_sel2_boolean => true );
    elsif rising_edge(bclk) then
      ds3 <= ( Tup3_0_sel0_std_logic_vector_0 => \bin'_0\
  , Tup3_0_sel1_std_logic_vector_1 => \ptr'_0\
  , Tup3_0_sel2_boolean => \ptr'_0\ = result_6 );
    end if;
  end process;
  -- register end

  -- register begin
  capp_arg_12_register : process(bclk,i2s_rst)
  begin
    if i2s_rst =  '0'  then
      \c$app_arg_12\ <= std_logic_vector'("000");
    elsif rising_edge(bclk) then
      \c$app_arg_12\ <= (ptr);
    end if;
  end process;
  -- register end

  -- register begin
  result_6_register : process(bclk,i2s_rst)
  begin
    if i2s_rst =  '0'  then
      result_6 <= std_logic_vector'("000");
    elsif rising_edge(bclk) then
      result_6 <= \c$app_arg_12\;
    end if;
  end process;
  -- register end

  result_7 <= std_logic_vector'("1" & ((std_logic_vector(signed((\c$ds1_app_arg\(47 downto 24))))
               & std_logic_vector(signed((\c$ds1_app_arg\(23 downto 0))))))) when b_0 else
              std_logic_vector'("0" & "------------------------------------------------");

  b_0 <= hp_ready and axis_hp_tvalid;

  hp_ready <= not result_3.Tup3_sel2_boolean_1;

  \c$ds1_app_arg\ <= axis_hp_tdata;

  with (result_12(48 downto 48)) select
    \c$ds1_app_arg_0\ <= false when "0",
                         true when others;

  result_8 <= ( Tup3_sel0_Tup2 => \c$case_scrut_0\.Tup2_0_sel0_Tup2_0
              , Tup3_sel1_boolean_0 => flag_2
              , Tup3_sel2_boolean_1 => flag_1 );

  ADAU1761_topEntity_trueDualPortBlockRamWrapper_0_ccase_scrut_0 : entity ADAU1761_topEntity_trueDualPortBlockRamWrapper_0
    port map
      ( result => \c$case_scrut_0\
      , clkA   => clk
      , enA    => \c$app_arg_20\
      , weA    => \c$app_arg_19\
      , addrA  => \c$app_arg_18\
      , datA   => \c$app_arg_17\
      , clkB   => bclk
      , enB    => \c$app_arg_16\
      , weB    => \c$app_arg_15\
      , addrB  => \c$app_arg_14\
      , datB   => \c$app_arg_13\ );

  with (result_9(51 downto 50)) select
    \c$app_arg_13\ <= val_1 when "01",
                      i2s_to_stream_types.Tup2'(signed'(0 to 23 => '-'), signed'(0 to 23 => '-')) when others;

  val_1 <= i2s_to_stream_types.Tup2'(i2s_to_stream_types.fromSLV(result_9(47 downto 0)));

  with (result_9(51 downto 50)) select
    \c$app_arg_14\ <= addr_4 when "00",
                      addr_3 when "01",
                      i2s_to_stream_types.index_4'(0 to 1 => '-') when others;

  addr_3 <= i2s_to_stream_types.index_4'(i2s_to_stream_types.fromSLV(result_9(49 downto 48)));

  addr_4 <= i2s_to_stream_types.index_4'(i2s_to_stream_types.fromSLV(result_9(49 downto 48)));

  with (result_9(51 downto 50)) select
    \c$app_arg_15\ <= true when "01",
                      false when others;

  with (result_9(51 downto 50)) select
    \c$app_arg_16\ <= false when "10",
                      true when others;

  with (t_0(51 downto 50)) select
    \c$app_arg_17\ <= val_2 when "01",
                      i2s_to_stream_types.Tup2'(signed'(0 to 23 => '-'), signed'(0 to 23 => '-')) when others;

  val_2 <= i2s_to_stream_types.Tup2'(i2s_to_stream_types.fromSLV(t_0(47 downto 0)));

  with (t_0(51 downto 50)) select
    \c$app_arg_18\ <= addr_6 when "00",
                      addr_5 when "01",
                      i2s_to_stream_types.index_4'(0 to 1 => '-') when others;

  addr_5 <= i2s_to_stream_types.index_4'(i2s_to_stream_types.fromSLV(t_0(49 downto 48)));

  addr_6 <= i2s_to_stream_types.index_4'(i2s_to_stream_types.fromSLV(t_0(49 downto 48)));

  with (t_0(51 downto 50)) select
    \c$app_arg_19\ <= true when "01",
                      false when others;

  with (t_0(51 downto 50)) select
    \c$app_arg_20\ <= false when "10",
                      true when others;

  t_0 <= std_logic_vector'("00" & (std_logic_vector(unsigned((std_logic_vector(resize(unsigned(\bin'_2\),2)))))) & "------------------------------------------------");

  result_9 <= std_logic_vector'("01" & (std_logic_vector(unsigned((std_logic_vector(resize(unsigned(bin_1),2)))))) & ((std_logic_vector(ds1_0.Tup2_sel0_signed_0)
               & std_logic_vector(ds1_0.Tup2_sel1_signed_1)))) when b_1 else
              std_logic_vector'("10" & "--------------------------------------------------");

  b_1 <= (not flag_1) and \c$eta10_app_arg_0\;

  with (result_12(48 downto 48)) select
    ds1_0 <= i2s_to_stream_types.Tup2'(signed'(0 to 23 => '-'), signed'(0 to 23 => '-')) when "0",
             a1_0 when others;

  a1_0 <= i2s_to_stream_types.Tup2'(i2s_to_stream_types.fromSLV(result_12(47 downto 0)));

  ptr_1 <= eta9_0.Tup3_0_sel1_std_logic_vector_1;

  \ptr'_1\ <= \c$ptr'_app_arg_1\ xor \bin'_1\;

  \c$shI_1\ <= to_signed(1,64);

  cptr_app_arg_1_shiftR : block
    signal sh_1 : natural;
  begin
    sh_1 <=
        -- pragma translate_off
        natural'high when (\c$shI_1\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_1\);
    \c$ptr'_app_arg_1\ <= std_logic_vector(shift_right(unsigned(\bin'_1\),sh_1))
        -- pragma translate_off
        when (to_signed(1,64) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \bin'_1\ <= std_logic_vector(unsigned(bin_1) + unsigned((std_logic_vector'(std_logic_vector'(std_logic_vector'("00")) & std_logic_vector'((\c$bin'_app_arg_1\))))));

  bin_1 <= eta9_0.Tup3_0_sel0_std_logic_vector_0;

  \c$bin'_app_arg_1\ <= \c$bin'_case_alt_1\ when inc_0 else
                        std_logic_vector'("0");

  inc_0 <= eta10_0.Tup2_1_sel1_boolean;

  \c$bin'_case_alt_1\ <= std_logic_vector'("0") when flag_1 else
                         std_logic_vector'("1");

  flag_1 <= eta9_0.Tup3_0_sel2_boolean;

  -- register begin
  eta9_0_register : process(bclk,i2s_rst)
  begin
    if i2s_rst =  '0'  then
      eta9_0 <= ( Tup3_0_sel0_std_logic_vector_0 => std_logic_vector'("000")
  , Tup3_0_sel1_std_logic_vector_1 => std_logic_vector'("000")
  , Tup3_0_sel2_boolean => false );
    elsif rising_edge(bclk) then
      eta9_0 <= ( Tup3_0_sel0_std_logic_vector_0 => \bin'_1\
  , Tup3_0_sel1_std_logic_vector_1 => \ptr'_1\
  , Tup3_0_sel2_boolean => \ptr'_1\ = (std_logic_vector'(std_logic_vector'((not (\c$ds2_app_arg_0\(2 downto 1)))) & std_logic_vector'((\c$ds2_app_arg_0\(0 downto 0))))) );
    end if;
  end process;
  -- register end

  \c$ds2_app_arg_0\ <= s_ptr_0;

  s_ptr_0 <= eta10_0.Tup2_1_sel0_std_logic_vector;

  eta10_0 <= ( Tup2_1_sel0_std_logic_vector => result_10
             , Tup2_1_sel1_boolean => \c$eta10_app_arg_0\ );

  with (result_12(48 downto 48)) select
    \c$eta10_app_arg_0\ <= false when "0",
                           true when others;

  -- register begin
  capp_arg_21_register : process(bclk,i2s_rst)
  begin
    if i2s_rst =  '0'  then
      \c$app_arg_21\ <= std_logic_vector'("000");
    elsif rising_edge(bclk) then
      \c$app_arg_21\ <= (ptr_2);
    end if;
  end process;
  -- register end

  -- register begin
  result_10_register : process(bclk,i2s_rst)
  begin
    if i2s_rst =  '0'  then
      result_10 <= std_logic_vector'("000");
    elsif rising_edge(bclk) then
      result_10 <= \c$app_arg_21\;
    end if;
  end process;
  -- register end

  ptr_2 <= ds3_0.Tup3_0_sel1_std_logic_vector_1;

  \ptr'_2\ <= \c$ptr'_app_arg_2\ xor \bin'_2\;

  \c$shI_2\ <= to_signed(1,64);

  cptr_app_arg_2_shiftR : block
    signal sh_2 : natural;
  begin
    sh_2 <=
        -- pragma translate_off
        natural'high when (\c$shI_2\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_2\);
    \c$ptr'_app_arg_2\ <= std_logic_vector(shift_right(unsigned(\bin'_2\),sh_2))
        -- pragma translate_off
        when (to_signed(1,64) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \bin'_2\ <= std_logic_vector(unsigned(bin_2) + unsigned((std_logic_vector'(std_logic_vector'(std_logic_vector'("00")) & std_logic_vector'((\c$bin'_case_alt_2\))))));

  bin_2 <= ds3_0.Tup3_0_sel0_std_logic_vector_0;

  \c$bin'_case_alt_2\ <= std_logic_vector'("0") when flag_2 else
                         std_logic_vector'("1");

  flag_2 <= ds3_0.Tup3_0_sel2_boolean;

  -- register begin
  ds3_0_register : process(clk,resetn)
  begin
    if resetn =  '0'  then
      ds3_0 <= ( Tup3_0_sel0_std_logic_vector_0 => std_logic_vector'("000")
  , Tup3_0_sel1_std_logic_vector_1 => std_logic_vector'("000")
  , Tup3_0_sel2_boolean => true );
    elsif rising_edge(clk) then
      ds3_0 <= ( Tup3_0_sel0_std_logic_vector_0 => \bin'_2\
  , Tup3_0_sel1_std_logic_vector_1 => \ptr'_2\
  , Tup3_0_sel2_boolean => \ptr'_2\ = result_11 );
    end if;
  end process;
  -- register end

  -- register begin
  capp_arg_22_register : process(clk,resetn)
  begin
    if resetn =  '0'  then
      \c$app_arg_22\ <= std_logic_vector'("000");
    elsif rising_edge(clk) then
      \c$app_arg_22\ <= (ptr_1);
    end if;
  end process;
  -- register end

  -- register begin
  result_11_register : process(clk,resetn)
  begin
    if resetn =  '0'  then
      result_11 <= std_logic_vector'("000");
    elsif rising_edge(clk) then
      result_11 <= \c$app_arg_22\;
    end if;
  end process;
  -- register end

  b_2 <= (not lrclk) and \c$b_app_arg\;

  result_12 <= std_logic_vector'("1" & ((std_logic_vector(result_13.Tup2_sel0_signed_0)
                & std_logic_vector(result_13.Tup2_sel1_signed_1)))) when b_2 else
               std_logic_vector'("0" & "------------------------------------------------");

  -- register begin
  sr_register : process(bclk,i2s_rst)
  begin
    if i2s_rst =  '0'  then
      sr <= i2s_to_stream_types.array_of_std_logic'( '0'
                                         , '0'
                                         , '0'
                                         , '0'
                                         , '0'
                                         , '0'
                                         , '0'
                                         , '0'
                                         , '0'
                                         , '0'
                                         , '0'
                                         , '0'
                                         , '0'
                                         , '0'
                                         , '0'
                                         , '0'
                                         , '0'
                                         , '0'
                                         , '0'
                                         , '0'
                                         , '0'
                                         , '0'
                                         , '0'
                                         , '0'
                                         , '0'
                                         , '0'
                                         , '0'
                                         , '0'
                                         , '0'
                                         , '0'
                                         , '0'
                                         , '0'
                                         , '0'
                                         , '0'
                                         , '0'
                                         , '0'
                                         , '0'
                                         , '0'
                                         , '0'
                                         , '0'
                                         , '0'
                                         , '0'
                                         , '0'
                                         , '0'
                                         , '0'
                                         , '0'
                                         , '0'
                                         , '0'
                                         , '0'
                                         , '0'
                                         , '0'
                                         , '0'
                                         , '0'
                                         , '0'
                                         , '0'
                                         , '0'
                                         , '0'
                                         , '0'
                                         , '0'
                                         , '0'
                                         , '0'
                                         , '0'
                                         , '0'
                                         , '0' );
    elsif rising_edge(bclk) then
      sr <= \c$sr_app_arg\;
    end if;
  end process;
  -- register end

  -- map begin
  r_map_1 : for i_3 in \c$case_alt\'range generate
  begin
    \c$case_alt\(i_3) <= (std_logic_vector'(0 => x1_0(i_3)));


  end generate;
  -- map end

  -- concatBitVector begin
  concatBitVectorIter_loop : for i_4 in 0 to (24 - 1) generate
    \c$app_arg_23\(((i_4 * 1) + 1 - 1) downto (i_4 * 1)) <= std_logic_vector'(\c$case_alt\(\c$case_alt\'high - i_4));
  end generate;
  -- concatBitVector end

  -- map begin
  r_map_2 : for i_5 in \c$case_alt_0\'range generate
  begin
    \c$case_alt_0\(i_5) <= (std_logic_vector'(0 => x1_1(i_5)));


  end generate;
  -- map end

  -- concatBitVector begin
  concatBitVectorIter_loop_0 : for i_6 in 0 to (24 - 1) generate
    \c$app_arg_24\(((i_6 * 1) + 1 - 1) downto (i_6 * 1)) <= std_logic_vector'(\c$case_alt_0\(\c$case_alt_0\'high - i_6));
  end generate;
  -- concatBitVector end

  x1_projection_1_1 <= (sr(0 to 1-1),sr(1 to sr'high));

  \c$vec_1\ <= x1_projection_1_1.Tup2_2_sel1_array_of_std_logic_1;

  x1_projection_1 <= (\c$vec_1\(0 to 24-1),\c$vec_1\(24 to \c$vec_1\'high));

  x1_0 <= x1_projection_1.Tup2_3_sel0_array_of_std_logic_0;

  x1_projection_2_3 <= (sr(0 to 33-1),sr(33 to sr'high));

  \c$vec_2\ <= x1_projection_2_3.Tup2_4_sel1_array_of_std_logic_1;

  x1_projection_2 <= (\c$vec_2\(0 to 24-1),\c$vec_2\(24 to \c$vec_2\'high));

  x1_1 <= x1_projection_2.Tup2_5_sel0_array_of_std_logic_0;

  result_13 <= ( Tup2_sel0_signed_0 => signed((\c$app_arg_23\))
               , Tup2_sel1_signed_1 => signed((\c$app_arg_24\)) );

  \c$vec_3\ <= (i2s_to_stream_types.array_of_std_logic'(i2s_to_stream_types.array_of_std_logic'(sr) & i2s_to_stream_types.array_of_std_logic'(i2s_to_stream_types.array_of_std_logic'(0 => si))));

  \c$sr_app_arg_projection\ <= (\c$vec_3\(0 to 1-1),\c$vec_3\(1 to \c$vec_3\'high));

  \c$sr_app_arg\ <= \c$sr_app_arg_projection\.Tup2_6_sel1_array_of_std_logic_1;

  -- delay begin
  cb_app_arg_delay : process(bclk)
  begin
    if rising_edge(bclk) then
      \c$b_app_arg\ <= lrclk;
    end if;
  end process;
  -- delay end

  so <= result.Tup5_sel0_std_logic;

  axis_hp_tready <= result.Tup5_sel1_boolean_0;

  axis_li_tdata <= result.Tup5_sel2_std_logic_vector;

  axis_li_tvalid <= result.Tup5_sel3_boolean_1;

  axis_li_tlast <= result.Tup5_sel4_boolean_2;


end;

