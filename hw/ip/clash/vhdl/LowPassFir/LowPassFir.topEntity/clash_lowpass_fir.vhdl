-- Automatically generated VHDL-93
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;
use std.textio.all;
use work.all;
use work.clash_lowpass_fir_types.all;

entity clash_lowpass_fir is
  port(-- clock
       clk             : in std_logic;
       -- reset
       aresetn         : in std_logic;
       axis_in_tdata   : in std_logic_vector(47 downto 0);
       axis_in_tvalid  : in boolean;
       axis_in_tlast   : in boolean;
       axis_out_tready : in boolean;
       axis_out_tdata  : out std_logic_vector(47 downto 0);
       axis_out_tvalid : out boolean;
       axis_out_tlast  : out boolean;
       axis_in_tready  : out boolean);
end;

architecture structural of clash_lowpass_fir is
  signal \c$bindCsr\               : clash_lowpass_fir_types.en_AudioDomain;
  -- src/LowPassFir.hs:(12,1)-(18,44)
  signal ws                        : clash_lowpass_fir_types.array_of_signed_24(0 to 91);
  -- src/LowPassFir.hs:(12,1)-(18,44)
  signal ws1                       : clash_lowpass_fir_types.array_of_signed_24(0 to 90);
  signal result_0                  : signed(23 downto 0);
  -- src/LowPassFir.hs:(12,1)-(18,44)
  signal \c$ws1_app_arg\           : clash_lowpass_fir_types.array_of_signed_24(0 to 90);
  signal \c$bindCsr_0\             : clash_lowpass_fir_types.en_AudioDomain;
  -- src/LowPassFir.hs:(12,1)-(18,44)
  signal ws_0                      : clash_lowpass_fir_types.array_of_signed_24(0 to 91);
  -- src/LowPassFir.hs:(12,1)-(18,44)
  signal ws1_0                     : clash_lowpass_fir_types.array_of_signed_24(0 to 90);
  signal result_1                  : signed(23 downto 0);
  -- src/LowPassFir.hs:(12,1)-(18,44)
  signal \c$ws1_app_arg_0\         : clash_lowpass_fir_types.array_of_signed_24(0 to 90);
  -- src/LowPassFir.hs:122:1-10
  signal chans                     : clash_lowpass_fir_types.array_of_array_of_24_std_logic(0 to 1);
  signal result_2                  : clash_lowpass_fir_types.Tup2;
  signal \c$app_arg\               : std_logic_vector(23 downto 0);
  signal \c$app_arg_0\             : clash_lowpass_fir_types.array_of_std_logic_vector_1(0 to 23);
  signal \c$app_arg_1\             : clash_lowpass_fir_types.array_of_std_logic(0 to 23);
  signal \c$app_arg_2\             : std_logic_vector(23 downto 0);
  signal \c$app_arg_3\             : clash_lowpass_fir_types.array_of_std_logic_vector_1(0 to 23);
  signal \c$app_arg_4\             : clash_lowpass_fir_types.array_of_std_logic(0 to 23);
  -- src/LowPassFir.hs:122:1-10
  signal \c$chans_app_arg\         : clash_lowpass_fir_types.array_of_std_logic(0 to 47);
  -- src/LowPassFir.hs:122:1-10
  signal \c$chans_app_arg_0\       : clash_lowpass_fir_types.array_of_std_logic_vector_1(0 to 47);
  signal \c$vec2\                  : clash_lowpass_fir_types.array_of_signed_24(0 to 90);
  signal \c$ws1_app_arg_res\       : clash_lowpass_fir_types.array_of_signed_24(0 to 90);
  signal \c$ws1_app_arg_res_res\   : clash_lowpass_fir_types.array_of_signed_24(0 to 90);
  signal \c$vec\                   : clash_lowpass_fir_types.array_of_signed_24(0 to 90);
  signal \c$vec2_0\                : clash_lowpass_fir_types.array_of_signed_24(0 to 90);
  signal \c$vec2_1\                : clash_lowpass_fir_types.array_of_signed_24(0 to 90);
  signal \c$ws1_app_arg_res_1\     : clash_lowpass_fir_types.array_of_signed_24(0 to 90);
  signal \c$ws1_app_arg_res_res_0\ : clash_lowpass_fir_types.array_of_signed_24(0 to 90);
  signal \c$vec_0\                 : clash_lowpass_fir_types.array_of_signed_24(0 to 90);
  signal \c$vec2_2\                : clash_lowpass_fir_types.array_of_signed_24(0 to 90);
  signal result                    : clash_lowpass_fir_types.Tup4;

begin
  \c$bindCsr\ <= axis_in_tvalid and axis_out_tready;

  ws <= clash_lowpass_fir_types.array_of_signed_24'(signed'(to_signed(0,24)) & ws1);

  \c$vec2\ <= (ws(0 to ws'high - 1));

  -- zipWith begin
  zipWith : for i in ws1'range generate
  begin
    fun_3 : block
      -- src/LowPassFir.hs:(12,1)-(18,44)
      signal \c$ws1_app_arg_1\          : signed(23 downto 0) := to_signed(0,24);
      signal result_3                   : signed(23 downto 0);
      signal \c$case_alt\               : signed(23 downto 0);
      signal \r'\                       : std_logic_vector(23 downto 0);
      signal \c$r'_app_arg\             : std_logic_vector(24 downto 0);
      signal r                          : signed(24 downto 0);
      signal result_selection_res       : boolean;
      signal \c$bv\                     : std_logic_vector(23 downto 0);
      signal \c$case_alt_selection_res\ : boolean;
      signal \c$bv_0\                   : std_logic_vector(23 downto 0);
      signal \c$bv_1\                   : std_logic_vector(23 downto 0);
      signal \r'_projection\            : clash_lowpass_fir_types.Tup2_0;
    begin
      ws1(i) <= result_3;

      -- delay begin
      cws1_app_arg_1_delay : process(clk)
      begin
        if rising_edge(clk) then
          if \c$bindCsr\ then
            \c$ws1_app_arg_1\ <= \c$vec2\(i);
          end if;
        end if;
      end process;
      -- delay end

      \c$bv\ <= (\r'\);

      result_selection_res <= (( \c$r'_app_arg\(\c$r'_app_arg\'high) ) xor ( \c$bv\(\c$bv\'high) )) = '0';

      result_3 <= signed(\r'\) when result_selection_res else
                  \c$case_alt\;

      \c$bv_0\ <= ((std_logic_vector(\c$ws1_app_arg_1\)));

      \c$bv_1\ <= ((std_logic_vector(\c$ws1_app_arg\(i))));

      \c$case_alt_selection_res\ <= (( \c$bv_0\(\c$bv_0\'high) ) and ( \c$bv_1\(\c$bv_1\'high) )) = '0';

      \c$case_alt\ <= to_signed(8388607,24) when \c$case_alt_selection_res\ else
                      to_signed(-8388608,24);

      \r'_projection\ <= (\c$r'_app_arg\(\c$r'_app_arg\'high downto 24),\c$r'_app_arg\(24-1 downto 0));

      \r'\ <= \r'_projection\.Tup2_0_sel1_std_logic_vector_1;

      \c$r'_app_arg\ <= (std_logic_vector(r));

      r <= resize(\c$ws1_app_arg_1\,25) + resize(\c$ws1_app_arg\(i),25);


    end block;
  end generate;
  -- zipWith end

  result_0 <=  ws(ws'high) ;

  \c$vec\ <= clash_lowpass_fir_types.array_of_signed_24'( to_signed(-431439,24)
                                                        , to_signed(-36728,24)
                                                        , to_signed(-37457,24)
                                                        , to_signed(-37632,24)
                                                        , to_signed(-37145,24)
                                                        , to_signed(-35990,24)
                                                        , to_signed(-34112,24)
                                                        , to_signed(-31489,24)
                                                        , to_signed(-28130,24)
                                                        , to_signed(-24021,24)
                                                        , to_signed(-19141,24)
                                                        , to_signed(-13494,24)
                                                        , to_signed(-6915,24)
                                                        , to_signed(471,24)
                                                        , to_signed(8311,24)
                                                        , to_signed(17224,24)
                                                        , to_signed(26750,24)
                                                        , to_signed(36965,24)
                                                        , to_signed(47834,24)
                                                        , to_signed(59286,24)
                                                        , to_signed(71280,24)
                                                        , to_signed(83765,24)
                                                        , to_signed(96656,24)
                                                        , to_signed(109889,24)
                                                        , to_signed(123416,24)
                                                        , to_signed(136977,24)
                                                        , to_signed(150809,24)
                                                        , to_signed(164647,24)
                                                        , to_signed(178283,24)
                                                        , to_signed(191832,24)
                                                        , to_signed(205134,24)
                                                        , to_signed(218101,24)
                                                        , to_signed(230645,24)
                                                        , to_signed(242654,24)
                                                        , to_signed(254051,24)
                                                        , to_signed(264771,24)
                                                        , to_signed(274706,24)
                                                        , to_signed(283753,24)
                                                        , to_signed(292469,24)
                                                        , to_signed(298832,24)
                                                        , to_signed(305240,24)
                                                        , to_signed(310610,24)
                                                        , to_signed(314690,24)
                                                        , to_signed(317557,24)
                                                        , to_signed(319242,24)
                                                        , to_signed(319794,24)
                                                        , to_signed(319242,24)
                                                        , to_signed(317557,24)
                                                        , to_signed(314690,24)
                                                        , to_signed(310610,24)
                                                        , to_signed(305240,24)
                                                        , to_signed(298832,24)
                                                        , to_signed(292469,24)
                                                        , to_signed(283753,24)
                                                        , to_signed(274706,24)
                                                        , to_signed(264771,24)
                                                        , to_signed(254051,24)
                                                        , to_signed(242654,24)
                                                        , to_signed(230645,24)
                                                        , to_signed(218101,24)
                                                        , to_signed(205134,24)
                                                        , to_signed(191832,24)
                                                        , to_signed(178283,24)
                                                        , to_signed(164647,24)
                                                        , to_signed(150809,24)
                                                        , to_signed(136977,24)
                                                        , to_signed(123416,24)
                                                        , to_signed(109889,24)
                                                        , to_signed(96656,24)
                                                        , to_signed(83765,24)
                                                        , to_signed(71280,24)
                                                        , to_signed(59286,24)
                                                        , to_signed(47834,24)
                                                        , to_signed(36965,24)
                                                        , to_signed(26750,24)
                                                        , to_signed(17224,24)
                                                        , to_signed(8311,24)
                                                        , to_signed(471,24)
                                                        , to_signed(-6915,24)
                                                        , to_signed(-13494,24)
                                                        , to_signed(-19141,24)
                                                        , to_signed(-24021,24)
                                                        , to_signed(-28130,24)
                                                        , to_signed(-31489,24)
                                                        , to_signed(-34112,24)
                                                        , to_signed(-35990,24)
                                                        , to_signed(-37145,24)
                                                        , to_signed(-37632,24)
                                                        , to_signed(-37457,24)
                                                        , to_signed(-36728,24)
                                                        , to_signed(-431439,24) );

  -- reverse begin
  reverse_loop : for i_0 in 0 to (91 - 1) generate
    \c$ws1_app_arg_res_res\(\c$vec\'high - i_0) <= \c$vec\(i_0);
  end generate;
  -- reverse end

  -- map begin
  r_map : for i_1 in \c$ws1_app_arg_res\'range generate
  begin
    \c$ws1_app_arg_res\(i_1) <= \c$ws1_app_arg_res_res\(i_1);


  end generate;
  -- map end

  \c$vec2_0\ <= (clash_lowpass_fir_types.array_of_signed_24'(0 to 91-1 =>  result_2.Tup2_sel0_signed_0 ));

  -- zipWith begin
  zipWith_0 : for i_2 in \c$ws1_app_arg\'range generate
  begin
    fun_4 : block
      signal result_6                     : signed(23 downto 0);
      signal \c$case_alt_3\               : signed(23 downto 0);
      signal \c$app_arg_5\                : std_logic_vector(46 downto 0);
      signal \c$app_arg_6\                : std_logic;
      signal \c$app_arg_7\                : std_logic;
      signal \c$app_arg_8\                : std_logic_vector(1 downto 0);
      signal \c$app_arg_9\                : std_logic_vector(0 downto 0);
      signal rL                           : std_logic_vector(0 downto 0);
      signal rR                           : std_logic_vector(46 downto 0);
      signal ds3                          : clash_lowpass_fir_types.Tup2_1;
      signal result_5                     : signed(23 downto 0) := to_signed(0,24);
      signal result_4                     : signed(23 downto 0);
      signal result_selection_res_0       : boolean;
      signal \c$case_alt_selection_res_0\ : boolean;
      signal \c$shI\                      : signed(63 downto 0);
      signal \c$bv_2\                     : std_logic_vector(46 downto 0);
      signal \c$bv_3\                     : std_logic_vector(47 downto 0);
    begin
      \c$ws1_app_arg\(i_2) <= result_4;

      result_selection_res_0 <= ((not \c$app_arg_7\) or \c$app_arg_6\) = '1';

      result_6 <= signed((std_logic_vector(resize(unsigned(\c$app_arg_5\),24)))) when result_selection_res_0 else
                  \c$case_alt_3\;

      \c$case_alt_selection_res_0\ <= ( \c$app_arg_9\(\c$app_arg_9\'high) ) = '0';

      \c$case_alt_3\ <= to_signed(8388607,24) when \c$case_alt_selection_res_0\ else
                        to_signed(-8388608,24);

      \c$shI\ <= to_signed(23,64);

      capp_arg_5_shiftR : block
        signal sh : natural;
      begin
        sh <=
            -- pragma translate_off
            natural'high when (\c$shI\(64-1 downto 31) /= 0) else
            -- pragma translate_on
            to_integer(\c$shI\);
        \c$app_arg_5\ <= std_logic_vector(shift_right(unsigned(rR),sh))
            -- pragma translate_off
            when (to_signed(23,64) >= 0) else (others => 'X')
            -- pragma translate_on
            ;
      end block;

      -- reduceAnd begin,

      reduceAnd : block
        function and_reduce (arg : std_logic_vector) return std_logic is
          variable upper, lower : std_logic;
          variable half         : integer;
          variable argi         : std_logic_vector (arg'length - 1 downto 0);
          variable result       : std_logic;
        begin
          if (arg'length < 1) then
            result := '1';
          else
            argi := arg;
            if (argi'length = 1) then
              result := argi(argi'left);
            else
              half   := (argi'length + 1) / 2; -- lsb-biased tree
              upper  := and_reduce (argi (argi'left downto half));
              lower  := and_reduce (argi (half - 1 downto argi'right));
              result := upper and lower;
            end if;
          end if;
          return result;
        end;
      begin
        \c$app_arg_6\ <= and_reduce(\c$app_arg_8\);
      end block;
      -- reduceAnd end

      -- reduceOr begin
      reduceOr : block
        function or_reduce (arg : std_logic_vector) return std_logic is
          variable upper, lower : std_logic;
          variable half         : integer;
          variable argi         : std_logic_vector (arg'length - 1 downto 0);
          variable result       : std_logic;
        begin
          if (arg'length < 1) then
            result := '0';
          else
            argi := arg;
            if (argi'length = 1) then
              result := argi(argi'left);
            else
              half   := (argi'length + 1) / 2; -- lsb-biased tree
              upper  := or_reduce (argi (argi'left downto half));
              lower  := or_reduce (argi (half - 1 downto argi'right));
              result := upper or lower;
            end if;
          end if;
          return result;
        end;
      begin
        \c$app_arg_7\ <= or_reduce(\c$app_arg_8\);
      end block;
      -- reduceOr end

      \c$bv_2\ <= (rR);

      \c$app_arg_8\ <= (std_logic_vector'(std_logic_vector'(((std_logic_vector'(0 => ( \c$bv_2\(\c$bv_2\'high) ))))) & std_logic_vector'(\c$app_arg_9\)));

      \c$app_arg_9\ <= rL;

      rL <= ds3.Tup2_1_sel0_std_logic_vector_0;

      rR <= ds3.Tup2_1_sel1_std_logic_vector_1;

      \c$bv_3\ <= ((std_logic_vector((\c$ws1_app_arg_res\(i_2) * \c$vec2_0\(i_2)))));

      ds3 <= (\c$bv_3\(\c$bv_3\'high downto 47),\c$bv_3\(47-1 downto 0));

      -- delay begin
      result_5_delay : process(clk)
      begin
        if rising_edge(clk) then
          if \c$bindCsr\ then
            result_5 <= result_6;
          end if;
        end if;
      end process;
      -- delay end

      result_4 <= result_5;


    end block;
  end generate;
  -- zipWith end

  \c$bindCsr_0\ <= axis_in_tvalid and axis_out_tready;

  ws_0 <= clash_lowpass_fir_types.array_of_signed_24'(signed'(to_signed(0,24)) & ws1_0);

  \c$vec2_1\ <= (ws_0(0 to ws_0'high - 1));

  -- zipWith begin
  zipWith_1 : for i_3 in ws1_0'range generate
  begin
    fun_5 : block
      -- src/LowPassFir.hs:(12,1)-(18,44)
      signal \c$ws1_app_arg_5\            : signed(23 downto 0) := to_signed(0,24);
      signal result_7                     : signed(23 downto 0);
      signal \c$case_alt_4\               : signed(23 downto 0);
      signal \r'_1\                       : std_logic_vector(23 downto 0);
      signal \c$r'_app_arg_0\             : std_logic_vector(24 downto 0);
      signal r_0                          : signed(24 downto 0);
      signal result_selection_res_1       : boolean;
      signal \c$bv_4\                     : std_logic_vector(23 downto 0);
      signal \c$case_alt_selection_res_1\ : boolean;
      signal \c$bv_5\                     : std_logic_vector(23 downto 0);
      signal \c$bv_6\                     : std_logic_vector(23 downto 0);
      signal \r'_projection_0\            : clash_lowpass_fir_types.Tup2_0;
    begin
      ws1_0(i_3) <= result_7;

      -- delay begin
      cws1_app_arg_5_delay : process(clk)
      begin
        if rising_edge(clk) then
          if \c$bindCsr_0\ then
            \c$ws1_app_arg_5\ <= \c$vec2_1\(i_3);
          end if;
        end if;
      end process;
      -- delay end

      \c$bv_4\ <= (\r'_1\);

      result_selection_res_1 <= (( \c$r'_app_arg_0\(\c$r'_app_arg_0\'high) ) xor ( \c$bv_4\(\c$bv_4\'high) )) = '0';

      result_7 <= signed(\r'_1\) when result_selection_res_1 else
                  \c$case_alt_4\;

      \c$bv_5\ <= ((std_logic_vector(\c$ws1_app_arg_5\)));

      \c$bv_6\ <= ((std_logic_vector(\c$ws1_app_arg_0\(i_3))));

      \c$case_alt_selection_res_1\ <= (( \c$bv_5\(\c$bv_5\'high) ) and ( \c$bv_6\(\c$bv_6\'high) )) = '0';

      \c$case_alt_4\ <= to_signed(8388607,24) when \c$case_alt_selection_res_1\ else
                        to_signed(-8388608,24);

      \r'_projection_0\ <= (\c$r'_app_arg_0\(\c$r'_app_arg_0\'high downto 24),\c$r'_app_arg_0\(24-1 downto 0));

      \r'_1\ <= \r'_projection_0\.Tup2_0_sel1_std_logic_vector_1;

      \c$r'_app_arg_0\ <= (std_logic_vector(r_0));

      r_0 <= resize(\c$ws1_app_arg_5\,25) + resize(\c$ws1_app_arg_0\(i_3),25);


    end block;
  end generate;
  -- zipWith end

  result_1 <=  ws_0(ws_0'high) ;

  \c$vec_0\ <= clash_lowpass_fir_types.array_of_signed_24'( to_signed(-431439,24)
                                                          , to_signed(-36728,24)
                                                          , to_signed(-37457,24)
                                                          , to_signed(-37632,24)
                                                          , to_signed(-37145,24)
                                                          , to_signed(-35990,24)
                                                          , to_signed(-34112,24)
                                                          , to_signed(-31489,24)
                                                          , to_signed(-28130,24)
                                                          , to_signed(-24021,24)
                                                          , to_signed(-19141,24)
                                                          , to_signed(-13494,24)
                                                          , to_signed(-6915,24)
                                                          , to_signed(471,24)
                                                          , to_signed(8311,24)
                                                          , to_signed(17224,24)
                                                          , to_signed(26750,24)
                                                          , to_signed(36965,24)
                                                          , to_signed(47834,24)
                                                          , to_signed(59286,24)
                                                          , to_signed(71280,24)
                                                          , to_signed(83765,24)
                                                          , to_signed(96656,24)
                                                          , to_signed(109889,24)
                                                          , to_signed(123416,24)
                                                          , to_signed(136977,24)
                                                          , to_signed(150809,24)
                                                          , to_signed(164647,24)
                                                          , to_signed(178283,24)
                                                          , to_signed(191832,24)
                                                          , to_signed(205134,24)
                                                          , to_signed(218101,24)
                                                          , to_signed(230645,24)
                                                          , to_signed(242654,24)
                                                          , to_signed(254051,24)
                                                          , to_signed(264771,24)
                                                          , to_signed(274706,24)
                                                          , to_signed(283753,24)
                                                          , to_signed(292469,24)
                                                          , to_signed(298832,24)
                                                          , to_signed(305240,24)
                                                          , to_signed(310610,24)
                                                          , to_signed(314690,24)
                                                          , to_signed(317557,24)
                                                          , to_signed(319242,24)
                                                          , to_signed(319794,24)
                                                          , to_signed(319242,24)
                                                          , to_signed(317557,24)
                                                          , to_signed(314690,24)
                                                          , to_signed(310610,24)
                                                          , to_signed(305240,24)
                                                          , to_signed(298832,24)
                                                          , to_signed(292469,24)
                                                          , to_signed(283753,24)
                                                          , to_signed(274706,24)
                                                          , to_signed(264771,24)
                                                          , to_signed(254051,24)
                                                          , to_signed(242654,24)
                                                          , to_signed(230645,24)
                                                          , to_signed(218101,24)
                                                          , to_signed(205134,24)
                                                          , to_signed(191832,24)
                                                          , to_signed(178283,24)
                                                          , to_signed(164647,24)
                                                          , to_signed(150809,24)
                                                          , to_signed(136977,24)
                                                          , to_signed(123416,24)
                                                          , to_signed(109889,24)
                                                          , to_signed(96656,24)
                                                          , to_signed(83765,24)
                                                          , to_signed(71280,24)
                                                          , to_signed(59286,24)
                                                          , to_signed(47834,24)
                                                          , to_signed(36965,24)
                                                          , to_signed(26750,24)
                                                          , to_signed(17224,24)
                                                          , to_signed(8311,24)
                                                          , to_signed(471,24)
                                                          , to_signed(-6915,24)
                                                          , to_signed(-13494,24)
                                                          , to_signed(-19141,24)
                                                          , to_signed(-24021,24)
                                                          , to_signed(-28130,24)
                                                          , to_signed(-31489,24)
                                                          , to_signed(-34112,24)
                                                          , to_signed(-35990,24)
                                                          , to_signed(-37145,24)
                                                          , to_signed(-37632,24)
                                                          , to_signed(-37457,24)
                                                          , to_signed(-36728,24)
                                                          , to_signed(-431439,24) );

  -- reverse begin
  reverse_loop_0 : for i_4 in 0 to (91 - 1) generate
    \c$ws1_app_arg_res_res_0\(\c$vec_0\'high - i_4) <= \c$vec_0\(i_4);
  end generate;
  -- reverse end

  -- map begin
  r_map_0 : for i_5 in \c$ws1_app_arg_res_1\'range generate
  begin
    \c$ws1_app_arg_res_1\(i_5) <= \c$ws1_app_arg_res_res_0\(i_5);


  end generate;
  -- map end

  \c$vec2_2\ <= (clash_lowpass_fir_types.array_of_signed_24'(0 to 91-1 =>  result_2.Tup2_sel1_signed_1 ));

  -- zipWith begin
  zipWith_2 : for i_6 in \c$ws1_app_arg_0\'range generate
  begin
    fun_6 : block
      signal result_10                    : signed(23 downto 0);
      signal \c$case_alt_5\               : signed(23 downto 0);
      signal \c$app_arg_10\               : std_logic_vector(46 downto 0);
      signal \c$app_arg_11\               : std_logic;
      signal \c$app_arg_12\               : std_logic;
      signal \c$app_arg_13\               : std_logic_vector(1 downto 0);
      signal \c$app_arg_14\               : std_logic_vector(0 downto 0);
      signal rL_1                         : std_logic_vector(0 downto 0);
      signal rR_1                         : std_logic_vector(46 downto 0);
      signal ds3_0                        : clash_lowpass_fir_types.Tup2_1;
      signal result_9                     : signed(23 downto 0) := to_signed(0,24);
      signal result_8                     : signed(23 downto 0);
      signal result_selection_res_2       : boolean;
      signal \c$case_alt_selection_res_2\ : boolean;
      signal \c$shI_0\                    : signed(63 downto 0);
      signal \c$bv_7\                     : std_logic_vector(46 downto 0);
      signal \c$bv_8\                     : std_logic_vector(47 downto 0);
    begin
      \c$ws1_app_arg_0\(i_6) <= result_8;

      result_selection_res_2 <= ((not \c$app_arg_12\) or \c$app_arg_11\) = '1';

      result_10 <= signed((std_logic_vector(resize(unsigned(\c$app_arg_10\),24)))) when result_selection_res_2 else
                   \c$case_alt_5\;

      \c$case_alt_selection_res_2\ <= ( \c$app_arg_14\(\c$app_arg_14\'high) ) = '0';

      \c$case_alt_5\ <= to_signed(8388607,24) when \c$case_alt_selection_res_2\ else
                        to_signed(-8388608,24);

      \c$shI_0\ <= to_signed(23,64);

      capp_arg_10_shiftR : block
        signal sh_0 : natural;
      begin
        sh_0 <=
            -- pragma translate_off
            natural'high when (\c$shI_0\(64-1 downto 31) /= 0) else
            -- pragma translate_on
            to_integer(\c$shI_0\);
        \c$app_arg_10\ <= std_logic_vector(shift_right(unsigned(rR_1),sh_0))
            -- pragma translate_off
            when (to_signed(23,64) >= 0) else (others => 'X')
            -- pragma translate_on
            ;
      end block;

      -- reduceAnd begin,

      reduceAnd_0 : block
        function and_reduce (arg : std_logic_vector) return std_logic is
          variable upper, lower : std_logic;
          variable half         : integer;
          variable argi         : std_logic_vector (arg'length - 1 downto 0);
          variable result       : std_logic;
        begin
          if (arg'length < 1) then
            result := '1';
          else
            argi := arg;
            if (argi'length = 1) then
              result := argi(argi'left);
            else
              half   := (argi'length + 1) / 2; -- lsb-biased tree
              upper  := and_reduce (argi (argi'left downto half));
              lower  := and_reduce (argi (half - 1 downto argi'right));
              result := upper and lower;
            end if;
          end if;
          return result;
        end;
      begin
        \c$app_arg_11\ <= and_reduce(\c$app_arg_13\);
      end block;
      -- reduceAnd end

      -- reduceOr begin
      reduceOr_0 : block
        function or_reduce (arg : std_logic_vector) return std_logic is
          variable upper, lower : std_logic;
          variable half         : integer;
          variable argi         : std_logic_vector (arg'length - 1 downto 0);
          variable result       : std_logic;
        begin
          if (arg'length < 1) then
            result := '0';
          else
            argi := arg;
            if (argi'length = 1) then
              result := argi(argi'left);
            else
              half   := (argi'length + 1) / 2; -- lsb-biased tree
              upper  := or_reduce (argi (argi'left downto half));
              lower  := or_reduce (argi (half - 1 downto argi'right));
              result := upper or lower;
            end if;
          end if;
          return result;
        end;
      begin
        \c$app_arg_12\ <= or_reduce(\c$app_arg_13\);
      end block;
      -- reduceOr end

      \c$bv_7\ <= (rR_1);

      \c$app_arg_13\ <= (std_logic_vector'(std_logic_vector'(((std_logic_vector'(0 => ( \c$bv_7\(\c$bv_7\'high) ))))) & std_logic_vector'(\c$app_arg_14\)));

      \c$app_arg_14\ <= rL_1;

      rL_1 <= ds3_0.Tup2_1_sel0_std_logic_vector_0;

      rR_1 <= ds3_0.Tup2_1_sel1_std_logic_vector_1;

      \c$bv_8\ <= ((std_logic_vector((\c$ws1_app_arg_res_1\(i_6) * \c$vec2_2\(i_6)))));

      ds3_0 <= (\c$bv_8\(\c$bv_8\'high downto 47),\c$bv_8\(47-1 downto 0));

      -- delay begin
      result_9_delay : process(clk)
      begin
        if rising_edge(clk) then
          if \c$bindCsr_0\ then
            result_9 <= result_10;
          end if;
        end if;
      end process;
      -- delay end

      result_8 <= result_9;


    end block;
  end generate;
  -- zipWith end

  -- unconcat begin
  unconcat : for i_7 in chans'range generate
  begin
    chans(i_7) <= \c$chans_app_arg\((i_7 * 24) to ((i_7 * 24) + 24 - 1));
  end generate;
  -- unconcat end

  result_2 <= ( Tup2_sel0_signed_0 => signed((\c$app_arg_2\))
              , Tup2_sel1_signed_1 => signed((\c$app_arg\)) );

  -- concatBitVector begin
  concatBitVectorIter_loop : for i_8 in 0 to (24 - 1) generate
    \c$app_arg\(((i_8 * 1) + 1 - 1) downto (i_8 * 1)) <= std_logic_vector'(\c$app_arg_0\(\c$app_arg_0\'high - i_8));
  end generate;
  -- concatBitVector end

  -- map begin
  r_map_1 : for i_9 in \c$app_arg_0\'range generate
  begin
    \c$app_arg_0\(i_9) <= (std_logic_vector'(0 => \c$app_arg_1\(i_9)));


  end generate;
  -- map end

  -- index begin
  indexVec : block
    signal vec_index : integer range 0 to 2-1;
  begin
    vec_index <= to_integer(to_signed(0,64))
    -- pragma translate_off
                 mod 2
    -- pragma translate_on
                 ;
    \c$app_arg_1\ <= chans(vec_index);
  end block;
  -- index end

  -- concatBitVector begin
  concatBitVectorIter_loop_0 : for i_10 in 0 to (24 - 1) generate
    \c$app_arg_2\(((i_10 * 1) + 1 - 1) downto (i_10 * 1)) <= std_logic_vector'(\c$app_arg_3\(\c$app_arg_3\'high - i_10));
  end generate;
  -- concatBitVector end

  -- map begin
  r_map_2 : for i_11 in \c$app_arg_3\'range generate
  begin
    \c$app_arg_3\(i_11) <= (std_logic_vector'(0 => \c$app_arg_4\(i_11)));


  end generate;
  -- map end

  -- index begin
  indexVec_0 : block
    signal vec_index_0 : integer range 0 to 2-1;
  begin
    vec_index_0 <= to_integer(to_signed(1,64))
    -- pragma translate_off
                 mod 2
    -- pragma translate_on
                 ;
    \c$app_arg_4\ <= chans(vec_index_0);
  end block;
  -- index end

  -- map begin
  r_map_3 : for i_12 in \c$chans_app_arg\'range generate
  begin
    \c$chans_app_arg\(i_12) <= \c$chans_app_arg_0\(i_12)(0);


  end generate;
  -- map end

  -- unconcatBitVector begin
  unconcatBitVectorIter_loop : for i_13 in \c$chans_app_arg_0\'range generate
    \c$chans_app_arg_0\(\c$chans_app_arg_0\'high - i_13) <= axis_in_tdata(((i_13 * 1) + 1 - 1) downto (i_13 * 1));
  end generate;
  -- unconcatBitVector end

  result <= ( Tup4_sel0_std_logic_vector => std_logic_vector'(std_logic_vector'(((std_logic_vector(result_1)))) & std_logic_vector'(((std_logic_vector(result_0)))))
            , Tup4_sel1_boolean_0 => axis_in_tvalid
            , Tup4_sel2_boolean_1 => axis_in_tlast
            , Tup4_sel3_boolean_2 => axis_out_tready );

  axis_out_tdata <= result.Tup4_sel0_std_logic_vector;

  axis_out_tvalid <= result.Tup4_sel1_boolean_0;

  axis_out_tlast <= result.Tup4_sel2_boolean_1;

  axis_in_tready <= result.Tup4_sel3_boolean_2;


end;

