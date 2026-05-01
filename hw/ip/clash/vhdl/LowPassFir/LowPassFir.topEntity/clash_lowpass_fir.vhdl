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
       clk                : in std_logic;
       -- reset
       aresetn            : in std_logic;
       gate_control       : in std_logic_vector(31 downto 0);
       overdrive_control  : in std_logic_vector(31 downto 0);
       distortion_control : in std_logic_vector(31 downto 0);
       eq_control         : in std_logic_vector(31 downto 0);
       delay_control      : in std_logic_vector(31 downto 0);
       reverb_control     : in std_logic_vector(31 downto 0);
       axis_in_tdata      : in std_logic_vector(47 downto 0);
       axis_in_tvalid     : in boolean;
       axis_in_tlast      : in boolean;
       axis_out_tready    : in boolean;
       axis_out_tdata     : out std_logic_vector(47 downto 0);
       axis_out_tvalid    : out boolean;
       axis_out_tlast     : out boolean;
       axis_in_tready     : out boolean);
end;

architecture structural of clash_lowpass_fir is
  signal result_0                              : clash_lowpass_fir_types.AxisOut;
  signal \c$case_alt\                          : clash_lowpass_fir_types.AxisOut;
  -- src/LowPassFir.hs:580:1-11
  signal \new\                                 : boolean;
  signal \c$app_arg\                           : boolean;
  signal \c$app_arg_0\                         : std_logic_vector(47 downto 0);
  -- src/LowPassFir.hs:569:1-8
  signal f                                     : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:580:1-11
  signal consumed                              : boolean;
  -- src/LowPassFir.hs:650:1-10
  signal outReg                                : clash_lowpass_fir_types.AxisOut := ( AxisOut_sel0_oData => std_logic_vector'(x"000000000000")
, AxisOut_sel1_oValid => false
, AxisOut_sel2_oLast => false );
  signal result_1                              : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_1\                         : signed(47 downto 0);
  signal \c$app_arg_2\                         : signed(47 downto 0);
  -- src/LowPassFir.hs:526:1-27
  signal \on\                                  : boolean;
  signal \c$app_arg_3\                         : signed(47 downto 0);
  -- src/LowPassFir.hs:108:1-5
  signal gain                                  : unsigned(7 downto 0);
  -- src/LowPassFir.hs:650:1-10
  signal reverbToneBlendPipe                   : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_2                              : clash_lowpass_fir_types.Maybe;
  signal \c$app_arg_4\                         : signed(47 downto 0);
  signal \c$case_alt_0\                        : signed(23 downto 0);
  signal result_3                              : signed(23 downto 0);
  signal \c$app_arg_5\                         : signed(47 downto 0);
  signal \c$case_alt_1\                        : signed(23 downto 0);
  signal result_4                              : signed(23 downto 0);
  signal \c$case_alt_2\                        : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:650:1-10
  signal x                                     : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:650:1-10
  signal ds1                                   : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_5                              : clash_lowpass_fir_types.Maybe;
  signal \c$app_arg_6\                         : signed(47 downto 0);
  -- src/LowPassFir.hs:108:1-5
  signal gain_0                                : unsigned(7 downto 0);
  signal \c$app_arg_7\                         : signed(47 downto 0);
  -- src/LowPassFir.hs:108:1-5
  signal gain_1                                : unsigned(7 downto 0);
  -- src/LowPassFir.hs:511:1-23
  signal x_0                                   : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:650:1-10
  signal reverbTonePrevR                       : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:650:1-10
  signal \c$reverbTonePrevR_app_arg\           : signed(23 downto 0);
  -- src/LowPassFir.hs:650:1-10
  signal reverbTonePrevL                       : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:650:1-10
  signal \c$reverbTonePrevL_app_arg\           : signed(23 downto 0);
  -- src/LowPassFir.hs:650:1-10
  signal x_1                                   : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:650:1-10
  signal \c$ds1_app_arg\                       : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  -- src/LowPassFir.hs:504:1-10
  signal f_0                                   : clash_lowpass_fir_types.Frame;
  signal result_6                              : clash_lowpass_fir_types.Maybe;
  signal result_7                              : signed(23 downto 0);
  -- src/LowPassFir.hs:650:1-10
  signal ds                                    : clash_lowpass_fir_types.Tuple2;
  -- src/LowPassFir.hs:650:1-10
  signal a1                                    : clash_lowpass_fir_types.Tuple2;
  -- src/LowPassFir.hs:650:1-10
  signal \c$ds1_app_arg_0\                     : boolean;
  -- src/LowPassFir.hs:650:1-10
  signal wrM                                   : clash_lowpass_fir_types.Maybe_0;
  signal result_8                              : signed(23 downto 0);
  -- src/LowPassFir.hs:650:1-10
  signal ds_0                                  : clash_lowpass_fir_types.Tuple2;
  -- src/LowPassFir.hs:650:1-10
  signal a1_0                                  : clash_lowpass_fir_types.Tuple2;
  -- src/LowPassFir.hs:650:1-10
  signal \c$ds1_app_arg_1\                     : boolean;
  -- src/LowPassFir.hs:650:1-10
  signal wrM_0                                 : clash_lowpass_fir_types.Maybe_0;
  -- src/LowPassFir.hs:561:1-12
  signal f_1                                   : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:650:1-10
  signal outPipe                               : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_9                              : clash_lowpass_fir_types.Maybe;
  signal \c$app_arg_8\                         : signed(47 downto 0);
  signal \c$case_alt_3\                        : signed(23 downto 0);
  signal result_10                             : signed(23 downto 0);
  signal \c$app_arg_9\                         : signed(23 downto 0);
  signal \c$app_arg_10\                        : signed(47 downto 0);
  signal \c$case_alt_4\                        : signed(23 downto 0);
  signal result_11                             : signed(23 downto 0);
  signal \c$app_arg_11\                        : signed(23 downto 0);
  signal result_12                             : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:553:1-14
  signal \on_0\                                : boolean;
  -- src/LowPassFir.hs:650:1-10
  signal x_2                                   : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:650:1-10
  signal ds1_0                                 : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_13                             : clash_lowpass_fir_types.Maybe;
  signal result_14                             : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_12\                        : signed(47 downto 0);
  signal \c$app_arg_13\                        : signed(47 downto 0);
  signal \c$app_arg_14\                        : signed(47 downto 0);
  signal \c$app_arg_15\                        : signed(47 downto 0);
  signal \c$app_arg_16\                        : signed(47 downto 0);
  -- src/LowPassFir.hs:540:1-22
  signal \on_1\                                : boolean;
  signal \c$app_arg_17\                        : signed(47 downto 0);
  -- src/LowPassFir.hs:540:1-22
  signal invMixGain                            : unsigned(8 downto 0);
  -- src/LowPassFir.hs:540:1-22
  signal mixGain                               : unsigned(7 downto 0);
  -- src/LowPassFir.hs:650:1-10
  signal x_3                                   : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:650:1-10
  signal ds1_1                                 : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_15                             : clash_lowpass_fir_types.Maybe;
  signal \c$app_arg_18\                        : signed(47 downto 0);
  signal \c$app_arg_19\                        : signed(47 downto 0);
  -- src/LowPassFir.hs:117:1-7
  signal x_4                                   : signed(47 downto 0);
  signal \c$case_alt_5\                        : signed(23 downto 0);
  signal result_16                             : signed(23 downto 0);
  signal \c$app_arg_20\                        : signed(23 downto 0);
  signal \c$app_arg_21\                        : signed(47 downto 0);
  signal \c$app_arg_22\                        : signed(47 downto 0);
  -- src/LowPassFir.hs:117:1-7
  signal x_5                                   : signed(47 downto 0);
  signal \c$case_alt_6\                        : signed(23 downto 0);
  signal result_17                             : signed(23 downto 0);
  signal \c$app_arg_23\                        : signed(23 downto 0);
  signal result_18                             : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:532:1-19
  signal \on_2\                                : boolean;
  -- src/LowPassFir.hs:650:1-10
  signal x_6                                   : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:650:1-10
  signal ds1_2                                 : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  -- src/LowPassFir.hs:650:1-10
  signal \c$ds1_app_arg_2\                     : clash_lowpass_fir_types.Maybe;
  -- src/LowPassFir.hs:650:1-10
  signal \c$ds1_app_arg_3\                     : signed(63 downto 0);
  -- src/LowPassFir.hs:650:1-10
  signal reverbAddr                            : clash_lowpass_fir_types.index_1024 := to_unsigned(0,10);
  -- src/LowPassFir.hs:650:1-10
  signal \c$reverbAddr_app_arg\                : clash_lowpass_fir_types.index_1024;
  -- src/LowPassFir.hs:650:1-10
  signal eqMixPipe                             : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_19                             : clash_lowpass_fir_types.Maybe;
  -- src/LowPassFir.hs:496:1-10
  signal \on_3\                                : boolean;
  signal result_20                             : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_24\                        : signed(23 downto 0);
  signal \c$case_alt_7\                        : signed(23 downto 0);
  signal result_21                             : signed(23 downto 0);
  signal \c$app_arg_25\                        : signed(47 downto 0);
  signal \c$app_arg_26\                        : signed(23 downto 0);
  signal \c$case_alt_8\                        : signed(23 downto 0);
  signal result_22                             : signed(23 downto 0);
  signal \c$app_arg_27\                        : signed(47 downto 0);
  -- src/LowPassFir.hs:650:1-10
  signal x_7                                   : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:650:1-10
  signal ds1_3                                 : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_23                             : clash_lowpass_fir_types.Maybe;
  signal result_24                             : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_28\                        : signed(47 downto 0);
  signal \c$app_arg_29\                        : signed(47 downto 0);
  signal \c$app_arg_30\                        : signed(47 downto 0);
  -- src/LowPassFir.hs:108:1-5
  signal gain_2                                : unsigned(7 downto 0);
  signal \c$app_arg_31\                        : signed(47 downto 0);
  signal \c$app_arg_32\                        : signed(47 downto 0);
  signal \c$app_arg_33\                        : signed(47 downto 0);
  -- src/LowPassFir.hs:108:1-5
  signal gain_3                                : unsigned(7 downto 0);
  signal \c$app_arg_34\                        : signed(47 downto 0);
  signal \c$app_arg_35\                        : signed(47 downto 0);
  -- src/LowPassFir.hs:483:1-15
  signal \on_4\                                : boolean;
  signal \c$app_arg_36\                        : signed(47 downto 0);
  -- src/LowPassFir.hs:108:1-5
  signal gain_4                                : unsigned(7 downto 0);
  -- src/LowPassFir.hs:108:1-5
  signal \c$gain_app_arg\                      : std_logic_vector(31 downto 0);
  -- src/LowPassFir.hs:650:1-10
  signal x_8                                   : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:650:1-10
  signal ds1_4                                 : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_25                             : clash_lowpass_fir_types.Maybe;
  signal \c$case_alt_9\                        : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:117:1-7
  signal x_9                                   : signed(47 downto 0);
  signal \c$case_alt_10\                       : signed(23 downto 0);
  signal result_26                             : signed(23 downto 0);
  -- src/LowPassFir.hs:117:1-7
  signal x_10                                  : signed(47 downto 0);
  signal \c$case_alt_11\                       : signed(23 downto 0);
  signal result_27                             : signed(23 downto 0);
  -- src/LowPassFir.hs:117:1-7
  signal x_11                                  : signed(47 downto 0);
  signal \c$case_alt_12\                       : signed(23 downto 0);
  signal result_28                             : signed(23 downto 0);
  signal \c$app_arg_37\                        : signed(47 downto 0);
  -- src/LowPassFir.hs:117:1-7
  signal x_12                                  : signed(47 downto 0);
  signal \c$case_alt_13\                       : signed(23 downto 0);
  signal result_29                             : signed(23 downto 0);
  signal \c$app_arg_38\                        : signed(47 downto 0);
  -- src/LowPassFir.hs:650:1-10
  signal eqFilterPipe                          : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_30                             : clash_lowpass_fir_types.Maybe;
  signal \c$case_alt_14\                       : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_39\                        : signed(24 downto 0);
  signal \c$app_arg_40\                        : signed(24 downto 0);
  signal \c$app_arg_41\                        : signed(24 downto 0);
  signal \c$app_arg_42\                        : signed(24 downto 0);
  signal \c$app_arg_43\                        : signed(24 downto 0);
  signal \c$app_arg_44\                        : signed(24 downto 0);
  -- src/LowPassFir.hs:650:1-10
  signal eqHighPrevR                           : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:650:1-10
  signal \c$eqHighPrevR_app_arg\               : signed(23 downto 0);
  -- src/LowPassFir.hs:650:1-10
  signal eqHighPrevL                           : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:650:1-10
  signal \c$eqHighPrevL_app_arg\               : signed(23 downto 0);
  -- src/LowPassFir.hs:650:1-10
  signal eqLowPrevR                            : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:650:1-10
  signal \c$eqLowPrevR_app_arg\                : signed(23 downto 0);
  -- src/LowPassFir.hs:650:1-10
  signal eqLowPrevL                            : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:650:1-10
  signal \c$eqLowPrevL_app_arg\                : signed(23 downto 0);
  -- src/LowPassFir.hs:650:1-10
  signal x_13                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:152:1-7
  signal x_14                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:152:1-7
  signal ds1_5                                 : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_31                             : clash_lowpass_fir_types.Maybe;
  signal result_32                             : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_45\                        : signed(23 downto 0);
  signal result_33                             : signed(23 downto 0);
  signal \c$case_alt_15\                       : signed(23 downto 0);
  signal \c$app_arg_46\                        : signed(24 downto 0);
  signal \c$app_arg_47\                        : signed(24 downto 0);
  signal \c$app_arg_48\                        : signed(24 downto 0);
  signal \c$case_alt_16\                       : signed(23 downto 0);
  signal result_34                             : signed(23 downto 0);
  signal \c$app_arg_49\                        : signed(47 downto 0);
  signal \c$app_arg_50\                        : signed(23 downto 0);
  -- src/LowPassFir.hs:448:1-11
  signal \on_5\                                : boolean;
  signal result_35                             : signed(23 downto 0);
  signal \c$case_alt_17\                       : signed(23 downto 0);
  signal \c$app_arg_51\                        : signed(24 downto 0);
  signal \c$app_arg_52\                        : signed(24 downto 0);
  signal \c$app_arg_53\                        : signed(24 downto 0);
  signal \c$case_alt_18\                       : signed(23 downto 0);
  signal result_36                             : signed(23 downto 0);
  signal \c$app_arg_54\                        : signed(47 downto 0);
  signal \c$app_arg_55\                        : signed(47 downto 0);
  signal \c$app_arg_56\                        : signed(47 downto 0);
  -- src/LowPassFir.hs:448:1-11
  signal invMix                                : unsigned(7 downto 0);
  -- src/LowPassFir.hs:448:1-11
  signal mix                                   : unsigned(7 downto 0);
  -- src/LowPassFir.hs:650:1-10
  signal x_15                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:650:1-10
  signal ds1_6                                 : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_37                             : clash_lowpass_fir_types.Maybe;
  signal result_38                             : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_57\                        : signed(23 downto 0);
  signal \c$case_alt_19\                       : signed(23 downto 0);
  signal result_39                             : signed(23 downto 0);
  signal \c$app_arg_58\                        : signed(47 downto 0);
  signal \c$app_arg_59\                        : signed(23 downto 0);
  -- src/LowPassFir.hs:439:1-13
  signal \on_6\                                : boolean;
  signal \c$case_alt_20\                       : signed(23 downto 0);
  signal result_40                             : signed(23 downto 0);
  signal \c$app_arg_60\                        : signed(47 downto 0);
  signal \c$app_arg_61\                        : signed(47 downto 0);
  -- src/LowPassFir.hs:439:1-13
  signal level                                 : unsigned(7 downto 0);
  -- src/LowPassFir.hs:650:1-10
  signal ratTonePipe                           : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_41                             : clash_lowpass_fir_types.Maybe;
  -- src/LowPassFir.hs:431:1-12
  signal alpha                                 : unsigned(7 downto 0);
  -- src/LowPassFir.hs:431:1-12
  signal \on_7\                                : boolean;
  signal result_42                             : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_62\                        : signed(23 downto 0);
  signal \c$app_arg_63\                        : signed(47 downto 0);
  -- src/LowPassFir.hs:108:1-5
  signal gain_5                                : unsigned(7 downto 0);
  signal \c$case_alt_21\                       : signed(23 downto 0);
  signal result_43                             : signed(23 downto 0);
  signal \c$app_arg_64\                        : signed(23 downto 0);
  signal \c$app_arg_65\                        : signed(47 downto 0);
  -- src/LowPassFir.hs:108:1-5
  signal gain_6                                : unsigned(7 downto 0);
  signal \c$case_alt_22\                       : signed(23 downto 0);
  signal result_44                             : signed(23 downto 0);
  -- src/LowPassFir.hs:431:1-12
  signal \c$alpha_app_arg\                     : unsigned(9 downto 0);
  -- src/LowPassFir.hs:650:1-10
  signal ratTonePrevR                          : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:650:1-10
  signal \c$ratTonePrevR_app_arg\              : signed(23 downto 0);
  -- src/LowPassFir.hs:650:1-10
  signal ratTonePrevL                          : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:650:1-10
  signal \c$ratTonePrevL_app_arg\              : signed(23 downto 0);
  -- src/LowPassFir.hs:650:1-10
  signal x_16                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:650:1-10
  signal ratPostPipe                           : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_45                             : clash_lowpass_fir_types.Maybe;
  -- src/LowPassFir.hs:425:1-19
  signal \on_8\                                : boolean;
  signal result_46                             : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_66\                        : signed(23 downto 0);
  signal \c$app_arg_67\                        : signed(47 downto 0);
  signal \c$case_alt_23\                       : signed(23 downto 0);
  signal result_47                             : signed(23 downto 0);
  signal \c$app_arg_68\                        : signed(23 downto 0);
  signal \c$app_arg_69\                        : signed(47 downto 0);
  signal \c$case_alt_24\                       : signed(23 downto 0);
  signal result_48                             : signed(23 downto 0);
  -- src/LowPassFir.hs:650:1-10
  signal ratPostPrevR                          : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:650:1-10
  signal \c$ratPostPrevR_app_arg\              : signed(23 downto 0);
  -- src/LowPassFir.hs:650:1-10
  signal ratPostPrevL                          : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:650:1-10
  signal \c$ratPostPrevL_app_arg\              : signed(23 downto 0);
  -- src/LowPassFir.hs:650:1-10
  signal x_17                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:152:1-7
  signal x_18                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:152:1-7
  signal ds1_7                                 : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_49                             : clash_lowpass_fir_types.Maybe;
  -- src/LowPassFir.hs:415:1-12
  signal threshold                             : signed(23 downto 0);
  -- src/LowPassFir.hs:415:1-12
  signal \on_9\                                : boolean;
  signal result_50                             : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_70\                        : signed(23 downto 0);
  signal result_51                             : signed(23 downto 0);
  signal \c$case_alt_25\                       : signed(23 downto 0);
  signal \c$app_arg_71\                        : signed(23 downto 0);
  signal \c$app_arg_72\                        : signed(23 downto 0);
  signal result_52                             : signed(23 downto 0);
  signal \c$case_alt_26\                       : signed(23 downto 0);
  signal \c$app_arg_73\                        : signed(23 downto 0);
  -- src/LowPassFir.hs:415:1-12
  signal rawThreshold                          : signed(24 downto 0);
  signal result_53                             : signed(24 downto 0);
  -- src/LowPassFir.hs:93:1-9
  signal x_19                                  : unsigned(7 downto 0);
  -- src/LowPassFir.hs:650:1-10
  signal ratOpAmpPipe                          : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_54                             : clash_lowpass_fir_types.Maybe;
  -- src/LowPassFir.hs:406:1-20
  signal alpha_0                               : unsigned(7 downto 0);
  -- src/LowPassFir.hs:406:1-20
  signal \on_10\                               : boolean;
  signal result_55                             : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_74\                        : signed(23 downto 0);
  signal \c$app_arg_75\                        : signed(47 downto 0);
  -- src/LowPassFir.hs:108:1-5
  signal gain_7                                : unsigned(7 downto 0);
  signal \c$case_alt_27\                       : signed(23 downto 0);
  signal result_56                             : signed(23 downto 0);
  signal \c$app_arg_76\                        : signed(23 downto 0);
  signal \c$app_arg_77\                        : signed(47 downto 0);
  -- src/LowPassFir.hs:108:1-5
  signal gain_8                                : unsigned(7 downto 0);
  signal \c$case_alt_28\                       : signed(23 downto 0);
  signal result_57                             : signed(23 downto 0);
  -- src/LowPassFir.hs:406:1-20
  signal \c$alpha_app_arg_0\                   : unsigned(7 downto 0);
  -- src/LowPassFir.hs:650:1-10
  signal ratOpAmpPrevR                         : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:650:1-10
  signal \c$ratOpAmpPrevR_app_arg\             : signed(23 downto 0);
  -- src/LowPassFir.hs:650:1-10
  signal ratOpAmpPrevL                         : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:650:1-10
  signal \c$ratOpAmpPrevL_app_arg\             : signed(23 downto 0);
  -- src/LowPassFir.hs:650:1-10
  signal x_20                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:152:1-7
  signal x_21                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:152:1-7
  signal ds1_8                                 : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_58                             : clash_lowpass_fir_types.Maybe;
  signal \c$app_arg_78\                        : signed(47 downto 0);
  signal \c$case_alt_29\                       : signed(23 downto 0);
  signal result_59                             : signed(23 downto 0);
  signal \c$app_arg_79\                        : signed(23 downto 0);
  signal \c$app_arg_80\                        : signed(47 downto 0);
  signal \c$case_alt_30\                       : signed(23 downto 0);
  signal result_60                             : signed(23 downto 0);
  signal \c$app_arg_81\                        : signed(23 downto 0);
  signal result_61                             : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:400:1-18
  signal \on_11\                               : boolean;
  -- src/LowPassFir.hs:650:1-10
  signal x_22                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:650:1-10
  signal ds1_9                                 : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_62                             : clash_lowpass_fir_types.Maybe;
  signal result_63                             : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_82\                        : signed(47 downto 0);
  signal \c$app_arg_83\                        : signed(47 downto 0);
  -- src/LowPassFir.hs:393:1-21
  signal \on_12\                               : boolean;
  signal \c$app_arg_84\                        : signed(47 downto 0);
  -- src/LowPassFir.hs:393:1-21
  signal driveGain                             : unsigned(11 downto 0);
  -- src/LowPassFir.hs:650:1-10
  signal ratHighpassPipe                       : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_64                             : clash_lowpass_fir_types.Maybe;
  -- src/LowPassFir.hs:117:1-7
  signal x_23                                  : signed(47 downto 0);
  signal \c$case_alt_31\                       : signed(23 downto 0);
  signal result_65                             : signed(23 downto 0);
  signal \c$app_arg_85\                        : signed(23 downto 0);
  -- src/LowPassFir.hs:117:1-7
  signal x_24                                  : signed(47 downto 0);
  signal \c$case_alt_32\                       : signed(23 downto 0);
  signal result_66                             : signed(23 downto 0);
  signal \c$app_arg_86\                        : signed(23 downto 0);
  signal result_67                             : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:380:1-16
  signal \on_13\                               : boolean;
  -- src/LowPassFir.hs:650:1-10
  signal ratHpOutPrevR                         : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:650:1-10
  signal \c$ratHpOutPrevR_app_arg\             : signed(23 downto 0);
  -- src/LowPassFir.hs:650:1-10
  signal ratHpOutPrevL                         : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:650:1-10
  signal \c$ratHpOutPrevL_app_arg\             : signed(23 downto 0);
  -- src/LowPassFir.hs:650:1-10
  signal ratHpInPrevR                          : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:650:1-10
  signal \c$ratHpInPrevR_app_arg\              : signed(23 downto 0);
  -- src/LowPassFir.hs:650:1-10
  signal ratHpInPrevL                          : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:650:1-10
  signal \c$ratHpInPrevL_app_arg\              : signed(23 downto 0);
  -- src/LowPassFir.hs:650:1-10
  signal x_25                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:152:1-7
  signal x_26                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:152:1-7
  signal ds1_10                                : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_68                             : clash_lowpass_fir_types.Maybe;
  signal result_69                             : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_87\                        : signed(23 downto 0);
  signal \c$case_alt_33\                       : signed(23 downto 0);
  signal result_70                             : signed(23 downto 0);
  signal \c$app_arg_88\                        : signed(47 downto 0);
  signal \c$app_arg_89\                        : signed(23 downto 0);
  -- src/LowPassFir.hs:371:1-20
  signal \on_14\                               : boolean;
  signal \c$case_alt_34\                       : signed(23 downto 0);
  signal result_71                             : signed(23 downto 0);
  signal \c$app_arg_90\                        : signed(47 downto 0);
  signal \c$app_arg_91\                        : signed(47 downto 0);
  -- src/LowPassFir.hs:371:1-20
  signal level_0                               : unsigned(7 downto 0);
  -- src/LowPassFir.hs:650:1-10
  signal distToneBlendPipe                     : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_72                             : clash_lowpass_fir_types.Maybe;
  signal \c$app_arg_92\                        : signed(47 downto 0);
  signal \c$case_alt_35\                       : signed(23 downto 0);
  signal result_73                             : signed(23 downto 0);
  signal \c$app_arg_93\                        : signed(23 downto 0);
  signal \c$app_arg_94\                        : signed(47 downto 0);
  signal \c$case_alt_36\                       : signed(23 downto 0);
  signal result_74                             : signed(23 downto 0);
  signal \c$app_arg_95\                        : signed(23 downto 0);
  signal result_75                             : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:360:1-24
  signal \on_15\                               : boolean;
  -- src/LowPassFir.hs:650:1-10
  signal x_27                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:650:1-10
  signal ds1_11                                : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_76                             : clash_lowpass_fir_types.Maybe;
  signal result_77                             : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_96\                        : signed(47 downto 0);
  signal \c$app_arg_97\                        : signed(47 downto 0);
  signal \c$app_arg_98\                        : signed(47 downto 0);
  -- src/LowPassFir.hs:347:1-27
  signal toneInv                               : unsigned(7 downto 0);
  signal \c$app_arg_99\                        : signed(47 downto 0);
  signal \c$app_arg_100\                       : signed(47 downto 0);
  -- src/LowPassFir.hs:347:1-27
  signal \on_16\                               : boolean;
  signal \c$app_arg_101\                       : signed(47 downto 0);
  -- src/LowPassFir.hs:347:1-27
  signal tone                                  : unsigned(7 downto 0);
  -- src/LowPassFir.hs:650:1-10
  signal distTonePrevR                         : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:650:1-10
  signal \c$distTonePrevR_app_arg\             : signed(23 downto 0);
  -- src/LowPassFir.hs:650:1-10
  signal distTonePrevL                         : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:650:1-10
  signal \c$distTonePrevL_app_arg\             : signed(23 downto 0);
  -- src/LowPassFir.hs:650:1-10
  signal x_28                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:152:1-7
  signal x_29                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:152:1-7
  signal ds1_12                                : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_78                             : clash_lowpass_fir_types.Maybe;
  -- src/LowPassFir.hs:340:1-24
  signal threshold_0                           : signed(23 downto 0);
  -- src/LowPassFir.hs:340:1-24
  signal \on_17\                               : boolean;
  signal result_79                             : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_102\                       : signed(23 downto 0);
  signal result_80                             : signed(23 downto 0);
  signal \c$case_alt_37\                       : signed(23 downto 0);
  signal \c$app_arg_103\                       : signed(23 downto 0);
  signal \c$app_arg_104\                       : signed(23 downto 0);
  signal result_81                             : signed(23 downto 0);
  signal \c$case_alt_38\                       : signed(23 downto 0);
  signal \c$app_arg_105\                       : signed(23 downto 0);
  -- src/LowPassFir.hs:650:1-10
  signal x_30                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:650:1-10
  signal ds1_13                                : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_82                             : clash_lowpass_fir_types.Maybe;
  signal \c$app_arg_106\                       : signed(47 downto 0);
  signal \c$case_alt_39\                       : signed(23 downto 0);
  signal result_83                             : signed(23 downto 0);
  signal \c$app_arg_107\                       : signed(23 downto 0);
  signal \c$app_arg_108\                       : signed(47 downto 0);
  signal \c$case_alt_40\                       : signed(23 downto 0);
  signal result_84                             : signed(23 downto 0);
  signal \c$app_arg_109\                       : signed(23 downto 0);
  signal result_85                             : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:334:1-25
  signal \on_18\                               : boolean;
  -- src/LowPassFir.hs:650:1-10
  signal x_31                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:650:1-10
  signal ds1_14                                : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_86                             : clash_lowpass_fir_types.Maybe;
  signal result_87                             : clash_lowpass_fir_types.Frame;
  signal result_88                             : signed(24 downto 0);
  -- src/LowPassFir.hs:319:1-28
  signal rawThreshold_0                        : signed(24 downto 0);
  signal \c$app_arg_110\                       : signed(47 downto 0);
  signal \c$app_arg_111\                       : signed(47 downto 0);
  -- src/LowPassFir.hs:319:1-28
  signal \on_19\                               : boolean;
  signal \c$app_arg_112\                       : signed(47 downto 0);
  -- src/LowPassFir.hs:319:1-28
  signal driveGain_0                           : unsigned(11 downto 0);
  -- src/LowPassFir.hs:319:1-28
  signal amount                                : unsigned(7 downto 0);
  -- src/LowPassFir.hs:650:1-10
  signal x_32                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:650:1-10
  signal ds1_15                                : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_89                             : clash_lowpass_fir_types.Maybe;
  signal result_90                             : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_113\                       : signed(23 downto 0);
  signal \c$case_alt_41\                       : signed(23 downto 0);
  signal result_91                             : signed(23 downto 0);
  signal \c$app_arg_114\                       : signed(47 downto 0);
  signal \c$app_arg_115\                       : signed(23 downto 0);
  -- src/LowPassFir.hs:310:1-19
  signal \on_20\                               : boolean;
  signal \c$case_alt_42\                       : signed(23 downto 0);
  signal result_92                             : signed(23 downto 0);
  signal \c$app_arg_116\                       : signed(47 downto 0);
  signal \c$app_arg_117\                       : signed(47 downto 0);
  -- src/LowPassFir.hs:310:1-19
  signal level_1                               : unsigned(7 downto 0);
  -- src/LowPassFir.hs:650:1-10
  signal odToneBlendPipe                       : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_93                             : clash_lowpass_fir_types.Maybe;
  signal \c$app_arg_118\                       : signed(47 downto 0);
  signal \c$case_alt_43\                       : signed(23 downto 0);
  signal result_94                             : signed(23 downto 0);
  signal \c$app_arg_119\                       : signed(23 downto 0);
  signal \c$app_arg_120\                       : signed(47 downto 0);
  signal \c$case_alt_44\                       : signed(23 downto 0);
  signal result_95                             : signed(23 downto 0);
  signal \c$app_arg_121\                       : signed(23 downto 0);
  signal result_96                             : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:299:1-23
  signal \on_21\                               : boolean;
  -- src/LowPassFir.hs:650:1-10
  signal x_33                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:650:1-10
  signal ds1_16                                : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_97                             : clash_lowpass_fir_types.Maybe;
  signal result_98                             : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_122\                       : signed(47 downto 0);
  signal \c$app_arg_123\                       : signed(47 downto 0);
  signal \c$app_arg_124\                       : signed(47 downto 0);
  -- src/LowPassFir.hs:286:1-26
  signal toneInv_0                             : unsigned(7 downto 0);
  signal \c$app_arg_125\                       : signed(47 downto 0);
  signal \c$app_arg_126\                       : signed(47 downto 0);
  -- src/LowPassFir.hs:286:1-26
  signal \on_22\                               : boolean;
  signal \c$app_arg_127\                       : signed(47 downto 0);
  -- src/LowPassFir.hs:286:1-26
  signal tone_0                                : unsigned(7 downto 0);
  -- src/LowPassFir.hs:650:1-10
  signal odTonePrevR                           : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:650:1-10
  signal \c$odTonePrevR_app_arg\               : signed(23 downto 0);
  -- src/LowPassFir.hs:650:1-10
  signal odTonePrevL                           : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:650:1-10
  signal \c$odTonePrevL_app_arg\               : signed(23 downto 0);
  -- src/LowPassFir.hs:650:1-10
  signal x_34                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:152:1-7
  signal x_35                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:152:1-7
  signal ds1_17                                : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_99                             : clash_lowpass_fir_types.Maybe;
  -- src/LowPassFir.hs:280:1-23
  signal \on_23\                               : boolean;
  signal result_100                            : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_128\                       : signed(23 downto 0);
  signal result_101                            : signed(23 downto 0);
  signal \c$case_alt_45\                       : signed(23 downto 0);
  signal \c$app_arg_129\                       : signed(24 downto 0);
  signal \c$app_arg_130\                       : signed(24 downto 0);
  signal \c$app_arg_131\                       : signed(24 downto 0);
  signal \c$app_arg_132\                       : signed(23 downto 0);
  signal result_102                            : signed(23 downto 0);
  signal \c$case_alt_46\                       : signed(23 downto 0);
  signal \c$app_arg_133\                       : signed(24 downto 0);
  signal \c$app_arg_134\                       : signed(24 downto 0);
  signal \c$app_arg_135\                       : signed(24 downto 0);
  -- src/LowPassFir.hs:650:1-10
  signal x_36                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:650:1-10
  signal ds1_18                                : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_103                            : clash_lowpass_fir_types.Maybe;
  signal \c$app_arg_136\                       : signed(47 downto 0);
  signal \c$case_alt_47\                       : signed(23 downto 0);
  signal result_104                            : signed(23 downto 0);
  signal \c$app_arg_137\                       : signed(23 downto 0);
  signal \c$app_arg_138\                       : signed(47 downto 0);
  signal \c$case_alt_48\                       : signed(23 downto 0);
  signal result_105                            : signed(23 downto 0);
  signal \c$app_arg_139\                       : signed(23 downto 0);
  signal result_106                            : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:274:1-24
  signal \on_24\                               : boolean;
  -- src/LowPassFir.hs:650:1-10
  signal x_37                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:650:1-10
  signal ds1_19                                : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_107                            : clash_lowpass_fir_types.Maybe;
  signal result_108                            : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_140\                       : signed(47 downto 0);
  signal \c$app_arg_141\                       : signed(47 downto 0);
  -- src/LowPassFir.hs:267:1-27
  signal \on_25\                               : boolean;
  signal \c$app_arg_142\                       : signed(47 downto 0);
  -- src/LowPassFir.hs:267:1-27
  signal driveGain_1                           : unsigned(11 downto 0);
  -- src/LowPassFir.hs:650:1-10
  signal x_38                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:650:1-10
  signal ds1_20                                : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_109                            : clash_lowpass_fir_types.Maybe;
  signal result_110                            : clash_lowpass_fir_types.Frame;
  signal \c$case_alt_49\                       : signed(23 downto 0);
  signal result_111                            : signed(23 downto 0);
  signal \c$app_arg_143\                       : signed(47 downto 0);
  signal \c$case_alt_50\                       : signed(23 downto 0);
  signal result_112                            : signed(23 downto 0);
  signal \c$app_arg_144\                       : signed(47 downto 0);
  signal \c$app_arg_145\                       : signed(47 downto 0);
  -- src/LowPassFir.hs:650:1-10
  signal gateGain                              : unsigned(11 downto 0) := to_unsigned(4095,12);
  signal \c$case_alt_51\                       : unsigned(11 downto 0);
  signal \c$case_alt_52\                       : unsigned(11 downto 0);
  signal \c$case_alt_53\                       : unsigned(11 downto 0);
  signal \c$case_alt_54\                       : unsigned(11 downto 0);
  -- src/LowPassFir.hs:252:1-12
  signal f_2                                   : clash_lowpass_fir_types.Frame;
  signal result_113                            : unsigned(11 downto 0);
  -- src/LowPassFir.hs:650:1-10
  signal gateOpen                              : boolean := true;
  signal result_114                            : boolean;
  signal \c$case_alt_55\                       : boolean;
  signal result_115                            : boolean;
  signal \c$case_alt_56\                       : boolean;
  signal \c$case_alt_57\                       : boolean;
  -- src/LowPassFir.hs:117:1-7
  signal x_39                                  : signed(47 downto 0);
  signal \c$case_alt_58\                       : signed(23 downto 0);
  signal result_116                            : signed(23 downto 0);
  signal \c$app_arg_146\                       : signed(47 downto 0);
  signal \c$app_arg_147\                       : signed(47 downto 0);
  -- src/LowPassFir.hs:240:1-12
  signal closeThreshold                        : signed(23 downto 0);
  -- src/LowPassFir.hs:93:1-9
  signal x_40                                  : unsigned(7 downto 0);
  signal \c$app_arg_148\                       : std_logic_vector(31 downto 0);
  -- src/LowPassFir.hs:240:1-12
  signal f_3                                   : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:650:1-10
  signal gateEnv                               : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:229:1-11
  signal \c$decay_app_arg\                     : signed(24 downto 0);
  signal result_117                            : signed(23 downto 0);
  signal \c$case_alt_59\                       : signed(23 downto 0);
  signal \c$case_alt_60\                       : signed(23 downto 0);
  -- src/LowPassFir.hs:229:1-11
  signal f_4                                   : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:229:1-11
  signal decay                                 : signed(23 downto 0);
  signal result_118                            : signed(23 downto 0);
  -- src/LowPassFir.hs:152:1-7
  signal x_41                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:650:1-10
  signal gateLevelPipe                         : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_119                            : clash_lowpass_fir_types.Maybe;
  signal result_120                            : signed(23 downto 0);
  signal \c$case_alt_61\                       : clash_lowpass_fir_types.Frame;
  signal \c$case_alt_62\                       : signed(23 downto 0);
  signal result_121                            : signed(23 downto 0);
  signal \c$case_alt_63\                       : signed(23 downto 0);
  signal result_122                            : signed(23 downto 0);
  -- src/LowPassFir.hs:650:1-10
  signal x_42                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:650:1-10
  signal ds1_21                                : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  -- src/LowPassFir.hs:189:1-9
  signal validIn                               : boolean;
  -- src/LowPassFir.hs:189:1-9
  signal right                                 : signed(23 downto 0);
  -- src/LowPassFir.hs:189:1-9
  signal left                                  : signed(23 downto 0);
  signal result_123                            : clash_lowpass_fir_types.Tuple2_0;
  signal \c$app_arg_149\                       : std_logic_vector(47 downto 0);
  signal result_124                            : clash_lowpass_fir_types.Maybe;
  -- src/LowPassFir.hs:650:1-10
  signal \c$reverbAddr_case_alt\               : clash_lowpass_fir_types.index_1024;
  signal result_selection_res                  : boolean;
  signal \c$bv\                                : std_logic_vector(31 downto 0);
  signal \c$bv_0\                              : std_logic_vector(31 downto 0);
  signal \c$shI\                               : signed(63 downto 0);
  signal \c$case_alt_selection_res\            : boolean;
  signal result_selection_res_2                : boolean;
  signal \c$shI_0\                             : signed(63 downto 0);
  signal \c$case_alt_selection_res_0\          : boolean;
  signal result_selection_res_3                : boolean;
  signal \c$bv_1\                              : std_logic_vector(31 downto 0);
  signal \c$wrI\                               : signed(63 downto 0);
  signal \c$wrI_0\                             : signed(63 downto 0);
  signal \c$shI_1\                             : signed(63 downto 0);
  signal \c$case_alt_selection_res_1\          : boolean;
  signal result_selection_res_4                : boolean;
  signal \c$shI_2\                             : signed(63 downto 0);
  signal \c$case_alt_selection_res_2\          : boolean;
  signal result_selection_res_5                : boolean;
  signal \c$bv_2\                              : std_logic_vector(31 downto 0);
  signal \c$bv_3\                              : std_logic_vector(31 downto 0);
  signal \c$bv_4\                              : std_logic_vector(31 downto 0);
  signal \c$shI_3\                             : signed(63 downto 0);
  signal \c$shI_4\                             : signed(63 downto 0);
  signal \c$case_alt_selection_res_3\          : boolean;
  signal result_selection_res_6                : boolean;
  signal \c$shI_5\                             : signed(63 downto 0);
  signal \c$shI_6\                             : signed(63 downto 0);
  signal \c$case_alt_selection_res_4\          : boolean;
  signal result_selection_res_7                : boolean;
  signal \c$bv_5\                              : std_logic_vector(31 downto 0);
  signal \c$bv_6\                              : std_logic_vector(31 downto 0);
  signal \c$case_alt_selection_res_5\          : boolean;
  signal result_selection_res_8                : boolean;
  signal \c$shI_7\                             : signed(63 downto 0);
  signal \c$case_alt_selection_res_6\          : boolean;
  signal result_selection_res_9                : boolean;
  signal \c$shI_8\                             : signed(63 downto 0);
  signal \c$bv_7\                              : std_logic_vector(31 downto 0);
  signal \c$case_alt_selection_res_7\          : boolean;
  signal result_selection_res_10               : boolean;
  signal \c$case_alt_selection_res_8\          : boolean;
  signal result_selection_res_11               : boolean;
  signal \c$case_alt_selection_res_9\          : boolean;
  signal result_selection_res_12               : boolean;
  signal \c$case_alt_selection_res_10\         : boolean;
  signal result_selection_res_13               : boolean;
  signal \c$shI_9\                             : signed(63 downto 0);
  signal \c$shI_10\                            : signed(63 downto 0);
  signal \c$shI_11\                            : signed(63 downto 0);
  signal \c$shI_12\                            : signed(63 downto 0);
  signal result_selection_res_14               : boolean;
  signal \c$case_alt_selection_res_11\         : boolean;
  signal \c$shI_13\                            : signed(63 downto 0);
  signal \c$shI_14\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_12\         : boolean;
  signal result_selection_res_15               : boolean;
  signal \c$shI_15\                            : signed(63 downto 0);
  signal \c$bv_8\                              : std_logic_vector(31 downto 0);
  signal result_selection_res_16               : boolean;
  signal \c$case_alt_selection_res_13\         : boolean;
  signal \c$shI_16\                            : signed(63 downto 0);
  signal \c$shI_17\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_14\         : boolean;
  signal result_selection_res_17               : boolean;
  signal \c$shI_18\                            : signed(63 downto 0);
  signal \c$bv_9\                              : std_logic_vector(31 downto 0);
  signal \c$case_alt_selection_res_15\         : boolean;
  signal result_selection_res_18               : boolean;
  signal \c$shI_19\                            : signed(63 downto 0);
  signal \c$bv_10\                             : std_logic_vector(31 downto 0);
  signal \c$case_alt_selection_res_16\         : boolean;
  signal result_selection_res_19               : boolean;
  signal \c$shI_20\                            : signed(63 downto 0);
  signal \c$bv_11\                             : std_logic_vector(31 downto 0);
  signal \c$bv_12\                             : std_logic_vector(31 downto 0);
  signal \c$shI_21\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_17\         : boolean;
  signal result_selection_res_20               : boolean;
  signal \c$shI_22\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_18\         : boolean;
  signal result_selection_res_21               : boolean;
  signal \c$bv_13\                             : std_logic_vector(31 downto 0);
  signal \c$shI_23\                            : signed(63 downto 0);
  signal \c$bv_14\                             : std_logic_vector(31 downto 0);
  signal \c$shI_24\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_19\         : boolean;
  signal result_selection_res_22               : boolean;
  signal \c$shI_25\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_20\         : boolean;
  signal result_selection_res_23               : boolean;
  signal \c$bv_15\                             : std_logic_vector(31 downto 0);
  signal result_selection_res_24               : boolean;
  signal \c$case_alt_selection_res_21\         : boolean;
  signal result_selection_res_25               : boolean;
  signal \c$case_alt_selection_res_22\         : boolean;
  signal result_selection_res_26               : boolean;
  signal \c$bv_16\                             : std_logic_vector(31 downto 0);
  signal \c$bv_17\                             : std_logic_vector(31 downto 0);
  signal \c$shI_26\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_23\         : boolean;
  signal result_selection_res_27               : boolean;
  signal \c$shI_27\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_24\         : boolean;
  signal result_selection_res_28               : boolean;
  signal \c$bv_18\                             : std_logic_vector(31 downto 0);
  signal \c$shI_28\                            : signed(63 downto 0);
  signal \c$shI_29\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_25\         : boolean;
  signal result_selection_res_29               : boolean;
  signal \c$shI_30\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_26\         : boolean;
  signal result_selection_res_30               : boolean;
  signal \c$bv_19\                             : std_logic_vector(31 downto 0);
  signal \c$bv_20\                             : std_logic_vector(31 downto 0);
  signal \c$bv_21\                             : std_logic_vector(31 downto 0);
  signal \c$case_alt_selection_res_27\         : boolean;
  signal result_selection_res_31               : boolean;
  signal \c$case_alt_selection_res_28\         : boolean;
  signal result_selection_res_32               : boolean;
  signal \c$bv_22\                             : std_logic_vector(31 downto 0);
  signal \c$case_alt_selection_res_29\         : boolean;
  signal result_selection_res_33               : boolean;
  signal \c$shI_31\                            : signed(63 downto 0);
  signal \c$bv_23\                             : std_logic_vector(31 downto 0);
  signal \c$case_alt_selection_res_30\         : boolean;
  signal result_selection_res_34               : boolean;
  signal \c$shI_32\                            : signed(63 downto 0);
  signal \c$bv_24\                             : std_logic_vector(31 downto 0);
  signal \c$shI_33\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_31\         : boolean;
  signal result_selection_res_35               : boolean;
  signal \c$shI_34\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_32\         : boolean;
  signal result_selection_res_36               : boolean;
  signal \c$bv_25\                             : std_logic_vector(31 downto 0);
  signal \c$bv_26\                             : std_logic_vector(31 downto 0);
  signal \c$bv_27\                             : std_logic_vector(31 downto 0);
  signal \c$bv_28\                             : std_logic_vector(31 downto 0);
  signal result_selection_res_37               : boolean;
  signal \c$case_alt_selection_res_33\         : boolean;
  signal result_selection_res_38               : boolean;
  signal \c$case_alt_selection_res_34\         : boolean;
  signal \c$shI_35\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_35\         : boolean;
  signal result_selection_res_39               : boolean;
  signal \c$shI_36\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_36\         : boolean;
  signal result_selection_res_40               : boolean;
  signal \c$bv_29\                             : std_logic_vector(31 downto 0);
  signal result_selection_res_41               : boolean;
  signal \c$bv_30\                             : std_logic_vector(31 downto 0);
  signal \c$bv_31\                             : std_logic_vector(31 downto 0);
  signal \c$case_alt_selection_res_37\         : boolean;
  signal result_selection_res_42               : boolean;
  signal \c$shI_37\                            : signed(63 downto 0);
  signal \c$bv_32\                             : std_logic_vector(31 downto 0);
  signal \c$case_alt_selection_res_38\         : boolean;
  signal result_selection_res_43               : boolean;
  signal \c$shI_38\                            : signed(63 downto 0);
  signal \c$bv_33\                             : std_logic_vector(31 downto 0);
  signal \c$shI_39\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_39\         : boolean;
  signal result_selection_res_44               : boolean;
  signal \c$shI_40\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_40\         : boolean;
  signal result_selection_res_45               : boolean;
  signal \c$bv_34\                             : std_logic_vector(31 downto 0);
  signal \c$bv_35\                             : std_logic_vector(31 downto 0);
  signal \c$bv_36\                             : std_logic_vector(31 downto 0);
  signal \c$bv_37\                             : std_logic_vector(31 downto 0);
  signal result_selection_res_46               : boolean;
  signal \c$case_alt_selection_res_41\         : boolean;
  signal \c$shI_41\                            : signed(63 downto 0);
  signal \c$shI_42\                            : signed(63 downto 0);
  signal result_selection_res_47               : boolean;
  signal \c$case_alt_selection_res_42\         : boolean;
  signal \c$shI_43\                            : signed(63 downto 0);
  signal \c$shI_44\                            : signed(63 downto 0);
  signal \c$shI_45\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_43\         : boolean;
  signal result_selection_res_48               : boolean;
  signal \c$shI_46\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_44\         : boolean;
  signal result_selection_res_49               : boolean;
  signal \c$bv_38\                             : std_logic_vector(31 downto 0);
  signal \c$bv_39\                             : std_logic_vector(31 downto 0);
  signal \c$bv_40\                             : std_logic_vector(31 downto 0);
  signal result_selection_res_50               : boolean;
  signal \c$bv_41\                             : std_logic_vector(31 downto 0);
  signal \c$case_alt_selection_res_45\         : boolean;
  signal result_selection_res_51               : boolean;
  signal \c$shI_47\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_46\         : boolean;
  signal result_selection_res_52               : boolean;
  signal \c$shI_48\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_47\         : boolean;
  signal \c$case_alt_selection_res_48\         : boolean;
  signal \c$case_alt_selection_res_49\         : boolean;
  signal \c$bv_42\                             : std_logic_vector(31 downto 0);
  signal \c$case_alt_selection_res_50\         : boolean;
  signal \c$case_alt_selection_res_51\         : boolean;
  signal \c$case_alt_selection_res_52\         : boolean;
  signal \c$case_alt_selection_res_53\         : boolean;
  signal result_selection_res_53               : boolean;
  signal \c$shI_49\                            : signed(63 downto 0);
  signal \c$shI_50\                            : signed(63 downto 0);
  signal \c$shI_51\                            : signed(63 downto 0);
  signal result_selection_res_54               : boolean;
  signal \c$case_alt_selection_res_54\         : boolean;
  signal \c$case_alt_selection_res_55\         : boolean;
  signal \c$bv_43\                             : std_logic_vector(31 downto 0);
  signal result_selection_res_55               : boolean;
  signal \c$case_alt_selection_res_56\         : boolean;
  signal result_selection_res_56               : boolean;
  signal \c$case_alt_selection_res_57\         : boolean;
  signal result_selection_res_57               : boolean;
  signal \c$reverbAddr_case_alt_selection_res\ : boolean;
  signal result                                : clash_lowpass_fir_types.Tuple4;

begin
  result <= ( Tuple4_sel0_std_logic_vector => outReg.AxisOut_sel0_oData
            , Tuple4_sel1_boolean_0 => outReg.AxisOut_sel1_oValid
            , Tuple4_sel2_boolean_1 => outReg.AxisOut_sel2_oLast
            , Tuple4_sel3_boolean_2 => axis_out_tready );

  result_selection_res <= \new\ and ((not outReg.AxisOut_sel1_oValid) or consumed);

  result_0 <= ( AxisOut_sel0_oData => \c$app_arg_0\
              , AxisOut_sel1_oValid => \new\
              , AxisOut_sel2_oLast => \c$app_arg\ ) when result_selection_res else
              \c$case_alt\;

  \c$case_alt\ <= ( AxisOut_sel0_oData => std_logic_vector'(x"000000000000")
                  , AxisOut_sel1_oValid => false
                  , AxisOut_sel2_oLast => false ) when consumed else
                  outReg;

  with (outPipe(875 downto 875)) select
    \new\ <= false when "0",
             true when others;

  with (outPipe(875 downto 875)) select
    \c$app_arg\ <= false when "0",
                   f.Frame_sel2_fLast when others;

  with (outPipe(875 downto 875)) select
    \c$app_arg_0\ <= std_logic_vector'(x"000000000000") when "0",
                     std_logic_vector'(std_logic_vector'(((std_logic_vector(f.Frame_sel1_fR)))) & std_logic_vector'(((std_logic_vector(f.Frame_sel0_fL))))) when others;

  f <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(outPipe(874 downto 0)));

  consumed <= outReg.AxisOut_sel1_oValid and axis_out_tready;

  -- register begin
  outReg_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      outReg <= ( AxisOut_sel0_oData => std_logic_vector'(x"000000000000")
  , AxisOut_sel1_oValid => false
  , AxisOut_sel2_oLast => false );
    elsif rising_edge(clk) then
      outReg <= result_0;
    end if;
  end process;
  -- register end

  result_1 <= ( Frame_sel0_fL => x_1.Frame_sel0_fL
              , Frame_sel1_fR => x_1.Frame_sel1_fR
              , Frame_sel2_fLast => x_1.Frame_sel2_fLast
              , Frame_sel3_fGate => x_1.Frame_sel3_fGate
              , Frame_sel4_fOd => x_1.Frame_sel4_fOd
              , Frame_sel5_fDist => x_1.Frame_sel5_fDist
              , Frame_sel6_fEq => x_1.Frame_sel6_fEq
              , Frame_sel7_fRat => x_1.Frame_sel7_fRat
              , Frame_sel8_fReverb => x_1.Frame_sel8_fReverb
              , Frame_sel9_fAddr => x_1.Frame_sel9_fAddr
              , Frame_sel10_fDryL => x_1.Frame_sel10_fDryL
              , Frame_sel11_fDryR => x_1.Frame_sel11_fDryR
              , Frame_sel12_fWetL => x_1.Frame_sel12_fWetL
              , Frame_sel13_fWetR => x_1.Frame_sel13_fWetR
              , Frame_sel14_fFbL => x_1.Frame_sel14_fFbL
              , Frame_sel15_fFbR => x_1.Frame_sel15_fFbR
              , Frame_sel16_fEqLowL => x_1.Frame_sel16_fEqLowL
              , Frame_sel17_fEqLowR => x_1.Frame_sel17_fEqLowR
              , Frame_sel18_fEqMidL => x_1.Frame_sel18_fEqMidL
              , Frame_sel19_fEqMidR => x_1.Frame_sel19_fEqMidR
              , Frame_sel20_fEqHighL => x_1.Frame_sel20_fEqHighL
              , Frame_sel21_fEqHighR => x_1.Frame_sel21_fEqHighR
              , Frame_sel22_fEqHighLpL => x_1.Frame_sel22_fEqHighLpL
              , Frame_sel23_fEqHighLpR => x_1.Frame_sel23_fEqHighLpR
              , Frame_sel24_fAccL => x_1.Frame_sel24_fAccL
              , Frame_sel25_fAccR => x_1.Frame_sel25_fAccR
              , Frame_sel26_fAcc2L => x_1.Frame_sel26_fAcc2L
              , Frame_sel27_fAcc2R => x_1.Frame_sel27_fAcc2R
              , Frame_sel28_fAcc3L => \c$app_arg_2\
              , Frame_sel29_fAcc3R => \c$app_arg_1\ );

  \c$app_arg_1\ <= resize((resize(x_1.Frame_sel13_fWetR,48)) * \c$app_arg_3\, 48) when \on\ else
                   to_signed(0,48);

  \c$app_arg_2\ <= resize((resize(x_1.Frame_sel12_fWetL,48)) * \c$app_arg_3\, 48) when \on\ else
                   to_signed(0,48);

  \c$bv\ <= (x_1.Frame_sel3_fGate);

  \on\ <= (\c$bv\(5 downto 5)) = std_logic_vector'("1");

  \c$app_arg_3\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(gain)))))))),48);

  \c$bv_0\ <= (x_1.Frame_sel8_fReverb);

  gain <= unsigned((\c$bv_0\(7 downto 0)));

  -- register begin
  reverbToneBlendPipe_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      reverbToneBlendPipe <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      reverbToneBlendPipe <= result_2;
    end if;
  end process;
  -- register end

  with (ds1(875 downto 875)) select
    result_2 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                std_logic_vector'("1" & ((std_logic_vector(\c$case_alt_2\.Frame_sel0_fL)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel1_fR)
                 & clash_lowpass_fir_types.toSLV(\c$case_alt_2\.Frame_sel2_fLast)
                 & \c$case_alt_2\.Frame_sel3_fGate
                 & \c$case_alt_2\.Frame_sel4_fOd
                 & \c$case_alt_2\.Frame_sel5_fDist
                 & \c$case_alt_2\.Frame_sel6_fEq
                 & \c$case_alt_2\.Frame_sel7_fRat
                 & \c$case_alt_2\.Frame_sel8_fReverb
                 & std_logic_vector(\c$case_alt_2\.Frame_sel9_fAddr)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel10_fDryL)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel11_fDryR)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel12_fWetL)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel13_fWetR)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel14_fFbL)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel15_fFbR)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel16_fEqLowL)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel17_fEqLowR)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel18_fEqMidL)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel19_fEqMidR)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel20_fEqHighL)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel21_fEqHighR)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel22_fEqHighLpL)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel23_fEqHighLpR)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel24_fAccL)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel25_fAccR)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel26_fAcc2L)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel27_fAcc2R)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel28_fAcc3L)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel29_fAcc3R)))) when others;

  \c$shI\ <= (to_signed(8,64));

  capp_arg_4_shiftR : block
    signal sh : natural;
  begin
    sh <=
        -- pragma translate_off
        natural'high when (\c$shI\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI\);
    \c$app_arg_4\ <= shift_right((x.Frame_sel24_fAccL + x.Frame_sel26_fAcc2L),sh)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res\ <= \c$app_arg_4\ < to_signed(-8388608,48);

  \c$case_alt_0\ <= to_signed(-8388608,24) when \c$case_alt_selection_res\ else
                    resize(\c$app_arg_4\,24);

  result_selection_res_2 <= \c$app_arg_4\ > to_signed(8388607,48);

  result_3 <= to_signed(8388607,24) when result_selection_res_2 else
              \c$case_alt_0\;

  \c$shI_0\ <= (to_signed(8,64));

  capp_arg_5_shiftR : block
    signal sh_0 : natural;
  begin
    sh_0 <=
        -- pragma translate_off
        natural'high when (\c$shI_0\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_0\);
    \c$app_arg_5\ <= shift_right((x.Frame_sel25_fAccR + x.Frame_sel27_fAcc2R),sh_0)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_0\ <= \c$app_arg_5\ < to_signed(-8388608,48);

  \c$case_alt_1\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_0\ else
                    resize(\c$app_arg_5\,24);

  result_selection_res_3 <= \c$app_arg_5\ > to_signed(8388607,48);

  result_4 <= to_signed(8388607,24) when result_selection_res_3 else
              \c$case_alt_1\;

  \c$case_alt_2\ <= ( Frame_sel0_fL => x.Frame_sel0_fL
                    , Frame_sel1_fR => x.Frame_sel1_fR
                    , Frame_sel2_fLast => x.Frame_sel2_fLast
                    , Frame_sel3_fGate => x.Frame_sel3_fGate
                    , Frame_sel4_fOd => x.Frame_sel4_fOd
                    , Frame_sel5_fDist => x.Frame_sel5_fDist
                    , Frame_sel6_fEq => x.Frame_sel6_fEq
                    , Frame_sel7_fRat => x.Frame_sel7_fRat
                    , Frame_sel8_fReverb => x.Frame_sel8_fReverb
                    , Frame_sel9_fAddr => x.Frame_sel9_fAddr
                    , Frame_sel10_fDryL => x.Frame_sel10_fDryL
                    , Frame_sel11_fDryR => x.Frame_sel11_fDryR
                    , Frame_sel12_fWetL => result_3
                    , Frame_sel13_fWetR => result_4
                    , Frame_sel14_fFbL => x.Frame_sel14_fFbL
                    , Frame_sel15_fFbR => x.Frame_sel15_fFbR
                    , Frame_sel16_fEqLowL => x.Frame_sel16_fEqLowL
                    , Frame_sel17_fEqLowR => x.Frame_sel17_fEqLowR
                    , Frame_sel18_fEqMidL => x.Frame_sel18_fEqMidL
                    , Frame_sel19_fEqMidR => x.Frame_sel19_fEqMidR
                    , Frame_sel20_fEqHighL => x.Frame_sel20_fEqHighL
                    , Frame_sel21_fEqHighR => x.Frame_sel21_fEqHighR
                    , Frame_sel22_fEqHighLpL => x.Frame_sel22_fEqHighLpL
                    , Frame_sel23_fEqHighLpR => x.Frame_sel23_fEqHighLpR
                    , Frame_sel24_fAccL => x.Frame_sel24_fAccL
                    , Frame_sel25_fAccR => x.Frame_sel25_fAccR
                    , Frame_sel26_fAcc2L => x.Frame_sel26_fAcc2L
                    , Frame_sel27_fAcc2R => x.Frame_sel27_fAcc2R
                    , Frame_sel28_fAcc3L => x.Frame_sel28_fAcc3L
                    , Frame_sel29_fAcc3R => x.Frame_sel29_fAcc3R );

  x <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1(874 downto 0)));

  -- register begin
  ds1_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1 <= result_5;
    end if;
  end process;
  -- register end

  with (\c$ds1_app_arg\(875 downto 875)) select
    result_5 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                std_logic_vector'("1" & ((std_logic_vector(x_0.Frame_sel0_fL)
                 & std_logic_vector(x_0.Frame_sel1_fR)
                 & clash_lowpass_fir_types.toSLV(x_0.Frame_sel2_fLast)
                 & x_0.Frame_sel3_fGate
                 & x_0.Frame_sel4_fOd
                 & x_0.Frame_sel5_fDist
                 & x_0.Frame_sel6_fEq
                 & x_0.Frame_sel7_fRat
                 & x_0.Frame_sel8_fReverb
                 & std_logic_vector(x_0.Frame_sel9_fAddr)
                 & std_logic_vector(x_0.Frame_sel10_fDryL)
                 & std_logic_vector(x_0.Frame_sel11_fDryR)
                 & std_logic_vector(x_0.Frame_sel12_fWetL)
                 & std_logic_vector(x_0.Frame_sel13_fWetR)
                 & std_logic_vector(x_0.Frame_sel14_fFbL)
                 & std_logic_vector(x_0.Frame_sel15_fFbR)
                 & std_logic_vector(x_0.Frame_sel16_fEqLowL)
                 & std_logic_vector(x_0.Frame_sel17_fEqLowR)
                 & std_logic_vector(x_0.Frame_sel18_fEqMidL)
                 & std_logic_vector(x_0.Frame_sel19_fEqMidR)
                 & std_logic_vector(x_0.Frame_sel20_fEqHighL)
                 & std_logic_vector(x_0.Frame_sel21_fEqHighR)
                 & std_logic_vector(x_0.Frame_sel22_fEqHighLpL)
                 & std_logic_vector(x_0.Frame_sel23_fEqHighLpR)
                 & std_logic_vector(resize((resize(result_8,48)) * \c$app_arg_7\, 48))
                 & std_logic_vector(resize((resize(result_7,48)) * \c$app_arg_7\, 48))
                 & std_logic_vector(resize((resize(reverbTonePrevL,48)) * \c$app_arg_6\, 48))
                 & std_logic_vector(resize((resize(reverbTonePrevR,48)) * \c$app_arg_6\, 48))
                 & std_logic_vector(x_0.Frame_sel28_fAcc3L)
                 & std_logic_vector(x_0.Frame_sel29_fAcc3R)))) when others;

  \c$app_arg_6\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(gain_0)))))))),48);

  gain_0 <= to_unsigned(255,8) - gain_1;

  \c$app_arg_7\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(gain_1)))))))),48);

  \c$bv_1\ <= (x_0.Frame_sel8_fReverb);

  gain_1 <= unsigned((\c$bv_1\(15 downto 8)));

  x_0 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(\c$ds1_app_arg\(874 downto 0)));

  -- register begin
  reverbTonePrevR_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      reverbTonePrevR <= to_signed(0,24);
    elsif rising_edge(clk) then
      reverbTonePrevR <= \c$reverbTonePrevR_app_arg\;
    end if;
  end process;
  -- register end

  with (reverbToneBlendPipe(875 downto 875)) select
    \c$reverbTonePrevR_app_arg\ <= reverbTonePrevR when "0",
                                   x_1.Frame_sel13_fWetR when others;

  -- register begin
  reverbTonePrevL_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      reverbTonePrevL <= to_signed(0,24);
    elsif rising_edge(clk) then
      reverbTonePrevL <= \c$reverbTonePrevL_app_arg\;
    end if;
  end process;
  -- register end

  with (reverbToneBlendPipe(875 downto 875)) select
    \c$reverbTonePrevL_app_arg\ <= reverbTonePrevL when "0",
                                   x_1.Frame_sel12_fWetL when others;

  x_1 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(reverbToneBlendPipe(874 downto 0)));

  -- register begin
  cds1_app_arg_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      \c$ds1_app_arg\ <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      \c$ds1_app_arg\ <= result_6;
    end if;
  end process;
  -- register end

  f_0 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(eqMixPipe(874 downto 0)));

  with (eqMixPipe(875 downto 875)) select
    result_6 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                std_logic_vector'("1" & ((std_logic_vector(f_0.Frame_sel0_fL)
                 & std_logic_vector(f_0.Frame_sel1_fR)
                 & clash_lowpass_fir_types.toSLV(f_0.Frame_sel2_fLast)
                 & f_0.Frame_sel3_fGate
                 & f_0.Frame_sel4_fOd
                 & f_0.Frame_sel5_fDist
                 & f_0.Frame_sel6_fEq
                 & f_0.Frame_sel7_fRat
                 & f_0.Frame_sel8_fReverb
                 & std_logic_vector(reverbAddr)
                 & std_logic_vector(f_0.Frame_sel0_fL)
                 & std_logic_vector(f_0.Frame_sel1_fR)
                 & std_logic_vector(f_0.Frame_sel12_fWetL)
                 & std_logic_vector(f_0.Frame_sel13_fWetR)
                 & std_logic_vector(f_0.Frame_sel14_fFbL)
                 & std_logic_vector(f_0.Frame_sel15_fFbR)
                 & std_logic_vector(f_0.Frame_sel16_fEqLowL)
                 & std_logic_vector(f_0.Frame_sel17_fEqLowR)
                 & std_logic_vector(f_0.Frame_sel18_fEqMidL)
                 & std_logic_vector(f_0.Frame_sel19_fEqMidR)
                 & std_logic_vector(f_0.Frame_sel20_fEqHighL)
                 & std_logic_vector(f_0.Frame_sel21_fEqHighR)
                 & std_logic_vector(f_0.Frame_sel22_fEqHighLpL)
                 & std_logic_vector(f_0.Frame_sel23_fEqHighLpR)
                 & std_logic_vector(f_0.Frame_sel24_fAccL)
                 & std_logic_vector(f_0.Frame_sel25_fAccR)
                 & std_logic_vector(f_0.Frame_sel26_fAcc2L)
                 & std_logic_vector(f_0.Frame_sel27_fAcc2R)
                 & std_logic_vector(f_0.Frame_sel28_fAcc3L)
                 & std_logic_vector(f_0.Frame_sel29_fAcc3R)))) when others;

  \c$wrI\ <= (signed(std_logic_vector(resize(ds.Tuple2_sel0_index_1024,64))));

  -- blockRam begin
  result_7_blockRam : block
    signal result_7_RAM : clash_lowpass_fir_types.array_of_signed_24(0 to 1023) := clash_lowpass_fir_types.array_of_signed_24'( to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24) );
    signal rd  : integer range 0 to 1024 - 1;
    signal wr  : integer range 0 to 1024 - 1;
  begin
    rd <= to_integer(\c$ds1_app_arg_3\(31 downto 0))
    -- pragma translate_off
                  mod 1024
    -- pragma translate_on
                  ;

    wr <= to_integer(\c$wrI\(31 downto 0))
    -- pragma translate_off
                  mod 1024
    -- pragma translate_on
                  ;

    \c$n\ : process(clk)
    begin
      if rising_edge(clk) then
        if \c$ds1_app_arg_0\   then
          result_7_RAM(wr) <= ds.Tuple2_sel1_signed;
        end if;
        result_7 <= result_7_RAM(rd);
      end if;
    end process;
  end block;
  --end blockRam

  with (wrM(34 downto 34)) select
    ds <= ( Tuple2_sel0_index_1024 => clash_lowpass_fir_types.index_1024'(0 to 9 => '-')
          , Tuple2_sel1_signed => signed'(0 to 23 => '-') ) when "0",
          a1 when others;

  a1 <= clash_lowpass_fir_types.Tuple2'(clash_lowpass_fir_types.fromSLV(wrM(33 downto 0)));

  with (wrM(34 downto 34)) select
    \c$ds1_app_arg_0\ <= false when "0",
                         true when others;

  with (outPipe(875 downto 875)) select
    wrM <= std_logic_vector'("0" & "----------------------------------") when "0",
           std_logic_vector'("1" & ((std_logic_vector(f_1.Frame_sel9_fAddr)
            & std_logic_vector(f_1.Frame_sel15_fFbR)))) when others;

  \c$wrI_0\ <= (signed(std_logic_vector(resize(ds_0.Tuple2_sel0_index_1024,64))));

  -- blockRam begin
  result_8_blockRam : block
    signal result_8_RAM : clash_lowpass_fir_types.array_of_signed_24(0 to 1023) := clash_lowpass_fir_types.array_of_signed_24'( to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24)
                                             , to_signed(0,24) );
    signal rd_0  : integer range 0 to 1024 - 1;
    signal wr_0  : integer range 0 to 1024 - 1;
  begin
    rd_0 <= to_integer(\c$ds1_app_arg_3\(31 downto 0))
    -- pragma translate_off
                  mod 1024
    -- pragma translate_on
                  ;

    wr_0 <= to_integer(\c$wrI_0\(31 downto 0))
    -- pragma translate_off
                  mod 1024
    -- pragma translate_on
                  ;

    \c$n_0\ : process(clk)
    begin
      if rising_edge(clk) then
        if \c$ds1_app_arg_1\   then
          result_8_RAM(wr_0) <= ds_0.Tuple2_sel1_signed;
        end if;
        result_8 <= result_8_RAM(rd_0);
      end if;
    end process;
  end block;
  --end blockRam

  with (wrM_0(34 downto 34)) select
    ds_0 <= ( Tuple2_sel0_index_1024 => clash_lowpass_fir_types.index_1024'(0 to 9 => '-')
            , Tuple2_sel1_signed => signed'(0 to 23 => '-') ) when "0",
            a1_0 when others;

  a1_0 <= clash_lowpass_fir_types.Tuple2'(clash_lowpass_fir_types.fromSLV(wrM_0(33 downto 0)));

  with (wrM_0(34 downto 34)) select
    \c$ds1_app_arg_1\ <= false when "0",
                         true when others;

  with (outPipe(875 downto 875)) select
    wrM_0 <= std_logic_vector'("0" & "----------------------------------") when "0",
             std_logic_vector'("1" & ((std_logic_vector(f_1.Frame_sel9_fAddr)
              & std_logic_vector(f_1.Frame_sel14_fFbL)))) when others;

  f_1 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(outPipe(874 downto 0)));

  -- register begin
  outPipe_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      outPipe <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      outPipe <= result_9;
    end if;
  end process;
  -- register end

  with (ds1_0(875 downto 875)) select
    result_9 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                std_logic_vector'("1" & ((std_logic_vector(result_12.Frame_sel0_fL)
                 & std_logic_vector(result_12.Frame_sel1_fR)
                 & clash_lowpass_fir_types.toSLV(result_12.Frame_sel2_fLast)
                 & result_12.Frame_sel3_fGate
                 & result_12.Frame_sel4_fOd
                 & result_12.Frame_sel5_fDist
                 & result_12.Frame_sel6_fEq
                 & result_12.Frame_sel7_fRat
                 & result_12.Frame_sel8_fReverb
                 & std_logic_vector(result_12.Frame_sel9_fAddr)
                 & std_logic_vector(result_12.Frame_sel10_fDryL)
                 & std_logic_vector(result_12.Frame_sel11_fDryR)
                 & std_logic_vector(result_12.Frame_sel12_fWetL)
                 & std_logic_vector(result_12.Frame_sel13_fWetR)
                 & std_logic_vector(result_12.Frame_sel14_fFbL)
                 & std_logic_vector(result_12.Frame_sel15_fFbR)
                 & std_logic_vector(result_12.Frame_sel16_fEqLowL)
                 & std_logic_vector(result_12.Frame_sel17_fEqLowR)
                 & std_logic_vector(result_12.Frame_sel18_fEqMidL)
                 & std_logic_vector(result_12.Frame_sel19_fEqMidR)
                 & std_logic_vector(result_12.Frame_sel20_fEqHighL)
                 & std_logic_vector(result_12.Frame_sel21_fEqHighR)
                 & std_logic_vector(result_12.Frame_sel22_fEqHighLpL)
                 & std_logic_vector(result_12.Frame_sel23_fEqHighLpR)
                 & std_logic_vector(result_12.Frame_sel24_fAccL)
                 & std_logic_vector(result_12.Frame_sel25_fAccR)
                 & std_logic_vector(result_12.Frame_sel26_fAcc2L)
                 & std_logic_vector(result_12.Frame_sel27_fAcc2R)
                 & std_logic_vector(result_12.Frame_sel28_fAcc3L)
                 & std_logic_vector(result_12.Frame_sel29_fAcc3R)))) when others;

  \c$shI_1\ <= (to_signed(8,64));

  capp_arg_8_shiftR : block
    signal sh_1 : natural;
  begin
    sh_1 <=
        -- pragma translate_off
        natural'high when (\c$shI_1\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_1\);
    \c$app_arg_8\ <= shift_right((x_2.Frame_sel24_fAccL + x_2.Frame_sel26_fAcc2L),sh_1)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_1\ <= \c$app_arg_8\ < to_signed(-8388608,48);

  \c$case_alt_3\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_1\ else
                    resize(\c$app_arg_8\,24);

  result_selection_res_4 <= \c$app_arg_8\ > to_signed(8388607,48);

  result_10 <= to_signed(8388607,24) when result_selection_res_4 else
               \c$case_alt_3\;

  \c$app_arg_9\ <= result_10 when \on_0\ else
                   x_2.Frame_sel10_fDryL;

  \c$shI_2\ <= (to_signed(8,64));

  capp_arg_10_shiftR : block
    signal sh_2 : natural;
  begin
    sh_2 <=
        -- pragma translate_off
        natural'high when (\c$shI_2\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_2\);
    \c$app_arg_10\ <= shift_right((x_2.Frame_sel25_fAccR + x_2.Frame_sel27_fAcc2R),sh_2)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_2\ <= \c$app_arg_10\ < to_signed(-8388608,48);

  \c$case_alt_4\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_2\ else
                    resize(\c$app_arg_10\,24);

  result_selection_res_5 <= \c$app_arg_10\ > to_signed(8388607,48);

  result_11 <= to_signed(8388607,24) when result_selection_res_5 else
               \c$case_alt_4\;

  \c$app_arg_11\ <= result_11 when \on_0\ else
                    x_2.Frame_sel11_fDryR;

  result_12 <= ( Frame_sel0_fL => \c$app_arg_9\
               , Frame_sel1_fR => \c$app_arg_11\
               , Frame_sel2_fLast => x_2.Frame_sel2_fLast
               , Frame_sel3_fGate => x_2.Frame_sel3_fGate
               , Frame_sel4_fOd => x_2.Frame_sel4_fOd
               , Frame_sel5_fDist => x_2.Frame_sel5_fDist
               , Frame_sel6_fEq => x_2.Frame_sel6_fEq
               , Frame_sel7_fRat => x_2.Frame_sel7_fRat
               , Frame_sel8_fReverb => x_2.Frame_sel8_fReverb
               , Frame_sel9_fAddr => x_2.Frame_sel9_fAddr
               , Frame_sel10_fDryL => x_2.Frame_sel10_fDryL
               , Frame_sel11_fDryR => x_2.Frame_sel11_fDryR
               , Frame_sel12_fWetL => x_2.Frame_sel12_fWetL
               , Frame_sel13_fWetR => x_2.Frame_sel13_fWetR
               , Frame_sel14_fFbL => x_2.Frame_sel14_fFbL
               , Frame_sel15_fFbR => x_2.Frame_sel15_fFbR
               , Frame_sel16_fEqLowL => x_2.Frame_sel16_fEqLowL
               , Frame_sel17_fEqLowR => x_2.Frame_sel17_fEqLowR
               , Frame_sel18_fEqMidL => x_2.Frame_sel18_fEqMidL
               , Frame_sel19_fEqMidR => x_2.Frame_sel19_fEqMidR
               , Frame_sel20_fEqHighL => x_2.Frame_sel20_fEqHighL
               , Frame_sel21_fEqHighR => x_2.Frame_sel21_fEqHighR
               , Frame_sel22_fEqHighLpL => x_2.Frame_sel22_fEqHighLpL
               , Frame_sel23_fEqHighLpR => x_2.Frame_sel23_fEqHighLpR
               , Frame_sel24_fAccL => x_2.Frame_sel24_fAccL
               , Frame_sel25_fAccR => x_2.Frame_sel25_fAccR
               , Frame_sel26_fAcc2L => x_2.Frame_sel26_fAcc2L
               , Frame_sel27_fAcc2R => x_2.Frame_sel27_fAcc2R
               , Frame_sel28_fAcc3L => x_2.Frame_sel28_fAcc3L
               , Frame_sel29_fAcc3R => x_2.Frame_sel29_fAcc3R );

  \c$bv_2\ <= (x_2.Frame_sel3_fGate);

  \on_0\ <= (\c$bv_2\(5 downto 5)) = std_logic_vector'("1");

  x_2 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_0(874 downto 0)));

  -- register begin
  ds1_0_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_0 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_0 <= result_13;
    end if;
  end process;
  -- register end

  with (ds1_1(875 downto 875)) select
    result_13 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(result_14.Frame_sel0_fL)
                  & std_logic_vector(result_14.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(result_14.Frame_sel2_fLast)
                  & result_14.Frame_sel3_fGate
                  & result_14.Frame_sel4_fOd
                  & result_14.Frame_sel5_fDist
                  & result_14.Frame_sel6_fEq
                  & result_14.Frame_sel7_fRat
                  & result_14.Frame_sel8_fReverb
                  & std_logic_vector(result_14.Frame_sel9_fAddr)
                  & std_logic_vector(result_14.Frame_sel10_fDryL)
                  & std_logic_vector(result_14.Frame_sel11_fDryR)
                  & std_logic_vector(result_14.Frame_sel12_fWetL)
                  & std_logic_vector(result_14.Frame_sel13_fWetR)
                  & std_logic_vector(result_14.Frame_sel14_fFbL)
                  & std_logic_vector(result_14.Frame_sel15_fFbR)
                  & std_logic_vector(result_14.Frame_sel16_fEqLowL)
                  & std_logic_vector(result_14.Frame_sel17_fEqLowR)
                  & std_logic_vector(result_14.Frame_sel18_fEqMidL)
                  & std_logic_vector(result_14.Frame_sel19_fEqMidR)
                  & std_logic_vector(result_14.Frame_sel20_fEqHighL)
                  & std_logic_vector(result_14.Frame_sel21_fEqHighR)
                  & std_logic_vector(result_14.Frame_sel22_fEqHighLpL)
                  & std_logic_vector(result_14.Frame_sel23_fEqHighLpR)
                  & std_logic_vector(result_14.Frame_sel24_fAccL)
                  & std_logic_vector(result_14.Frame_sel25_fAccR)
                  & std_logic_vector(result_14.Frame_sel26_fAcc2L)
                  & std_logic_vector(result_14.Frame_sel27_fAcc2R)
                  & std_logic_vector(result_14.Frame_sel28_fAcc3L)
                  & std_logic_vector(result_14.Frame_sel29_fAcc3R)))) when others;

  result_14 <= ( Frame_sel0_fL => x_3.Frame_sel0_fL
               , Frame_sel1_fR => x_3.Frame_sel1_fR
               , Frame_sel2_fLast => x_3.Frame_sel2_fLast
               , Frame_sel3_fGate => x_3.Frame_sel3_fGate
               , Frame_sel4_fOd => x_3.Frame_sel4_fOd
               , Frame_sel5_fDist => x_3.Frame_sel5_fDist
               , Frame_sel6_fEq => x_3.Frame_sel6_fEq
               , Frame_sel7_fRat => x_3.Frame_sel7_fRat
               , Frame_sel8_fReverb => x_3.Frame_sel8_fReverb
               , Frame_sel9_fAddr => x_3.Frame_sel9_fAddr
               , Frame_sel10_fDryL => x_3.Frame_sel10_fDryL
               , Frame_sel11_fDryR => x_3.Frame_sel11_fDryR
               , Frame_sel12_fWetL => x_3.Frame_sel12_fWetL
               , Frame_sel13_fWetR => x_3.Frame_sel13_fWetR
               , Frame_sel14_fFbL => x_3.Frame_sel14_fFbL
               , Frame_sel15_fFbR => x_3.Frame_sel15_fFbR
               , Frame_sel16_fEqLowL => x_3.Frame_sel16_fEqLowL
               , Frame_sel17_fEqLowR => x_3.Frame_sel17_fEqLowR
               , Frame_sel18_fEqMidL => x_3.Frame_sel18_fEqMidL
               , Frame_sel19_fEqMidR => x_3.Frame_sel19_fEqMidR
               , Frame_sel20_fEqHighL => x_3.Frame_sel20_fEqHighL
               , Frame_sel21_fEqHighR => x_3.Frame_sel21_fEqHighR
               , Frame_sel22_fEqHighLpL => x_3.Frame_sel22_fEqHighLpL
               , Frame_sel23_fEqHighLpR => x_3.Frame_sel23_fEqHighLpR
               , Frame_sel24_fAccL => \c$app_arg_16\
               , Frame_sel25_fAccR => \c$app_arg_15\
               , Frame_sel26_fAcc2L => \c$app_arg_13\
               , Frame_sel27_fAcc2R => \c$app_arg_12\
               , Frame_sel28_fAcc3L => x_3.Frame_sel28_fAcc3L
               , Frame_sel29_fAcc3R => x_3.Frame_sel29_fAcc3R );

  \c$app_arg_12\ <= resize((resize(x_3.Frame_sel13_fWetR,48)) * \c$app_arg_14\, 48) when \on_1\ else
                    to_signed(0,48);

  \c$app_arg_13\ <= resize((resize(x_3.Frame_sel12_fWetL,48)) * \c$app_arg_14\, 48) when \on_1\ else
                    to_signed(0,48);

  \c$app_arg_14\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(mixGain)))))))),48);

  \c$app_arg_15\ <= resize((resize(x_3.Frame_sel11_fDryR,48)) * \c$app_arg_17\, 48) when \on_1\ else
                    to_signed(0,48);

  \c$app_arg_16\ <= resize((resize(x_3.Frame_sel10_fDryL,48)) * \c$app_arg_17\, 48) when \on_1\ else
                    to_signed(0,48);

  \c$bv_3\ <= (x_3.Frame_sel3_fGate);

  \on_1\ <= (\c$bv_3\(5 downto 5)) = std_logic_vector'("1");

  \c$app_arg_17\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(invMixGain)))))))),48);

  invMixGain <= to_unsigned(256,9) - (resize(mixGain,9));

  \c$bv_4\ <= (x_3.Frame_sel8_fReverb);

  mixGain <= unsigned((\c$bv_4\(23 downto 16)));

  x_3 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_1(874 downto 0)));

  -- register begin
  ds1_1_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_1 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_1 <= result_15;
    end if;
  end process;
  -- register end

  with (ds1_2(875 downto 875)) select
    result_15 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(result_18.Frame_sel0_fL)
                  & std_logic_vector(result_18.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(result_18.Frame_sel2_fLast)
                  & result_18.Frame_sel3_fGate
                  & result_18.Frame_sel4_fOd
                  & result_18.Frame_sel5_fDist
                  & result_18.Frame_sel6_fEq
                  & result_18.Frame_sel7_fRat
                  & result_18.Frame_sel8_fReverb
                  & std_logic_vector(result_18.Frame_sel9_fAddr)
                  & std_logic_vector(result_18.Frame_sel10_fDryL)
                  & std_logic_vector(result_18.Frame_sel11_fDryR)
                  & std_logic_vector(result_18.Frame_sel12_fWetL)
                  & std_logic_vector(result_18.Frame_sel13_fWetR)
                  & std_logic_vector(result_18.Frame_sel14_fFbL)
                  & std_logic_vector(result_18.Frame_sel15_fFbR)
                  & std_logic_vector(result_18.Frame_sel16_fEqLowL)
                  & std_logic_vector(result_18.Frame_sel17_fEqLowR)
                  & std_logic_vector(result_18.Frame_sel18_fEqMidL)
                  & std_logic_vector(result_18.Frame_sel19_fEqMidR)
                  & std_logic_vector(result_18.Frame_sel20_fEqHighL)
                  & std_logic_vector(result_18.Frame_sel21_fEqHighR)
                  & std_logic_vector(result_18.Frame_sel22_fEqHighLpL)
                  & std_logic_vector(result_18.Frame_sel23_fEqHighLpR)
                  & std_logic_vector(result_18.Frame_sel24_fAccL)
                  & std_logic_vector(result_18.Frame_sel25_fAccR)
                  & std_logic_vector(result_18.Frame_sel26_fAcc2L)
                  & std_logic_vector(result_18.Frame_sel27_fAcc2R)
                  & std_logic_vector(result_18.Frame_sel28_fAcc3L)
                  & std_logic_vector(result_18.Frame_sel29_fAcc3R)))) when others;

  \c$shI_3\ <= (to_signed(1,64));

  capp_arg_18_shiftR : block
    signal sh_3 : natural;
  begin
    sh_3 <=
        -- pragma translate_off
        natural'high when (\c$shI_3\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_3\);
    \c$app_arg_18\ <= shift_right((resize(x_6.Frame_sel10_fDryL,48)),sh_3)
        -- pragma translate_off
        when ((to_signed(1,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$shI_4\ <= (to_signed(8,64));

  capp_arg_19_shiftR : block
    signal sh_4 : natural;
  begin
    sh_4 <=
        -- pragma translate_off
        natural'high when (\c$shI_4\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_4\);
    \c$app_arg_19\ <= shift_right(x_6.Frame_sel28_fAcc3L,sh_4)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  x_4 <= \c$app_arg_18\ + \c$app_arg_19\;

  \c$case_alt_selection_res_3\ <= x_4 < to_signed(-8388608,48);

  \c$case_alt_5\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_3\ else
                    resize(x_4,24);

  result_selection_res_6 <= x_4 > to_signed(8388607,48);

  result_16 <= to_signed(8388607,24) when result_selection_res_6 else
               \c$case_alt_5\;

  \c$app_arg_20\ <= result_16 when \on_2\ else
                    to_signed(0,24);

  \c$shI_5\ <= (to_signed(1,64));

  capp_arg_21_shiftR : block
    signal sh_5 : natural;
  begin
    sh_5 <=
        -- pragma translate_off
        natural'high when (\c$shI_5\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_5\);
    \c$app_arg_21\ <= shift_right((resize(x_6.Frame_sel11_fDryR,48)),sh_5)
        -- pragma translate_off
        when ((to_signed(1,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$shI_6\ <= (to_signed(8,64));

  capp_arg_22_shiftR : block
    signal sh_6 : natural;
  begin
    sh_6 <=
        -- pragma translate_off
        natural'high when (\c$shI_6\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_6\);
    \c$app_arg_22\ <= shift_right(x_6.Frame_sel29_fAcc3R,sh_6)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  x_5 <= \c$app_arg_21\ + \c$app_arg_22\;

  \c$case_alt_selection_res_4\ <= x_5 < to_signed(-8388608,48);

  \c$case_alt_6\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_4\ else
                    resize(x_5,24);

  result_selection_res_7 <= x_5 > to_signed(8388607,48);

  result_17 <= to_signed(8388607,24) when result_selection_res_7 else
               \c$case_alt_6\;

  \c$app_arg_23\ <= result_17 when \on_2\ else
                    to_signed(0,24);

  result_18 <= ( Frame_sel0_fL => x_6.Frame_sel0_fL
               , Frame_sel1_fR => x_6.Frame_sel1_fR
               , Frame_sel2_fLast => x_6.Frame_sel2_fLast
               , Frame_sel3_fGate => x_6.Frame_sel3_fGate
               , Frame_sel4_fOd => x_6.Frame_sel4_fOd
               , Frame_sel5_fDist => x_6.Frame_sel5_fDist
               , Frame_sel6_fEq => x_6.Frame_sel6_fEq
               , Frame_sel7_fRat => x_6.Frame_sel7_fRat
               , Frame_sel8_fReverb => x_6.Frame_sel8_fReverb
               , Frame_sel9_fAddr => x_6.Frame_sel9_fAddr
               , Frame_sel10_fDryL => x_6.Frame_sel10_fDryL
               , Frame_sel11_fDryR => x_6.Frame_sel11_fDryR
               , Frame_sel12_fWetL => x_6.Frame_sel12_fWetL
               , Frame_sel13_fWetR => x_6.Frame_sel13_fWetR
               , Frame_sel14_fFbL => \c$app_arg_20\
               , Frame_sel15_fFbR => \c$app_arg_23\
               , Frame_sel16_fEqLowL => x_6.Frame_sel16_fEqLowL
               , Frame_sel17_fEqLowR => x_6.Frame_sel17_fEqLowR
               , Frame_sel18_fEqMidL => x_6.Frame_sel18_fEqMidL
               , Frame_sel19_fEqMidR => x_6.Frame_sel19_fEqMidR
               , Frame_sel20_fEqHighL => x_6.Frame_sel20_fEqHighL
               , Frame_sel21_fEqHighR => x_6.Frame_sel21_fEqHighR
               , Frame_sel22_fEqHighLpL => x_6.Frame_sel22_fEqHighLpL
               , Frame_sel23_fEqHighLpR => x_6.Frame_sel23_fEqHighLpR
               , Frame_sel24_fAccL => x_6.Frame_sel24_fAccL
               , Frame_sel25_fAccR => x_6.Frame_sel25_fAccR
               , Frame_sel26_fAcc2L => x_6.Frame_sel26_fAcc2L
               , Frame_sel27_fAcc2R => x_6.Frame_sel27_fAcc2R
               , Frame_sel28_fAcc3L => x_6.Frame_sel28_fAcc3L
               , Frame_sel29_fAcc3R => x_6.Frame_sel29_fAcc3R );

  \c$bv_5\ <= (x_6.Frame_sel3_fGate);

  \on_2\ <= (\c$bv_5\(5 downto 5)) = std_logic_vector'("1");

  x_6 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_2(874 downto 0)));

  -- register begin
  ds1_2_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_2 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_2 <= \c$ds1_app_arg_2\;
    end if;
  end process;
  -- register end

  with (reverbToneBlendPipe(875 downto 875)) select
    \c$ds1_app_arg_2\ <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                         std_logic_vector'("1" & ((std_logic_vector(result_1.Frame_sel0_fL)
                          & std_logic_vector(result_1.Frame_sel1_fR)
                          & clash_lowpass_fir_types.toSLV(result_1.Frame_sel2_fLast)
                          & result_1.Frame_sel3_fGate
                          & result_1.Frame_sel4_fOd
                          & result_1.Frame_sel5_fDist
                          & result_1.Frame_sel6_fEq
                          & result_1.Frame_sel7_fRat
                          & result_1.Frame_sel8_fReverb
                          & std_logic_vector(result_1.Frame_sel9_fAddr)
                          & std_logic_vector(result_1.Frame_sel10_fDryL)
                          & std_logic_vector(result_1.Frame_sel11_fDryR)
                          & std_logic_vector(result_1.Frame_sel12_fWetL)
                          & std_logic_vector(result_1.Frame_sel13_fWetR)
                          & std_logic_vector(result_1.Frame_sel14_fFbL)
                          & std_logic_vector(result_1.Frame_sel15_fFbR)
                          & std_logic_vector(result_1.Frame_sel16_fEqLowL)
                          & std_logic_vector(result_1.Frame_sel17_fEqLowR)
                          & std_logic_vector(result_1.Frame_sel18_fEqMidL)
                          & std_logic_vector(result_1.Frame_sel19_fEqMidR)
                          & std_logic_vector(result_1.Frame_sel20_fEqHighL)
                          & std_logic_vector(result_1.Frame_sel21_fEqHighR)
                          & std_logic_vector(result_1.Frame_sel22_fEqHighLpL)
                          & std_logic_vector(result_1.Frame_sel23_fEqHighLpR)
                          & std_logic_vector(result_1.Frame_sel24_fAccL)
                          & std_logic_vector(result_1.Frame_sel25_fAccR)
                          & std_logic_vector(result_1.Frame_sel26_fAcc2L)
                          & std_logic_vector(result_1.Frame_sel27_fAcc2R)
                          & std_logic_vector(result_1.Frame_sel28_fAcc3L)
                          & std_logic_vector(result_1.Frame_sel29_fAcc3R)))) when others;

  \c$ds1_app_arg_3\ <= signed(std_logic_vector(resize(reverbAddr,64)));

  -- register begin
  reverbAddr_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      reverbAddr <= to_unsigned(0,10);
    elsif rising_edge(clk) then
      reverbAddr <= \c$reverbAddr_app_arg\;
    end if;
  end process;
  -- register end

  with (eqMixPipe(875 downto 875)) select
    \c$reverbAddr_app_arg\ <= reverbAddr when "0",
                              \c$reverbAddr_case_alt\ when others;

  -- register begin
  eqMixPipe_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      eqMixPipe <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      eqMixPipe <= result_19;
    end if;
  end process;
  -- register end

  with (ds1_3(875 downto 875)) select
    result_19 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(result_20.Frame_sel0_fL)
                  & std_logic_vector(result_20.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(result_20.Frame_sel2_fLast)
                  & result_20.Frame_sel3_fGate
                  & result_20.Frame_sel4_fOd
                  & result_20.Frame_sel5_fDist
                  & result_20.Frame_sel6_fEq
                  & result_20.Frame_sel7_fRat
                  & result_20.Frame_sel8_fReverb
                  & std_logic_vector(result_20.Frame_sel9_fAddr)
                  & std_logic_vector(result_20.Frame_sel10_fDryL)
                  & std_logic_vector(result_20.Frame_sel11_fDryR)
                  & std_logic_vector(result_20.Frame_sel12_fWetL)
                  & std_logic_vector(result_20.Frame_sel13_fWetR)
                  & std_logic_vector(result_20.Frame_sel14_fFbL)
                  & std_logic_vector(result_20.Frame_sel15_fFbR)
                  & std_logic_vector(result_20.Frame_sel16_fEqLowL)
                  & std_logic_vector(result_20.Frame_sel17_fEqLowR)
                  & std_logic_vector(result_20.Frame_sel18_fEqMidL)
                  & std_logic_vector(result_20.Frame_sel19_fEqMidR)
                  & std_logic_vector(result_20.Frame_sel20_fEqHighL)
                  & std_logic_vector(result_20.Frame_sel21_fEqHighR)
                  & std_logic_vector(result_20.Frame_sel22_fEqHighLpL)
                  & std_logic_vector(result_20.Frame_sel23_fEqHighLpR)
                  & std_logic_vector(result_20.Frame_sel24_fAccL)
                  & std_logic_vector(result_20.Frame_sel25_fAccR)
                  & std_logic_vector(result_20.Frame_sel26_fAcc2L)
                  & std_logic_vector(result_20.Frame_sel27_fAcc2R)
                  & std_logic_vector(result_20.Frame_sel28_fAcc3L)
                  & std_logic_vector(result_20.Frame_sel29_fAcc3R)))) when others;

  \c$bv_6\ <= (x_7.Frame_sel3_fGate);

  \on_3\ <= (\c$bv_6\(3 downto 3)) = std_logic_vector'("1");

  result_20 <= ( Frame_sel0_fL => \c$app_arg_26\
               , Frame_sel1_fR => \c$app_arg_24\
               , Frame_sel2_fLast => x_7.Frame_sel2_fLast
               , Frame_sel3_fGate => x_7.Frame_sel3_fGate
               , Frame_sel4_fOd => x_7.Frame_sel4_fOd
               , Frame_sel5_fDist => x_7.Frame_sel5_fDist
               , Frame_sel6_fEq => x_7.Frame_sel6_fEq
               , Frame_sel7_fRat => x_7.Frame_sel7_fRat
               , Frame_sel8_fReverb => x_7.Frame_sel8_fReverb
               , Frame_sel9_fAddr => x_7.Frame_sel9_fAddr
               , Frame_sel10_fDryL => x_7.Frame_sel10_fDryL
               , Frame_sel11_fDryR => x_7.Frame_sel11_fDryR
               , Frame_sel12_fWetL => x_7.Frame_sel12_fWetL
               , Frame_sel13_fWetR => x_7.Frame_sel13_fWetR
               , Frame_sel14_fFbL => x_7.Frame_sel14_fFbL
               , Frame_sel15_fFbR => x_7.Frame_sel15_fFbR
               , Frame_sel16_fEqLowL => x_7.Frame_sel16_fEqLowL
               , Frame_sel17_fEqLowR => x_7.Frame_sel17_fEqLowR
               , Frame_sel18_fEqMidL => x_7.Frame_sel18_fEqMidL
               , Frame_sel19_fEqMidR => x_7.Frame_sel19_fEqMidR
               , Frame_sel20_fEqHighL => x_7.Frame_sel20_fEqHighL
               , Frame_sel21_fEqHighR => x_7.Frame_sel21_fEqHighR
               , Frame_sel22_fEqHighLpL => x_7.Frame_sel22_fEqHighLpL
               , Frame_sel23_fEqHighLpR => x_7.Frame_sel23_fEqHighLpR
               , Frame_sel24_fAccL => x_7.Frame_sel24_fAccL
               , Frame_sel25_fAccR => x_7.Frame_sel25_fAccR
               , Frame_sel26_fAcc2L => x_7.Frame_sel26_fAcc2L
               , Frame_sel27_fAcc2R => x_7.Frame_sel27_fAcc2R
               , Frame_sel28_fAcc3L => x_7.Frame_sel28_fAcc3L
               , Frame_sel29_fAcc3R => x_7.Frame_sel29_fAcc3R );

  \c$app_arg_24\ <= result_21 when \on_3\ else
                    x_7.Frame_sel1_fR;

  \c$case_alt_selection_res_5\ <= \c$app_arg_25\ < to_signed(-8388608,48);

  \c$case_alt_7\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_5\ else
                    resize(\c$app_arg_25\,24);

  result_selection_res_8 <= \c$app_arg_25\ > to_signed(8388607,48);

  result_21 <= to_signed(8388607,24) when result_selection_res_8 else
               \c$case_alt_7\;

  \c$shI_7\ <= (to_signed(7,64));

  capp_arg_25_shiftR : block
    signal sh_7 : natural;
  begin
    sh_7 <=
        -- pragma translate_off
        natural'high when (\c$shI_7\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_7\);
    \c$app_arg_25\ <= shift_right(((x_7.Frame_sel25_fAccR + x_7.Frame_sel27_fAcc2R) + x_7.Frame_sel29_fAcc3R),sh_7)
        -- pragma translate_off
        when ((to_signed(7,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_26\ <= result_22 when \on_3\ else
                    x_7.Frame_sel0_fL;

  \c$case_alt_selection_res_6\ <= \c$app_arg_27\ < to_signed(-8388608,48);

  \c$case_alt_8\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_6\ else
                    resize(\c$app_arg_27\,24);

  result_selection_res_9 <= \c$app_arg_27\ > to_signed(8388607,48);

  result_22 <= to_signed(8388607,24) when result_selection_res_9 else
               \c$case_alt_8\;

  \c$shI_8\ <= (to_signed(7,64));

  capp_arg_27_shiftR : block
    signal sh_8 : natural;
  begin
    sh_8 <=
        -- pragma translate_off
        natural'high when (\c$shI_8\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_8\);
    \c$app_arg_27\ <= shift_right(((x_7.Frame_sel24_fAccL + x_7.Frame_sel26_fAcc2L) + x_7.Frame_sel28_fAcc3L),sh_8)
        -- pragma translate_off
        when ((to_signed(7,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  x_7 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_3(874 downto 0)));

  -- register begin
  ds1_3_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_3 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_3 <= result_23;
    end if;
  end process;
  -- register end

  with (ds1_4(875 downto 875)) select
    result_23 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(result_24.Frame_sel0_fL)
                  & std_logic_vector(result_24.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(result_24.Frame_sel2_fLast)
                  & result_24.Frame_sel3_fGate
                  & result_24.Frame_sel4_fOd
                  & result_24.Frame_sel5_fDist
                  & result_24.Frame_sel6_fEq
                  & result_24.Frame_sel7_fRat
                  & result_24.Frame_sel8_fReverb
                  & std_logic_vector(result_24.Frame_sel9_fAddr)
                  & std_logic_vector(result_24.Frame_sel10_fDryL)
                  & std_logic_vector(result_24.Frame_sel11_fDryR)
                  & std_logic_vector(result_24.Frame_sel12_fWetL)
                  & std_logic_vector(result_24.Frame_sel13_fWetR)
                  & std_logic_vector(result_24.Frame_sel14_fFbL)
                  & std_logic_vector(result_24.Frame_sel15_fFbR)
                  & std_logic_vector(result_24.Frame_sel16_fEqLowL)
                  & std_logic_vector(result_24.Frame_sel17_fEqLowR)
                  & std_logic_vector(result_24.Frame_sel18_fEqMidL)
                  & std_logic_vector(result_24.Frame_sel19_fEqMidR)
                  & std_logic_vector(result_24.Frame_sel20_fEqHighL)
                  & std_logic_vector(result_24.Frame_sel21_fEqHighR)
                  & std_logic_vector(result_24.Frame_sel22_fEqHighLpL)
                  & std_logic_vector(result_24.Frame_sel23_fEqHighLpR)
                  & std_logic_vector(result_24.Frame_sel24_fAccL)
                  & std_logic_vector(result_24.Frame_sel25_fAccR)
                  & std_logic_vector(result_24.Frame_sel26_fAcc2L)
                  & std_logic_vector(result_24.Frame_sel27_fAcc2R)
                  & std_logic_vector(result_24.Frame_sel28_fAcc3L)
                  & std_logic_vector(result_24.Frame_sel29_fAcc3R)))) when others;

  result_24 <= ( Frame_sel0_fL => x_8.Frame_sel0_fL
               , Frame_sel1_fR => x_8.Frame_sel1_fR
               , Frame_sel2_fLast => x_8.Frame_sel2_fLast
               , Frame_sel3_fGate => x_8.Frame_sel3_fGate
               , Frame_sel4_fOd => x_8.Frame_sel4_fOd
               , Frame_sel5_fDist => x_8.Frame_sel5_fDist
               , Frame_sel6_fEq => x_8.Frame_sel6_fEq
               , Frame_sel7_fRat => x_8.Frame_sel7_fRat
               , Frame_sel8_fReverb => x_8.Frame_sel8_fReverb
               , Frame_sel9_fAddr => x_8.Frame_sel9_fAddr
               , Frame_sel10_fDryL => x_8.Frame_sel10_fDryL
               , Frame_sel11_fDryR => x_8.Frame_sel11_fDryR
               , Frame_sel12_fWetL => x_8.Frame_sel12_fWetL
               , Frame_sel13_fWetR => x_8.Frame_sel13_fWetR
               , Frame_sel14_fFbL => x_8.Frame_sel14_fFbL
               , Frame_sel15_fFbR => x_8.Frame_sel15_fFbR
               , Frame_sel16_fEqLowL => x_8.Frame_sel16_fEqLowL
               , Frame_sel17_fEqLowR => x_8.Frame_sel17_fEqLowR
               , Frame_sel18_fEqMidL => x_8.Frame_sel18_fEqMidL
               , Frame_sel19_fEqMidR => x_8.Frame_sel19_fEqMidR
               , Frame_sel20_fEqHighL => x_8.Frame_sel20_fEqHighL
               , Frame_sel21_fEqHighR => x_8.Frame_sel21_fEqHighR
               , Frame_sel22_fEqHighLpL => x_8.Frame_sel22_fEqHighLpL
               , Frame_sel23_fEqHighLpR => x_8.Frame_sel23_fEqHighLpR
               , Frame_sel24_fAccL => \c$app_arg_35\
               , Frame_sel25_fAccR => \c$app_arg_34\
               , Frame_sel26_fAcc2L => \c$app_arg_32\
               , Frame_sel27_fAcc2R => \c$app_arg_31\
               , Frame_sel28_fAcc3L => \c$app_arg_29\
               , Frame_sel29_fAcc3R => \c$app_arg_28\ );

  \c$app_arg_28\ <= resize((resize(x_8.Frame_sel21_fEqHighR,48)) * \c$app_arg_30\, 48) when \on_4\ else
                    to_signed(0,48);

  \c$app_arg_29\ <= resize((resize(x_8.Frame_sel20_fEqHighL,48)) * \c$app_arg_30\, 48) when \on_4\ else
                    to_signed(0,48);

  \c$app_arg_30\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(gain_2)))))))),48);

  gain_2 <= unsigned((\c$gain_app_arg\(23 downto 16)));

  \c$app_arg_31\ <= resize((resize(x_8.Frame_sel19_fEqMidR,48)) * \c$app_arg_33\, 48) when \on_4\ else
                    to_signed(0,48);

  \c$app_arg_32\ <= resize((resize(x_8.Frame_sel18_fEqMidL,48)) * \c$app_arg_33\, 48) when \on_4\ else
                    to_signed(0,48);

  \c$app_arg_33\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(gain_3)))))))),48);

  gain_3 <= unsigned((\c$gain_app_arg\(15 downto 8)));

  \c$app_arg_34\ <= resize((resize(x_8.Frame_sel17_fEqLowR,48)) * \c$app_arg_36\, 48) when \on_4\ else
                    to_signed(0,48);

  \c$app_arg_35\ <= resize((resize(x_8.Frame_sel16_fEqLowL,48)) * \c$app_arg_36\, 48) when \on_4\ else
                    to_signed(0,48);

  \c$bv_7\ <= (x_8.Frame_sel3_fGate);

  \on_4\ <= (\c$bv_7\(3 downto 3)) = std_logic_vector'("1");

  \c$app_arg_36\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(gain_4)))))))),48);

  gain_4 <= unsigned((\c$gain_app_arg\(7 downto 0)));

  \c$gain_app_arg\ <= x_8.Frame_sel6_fEq;

  x_8 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_4(874 downto 0)));

  -- register begin
  ds1_4_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_4 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_4 <= result_25;
    end if;
  end process;
  -- register end

  with (eqFilterPipe(875 downto 875)) select
    result_25 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(\c$case_alt_9\.Frame_sel0_fL)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(\c$case_alt_9\.Frame_sel2_fLast)
                  & \c$case_alt_9\.Frame_sel3_fGate
                  & \c$case_alt_9\.Frame_sel4_fOd
                  & \c$case_alt_9\.Frame_sel5_fDist
                  & \c$case_alt_9\.Frame_sel6_fEq
                  & \c$case_alt_9\.Frame_sel7_fRat
                  & \c$case_alt_9\.Frame_sel8_fReverb
                  & std_logic_vector(\c$case_alt_9\.Frame_sel9_fAddr)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel10_fDryL)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel11_fDryR)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel12_fWetL)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel13_fWetR)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel14_fFbL)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel15_fFbR)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel16_fEqLowL)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel17_fEqLowR)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel18_fEqMidL)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel19_fEqMidR)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel20_fEqHighL)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel21_fEqHighR)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel22_fEqHighLpL)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel23_fEqHighLpR)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel24_fAccL)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel25_fAccR)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel26_fAcc2L)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel27_fAcc2R)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel28_fAcc3L)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel29_fAcc3R)))) when others;

  \c$case_alt_9\ <= ( Frame_sel0_fL => x_13.Frame_sel0_fL
                    , Frame_sel1_fR => x_13.Frame_sel1_fR
                    , Frame_sel2_fLast => x_13.Frame_sel2_fLast
                    , Frame_sel3_fGate => x_13.Frame_sel3_fGate
                    , Frame_sel4_fOd => x_13.Frame_sel4_fOd
                    , Frame_sel5_fDist => x_13.Frame_sel5_fDist
                    , Frame_sel6_fEq => x_13.Frame_sel6_fEq
                    , Frame_sel7_fRat => x_13.Frame_sel7_fRat
                    , Frame_sel8_fReverb => x_13.Frame_sel8_fReverb
                    , Frame_sel9_fAddr => x_13.Frame_sel9_fAddr
                    , Frame_sel10_fDryL => x_13.Frame_sel10_fDryL
                    , Frame_sel11_fDryR => x_13.Frame_sel11_fDryR
                    , Frame_sel12_fWetL => x_13.Frame_sel12_fWetL
                    , Frame_sel13_fWetR => x_13.Frame_sel13_fWetR
                    , Frame_sel14_fFbL => x_13.Frame_sel14_fFbL
                    , Frame_sel15_fFbR => x_13.Frame_sel15_fFbR
                    , Frame_sel16_fEqLowL => x_13.Frame_sel16_fEqLowL
                    , Frame_sel17_fEqLowR => x_13.Frame_sel17_fEqLowR
                    , Frame_sel18_fEqMidL => result_29
                    , Frame_sel19_fEqMidR => result_28
                    , Frame_sel20_fEqHighL => result_27
                    , Frame_sel21_fEqHighR => result_26
                    , Frame_sel22_fEqHighLpL => x_13.Frame_sel22_fEqHighLpL
                    , Frame_sel23_fEqHighLpR => x_13.Frame_sel23_fEqHighLpR
                    , Frame_sel24_fAccL => x_13.Frame_sel24_fAccL
                    , Frame_sel25_fAccR => x_13.Frame_sel25_fAccR
                    , Frame_sel26_fAcc2L => x_13.Frame_sel26_fAcc2L
                    , Frame_sel27_fAcc2R => x_13.Frame_sel27_fAcc2R
                    , Frame_sel28_fAcc3L => x_13.Frame_sel28_fAcc3L
                    , Frame_sel29_fAcc3R => x_13.Frame_sel29_fAcc3R );

  x_9 <= (resize(x_13.Frame_sel1_fR,48)) - \c$app_arg_37\;

  \c$case_alt_selection_res_7\ <= x_9 < to_signed(-8388608,48);

  \c$case_alt_10\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_7\ else
                     resize(x_9,24);

  result_selection_res_10 <= x_9 > to_signed(8388607,48);

  result_26 <= to_signed(8388607,24) when result_selection_res_10 else
               \c$case_alt_10\;

  x_10 <= (resize(x_13.Frame_sel0_fL,48)) - \c$app_arg_38\;

  \c$case_alt_selection_res_8\ <= x_10 < to_signed(-8388608,48);

  \c$case_alt_11\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_8\ else
                     resize(x_10,24);

  result_selection_res_11 <= x_10 > to_signed(8388607,48);

  result_27 <= to_signed(8388607,24) when result_selection_res_11 else
               \c$case_alt_11\;

  x_11 <= \c$app_arg_37\ - (resize(x_13.Frame_sel17_fEqLowR,48));

  \c$case_alt_selection_res_9\ <= x_11 < to_signed(-8388608,48);

  \c$case_alt_12\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_9\ else
                     resize(x_11,24);

  result_selection_res_12 <= x_11 > to_signed(8388607,48);

  result_28 <= to_signed(8388607,24) when result_selection_res_12 else
               \c$case_alt_12\;

  \c$app_arg_37\ <= resize(x_13.Frame_sel23_fEqHighLpR,48);

  x_12 <= \c$app_arg_38\ - (resize(x_13.Frame_sel16_fEqLowL,48));

  \c$case_alt_selection_res_10\ <= x_12 < to_signed(-8388608,48);

  \c$case_alt_13\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_10\ else
                     resize(x_12,24);

  result_selection_res_13 <= x_12 > to_signed(8388607,48);

  result_29 <= to_signed(8388607,24) when result_selection_res_13 else
               \c$case_alt_13\;

  \c$app_arg_38\ <= resize(x_13.Frame_sel22_fEqHighLpL,48);

  -- register begin
  eqFilterPipe_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      eqFilterPipe <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      eqFilterPipe <= result_30;
    end if;
  end process;
  -- register end

  with (ds1_5(875 downto 875)) select
    result_30 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(\c$case_alt_14\.Frame_sel0_fL)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(\c$case_alt_14\.Frame_sel2_fLast)
                  & \c$case_alt_14\.Frame_sel3_fGate
                  & \c$case_alt_14\.Frame_sel4_fOd
                  & \c$case_alt_14\.Frame_sel5_fDist
                  & \c$case_alt_14\.Frame_sel6_fEq
                  & \c$case_alt_14\.Frame_sel7_fRat
                  & \c$case_alt_14\.Frame_sel8_fReverb
                  & std_logic_vector(\c$case_alt_14\.Frame_sel9_fAddr)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel10_fDryL)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel11_fDryR)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel12_fWetL)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel13_fWetR)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel14_fFbL)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel15_fFbR)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel16_fEqLowL)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel17_fEqLowR)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel18_fEqMidL)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel19_fEqMidR)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel20_fEqHighL)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel21_fEqHighR)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel22_fEqHighLpL)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel23_fEqHighLpR)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel24_fAccL)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel25_fAccR)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel26_fAcc2L)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel27_fAcc2R)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel28_fAcc3L)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel29_fAcc3R)))) when others;

  \c$case_alt_14\ <= ( Frame_sel0_fL => x_14.Frame_sel0_fL
                     , Frame_sel1_fR => x_14.Frame_sel1_fR
                     , Frame_sel2_fLast => x_14.Frame_sel2_fLast
                     , Frame_sel3_fGate => x_14.Frame_sel3_fGate
                     , Frame_sel4_fOd => x_14.Frame_sel4_fOd
                     , Frame_sel5_fDist => x_14.Frame_sel5_fDist
                     , Frame_sel6_fEq => x_14.Frame_sel6_fEq
                     , Frame_sel7_fRat => x_14.Frame_sel7_fRat
                     , Frame_sel8_fReverb => x_14.Frame_sel8_fReverb
                     , Frame_sel9_fAddr => x_14.Frame_sel9_fAddr
                     , Frame_sel10_fDryL => x_14.Frame_sel10_fDryL
                     , Frame_sel11_fDryR => x_14.Frame_sel11_fDryR
                     , Frame_sel12_fWetL => x_14.Frame_sel12_fWetL
                     , Frame_sel13_fWetR => x_14.Frame_sel13_fWetR
                     , Frame_sel14_fFbL => x_14.Frame_sel14_fFbL
                     , Frame_sel15_fFbR => x_14.Frame_sel15_fFbR
                     , Frame_sel16_fEqLowL => eqLowPrevL + (resize(\c$app_arg_43\,24))
                     , Frame_sel17_fEqLowR => eqLowPrevR + (resize(\c$app_arg_41\,24))
                     , Frame_sel18_fEqMidL => x_14.Frame_sel18_fEqMidL
                     , Frame_sel19_fEqMidR => x_14.Frame_sel19_fEqMidR
                     , Frame_sel20_fEqHighL => x_14.Frame_sel20_fEqHighL
                     , Frame_sel21_fEqHighR => x_14.Frame_sel21_fEqHighR
                     , Frame_sel22_fEqHighLpL => eqHighPrevL + (resize(\c$app_arg_40\,24))
                     , Frame_sel23_fEqHighLpR => eqHighPrevR + (resize(\c$app_arg_39\,24))
                     , Frame_sel24_fAccL => x_14.Frame_sel24_fAccL
                     , Frame_sel25_fAccR => x_14.Frame_sel25_fAccR
                     , Frame_sel26_fAcc2L => x_14.Frame_sel26_fAcc2L
                     , Frame_sel27_fAcc2R => x_14.Frame_sel27_fAcc2R
                     , Frame_sel28_fAcc3L => x_14.Frame_sel28_fAcc3L
                     , Frame_sel29_fAcc3R => x_14.Frame_sel29_fAcc3R );

  \c$shI_9\ <= (to_signed(2,64));

  capp_arg_39_shiftR : block
    signal sh_9 : natural;
  begin
    sh_9 <=
        -- pragma translate_off
        natural'high when (\c$shI_9\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_9\);
    \c$app_arg_39\ <= shift_right((\c$app_arg_42\ - (resize(eqHighPrevR,25))),sh_9)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$shI_10\ <= (to_signed(2,64));

  capp_arg_40_shiftR : block
    signal sh_10 : natural;
  begin
    sh_10 <=
        -- pragma translate_off
        natural'high when (\c$shI_10\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_10\);
    \c$app_arg_40\ <= shift_right((\c$app_arg_44\ - (resize(eqHighPrevL,25))),sh_10)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$shI_11\ <= (to_signed(5,64));

  capp_arg_41_shiftR : block
    signal sh_11 : natural;
  begin
    sh_11 <=
        -- pragma translate_off
        natural'high when (\c$shI_11\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_11\);
    \c$app_arg_41\ <= shift_right((\c$app_arg_42\ - (resize(eqLowPrevR,25))),sh_11)
        -- pragma translate_off
        when ((to_signed(5,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_42\ <= resize(x_14.Frame_sel1_fR,25);

  \c$shI_12\ <= (to_signed(5,64));

  capp_arg_43_shiftR : block
    signal sh_12 : natural;
  begin
    sh_12 <=
        -- pragma translate_off
        natural'high when (\c$shI_12\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_12\);
    \c$app_arg_43\ <= shift_right((\c$app_arg_44\ - (resize(eqLowPrevL,25))),sh_12)
        -- pragma translate_off
        when ((to_signed(5,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_44\ <= resize(x_14.Frame_sel0_fL,25);

  -- register begin
  eqHighPrevR_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      eqHighPrevR <= to_signed(0,24);
    elsif rising_edge(clk) then
      eqHighPrevR <= \c$eqHighPrevR_app_arg\;
    end if;
  end process;
  -- register end

  with (eqFilterPipe(875 downto 875)) select
    \c$eqHighPrevR_app_arg\ <= eqHighPrevR when "0",
                               x_13.Frame_sel23_fEqHighLpR when others;

  -- register begin
  eqHighPrevL_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      eqHighPrevL <= to_signed(0,24);
    elsif rising_edge(clk) then
      eqHighPrevL <= \c$eqHighPrevL_app_arg\;
    end if;
  end process;
  -- register end

  with (eqFilterPipe(875 downto 875)) select
    \c$eqHighPrevL_app_arg\ <= eqHighPrevL when "0",
                               x_13.Frame_sel22_fEqHighLpL when others;

  -- register begin
  eqLowPrevR_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      eqLowPrevR <= to_signed(0,24);
    elsif rising_edge(clk) then
      eqLowPrevR <= \c$eqLowPrevR_app_arg\;
    end if;
  end process;
  -- register end

  with (eqFilterPipe(875 downto 875)) select
    \c$eqLowPrevR_app_arg\ <= eqLowPrevR when "0",
                              x_13.Frame_sel17_fEqLowR when others;

  -- register begin
  eqLowPrevL_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      eqLowPrevL <= to_signed(0,24);
    elsif rising_edge(clk) then
      eqLowPrevL <= \c$eqLowPrevL_app_arg\;
    end if;
  end process;
  -- register end

  with (eqFilterPipe(875 downto 875)) select
    \c$eqLowPrevL_app_arg\ <= eqLowPrevL when "0",
                              x_13.Frame_sel16_fEqLowL when others;

  x_13 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(eqFilterPipe(874 downto 0)));

  x_14 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_5(874 downto 0)));

  -- register begin
  ds1_5_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_5 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_5 <= result_31;
    end if;
  end process;
  -- register end

  with (ds1_6(875 downto 875)) select
    result_31 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(result_32.Frame_sel0_fL)
                  & std_logic_vector(result_32.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(result_32.Frame_sel2_fLast)
                  & result_32.Frame_sel3_fGate
                  & result_32.Frame_sel4_fOd
                  & result_32.Frame_sel5_fDist
                  & result_32.Frame_sel6_fEq
                  & result_32.Frame_sel7_fRat
                  & result_32.Frame_sel8_fReverb
                  & std_logic_vector(result_32.Frame_sel9_fAddr)
                  & std_logic_vector(result_32.Frame_sel10_fDryL)
                  & std_logic_vector(result_32.Frame_sel11_fDryR)
                  & std_logic_vector(result_32.Frame_sel12_fWetL)
                  & std_logic_vector(result_32.Frame_sel13_fWetR)
                  & std_logic_vector(result_32.Frame_sel14_fFbL)
                  & std_logic_vector(result_32.Frame_sel15_fFbR)
                  & std_logic_vector(result_32.Frame_sel16_fEqLowL)
                  & std_logic_vector(result_32.Frame_sel17_fEqLowR)
                  & std_logic_vector(result_32.Frame_sel18_fEqMidL)
                  & std_logic_vector(result_32.Frame_sel19_fEqMidR)
                  & std_logic_vector(result_32.Frame_sel20_fEqHighL)
                  & std_logic_vector(result_32.Frame_sel21_fEqHighR)
                  & std_logic_vector(result_32.Frame_sel22_fEqHighLpL)
                  & std_logic_vector(result_32.Frame_sel23_fEqHighLpR)
                  & std_logic_vector(result_32.Frame_sel24_fAccL)
                  & std_logic_vector(result_32.Frame_sel25_fAccR)
                  & std_logic_vector(result_32.Frame_sel26_fAcc2L)
                  & std_logic_vector(result_32.Frame_sel27_fAcc2R)
                  & std_logic_vector(result_32.Frame_sel28_fAcc3L)
                  & std_logic_vector(result_32.Frame_sel29_fAcc3R)))) when others;

  result_32 <= ( Frame_sel0_fL => \c$app_arg_50\
               , Frame_sel1_fR => \c$app_arg_45\
               , Frame_sel2_fLast => x_15.Frame_sel2_fLast
               , Frame_sel3_fGate => x_15.Frame_sel3_fGate
               , Frame_sel4_fOd => x_15.Frame_sel4_fOd
               , Frame_sel5_fDist => x_15.Frame_sel5_fDist
               , Frame_sel6_fEq => x_15.Frame_sel6_fEq
               , Frame_sel7_fRat => x_15.Frame_sel7_fRat
               , Frame_sel8_fReverb => x_15.Frame_sel8_fReverb
               , Frame_sel9_fAddr => x_15.Frame_sel9_fAddr
               , Frame_sel10_fDryL => x_15.Frame_sel10_fDryL
               , Frame_sel11_fDryR => x_15.Frame_sel11_fDryR
               , Frame_sel12_fWetL => x_15.Frame_sel12_fWetL
               , Frame_sel13_fWetR => x_15.Frame_sel13_fWetR
               , Frame_sel14_fFbL => x_15.Frame_sel14_fFbL
               , Frame_sel15_fFbR => x_15.Frame_sel15_fFbR
               , Frame_sel16_fEqLowL => x_15.Frame_sel16_fEqLowL
               , Frame_sel17_fEqLowR => x_15.Frame_sel17_fEqLowR
               , Frame_sel18_fEqMidL => x_15.Frame_sel18_fEqMidL
               , Frame_sel19_fEqMidR => x_15.Frame_sel19_fEqMidR
               , Frame_sel20_fEqHighL => x_15.Frame_sel20_fEqHighL
               , Frame_sel21_fEqHighR => x_15.Frame_sel21_fEqHighR
               , Frame_sel22_fEqHighLpL => x_15.Frame_sel22_fEqHighLpL
               , Frame_sel23_fEqHighLpR => x_15.Frame_sel23_fEqHighLpR
               , Frame_sel24_fAccL => x_15.Frame_sel24_fAccL
               , Frame_sel25_fAccR => x_15.Frame_sel25_fAccR
               , Frame_sel26_fAcc2L => x_15.Frame_sel26_fAcc2L
               , Frame_sel27_fAcc2R => x_15.Frame_sel27_fAcc2R
               , Frame_sel28_fAcc3L => x_15.Frame_sel28_fAcc3L
               , Frame_sel29_fAcc3R => x_15.Frame_sel29_fAcc3R );

  \c$app_arg_45\ <= result_33 when \on_5\ else
                    x_15.Frame_sel1_fR;

  result_selection_res_14 <= result_34 > to_signed(4194304,24);

  result_33 <= resize((to_signed(4194304,25) + \c$app_arg_46\),24) when result_selection_res_14 else
               \c$case_alt_15\;

  \c$case_alt_selection_res_11\ <= result_34 < to_signed(-4194304,24);

  \c$case_alt_15\ <= resize((to_signed(-4194304,25) + \c$app_arg_47\),24) when \c$case_alt_selection_res_11\ else
                     result_34;

  \c$shI_13\ <= (to_signed(2,64));

  capp_arg_46_shiftR : block
    signal sh_13 : natural;
  begin
    sh_13 <=
        -- pragma translate_off
        natural'high when (\c$shI_13\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_13\);
    \c$app_arg_46\ <= shift_right((\c$app_arg_48\ - to_signed(4194304,25)),sh_13)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$shI_14\ <= (to_signed(2,64));

  capp_arg_47_shiftR : block
    signal sh_14 : natural;
  begin
    sh_14 <=
        -- pragma translate_off
        natural'high when (\c$shI_14\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_14\);
    \c$app_arg_47\ <= shift_right((\c$app_arg_48\ + to_signed(4194304,25)),sh_14)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_48\ <= resize(result_34,25);

  \c$case_alt_selection_res_12\ <= \c$app_arg_49\ < to_signed(-8388608,48);

  \c$case_alt_16\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_12\ else
                     resize(\c$app_arg_49\,24);

  result_selection_res_15 <= \c$app_arg_49\ > to_signed(8388607,48);

  result_34 <= to_signed(8388607,24) when result_selection_res_15 else
               \c$case_alt_16\;

  \c$shI_15\ <= (to_signed(8,64));

  capp_arg_49_shiftR : block
    signal sh_15 : natural;
  begin
    sh_15 <=
        -- pragma translate_off
        natural'high when (\c$shI_15\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_15\);
    \c$app_arg_49\ <= shift_right(((resize((resize(x_15.Frame_sel11_fDryR,48)) * \c$app_arg_56\, 48)) + (resize((resize(x_15.Frame_sel13_fWetR,48)) * \c$app_arg_55\, 48))),sh_15)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_50\ <= result_35 when \on_5\ else
                    x_15.Frame_sel0_fL;

  \c$bv_8\ <= (x_15.Frame_sel3_fGate);

  \on_5\ <= (\c$bv_8\(4 downto 4)) = std_logic_vector'("1");

  result_selection_res_16 <= result_36 > to_signed(4194304,24);

  result_35 <= resize((to_signed(4194304,25) + \c$app_arg_51\),24) when result_selection_res_16 else
               \c$case_alt_17\;

  \c$case_alt_selection_res_13\ <= result_36 < to_signed(-4194304,24);

  \c$case_alt_17\ <= resize((to_signed(-4194304,25) + \c$app_arg_52\),24) when \c$case_alt_selection_res_13\ else
                     result_36;

  \c$shI_16\ <= (to_signed(2,64));

  capp_arg_51_shiftR : block
    signal sh_16 : natural;
  begin
    sh_16 <=
        -- pragma translate_off
        natural'high when (\c$shI_16\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_16\);
    \c$app_arg_51\ <= shift_right((\c$app_arg_53\ - to_signed(4194304,25)),sh_16)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$shI_17\ <= (to_signed(2,64));

  capp_arg_52_shiftR : block
    signal sh_17 : natural;
  begin
    sh_17 <=
        -- pragma translate_off
        natural'high when (\c$shI_17\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_17\);
    \c$app_arg_52\ <= shift_right((\c$app_arg_53\ + to_signed(4194304,25)),sh_17)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_53\ <= resize(result_36,25);

  \c$case_alt_selection_res_14\ <= \c$app_arg_54\ < to_signed(-8388608,48);

  \c$case_alt_18\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_14\ else
                     resize(\c$app_arg_54\,24);

  result_selection_res_17 <= \c$app_arg_54\ > to_signed(8388607,48);

  result_36 <= to_signed(8388607,24) when result_selection_res_17 else
               \c$case_alt_18\;

  \c$shI_18\ <= (to_signed(8,64));

  capp_arg_54_shiftR : block
    signal sh_18 : natural;
  begin
    sh_18 <=
        -- pragma translate_off
        natural'high when (\c$shI_18\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_18\);
    \c$app_arg_54\ <= shift_right(((resize((resize(x_15.Frame_sel10_fDryL,48)) * \c$app_arg_56\, 48)) + (resize((resize(x_15.Frame_sel12_fWetL,48)) * \c$app_arg_55\, 48))),sh_18)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_55\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(mix)))))))),48);

  \c$app_arg_56\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(invMix)))))))),48);

  invMix <= to_unsigned(255,8) - mix;

  \c$bv_9\ <= (x_15.Frame_sel7_fRat);

  mix <= unsigned((\c$bv_9\(31 downto 24)));

  x_15 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_6(874 downto 0)));

  -- register begin
  ds1_6_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_6 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_6 <= result_37;
    end if;
  end process;
  -- register end

  with (ratTonePipe(875 downto 875)) select
    result_37 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(result_38.Frame_sel0_fL)
                  & std_logic_vector(result_38.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(result_38.Frame_sel2_fLast)
                  & result_38.Frame_sel3_fGate
                  & result_38.Frame_sel4_fOd
                  & result_38.Frame_sel5_fDist
                  & result_38.Frame_sel6_fEq
                  & result_38.Frame_sel7_fRat
                  & result_38.Frame_sel8_fReverb
                  & std_logic_vector(result_38.Frame_sel9_fAddr)
                  & std_logic_vector(result_38.Frame_sel10_fDryL)
                  & std_logic_vector(result_38.Frame_sel11_fDryR)
                  & std_logic_vector(result_38.Frame_sel12_fWetL)
                  & std_logic_vector(result_38.Frame_sel13_fWetR)
                  & std_logic_vector(result_38.Frame_sel14_fFbL)
                  & std_logic_vector(result_38.Frame_sel15_fFbR)
                  & std_logic_vector(result_38.Frame_sel16_fEqLowL)
                  & std_logic_vector(result_38.Frame_sel17_fEqLowR)
                  & std_logic_vector(result_38.Frame_sel18_fEqMidL)
                  & std_logic_vector(result_38.Frame_sel19_fEqMidR)
                  & std_logic_vector(result_38.Frame_sel20_fEqHighL)
                  & std_logic_vector(result_38.Frame_sel21_fEqHighR)
                  & std_logic_vector(result_38.Frame_sel22_fEqHighLpL)
                  & std_logic_vector(result_38.Frame_sel23_fEqHighLpR)
                  & std_logic_vector(result_38.Frame_sel24_fAccL)
                  & std_logic_vector(result_38.Frame_sel25_fAccR)
                  & std_logic_vector(result_38.Frame_sel26_fAcc2L)
                  & std_logic_vector(result_38.Frame_sel27_fAcc2R)
                  & std_logic_vector(result_38.Frame_sel28_fAcc3L)
                  & std_logic_vector(result_38.Frame_sel29_fAcc3R)))) when others;

  result_38 <= ( Frame_sel0_fL => x_16.Frame_sel0_fL
               , Frame_sel1_fR => x_16.Frame_sel1_fR
               , Frame_sel2_fLast => x_16.Frame_sel2_fLast
               , Frame_sel3_fGate => x_16.Frame_sel3_fGate
               , Frame_sel4_fOd => x_16.Frame_sel4_fOd
               , Frame_sel5_fDist => x_16.Frame_sel5_fDist
               , Frame_sel6_fEq => x_16.Frame_sel6_fEq
               , Frame_sel7_fRat => x_16.Frame_sel7_fRat
               , Frame_sel8_fReverb => x_16.Frame_sel8_fReverb
               , Frame_sel9_fAddr => x_16.Frame_sel9_fAddr
               , Frame_sel10_fDryL => x_16.Frame_sel10_fDryL
               , Frame_sel11_fDryR => x_16.Frame_sel11_fDryR
               , Frame_sel12_fWetL => \c$app_arg_59\
               , Frame_sel13_fWetR => \c$app_arg_57\
               , Frame_sel14_fFbL => x_16.Frame_sel14_fFbL
               , Frame_sel15_fFbR => x_16.Frame_sel15_fFbR
               , Frame_sel16_fEqLowL => x_16.Frame_sel16_fEqLowL
               , Frame_sel17_fEqLowR => x_16.Frame_sel17_fEqLowR
               , Frame_sel18_fEqMidL => x_16.Frame_sel18_fEqMidL
               , Frame_sel19_fEqMidR => x_16.Frame_sel19_fEqMidR
               , Frame_sel20_fEqHighL => x_16.Frame_sel20_fEqHighL
               , Frame_sel21_fEqHighR => x_16.Frame_sel21_fEqHighR
               , Frame_sel22_fEqHighLpL => x_16.Frame_sel22_fEqHighLpL
               , Frame_sel23_fEqHighLpR => x_16.Frame_sel23_fEqHighLpR
               , Frame_sel24_fAccL => x_16.Frame_sel24_fAccL
               , Frame_sel25_fAccR => x_16.Frame_sel25_fAccR
               , Frame_sel26_fAcc2L => x_16.Frame_sel26_fAcc2L
               , Frame_sel27_fAcc2R => x_16.Frame_sel27_fAcc2R
               , Frame_sel28_fAcc3L => x_16.Frame_sel28_fAcc3L
               , Frame_sel29_fAcc3R => x_16.Frame_sel29_fAcc3R );

  \c$app_arg_57\ <= result_39 when \on_6\ else
                    x_16.Frame_sel1_fR;

  \c$case_alt_selection_res_15\ <= \c$app_arg_58\ < to_signed(-8388608,48);

  \c$case_alt_19\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_15\ else
                     resize(\c$app_arg_58\,24);

  result_selection_res_18 <= \c$app_arg_58\ > to_signed(8388607,48);

  result_39 <= to_signed(8388607,24) when result_selection_res_18 else
               \c$case_alt_19\;

  \c$shI_19\ <= (to_signed(7,64));

  capp_arg_58_shiftR : block
    signal sh_19 : natural;
  begin
    sh_19 <=
        -- pragma translate_off
        natural'high when (\c$shI_19\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_19\);
    \c$app_arg_58\ <= shift_right((resize((resize(x_16.Frame_sel13_fWetR,48)) * \c$app_arg_61\, 48)),sh_19)
        -- pragma translate_off
        when ((to_signed(7,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_59\ <= result_40 when \on_6\ else
                    x_16.Frame_sel0_fL;

  \c$bv_10\ <= (x_16.Frame_sel3_fGate);

  \on_6\ <= (\c$bv_10\(4 downto 4)) = std_logic_vector'("1");

  \c$case_alt_selection_res_16\ <= \c$app_arg_60\ < to_signed(-8388608,48);

  \c$case_alt_20\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_16\ else
                     resize(\c$app_arg_60\,24);

  result_selection_res_19 <= \c$app_arg_60\ > to_signed(8388607,48);

  result_40 <= to_signed(8388607,24) when result_selection_res_19 else
               \c$case_alt_20\;

  \c$shI_20\ <= (to_signed(7,64));

  capp_arg_60_shiftR : block
    signal sh_20 : natural;
  begin
    sh_20 <=
        -- pragma translate_off
        natural'high when (\c$shI_20\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_20\);
    \c$app_arg_60\ <= shift_right((resize((resize(x_16.Frame_sel12_fWetL,48)) * \c$app_arg_61\, 48)),sh_20)
        -- pragma translate_off
        when ((to_signed(7,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_61\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(level)))))))),48);

  \c$bv_11\ <= (x_16.Frame_sel7_fRat);

  level <= unsigned((\c$bv_11\(15 downto 8)));

  -- register begin
  ratTonePipe_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ratTonePipe <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ratTonePipe <= result_41;
    end if;
  end process;
  -- register end

  with (ratPostPipe(875 downto 875)) select
    result_41 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(result_42.Frame_sel0_fL)
                  & std_logic_vector(result_42.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(result_42.Frame_sel2_fLast)
                  & result_42.Frame_sel3_fGate
                  & result_42.Frame_sel4_fOd
                  & result_42.Frame_sel5_fDist
                  & result_42.Frame_sel6_fEq
                  & result_42.Frame_sel7_fRat
                  & result_42.Frame_sel8_fReverb
                  & std_logic_vector(result_42.Frame_sel9_fAddr)
                  & std_logic_vector(result_42.Frame_sel10_fDryL)
                  & std_logic_vector(result_42.Frame_sel11_fDryR)
                  & std_logic_vector(result_42.Frame_sel12_fWetL)
                  & std_logic_vector(result_42.Frame_sel13_fWetR)
                  & std_logic_vector(result_42.Frame_sel14_fFbL)
                  & std_logic_vector(result_42.Frame_sel15_fFbR)
                  & std_logic_vector(result_42.Frame_sel16_fEqLowL)
                  & std_logic_vector(result_42.Frame_sel17_fEqLowR)
                  & std_logic_vector(result_42.Frame_sel18_fEqMidL)
                  & std_logic_vector(result_42.Frame_sel19_fEqMidR)
                  & std_logic_vector(result_42.Frame_sel20_fEqHighL)
                  & std_logic_vector(result_42.Frame_sel21_fEqHighR)
                  & std_logic_vector(result_42.Frame_sel22_fEqHighLpL)
                  & std_logic_vector(result_42.Frame_sel23_fEqHighLpR)
                  & std_logic_vector(result_42.Frame_sel24_fAccL)
                  & std_logic_vector(result_42.Frame_sel25_fAccR)
                  & std_logic_vector(result_42.Frame_sel26_fAcc2L)
                  & std_logic_vector(result_42.Frame_sel27_fAcc2R)
                  & std_logic_vector(result_42.Frame_sel28_fAcc3L)
                  & std_logic_vector(result_42.Frame_sel29_fAcc3R)))) when others;

  alpha <= to_unsigned(224,8) - (resize(\c$alpha_app_arg\,8));

  \c$bv_12\ <= (x_17.Frame_sel3_fGate);

  \on_7\ <= (\c$bv_12\(4 downto 4)) = std_logic_vector'("1");

  result_42 <= ( Frame_sel0_fL => x_17.Frame_sel0_fL
               , Frame_sel1_fR => x_17.Frame_sel1_fR
               , Frame_sel2_fLast => x_17.Frame_sel2_fLast
               , Frame_sel3_fGate => x_17.Frame_sel3_fGate
               , Frame_sel4_fOd => x_17.Frame_sel4_fOd
               , Frame_sel5_fDist => x_17.Frame_sel5_fDist
               , Frame_sel6_fEq => x_17.Frame_sel6_fEq
               , Frame_sel7_fRat => x_17.Frame_sel7_fRat
               , Frame_sel8_fReverb => x_17.Frame_sel8_fReverb
               , Frame_sel9_fAddr => x_17.Frame_sel9_fAddr
               , Frame_sel10_fDryL => x_17.Frame_sel10_fDryL
               , Frame_sel11_fDryR => x_17.Frame_sel11_fDryR
               , Frame_sel12_fWetL => \c$app_arg_64\
               , Frame_sel13_fWetR => \c$app_arg_62\
               , Frame_sel14_fFbL => x_17.Frame_sel14_fFbL
               , Frame_sel15_fFbR => x_17.Frame_sel15_fFbR
               , Frame_sel16_fEqLowL => x_17.Frame_sel16_fEqLowL
               , Frame_sel17_fEqLowR => x_17.Frame_sel17_fEqLowR
               , Frame_sel18_fEqMidL => x_17.Frame_sel18_fEqMidL
               , Frame_sel19_fEqMidR => x_17.Frame_sel19_fEqMidR
               , Frame_sel20_fEqHighL => x_17.Frame_sel20_fEqHighL
               , Frame_sel21_fEqHighR => x_17.Frame_sel21_fEqHighR
               , Frame_sel22_fEqHighLpL => x_17.Frame_sel22_fEqHighLpL
               , Frame_sel23_fEqHighLpR => x_17.Frame_sel23_fEqHighLpR
               , Frame_sel24_fAccL => x_17.Frame_sel24_fAccL
               , Frame_sel25_fAccR => x_17.Frame_sel25_fAccR
               , Frame_sel26_fAcc2L => x_17.Frame_sel26_fAcc2L
               , Frame_sel27_fAcc2R => x_17.Frame_sel27_fAcc2R
               , Frame_sel28_fAcc3L => x_17.Frame_sel28_fAcc3L
               , Frame_sel29_fAcc3R => x_17.Frame_sel29_fAcc3R );

  \c$app_arg_62\ <= result_43 when \on_7\ else
                    x_17.Frame_sel1_fR;

  \c$shI_21\ <= (to_signed(8,64));

  capp_arg_63_shiftR : block
    signal sh_21 : natural;
  begin
    sh_21 <=
        -- pragma translate_off
        natural'high when (\c$shI_21\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_21\);
    \c$app_arg_63\ <= shift_right(((resize((resize(x_17.Frame_sel13_fWetR,48)) * (resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(alpha)))))))),48)), 48)) + (resize((resize(ratTonePrevR,48)) * (resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(gain_5)))))))),48)), 48))),sh_21)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  gain_5 <= to_unsigned(255,8) - alpha;

  \c$case_alt_selection_res_17\ <= \c$app_arg_63\ < to_signed(-8388608,48);

  \c$case_alt_21\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_17\ else
                     resize(\c$app_arg_63\,24);

  result_selection_res_20 <= \c$app_arg_63\ > to_signed(8388607,48);

  result_43 <= to_signed(8388607,24) when result_selection_res_20 else
               \c$case_alt_21\;

  \c$app_arg_64\ <= result_44 when \on_7\ else
                    x_17.Frame_sel0_fL;

  \c$shI_22\ <= (to_signed(8,64));

  capp_arg_65_shiftR : block
    signal sh_22 : natural;
  begin
    sh_22 <=
        -- pragma translate_off
        natural'high when (\c$shI_22\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_22\);
    \c$app_arg_65\ <= shift_right(((resize((resize(x_17.Frame_sel12_fWetL,48)) * (resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(alpha)))))))),48)), 48)) + (resize((resize(ratTonePrevL,48)) * (resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(gain_6)))))))),48)), 48))),sh_22)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  gain_6 <= to_unsigned(255,8) - alpha;

  \c$case_alt_selection_res_18\ <= \c$app_arg_65\ < to_signed(-8388608,48);

  \c$case_alt_22\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_18\ else
                     resize(\c$app_arg_65\,24);

  result_selection_res_21 <= \c$app_arg_65\ > to_signed(8388607,48);

  result_44 <= to_signed(8388607,24) when result_selection_res_21 else
               \c$case_alt_22\;

  \c$bv_13\ <= (x_17.Frame_sel7_fRat);

  \c$shI_23\ <= (to_signed(2,64));

  calpha_app_arg_shiftL : block
    signal sh_23 : natural;
  begin
    sh_23 <=
        -- pragma translate_off
        natural'high when (\c$shI_23\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_23\);
    \c$alpha_app_arg\ <= shift_right((resize((resize((unsigned((\c$bv_13\(7 downto 0)))),10)) * to_unsigned(3,10), 10)),sh_23)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  -- register begin
  ratTonePrevR_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ratTonePrevR <= to_signed(0,24);
    elsif rising_edge(clk) then
      ratTonePrevR <= \c$ratTonePrevR_app_arg\;
    end if;
  end process;
  -- register end

  with (ratTonePipe(875 downto 875)) select
    \c$ratTonePrevR_app_arg\ <= ratTonePrevR when "0",
                                x_16.Frame_sel13_fWetR when others;

  -- register begin
  ratTonePrevL_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ratTonePrevL <= to_signed(0,24);
    elsif rising_edge(clk) then
      ratTonePrevL <= \c$ratTonePrevL_app_arg\;
    end if;
  end process;
  -- register end

  with (ratTonePipe(875 downto 875)) select
    \c$ratTonePrevL_app_arg\ <= ratTonePrevL when "0",
                                x_16.Frame_sel12_fWetL when others;

  x_16 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ratTonePipe(874 downto 0)));

  -- register begin
  ratPostPipe_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ratPostPipe <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ratPostPipe <= result_45;
    end if;
  end process;
  -- register end

  with (ds1_7(875 downto 875)) select
    result_45 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(result_46.Frame_sel0_fL)
                  & std_logic_vector(result_46.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(result_46.Frame_sel2_fLast)
                  & result_46.Frame_sel3_fGate
                  & result_46.Frame_sel4_fOd
                  & result_46.Frame_sel5_fDist
                  & result_46.Frame_sel6_fEq
                  & result_46.Frame_sel7_fRat
                  & result_46.Frame_sel8_fReverb
                  & std_logic_vector(result_46.Frame_sel9_fAddr)
                  & std_logic_vector(result_46.Frame_sel10_fDryL)
                  & std_logic_vector(result_46.Frame_sel11_fDryR)
                  & std_logic_vector(result_46.Frame_sel12_fWetL)
                  & std_logic_vector(result_46.Frame_sel13_fWetR)
                  & std_logic_vector(result_46.Frame_sel14_fFbL)
                  & std_logic_vector(result_46.Frame_sel15_fFbR)
                  & std_logic_vector(result_46.Frame_sel16_fEqLowL)
                  & std_logic_vector(result_46.Frame_sel17_fEqLowR)
                  & std_logic_vector(result_46.Frame_sel18_fEqMidL)
                  & std_logic_vector(result_46.Frame_sel19_fEqMidR)
                  & std_logic_vector(result_46.Frame_sel20_fEqHighL)
                  & std_logic_vector(result_46.Frame_sel21_fEqHighR)
                  & std_logic_vector(result_46.Frame_sel22_fEqHighLpL)
                  & std_logic_vector(result_46.Frame_sel23_fEqHighLpR)
                  & std_logic_vector(result_46.Frame_sel24_fAccL)
                  & std_logic_vector(result_46.Frame_sel25_fAccR)
                  & std_logic_vector(result_46.Frame_sel26_fAcc2L)
                  & std_logic_vector(result_46.Frame_sel27_fAcc2R)
                  & std_logic_vector(result_46.Frame_sel28_fAcc3L)
                  & std_logic_vector(result_46.Frame_sel29_fAcc3R)))) when others;

  \c$bv_14\ <= (x_18.Frame_sel3_fGate);

  \on_8\ <= (\c$bv_14\(4 downto 4)) = std_logic_vector'("1");

  result_46 <= ( Frame_sel0_fL => x_18.Frame_sel0_fL
               , Frame_sel1_fR => x_18.Frame_sel1_fR
               , Frame_sel2_fLast => x_18.Frame_sel2_fLast
               , Frame_sel3_fGate => x_18.Frame_sel3_fGate
               , Frame_sel4_fOd => x_18.Frame_sel4_fOd
               , Frame_sel5_fDist => x_18.Frame_sel5_fDist
               , Frame_sel6_fEq => x_18.Frame_sel6_fEq
               , Frame_sel7_fRat => x_18.Frame_sel7_fRat
               , Frame_sel8_fReverb => x_18.Frame_sel8_fReverb
               , Frame_sel9_fAddr => x_18.Frame_sel9_fAddr
               , Frame_sel10_fDryL => x_18.Frame_sel10_fDryL
               , Frame_sel11_fDryR => x_18.Frame_sel11_fDryR
               , Frame_sel12_fWetL => \c$app_arg_68\
               , Frame_sel13_fWetR => \c$app_arg_66\
               , Frame_sel14_fFbL => x_18.Frame_sel14_fFbL
               , Frame_sel15_fFbR => x_18.Frame_sel15_fFbR
               , Frame_sel16_fEqLowL => x_18.Frame_sel16_fEqLowL
               , Frame_sel17_fEqLowR => x_18.Frame_sel17_fEqLowR
               , Frame_sel18_fEqMidL => x_18.Frame_sel18_fEqMidL
               , Frame_sel19_fEqMidR => x_18.Frame_sel19_fEqMidR
               , Frame_sel20_fEqHighL => x_18.Frame_sel20_fEqHighL
               , Frame_sel21_fEqHighR => x_18.Frame_sel21_fEqHighR
               , Frame_sel22_fEqHighLpL => x_18.Frame_sel22_fEqHighLpL
               , Frame_sel23_fEqHighLpR => x_18.Frame_sel23_fEqHighLpR
               , Frame_sel24_fAccL => x_18.Frame_sel24_fAccL
               , Frame_sel25_fAccR => x_18.Frame_sel25_fAccR
               , Frame_sel26_fAcc2L => x_18.Frame_sel26_fAcc2L
               , Frame_sel27_fAcc2R => x_18.Frame_sel27_fAcc2R
               , Frame_sel28_fAcc3L => x_18.Frame_sel28_fAcc3L
               , Frame_sel29_fAcc3R => x_18.Frame_sel29_fAcc3R );

  \c$app_arg_66\ <= result_47 when \on_8\ else
                    x_18.Frame_sel1_fR;

  \c$shI_24\ <= (to_signed(8,64));

  capp_arg_67_shiftR : block
    signal sh_24 : natural;
  begin
    sh_24 <=
        -- pragma translate_off
        natural'high when (\c$shI_24\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_24\);
    \c$app_arg_67\ <= shift_right(((resize((resize(x_18.Frame_sel13_fWetR,48)) * to_signed(192,48), 48)) + (resize((resize(ratPostPrevR,48)) * to_signed(63,48), 48))),sh_24)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_19\ <= \c$app_arg_67\ < to_signed(-8388608,48);

  \c$case_alt_23\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_19\ else
                     resize(\c$app_arg_67\,24);

  result_selection_res_22 <= \c$app_arg_67\ > to_signed(8388607,48);

  result_47 <= to_signed(8388607,24) when result_selection_res_22 else
               \c$case_alt_23\;

  \c$app_arg_68\ <= result_48 when \on_8\ else
                    x_18.Frame_sel0_fL;

  \c$shI_25\ <= (to_signed(8,64));

  capp_arg_69_shiftR : block
    signal sh_25 : natural;
  begin
    sh_25 <=
        -- pragma translate_off
        natural'high when (\c$shI_25\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_25\);
    \c$app_arg_69\ <= shift_right(((resize((resize(x_18.Frame_sel12_fWetL,48)) * to_signed(192,48), 48)) + (resize((resize(ratPostPrevL,48)) * to_signed(63,48), 48))),sh_25)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_20\ <= \c$app_arg_69\ < to_signed(-8388608,48);

  \c$case_alt_24\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_20\ else
                     resize(\c$app_arg_69\,24);

  result_selection_res_23 <= \c$app_arg_69\ > to_signed(8388607,48);

  result_48 <= to_signed(8388607,24) when result_selection_res_23 else
               \c$case_alt_24\;

  -- register begin
  ratPostPrevR_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ratPostPrevR <= to_signed(0,24);
    elsif rising_edge(clk) then
      ratPostPrevR <= \c$ratPostPrevR_app_arg\;
    end if;
  end process;
  -- register end

  with (ratPostPipe(875 downto 875)) select
    \c$ratPostPrevR_app_arg\ <= ratPostPrevR when "0",
                                x_17.Frame_sel13_fWetR when others;

  -- register begin
  ratPostPrevL_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ratPostPrevL <= to_signed(0,24);
    elsif rising_edge(clk) then
      ratPostPrevL <= \c$ratPostPrevL_app_arg\;
    end if;
  end process;
  -- register end

  with (ratPostPipe(875 downto 875)) select
    \c$ratPostPrevL_app_arg\ <= ratPostPrevL when "0",
                                x_17.Frame_sel12_fWetL when others;

  x_17 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ratPostPipe(874 downto 0)));

  x_18 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_7(874 downto 0)));

  -- register begin
  ds1_7_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_7 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_7 <= result_49;
    end if;
  end process;
  -- register end

  with (ratOpAmpPipe(875 downto 875)) select
    result_49 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(result_50.Frame_sel0_fL)
                  & std_logic_vector(result_50.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(result_50.Frame_sel2_fLast)
                  & result_50.Frame_sel3_fGate
                  & result_50.Frame_sel4_fOd
                  & result_50.Frame_sel5_fDist
                  & result_50.Frame_sel6_fEq
                  & result_50.Frame_sel7_fRat
                  & result_50.Frame_sel8_fReverb
                  & std_logic_vector(result_50.Frame_sel9_fAddr)
                  & std_logic_vector(result_50.Frame_sel10_fDryL)
                  & std_logic_vector(result_50.Frame_sel11_fDryR)
                  & std_logic_vector(result_50.Frame_sel12_fWetL)
                  & std_logic_vector(result_50.Frame_sel13_fWetR)
                  & std_logic_vector(result_50.Frame_sel14_fFbL)
                  & std_logic_vector(result_50.Frame_sel15_fFbR)
                  & std_logic_vector(result_50.Frame_sel16_fEqLowL)
                  & std_logic_vector(result_50.Frame_sel17_fEqLowR)
                  & std_logic_vector(result_50.Frame_sel18_fEqMidL)
                  & std_logic_vector(result_50.Frame_sel19_fEqMidR)
                  & std_logic_vector(result_50.Frame_sel20_fEqHighL)
                  & std_logic_vector(result_50.Frame_sel21_fEqHighR)
                  & std_logic_vector(result_50.Frame_sel22_fEqHighLpL)
                  & std_logic_vector(result_50.Frame_sel23_fEqHighLpR)
                  & std_logic_vector(result_50.Frame_sel24_fAccL)
                  & std_logic_vector(result_50.Frame_sel25_fAccR)
                  & std_logic_vector(result_50.Frame_sel26_fAcc2L)
                  & std_logic_vector(result_50.Frame_sel27_fAcc2R)
                  & std_logic_vector(result_50.Frame_sel28_fAcc3L)
                  & std_logic_vector(result_50.Frame_sel29_fAcc3R)))) when others;

  threshold <= resize(result_53,24);

  \c$bv_15\ <= (x_20.Frame_sel3_fGate);

  \on_9\ <= (\c$bv_15\(4 downto 4)) = std_logic_vector'("1");

  result_50 <= ( Frame_sel0_fL => x_20.Frame_sel0_fL
               , Frame_sel1_fR => x_20.Frame_sel1_fR
               , Frame_sel2_fLast => x_20.Frame_sel2_fLast
               , Frame_sel3_fGate => x_20.Frame_sel3_fGate
               , Frame_sel4_fOd => x_20.Frame_sel4_fOd
               , Frame_sel5_fDist => x_20.Frame_sel5_fDist
               , Frame_sel6_fEq => x_20.Frame_sel6_fEq
               , Frame_sel7_fRat => x_20.Frame_sel7_fRat
               , Frame_sel8_fReverb => x_20.Frame_sel8_fReverb
               , Frame_sel9_fAddr => x_20.Frame_sel9_fAddr
               , Frame_sel10_fDryL => x_20.Frame_sel10_fDryL
               , Frame_sel11_fDryR => x_20.Frame_sel11_fDryR
               , Frame_sel12_fWetL => \c$app_arg_72\
               , Frame_sel13_fWetR => \c$app_arg_70\
               , Frame_sel14_fFbL => x_20.Frame_sel14_fFbL
               , Frame_sel15_fFbR => x_20.Frame_sel15_fFbR
               , Frame_sel16_fEqLowL => x_20.Frame_sel16_fEqLowL
               , Frame_sel17_fEqLowR => x_20.Frame_sel17_fEqLowR
               , Frame_sel18_fEqMidL => x_20.Frame_sel18_fEqMidL
               , Frame_sel19_fEqMidR => x_20.Frame_sel19_fEqMidR
               , Frame_sel20_fEqHighL => x_20.Frame_sel20_fEqHighL
               , Frame_sel21_fEqHighR => x_20.Frame_sel21_fEqHighR
               , Frame_sel22_fEqHighLpL => x_20.Frame_sel22_fEqHighLpL
               , Frame_sel23_fEqHighLpR => x_20.Frame_sel23_fEqHighLpR
               , Frame_sel24_fAccL => x_20.Frame_sel24_fAccL
               , Frame_sel25_fAccR => x_20.Frame_sel25_fAccR
               , Frame_sel26_fAcc2L => x_20.Frame_sel26_fAcc2L
               , Frame_sel27_fAcc2R => x_20.Frame_sel27_fAcc2R
               , Frame_sel28_fAcc3L => x_20.Frame_sel28_fAcc3L
               , Frame_sel29_fAcc3R => x_20.Frame_sel29_fAcc3R );

  \c$app_arg_70\ <= result_51 when \on_9\ else
                    x_20.Frame_sel1_fR;

  result_selection_res_24 <= x_20.Frame_sel13_fWetR > threshold;

  result_51 <= threshold when result_selection_res_24 else
               \c$case_alt_25\;

  \c$case_alt_selection_res_21\ <= x_20.Frame_sel13_fWetR < \c$app_arg_71\;

  \c$case_alt_25\ <= \c$app_arg_71\ when \c$case_alt_selection_res_21\ else
                     x_20.Frame_sel13_fWetR;

  \c$app_arg_71\ <= -threshold;

  \c$app_arg_72\ <= result_52 when \on_9\ else
                    x_20.Frame_sel0_fL;

  result_selection_res_25 <= x_20.Frame_sel12_fWetL > threshold;

  result_52 <= threshold when result_selection_res_25 else
               \c$case_alt_26\;

  \c$case_alt_selection_res_22\ <= x_20.Frame_sel12_fWetL < \c$app_arg_73\;

  \c$case_alt_26\ <= \c$app_arg_73\ when \c$case_alt_selection_res_22\ else
                     x_20.Frame_sel12_fWetL;

  \c$app_arg_73\ <= -threshold;

  rawThreshold <= to_signed(6291456,25) - (resize((resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(x_19)))))))),25)) * to_signed(9000,25), 25));

  result_selection_res_26 <= rawThreshold < to_signed(3750000,25);

  result_53 <= to_signed(3750000,25) when result_selection_res_26 else
               rawThreshold;

  \c$bv_16\ <= (x_20.Frame_sel7_fRat);

  x_19 <= unsigned((\c$bv_16\(23 downto 16)));

  -- register begin
  ratOpAmpPipe_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ratOpAmpPipe <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ratOpAmpPipe <= result_54;
    end if;
  end process;
  -- register end

  with (ds1_8(875 downto 875)) select
    result_54 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(result_55.Frame_sel0_fL)
                  & std_logic_vector(result_55.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(result_55.Frame_sel2_fLast)
                  & result_55.Frame_sel3_fGate
                  & result_55.Frame_sel4_fOd
                  & result_55.Frame_sel5_fDist
                  & result_55.Frame_sel6_fEq
                  & result_55.Frame_sel7_fRat
                  & result_55.Frame_sel8_fReverb
                  & std_logic_vector(result_55.Frame_sel9_fAddr)
                  & std_logic_vector(result_55.Frame_sel10_fDryL)
                  & std_logic_vector(result_55.Frame_sel11_fDryR)
                  & std_logic_vector(result_55.Frame_sel12_fWetL)
                  & std_logic_vector(result_55.Frame_sel13_fWetR)
                  & std_logic_vector(result_55.Frame_sel14_fFbL)
                  & std_logic_vector(result_55.Frame_sel15_fFbR)
                  & std_logic_vector(result_55.Frame_sel16_fEqLowL)
                  & std_logic_vector(result_55.Frame_sel17_fEqLowR)
                  & std_logic_vector(result_55.Frame_sel18_fEqMidL)
                  & std_logic_vector(result_55.Frame_sel19_fEqMidR)
                  & std_logic_vector(result_55.Frame_sel20_fEqHighL)
                  & std_logic_vector(result_55.Frame_sel21_fEqHighR)
                  & std_logic_vector(result_55.Frame_sel22_fEqHighLpL)
                  & std_logic_vector(result_55.Frame_sel23_fEqHighLpR)
                  & std_logic_vector(result_55.Frame_sel24_fAccL)
                  & std_logic_vector(result_55.Frame_sel25_fAccR)
                  & std_logic_vector(result_55.Frame_sel26_fAcc2L)
                  & std_logic_vector(result_55.Frame_sel27_fAcc2R)
                  & std_logic_vector(result_55.Frame_sel28_fAcc3L)
                  & std_logic_vector(result_55.Frame_sel29_fAcc3R)))) when others;

  alpha_0 <= to_unsigned(192,8) - (resize(\c$alpha_app_arg_0\,8));

  \c$bv_17\ <= (x_21.Frame_sel3_fGate);

  \on_10\ <= (\c$bv_17\(4 downto 4)) = std_logic_vector'("1");

  result_55 <= ( Frame_sel0_fL => x_21.Frame_sel0_fL
               , Frame_sel1_fR => x_21.Frame_sel1_fR
               , Frame_sel2_fLast => x_21.Frame_sel2_fLast
               , Frame_sel3_fGate => x_21.Frame_sel3_fGate
               , Frame_sel4_fOd => x_21.Frame_sel4_fOd
               , Frame_sel5_fDist => x_21.Frame_sel5_fDist
               , Frame_sel6_fEq => x_21.Frame_sel6_fEq
               , Frame_sel7_fRat => x_21.Frame_sel7_fRat
               , Frame_sel8_fReverb => x_21.Frame_sel8_fReverb
               , Frame_sel9_fAddr => x_21.Frame_sel9_fAddr
               , Frame_sel10_fDryL => x_21.Frame_sel10_fDryL
               , Frame_sel11_fDryR => x_21.Frame_sel11_fDryR
               , Frame_sel12_fWetL => \c$app_arg_76\
               , Frame_sel13_fWetR => \c$app_arg_74\
               , Frame_sel14_fFbL => x_21.Frame_sel14_fFbL
               , Frame_sel15_fFbR => x_21.Frame_sel15_fFbR
               , Frame_sel16_fEqLowL => x_21.Frame_sel16_fEqLowL
               , Frame_sel17_fEqLowR => x_21.Frame_sel17_fEqLowR
               , Frame_sel18_fEqMidL => x_21.Frame_sel18_fEqMidL
               , Frame_sel19_fEqMidR => x_21.Frame_sel19_fEqMidR
               , Frame_sel20_fEqHighL => x_21.Frame_sel20_fEqHighL
               , Frame_sel21_fEqHighR => x_21.Frame_sel21_fEqHighR
               , Frame_sel22_fEqHighLpL => x_21.Frame_sel22_fEqHighLpL
               , Frame_sel23_fEqHighLpR => x_21.Frame_sel23_fEqHighLpR
               , Frame_sel24_fAccL => x_21.Frame_sel24_fAccL
               , Frame_sel25_fAccR => x_21.Frame_sel25_fAccR
               , Frame_sel26_fAcc2L => x_21.Frame_sel26_fAcc2L
               , Frame_sel27_fAcc2R => x_21.Frame_sel27_fAcc2R
               , Frame_sel28_fAcc3L => x_21.Frame_sel28_fAcc3L
               , Frame_sel29_fAcc3R => x_21.Frame_sel29_fAcc3R );

  \c$app_arg_74\ <= result_56 when \on_10\ else
                    x_21.Frame_sel1_fR;

  \c$shI_26\ <= (to_signed(8,64));

  capp_arg_75_shiftR : block
    signal sh_26 : natural;
  begin
    sh_26 <=
        -- pragma translate_off
        natural'high when (\c$shI_26\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_26\);
    \c$app_arg_75\ <= shift_right(((resize((resize(x_21.Frame_sel13_fWetR,48)) * (resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(alpha_0)))))))),48)), 48)) + (resize((resize(ratOpAmpPrevR,48)) * (resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(gain_7)))))))),48)), 48))),sh_26)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  gain_7 <= to_unsigned(255,8) - alpha_0;

  \c$case_alt_selection_res_23\ <= \c$app_arg_75\ < to_signed(-8388608,48);

  \c$case_alt_27\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_23\ else
                     resize(\c$app_arg_75\,24);

  result_selection_res_27 <= \c$app_arg_75\ > to_signed(8388607,48);

  result_56 <= to_signed(8388607,24) when result_selection_res_27 else
               \c$case_alt_27\;

  \c$app_arg_76\ <= result_57 when \on_10\ else
                    x_21.Frame_sel0_fL;

  \c$shI_27\ <= (to_signed(8,64));

  capp_arg_77_shiftR : block
    signal sh_27 : natural;
  begin
    sh_27 <=
        -- pragma translate_off
        natural'high when (\c$shI_27\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_27\);
    \c$app_arg_77\ <= shift_right(((resize((resize(x_21.Frame_sel12_fWetL,48)) * (resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(alpha_0)))))))),48)), 48)) + (resize((resize(ratOpAmpPrevL,48)) * (resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(gain_8)))))))),48)), 48))),sh_27)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  gain_8 <= to_unsigned(255,8) - alpha_0;

  \c$case_alt_selection_res_24\ <= \c$app_arg_77\ < to_signed(-8388608,48);

  \c$case_alt_28\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_24\ else
                     resize(\c$app_arg_77\,24);

  result_selection_res_28 <= \c$app_arg_77\ > to_signed(8388607,48);

  result_57 <= to_signed(8388607,24) when result_selection_res_28 else
               \c$case_alt_28\;

  \c$bv_18\ <= (x_21.Frame_sel7_fRat);

  \c$shI_28\ <= (to_signed(1,64));

  calpha_app_arg_0_shiftL : block
    signal sh_28 : natural;
  begin
    sh_28 <=
        -- pragma translate_off
        natural'high when (\c$shI_28\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_28\);
    \c$alpha_app_arg_0\ <= shift_right((unsigned((\c$bv_18\(23 downto 16)))),sh_28)
        -- pragma translate_off
        when ((to_signed(1,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  -- register begin
  ratOpAmpPrevR_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ratOpAmpPrevR <= to_signed(0,24);
    elsif rising_edge(clk) then
      ratOpAmpPrevR <= \c$ratOpAmpPrevR_app_arg\;
    end if;
  end process;
  -- register end

  with (ratOpAmpPipe(875 downto 875)) select
    \c$ratOpAmpPrevR_app_arg\ <= ratOpAmpPrevR when "0",
                                 x_20.Frame_sel13_fWetR when others;

  -- register begin
  ratOpAmpPrevL_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ratOpAmpPrevL <= to_signed(0,24);
    elsif rising_edge(clk) then
      ratOpAmpPrevL <= \c$ratOpAmpPrevL_app_arg\;
    end if;
  end process;
  -- register end

  with (ratOpAmpPipe(875 downto 875)) select
    \c$ratOpAmpPrevL_app_arg\ <= ratOpAmpPrevL when "0",
                                 x_20.Frame_sel12_fWetL when others;

  x_20 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ratOpAmpPipe(874 downto 0)));

  x_21 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_8(874 downto 0)));

  -- register begin
  ds1_8_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_8 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_8 <= result_58;
    end if;
  end process;
  -- register end

  with (ds1_9(875 downto 875)) select
    result_58 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(result_61.Frame_sel0_fL)
                  & std_logic_vector(result_61.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(result_61.Frame_sel2_fLast)
                  & result_61.Frame_sel3_fGate
                  & result_61.Frame_sel4_fOd
                  & result_61.Frame_sel5_fDist
                  & result_61.Frame_sel6_fEq
                  & result_61.Frame_sel7_fRat
                  & result_61.Frame_sel8_fReverb
                  & std_logic_vector(result_61.Frame_sel9_fAddr)
                  & std_logic_vector(result_61.Frame_sel10_fDryL)
                  & std_logic_vector(result_61.Frame_sel11_fDryR)
                  & std_logic_vector(result_61.Frame_sel12_fWetL)
                  & std_logic_vector(result_61.Frame_sel13_fWetR)
                  & std_logic_vector(result_61.Frame_sel14_fFbL)
                  & std_logic_vector(result_61.Frame_sel15_fFbR)
                  & std_logic_vector(result_61.Frame_sel16_fEqLowL)
                  & std_logic_vector(result_61.Frame_sel17_fEqLowR)
                  & std_logic_vector(result_61.Frame_sel18_fEqMidL)
                  & std_logic_vector(result_61.Frame_sel19_fEqMidR)
                  & std_logic_vector(result_61.Frame_sel20_fEqHighL)
                  & std_logic_vector(result_61.Frame_sel21_fEqHighR)
                  & std_logic_vector(result_61.Frame_sel22_fEqHighLpL)
                  & std_logic_vector(result_61.Frame_sel23_fEqHighLpR)
                  & std_logic_vector(result_61.Frame_sel24_fAccL)
                  & std_logic_vector(result_61.Frame_sel25_fAccR)
                  & std_logic_vector(result_61.Frame_sel26_fAcc2L)
                  & std_logic_vector(result_61.Frame_sel27_fAcc2R)
                  & std_logic_vector(result_61.Frame_sel28_fAcc3L)
                  & std_logic_vector(result_61.Frame_sel29_fAcc3R)))) when others;

  \c$shI_29\ <= (to_signed(8,64));

  capp_arg_78_shiftR : block
    signal sh_29 : natural;
  begin
    sh_29 <=
        -- pragma translate_off
        natural'high when (\c$shI_29\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_29\);
    \c$app_arg_78\ <= shift_right(x_22.Frame_sel24_fAccL,sh_29)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_25\ <= \c$app_arg_78\ < to_signed(-8388608,48);

  \c$case_alt_29\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_25\ else
                     resize(\c$app_arg_78\,24);

  result_selection_res_29 <= \c$app_arg_78\ > to_signed(8388607,48);

  result_59 <= to_signed(8388607,24) when result_selection_res_29 else
               \c$case_alt_29\;

  \c$app_arg_79\ <= result_59 when \on_11\ else
                    x_22.Frame_sel0_fL;

  \c$shI_30\ <= (to_signed(8,64));

  capp_arg_80_shiftR : block
    signal sh_30 : natural;
  begin
    sh_30 <=
        -- pragma translate_off
        natural'high when (\c$shI_30\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_30\);
    \c$app_arg_80\ <= shift_right(x_22.Frame_sel25_fAccR,sh_30)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_26\ <= \c$app_arg_80\ < to_signed(-8388608,48);

  \c$case_alt_30\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_26\ else
                     resize(\c$app_arg_80\,24);

  result_selection_res_30 <= \c$app_arg_80\ > to_signed(8388607,48);

  result_60 <= to_signed(8388607,24) when result_selection_res_30 else
               \c$case_alt_30\;

  \c$app_arg_81\ <= result_60 when \on_11\ else
                    x_22.Frame_sel1_fR;

  result_61 <= ( Frame_sel0_fL => x_22.Frame_sel0_fL
               , Frame_sel1_fR => x_22.Frame_sel1_fR
               , Frame_sel2_fLast => x_22.Frame_sel2_fLast
               , Frame_sel3_fGate => x_22.Frame_sel3_fGate
               , Frame_sel4_fOd => x_22.Frame_sel4_fOd
               , Frame_sel5_fDist => x_22.Frame_sel5_fDist
               , Frame_sel6_fEq => x_22.Frame_sel6_fEq
               , Frame_sel7_fRat => x_22.Frame_sel7_fRat
               , Frame_sel8_fReverb => x_22.Frame_sel8_fReverb
               , Frame_sel9_fAddr => x_22.Frame_sel9_fAddr
               , Frame_sel10_fDryL => x_22.Frame_sel10_fDryL
               , Frame_sel11_fDryR => x_22.Frame_sel11_fDryR
               , Frame_sel12_fWetL => \c$app_arg_79\
               , Frame_sel13_fWetR => \c$app_arg_81\
               , Frame_sel14_fFbL => x_22.Frame_sel14_fFbL
               , Frame_sel15_fFbR => x_22.Frame_sel15_fFbR
               , Frame_sel16_fEqLowL => x_22.Frame_sel16_fEqLowL
               , Frame_sel17_fEqLowR => x_22.Frame_sel17_fEqLowR
               , Frame_sel18_fEqMidL => x_22.Frame_sel18_fEqMidL
               , Frame_sel19_fEqMidR => x_22.Frame_sel19_fEqMidR
               , Frame_sel20_fEqHighL => x_22.Frame_sel20_fEqHighL
               , Frame_sel21_fEqHighR => x_22.Frame_sel21_fEqHighR
               , Frame_sel22_fEqHighLpL => x_22.Frame_sel22_fEqHighLpL
               , Frame_sel23_fEqHighLpR => x_22.Frame_sel23_fEqHighLpR
               , Frame_sel24_fAccL => x_22.Frame_sel24_fAccL
               , Frame_sel25_fAccR => x_22.Frame_sel25_fAccR
               , Frame_sel26_fAcc2L => x_22.Frame_sel26_fAcc2L
               , Frame_sel27_fAcc2R => x_22.Frame_sel27_fAcc2R
               , Frame_sel28_fAcc3L => x_22.Frame_sel28_fAcc3L
               , Frame_sel29_fAcc3R => x_22.Frame_sel29_fAcc3R );

  \c$bv_19\ <= (x_22.Frame_sel3_fGate);

  \on_11\ <= (\c$bv_19\(4 downto 4)) = std_logic_vector'("1");

  x_22 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_9(874 downto 0)));

  -- register begin
  ds1_9_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_9 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_9 <= result_62;
    end if;
  end process;
  -- register end

  with (ratHighpassPipe(875 downto 875)) select
    result_62 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(result_63.Frame_sel0_fL)
                  & std_logic_vector(result_63.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(result_63.Frame_sel2_fLast)
                  & result_63.Frame_sel3_fGate
                  & result_63.Frame_sel4_fOd
                  & result_63.Frame_sel5_fDist
                  & result_63.Frame_sel6_fEq
                  & result_63.Frame_sel7_fRat
                  & result_63.Frame_sel8_fReverb
                  & std_logic_vector(result_63.Frame_sel9_fAddr)
                  & std_logic_vector(result_63.Frame_sel10_fDryL)
                  & std_logic_vector(result_63.Frame_sel11_fDryR)
                  & std_logic_vector(result_63.Frame_sel12_fWetL)
                  & std_logic_vector(result_63.Frame_sel13_fWetR)
                  & std_logic_vector(result_63.Frame_sel14_fFbL)
                  & std_logic_vector(result_63.Frame_sel15_fFbR)
                  & std_logic_vector(result_63.Frame_sel16_fEqLowL)
                  & std_logic_vector(result_63.Frame_sel17_fEqLowR)
                  & std_logic_vector(result_63.Frame_sel18_fEqMidL)
                  & std_logic_vector(result_63.Frame_sel19_fEqMidR)
                  & std_logic_vector(result_63.Frame_sel20_fEqHighL)
                  & std_logic_vector(result_63.Frame_sel21_fEqHighR)
                  & std_logic_vector(result_63.Frame_sel22_fEqHighLpL)
                  & std_logic_vector(result_63.Frame_sel23_fEqHighLpR)
                  & std_logic_vector(result_63.Frame_sel24_fAccL)
                  & std_logic_vector(result_63.Frame_sel25_fAccR)
                  & std_logic_vector(result_63.Frame_sel26_fAcc2L)
                  & std_logic_vector(result_63.Frame_sel27_fAcc2R)
                  & std_logic_vector(result_63.Frame_sel28_fAcc3L)
                  & std_logic_vector(result_63.Frame_sel29_fAcc3R)))) when others;

  result_63 <= ( Frame_sel0_fL => x_25.Frame_sel0_fL
               , Frame_sel1_fR => x_25.Frame_sel1_fR
               , Frame_sel2_fLast => x_25.Frame_sel2_fLast
               , Frame_sel3_fGate => x_25.Frame_sel3_fGate
               , Frame_sel4_fOd => x_25.Frame_sel4_fOd
               , Frame_sel5_fDist => x_25.Frame_sel5_fDist
               , Frame_sel6_fEq => x_25.Frame_sel6_fEq
               , Frame_sel7_fRat => x_25.Frame_sel7_fRat
               , Frame_sel8_fReverb => x_25.Frame_sel8_fReverb
               , Frame_sel9_fAddr => x_25.Frame_sel9_fAddr
               , Frame_sel10_fDryL => x_25.Frame_sel10_fDryL
               , Frame_sel11_fDryR => x_25.Frame_sel11_fDryR
               , Frame_sel12_fWetL => x_25.Frame_sel12_fWetL
               , Frame_sel13_fWetR => x_25.Frame_sel13_fWetR
               , Frame_sel14_fFbL => x_25.Frame_sel14_fFbL
               , Frame_sel15_fFbR => x_25.Frame_sel15_fFbR
               , Frame_sel16_fEqLowL => x_25.Frame_sel16_fEqLowL
               , Frame_sel17_fEqLowR => x_25.Frame_sel17_fEqLowR
               , Frame_sel18_fEqMidL => x_25.Frame_sel18_fEqMidL
               , Frame_sel19_fEqMidR => x_25.Frame_sel19_fEqMidR
               , Frame_sel20_fEqHighL => x_25.Frame_sel20_fEqHighL
               , Frame_sel21_fEqHighR => x_25.Frame_sel21_fEqHighR
               , Frame_sel22_fEqHighLpL => x_25.Frame_sel22_fEqHighLpL
               , Frame_sel23_fEqHighLpR => x_25.Frame_sel23_fEqHighLpR
               , Frame_sel24_fAccL => \c$app_arg_83\
               , Frame_sel25_fAccR => \c$app_arg_82\
               , Frame_sel26_fAcc2L => x_25.Frame_sel26_fAcc2L
               , Frame_sel27_fAcc2R => x_25.Frame_sel27_fAcc2R
               , Frame_sel28_fAcc3L => x_25.Frame_sel28_fAcc3L
               , Frame_sel29_fAcc3R => x_25.Frame_sel29_fAcc3R );

  \c$app_arg_82\ <= resize((resize(x_25.Frame_sel13_fWetR,48)) * \c$app_arg_84\, 48) when \on_12\ else
                    to_signed(0,48);

  \c$app_arg_83\ <= resize((resize(x_25.Frame_sel12_fWetL,48)) * \c$app_arg_84\, 48) when \on_12\ else
                    to_signed(0,48);

  \c$bv_20\ <= (x_25.Frame_sel3_fGate);

  \on_12\ <= (\c$bv_20\(4 downto 4)) = std_logic_vector'("1");

  \c$app_arg_84\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(driveGain)))))))),48);

  \c$bv_21\ <= (x_25.Frame_sel7_fRat);

  driveGain <= resize((to_unsigned(512,12) + (resize((resize((unsigned((\c$bv_21\(23 downto 16)))),12)) * to_unsigned(14,12), 12))),12);

  -- register begin
  ratHighpassPipe_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ratHighpassPipe <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ratHighpassPipe <= result_64;
    end if;
  end process;
  -- register end

  with (ds1_10(875 downto 875)) select
    result_64 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(result_67.Frame_sel0_fL)
                  & std_logic_vector(result_67.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(result_67.Frame_sel2_fLast)
                  & result_67.Frame_sel3_fGate
                  & result_67.Frame_sel4_fOd
                  & result_67.Frame_sel5_fDist
                  & result_67.Frame_sel6_fEq
                  & result_67.Frame_sel7_fRat
                  & result_67.Frame_sel8_fReverb
                  & std_logic_vector(result_67.Frame_sel9_fAddr)
                  & std_logic_vector(result_67.Frame_sel10_fDryL)
                  & std_logic_vector(result_67.Frame_sel11_fDryR)
                  & std_logic_vector(result_67.Frame_sel12_fWetL)
                  & std_logic_vector(result_67.Frame_sel13_fWetR)
                  & std_logic_vector(result_67.Frame_sel14_fFbL)
                  & std_logic_vector(result_67.Frame_sel15_fFbR)
                  & std_logic_vector(result_67.Frame_sel16_fEqLowL)
                  & std_logic_vector(result_67.Frame_sel17_fEqLowR)
                  & std_logic_vector(result_67.Frame_sel18_fEqMidL)
                  & std_logic_vector(result_67.Frame_sel19_fEqMidR)
                  & std_logic_vector(result_67.Frame_sel20_fEqHighL)
                  & std_logic_vector(result_67.Frame_sel21_fEqHighR)
                  & std_logic_vector(result_67.Frame_sel22_fEqHighLpL)
                  & std_logic_vector(result_67.Frame_sel23_fEqHighLpR)
                  & std_logic_vector(result_67.Frame_sel24_fAccL)
                  & std_logic_vector(result_67.Frame_sel25_fAccR)
                  & std_logic_vector(result_67.Frame_sel26_fAcc2L)
                  & std_logic_vector(result_67.Frame_sel27_fAcc2R)
                  & std_logic_vector(result_67.Frame_sel28_fAcc3L)
                  & std_logic_vector(result_67.Frame_sel29_fAcc3R)))) when others;

  x_23 <= ((resize(x_26.Frame_sel0_fL,48)) - (resize(ratHpInPrevL,48))) + (resize((resize(ratHpOutPrevL,48)) * to_signed(0,48), 48));

  \c$case_alt_selection_res_27\ <= x_23 < to_signed(-8388608,48);

  \c$case_alt_31\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_27\ else
                     resize(x_23,24);

  result_selection_res_31 <= x_23 > to_signed(8388607,48);

  result_65 <= to_signed(8388607,24) when result_selection_res_31 else
               \c$case_alt_31\;

  \c$app_arg_85\ <= result_65 when \on_13\ else
                    x_26.Frame_sel0_fL;

  x_24 <= ((resize(x_26.Frame_sel1_fR,48)) - (resize(ratHpInPrevR,48))) + (resize((resize(ratHpOutPrevR,48)) * to_signed(0,48), 48));

  \c$case_alt_selection_res_28\ <= x_24 < to_signed(-8388608,48);

  \c$case_alt_32\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_28\ else
                     resize(x_24,24);

  result_selection_res_32 <= x_24 > to_signed(8388607,48);

  result_66 <= to_signed(8388607,24) when result_selection_res_32 else
               \c$case_alt_32\;

  \c$app_arg_86\ <= result_66 when \on_13\ else
                    x_26.Frame_sel1_fR;

  result_67 <= ( Frame_sel0_fL => x_26.Frame_sel0_fL
               , Frame_sel1_fR => x_26.Frame_sel1_fR
               , Frame_sel2_fLast => x_26.Frame_sel2_fLast
               , Frame_sel3_fGate => x_26.Frame_sel3_fGate
               , Frame_sel4_fOd => x_26.Frame_sel4_fOd
               , Frame_sel5_fDist => x_26.Frame_sel5_fDist
               , Frame_sel6_fEq => x_26.Frame_sel6_fEq
               , Frame_sel7_fRat => x_26.Frame_sel7_fRat
               , Frame_sel8_fReverb => x_26.Frame_sel8_fReverb
               , Frame_sel9_fAddr => x_26.Frame_sel9_fAddr
               , Frame_sel10_fDryL => x_26.Frame_sel0_fL
               , Frame_sel11_fDryR => x_26.Frame_sel1_fR
               , Frame_sel12_fWetL => \c$app_arg_85\
               , Frame_sel13_fWetR => \c$app_arg_86\
               , Frame_sel14_fFbL => x_26.Frame_sel14_fFbL
               , Frame_sel15_fFbR => x_26.Frame_sel15_fFbR
               , Frame_sel16_fEqLowL => x_26.Frame_sel16_fEqLowL
               , Frame_sel17_fEqLowR => x_26.Frame_sel17_fEqLowR
               , Frame_sel18_fEqMidL => x_26.Frame_sel18_fEqMidL
               , Frame_sel19_fEqMidR => x_26.Frame_sel19_fEqMidR
               , Frame_sel20_fEqHighL => x_26.Frame_sel20_fEqHighL
               , Frame_sel21_fEqHighR => x_26.Frame_sel21_fEqHighR
               , Frame_sel22_fEqHighLpL => x_26.Frame_sel22_fEqHighLpL
               , Frame_sel23_fEqHighLpR => x_26.Frame_sel23_fEqHighLpR
               , Frame_sel24_fAccL => x_26.Frame_sel24_fAccL
               , Frame_sel25_fAccR => x_26.Frame_sel25_fAccR
               , Frame_sel26_fAcc2L => x_26.Frame_sel26_fAcc2L
               , Frame_sel27_fAcc2R => x_26.Frame_sel27_fAcc2R
               , Frame_sel28_fAcc3L => x_26.Frame_sel28_fAcc3L
               , Frame_sel29_fAcc3R => x_26.Frame_sel29_fAcc3R );

  \c$bv_22\ <= (x_26.Frame_sel3_fGate);

  \on_13\ <= (\c$bv_22\(4 downto 4)) = std_logic_vector'("1");

  -- register begin
  ratHpOutPrevR_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ratHpOutPrevR <= to_signed(0,24);
    elsif rising_edge(clk) then
      ratHpOutPrevR <= \c$ratHpOutPrevR_app_arg\;
    end if;
  end process;
  -- register end

  with (ratHighpassPipe(875 downto 875)) select
    \c$ratHpOutPrevR_app_arg\ <= ratHpOutPrevR when "0",
                                 x_25.Frame_sel13_fWetR when others;

  -- register begin
  ratHpOutPrevL_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ratHpOutPrevL <= to_signed(0,24);
    elsif rising_edge(clk) then
      ratHpOutPrevL <= \c$ratHpOutPrevL_app_arg\;
    end if;
  end process;
  -- register end

  with (ratHighpassPipe(875 downto 875)) select
    \c$ratHpOutPrevL_app_arg\ <= ratHpOutPrevL when "0",
                                 x_25.Frame_sel12_fWetL when others;

  -- register begin
  ratHpInPrevR_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ratHpInPrevR <= to_signed(0,24);
    elsif rising_edge(clk) then
      ratHpInPrevR <= \c$ratHpInPrevR_app_arg\;
    end if;
  end process;
  -- register end

  with (ratHighpassPipe(875 downto 875)) select
    \c$ratHpInPrevR_app_arg\ <= ratHpInPrevR when "0",
                                x_25.Frame_sel11_fDryR when others;

  -- register begin
  ratHpInPrevL_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ratHpInPrevL <= to_signed(0,24);
    elsif rising_edge(clk) then
      ratHpInPrevL <= \c$ratHpInPrevL_app_arg\;
    end if;
  end process;
  -- register end

  with (ratHighpassPipe(875 downto 875)) select
    \c$ratHpInPrevL_app_arg\ <= ratHpInPrevL when "0",
                                x_25.Frame_sel10_fDryL when others;

  x_25 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ratHighpassPipe(874 downto 0)));

  x_26 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_10(874 downto 0)));

  -- register begin
  ds1_10_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_10 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_10 <= result_68;
    end if;
  end process;
  -- register end

  with (distToneBlendPipe(875 downto 875)) select
    result_68 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(result_69.Frame_sel0_fL)
                  & std_logic_vector(result_69.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(result_69.Frame_sel2_fLast)
                  & result_69.Frame_sel3_fGate
                  & result_69.Frame_sel4_fOd
                  & result_69.Frame_sel5_fDist
                  & result_69.Frame_sel6_fEq
                  & result_69.Frame_sel7_fRat
                  & result_69.Frame_sel8_fReverb
                  & std_logic_vector(result_69.Frame_sel9_fAddr)
                  & std_logic_vector(result_69.Frame_sel10_fDryL)
                  & std_logic_vector(result_69.Frame_sel11_fDryR)
                  & std_logic_vector(result_69.Frame_sel12_fWetL)
                  & std_logic_vector(result_69.Frame_sel13_fWetR)
                  & std_logic_vector(result_69.Frame_sel14_fFbL)
                  & std_logic_vector(result_69.Frame_sel15_fFbR)
                  & std_logic_vector(result_69.Frame_sel16_fEqLowL)
                  & std_logic_vector(result_69.Frame_sel17_fEqLowR)
                  & std_logic_vector(result_69.Frame_sel18_fEqMidL)
                  & std_logic_vector(result_69.Frame_sel19_fEqMidR)
                  & std_logic_vector(result_69.Frame_sel20_fEqHighL)
                  & std_logic_vector(result_69.Frame_sel21_fEqHighR)
                  & std_logic_vector(result_69.Frame_sel22_fEqHighLpL)
                  & std_logic_vector(result_69.Frame_sel23_fEqHighLpR)
                  & std_logic_vector(result_69.Frame_sel24_fAccL)
                  & std_logic_vector(result_69.Frame_sel25_fAccR)
                  & std_logic_vector(result_69.Frame_sel26_fAcc2L)
                  & std_logic_vector(result_69.Frame_sel27_fAcc2R)
                  & std_logic_vector(result_69.Frame_sel28_fAcc3L)
                  & std_logic_vector(result_69.Frame_sel29_fAcc3R)))) when others;

  result_69 <= ( Frame_sel0_fL => \c$app_arg_89\
               , Frame_sel1_fR => \c$app_arg_87\
               , Frame_sel2_fLast => x_28.Frame_sel2_fLast
               , Frame_sel3_fGate => x_28.Frame_sel3_fGate
               , Frame_sel4_fOd => x_28.Frame_sel4_fOd
               , Frame_sel5_fDist => x_28.Frame_sel5_fDist
               , Frame_sel6_fEq => x_28.Frame_sel6_fEq
               , Frame_sel7_fRat => x_28.Frame_sel7_fRat
               , Frame_sel8_fReverb => x_28.Frame_sel8_fReverb
               , Frame_sel9_fAddr => x_28.Frame_sel9_fAddr
               , Frame_sel10_fDryL => x_28.Frame_sel10_fDryL
               , Frame_sel11_fDryR => x_28.Frame_sel11_fDryR
               , Frame_sel12_fWetL => x_28.Frame_sel12_fWetL
               , Frame_sel13_fWetR => x_28.Frame_sel13_fWetR
               , Frame_sel14_fFbL => x_28.Frame_sel14_fFbL
               , Frame_sel15_fFbR => x_28.Frame_sel15_fFbR
               , Frame_sel16_fEqLowL => x_28.Frame_sel16_fEqLowL
               , Frame_sel17_fEqLowR => x_28.Frame_sel17_fEqLowR
               , Frame_sel18_fEqMidL => x_28.Frame_sel18_fEqMidL
               , Frame_sel19_fEqMidR => x_28.Frame_sel19_fEqMidR
               , Frame_sel20_fEqHighL => x_28.Frame_sel20_fEqHighL
               , Frame_sel21_fEqHighR => x_28.Frame_sel21_fEqHighR
               , Frame_sel22_fEqHighLpL => x_28.Frame_sel22_fEqHighLpL
               , Frame_sel23_fEqHighLpR => x_28.Frame_sel23_fEqHighLpR
               , Frame_sel24_fAccL => x_28.Frame_sel24_fAccL
               , Frame_sel25_fAccR => x_28.Frame_sel25_fAccR
               , Frame_sel26_fAcc2L => x_28.Frame_sel26_fAcc2L
               , Frame_sel27_fAcc2R => x_28.Frame_sel27_fAcc2R
               , Frame_sel28_fAcc3L => x_28.Frame_sel28_fAcc3L
               , Frame_sel29_fAcc3R => x_28.Frame_sel29_fAcc3R );

  \c$app_arg_87\ <= result_70 when \on_14\ else
                    x_28.Frame_sel1_fR;

  \c$case_alt_selection_res_29\ <= \c$app_arg_88\ < to_signed(-8388608,48);

  \c$case_alt_33\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_29\ else
                     resize(\c$app_arg_88\,24);

  result_selection_res_33 <= \c$app_arg_88\ > to_signed(8388607,48);

  result_70 <= to_signed(8388607,24) when result_selection_res_33 else
               \c$case_alt_33\;

  \c$shI_31\ <= (to_signed(7,64));

  capp_arg_88_shiftR : block
    signal sh_31 : natural;
  begin
    sh_31 <=
        -- pragma translate_off
        natural'high when (\c$shI_31\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_31\);
    \c$app_arg_88\ <= shift_right((resize((resize(x_28.Frame_sel13_fWetR,48)) * \c$app_arg_91\, 48)),sh_31)
        -- pragma translate_off
        when ((to_signed(7,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_89\ <= result_71 when \on_14\ else
                    x_28.Frame_sel0_fL;

  \c$bv_23\ <= (x_28.Frame_sel3_fGate);

  \on_14\ <= (\c$bv_23\(2 downto 2)) = std_logic_vector'("1");

  \c$case_alt_selection_res_30\ <= \c$app_arg_90\ < to_signed(-8388608,48);

  \c$case_alt_34\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_30\ else
                     resize(\c$app_arg_90\,24);

  result_selection_res_34 <= \c$app_arg_90\ > to_signed(8388607,48);

  result_71 <= to_signed(8388607,24) when result_selection_res_34 else
               \c$case_alt_34\;

  \c$shI_32\ <= (to_signed(7,64));

  capp_arg_90_shiftR : block
    signal sh_32 : natural;
  begin
    sh_32 <=
        -- pragma translate_off
        natural'high when (\c$shI_32\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_32\);
    \c$app_arg_90\ <= shift_right((resize((resize(x_28.Frame_sel12_fWetL,48)) * \c$app_arg_91\, 48)),sh_32)
        -- pragma translate_off
        when ((to_signed(7,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_91\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(level_0)))))))),48);

  \c$bv_24\ <= (x_28.Frame_sel5_fDist);

  level_0 <= unsigned((\c$bv_24\(15 downto 8)));

  -- register begin
  distToneBlendPipe_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      distToneBlendPipe <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      distToneBlendPipe <= result_72;
    end if;
  end process;
  -- register end

  with (ds1_11(875 downto 875)) select
    result_72 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(result_75.Frame_sel0_fL)
                  & std_logic_vector(result_75.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(result_75.Frame_sel2_fLast)
                  & result_75.Frame_sel3_fGate
                  & result_75.Frame_sel4_fOd
                  & result_75.Frame_sel5_fDist
                  & result_75.Frame_sel6_fEq
                  & result_75.Frame_sel7_fRat
                  & result_75.Frame_sel8_fReverb
                  & std_logic_vector(result_75.Frame_sel9_fAddr)
                  & std_logic_vector(result_75.Frame_sel10_fDryL)
                  & std_logic_vector(result_75.Frame_sel11_fDryR)
                  & std_logic_vector(result_75.Frame_sel12_fWetL)
                  & std_logic_vector(result_75.Frame_sel13_fWetR)
                  & std_logic_vector(result_75.Frame_sel14_fFbL)
                  & std_logic_vector(result_75.Frame_sel15_fFbR)
                  & std_logic_vector(result_75.Frame_sel16_fEqLowL)
                  & std_logic_vector(result_75.Frame_sel17_fEqLowR)
                  & std_logic_vector(result_75.Frame_sel18_fEqMidL)
                  & std_logic_vector(result_75.Frame_sel19_fEqMidR)
                  & std_logic_vector(result_75.Frame_sel20_fEqHighL)
                  & std_logic_vector(result_75.Frame_sel21_fEqHighR)
                  & std_logic_vector(result_75.Frame_sel22_fEqHighLpL)
                  & std_logic_vector(result_75.Frame_sel23_fEqHighLpR)
                  & std_logic_vector(result_75.Frame_sel24_fAccL)
                  & std_logic_vector(result_75.Frame_sel25_fAccR)
                  & std_logic_vector(result_75.Frame_sel26_fAcc2L)
                  & std_logic_vector(result_75.Frame_sel27_fAcc2R)
                  & std_logic_vector(result_75.Frame_sel28_fAcc3L)
                  & std_logic_vector(result_75.Frame_sel29_fAcc3R)))) when others;

  \c$shI_33\ <= (to_signed(8,64));

  capp_arg_92_shiftR : block
    signal sh_33 : natural;
  begin
    sh_33 <=
        -- pragma translate_off
        natural'high when (\c$shI_33\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_33\);
    \c$app_arg_92\ <= shift_right((x_27.Frame_sel24_fAccL + x_27.Frame_sel26_fAcc2L),sh_33)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_31\ <= \c$app_arg_92\ < to_signed(-8388608,48);

  \c$case_alt_35\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_31\ else
                     resize(\c$app_arg_92\,24);

  result_selection_res_35 <= \c$app_arg_92\ > to_signed(8388607,48);

  result_73 <= to_signed(8388607,24) when result_selection_res_35 else
               \c$case_alt_35\;

  \c$app_arg_93\ <= result_73 when \on_15\ else
                    x_27.Frame_sel0_fL;

  \c$shI_34\ <= (to_signed(8,64));

  capp_arg_94_shiftR : block
    signal sh_34 : natural;
  begin
    sh_34 <=
        -- pragma translate_off
        natural'high when (\c$shI_34\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_34\);
    \c$app_arg_94\ <= shift_right((x_27.Frame_sel25_fAccR + x_27.Frame_sel27_fAcc2R),sh_34)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_32\ <= \c$app_arg_94\ < to_signed(-8388608,48);

  \c$case_alt_36\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_32\ else
                     resize(\c$app_arg_94\,24);

  result_selection_res_36 <= \c$app_arg_94\ > to_signed(8388607,48);

  result_74 <= to_signed(8388607,24) when result_selection_res_36 else
               \c$case_alt_36\;

  \c$app_arg_95\ <= result_74 when \on_15\ else
                    x_27.Frame_sel1_fR;

  result_75 <= ( Frame_sel0_fL => x_27.Frame_sel0_fL
               , Frame_sel1_fR => x_27.Frame_sel1_fR
               , Frame_sel2_fLast => x_27.Frame_sel2_fLast
               , Frame_sel3_fGate => x_27.Frame_sel3_fGate
               , Frame_sel4_fOd => x_27.Frame_sel4_fOd
               , Frame_sel5_fDist => x_27.Frame_sel5_fDist
               , Frame_sel6_fEq => x_27.Frame_sel6_fEq
               , Frame_sel7_fRat => x_27.Frame_sel7_fRat
               , Frame_sel8_fReverb => x_27.Frame_sel8_fReverb
               , Frame_sel9_fAddr => x_27.Frame_sel9_fAddr
               , Frame_sel10_fDryL => x_27.Frame_sel10_fDryL
               , Frame_sel11_fDryR => x_27.Frame_sel11_fDryR
               , Frame_sel12_fWetL => \c$app_arg_93\
               , Frame_sel13_fWetR => \c$app_arg_95\
               , Frame_sel14_fFbL => x_27.Frame_sel14_fFbL
               , Frame_sel15_fFbR => x_27.Frame_sel15_fFbR
               , Frame_sel16_fEqLowL => x_27.Frame_sel16_fEqLowL
               , Frame_sel17_fEqLowR => x_27.Frame_sel17_fEqLowR
               , Frame_sel18_fEqMidL => x_27.Frame_sel18_fEqMidL
               , Frame_sel19_fEqMidR => x_27.Frame_sel19_fEqMidR
               , Frame_sel20_fEqHighL => x_27.Frame_sel20_fEqHighL
               , Frame_sel21_fEqHighR => x_27.Frame_sel21_fEqHighR
               , Frame_sel22_fEqHighLpL => x_27.Frame_sel22_fEqHighLpL
               , Frame_sel23_fEqHighLpR => x_27.Frame_sel23_fEqHighLpR
               , Frame_sel24_fAccL => x_27.Frame_sel24_fAccL
               , Frame_sel25_fAccR => x_27.Frame_sel25_fAccR
               , Frame_sel26_fAcc2L => x_27.Frame_sel26_fAcc2L
               , Frame_sel27_fAcc2R => x_27.Frame_sel27_fAcc2R
               , Frame_sel28_fAcc3L => x_27.Frame_sel28_fAcc3L
               , Frame_sel29_fAcc3R => x_27.Frame_sel29_fAcc3R );

  \c$bv_25\ <= (x_27.Frame_sel3_fGate);

  \on_15\ <= (\c$bv_25\(2 downto 2)) = std_logic_vector'("1");

  x_27 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_11(874 downto 0)));

  -- register begin
  ds1_11_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_11 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_11 <= result_76;
    end if;
  end process;
  -- register end

  with (ds1_12(875 downto 875)) select
    result_76 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(result_77.Frame_sel0_fL)
                  & std_logic_vector(result_77.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(result_77.Frame_sel2_fLast)
                  & result_77.Frame_sel3_fGate
                  & result_77.Frame_sel4_fOd
                  & result_77.Frame_sel5_fDist
                  & result_77.Frame_sel6_fEq
                  & result_77.Frame_sel7_fRat
                  & result_77.Frame_sel8_fReverb
                  & std_logic_vector(result_77.Frame_sel9_fAddr)
                  & std_logic_vector(result_77.Frame_sel10_fDryL)
                  & std_logic_vector(result_77.Frame_sel11_fDryR)
                  & std_logic_vector(result_77.Frame_sel12_fWetL)
                  & std_logic_vector(result_77.Frame_sel13_fWetR)
                  & std_logic_vector(result_77.Frame_sel14_fFbL)
                  & std_logic_vector(result_77.Frame_sel15_fFbR)
                  & std_logic_vector(result_77.Frame_sel16_fEqLowL)
                  & std_logic_vector(result_77.Frame_sel17_fEqLowR)
                  & std_logic_vector(result_77.Frame_sel18_fEqMidL)
                  & std_logic_vector(result_77.Frame_sel19_fEqMidR)
                  & std_logic_vector(result_77.Frame_sel20_fEqHighL)
                  & std_logic_vector(result_77.Frame_sel21_fEqHighR)
                  & std_logic_vector(result_77.Frame_sel22_fEqHighLpL)
                  & std_logic_vector(result_77.Frame_sel23_fEqHighLpR)
                  & std_logic_vector(result_77.Frame_sel24_fAccL)
                  & std_logic_vector(result_77.Frame_sel25_fAccR)
                  & std_logic_vector(result_77.Frame_sel26_fAcc2L)
                  & std_logic_vector(result_77.Frame_sel27_fAcc2R)
                  & std_logic_vector(result_77.Frame_sel28_fAcc3L)
                  & std_logic_vector(result_77.Frame_sel29_fAcc3R)))) when others;

  result_77 <= ( Frame_sel0_fL => x_29.Frame_sel0_fL
               , Frame_sel1_fR => x_29.Frame_sel1_fR
               , Frame_sel2_fLast => x_29.Frame_sel2_fLast
               , Frame_sel3_fGate => x_29.Frame_sel3_fGate
               , Frame_sel4_fOd => x_29.Frame_sel4_fOd
               , Frame_sel5_fDist => x_29.Frame_sel5_fDist
               , Frame_sel6_fEq => x_29.Frame_sel6_fEq
               , Frame_sel7_fRat => x_29.Frame_sel7_fRat
               , Frame_sel8_fReverb => x_29.Frame_sel8_fReverb
               , Frame_sel9_fAddr => x_29.Frame_sel9_fAddr
               , Frame_sel10_fDryL => x_29.Frame_sel10_fDryL
               , Frame_sel11_fDryR => x_29.Frame_sel11_fDryR
               , Frame_sel12_fWetL => x_29.Frame_sel12_fWetL
               , Frame_sel13_fWetR => x_29.Frame_sel13_fWetR
               , Frame_sel14_fFbL => x_29.Frame_sel14_fFbL
               , Frame_sel15_fFbR => x_29.Frame_sel15_fFbR
               , Frame_sel16_fEqLowL => x_29.Frame_sel16_fEqLowL
               , Frame_sel17_fEqLowR => x_29.Frame_sel17_fEqLowR
               , Frame_sel18_fEqMidL => x_29.Frame_sel18_fEqMidL
               , Frame_sel19_fEqMidR => x_29.Frame_sel19_fEqMidR
               , Frame_sel20_fEqHighL => x_29.Frame_sel20_fEqHighL
               , Frame_sel21_fEqHighR => x_29.Frame_sel21_fEqHighR
               , Frame_sel22_fEqHighLpL => x_29.Frame_sel22_fEqHighLpL
               , Frame_sel23_fEqHighLpR => x_29.Frame_sel23_fEqHighLpR
               , Frame_sel24_fAccL => \c$app_arg_100\
               , Frame_sel25_fAccR => \c$app_arg_99\
               , Frame_sel26_fAcc2L => \c$app_arg_97\
               , Frame_sel27_fAcc2R => \c$app_arg_96\
               , Frame_sel28_fAcc3L => x_29.Frame_sel28_fAcc3L
               , Frame_sel29_fAcc3R => x_29.Frame_sel29_fAcc3R );

  \c$app_arg_96\ <= resize((resize(distTonePrevR,48)) * \c$app_arg_98\, 48) when \on_16\ else
                    to_signed(0,48);

  \c$app_arg_97\ <= resize((resize(distTonePrevL,48)) * \c$app_arg_98\, 48) when \on_16\ else
                    to_signed(0,48);

  \c$app_arg_98\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(toneInv)))))))),48);

  toneInv <= to_unsigned(255,8) - tone;

  \c$app_arg_99\ <= resize((resize(x_29.Frame_sel1_fR,48)) * \c$app_arg_101\, 48) when \on_16\ else
                    to_signed(0,48);

  \c$app_arg_100\ <= resize((resize(x_29.Frame_sel0_fL,48)) * \c$app_arg_101\, 48) when \on_16\ else
                     to_signed(0,48);

  \c$bv_26\ <= (x_29.Frame_sel3_fGate);

  \on_16\ <= (\c$bv_26\(2 downto 2)) = std_logic_vector'("1");

  \c$app_arg_101\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(tone)))))))),48);

  \c$bv_27\ <= (x_29.Frame_sel5_fDist);

  tone <= unsigned((\c$bv_27\(7 downto 0)));

  -- register begin
  distTonePrevR_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      distTonePrevR <= to_signed(0,24);
    elsif rising_edge(clk) then
      distTonePrevR <= \c$distTonePrevR_app_arg\;
    end if;
  end process;
  -- register end

  with (distToneBlendPipe(875 downto 875)) select
    \c$distTonePrevR_app_arg\ <= distTonePrevR when "0",
                                 x_28.Frame_sel13_fWetR when others;

  -- register begin
  distTonePrevL_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      distTonePrevL <= to_signed(0,24);
    elsif rising_edge(clk) then
      distTonePrevL <= \c$distTonePrevL_app_arg\;
    end if;
  end process;
  -- register end

  with (distToneBlendPipe(875 downto 875)) select
    \c$distTonePrevL_app_arg\ <= distTonePrevL when "0",
                                 x_28.Frame_sel12_fWetL when others;

  x_28 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(distToneBlendPipe(874 downto 0)));

  x_29 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_12(874 downto 0)));

  -- register begin
  ds1_12_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_12 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_12 <= result_78;
    end if;
  end process;
  -- register end

  with (ds1_13(875 downto 875)) select
    result_78 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(result_79.Frame_sel0_fL)
                  & std_logic_vector(result_79.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(result_79.Frame_sel2_fLast)
                  & result_79.Frame_sel3_fGate
                  & result_79.Frame_sel4_fOd
                  & result_79.Frame_sel5_fDist
                  & result_79.Frame_sel6_fEq
                  & result_79.Frame_sel7_fRat
                  & result_79.Frame_sel8_fReverb
                  & std_logic_vector(result_79.Frame_sel9_fAddr)
                  & std_logic_vector(result_79.Frame_sel10_fDryL)
                  & std_logic_vector(result_79.Frame_sel11_fDryR)
                  & std_logic_vector(result_79.Frame_sel12_fWetL)
                  & std_logic_vector(result_79.Frame_sel13_fWetR)
                  & std_logic_vector(result_79.Frame_sel14_fFbL)
                  & std_logic_vector(result_79.Frame_sel15_fFbR)
                  & std_logic_vector(result_79.Frame_sel16_fEqLowL)
                  & std_logic_vector(result_79.Frame_sel17_fEqLowR)
                  & std_logic_vector(result_79.Frame_sel18_fEqMidL)
                  & std_logic_vector(result_79.Frame_sel19_fEqMidR)
                  & std_logic_vector(result_79.Frame_sel20_fEqHighL)
                  & std_logic_vector(result_79.Frame_sel21_fEqHighR)
                  & std_logic_vector(result_79.Frame_sel22_fEqHighLpL)
                  & std_logic_vector(result_79.Frame_sel23_fEqHighLpR)
                  & std_logic_vector(result_79.Frame_sel24_fAccL)
                  & std_logic_vector(result_79.Frame_sel25_fAccR)
                  & std_logic_vector(result_79.Frame_sel26_fAcc2L)
                  & std_logic_vector(result_79.Frame_sel27_fAcc2R)
                  & std_logic_vector(result_79.Frame_sel28_fAcc3L)
                  & std_logic_vector(result_79.Frame_sel29_fAcc3R)))) when others;

  threshold_0 <= resize(x_30.Frame_sel26_fAcc2L,24);

  \c$bv_28\ <= (x_30.Frame_sel3_fGate);

  \on_17\ <= (\c$bv_28\(2 downto 2)) = std_logic_vector'("1");

  result_79 <= ( Frame_sel0_fL => \c$app_arg_104\
               , Frame_sel1_fR => \c$app_arg_102\
               , Frame_sel2_fLast => x_30.Frame_sel2_fLast
               , Frame_sel3_fGate => x_30.Frame_sel3_fGate
               , Frame_sel4_fOd => x_30.Frame_sel4_fOd
               , Frame_sel5_fDist => x_30.Frame_sel5_fDist
               , Frame_sel6_fEq => x_30.Frame_sel6_fEq
               , Frame_sel7_fRat => x_30.Frame_sel7_fRat
               , Frame_sel8_fReverb => x_30.Frame_sel8_fReverb
               , Frame_sel9_fAddr => x_30.Frame_sel9_fAddr
               , Frame_sel10_fDryL => x_30.Frame_sel10_fDryL
               , Frame_sel11_fDryR => x_30.Frame_sel11_fDryR
               , Frame_sel12_fWetL => x_30.Frame_sel12_fWetL
               , Frame_sel13_fWetR => x_30.Frame_sel13_fWetR
               , Frame_sel14_fFbL => x_30.Frame_sel14_fFbL
               , Frame_sel15_fFbR => x_30.Frame_sel15_fFbR
               , Frame_sel16_fEqLowL => x_30.Frame_sel16_fEqLowL
               , Frame_sel17_fEqLowR => x_30.Frame_sel17_fEqLowR
               , Frame_sel18_fEqMidL => x_30.Frame_sel18_fEqMidL
               , Frame_sel19_fEqMidR => x_30.Frame_sel19_fEqMidR
               , Frame_sel20_fEqHighL => x_30.Frame_sel20_fEqHighL
               , Frame_sel21_fEqHighR => x_30.Frame_sel21_fEqHighR
               , Frame_sel22_fEqHighLpL => x_30.Frame_sel22_fEqHighLpL
               , Frame_sel23_fEqHighLpR => x_30.Frame_sel23_fEqHighLpR
               , Frame_sel24_fAccL => x_30.Frame_sel24_fAccL
               , Frame_sel25_fAccR => x_30.Frame_sel25_fAccR
               , Frame_sel26_fAcc2L => x_30.Frame_sel26_fAcc2L
               , Frame_sel27_fAcc2R => x_30.Frame_sel27_fAcc2R
               , Frame_sel28_fAcc3L => x_30.Frame_sel28_fAcc3L
               , Frame_sel29_fAcc3R => x_30.Frame_sel29_fAcc3R );

  \c$app_arg_102\ <= result_80 when \on_17\ else
                     x_30.Frame_sel1_fR;

  result_selection_res_37 <= x_30.Frame_sel13_fWetR > threshold_0;

  result_80 <= threshold_0 when result_selection_res_37 else
               \c$case_alt_37\;

  \c$case_alt_selection_res_33\ <= x_30.Frame_sel13_fWetR < \c$app_arg_103\;

  \c$case_alt_37\ <= \c$app_arg_103\ when \c$case_alt_selection_res_33\ else
                     x_30.Frame_sel13_fWetR;

  \c$app_arg_103\ <= -threshold_0;

  \c$app_arg_104\ <= result_81 when \on_17\ else
                     x_30.Frame_sel0_fL;

  result_selection_res_38 <= x_30.Frame_sel12_fWetL > threshold_0;

  result_81 <= threshold_0 when result_selection_res_38 else
               \c$case_alt_38\;

  \c$case_alt_selection_res_34\ <= x_30.Frame_sel12_fWetL < \c$app_arg_105\;

  \c$case_alt_38\ <= \c$app_arg_105\ when \c$case_alt_selection_res_34\ else
                     x_30.Frame_sel12_fWetL;

  \c$app_arg_105\ <= -threshold_0;

  x_30 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_13(874 downto 0)));

  -- register begin
  ds1_13_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_13 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_13 <= result_82;
    end if;
  end process;
  -- register end

  with (ds1_14(875 downto 875)) select
    result_82 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(result_85.Frame_sel0_fL)
                  & std_logic_vector(result_85.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(result_85.Frame_sel2_fLast)
                  & result_85.Frame_sel3_fGate
                  & result_85.Frame_sel4_fOd
                  & result_85.Frame_sel5_fDist
                  & result_85.Frame_sel6_fEq
                  & result_85.Frame_sel7_fRat
                  & result_85.Frame_sel8_fReverb
                  & std_logic_vector(result_85.Frame_sel9_fAddr)
                  & std_logic_vector(result_85.Frame_sel10_fDryL)
                  & std_logic_vector(result_85.Frame_sel11_fDryR)
                  & std_logic_vector(result_85.Frame_sel12_fWetL)
                  & std_logic_vector(result_85.Frame_sel13_fWetR)
                  & std_logic_vector(result_85.Frame_sel14_fFbL)
                  & std_logic_vector(result_85.Frame_sel15_fFbR)
                  & std_logic_vector(result_85.Frame_sel16_fEqLowL)
                  & std_logic_vector(result_85.Frame_sel17_fEqLowR)
                  & std_logic_vector(result_85.Frame_sel18_fEqMidL)
                  & std_logic_vector(result_85.Frame_sel19_fEqMidR)
                  & std_logic_vector(result_85.Frame_sel20_fEqHighL)
                  & std_logic_vector(result_85.Frame_sel21_fEqHighR)
                  & std_logic_vector(result_85.Frame_sel22_fEqHighLpL)
                  & std_logic_vector(result_85.Frame_sel23_fEqHighLpR)
                  & std_logic_vector(result_85.Frame_sel24_fAccL)
                  & std_logic_vector(result_85.Frame_sel25_fAccR)
                  & std_logic_vector(result_85.Frame_sel26_fAcc2L)
                  & std_logic_vector(result_85.Frame_sel27_fAcc2R)
                  & std_logic_vector(result_85.Frame_sel28_fAcc3L)
                  & std_logic_vector(result_85.Frame_sel29_fAcc3R)))) when others;

  \c$shI_35\ <= (to_signed(8,64));

  capp_arg_106_shiftR : block
    signal sh_35 : natural;
  begin
    sh_35 <=
        -- pragma translate_off
        natural'high when (\c$shI_35\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_35\);
    \c$app_arg_106\ <= shift_right(x_31.Frame_sel24_fAccL,sh_35)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_35\ <= \c$app_arg_106\ < to_signed(-8388608,48);

  \c$case_alt_39\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_35\ else
                     resize(\c$app_arg_106\,24);

  result_selection_res_39 <= \c$app_arg_106\ > to_signed(8388607,48);

  result_83 <= to_signed(8388607,24) when result_selection_res_39 else
               \c$case_alt_39\;

  \c$app_arg_107\ <= result_83 when \on_18\ else
                     x_31.Frame_sel0_fL;

  \c$shI_36\ <= (to_signed(8,64));

  capp_arg_108_shiftR : block
    signal sh_36 : natural;
  begin
    sh_36 <=
        -- pragma translate_off
        natural'high when (\c$shI_36\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_36\);
    \c$app_arg_108\ <= shift_right(x_31.Frame_sel25_fAccR,sh_36)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_36\ <= \c$app_arg_108\ < to_signed(-8388608,48);

  \c$case_alt_40\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_36\ else
                     resize(\c$app_arg_108\,24);

  result_selection_res_40 <= \c$app_arg_108\ > to_signed(8388607,48);

  result_84 <= to_signed(8388607,24) when result_selection_res_40 else
               \c$case_alt_40\;

  \c$app_arg_109\ <= result_84 when \on_18\ else
                     x_31.Frame_sel1_fR;

  result_85 <= ( Frame_sel0_fL => x_31.Frame_sel0_fL
               , Frame_sel1_fR => x_31.Frame_sel1_fR
               , Frame_sel2_fLast => x_31.Frame_sel2_fLast
               , Frame_sel3_fGate => x_31.Frame_sel3_fGate
               , Frame_sel4_fOd => x_31.Frame_sel4_fOd
               , Frame_sel5_fDist => x_31.Frame_sel5_fDist
               , Frame_sel6_fEq => x_31.Frame_sel6_fEq
               , Frame_sel7_fRat => x_31.Frame_sel7_fRat
               , Frame_sel8_fReverb => x_31.Frame_sel8_fReverb
               , Frame_sel9_fAddr => x_31.Frame_sel9_fAddr
               , Frame_sel10_fDryL => x_31.Frame_sel10_fDryL
               , Frame_sel11_fDryR => x_31.Frame_sel11_fDryR
               , Frame_sel12_fWetL => \c$app_arg_107\
               , Frame_sel13_fWetR => \c$app_arg_109\
               , Frame_sel14_fFbL => x_31.Frame_sel14_fFbL
               , Frame_sel15_fFbR => x_31.Frame_sel15_fFbR
               , Frame_sel16_fEqLowL => x_31.Frame_sel16_fEqLowL
               , Frame_sel17_fEqLowR => x_31.Frame_sel17_fEqLowR
               , Frame_sel18_fEqMidL => x_31.Frame_sel18_fEqMidL
               , Frame_sel19_fEqMidR => x_31.Frame_sel19_fEqMidR
               , Frame_sel20_fEqHighL => x_31.Frame_sel20_fEqHighL
               , Frame_sel21_fEqHighR => x_31.Frame_sel21_fEqHighR
               , Frame_sel22_fEqHighLpL => x_31.Frame_sel22_fEqHighLpL
               , Frame_sel23_fEqHighLpR => x_31.Frame_sel23_fEqHighLpR
               , Frame_sel24_fAccL => x_31.Frame_sel24_fAccL
               , Frame_sel25_fAccR => x_31.Frame_sel25_fAccR
               , Frame_sel26_fAcc2L => x_31.Frame_sel26_fAcc2L
               , Frame_sel27_fAcc2R => x_31.Frame_sel27_fAcc2R
               , Frame_sel28_fAcc3L => x_31.Frame_sel28_fAcc3L
               , Frame_sel29_fAcc3R => x_31.Frame_sel29_fAcc3R );

  \c$bv_29\ <= (x_31.Frame_sel3_fGate);

  \on_18\ <= (\c$bv_29\(2 downto 2)) = std_logic_vector'("1");

  x_31 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_14(874 downto 0)));

  -- register begin
  ds1_14_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_14 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_14 <= result_86;
    end if;
  end process;
  -- register end

  with (ds1_15(875 downto 875)) select
    result_86 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(result_87.Frame_sel0_fL)
                  & std_logic_vector(result_87.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(result_87.Frame_sel2_fLast)
                  & result_87.Frame_sel3_fGate
                  & result_87.Frame_sel4_fOd
                  & result_87.Frame_sel5_fDist
                  & result_87.Frame_sel6_fEq
                  & result_87.Frame_sel7_fRat
                  & result_87.Frame_sel8_fReverb
                  & std_logic_vector(result_87.Frame_sel9_fAddr)
                  & std_logic_vector(result_87.Frame_sel10_fDryL)
                  & std_logic_vector(result_87.Frame_sel11_fDryR)
                  & std_logic_vector(result_87.Frame_sel12_fWetL)
                  & std_logic_vector(result_87.Frame_sel13_fWetR)
                  & std_logic_vector(result_87.Frame_sel14_fFbL)
                  & std_logic_vector(result_87.Frame_sel15_fFbR)
                  & std_logic_vector(result_87.Frame_sel16_fEqLowL)
                  & std_logic_vector(result_87.Frame_sel17_fEqLowR)
                  & std_logic_vector(result_87.Frame_sel18_fEqMidL)
                  & std_logic_vector(result_87.Frame_sel19_fEqMidR)
                  & std_logic_vector(result_87.Frame_sel20_fEqHighL)
                  & std_logic_vector(result_87.Frame_sel21_fEqHighR)
                  & std_logic_vector(result_87.Frame_sel22_fEqHighLpL)
                  & std_logic_vector(result_87.Frame_sel23_fEqHighLpR)
                  & std_logic_vector(result_87.Frame_sel24_fAccL)
                  & std_logic_vector(result_87.Frame_sel25_fAccR)
                  & std_logic_vector(result_87.Frame_sel26_fAcc2L)
                  & std_logic_vector(result_87.Frame_sel27_fAcc2R)
                  & std_logic_vector(result_87.Frame_sel28_fAcc3L)
                  & std_logic_vector(result_87.Frame_sel29_fAcc3R)))) when others;

  result_87 <= ( Frame_sel0_fL => x_32.Frame_sel0_fL
               , Frame_sel1_fR => x_32.Frame_sel1_fR
               , Frame_sel2_fLast => x_32.Frame_sel2_fLast
               , Frame_sel3_fGate => x_32.Frame_sel3_fGate
               , Frame_sel4_fOd => x_32.Frame_sel4_fOd
               , Frame_sel5_fDist => x_32.Frame_sel5_fDist
               , Frame_sel6_fEq => x_32.Frame_sel6_fEq
               , Frame_sel7_fRat => x_32.Frame_sel7_fRat
               , Frame_sel8_fReverb => x_32.Frame_sel8_fReverb
               , Frame_sel9_fAddr => x_32.Frame_sel9_fAddr
               , Frame_sel10_fDryL => x_32.Frame_sel10_fDryL
               , Frame_sel11_fDryR => x_32.Frame_sel11_fDryR
               , Frame_sel12_fWetL => x_32.Frame_sel12_fWetL
               , Frame_sel13_fWetR => x_32.Frame_sel13_fWetR
               , Frame_sel14_fFbL => x_32.Frame_sel14_fFbL
               , Frame_sel15_fFbR => x_32.Frame_sel15_fFbR
               , Frame_sel16_fEqLowL => x_32.Frame_sel16_fEqLowL
               , Frame_sel17_fEqLowR => x_32.Frame_sel17_fEqLowR
               , Frame_sel18_fEqMidL => x_32.Frame_sel18_fEqMidL
               , Frame_sel19_fEqMidR => x_32.Frame_sel19_fEqMidR
               , Frame_sel20_fEqHighL => x_32.Frame_sel20_fEqHighL
               , Frame_sel21_fEqHighR => x_32.Frame_sel21_fEqHighR
               , Frame_sel22_fEqHighLpL => x_32.Frame_sel22_fEqHighLpL
               , Frame_sel23_fEqHighLpR => x_32.Frame_sel23_fEqHighLpR
               , Frame_sel24_fAccL => \c$app_arg_111\
               , Frame_sel25_fAccR => \c$app_arg_110\
               , Frame_sel26_fAcc2L => resize((resize(result_88,24)),48)
               , Frame_sel27_fAcc2R => x_32.Frame_sel27_fAcc2R
               , Frame_sel28_fAcc3L => x_32.Frame_sel28_fAcc3L
               , Frame_sel29_fAcc3R => x_32.Frame_sel29_fAcc3R );

  result_selection_res_41 <= rawThreshold_0 < to_signed(1800000,25);

  result_88 <= to_signed(1800000,25) when result_selection_res_41 else
               rawThreshold_0;

  rawThreshold_0 <= to_signed(8388607,25) - (resize((resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(amount)))))))),25)) * to_signed(24000,25), 25));

  \c$app_arg_110\ <= resize((resize(x_32.Frame_sel1_fR,48)) * \c$app_arg_112\, 48) when \on_19\ else
                     to_signed(0,48);

  \c$app_arg_111\ <= resize((resize(x_32.Frame_sel0_fL,48)) * \c$app_arg_112\, 48) when \on_19\ else
                     to_signed(0,48);

  \c$bv_30\ <= (x_32.Frame_sel3_fGate);

  \on_19\ <= (\c$bv_30\(2 downto 2)) = std_logic_vector'("1");

  \c$app_arg_112\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(driveGain_0)))))))),48);

  driveGain_0 <= resize((to_unsigned(256,11) + (resize((resize(amount,11)) * to_unsigned(8,11), 11))),12);

  \c$bv_31\ <= (x_32.Frame_sel5_fDist);

  amount <= unsigned((\c$bv_31\(23 downto 16)));

  x_32 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_15(874 downto 0)));

  -- register begin
  ds1_15_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_15 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_15 <= result_89;
    end if;
  end process;
  -- register end

  with (odToneBlendPipe(875 downto 875)) select
    result_89 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(result_90.Frame_sel0_fL)
                  & std_logic_vector(result_90.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(result_90.Frame_sel2_fLast)
                  & result_90.Frame_sel3_fGate
                  & result_90.Frame_sel4_fOd
                  & result_90.Frame_sel5_fDist
                  & result_90.Frame_sel6_fEq
                  & result_90.Frame_sel7_fRat
                  & result_90.Frame_sel8_fReverb
                  & std_logic_vector(result_90.Frame_sel9_fAddr)
                  & std_logic_vector(result_90.Frame_sel10_fDryL)
                  & std_logic_vector(result_90.Frame_sel11_fDryR)
                  & std_logic_vector(result_90.Frame_sel12_fWetL)
                  & std_logic_vector(result_90.Frame_sel13_fWetR)
                  & std_logic_vector(result_90.Frame_sel14_fFbL)
                  & std_logic_vector(result_90.Frame_sel15_fFbR)
                  & std_logic_vector(result_90.Frame_sel16_fEqLowL)
                  & std_logic_vector(result_90.Frame_sel17_fEqLowR)
                  & std_logic_vector(result_90.Frame_sel18_fEqMidL)
                  & std_logic_vector(result_90.Frame_sel19_fEqMidR)
                  & std_logic_vector(result_90.Frame_sel20_fEqHighL)
                  & std_logic_vector(result_90.Frame_sel21_fEqHighR)
                  & std_logic_vector(result_90.Frame_sel22_fEqHighLpL)
                  & std_logic_vector(result_90.Frame_sel23_fEqHighLpR)
                  & std_logic_vector(result_90.Frame_sel24_fAccL)
                  & std_logic_vector(result_90.Frame_sel25_fAccR)
                  & std_logic_vector(result_90.Frame_sel26_fAcc2L)
                  & std_logic_vector(result_90.Frame_sel27_fAcc2R)
                  & std_logic_vector(result_90.Frame_sel28_fAcc3L)
                  & std_logic_vector(result_90.Frame_sel29_fAcc3R)))) when others;

  result_90 <= ( Frame_sel0_fL => \c$app_arg_115\
               , Frame_sel1_fR => \c$app_arg_113\
               , Frame_sel2_fLast => x_34.Frame_sel2_fLast
               , Frame_sel3_fGate => x_34.Frame_sel3_fGate
               , Frame_sel4_fOd => x_34.Frame_sel4_fOd
               , Frame_sel5_fDist => x_34.Frame_sel5_fDist
               , Frame_sel6_fEq => x_34.Frame_sel6_fEq
               , Frame_sel7_fRat => x_34.Frame_sel7_fRat
               , Frame_sel8_fReverb => x_34.Frame_sel8_fReverb
               , Frame_sel9_fAddr => x_34.Frame_sel9_fAddr
               , Frame_sel10_fDryL => x_34.Frame_sel10_fDryL
               , Frame_sel11_fDryR => x_34.Frame_sel11_fDryR
               , Frame_sel12_fWetL => x_34.Frame_sel12_fWetL
               , Frame_sel13_fWetR => x_34.Frame_sel13_fWetR
               , Frame_sel14_fFbL => x_34.Frame_sel14_fFbL
               , Frame_sel15_fFbR => x_34.Frame_sel15_fFbR
               , Frame_sel16_fEqLowL => x_34.Frame_sel16_fEqLowL
               , Frame_sel17_fEqLowR => x_34.Frame_sel17_fEqLowR
               , Frame_sel18_fEqMidL => x_34.Frame_sel18_fEqMidL
               , Frame_sel19_fEqMidR => x_34.Frame_sel19_fEqMidR
               , Frame_sel20_fEqHighL => x_34.Frame_sel20_fEqHighL
               , Frame_sel21_fEqHighR => x_34.Frame_sel21_fEqHighR
               , Frame_sel22_fEqHighLpL => x_34.Frame_sel22_fEqHighLpL
               , Frame_sel23_fEqHighLpR => x_34.Frame_sel23_fEqHighLpR
               , Frame_sel24_fAccL => x_34.Frame_sel24_fAccL
               , Frame_sel25_fAccR => x_34.Frame_sel25_fAccR
               , Frame_sel26_fAcc2L => x_34.Frame_sel26_fAcc2L
               , Frame_sel27_fAcc2R => x_34.Frame_sel27_fAcc2R
               , Frame_sel28_fAcc3L => x_34.Frame_sel28_fAcc3L
               , Frame_sel29_fAcc3R => x_34.Frame_sel29_fAcc3R );

  \c$app_arg_113\ <= result_91 when \on_20\ else
                     x_34.Frame_sel1_fR;

  \c$case_alt_selection_res_37\ <= \c$app_arg_114\ < to_signed(-8388608,48);

  \c$case_alt_41\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_37\ else
                     resize(\c$app_arg_114\,24);

  result_selection_res_42 <= \c$app_arg_114\ > to_signed(8388607,48);

  result_91 <= to_signed(8388607,24) when result_selection_res_42 else
               \c$case_alt_41\;

  \c$shI_37\ <= (to_signed(7,64));

  capp_arg_114_shiftR : block
    signal sh_37 : natural;
  begin
    sh_37 <=
        -- pragma translate_off
        natural'high when (\c$shI_37\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_37\);
    \c$app_arg_114\ <= shift_right((resize((resize(x_34.Frame_sel13_fWetR,48)) * \c$app_arg_117\, 48)),sh_37)
        -- pragma translate_off
        when ((to_signed(7,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_115\ <= result_92 when \on_20\ else
                     x_34.Frame_sel0_fL;

  \c$bv_32\ <= (x_34.Frame_sel3_fGate);

  \on_20\ <= (\c$bv_32\(1 downto 1)) = std_logic_vector'("1");

  \c$case_alt_selection_res_38\ <= \c$app_arg_116\ < to_signed(-8388608,48);

  \c$case_alt_42\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_38\ else
                     resize(\c$app_arg_116\,24);

  result_selection_res_43 <= \c$app_arg_116\ > to_signed(8388607,48);

  result_92 <= to_signed(8388607,24) when result_selection_res_43 else
               \c$case_alt_42\;

  \c$shI_38\ <= (to_signed(7,64));

  capp_arg_116_shiftR : block
    signal sh_38 : natural;
  begin
    sh_38 <=
        -- pragma translate_off
        natural'high when (\c$shI_38\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_38\);
    \c$app_arg_116\ <= shift_right((resize((resize(x_34.Frame_sel12_fWetL,48)) * \c$app_arg_117\, 48)),sh_38)
        -- pragma translate_off
        when ((to_signed(7,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_117\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(level_1)))))))),48);

  \c$bv_33\ <= (x_34.Frame_sel4_fOd);

  level_1 <= unsigned((\c$bv_33\(15 downto 8)));

  -- register begin
  odToneBlendPipe_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      odToneBlendPipe <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      odToneBlendPipe <= result_93;
    end if;
  end process;
  -- register end

  with (ds1_16(875 downto 875)) select
    result_93 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(result_96.Frame_sel0_fL)
                  & std_logic_vector(result_96.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(result_96.Frame_sel2_fLast)
                  & result_96.Frame_sel3_fGate
                  & result_96.Frame_sel4_fOd
                  & result_96.Frame_sel5_fDist
                  & result_96.Frame_sel6_fEq
                  & result_96.Frame_sel7_fRat
                  & result_96.Frame_sel8_fReverb
                  & std_logic_vector(result_96.Frame_sel9_fAddr)
                  & std_logic_vector(result_96.Frame_sel10_fDryL)
                  & std_logic_vector(result_96.Frame_sel11_fDryR)
                  & std_logic_vector(result_96.Frame_sel12_fWetL)
                  & std_logic_vector(result_96.Frame_sel13_fWetR)
                  & std_logic_vector(result_96.Frame_sel14_fFbL)
                  & std_logic_vector(result_96.Frame_sel15_fFbR)
                  & std_logic_vector(result_96.Frame_sel16_fEqLowL)
                  & std_logic_vector(result_96.Frame_sel17_fEqLowR)
                  & std_logic_vector(result_96.Frame_sel18_fEqMidL)
                  & std_logic_vector(result_96.Frame_sel19_fEqMidR)
                  & std_logic_vector(result_96.Frame_sel20_fEqHighL)
                  & std_logic_vector(result_96.Frame_sel21_fEqHighR)
                  & std_logic_vector(result_96.Frame_sel22_fEqHighLpL)
                  & std_logic_vector(result_96.Frame_sel23_fEqHighLpR)
                  & std_logic_vector(result_96.Frame_sel24_fAccL)
                  & std_logic_vector(result_96.Frame_sel25_fAccR)
                  & std_logic_vector(result_96.Frame_sel26_fAcc2L)
                  & std_logic_vector(result_96.Frame_sel27_fAcc2R)
                  & std_logic_vector(result_96.Frame_sel28_fAcc3L)
                  & std_logic_vector(result_96.Frame_sel29_fAcc3R)))) when others;

  \c$shI_39\ <= (to_signed(8,64));

  capp_arg_118_shiftR : block
    signal sh_39 : natural;
  begin
    sh_39 <=
        -- pragma translate_off
        natural'high when (\c$shI_39\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_39\);
    \c$app_arg_118\ <= shift_right((x_33.Frame_sel24_fAccL + x_33.Frame_sel26_fAcc2L),sh_39)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_39\ <= \c$app_arg_118\ < to_signed(-8388608,48);

  \c$case_alt_43\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_39\ else
                     resize(\c$app_arg_118\,24);

  result_selection_res_44 <= \c$app_arg_118\ > to_signed(8388607,48);

  result_94 <= to_signed(8388607,24) when result_selection_res_44 else
               \c$case_alt_43\;

  \c$app_arg_119\ <= result_94 when \on_21\ else
                     x_33.Frame_sel0_fL;

  \c$shI_40\ <= (to_signed(8,64));

  capp_arg_120_shiftR : block
    signal sh_40 : natural;
  begin
    sh_40 <=
        -- pragma translate_off
        natural'high when (\c$shI_40\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_40\);
    \c$app_arg_120\ <= shift_right((x_33.Frame_sel25_fAccR + x_33.Frame_sel27_fAcc2R),sh_40)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_40\ <= \c$app_arg_120\ < to_signed(-8388608,48);

  \c$case_alt_44\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_40\ else
                     resize(\c$app_arg_120\,24);

  result_selection_res_45 <= \c$app_arg_120\ > to_signed(8388607,48);

  result_95 <= to_signed(8388607,24) when result_selection_res_45 else
               \c$case_alt_44\;

  \c$app_arg_121\ <= result_95 when \on_21\ else
                     x_33.Frame_sel1_fR;

  result_96 <= ( Frame_sel0_fL => x_33.Frame_sel0_fL
               , Frame_sel1_fR => x_33.Frame_sel1_fR
               , Frame_sel2_fLast => x_33.Frame_sel2_fLast
               , Frame_sel3_fGate => x_33.Frame_sel3_fGate
               , Frame_sel4_fOd => x_33.Frame_sel4_fOd
               , Frame_sel5_fDist => x_33.Frame_sel5_fDist
               , Frame_sel6_fEq => x_33.Frame_sel6_fEq
               , Frame_sel7_fRat => x_33.Frame_sel7_fRat
               , Frame_sel8_fReverb => x_33.Frame_sel8_fReverb
               , Frame_sel9_fAddr => x_33.Frame_sel9_fAddr
               , Frame_sel10_fDryL => x_33.Frame_sel10_fDryL
               , Frame_sel11_fDryR => x_33.Frame_sel11_fDryR
               , Frame_sel12_fWetL => \c$app_arg_119\
               , Frame_sel13_fWetR => \c$app_arg_121\
               , Frame_sel14_fFbL => x_33.Frame_sel14_fFbL
               , Frame_sel15_fFbR => x_33.Frame_sel15_fFbR
               , Frame_sel16_fEqLowL => x_33.Frame_sel16_fEqLowL
               , Frame_sel17_fEqLowR => x_33.Frame_sel17_fEqLowR
               , Frame_sel18_fEqMidL => x_33.Frame_sel18_fEqMidL
               , Frame_sel19_fEqMidR => x_33.Frame_sel19_fEqMidR
               , Frame_sel20_fEqHighL => x_33.Frame_sel20_fEqHighL
               , Frame_sel21_fEqHighR => x_33.Frame_sel21_fEqHighR
               , Frame_sel22_fEqHighLpL => x_33.Frame_sel22_fEqHighLpL
               , Frame_sel23_fEqHighLpR => x_33.Frame_sel23_fEqHighLpR
               , Frame_sel24_fAccL => x_33.Frame_sel24_fAccL
               , Frame_sel25_fAccR => x_33.Frame_sel25_fAccR
               , Frame_sel26_fAcc2L => x_33.Frame_sel26_fAcc2L
               , Frame_sel27_fAcc2R => x_33.Frame_sel27_fAcc2R
               , Frame_sel28_fAcc3L => x_33.Frame_sel28_fAcc3L
               , Frame_sel29_fAcc3R => x_33.Frame_sel29_fAcc3R );

  \c$bv_34\ <= (x_33.Frame_sel3_fGate);

  \on_21\ <= (\c$bv_34\(1 downto 1)) = std_logic_vector'("1");

  x_33 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_16(874 downto 0)));

  -- register begin
  ds1_16_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_16 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_16 <= result_97;
    end if;
  end process;
  -- register end

  with (ds1_17(875 downto 875)) select
    result_97 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(result_98.Frame_sel0_fL)
                  & std_logic_vector(result_98.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(result_98.Frame_sel2_fLast)
                  & result_98.Frame_sel3_fGate
                  & result_98.Frame_sel4_fOd
                  & result_98.Frame_sel5_fDist
                  & result_98.Frame_sel6_fEq
                  & result_98.Frame_sel7_fRat
                  & result_98.Frame_sel8_fReverb
                  & std_logic_vector(result_98.Frame_sel9_fAddr)
                  & std_logic_vector(result_98.Frame_sel10_fDryL)
                  & std_logic_vector(result_98.Frame_sel11_fDryR)
                  & std_logic_vector(result_98.Frame_sel12_fWetL)
                  & std_logic_vector(result_98.Frame_sel13_fWetR)
                  & std_logic_vector(result_98.Frame_sel14_fFbL)
                  & std_logic_vector(result_98.Frame_sel15_fFbR)
                  & std_logic_vector(result_98.Frame_sel16_fEqLowL)
                  & std_logic_vector(result_98.Frame_sel17_fEqLowR)
                  & std_logic_vector(result_98.Frame_sel18_fEqMidL)
                  & std_logic_vector(result_98.Frame_sel19_fEqMidR)
                  & std_logic_vector(result_98.Frame_sel20_fEqHighL)
                  & std_logic_vector(result_98.Frame_sel21_fEqHighR)
                  & std_logic_vector(result_98.Frame_sel22_fEqHighLpL)
                  & std_logic_vector(result_98.Frame_sel23_fEqHighLpR)
                  & std_logic_vector(result_98.Frame_sel24_fAccL)
                  & std_logic_vector(result_98.Frame_sel25_fAccR)
                  & std_logic_vector(result_98.Frame_sel26_fAcc2L)
                  & std_logic_vector(result_98.Frame_sel27_fAcc2R)
                  & std_logic_vector(result_98.Frame_sel28_fAcc3L)
                  & std_logic_vector(result_98.Frame_sel29_fAcc3R)))) when others;

  result_98 <= ( Frame_sel0_fL => x_35.Frame_sel0_fL
               , Frame_sel1_fR => x_35.Frame_sel1_fR
               , Frame_sel2_fLast => x_35.Frame_sel2_fLast
               , Frame_sel3_fGate => x_35.Frame_sel3_fGate
               , Frame_sel4_fOd => x_35.Frame_sel4_fOd
               , Frame_sel5_fDist => x_35.Frame_sel5_fDist
               , Frame_sel6_fEq => x_35.Frame_sel6_fEq
               , Frame_sel7_fRat => x_35.Frame_sel7_fRat
               , Frame_sel8_fReverb => x_35.Frame_sel8_fReverb
               , Frame_sel9_fAddr => x_35.Frame_sel9_fAddr
               , Frame_sel10_fDryL => x_35.Frame_sel10_fDryL
               , Frame_sel11_fDryR => x_35.Frame_sel11_fDryR
               , Frame_sel12_fWetL => x_35.Frame_sel12_fWetL
               , Frame_sel13_fWetR => x_35.Frame_sel13_fWetR
               , Frame_sel14_fFbL => x_35.Frame_sel14_fFbL
               , Frame_sel15_fFbR => x_35.Frame_sel15_fFbR
               , Frame_sel16_fEqLowL => x_35.Frame_sel16_fEqLowL
               , Frame_sel17_fEqLowR => x_35.Frame_sel17_fEqLowR
               , Frame_sel18_fEqMidL => x_35.Frame_sel18_fEqMidL
               , Frame_sel19_fEqMidR => x_35.Frame_sel19_fEqMidR
               , Frame_sel20_fEqHighL => x_35.Frame_sel20_fEqHighL
               , Frame_sel21_fEqHighR => x_35.Frame_sel21_fEqHighR
               , Frame_sel22_fEqHighLpL => x_35.Frame_sel22_fEqHighLpL
               , Frame_sel23_fEqHighLpR => x_35.Frame_sel23_fEqHighLpR
               , Frame_sel24_fAccL => \c$app_arg_126\
               , Frame_sel25_fAccR => \c$app_arg_125\
               , Frame_sel26_fAcc2L => \c$app_arg_123\
               , Frame_sel27_fAcc2R => \c$app_arg_122\
               , Frame_sel28_fAcc3L => x_35.Frame_sel28_fAcc3L
               , Frame_sel29_fAcc3R => x_35.Frame_sel29_fAcc3R );

  \c$app_arg_122\ <= resize((resize(odTonePrevR,48)) * \c$app_arg_124\, 48) when \on_22\ else
                     to_signed(0,48);

  \c$app_arg_123\ <= resize((resize(odTonePrevL,48)) * \c$app_arg_124\, 48) when \on_22\ else
                     to_signed(0,48);

  \c$app_arg_124\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(toneInv_0)))))))),48);

  toneInv_0 <= to_unsigned(255,8) - tone_0;

  \c$app_arg_125\ <= resize((resize(x_35.Frame_sel1_fR,48)) * \c$app_arg_127\, 48) when \on_22\ else
                     to_signed(0,48);

  \c$app_arg_126\ <= resize((resize(x_35.Frame_sel0_fL,48)) * \c$app_arg_127\, 48) when \on_22\ else
                     to_signed(0,48);

  \c$bv_35\ <= (x_35.Frame_sel3_fGate);

  \on_22\ <= (\c$bv_35\(1 downto 1)) = std_logic_vector'("1");

  \c$app_arg_127\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(tone_0)))))))),48);

  \c$bv_36\ <= (x_35.Frame_sel4_fOd);

  tone_0 <= unsigned((\c$bv_36\(7 downto 0)));

  -- register begin
  odTonePrevR_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      odTonePrevR <= to_signed(0,24);
    elsif rising_edge(clk) then
      odTonePrevR <= \c$odTonePrevR_app_arg\;
    end if;
  end process;
  -- register end

  with (odToneBlendPipe(875 downto 875)) select
    \c$odTonePrevR_app_arg\ <= odTonePrevR when "0",
                               x_34.Frame_sel13_fWetR when others;

  -- register begin
  odTonePrevL_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      odTonePrevL <= to_signed(0,24);
    elsif rising_edge(clk) then
      odTonePrevL <= \c$odTonePrevL_app_arg\;
    end if;
  end process;
  -- register end

  with (odToneBlendPipe(875 downto 875)) select
    \c$odTonePrevL_app_arg\ <= odTonePrevL when "0",
                               x_34.Frame_sel12_fWetL when others;

  x_34 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(odToneBlendPipe(874 downto 0)));

  x_35 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_17(874 downto 0)));

  -- register begin
  ds1_17_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_17 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_17 <= result_99;
    end if;
  end process;
  -- register end

  with (ds1_18(875 downto 875)) select
    result_99 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(result_100.Frame_sel0_fL)
                  & std_logic_vector(result_100.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(result_100.Frame_sel2_fLast)
                  & result_100.Frame_sel3_fGate
                  & result_100.Frame_sel4_fOd
                  & result_100.Frame_sel5_fDist
                  & result_100.Frame_sel6_fEq
                  & result_100.Frame_sel7_fRat
                  & result_100.Frame_sel8_fReverb
                  & std_logic_vector(result_100.Frame_sel9_fAddr)
                  & std_logic_vector(result_100.Frame_sel10_fDryL)
                  & std_logic_vector(result_100.Frame_sel11_fDryR)
                  & std_logic_vector(result_100.Frame_sel12_fWetL)
                  & std_logic_vector(result_100.Frame_sel13_fWetR)
                  & std_logic_vector(result_100.Frame_sel14_fFbL)
                  & std_logic_vector(result_100.Frame_sel15_fFbR)
                  & std_logic_vector(result_100.Frame_sel16_fEqLowL)
                  & std_logic_vector(result_100.Frame_sel17_fEqLowR)
                  & std_logic_vector(result_100.Frame_sel18_fEqMidL)
                  & std_logic_vector(result_100.Frame_sel19_fEqMidR)
                  & std_logic_vector(result_100.Frame_sel20_fEqHighL)
                  & std_logic_vector(result_100.Frame_sel21_fEqHighR)
                  & std_logic_vector(result_100.Frame_sel22_fEqHighLpL)
                  & std_logic_vector(result_100.Frame_sel23_fEqHighLpR)
                  & std_logic_vector(result_100.Frame_sel24_fAccL)
                  & std_logic_vector(result_100.Frame_sel25_fAccR)
                  & std_logic_vector(result_100.Frame_sel26_fAcc2L)
                  & std_logic_vector(result_100.Frame_sel27_fAcc2R)
                  & std_logic_vector(result_100.Frame_sel28_fAcc3L)
                  & std_logic_vector(result_100.Frame_sel29_fAcc3R)))) when others;

  \c$bv_37\ <= (x_36.Frame_sel3_fGate);

  \on_23\ <= (\c$bv_37\(1 downto 1)) = std_logic_vector'("1");

  result_100 <= ( Frame_sel0_fL => \c$app_arg_132\
                , Frame_sel1_fR => \c$app_arg_128\
                , Frame_sel2_fLast => x_36.Frame_sel2_fLast
                , Frame_sel3_fGate => x_36.Frame_sel3_fGate
                , Frame_sel4_fOd => x_36.Frame_sel4_fOd
                , Frame_sel5_fDist => x_36.Frame_sel5_fDist
                , Frame_sel6_fEq => x_36.Frame_sel6_fEq
                , Frame_sel7_fRat => x_36.Frame_sel7_fRat
                , Frame_sel8_fReverb => x_36.Frame_sel8_fReverb
                , Frame_sel9_fAddr => x_36.Frame_sel9_fAddr
                , Frame_sel10_fDryL => x_36.Frame_sel10_fDryL
                , Frame_sel11_fDryR => x_36.Frame_sel11_fDryR
                , Frame_sel12_fWetL => x_36.Frame_sel12_fWetL
                , Frame_sel13_fWetR => x_36.Frame_sel13_fWetR
                , Frame_sel14_fFbL => x_36.Frame_sel14_fFbL
                , Frame_sel15_fFbR => x_36.Frame_sel15_fFbR
                , Frame_sel16_fEqLowL => x_36.Frame_sel16_fEqLowL
                , Frame_sel17_fEqLowR => x_36.Frame_sel17_fEqLowR
                , Frame_sel18_fEqMidL => x_36.Frame_sel18_fEqMidL
                , Frame_sel19_fEqMidR => x_36.Frame_sel19_fEqMidR
                , Frame_sel20_fEqHighL => x_36.Frame_sel20_fEqHighL
                , Frame_sel21_fEqHighR => x_36.Frame_sel21_fEqHighR
                , Frame_sel22_fEqHighLpL => x_36.Frame_sel22_fEqHighLpL
                , Frame_sel23_fEqHighLpR => x_36.Frame_sel23_fEqHighLpR
                , Frame_sel24_fAccL => x_36.Frame_sel24_fAccL
                , Frame_sel25_fAccR => x_36.Frame_sel25_fAccR
                , Frame_sel26_fAcc2L => x_36.Frame_sel26_fAcc2L
                , Frame_sel27_fAcc2R => x_36.Frame_sel27_fAcc2R
                , Frame_sel28_fAcc3L => x_36.Frame_sel28_fAcc3L
                , Frame_sel29_fAcc3R => x_36.Frame_sel29_fAcc3R );

  \c$app_arg_128\ <= result_101 when \on_23\ else
                     x_36.Frame_sel1_fR;

  result_selection_res_46 <= x_36.Frame_sel13_fWetR > to_signed(4194304,24);

  result_101 <= resize((to_signed(4194304,25) + \c$app_arg_129\),24) when result_selection_res_46 else
                \c$case_alt_45\;

  \c$case_alt_selection_res_41\ <= x_36.Frame_sel13_fWetR < to_signed(-4194304,24);

  \c$case_alt_45\ <= resize((to_signed(-4194304,25) + \c$app_arg_130\),24) when \c$case_alt_selection_res_41\ else
                     x_36.Frame_sel13_fWetR;

  \c$shI_41\ <= (to_signed(2,64));

  capp_arg_129_shiftR : block
    signal sh_41 : natural;
  begin
    sh_41 <=
        -- pragma translate_off
        natural'high when (\c$shI_41\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_41\);
    \c$app_arg_129\ <= shift_right((\c$app_arg_131\ - to_signed(4194304,25)),sh_41)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$shI_42\ <= (to_signed(2,64));

  capp_arg_130_shiftR : block
    signal sh_42 : natural;
  begin
    sh_42 <=
        -- pragma translate_off
        natural'high when (\c$shI_42\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_42\);
    \c$app_arg_130\ <= shift_right((\c$app_arg_131\ + to_signed(4194304,25)),sh_42)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_131\ <= resize(x_36.Frame_sel13_fWetR,25);

  \c$app_arg_132\ <= result_102 when \on_23\ else
                     x_36.Frame_sel0_fL;

  result_selection_res_47 <= x_36.Frame_sel12_fWetL > to_signed(4194304,24);

  result_102 <= resize((to_signed(4194304,25) + \c$app_arg_133\),24) when result_selection_res_47 else
                \c$case_alt_46\;

  \c$case_alt_selection_res_42\ <= x_36.Frame_sel12_fWetL < to_signed(-4194304,24);

  \c$case_alt_46\ <= resize((to_signed(-4194304,25) + \c$app_arg_134\),24) when \c$case_alt_selection_res_42\ else
                     x_36.Frame_sel12_fWetL;

  \c$shI_43\ <= (to_signed(2,64));

  capp_arg_133_shiftR : block
    signal sh_43 : natural;
  begin
    sh_43 <=
        -- pragma translate_off
        natural'high when (\c$shI_43\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_43\);
    \c$app_arg_133\ <= shift_right((\c$app_arg_135\ - to_signed(4194304,25)),sh_43)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$shI_44\ <= (to_signed(2,64));

  capp_arg_134_shiftR : block
    signal sh_44 : natural;
  begin
    sh_44 <=
        -- pragma translate_off
        natural'high when (\c$shI_44\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_44\);
    \c$app_arg_134\ <= shift_right((\c$app_arg_135\ + to_signed(4194304,25)),sh_44)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_135\ <= resize(x_36.Frame_sel12_fWetL,25);

  x_36 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_18(874 downto 0)));

  -- register begin
  ds1_18_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_18 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_18 <= result_103;
    end if;
  end process;
  -- register end

  with (ds1_19(875 downto 875)) select
    result_103 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                  std_logic_vector'("1" & ((std_logic_vector(result_106.Frame_sel0_fL)
                   & std_logic_vector(result_106.Frame_sel1_fR)
                   & clash_lowpass_fir_types.toSLV(result_106.Frame_sel2_fLast)
                   & result_106.Frame_sel3_fGate
                   & result_106.Frame_sel4_fOd
                   & result_106.Frame_sel5_fDist
                   & result_106.Frame_sel6_fEq
                   & result_106.Frame_sel7_fRat
                   & result_106.Frame_sel8_fReverb
                   & std_logic_vector(result_106.Frame_sel9_fAddr)
                   & std_logic_vector(result_106.Frame_sel10_fDryL)
                   & std_logic_vector(result_106.Frame_sel11_fDryR)
                   & std_logic_vector(result_106.Frame_sel12_fWetL)
                   & std_logic_vector(result_106.Frame_sel13_fWetR)
                   & std_logic_vector(result_106.Frame_sel14_fFbL)
                   & std_logic_vector(result_106.Frame_sel15_fFbR)
                   & std_logic_vector(result_106.Frame_sel16_fEqLowL)
                   & std_logic_vector(result_106.Frame_sel17_fEqLowR)
                   & std_logic_vector(result_106.Frame_sel18_fEqMidL)
                   & std_logic_vector(result_106.Frame_sel19_fEqMidR)
                   & std_logic_vector(result_106.Frame_sel20_fEqHighL)
                   & std_logic_vector(result_106.Frame_sel21_fEqHighR)
                   & std_logic_vector(result_106.Frame_sel22_fEqHighLpL)
                   & std_logic_vector(result_106.Frame_sel23_fEqHighLpR)
                   & std_logic_vector(result_106.Frame_sel24_fAccL)
                   & std_logic_vector(result_106.Frame_sel25_fAccR)
                   & std_logic_vector(result_106.Frame_sel26_fAcc2L)
                   & std_logic_vector(result_106.Frame_sel27_fAcc2R)
                   & std_logic_vector(result_106.Frame_sel28_fAcc3L)
                   & std_logic_vector(result_106.Frame_sel29_fAcc3R)))) when others;

  \c$shI_45\ <= (to_signed(8,64));

  capp_arg_136_shiftR : block
    signal sh_45 : natural;
  begin
    sh_45 <=
        -- pragma translate_off
        natural'high when (\c$shI_45\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_45\);
    \c$app_arg_136\ <= shift_right(x_37.Frame_sel24_fAccL,sh_45)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_43\ <= \c$app_arg_136\ < to_signed(-8388608,48);

  \c$case_alt_47\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_43\ else
                     resize(\c$app_arg_136\,24);

  result_selection_res_48 <= \c$app_arg_136\ > to_signed(8388607,48);

  result_104 <= to_signed(8388607,24) when result_selection_res_48 else
                \c$case_alt_47\;

  \c$app_arg_137\ <= result_104 when \on_24\ else
                     x_37.Frame_sel0_fL;

  \c$shI_46\ <= (to_signed(8,64));

  capp_arg_138_shiftR : block
    signal sh_46 : natural;
  begin
    sh_46 <=
        -- pragma translate_off
        natural'high when (\c$shI_46\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_46\);
    \c$app_arg_138\ <= shift_right(x_37.Frame_sel25_fAccR,sh_46)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_44\ <= \c$app_arg_138\ < to_signed(-8388608,48);

  \c$case_alt_48\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_44\ else
                     resize(\c$app_arg_138\,24);

  result_selection_res_49 <= \c$app_arg_138\ > to_signed(8388607,48);

  result_105 <= to_signed(8388607,24) when result_selection_res_49 else
                \c$case_alt_48\;

  \c$app_arg_139\ <= result_105 when \on_24\ else
                     x_37.Frame_sel1_fR;

  result_106 <= ( Frame_sel0_fL => x_37.Frame_sel0_fL
                , Frame_sel1_fR => x_37.Frame_sel1_fR
                , Frame_sel2_fLast => x_37.Frame_sel2_fLast
                , Frame_sel3_fGate => x_37.Frame_sel3_fGate
                , Frame_sel4_fOd => x_37.Frame_sel4_fOd
                , Frame_sel5_fDist => x_37.Frame_sel5_fDist
                , Frame_sel6_fEq => x_37.Frame_sel6_fEq
                , Frame_sel7_fRat => x_37.Frame_sel7_fRat
                , Frame_sel8_fReverb => x_37.Frame_sel8_fReverb
                , Frame_sel9_fAddr => x_37.Frame_sel9_fAddr
                , Frame_sel10_fDryL => x_37.Frame_sel10_fDryL
                , Frame_sel11_fDryR => x_37.Frame_sel11_fDryR
                , Frame_sel12_fWetL => \c$app_arg_137\
                , Frame_sel13_fWetR => \c$app_arg_139\
                , Frame_sel14_fFbL => x_37.Frame_sel14_fFbL
                , Frame_sel15_fFbR => x_37.Frame_sel15_fFbR
                , Frame_sel16_fEqLowL => x_37.Frame_sel16_fEqLowL
                , Frame_sel17_fEqLowR => x_37.Frame_sel17_fEqLowR
                , Frame_sel18_fEqMidL => x_37.Frame_sel18_fEqMidL
                , Frame_sel19_fEqMidR => x_37.Frame_sel19_fEqMidR
                , Frame_sel20_fEqHighL => x_37.Frame_sel20_fEqHighL
                , Frame_sel21_fEqHighR => x_37.Frame_sel21_fEqHighR
                , Frame_sel22_fEqHighLpL => x_37.Frame_sel22_fEqHighLpL
                , Frame_sel23_fEqHighLpR => x_37.Frame_sel23_fEqHighLpR
                , Frame_sel24_fAccL => x_37.Frame_sel24_fAccL
                , Frame_sel25_fAccR => x_37.Frame_sel25_fAccR
                , Frame_sel26_fAcc2L => x_37.Frame_sel26_fAcc2L
                , Frame_sel27_fAcc2R => x_37.Frame_sel27_fAcc2R
                , Frame_sel28_fAcc3L => x_37.Frame_sel28_fAcc3L
                , Frame_sel29_fAcc3R => x_37.Frame_sel29_fAcc3R );

  \c$bv_38\ <= (x_37.Frame_sel3_fGate);

  \on_24\ <= (\c$bv_38\(1 downto 1)) = std_logic_vector'("1");

  x_37 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_19(874 downto 0)));

  -- register begin
  ds1_19_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_19 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_19 <= result_107;
    end if;
  end process;
  -- register end

  with (ds1_20(875 downto 875)) select
    result_107 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                  std_logic_vector'("1" & ((std_logic_vector(result_108.Frame_sel0_fL)
                   & std_logic_vector(result_108.Frame_sel1_fR)
                   & clash_lowpass_fir_types.toSLV(result_108.Frame_sel2_fLast)
                   & result_108.Frame_sel3_fGate
                   & result_108.Frame_sel4_fOd
                   & result_108.Frame_sel5_fDist
                   & result_108.Frame_sel6_fEq
                   & result_108.Frame_sel7_fRat
                   & result_108.Frame_sel8_fReverb
                   & std_logic_vector(result_108.Frame_sel9_fAddr)
                   & std_logic_vector(result_108.Frame_sel10_fDryL)
                   & std_logic_vector(result_108.Frame_sel11_fDryR)
                   & std_logic_vector(result_108.Frame_sel12_fWetL)
                   & std_logic_vector(result_108.Frame_sel13_fWetR)
                   & std_logic_vector(result_108.Frame_sel14_fFbL)
                   & std_logic_vector(result_108.Frame_sel15_fFbR)
                   & std_logic_vector(result_108.Frame_sel16_fEqLowL)
                   & std_logic_vector(result_108.Frame_sel17_fEqLowR)
                   & std_logic_vector(result_108.Frame_sel18_fEqMidL)
                   & std_logic_vector(result_108.Frame_sel19_fEqMidR)
                   & std_logic_vector(result_108.Frame_sel20_fEqHighL)
                   & std_logic_vector(result_108.Frame_sel21_fEqHighR)
                   & std_logic_vector(result_108.Frame_sel22_fEqHighLpL)
                   & std_logic_vector(result_108.Frame_sel23_fEqHighLpR)
                   & std_logic_vector(result_108.Frame_sel24_fAccL)
                   & std_logic_vector(result_108.Frame_sel25_fAccR)
                   & std_logic_vector(result_108.Frame_sel26_fAcc2L)
                   & std_logic_vector(result_108.Frame_sel27_fAcc2R)
                   & std_logic_vector(result_108.Frame_sel28_fAcc3L)
                   & std_logic_vector(result_108.Frame_sel29_fAcc3R)))) when others;

  result_108 <= ( Frame_sel0_fL => x_38.Frame_sel0_fL
                , Frame_sel1_fR => x_38.Frame_sel1_fR
                , Frame_sel2_fLast => x_38.Frame_sel2_fLast
                , Frame_sel3_fGate => x_38.Frame_sel3_fGate
                , Frame_sel4_fOd => x_38.Frame_sel4_fOd
                , Frame_sel5_fDist => x_38.Frame_sel5_fDist
                , Frame_sel6_fEq => x_38.Frame_sel6_fEq
                , Frame_sel7_fRat => x_38.Frame_sel7_fRat
                , Frame_sel8_fReverb => x_38.Frame_sel8_fReverb
                , Frame_sel9_fAddr => x_38.Frame_sel9_fAddr
                , Frame_sel10_fDryL => x_38.Frame_sel10_fDryL
                , Frame_sel11_fDryR => x_38.Frame_sel11_fDryR
                , Frame_sel12_fWetL => x_38.Frame_sel12_fWetL
                , Frame_sel13_fWetR => x_38.Frame_sel13_fWetR
                , Frame_sel14_fFbL => x_38.Frame_sel14_fFbL
                , Frame_sel15_fFbR => x_38.Frame_sel15_fFbR
                , Frame_sel16_fEqLowL => x_38.Frame_sel16_fEqLowL
                , Frame_sel17_fEqLowR => x_38.Frame_sel17_fEqLowR
                , Frame_sel18_fEqMidL => x_38.Frame_sel18_fEqMidL
                , Frame_sel19_fEqMidR => x_38.Frame_sel19_fEqMidR
                , Frame_sel20_fEqHighL => x_38.Frame_sel20_fEqHighL
                , Frame_sel21_fEqHighR => x_38.Frame_sel21_fEqHighR
                , Frame_sel22_fEqHighLpL => x_38.Frame_sel22_fEqHighLpL
                , Frame_sel23_fEqHighLpR => x_38.Frame_sel23_fEqHighLpR
                , Frame_sel24_fAccL => \c$app_arg_141\
                , Frame_sel25_fAccR => \c$app_arg_140\
                , Frame_sel26_fAcc2L => x_38.Frame_sel26_fAcc2L
                , Frame_sel27_fAcc2R => x_38.Frame_sel27_fAcc2R
                , Frame_sel28_fAcc3L => x_38.Frame_sel28_fAcc3L
                , Frame_sel29_fAcc3R => x_38.Frame_sel29_fAcc3R );

  \c$app_arg_140\ <= resize((resize(x_38.Frame_sel1_fR,48)) * \c$app_arg_142\, 48) when \on_25\ else
                     to_signed(0,48);

  \c$app_arg_141\ <= resize((resize(x_38.Frame_sel0_fL,48)) * \c$app_arg_142\, 48) when \on_25\ else
                     to_signed(0,48);

  \c$bv_39\ <= (x_38.Frame_sel3_fGate);

  \on_25\ <= (\c$bv_39\(1 downto 1)) = std_logic_vector'("1");

  \c$app_arg_142\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(driveGain_1)))))))),48);

  \c$bv_40\ <= (x_38.Frame_sel4_fOd);

  driveGain_1 <= resize((to_unsigned(256,10) + (resize((resize((unsigned((\c$bv_40\(23 downto 16)))),10)) * to_unsigned(4,10), 10))),12);

  x_38 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_20(874 downto 0)));

  -- register begin
  ds1_20_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_20 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_20 <= result_109;
    end if;
  end process;
  -- register end

  with (gateLevelPipe(875 downto 875)) select
    result_109 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                  std_logic_vector'("1" & ((std_logic_vector(result_110.Frame_sel0_fL)
                   & std_logic_vector(result_110.Frame_sel1_fR)
                   & clash_lowpass_fir_types.toSLV(result_110.Frame_sel2_fLast)
                   & result_110.Frame_sel3_fGate
                   & result_110.Frame_sel4_fOd
                   & result_110.Frame_sel5_fDist
                   & result_110.Frame_sel6_fEq
                   & result_110.Frame_sel7_fRat
                   & result_110.Frame_sel8_fReverb
                   & std_logic_vector(result_110.Frame_sel9_fAddr)
                   & std_logic_vector(result_110.Frame_sel10_fDryL)
                   & std_logic_vector(result_110.Frame_sel11_fDryR)
                   & std_logic_vector(result_110.Frame_sel12_fWetL)
                   & std_logic_vector(result_110.Frame_sel13_fWetR)
                   & std_logic_vector(result_110.Frame_sel14_fFbL)
                   & std_logic_vector(result_110.Frame_sel15_fFbR)
                   & std_logic_vector(result_110.Frame_sel16_fEqLowL)
                   & std_logic_vector(result_110.Frame_sel17_fEqLowR)
                   & std_logic_vector(result_110.Frame_sel18_fEqMidL)
                   & std_logic_vector(result_110.Frame_sel19_fEqMidR)
                   & std_logic_vector(result_110.Frame_sel20_fEqHighL)
                   & std_logic_vector(result_110.Frame_sel21_fEqHighR)
                   & std_logic_vector(result_110.Frame_sel22_fEqHighLpL)
                   & std_logic_vector(result_110.Frame_sel23_fEqHighLpR)
                   & std_logic_vector(result_110.Frame_sel24_fAccL)
                   & std_logic_vector(result_110.Frame_sel25_fAccR)
                   & std_logic_vector(result_110.Frame_sel26_fAcc2L)
                   & std_logic_vector(result_110.Frame_sel27_fAcc2R)
                   & std_logic_vector(result_110.Frame_sel28_fAcc3L)
                   & std_logic_vector(result_110.Frame_sel29_fAcc3R)))) when others;

  \c$bv_41\ <= (x_41.Frame_sel3_fGate);

  result_selection_res_50 <= not ((\c$bv_41\(0 downto 0)) = std_logic_vector'("1"));

  result_110 <= x_41 when result_selection_res_50 else
                ( Frame_sel0_fL => result_112
                , Frame_sel1_fR => result_111
                , Frame_sel2_fLast => x_41.Frame_sel2_fLast
                , Frame_sel3_fGate => x_41.Frame_sel3_fGate
                , Frame_sel4_fOd => x_41.Frame_sel4_fOd
                , Frame_sel5_fDist => x_41.Frame_sel5_fDist
                , Frame_sel6_fEq => x_41.Frame_sel6_fEq
                , Frame_sel7_fRat => x_41.Frame_sel7_fRat
                , Frame_sel8_fReverb => x_41.Frame_sel8_fReverb
                , Frame_sel9_fAddr => x_41.Frame_sel9_fAddr
                , Frame_sel10_fDryL => x_41.Frame_sel10_fDryL
                , Frame_sel11_fDryR => x_41.Frame_sel11_fDryR
                , Frame_sel12_fWetL => x_41.Frame_sel12_fWetL
                , Frame_sel13_fWetR => x_41.Frame_sel13_fWetR
                , Frame_sel14_fFbL => x_41.Frame_sel14_fFbL
                , Frame_sel15_fFbR => x_41.Frame_sel15_fFbR
                , Frame_sel16_fEqLowL => x_41.Frame_sel16_fEqLowL
                , Frame_sel17_fEqLowR => x_41.Frame_sel17_fEqLowR
                , Frame_sel18_fEqMidL => x_41.Frame_sel18_fEqMidL
                , Frame_sel19_fEqMidR => x_41.Frame_sel19_fEqMidR
                , Frame_sel20_fEqHighL => x_41.Frame_sel20_fEqHighL
                , Frame_sel21_fEqHighR => x_41.Frame_sel21_fEqHighR
                , Frame_sel22_fEqHighLpL => x_41.Frame_sel22_fEqHighLpL
                , Frame_sel23_fEqHighLpR => x_41.Frame_sel23_fEqHighLpR
                , Frame_sel24_fAccL => x_41.Frame_sel24_fAccL
                , Frame_sel25_fAccR => x_41.Frame_sel25_fAccR
                , Frame_sel26_fAcc2L => x_41.Frame_sel26_fAcc2L
                , Frame_sel27_fAcc2R => x_41.Frame_sel27_fAcc2R
                , Frame_sel28_fAcc3L => x_41.Frame_sel28_fAcc3L
                , Frame_sel29_fAcc3R => x_41.Frame_sel29_fAcc3R );

  \c$case_alt_selection_res_45\ <= \c$app_arg_143\ < to_signed(-8388608,48);

  \c$case_alt_49\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_45\ else
                     resize(\c$app_arg_143\,24);

  result_selection_res_51 <= \c$app_arg_143\ > to_signed(8388607,48);

  result_111 <= to_signed(8388607,24) when result_selection_res_51 else
                \c$case_alt_49\;

  \c$shI_47\ <= (to_signed(12,64));

  capp_arg_143_shiftR : block
    signal sh_47 : natural;
  begin
    sh_47 <=
        -- pragma translate_off
        natural'high when (\c$shI_47\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_47\);
    \c$app_arg_143\ <= shift_right((resize((resize(x_41.Frame_sel1_fR,48)) * \c$app_arg_145\, 48)),sh_47)
        -- pragma translate_off
        when ((to_signed(12,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_46\ <= \c$app_arg_144\ < to_signed(-8388608,48);

  \c$case_alt_50\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_46\ else
                     resize(\c$app_arg_144\,24);

  result_selection_res_52 <= \c$app_arg_144\ > to_signed(8388607,48);

  result_112 <= to_signed(8388607,24) when result_selection_res_52 else
                \c$case_alt_50\;

  \c$shI_48\ <= (to_signed(12,64));

  capp_arg_144_shiftR : block
    signal sh_48 : natural;
  begin
    sh_48 <=
        -- pragma translate_off
        natural'high when (\c$shI_48\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_48\);
    \c$app_arg_144\ <= shift_right((resize((resize(x_41.Frame_sel0_fL,48)) * \c$app_arg_145\, 48)),sh_48)
        -- pragma translate_off
        when ((to_signed(12,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_145\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(gateGain)))))))),48);

  -- register begin
  gateGain_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      gateGain <= to_unsigned(4095,12);
    elsif rising_edge(clk) then
      gateGain <= result_113;
    end if;
  end process;
  -- register end

  \c$case_alt_selection_res_47\ <= gateGain < to_unsigned(4,12);

  \c$case_alt_51\ <= to_unsigned(0,12) when \c$case_alt_selection_res_47\ else
                     gateGain - to_unsigned(4,12);

  \c$case_alt_selection_res_48\ <= gateGain > to_unsigned(3583,12);

  \c$case_alt_52\ <= to_unsigned(4095,12) when \c$case_alt_selection_res_48\ else
                     gateGain + to_unsigned(512,12);

  \c$case_alt_53\ <= \c$case_alt_52\ when gateOpen else
                     \c$case_alt_51\;

  \c$bv_42\ <= (f_2.Frame_sel3_fGate);

  \c$case_alt_selection_res_49\ <= not ((\c$bv_42\(0 downto 0)) = std_logic_vector'("1"));

  \c$case_alt_54\ <= to_unsigned(4095,12) when \c$case_alt_selection_res_49\ else
                     \c$case_alt_53\;

  f_2 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(gateLevelPipe(874 downto 0)));

  with (gateLevelPipe(875 downto 875)) select
    result_113 <= gateGain when "0",
                  \c$case_alt_54\ when others;

  -- register begin
  gateOpen_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      gateOpen <= true;
    elsif rising_edge(clk) then
      gateOpen <= result_114;
    end if;
  end process;
  -- register end

  with (gateLevelPipe(875 downto 875)) select
    result_114 <= gateOpen when "0",
                  \c$case_alt_55\ when others;

  \c$case_alt_selection_res_50\ <= not ((\c$app_arg_148\(0 downto 0)) = std_logic_vector'("1"));

  \c$case_alt_55\ <= true when \c$case_alt_selection_res_50\ else
                     result_115;

  with (closeThreshold) select
    result_115 <= true when x"000000",
                  \c$case_alt_56\ when others;

  \c$case_alt_selection_res_51\ <= gateEnv > result_116;

  \c$case_alt_56\ <= true when \c$case_alt_selection_res_51\ else
                     \c$case_alt_57\;

  \c$case_alt_selection_res_52\ <= gateEnv < closeThreshold;

  \c$case_alt_57\ <= false when \c$case_alt_selection_res_52\ else
                     gateOpen;

  x_39 <= (\c$app_arg_147\ + \c$app_arg_146\) + to_signed(65536,48);

  \c$case_alt_selection_res_53\ <= x_39 < to_signed(-8388608,48);

  \c$case_alt_58\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_53\ else
                     resize(x_39,24);

  result_selection_res_53 <= x_39 > to_signed(8388607,48);

  result_116 <= to_signed(8388607,24) when result_selection_res_53 else
                \c$case_alt_58\;

  \c$shI_49\ <= (to_signed(1,64));

  capp_arg_146_shiftR : block
    signal sh_49 : natural;
  begin
    sh_49 <=
        -- pragma translate_off
        natural'high when (\c$shI_49\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_49\);
    \c$app_arg_146\ <= shift_right(\c$app_arg_147\,sh_49)
        -- pragma translate_off
        when ((to_signed(1,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_147\ <= resize(closeThreshold,48);

  \c$shI_50\ <= (to_signed(13,64));

  closeThreshold_shiftL : block
    signal sh_50 : natural;
  begin
    sh_50 <=
        -- pragma translate_off
        natural'high when (\c$shI_50\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_50\);
    closeThreshold <= shift_left((resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(x_40)))))))),24)),sh_50)
        -- pragma translate_off
        when ((to_signed(13,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  x_40 <= unsigned((\c$app_arg_148\(15 downto 8)));

  \c$app_arg_148\ <= f_3.Frame_sel3_fGate;

  f_3 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(gateLevelPipe(874 downto 0)));

  -- register begin
  gateEnv_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      gateEnv <= to_signed(0,24);
    elsif rising_edge(clk) then
      gateEnv <= result_118;
    end if;
  end process;
  -- register end

  \c$shI_51\ <= (to_signed(8,64));

  cdecay_app_arg_shiftR : block
    signal sh_51 : natural;
  begin
    sh_51 <=
        -- pragma translate_off
        natural'high when (\c$shI_51\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_51\);
    \c$decay_app_arg\ <= shift_right((resize(gateEnv,25)),sh_51)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  result_selection_res_54 <= gateEnv > decay;

  result_117 <= gateEnv - decay when result_selection_res_54 else
                to_signed(0,24);

  \c$case_alt_selection_res_54\ <= f_4.Frame_sel12_fWetL > gateEnv;

  \c$case_alt_59\ <= f_4.Frame_sel12_fWetL when \c$case_alt_selection_res_54\ else
                     result_117;

  \c$bv_43\ <= (f_4.Frame_sel3_fGate);

  \c$case_alt_selection_res_55\ <= not ((\c$bv_43\(0 downto 0)) = std_logic_vector'("1"));

  \c$case_alt_60\ <= to_signed(0,24) when \c$case_alt_selection_res_55\ else
                     \c$case_alt_59\;

  f_4 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(gateLevelPipe(874 downto 0)));

  decay <= resize((\c$decay_app_arg\ + to_signed(1,25)),24);

  with (gateLevelPipe(875 downto 875)) select
    result_118 <= gateEnv when "0",
                  \c$case_alt_60\ when others;

  x_41 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(gateLevelPipe(874 downto 0)));

  -- register begin
  gateLevelPipe_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      gateLevelPipe <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      gateLevelPipe <= result_119;
    end if;
  end process;
  -- register end

  with (ds1_21(875 downto 875)) select
    result_119 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                  std_logic_vector'("1" & ((std_logic_vector(\c$case_alt_61\.Frame_sel0_fL)
                   & std_logic_vector(\c$case_alt_61\.Frame_sel1_fR)
                   & clash_lowpass_fir_types.toSLV(\c$case_alt_61\.Frame_sel2_fLast)
                   & \c$case_alt_61\.Frame_sel3_fGate
                   & \c$case_alt_61\.Frame_sel4_fOd
                   & \c$case_alt_61\.Frame_sel5_fDist
                   & \c$case_alt_61\.Frame_sel6_fEq
                   & \c$case_alt_61\.Frame_sel7_fRat
                   & \c$case_alt_61\.Frame_sel8_fReverb
                   & std_logic_vector(\c$case_alt_61\.Frame_sel9_fAddr)
                   & std_logic_vector(\c$case_alt_61\.Frame_sel10_fDryL)
                   & std_logic_vector(\c$case_alt_61\.Frame_sel11_fDryR)
                   & std_logic_vector(\c$case_alt_61\.Frame_sel12_fWetL)
                   & std_logic_vector(\c$case_alt_61\.Frame_sel13_fWetR)
                   & std_logic_vector(\c$case_alt_61\.Frame_sel14_fFbL)
                   & std_logic_vector(\c$case_alt_61\.Frame_sel15_fFbR)
                   & std_logic_vector(\c$case_alt_61\.Frame_sel16_fEqLowL)
                   & std_logic_vector(\c$case_alt_61\.Frame_sel17_fEqLowR)
                   & std_logic_vector(\c$case_alt_61\.Frame_sel18_fEqMidL)
                   & std_logic_vector(\c$case_alt_61\.Frame_sel19_fEqMidR)
                   & std_logic_vector(\c$case_alt_61\.Frame_sel20_fEqHighL)
                   & std_logic_vector(\c$case_alt_61\.Frame_sel21_fEqHighR)
                   & std_logic_vector(\c$case_alt_61\.Frame_sel22_fEqHighLpL)
                   & std_logic_vector(\c$case_alt_61\.Frame_sel23_fEqHighLpR)
                   & std_logic_vector(\c$case_alt_61\.Frame_sel24_fAccL)
                   & std_logic_vector(\c$case_alt_61\.Frame_sel25_fAccR)
                   & std_logic_vector(\c$case_alt_61\.Frame_sel26_fAcc2L)
                   & std_logic_vector(\c$case_alt_61\.Frame_sel27_fAcc2R)
                   & std_logic_vector(\c$case_alt_61\.Frame_sel28_fAcc3L)
                   & std_logic_vector(\c$case_alt_61\.Frame_sel29_fAcc3R)))) when others;

  result_selection_res_55 <= result_122 > result_121;

  result_120 <= result_122 when result_selection_res_55 else
                result_121;

  \c$case_alt_61\ <= ( Frame_sel0_fL => x_42.Frame_sel0_fL
                     , Frame_sel1_fR => x_42.Frame_sel1_fR
                     , Frame_sel2_fLast => x_42.Frame_sel2_fLast
                     , Frame_sel3_fGate => x_42.Frame_sel3_fGate
                     , Frame_sel4_fOd => x_42.Frame_sel4_fOd
                     , Frame_sel5_fDist => x_42.Frame_sel5_fDist
                     , Frame_sel6_fEq => x_42.Frame_sel6_fEq
                     , Frame_sel7_fRat => x_42.Frame_sel7_fRat
                     , Frame_sel8_fReverb => x_42.Frame_sel8_fReverb
                     , Frame_sel9_fAddr => x_42.Frame_sel9_fAddr
                     , Frame_sel10_fDryL => x_42.Frame_sel10_fDryL
                     , Frame_sel11_fDryR => x_42.Frame_sel11_fDryR
                     , Frame_sel12_fWetL => result_120
                     , Frame_sel13_fWetR => x_42.Frame_sel13_fWetR
                     , Frame_sel14_fFbL => x_42.Frame_sel14_fFbL
                     , Frame_sel15_fFbR => x_42.Frame_sel15_fFbR
                     , Frame_sel16_fEqLowL => x_42.Frame_sel16_fEqLowL
                     , Frame_sel17_fEqLowR => x_42.Frame_sel17_fEqLowR
                     , Frame_sel18_fEqMidL => x_42.Frame_sel18_fEqMidL
                     , Frame_sel19_fEqMidR => x_42.Frame_sel19_fEqMidR
                     , Frame_sel20_fEqHighL => x_42.Frame_sel20_fEqHighL
                     , Frame_sel21_fEqHighR => x_42.Frame_sel21_fEqHighR
                     , Frame_sel22_fEqHighLpL => x_42.Frame_sel22_fEqHighLpL
                     , Frame_sel23_fEqHighLpR => x_42.Frame_sel23_fEqHighLpR
                     , Frame_sel24_fAccL => x_42.Frame_sel24_fAccL
                     , Frame_sel25_fAccR => x_42.Frame_sel25_fAccR
                     , Frame_sel26_fAcc2L => x_42.Frame_sel26_fAcc2L
                     , Frame_sel27_fAcc2R => x_42.Frame_sel27_fAcc2R
                     , Frame_sel28_fAcc3L => x_42.Frame_sel28_fAcc3L
                     , Frame_sel29_fAcc3R => x_42.Frame_sel29_fAcc3R );

  \c$case_alt_selection_res_56\ <= x_42.Frame_sel1_fR < to_signed(0,24);

  \c$case_alt_62\ <= -x_42.Frame_sel1_fR when \c$case_alt_selection_res_56\ else
                     x_42.Frame_sel1_fR;

  result_selection_res_56 <= x_42.Frame_sel1_fR = to_signed(-8388608,24);

  result_121 <= to_signed(8388607,24) when result_selection_res_56 else
                \c$case_alt_62\;

  \c$case_alt_selection_res_57\ <= x_42.Frame_sel0_fL < to_signed(0,24);

  \c$case_alt_63\ <= -x_42.Frame_sel0_fL when \c$case_alt_selection_res_57\ else
                     x_42.Frame_sel0_fL;

  result_selection_res_57 <= x_42.Frame_sel0_fL = to_signed(-8388608,24);

  result_122 <= to_signed(8388607,24) when result_selection_res_57 else
                \c$case_alt_63\;

  x_42 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_21(874 downto 0)));

  -- register begin
  ds1_21_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_21 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_21 <= result_124;
    end if;
  end process;
  -- register end

  validIn <= axis_in_tvalid and axis_out_tready;

  right <= result_123.Tuple2_0_sel1_signed_1;

  left <= result_123.Tuple2_0_sel0_signed_0;

  result_123 <= ( Tuple2_0_sel0_signed_0 => signed((\c$app_arg_149\(23 downto 0)))
                , Tuple2_0_sel1_signed_1 => signed((\c$app_arg_149\(47 downto 24))) );

  \c$app_arg_149\ <= axis_in_tdata;

  result_124 <= std_logic_vector'("1" & ((std_logic_vector(left)
                 & std_logic_vector(right)
                 & clash_lowpass_fir_types.toSLV(axis_in_tlast)
                 & gate_control
                 & overdrive_control
                 & distortion_control
                 & eq_control
                 & delay_control
                 & reverb_control
                 & std_logic_vector(to_unsigned(0,10))
                 & std_logic_vector(left)
                 & std_logic_vector(right)
                 & std_logic_vector(to_signed(0,24))
                 & std_logic_vector(to_signed(0,24))
                 & std_logic_vector(to_signed(0,24))
                 & std_logic_vector(to_signed(0,24))
                 & std_logic_vector(to_signed(0,24))
                 & std_logic_vector(to_signed(0,24))
                 & std_logic_vector(to_signed(0,24))
                 & std_logic_vector(to_signed(0,24))
                 & std_logic_vector(to_signed(0,24))
                 & std_logic_vector(to_signed(0,24))
                 & std_logic_vector(to_signed(0,24))
                 & std_logic_vector(to_signed(0,24))
                 & std_logic_vector(to_signed(0,48))
                 & std_logic_vector(to_signed(0,48))
                 & std_logic_vector(to_signed(0,48))
                 & std_logic_vector(to_signed(0,48))
                 & std_logic_vector(to_signed(0,48))
                 & std_logic_vector(to_signed(0,48))))) when validIn else
                std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");

  \c$reverbAddr_case_alt_selection_res\ <= reverbAddr = to_unsigned(1023,10);

  \c$reverbAddr_case_alt\ <= to_unsigned(0,10) when \c$reverbAddr_case_alt_selection_res\ else
                             reverbAddr + to_unsigned(1,10);

  axis_out_tdata <= result.Tuple4_sel0_std_logic_vector;

  axis_out_tvalid <= result.Tuple4_sel1_boolean_0;

  axis_out_tlast <= result.Tuple4_sel2_boolean_1;

  axis_in_tready <= result.Tuple4_sel3_boolean_2;


end;
