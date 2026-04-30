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
  -- src/LowPassFir.hs:493:1-11
  signal \new\                                 : boolean;
  signal \c$app_arg\                           : boolean;
  signal \c$app_arg_0\                         : std_logic_vector(47 downto 0);
  -- src/LowPassFir.hs:482:1-8
  signal f                                     : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:493:1-11
  signal consumed                              : boolean;
  -- src/LowPassFir.hs:562:1-10
  signal outReg                                : clash_lowpass_fir_types.AxisOut := ( AxisOut_sel0_oData => std_logic_vector'(x"000000000000")
, AxisOut_sel1_oValid => false
, AxisOut_sel2_oLast => false );
  signal result_1                              : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_1\                         : signed(47 downto 0);
  signal \c$app_arg_2\                         : signed(47 downto 0);
  -- src/LowPassFir.hs:439:1-27
  signal \on\                                  : boolean;
  signal \c$app_arg_3\                         : signed(47 downto 0);
  -- src/LowPassFir.hs:562:1-10
  signal reverbToneBlendPipe                   : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_2                              : clash_lowpass_fir_types.Maybe;
  signal \c$app_arg_4\                         : signed(47 downto 0);
  signal \c$case_alt_0\                        : signed(23 downto 0);
  signal result_3                              : signed(23 downto 0);
  signal \c$app_arg_5\                         : signed(47 downto 0);
  signal \c$case_alt_1\                        : signed(23 downto 0);
  signal result_4                              : signed(23 downto 0);
  signal \c$case_alt_2\                        : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:562:1-10
  signal x                                     : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:562:1-10
  signal ds1                                   : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_5                              : clash_lowpass_fir_types.Maybe;
  signal \c$app_arg_6\                         : signed(47 downto 0);
  -- src/LowPassFir.hs:103:1-5
  signal gain                                  : unsigned(7 downto 0);
  signal \c$app_arg_7\                         : signed(47 downto 0);
  signal \c$app_arg_8\                         : unsigned(7 downto 0);
  -- src/LowPassFir.hs:424:1-23
  signal x_0                                   : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:562:1-10
  signal reverbTonePrevR                       : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:562:1-10
  signal \c$reverbTonePrevR_app_arg\           : signed(23 downto 0);
  -- src/LowPassFir.hs:562:1-10
  signal reverbTonePrevL                       : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:562:1-10
  signal \c$reverbTonePrevL_app_arg\           : signed(23 downto 0);
  -- src/LowPassFir.hs:562:1-10
  signal x_1                                   : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:562:1-10
  signal \c$ds1_app_arg\                       : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  -- src/LowPassFir.hs:417:1-10
  signal f_0                                   : clash_lowpass_fir_types.Frame;
  signal result_6                              : clash_lowpass_fir_types.Maybe;
  signal result_7                              : signed(23 downto 0);
  -- src/LowPassFir.hs:562:1-10
  signal ds                                    : clash_lowpass_fir_types.Tuple2;
  -- src/LowPassFir.hs:562:1-10
  signal a1                                    : clash_lowpass_fir_types.Tuple2;
  -- src/LowPassFir.hs:562:1-10
  signal \c$ds1_app_arg_0\                     : boolean;
  -- src/LowPassFir.hs:562:1-10
  signal eta2                                  : clash_lowpass_fir_types.Maybe_0;
  signal result_8                              : signed(23 downto 0);
  -- src/LowPassFir.hs:562:1-10
  signal ds_0                                  : clash_lowpass_fir_types.Tuple2;
  -- src/LowPassFir.hs:562:1-10
  signal a1_0                                  : clash_lowpass_fir_types.Tuple2;
  -- src/LowPassFir.hs:562:1-10
  signal \c$ds1_app_arg_1\                     : boolean;
  -- src/LowPassFir.hs:562:1-10
  signal eta2_0                                : clash_lowpass_fir_types.Maybe_0;
  -- src/LowPassFir.hs:474:1-12
  signal f_1                                   : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:562:1-10
  signal outPipe                               : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_9                              : clash_lowpass_fir_types.Maybe;
  signal \c$app_arg_9\                         : signed(47 downto 0);
  signal \c$case_alt_3\                        : signed(23 downto 0);
  signal result_10                             : signed(23 downto 0);
  signal \c$app_arg_10\                        : signed(23 downto 0);
  signal \c$app_arg_11\                        : signed(47 downto 0);
  signal \c$case_alt_4\                        : signed(23 downto 0);
  signal result_11                             : signed(23 downto 0);
  signal \c$app_arg_12\                        : signed(23 downto 0);
  signal result_12                             : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:466:1-14
  signal \on_0\                                : boolean;
  -- src/LowPassFir.hs:562:1-10
  signal x_2                                   : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:562:1-10
  signal ds1_0                                 : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_13                             : clash_lowpass_fir_types.Maybe;
  signal result_14                             : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_13\                        : signed(47 downto 0);
  signal \c$app_arg_14\                        : signed(47 downto 0);
  signal \c$app_arg_15\                        : signed(47 downto 0);
  signal \c$app_arg_16\                        : signed(47 downto 0);
  signal \c$app_arg_17\                        : signed(47 downto 0);
  -- src/LowPassFir.hs:453:1-22
  signal \on_1\                                : boolean;
  signal \c$app_arg_18\                        : signed(47 downto 0);
  -- src/LowPassFir.hs:453:1-22
  signal invMixGain                            : unsigned(8 downto 0);
  -- src/LowPassFir.hs:453:1-22
  signal mixGain                               : unsigned(7 downto 0);
  -- src/LowPassFir.hs:562:1-10
  signal x_3                                   : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:562:1-10
  signal ds1_1                                 : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_15                             : clash_lowpass_fir_types.Maybe;
  signal \c$app_arg_19\                        : signed(47 downto 0);
  signal \c$app_arg_20\                        : signed(47 downto 0);
  -- src/LowPassFir.hs:112:1-7
  signal x_4                                   : signed(47 downto 0);
  signal \c$case_alt_5\                        : signed(23 downto 0);
  signal result_16                             : signed(23 downto 0);
  signal \c$app_arg_21\                        : signed(23 downto 0);
  signal \c$app_arg_22\                        : signed(47 downto 0);
  signal \c$app_arg_23\                        : signed(47 downto 0);
  -- src/LowPassFir.hs:112:1-7
  signal x_5                                   : signed(47 downto 0);
  signal \c$case_alt_6\                        : signed(23 downto 0);
  signal result_17                             : signed(23 downto 0);
  signal \c$app_arg_24\                        : signed(23 downto 0);
  signal result_18                             : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:445:1-19
  signal \on_2\                                : boolean;
  -- src/LowPassFir.hs:562:1-10
  signal x_6                                   : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:562:1-10
  signal ds1_2                                 : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  -- src/LowPassFir.hs:562:1-10
  signal \c$ds1_app_arg_2\                     : clash_lowpass_fir_types.Maybe;
  -- src/LowPassFir.hs:562:1-10
  signal \c$ds1_app_arg_3\                     : signed(63 downto 0);
  -- src/LowPassFir.hs:562:1-10
  signal reverbAddr                            : clash_lowpass_fir_types.index_1024 := to_unsigned(0,10);
  -- src/LowPassFir.hs:562:1-10
  signal \c$reverbAddr_app_arg\                : clash_lowpass_fir_types.index_1024;
  -- src/LowPassFir.hs:562:1-10
  signal eqMixPipe                             : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_19                             : clash_lowpass_fir_types.Maybe;
  -- src/LowPassFir.hs:409:1-10
  signal \on_3\                                : boolean;
  signal result_20                             : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_25\                        : signed(23 downto 0);
  signal \c$case_alt_7\                        : signed(23 downto 0);
  signal result_21                             : signed(23 downto 0);
  signal \c$app_arg_26\                        : signed(47 downto 0);
  signal \c$app_arg_27\                        : signed(23 downto 0);
  signal \c$case_alt_8\                        : signed(23 downto 0);
  signal result_22                             : signed(23 downto 0);
  signal \c$app_arg_28\                        : signed(47 downto 0);
  -- src/LowPassFir.hs:562:1-10
  signal x_7                                   : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:562:1-10
  signal ds1_3                                 : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_23                             : clash_lowpass_fir_types.Maybe;
  signal result_24                             : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_29\                        : signed(47 downto 0);
  signal \c$app_arg_30\                        : signed(47 downto 0);
  signal \c$app_arg_31\                        : signed(47 downto 0);
  signal \c$app_arg_32\                        : signed(47 downto 0);
  signal \c$app_arg_33\                        : signed(47 downto 0);
  signal \c$app_arg_34\                        : signed(47 downto 0);
  signal \c$app_arg_35\                        : signed(47 downto 0);
  signal \c$app_arg_36\                        : signed(47 downto 0);
  -- src/LowPassFir.hs:396:1-15
  signal \on_4\                                : boolean;
  signal \c$app_arg_37\                        : signed(47 downto 0);
  signal \c$app_arg_38\                        : std_logic_vector(31 downto 0);
  -- src/LowPassFir.hs:562:1-10
  signal x_8                                   : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:562:1-10
  signal ds1_4                                 : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_25                             : clash_lowpass_fir_types.Maybe;
  signal \c$case_alt_9\                        : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:112:1-7
  signal x_9                                   : signed(47 downto 0);
  signal \c$case_alt_10\                       : signed(23 downto 0);
  signal result_26                             : signed(23 downto 0);
  -- src/LowPassFir.hs:112:1-7
  signal x_10                                  : signed(47 downto 0);
  signal \c$case_alt_11\                       : signed(23 downto 0);
  signal result_27                             : signed(23 downto 0);
  -- src/LowPassFir.hs:112:1-7
  signal x_11                                  : signed(47 downto 0);
  signal \c$case_alt_12\                       : signed(23 downto 0);
  signal result_28                             : signed(23 downto 0);
  signal \c$app_arg_39\                        : signed(47 downto 0);
  -- src/LowPassFir.hs:112:1-7
  signal x_12                                  : signed(47 downto 0);
  signal \c$case_alt_13\                       : signed(23 downto 0);
  signal result_29                             : signed(23 downto 0);
  signal \c$app_arg_40\                        : signed(47 downto 0);
  -- src/LowPassFir.hs:562:1-10
  signal eqFilterPipe                          : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_30                             : clash_lowpass_fir_types.Maybe;
  signal \c$case_alt_14\                       : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_41\                        : signed(24 downto 0);
  signal \c$app_arg_42\                        : signed(24 downto 0);
  signal \c$app_arg_43\                        : signed(24 downto 0);
  signal \c$app_arg_44\                        : signed(24 downto 0);
  signal \c$app_arg_45\                        : signed(24 downto 0);
  signal \c$app_arg_46\                        : signed(24 downto 0);
  -- src/LowPassFir.hs:562:1-10
  signal eqHighPrevR                           : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:562:1-10
  signal \c$eqHighPrevR_app_arg\               : signed(23 downto 0);
  -- src/LowPassFir.hs:562:1-10
  signal eqHighPrevL                           : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:562:1-10
  signal \c$eqHighPrevL_app_arg\               : signed(23 downto 0);
  -- src/LowPassFir.hs:562:1-10
  signal eqLowPrevR                            : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:562:1-10
  signal \c$eqLowPrevR_app_arg\                : signed(23 downto 0);
  -- src/LowPassFir.hs:562:1-10
  signal eqLowPrevL                            : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:562:1-10
  signal \c$eqLowPrevL_app_arg\                : signed(23 downto 0);
  -- src/LowPassFir.hs:562:1-10
  signal x_13                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:144:1-7
  signal x_14                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:144:1-7
  signal ds1_5                                 : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_31                             : clash_lowpass_fir_types.Maybe;
  signal result_32                             : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_47\                        : signed(23 downto 0);
  signal \c$case_alt_15\                       : signed(23 downto 0);
  signal result_33                             : signed(23 downto 0);
  signal \c$app_arg_48\                        : signed(47 downto 0);
  signal \c$app_arg_49\                        : signed(23 downto 0);
  -- src/LowPassFir.hs:362:1-20
  signal \on_5\                                : boolean;
  signal \c$case_alt_16\                       : signed(23 downto 0);
  signal result_34                             : signed(23 downto 0);
  signal \c$app_arg_50\                        : signed(47 downto 0);
  signal \c$app_arg_51\                        : signed(47 downto 0);
  -- src/LowPassFir.hs:362:1-20
  signal level                                 : unsigned(7 downto 0);
  -- src/LowPassFir.hs:562:1-10
  signal distToneBlendPipe                     : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_35                             : clash_lowpass_fir_types.Maybe;
  signal \c$app_arg_52\                        : signed(47 downto 0);
  signal \c$case_alt_17\                       : signed(23 downto 0);
  signal result_36                             : signed(23 downto 0);
  signal \c$app_arg_53\                        : signed(23 downto 0);
  signal \c$app_arg_54\                        : signed(47 downto 0);
  signal \c$case_alt_18\                       : signed(23 downto 0);
  signal result_37                             : signed(23 downto 0);
  signal \c$app_arg_55\                        : signed(23 downto 0);
  signal result_38                             : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:351:1-24
  signal \on_6\                                : boolean;
  -- src/LowPassFir.hs:562:1-10
  signal x_15                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:562:1-10
  signal ds1_6                                 : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_39                             : clash_lowpass_fir_types.Maybe;
  signal result_40                             : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_56\                        : signed(47 downto 0);
  signal \c$app_arg_57\                        : signed(47 downto 0);
  signal \c$app_arg_58\                        : signed(47 downto 0);
  -- src/LowPassFir.hs:338:1-27
  signal toneInv                               : unsigned(7 downto 0);
  signal \c$app_arg_59\                        : signed(47 downto 0);
  signal \c$app_arg_60\                        : signed(47 downto 0);
  -- src/LowPassFir.hs:338:1-27
  signal \on_7\                                : boolean;
  signal \c$app_arg_61\                        : signed(47 downto 0);
  -- src/LowPassFir.hs:338:1-27
  signal tone                                  : unsigned(7 downto 0);
  -- src/LowPassFir.hs:562:1-10
  signal distTonePrevR                         : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:562:1-10
  signal \c$distTonePrevR_app_arg\             : signed(23 downto 0);
  -- src/LowPassFir.hs:562:1-10
  signal distTonePrevL                         : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:562:1-10
  signal \c$distTonePrevL_app_arg\             : signed(23 downto 0);
  -- src/LowPassFir.hs:562:1-10
  signal x_16                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:144:1-7
  signal x_17                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:144:1-7
  signal ds1_7                                 : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_41                             : clash_lowpass_fir_types.Maybe;
  -- src/LowPassFir.hs:331:1-24
  signal threshold                             : signed(23 downto 0);
  -- src/LowPassFir.hs:331:1-24
  signal \on_8\                                : boolean;
  signal result_42                             : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_62\                        : signed(23 downto 0);
  signal result_43                             : signed(23 downto 0);
  signal \c$case_alt_19\                       : signed(23 downto 0);
  signal \c$app_arg_63\                        : signed(23 downto 0);
  signal \c$app_arg_64\                        : signed(23 downto 0);
  signal result_44                             : signed(23 downto 0);
  signal \c$case_alt_20\                       : signed(23 downto 0);
  signal \c$app_arg_65\                        : signed(23 downto 0);
  -- src/LowPassFir.hs:562:1-10
  signal x_18                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:562:1-10
  signal ds1_8                                 : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_45                             : clash_lowpass_fir_types.Maybe;
  signal \c$app_arg_66\                        : signed(47 downto 0);
  signal \c$case_alt_21\                       : signed(23 downto 0);
  signal result_46                             : signed(23 downto 0);
  signal \c$app_arg_67\                        : signed(23 downto 0);
  signal \c$app_arg_68\                        : signed(47 downto 0);
  signal \c$case_alt_22\                       : signed(23 downto 0);
  signal result_47                             : signed(23 downto 0);
  signal \c$app_arg_69\                        : signed(23 downto 0);
  signal result_48                             : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:325:1-25
  signal \on_9\                                : boolean;
  -- src/LowPassFir.hs:562:1-10
  signal x_19                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:562:1-10
  signal ds1_9                                 : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_49                             : clash_lowpass_fir_types.Maybe;
  signal result_50                             : clash_lowpass_fir_types.Frame;
  signal result_51                             : signed(24 downto 0);
  -- src/LowPassFir.hs:310:1-28
  signal rawThreshold                          : signed(24 downto 0);
  signal \c$app_arg_70\                        : signed(47 downto 0);
  signal \c$app_arg_71\                        : signed(47 downto 0);
  -- src/LowPassFir.hs:310:1-28
  signal \on_10\                               : boolean;
  signal \c$app_arg_72\                        : signed(47 downto 0);
  -- src/LowPassFir.hs:310:1-28
  signal driveGain                             : unsigned(11 downto 0);
  -- src/LowPassFir.hs:310:1-28
  signal amount                                : unsigned(7 downto 0);
  -- src/LowPassFir.hs:562:1-10
  signal x_20                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:562:1-10
  signal ds1_10                                : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_52                             : clash_lowpass_fir_types.Maybe;
  signal result_53                             : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_73\                        : signed(23 downto 0);
  signal \c$case_alt_23\                       : signed(23 downto 0);
  signal result_54                             : signed(23 downto 0);
  signal \c$app_arg_74\                        : signed(47 downto 0);
  signal \c$app_arg_75\                        : signed(23 downto 0);
  -- src/LowPassFir.hs:301:1-19
  signal \on_11\                               : boolean;
  signal \c$case_alt_24\                       : signed(23 downto 0);
  signal result_55                             : signed(23 downto 0);
  signal \c$app_arg_76\                        : signed(47 downto 0);
  signal \c$app_arg_77\                        : signed(47 downto 0);
  -- src/LowPassFir.hs:301:1-19
  signal level_0                               : unsigned(7 downto 0);
  -- src/LowPassFir.hs:562:1-10
  signal odToneBlendPipe                       : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_56                             : clash_lowpass_fir_types.Maybe;
  signal \c$app_arg_78\                        : signed(47 downto 0);
  signal \c$case_alt_25\                       : signed(23 downto 0);
  signal result_57                             : signed(23 downto 0);
  signal \c$app_arg_79\                        : signed(23 downto 0);
  signal \c$app_arg_80\                        : signed(47 downto 0);
  signal \c$case_alt_26\                       : signed(23 downto 0);
  signal result_58                             : signed(23 downto 0);
  signal \c$app_arg_81\                        : signed(23 downto 0);
  signal result_59                             : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:290:1-23
  signal \on_12\                               : boolean;
  -- src/LowPassFir.hs:562:1-10
  signal x_21                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:562:1-10
  signal ds1_11                                : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_60                             : clash_lowpass_fir_types.Maybe;
  signal result_61                             : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_82\                        : signed(47 downto 0);
  signal \c$app_arg_83\                        : signed(47 downto 0);
  signal \c$app_arg_84\                        : signed(47 downto 0);
  -- src/LowPassFir.hs:277:1-26
  signal toneInv_0                             : unsigned(7 downto 0);
  signal \c$app_arg_85\                        : signed(47 downto 0);
  signal \c$app_arg_86\                        : signed(47 downto 0);
  -- src/LowPassFir.hs:277:1-26
  signal \on_13\                               : boolean;
  signal \c$app_arg_87\                        : signed(47 downto 0);
  -- src/LowPassFir.hs:277:1-26
  signal tone_0                                : unsigned(7 downto 0);
  -- src/LowPassFir.hs:562:1-10
  signal odTonePrevR                           : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:562:1-10
  signal \c$odTonePrevR_app_arg\               : signed(23 downto 0);
  -- src/LowPassFir.hs:562:1-10
  signal odTonePrevL                           : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:562:1-10
  signal \c$odTonePrevL_app_arg\               : signed(23 downto 0);
  -- src/LowPassFir.hs:562:1-10
  signal x_22                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:144:1-7
  signal x_23                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:144:1-7
  signal ds1_12                                : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_62                             : clash_lowpass_fir_types.Maybe;
  -- src/LowPassFir.hs:271:1-23
  signal \on_14\                               : boolean;
  signal result_63                             : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_88\                        : signed(23 downto 0);
  signal result_64                             : signed(23 downto 0);
  signal \c$case_alt_27\                       : signed(23 downto 0);
  signal \c$app_arg_89\                        : signed(24 downto 0);
  signal \c$app_arg_90\                        : signed(24 downto 0);
  signal \c$app_arg_91\                        : signed(24 downto 0);
  signal \c$app_arg_92\                        : signed(23 downto 0);
  signal result_65                             : signed(23 downto 0);
  signal \c$case_alt_28\                       : signed(23 downto 0);
  signal \c$app_arg_93\                        : signed(24 downto 0);
  signal \c$app_arg_94\                        : signed(24 downto 0);
  signal \c$app_arg_95\                        : signed(24 downto 0);
  -- src/LowPassFir.hs:562:1-10
  signal x_24                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:562:1-10
  signal ds1_13                                : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_66                             : clash_lowpass_fir_types.Maybe;
  signal \c$app_arg_96\                        : signed(47 downto 0);
  signal \c$case_alt_29\                       : signed(23 downto 0);
  signal result_67                             : signed(23 downto 0);
  signal \c$app_arg_97\                        : signed(23 downto 0);
  signal \c$app_arg_98\                        : signed(47 downto 0);
  signal \c$case_alt_30\                       : signed(23 downto 0);
  signal result_68                             : signed(23 downto 0);
  signal \c$app_arg_99\                        : signed(23 downto 0);
  signal result_69                             : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:265:1-24
  signal \on_15\                               : boolean;
  -- src/LowPassFir.hs:562:1-10
  signal x_25                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:562:1-10
  signal ds1_14                                : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_70                             : clash_lowpass_fir_types.Maybe;
  signal result_71                             : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_100\                       : signed(47 downto 0);
  signal \c$app_arg_101\                       : signed(47 downto 0);
  -- src/LowPassFir.hs:258:1-27
  signal \on_16\                               : boolean;
  signal \c$app_arg_102\                       : signed(47 downto 0);
  -- src/LowPassFir.hs:258:1-27
  signal driveGain_0                           : unsigned(11 downto 0);
  -- src/LowPassFir.hs:562:1-10
  signal x_26                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:562:1-10
  signal ds1_15                                : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_72                             : clash_lowpass_fir_types.Maybe;
  signal result_73                             : clash_lowpass_fir_types.Frame;
  signal \c$case_alt_31\                       : signed(23 downto 0);
  signal result_74                             : signed(23 downto 0);
  signal \c$app_arg_103\                       : signed(47 downto 0);
  signal \c$case_alt_32\                       : signed(23 downto 0);
  signal result_75                             : signed(23 downto 0);
  signal \c$app_arg_104\                       : signed(47 downto 0);
  signal \c$app_arg_105\                       : signed(47 downto 0);
  -- src/LowPassFir.hs:562:1-10
  signal gateGain                              : unsigned(11 downto 0) := to_unsigned(4095,12);
  signal \c$case_alt_33\                       : unsigned(11 downto 0);
  signal \c$case_alt_34\                       : unsigned(11 downto 0);
  signal \c$case_alt_35\                       : unsigned(11 downto 0);
  signal \c$case_alt_36\                       : unsigned(11 downto 0);
  -- src/LowPassFir.hs:243:1-12
  signal f_2                                   : clash_lowpass_fir_types.Frame;
  signal result_76                             : unsigned(11 downto 0);
  -- src/LowPassFir.hs:562:1-10
  signal gateOpen                              : boolean := true;
  signal result_77                             : boolean;
  signal \c$case_alt_37\                       : boolean;
  signal result_78                             : boolean;
  signal \c$case_alt_38\                       : boolean;
  signal \c$case_alt_39\                       : boolean;
  -- src/LowPassFir.hs:112:1-7
  signal x_27                                  : signed(47 downto 0);
  signal \c$case_alt_40\                       : signed(23 downto 0);
  signal result_79                             : signed(23 downto 0);
  signal \c$app_arg_106\                       : signed(47 downto 0);
  signal \c$app_arg_107\                       : signed(47 downto 0);
  -- src/LowPassFir.hs:231:1-12
  signal closeThreshold                        : signed(23 downto 0);
  -- src/LowPassFir.hs:88:1-9
  signal x_28                                  : unsigned(7 downto 0);
  signal \c$app_arg_108\                       : std_logic_vector(31 downto 0);
  -- src/LowPassFir.hs:231:1-12
  signal f_3                                   : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:562:1-10
  signal gateEnv                               : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:220:1-11
  signal \c$decay_app_arg\                     : signed(24 downto 0);
  signal result_80                             : signed(23 downto 0);
  signal \c$case_alt_41\                       : signed(23 downto 0);
  signal \c$case_alt_42\                       : signed(23 downto 0);
  -- src/LowPassFir.hs:220:1-11
  signal f_4                                   : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:220:1-11
  signal decay                                 : signed(23 downto 0);
  signal result_81                             : signed(23 downto 0);
  -- src/LowPassFir.hs:144:1-7
  signal x_29                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:562:1-10
  signal gateLevelPipe                         : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_82                             : clash_lowpass_fir_types.Maybe;
  signal result_83                             : signed(23 downto 0);
  signal \c$case_alt_43\                       : clash_lowpass_fir_types.Frame;
  signal \c$case_alt_44\                       : signed(23 downto 0);
  signal result_84                             : signed(23 downto 0);
  signal \c$case_alt_45\                       : signed(23 downto 0);
  signal result_85                             : signed(23 downto 0);
  -- src/LowPassFir.hs:562:1-10
  signal x_30                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:562:1-10
  signal ds1_16                                : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  -- src/LowPassFir.hs:181:1-9
  signal validIn                               : boolean;
  -- src/LowPassFir.hs:181:1-9
  signal right                                 : signed(23 downto 0);
  -- src/LowPassFir.hs:181:1-9
  signal left                                  : signed(23 downto 0);
  signal result_86                             : clash_lowpass_fir_types.Tuple2_0;
  signal \c$app_arg_109\                       : std_logic_vector(47 downto 0);
  signal result_87                             : clash_lowpass_fir_types.Maybe;
  -- src/LowPassFir.hs:562:1-10
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
  signal \c$case_alt_selection_res_11\         : boolean;
  signal result_selection_res_14               : boolean;
  signal \c$shI_13\                            : signed(63 downto 0);
  signal \c$bv_8\                              : std_logic_vector(31 downto 0);
  signal \c$case_alt_selection_res_12\         : boolean;
  signal result_selection_res_15               : boolean;
  signal \c$shI_14\                            : signed(63 downto 0);
  signal \c$bv_9\                              : std_logic_vector(31 downto 0);
  signal \c$shI_15\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_13\         : boolean;
  signal result_selection_res_16               : boolean;
  signal \c$shI_16\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_14\         : boolean;
  signal result_selection_res_17               : boolean;
  signal \c$bv_10\                             : std_logic_vector(31 downto 0);
  signal \c$bv_11\                             : std_logic_vector(31 downto 0);
  signal \c$bv_12\                             : std_logic_vector(31 downto 0);
  signal \c$bv_13\                             : std_logic_vector(31 downto 0);
  signal result_selection_res_18               : boolean;
  signal \c$case_alt_selection_res_15\         : boolean;
  signal result_selection_res_19               : boolean;
  signal \c$case_alt_selection_res_16\         : boolean;
  signal \c$shI_17\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_17\         : boolean;
  signal result_selection_res_20               : boolean;
  signal \c$shI_18\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_18\         : boolean;
  signal result_selection_res_21               : boolean;
  signal \c$bv_14\                             : std_logic_vector(31 downto 0);
  signal result_selection_res_22               : boolean;
  signal \c$bv_15\                             : std_logic_vector(31 downto 0);
  signal \c$bv_16\                             : std_logic_vector(31 downto 0);
  signal \c$case_alt_selection_res_19\         : boolean;
  signal result_selection_res_23               : boolean;
  signal \c$shI_19\                            : signed(63 downto 0);
  signal \c$bv_17\                             : std_logic_vector(31 downto 0);
  signal \c$case_alt_selection_res_20\         : boolean;
  signal result_selection_res_24               : boolean;
  signal \c$shI_20\                            : signed(63 downto 0);
  signal \c$bv_18\                             : std_logic_vector(31 downto 0);
  signal \c$shI_21\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_21\         : boolean;
  signal result_selection_res_25               : boolean;
  signal \c$shI_22\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_22\         : boolean;
  signal result_selection_res_26               : boolean;
  signal \c$bv_19\                             : std_logic_vector(31 downto 0);
  signal \c$bv_20\                             : std_logic_vector(31 downto 0);
  signal \c$bv_21\                             : std_logic_vector(31 downto 0);
  signal \c$bv_22\                             : std_logic_vector(31 downto 0);
  signal result_selection_res_27               : boolean;
  signal \c$case_alt_selection_res_23\         : boolean;
  signal \c$shI_23\                            : signed(63 downto 0);
  signal \c$shI_24\                            : signed(63 downto 0);
  signal result_selection_res_28               : boolean;
  signal \c$case_alt_selection_res_24\         : boolean;
  signal \c$shI_25\                            : signed(63 downto 0);
  signal \c$shI_26\                            : signed(63 downto 0);
  signal \c$shI_27\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_25\         : boolean;
  signal result_selection_res_29               : boolean;
  signal \c$shI_28\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_26\         : boolean;
  signal result_selection_res_30               : boolean;
  signal \c$bv_23\                             : std_logic_vector(31 downto 0);
  signal \c$bv_24\                             : std_logic_vector(31 downto 0);
  signal \c$bv_25\                             : std_logic_vector(31 downto 0);
  signal result_selection_res_31               : boolean;
  signal \c$bv_26\                             : std_logic_vector(31 downto 0);
  signal \c$case_alt_selection_res_27\         : boolean;
  signal result_selection_res_32               : boolean;
  signal \c$shI_29\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_28\         : boolean;
  signal result_selection_res_33               : boolean;
  signal \c$shI_30\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_29\         : boolean;
  signal \c$case_alt_selection_res_30\         : boolean;
  signal \c$case_alt_selection_res_31\         : boolean;
  signal \c$bv_27\                             : std_logic_vector(31 downto 0);
  signal \c$case_alt_selection_res_32\         : boolean;
  signal result_selection_res_34               : boolean;
  signal \c$case_alt_selection_res_33\         : boolean;
  signal \c$case_alt_selection_res_34\         : boolean;
  signal \c$case_alt_selection_res_35\         : boolean;
  signal result_selection_res_35               : boolean;
  signal \c$shI_31\                            : signed(63 downto 0);
  signal \c$shI_32\                            : signed(63 downto 0);
  signal \c$shI_33\                            : signed(63 downto 0);
  signal result_selection_res_36               : boolean;
  signal \c$case_alt_selection_res_36\         : boolean;
  signal \c$case_alt_selection_res_37\         : boolean;
  signal \c$bv_28\                             : std_logic_vector(31 downto 0);
  signal result_selection_res_37               : boolean;
  signal \c$case_alt_selection_res_38\         : boolean;
  signal result_selection_res_38               : boolean;
  signal \c$case_alt_selection_res_39\         : boolean;
  signal result_selection_res_39               : boolean;
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

  with (outPipe(843 downto 843)) select
    \new\ <= false when "0",
             true when others;

  with (outPipe(843 downto 843)) select
    \c$app_arg\ <= false when "0",
                   f.Frame_sel2_fLast when others;

  with (outPipe(843 downto 843)) select
    \c$app_arg_0\ <= std_logic_vector'(x"000000000000") when "0",
                     std_logic_vector'(std_logic_vector'(((std_logic_vector(f.Frame_sel1_fR)))) & std_logic_vector'(((std_logic_vector(f.Frame_sel0_fL))))) when others;

  f <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(outPipe(842 downto 0)));

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
              , Frame_sel7_fReverb => x_1.Frame_sel7_fReverb
              , Frame_sel8_fAddr => x_1.Frame_sel8_fAddr
              , Frame_sel9_fDryL => x_1.Frame_sel9_fDryL
              , Frame_sel10_fDryR => x_1.Frame_sel10_fDryR
              , Frame_sel11_fWetL => x_1.Frame_sel11_fWetL
              , Frame_sel12_fWetR => x_1.Frame_sel12_fWetR
              , Frame_sel13_fFbL => x_1.Frame_sel13_fFbL
              , Frame_sel14_fFbR => x_1.Frame_sel14_fFbR
              , Frame_sel15_fEqLowL => x_1.Frame_sel15_fEqLowL
              , Frame_sel16_fEqLowR => x_1.Frame_sel16_fEqLowR
              , Frame_sel17_fEqMidL => x_1.Frame_sel17_fEqMidL
              , Frame_sel18_fEqMidR => x_1.Frame_sel18_fEqMidR
              , Frame_sel19_fEqHighL => x_1.Frame_sel19_fEqHighL
              , Frame_sel20_fEqHighR => x_1.Frame_sel20_fEqHighR
              , Frame_sel21_fEqHighLpL => x_1.Frame_sel21_fEqHighLpL
              , Frame_sel22_fEqHighLpR => x_1.Frame_sel22_fEqHighLpR
              , Frame_sel23_fAccL => x_1.Frame_sel23_fAccL
              , Frame_sel24_fAccR => x_1.Frame_sel24_fAccR
              , Frame_sel25_fAcc2L => x_1.Frame_sel25_fAcc2L
              , Frame_sel26_fAcc2R => x_1.Frame_sel26_fAcc2R
              , Frame_sel27_fAcc3L => \c$app_arg_2\
              , Frame_sel28_fAcc3R => \c$app_arg_1\ );

  \c$app_arg_1\ <= resize((resize(x_1.Frame_sel12_fWetR,48)) * \c$app_arg_3\, 48) when \on\ else
                   to_signed(0,48);

  \c$app_arg_2\ <= resize((resize(x_1.Frame_sel11_fWetL,48)) * \c$app_arg_3\, 48) when \on\ else
                   to_signed(0,48);

  \c$bv\ <= (x_1.Frame_sel3_fGate);

  \on\ <= (\c$bv\(5 downto 5)) = std_logic_vector'("1");

  \c$bv_0\ <= (x_1.Frame_sel7_fReverb);

  \c$app_arg_3\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector((unsigned((\c$bv_0\(7 downto 0)))))))))))),48);

  -- register begin
  reverbToneBlendPipe_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      reverbToneBlendPipe <= std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      reverbToneBlendPipe <= result_2;
    end if;
  end process;
  -- register end

  with (ds1(843 downto 843)) select
    result_2 <= std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                std_logic_vector'("1" & ((std_logic_vector(\c$case_alt_2\.Frame_sel0_fL)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel1_fR)
                 & clash_lowpass_fir_types.toSLV(\c$case_alt_2\.Frame_sel2_fLast)
                 & \c$case_alt_2\.Frame_sel3_fGate
                 & \c$case_alt_2\.Frame_sel4_fOd
                 & \c$case_alt_2\.Frame_sel5_fDist
                 & \c$case_alt_2\.Frame_sel6_fEq
                 & \c$case_alt_2\.Frame_sel7_fReverb
                 & std_logic_vector(\c$case_alt_2\.Frame_sel8_fAddr)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel9_fDryL)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel10_fDryR)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel11_fWetL)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel12_fWetR)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel13_fFbL)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel14_fFbR)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel15_fEqLowL)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel16_fEqLowR)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel17_fEqMidL)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel18_fEqMidR)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel19_fEqHighL)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel20_fEqHighR)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel21_fEqHighLpL)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel22_fEqHighLpR)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel23_fAccL)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel24_fAccR)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel25_fAcc2L)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel26_fAcc2R)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel27_fAcc3L)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel28_fAcc3R)))) when others;

  \c$shI\ <= (to_signed(8,64));

  capp_arg_4_shiftR : block
    signal sh : natural;
  begin
    sh <=
        -- pragma translate_off
        natural'high when (\c$shI\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI\);
    \c$app_arg_4\ <= shift_right((x.Frame_sel23_fAccL + x.Frame_sel25_fAcc2L),sh)
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
    \c$app_arg_5\ <= shift_right((x.Frame_sel24_fAccR + x.Frame_sel26_fAcc2R),sh_0)
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
                    , Frame_sel7_fReverb => x.Frame_sel7_fReverb
                    , Frame_sel8_fAddr => x.Frame_sel8_fAddr
                    , Frame_sel9_fDryL => x.Frame_sel9_fDryL
                    , Frame_sel10_fDryR => x.Frame_sel10_fDryR
                    , Frame_sel11_fWetL => result_3
                    , Frame_sel12_fWetR => result_4
                    , Frame_sel13_fFbL => x.Frame_sel13_fFbL
                    , Frame_sel14_fFbR => x.Frame_sel14_fFbR
                    , Frame_sel15_fEqLowL => x.Frame_sel15_fEqLowL
                    , Frame_sel16_fEqLowR => x.Frame_sel16_fEqLowR
                    , Frame_sel17_fEqMidL => x.Frame_sel17_fEqMidL
                    , Frame_sel18_fEqMidR => x.Frame_sel18_fEqMidR
                    , Frame_sel19_fEqHighL => x.Frame_sel19_fEqHighL
                    , Frame_sel20_fEqHighR => x.Frame_sel20_fEqHighR
                    , Frame_sel21_fEqHighLpL => x.Frame_sel21_fEqHighLpL
                    , Frame_sel22_fEqHighLpR => x.Frame_sel22_fEqHighLpR
                    , Frame_sel23_fAccL => x.Frame_sel23_fAccL
                    , Frame_sel24_fAccR => x.Frame_sel24_fAccR
                    , Frame_sel25_fAcc2L => x.Frame_sel25_fAcc2L
                    , Frame_sel26_fAcc2R => x.Frame_sel26_fAcc2R
                    , Frame_sel27_fAcc3L => x.Frame_sel27_fAcc3L
                    , Frame_sel28_fAcc3R => x.Frame_sel28_fAcc3R );

  x <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1(842 downto 0)));

  -- register begin
  ds1_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1 <= std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1 <= result_5;
    end if;
  end process;
  -- register end

  with (\c$ds1_app_arg\(843 downto 843)) select
    result_5 <= std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                std_logic_vector'("1" & ((std_logic_vector(x_0.Frame_sel0_fL)
                 & std_logic_vector(x_0.Frame_sel1_fR)
                 & clash_lowpass_fir_types.toSLV(x_0.Frame_sel2_fLast)
                 & x_0.Frame_sel3_fGate
                 & x_0.Frame_sel4_fOd
                 & x_0.Frame_sel5_fDist
                 & x_0.Frame_sel6_fEq
                 & x_0.Frame_sel7_fReverb
                 & std_logic_vector(x_0.Frame_sel8_fAddr)
                 & std_logic_vector(x_0.Frame_sel9_fDryL)
                 & std_logic_vector(x_0.Frame_sel10_fDryR)
                 & std_logic_vector(x_0.Frame_sel11_fWetL)
                 & std_logic_vector(x_0.Frame_sel12_fWetR)
                 & std_logic_vector(x_0.Frame_sel13_fFbL)
                 & std_logic_vector(x_0.Frame_sel14_fFbR)
                 & std_logic_vector(x_0.Frame_sel15_fEqLowL)
                 & std_logic_vector(x_0.Frame_sel16_fEqLowR)
                 & std_logic_vector(x_0.Frame_sel17_fEqMidL)
                 & std_logic_vector(x_0.Frame_sel18_fEqMidR)
                 & std_logic_vector(x_0.Frame_sel19_fEqHighL)
                 & std_logic_vector(x_0.Frame_sel20_fEqHighR)
                 & std_logic_vector(x_0.Frame_sel21_fEqHighLpL)
                 & std_logic_vector(x_0.Frame_sel22_fEqHighLpR)
                 & std_logic_vector(resize((resize(result_8,48)) * \c$app_arg_7\, 48))
                 & std_logic_vector(resize((resize(result_7,48)) * \c$app_arg_7\, 48))
                 & std_logic_vector(resize((resize(reverbTonePrevL,48)) * \c$app_arg_6\, 48))
                 & std_logic_vector(resize((resize(reverbTonePrevR,48)) * \c$app_arg_6\, 48))
                 & std_logic_vector(x_0.Frame_sel27_fAcc3L)
                 & std_logic_vector(x_0.Frame_sel28_fAcc3R)))) when others;

  \c$app_arg_6\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(gain)))))))),48);

  gain <= to_unsigned(255,8) - \c$app_arg_8\;

  \c$app_arg_7\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(\c$app_arg_8\)))))))),48);

  \c$bv_1\ <= (x_0.Frame_sel7_fReverb);

  \c$app_arg_8\ <= unsigned((\c$bv_1\(15 downto 8)));

  x_0 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(\c$ds1_app_arg\(842 downto 0)));

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

  with (reverbToneBlendPipe(843 downto 843)) select
    \c$reverbTonePrevR_app_arg\ <= reverbTonePrevR when "0",
                                   x_1.Frame_sel12_fWetR when others;

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

  with (reverbToneBlendPipe(843 downto 843)) select
    \c$reverbTonePrevL_app_arg\ <= reverbTonePrevL when "0",
                                   x_1.Frame_sel11_fWetL when others;

  x_1 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(reverbToneBlendPipe(842 downto 0)));

  -- register begin
  cds1_app_arg_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      \c$ds1_app_arg\ <= std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      \c$ds1_app_arg\ <= result_6;
    end if;
  end process;
  -- register end

  f_0 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(eqMixPipe(842 downto 0)));

  with (eqMixPipe(843 downto 843)) select
    result_6 <= std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                std_logic_vector'("1" & ((std_logic_vector(f_0.Frame_sel0_fL)
                 & std_logic_vector(f_0.Frame_sel1_fR)
                 & clash_lowpass_fir_types.toSLV(f_0.Frame_sel2_fLast)
                 & f_0.Frame_sel3_fGate
                 & f_0.Frame_sel4_fOd
                 & f_0.Frame_sel5_fDist
                 & f_0.Frame_sel6_fEq
                 & f_0.Frame_sel7_fReverb
                 & std_logic_vector(reverbAddr)
                 & std_logic_vector(f_0.Frame_sel0_fL)
                 & std_logic_vector(f_0.Frame_sel1_fR)
                 & std_logic_vector(f_0.Frame_sel11_fWetL)
                 & std_logic_vector(f_0.Frame_sel12_fWetR)
                 & std_logic_vector(f_0.Frame_sel13_fFbL)
                 & std_logic_vector(f_0.Frame_sel14_fFbR)
                 & std_logic_vector(f_0.Frame_sel15_fEqLowL)
                 & std_logic_vector(f_0.Frame_sel16_fEqLowR)
                 & std_logic_vector(f_0.Frame_sel17_fEqMidL)
                 & std_logic_vector(f_0.Frame_sel18_fEqMidR)
                 & std_logic_vector(f_0.Frame_sel19_fEqHighL)
                 & std_logic_vector(f_0.Frame_sel20_fEqHighR)
                 & std_logic_vector(f_0.Frame_sel21_fEqHighLpL)
                 & std_logic_vector(f_0.Frame_sel22_fEqHighLpR)
                 & std_logic_vector(f_0.Frame_sel23_fAccL)
                 & std_logic_vector(f_0.Frame_sel24_fAccR)
                 & std_logic_vector(f_0.Frame_sel25_fAcc2L)
                 & std_logic_vector(f_0.Frame_sel26_fAcc2R)
                 & std_logic_vector(f_0.Frame_sel27_fAcc3L)
                 & std_logic_vector(f_0.Frame_sel28_fAcc3R)))) when others;

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

  with (eta2(34 downto 34)) select
    ds <= ( Tuple2_sel0_index_1024 => clash_lowpass_fir_types.index_1024'(0 to 9 => '-')
          , Tuple2_sel1_signed => signed'(0 to 23 => '-') ) when "0",
          a1 when others;

  a1 <= clash_lowpass_fir_types.Tuple2'(clash_lowpass_fir_types.fromSLV(eta2(33 downto 0)));

  with (eta2(34 downto 34)) select
    \c$ds1_app_arg_0\ <= false when "0",
                         true when others;

  with (outPipe(843 downto 843)) select
    eta2 <= std_logic_vector'("0" & "----------------------------------") when "0",
            std_logic_vector'("1" & ((std_logic_vector(f_1.Frame_sel8_fAddr)
             & std_logic_vector(f_1.Frame_sel14_fFbR)))) when others;

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

  with (eta2_0(34 downto 34)) select
    ds_0 <= ( Tuple2_sel0_index_1024 => clash_lowpass_fir_types.index_1024'(0 to 9 => '-')
            , Tuple2_sel1_signed => signed'(0 to 23 => '-') ) when "0",
            a1_0 when others;

  a1_0 <= clash_lowpass_fir_types.Tuple2'(clash_lowpass_fir_types.fromSLV(eta2_0(33 downto 0)));

  with (eta2_0(34 downto 34)) select
    \c$ds1_app_arg_1\ <= false when "0",
                         true when others;

  with (outPipe(843 downto 843)) select
    eta2_0 <= std_logic_vector'("0" & "----------------------------------") when "0",
              std_logic_vector'("1" & ((std_logic_vector(f_1.Frame_sel8_fAddr)
               & std_logic_vector(f_1.Frame_sel13_fFbL)))) when others;

  f_1 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(outPipe(842 downto 0)));

  -- register begin
  outPipe_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      outPipe <= std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      outPipe <= result_9;
    end if;
  end process;
  -- register end

  with (ds1_0(843 downto 843)) select
    result_9 <= std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                std_logic_vector'("1" & ((std_logic_vector(result_12.Frame_sel0_fL)
                 & std_logic_vector(result_12.Frame_sel1_fR)
                 & clash_lowpass_fir_types.toSLV(result_12.Frame_sel2_fLast)
                 & result_12.Frame_sel3_fGate
                 & result_12.Frame_sel4_fOd
                 & result_12.Frame_sel5_fDist
                 & result_12.Frame_sel6_fEq
                 & result_12.Frame_sel7_fReverb
                 & std_logic_vector(result_12.Frame_sel8_fAddr)
                 & std_logic_vector(result_12.Frame_sel9_fDryL)
                 & std_logic_vector(result_12.Frame_sel10_fDryR)
                 & std_logic_vector(result_12.Frame_sel11_fWetL)
                 & std_logic_vector(result_12.Frame_sel12_fWetR)
                 & std_logic_vector(result_12.Frame_sel13_fFbL)
                 & std_logic_vector(result_12.Frame_sel14_fFbR)
                 & std_logic_vector(result_12.Frame_sel15_fEqLowL)
                 & std_logic_vector(result_12.Frame_sel16_fEqLowR)
                 & std_logic_vector(result_12.Frame_sel17_fEqMidL)
                 & std_logic_vector(result_12.Frame_sel18_fEqMidR)
                 & std_logic_vector(result_12.Frame_sel19_fEqHighL)
                 & std_logic_vector(result_12.Frame_sel20_fEqHighR)
                 & std_logic_vector(result_12.Frame_sel21_fEqHighLpL)
                 & std_logic_vector(result_12.Frame_sel22_fEqHighLpR)
                 & std_logic_vector(result_12.Frame_sel23_fAccL)
                 & std_logic_vector(result_12.Frame_sel24_fAccR)
                 & std_logic_vector(result_12.Frame_sel25_fAcc2L)
                 & std_logic_vector(result_12.Frame_sel26_fAcc2R)
                 & std_logic_vector(result_12.Frame_sel27_fAcc3L)
                 & std_logic_vector(result_12.Frame_sel28_fAcc3R)))) when others;

  \c$shI_1\ <= (to_signed(8,64));

  capp_arg_9_shiftR : block
    signal sh_1 : natural;
  begin
    sh_1 <=
        -- pragma translate_off
        natural'high when (\c$shI_1\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_1\);
    \c$app_arg_9\ <= shift_right((x_2.Frame_sel23_fAccL + x_2.Frame_sel25_fAcc2L),sh_1)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_1\ <= \c$app_arg_9\ < to_signed(-8388608,48);

  \c$case_alt_3\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_1\ else
                    resize(\c$app_arg_9\,24);

  result_selection_res_4 <= \c$app_arg_9\ > to_signed(8388607,48);

  result_10 <= to_signed(8388607,24) when result_selection_res_4 else
               \c$case_alt_3\;

  \c$app_arg_10\ <= result_10 when \on_0\ else
                    x_2.Frame_sel9_fDryL;

  \c$shI_2\ <= (to_signed(8,64));

  capp_arg_11_shiftR : block
    signal sh_2 : natural;
  begin
    sh_2 <=
        -- pragma translate_off
        natural'high when (\c$shI_2\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_2\);
    \c$app_arg_11\ <= shift_right((x_2.Frame_sel24_fAccR + x_2.Frame_sel26_fAcc2R),sh_2)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_2\ <= \c$app_arg_11\ < to_signed(-8388608,48);

  \c$case_alt_4\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_2\ else
                    resize(\c$app_arg_11\,24);

  result_selection_res_5 <= \c$app_arg_11\ > to_signed(8388607,48);

  result_11 <= to_signed(8388607,24) when result_selection_res_5 else
               \c$case_alt_4\;

  \c$app_arg_12\ <= result_11 when \on_0\ else
                    x_2.Frame_sel10_fDryR;

  result_12 <= ( Frame_sel0_fL => \c$app_arg_10\
               , Frame_sel1_fR => \c$app_arg_12\
               , Frame_sel2_fLast => x_2.Frame_sel2_fLast
               , Frame_sel3_fGate => x_2.Frame_sel3_fGate
               , Frame_sel4_fOd => x_2.Frame_sel4_fOd
               , Frame_sel5_fDist => x_2.Frame_sel5_fDist
               , Frame_sel6_fEq => x_2.Frame_sel6_fEq
               , Frame_sel7_fReverb => x_2.Frame_sel7_fReverb
               , Frame_sel8_fAddr => x_2.Frame_sel8_fAddr
               , Frame_sel9_fDryL => x_2.Frame_sel9_fDryL
               , Frame_sel10_fDryR => x_2.Frame_sel10_fDryR
               , Frame_sel11_fWetL => x_2.Frame_sel11_fWetL
               , Frame_sel12_fWetR => x_2.Frame_sel12_fWetR
               , Frame_sel13_fFbL => x_2.Frame_sel13_fFbL
               , Frame_sel14_fFbR => x_2.Frame_sel14_fFbR
               , Frame_sel15_fEqLowL => x_2.Frame_sel15_fEqLowL
               , Frame_sel16_fEqLowR => x_2.Frame_sel16_fEqLowR
               , Frame_sel17_fEqMidL => x_2.Frame_sel17_fEqMidL
               , Frame_sel18_fEqMidR => x_2.Frame_sel18_fEqMidR
               , Frame_sel19_fEqHighL => x_2.Frame_sel19_fEqHighL
               , Frame_sel20_fEqHighR => x_2.Frame_sel20_fEqHighR
               , Frame_sel21_fEqHighLpL => x_2.Frame_sel21_fEqHighLpL
               , Frame_sel22_fEqHighLpR => x_2.Frame_sel22_fEqHighLpR
               , Frame_sel23_fAccL => x_2.Frame_sel23_fAccL
               , Frame_sel24_fAccR => x_2.Frame_sel24_fAccR
               , Frame_sel25_fAcc2L => x_2.Frame_sel25_fAcc2L
               , Frame_sel26_fAcc2R => x_2.Frame_sel26_fAcc2R
               , Frame_sel27_fAcc3L => x_2.Frame_sel27_fAcc3L
               , Frame_sel28_fAcc3R => x_2.Frame_sel28_fAcc3R );

  \c$bv_2\ <= (x_2.Frame_sel3_fGate);

  \on_0\ <= (\c$bv_2\(5 downto 5)) = std_logic_vector'("1");

  x_2 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_0(842 downto 0)));

  -- register begin
  ds1_0_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_0 <= std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_0 <= result_13;
    end if;
  end process;
  -- register end

  with (ds1_1(843 downto 843)) select
    result_13 <= std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(result_14.Frame_sel0_fL)
                  & std_logic_vector(result_14.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(result_14.Frame_sel2_fLast)
                  & result_14.Frame_sel3_fGate
                  & result_14.Frame_sel4_fOd
                  & result_14.Frame_sel5_fDist
                  & result_14.Frame_sel6_fEq
                  & result_14.Frame_sel7_fReverb
                  & std_logic_vector(result_14.Frame_sel8_fAddr)
                  & std_logic_vector(result_14.Frame_sel9_fDryL)
                  & std_logic_vector(result_14.Frame_sel10_fDryR)
                  & std_logic_vector(result_14.Frame_sel11_fWetL)
                  & std_logic_vector(result_14.Frame_sel12_fWetR)
                  & std_logic_vector(result_14.Frame_sel13_fFbL)
                  & std_logic_vector(result_14.Frame_sel14_fFbR)
                  & std_logic_vector(result_14.Frame_sel15_fEqLowL)
                  & std_logic_vector(result_14.Frame_sel16_fEqLowR)
                  & std_logic_vector(result_14.Frame_sel17_fEqMidL)
                  & std_logic_vector(result_14.Frame_sel18_fEqMidR)
                  & std_logic_vector(result_14.Frame_sel19_fEqHighL)
                  & std_logic_vector(result_14.Frame_sel20_fEqHighR)
                  & std_logic_vector(result_14.Frame_sel21_fEqHighLpL)
                  & std_logic_vector(result_14.Frame_sel22_fEqHighLpR)
                  & std_logic_vector(result_14.Frame_sel23_fAccL)
                  & std_logic_vector(result_14.Frame_sel24_fAccR)
                  & std_logic_vector(result_14.Frame_sel25_fAcc2L)
                  & std_logic_vector(result_14.Frame_sel26_fAcc2R)
                  & std_logic_vector(result_14.Frame_sel27_fAcc3L)
                  & std_logic_vector(result_14.Frame_sel28_fAcc3R)))) when others;

  result_14 <= ( Frame_sel0_fL => x_3.Frame_sel0_fL
               , Frame_sel1_fR => x_3.Frame_sel1_fR
               , Frame_sel2_fLast => x_3.Frame_sel2_fLast
               , Frame_sel3_fGate => x_3.Frame_sel3_fGate
               , Frame_sel4_fOd => x_3.Frame_sel4_fOd
               , Frame_sel5_fDist => x_3.Frame_sel5_fDist
               , Frame_sel6_fEq => x_3.Frame_sel6_fEq
               , Frame_sel7_fReverb => x_3.Frame_sel7_fReverb
               , Frame_sel8_fAddr => x_3.Frame_sel8_fAddr
               , Frame_sel9_fDryL => x_3.Frame_sel9_fDryL
               , Frame_sel10_fDryR => x_3.Frame_sel10_fDryR
               , Frame_sel11_fWetL => x_3.Frame_sel11_fWetL
               , Frame_sel12_fWetR => x_3.Frame_sel12_fWetR
               , Frame_sel13_fFbL => x_3.Frame_sel13_fFbL
               , Frame_sel14_fFbR => x_3.Frame_sel14_fFbR
               , Frame_sel15_fEqLowL => x_3.Frame_sel15_fEqLowL
               , Frame_sel16_fEqLowR => x_3.Frame_sel16_fEqLowR
               , Frame_sel17_fEqMidL => x_3.Frame_sel17_fEqMidL
               , Frame_sel18_fEqMidR => x_3.Frame_sel18_fEqMidR
               , Frame_sel19_fEqHighL => x_3.Frame_sel19_fEqHighL
               , Frame_sel20_fEqHighR => x_3.Frame_sel20_fEqHighR
               , Frame_sel21_fEqHighLpL => x_3.Frame_sel21_fEqHighLpL
               , Frame_sel22_fEqHighLpR => x_3.Frame_sel22_fEqHighLpR
               , Frame_sel23_fAccL => \c$app_arg_17\
               , Frame_sel24_fAccR => \c$app_arg_16\
               , Frame_sel25_fAcc2L => \c$app_arg_14\
               , Frame_sel26_fAcc2R => \c$app_arg_13\
               , Frame_sel27_fAcc3L => x_3.Frame_sel27_fAcc3L
               , Frame_sel28_fAcc3R => x_3.Frame_sel28_fAcc3R );

  \c$app_arg_13\ <= resize((resize(x_3.Frame_sel12_fWetR,48)) * \c$app_arg_15\, 48) when \on_1\ else
                    to_signed(0,48);

  \c$app_arg_14\ <= resize((resize(x_3.Frame_sel11_fWetL,48)) * \c$app_arg_15\, 48) when \on_1\ else
                    to_signed(0,48);

  \c$app_arg_15\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(mixGain)))))))),48);

  \c$app_arg_16\ <= resize((resize(x_3.Frame_sel10_fDryR,48)) * \c$app_arg_18\, 48) when \on_1\ else
                    to_signed(0,48);

  \c$app_arg_17\ <= resize((resize(x_3.Frame_sel9_fDryL,48)) * \c$app_arg_18\, 48) when \on_1\ else
                    to_signed(0,48);

  \c$bv_3\ <= (x_3.Frame_sel3_fGate);

  \on_1\ <= (\c$bv_3\(5 downto 5)) = std_logic_vector'("1");

  \c$app_arg_18\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(invMixGain)))))))),48);

  invMixGain <= to_unsigned(256,9) - (resize(mixGain,9));

  \c$bv_4\ <= (x_3.Frame_sel7_fReverb);

  mixGain <= unsigned((\c$bv_4\(23 downto 16)));

  x_3 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_1(842 downto 0)));

  -- register begin
  ds1_1_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_1 <= std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_1 <= result_15;
    end if;
  end process;
  -- register end

  with (ds1_2(843 downto 843)) select
    result_15 <= std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(result_18.Frame_sel0_fL)
                  & std_logic_vector(result_18.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(result_18.Frame_sel2_fLast)
                  & result_18.Frame_sel3_fGate
                  & result_18.Frame_sel4_fOd
                  & result_18.Frame_sel5_fDist
                  & result_18.Frame_sel6_fEq
                  & result_18.Frame_sel7_fReverb
                  & std_logic_vector(result_18.Frame_sel8_fAddr)
                  & std_logic_vector(result_18.Frame_sel9_fDryL)
                  & std_logic_vector(result_18.Frame_sel10_fDryR)
                  & std_logic_vector(result_18.Frame_sel11_fWetL)
                  & std_logic_vector(result_18.Frame_sel12_fWetR)
                  & std_logic_vector(result_18.Frame_sel13_fFbL)
                  & std_logic_vector(result_18.Frame_sel14_fFbR)
                  & std_logic_vector(result_18.Frame_sel15_fEqLowL)
                  & std_logic_vector(result_18.Frame_sel16_fEqLowR)
                  & std_logic_vector(result_18.Frame_sel17_fEqMidL)
                  & std_logic_vector(result_18.Frame_sel18_fEqMidR)
                  & std_logic_vector(result_18.Frame_sel19_fEqHighL)
                  & std_logic_vector(result_18.Frame_sel20_fEqHighR)
                  & std_logic_vector(result_18.Frame_sel21_fEqHighLpL)
                  & std_logic_vector(result_18.Frame_sel22_fEqHighLpR)
                  & std_logic_vector(result_18.Frame_sel23_fAccL)
                  & std_logic_vector(result_18.Frame_sel24_fAccR)
                  & std_logic_vector(result_18.Frame_sel25_fAcc2L)
                  & std_logic_vector(result_18.Frame_sel26_fAcc2R)
                  & std_logic_vector(result_18.Frame_sel27_fAcc3L)
                  & std_logic_vector(result_18.Frame_sel28_fAcc3R)))) when others;

  \c$shI_3\ <= (to_signed(1,64));

  capp_arg_19_shiftR : block
    signal sh_3 : natural;
  begin
    sh_3 <=
        -- pragma translate_off
        natural'high when (\c$shI_3\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_3\);
    \c$app_arg_19\ <= shift_right((resize(x_6.Frame_sel9_fDryL,48)),sh_3)
        -- pragma translate_off
        when ((to_signed(1,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$shI_4\ <= (to_signed(8,64));

  capp_arg_20_shiftR : block
    signal sh_4 : natural;
  begin
    sh_4 <=
        -- pragma translate_off
        natural'high when (\c$shI_4\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_4\);
    \c$app_arg_20\ <= shift_right(x_6.Frame_sel27_fAcc3L,sh_4)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  x_4 <= \c$app_arg_19\ + \c$app_arg_20\;

  \c$case_alt_selection_res_3\ <= x_4 < to_signed(-8388608,48);

  \c$case_alt_5\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_3\ else
                    resize(x_4,24);

  result_selection_res_6 <= x_4 > to_signed(8388607,48);

  result_16 <= to_signed(8388607,24) when result_selection_res_6 else
               \c$case_alt_5\;

  \c$app_arg_21\ <= result_16 when \on_2\ else
                    to_signed(0,24);

  \c$shI_5\ <= (to_signed(1,64));

  capp_arg_22_shiftR : block
    signal sh_5 : natural;
  begin
    sh_5 <=
        -- pragma translate_off
        natural'high when (\c$shI_5\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_5\);
    \c$app_arg_22\ <= shift_right((resize(x_6.Frame_sel10_fDryR,48)),sh_5)
        -- pragma translate_off
        when ((to_signed(1,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$shI_6\ <= (to_signed(8,64));

  capp_arg_23_shiftR : block
    signal sh_6 : natural;
  begin
    sh_6 <=
        -- pragma translate_off
        natural'high when (\c$shI_6\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_6\);
    \c$app_arg_23\ <= shift_right(x_6.Frame_sel28_fAcc3R,sh_6)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  x_5 <= \c$app_arg_22\ + \c$app_arg_23\;

  \c$case_alt_selection_res_4\ <= x_5 < to_signed(-8388608,48);

  \c$case_alt_6\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_4\ else
                    resize(x_5,24);

  result_selection_res_7 <= x_5 > to_signed(8388607,48);

  result_17 <= to_signed(8388607,24) when result_selection_res_7 else
               \c$case_alt_6\;

  \c$app_arg_24\ <= result_17 when \on_2\ else
                    to_signed(0,24);

  result_18 <= ( Frame_sel0_fL => x_6.Frame_sel0_fL
               , Frame_sel1_fR => x_6.Frame_sel1_fR
               , Frame_sel2_fLast => x_6.Frame_sel2_fLast
               , Frame_sel3_fGate => x_6.Frame_sel3_fGate
               , Frame_sel4_fOd => x_6.Frame_sel4_fOd
               , Frame_sel5_fDist => x_6.Frame_sel5_fDist
               , Frame_sel6_fEq => x_6.Frame_sel6_fEq
               , Frame_sel7_fReverb => x_6.Frame_sel7_fReverb
               , Frame_sel8_fAddr => x_6.Frame_sel8_fAddr
               , Frame_sel9_fDryL => x_6.Frame_sel9_fDryL
               , Frame_sel10_fDryR => x_6.Frame_sel10_fDryR
               , Frame_sel11_fWetL => x_6.Frame_sel11_fWetL
               , Frame_sel12_fWetR => x_6.Frame_sel12_fWetR
               , Frame_sel13_fFbL => \c$app_arg_21\
               , Frame_sel14_fFbR => \c$app_arg_24\
               , Frame_sel15_fEqLowL => x_6.Frame_sel15_fEqLowL
               , Frame_sel16_fEqLowR => x_6.Frame_sel16_fEqLowR
               , Frame_sel17_fEqMidL => x_6.Frame_sel17_fEqMidL
               , Frame_sel18_fEqMidR => x_6.Frame_sel18_fEqMidR
               , Frame_sel19_fEqHighL => x_6.Frame_sel19_fEqHighL
               , Frame_sel20_fEqHighR => x_6.Frame_sel20_fEqHighR
               , Frame_sel21_fEqHighLpL => x_6.Frame_sel21_fEqHighLpL
               , Frame_sel22_fEqHighLpR => x_6.Frame_sel22_fEqHighLpR
               , Frame_sel23_fAccL => x_6.Frame_sel23_fAccL
               , Frame_sel24_fAccR => x_6.Frame_sel24_fAccR
               , Frame_sel25_fAcc2L => x_6.Frame_sel25_fAcc2L
               , Frame_sel26_fAcc2R => x_6.Frame_sel26_fAcc2R
               , Frame_sel27_fAcc3L => x_6.Frame_sel27_fAcc3L
               , Frame_sel28_fAcc3R => x_6.Frame_sel28_fAcc3R );

  \c$bv_5\ <= (x_6.Frame_sel3_fGate);

  \on_2\ <= (\c$bv_5\(5 downto 5)) = std_logic_vector'("1");

  x_6 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_2(842 downto 0)));

  -- register begin
  ds1_2_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_2 <= std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_2 <= \c$ds1_app_arg_2\;
    end if;
  end process;
  -- register end

  with (reverbToneBlendPipe(843 downto 843)) select
    \c$ds1_app_arg_2\ <= std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                         std_logic_vector'("1" & ((std_logic_vector(result_1.Frame_sel0_fL)
                          & std_logic_vector(result_1.Frame_sel1_fR)
                          & clash_lowpass_fir_types.toSLV(result_1.Frame_sel2_fLast)
                          & result_1.Frame_sel3_fGate
                          & result_1.Frame_sel4_fOd
                          & result_1.Frame_sel5_fDist
                          & result_1.Frame_sel6_fEq
                          & result_1.Frame_sel7_fReverb
                          & std_logic_vector(result_1.Frame_sel8_fAddr)
                          & std_logic_vector(result_1.Frame_sel9_fDryL)
                          & std_logic_vector(result_1.Frame_sel10_fDryR)
                          & std_logic_vector(result_1.Frame_sel11_fWetL)
                          & std_logic_vector(result_1.Frame_sel12_fWetR)
                          & std_logic_vector(result_1.Frame_sel13_fFbL)
                          & std_logic_vector(result_1.Frame_sel14_fFbR)
                          & std_logic_vector(result_1.Frame_sel15_fEqLowL)
                          & std_logic_vector(result_1.Frame_sel16_fEqLowR)
                          & std_logic_vector(result_1.Frame_sel17_fEqMidL)
                          & std_logic_vector(result_1.Frame_sel18_fEqMidR)
                          & std_logic_vector(result_1.Frame_sel19_fEqHighL)
                          & std_logic_vector(result_1.Frame_sel20_fEqHighR)
                          & std_logic_vector(result_1.Frame_sel21_fEqHighLpL)
                          & std_logic_vector(result_1.Frame_sel22_fEqHighLpR)
                          & std_logic_vector(result_1.Frame_sel23_fAccL)
                          & std_logic_vector(result_1.Frame_sel24_fAccR)
                          & std_logic_vector(result_1.Frame_sel25_fAcc2L)
                          & std_logic_vector(result_1.Frame_sel26_fAcc2R)
                          & std_logic_vector(result_1.Frame_sel27_fAcc3L)
                          & std_logic_vector(result_1.Frame_sel28_fAcc3R)))) when others;

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

  with (eqMixPipe(843 downto 843)) select
    \c$reverbAddr_app_arg\ <= reverbAddr when "0",
                              \c$reverbAddr_case_alt\ when others;

  -- register begin
  eqMixPipe_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      eqMixPipe <= std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      eqMixPipe <= result_19;
    end if;
  end process;
  -- register end

  with (ds1_3(843 downto 843)) select
    result_19 <= std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(result_20.Frame_sel0_fL)
                  & std_logic_vector(result_20.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(result_20.Frame_sel2_fLast)
                  & result_20.Frame_sel3_fGate
                  & result_20.Frame_sel4_fOd
                  & result_20.Frame_sel5_fDist
                  & result_20.Frame_sel6_fEq
                  & result_20.Frame_sel7_fReverb
                  & std_logic_vector(result_20.Frame_sel8_fAddr)
                  & std_logic_vector(result_20.Frame_sel9_fDryL)
                  & std_logic_vector(result_20.Frame_sel10_fDryR)
                  & std_logic_vector(result_20.Frame_sel11_fWetL)
                  & std_logic_vector(result_20.Frame_sel12_fWetR)
                  & std_logic_vector(result_20.Frame_sel13_fFbL)
                  & std_logic_vector(result_20.Frame_sel14_fFbR)
                  & std_logic_vector(result_20.Frame_sel15_fEqLowL)
                  & std_logic_vector(result_20.Frame_sel16_fEqLowR)
                  & std_logic_vector(result_20.Frame_sel17_fEqMidL)
                  & std_logic_vector(result_20.Frame_sel18_fEqMidR)
                  & std_logic_vector(result_20.Frame_sel19_fEqHighL)
                  & std_logic_vector(result_20.Frame_sel20_fEqHighR)
                  & std_logic_vector(result_20.Frame_sel21_fEqHighLpL)
                  & std_logic_vector(result_20.Frame_sel22_fEqHighLpR)
                  & std_logic_vector(result_20.Frame_sel23_fAccL)
                  & std_logic_vector(result_20.Frame_sel24_fAccR)
                  & std_logic_vector(result_20.Frame_sel25_fAcc2L)
                  & std_logic_vector(result_20.Frame_sel26_fAcc2R)
                  & std_logic_vector(result_20.Frame_sel27_fAcc3L)
                  & std_logic_vector(result_20.Frame_sel28_fAcc3R)))) when others;

  \c$bv_6\ <= (x_7.Frame_sel3_fGate);

  \on_3\ <= (\c$bv_6\(3 downto 3)) = std_logic_vector'("1");

  result_20 <= ( Frame_sel0_fL => \c$app_arg_27\
               , Frame_sel1_fR => \c$app_arg_25\
               , Frame_sel2_fLast => x_7.Frame_sel2_fLast
               , Frame_sel3_fGate => x_7.Frame_sel3_fGate
               , Frame_sel4_fOd => x_7.Frame_sel4_fOd
               , Frame_sel5_fDist => x_7.Frame_sel5_fDist
               , Frame_sel6_fEq => x_7.Frame_sel6_fEq
               , Frame_sel7_fReverb => x_7.Frame_sel7_fReverb
               , Frame_sel8_fAddr => x_7.Frame_sel8_fAddr
               , Frame_sel9_fDryL => x_7.Frame_sel9_fDryL
               , Frame_sel10_fDryR => x_7.Frame_sel10_fDryR
               , Frame_sel11_fWetL => x_7.Frame_sel11_fWetL
               , Frame_sel12_fWetR => x_7.Frame_sel12_fWetR
               , Frame_sel13_fFbL => x_7.Frame_sel13_fFbL
               , Frame_sel14_fFbR => x_7.Frame_sel14_fFbR
               , Frame_sel15_fEqLowL => x_7.Frame_sel15_fEqLowL
               , Frame_sel16_fEqLowR => x_7.Frame_sel16_fEqLowR
               , Frame_sel17_fEqMidL => x_7.Frame_sel17_fEqMidL
               , Frame_sel18_fEqMidR => x_7.Frame_sel18_fEqMidR
               , Frame_sel19_fEqHighL => x_7.Frame_sel19_fEqHighL
               , Frame_sel20_fEqHighR => x_7.Frame_sel20_fEqHighR
               , Frame_sel21_fEqHighLpL => x_7.Frame_sel21_fEqHighLpL
               , Frame_sel22_fEqHighLpR => x_7.Frame_sel22_fEqHighLpR
               , Frame_sel23_fAccL => x_7.Frame_sel23_fAccL
               , Frame_sel24_fAccR => x_7.Frame_sel24_fAccR
               , Frame_sel25_fAcc2L => x_7.Frame_sel25_fAcc2L
               , Frame_sel26_fAcc2R => x_7.Frame_sel26_fAcc2R
               , Frame_sel27_fAcc3L => x_7.Frame_sel27_fAcc3L
               , Frame_sel28_fAcc3R => x_7.Frame_sel28_fAcc3R );

  \c$app_arg_25\ <= result_21 when \on_3\ else
                    x_7.Frame_sel1_fR;

  \c$case_alt_selection_res_5\ <= \c$app_arg_26\ < to_signed(-8388608,48);

  \c$case_alt_7\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_5\ else
                    resize(\c$app_arg_26\,24);

  result_selection_res_8 <= \c$app_arg_26\ > to_signed(8388607,48);

  result_21 <= to_signed(8388607,24) when result_selection_res_8 else
               \c$case_alt_7\;

  \c$shI_7\ <= (to_signed(7,64));

  capp_arg_26_shiftR : block
    signal sh_7 : natural;
  begin
    sh_7 <=
        -- pragma translate_off
        natural'high when (\c$shI_7\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_7\);
    \c$app_arg_26\ <= shift_right(((x_7.Frame_sel24_fAccR + x_7.Frame_sel26_fAcc2R) + x_7.Frame_sel28_fAcc3R),sh_7)
        -- pragma translate_off
        when ((to_signed(7,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_27\ <= result_22 when \on_3\ else
                    x_7.Frame_sel0_fL;

  \c$case_alt_selection_res_6\ <= \c$app_arg_28\ < to_signed(-8388608,48);

  \c$case_alt_8\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_6\ else
                    resize(\c$app_arg_28\,24);

  result_selection_res_9 <= \c$app_arg_28\ > to_signed(8388607,48);

  result_22 <= to_signed(8388607,24) when result_selection_res_9 else
               \c$case_alt_8\;

  \c$shI_8\ <= (to_signed(7,64));

  capp_arg_28_shiftR : block
    signal sh_8 : natural;
  begin
    sh_8 <=
        -- pragma translate_off
        natural'high when (\c$shI_8\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_8\);
    \c$app_arg_28\ <= shift_right(((x_7.Frame_sel23_fAccL + x_7.Frame_sel25_fAcc2L) + x_7.Frame_sel27_fAcc3L),sh_8)
        -- pragma translate_off
        when ((to_signed(7,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  x_7 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_3(842 downto 0)));

  -- register begin
  ds1_3_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_3 <= std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_3 <= result_23;
    end if;
  end process;
  -- register end

  with (ds1_4(843 downto 843)) select
    result_23 <= std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(result_24.Frame_sel0_fL)
                  & std_logic_vector(result_24.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(result_24.Frame_sel2_fLast)
                  & result_24.Frame_sel3_fGate
                  & result_24.Frame_sel4_fOd
                  & result_24.Frame_sel5_fDist
                  & result_24.Frame_sel6_fEq
                  & result_24.Frame_sel7_fReverb
                  & std_logic_vector(result_24.Frame_sel8_fAddr)
                  & std_logic_vector(result_24.Frame_sel9_fDryL)
                  & std_logic_vector(result_24.Frame_sel10_fDryR)
                  & std_logic_vector(result_24.Frame_sel11_fWetL)
                  & std_logic_vector(result_24.Frame_sel12_fWetR)
                  & std_logic_vector(result_24.Frame_sel13_fFbL)
                  & std_logic_vector(result_24.Frame_sel14_fFbR)
                  & std_logic_vector(result_24.Frame_sel15_fEqLowL)
                  & std_logic_vector(result_24.Frame_sel16_fEqLowR)
                  & std_logic_vector(result_24.Frame_sel17_fEqMidL)
                  & std_logic_vector(result_24.Frame_sel18_fEqMidR)
                  & std_logic_vector(result_24.Frame_sel19_fEqHighL)
                  & std_logic_vector(result_24.Frame_sel20_fEqHighR)
                  & std_logic_vector(result_24.Frame_sel21_fEqHighLpL)
                  & std_logic_vector(result_24.Frame_sel22_fEqHighLpR)
                  & std_logic_vector(result_24.Frame_sel23_fAccL)
                  & std_logic_vector(result_24.Frame_sel24_fAccR)
                  & std_logic_vector(result_24.Frame_sel25_fAcc2L)
                  & std_logic_vector(result_24.Frame_sel26_fAcc2R)
                  & std_logic_vector(result_24.Frame_sel27_fAcc3L)
                  & std_logic_vector(result_24.Frame_sel28_fAcc3R)))) when others;

  result_24 <= ( Frame_sel0_fL => x_8.Frame_sel0_fL
               , Frame_sel1_fR => x_8.Frame_sel1_fR
               , Frame_sel2_fLast => x_8.Frame_sel2_fLast
               , Frame_sel3_fGate => x_8.Frame_sel3_fGate
               , Frame_sel4_fOd => x_8.Frame_sel4_fOd
               , Frame_sel5_fDist => x_8.Frame_sel5_fDist
               , Frame_sel6_fEq => x_8.Frame_sel6_fEq
               , Frame_sel7_fReverb => x_8.Frame_sel7_fReverb
               , Frame_sel8_fAddr => x_8.Frame_sel8_fAddr
               , Frame_sel9_fDryL => x_8.Frame_sel9_fDryL
               , Frame_sel10_fDryR => x_8.Frame_sel10_fDryR
               , Frame_sel11_fWetL => x_8.Frame_sel11_fWetL
               , Frame_sel12_fWetR => x_8.Frame_sel12_fWetR
               , Frame_sel13_fFbL => x_8.Frame_sel13_fFbL
               , Frame_sel14_fFbR => x_8.Frame_sel14_fFbR
               , Frame_sel15_fEqLowL => x_8.Frame_sel15_fEqLowL
               , Frame_sel16_fEqLowR => x_8.Frame_sel16_fEqLowR
               , Frame_sel17_fEqMidL => x_8.Frame_sel17_fEqMidL
               , Frame_sel18_fEqMidR => x_8.Frame_sel18_fEqMidR
               , Frame_sel19_fEqHighL => x_8.Frame_sel19_fEqHighL
               , Frame_sel20_fEqHighR => x_8.Frame_sel20_fEqHighR
               , Frame_sel21_fEqHighLpL => x_8.Frame_sel21_fEqHighLpL
               , Frame_sel22_fEqHighLpR => x_8.Frame_sel22_fEqHighLpR
               , Frame_sel23_fAccL => \c$app_arg_36\
               , Frame_sel24_fAccR => \c$app_arg_35\
               , Frame_sel25_fAcc2L => \c$app_arg_33\
               , Frame_sel26_fAcc2R => \c$app_arg_32\
               , Frame_sel27_fAcc3L => \c$app_arg_30\
               , Frame_sel28_fAcc3R => \c$app_arg_29\ );

  \c$app_arg_29\ <= resize((resize(x_8.Frame_sel20_fEqHighR,48)) * \c$app_arg_31\, 48) when \on_4\ else
                    to_signed(0,48);

  \c$app_arg_30\ <= resize((resize(x_8.Frame_sel19_fEqHighL,48)) * \c$app_arg_31\, 48) when \on_4\ else
                    to_signed(0,48);

  \c$app_arg_31\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector((unsigned((\c$app_arg_38\(23 downto 16)))))))))))),48);

  \c$app_arg_32\ <= resize((resize(x_8.Frame_sel18_fEqMidR,48)) * \c$app_arg_34\, 48) when \on_4\ else
                    to_signed(0,48);

  \c$app_arg_33\ <= resize((resize(x_8.Frame_sel17_fEqMidL,48)) * \c$app_arg_34\, 48) when \on_4\ else
                    to_signed(0,48);

  \c$app_arg_34\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector((unsigned((\c$app_arg_38\(15 downto 8)))))))))))),48);

  \c$app_arg_35\ <= resize((resize(x_8.Frame_sel16_fEqLowR,48)) * \c$app_arg_37\, 48) when \on_4\ else
                    to_signed(0,48);

  \c$app_arg_36\ <= resize((resize(x_8.Frame_sel15_fEqLowL,48)) * \c$app_arg_37\, 48) when \on_4\ else
                    to_signed(0,48);

  \c$bv_7\ <= (x_8.Frame_sel3_fGate);

  \on_4\ <= (\c$bv_7\(3 downto 3)) = std_logic_vector'("1");

  \c$app_arg_37\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector((unsigned((\c$app_arg_38\(7 downto 0)))))))))))),48);

  \c$app_arg_38\ <= x_8.Frame_sel6_fEq;

  x_8 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_4(842 downto 0)));

  -- register begin
  ds1_4_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_4 <= std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_4 <= result_25;
    end if;
  end process;
  -- register end

  with (eqFilterPipe(843 downto 843)) select
    result_25 <= std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(\c$case_alt_9\.Frame_sel0_fL)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(\c$case_alt_9\.Frame_sel2_fLast)
                  & \c$case_alt_9\.Frame_sel3_fGate
                  & \c$case_alt_9\.Frame_sel4_fOd
                  & \c$case_alt_9\.Frame_sel5_fDist
                  & \c$case_alt_9\.Frame_sel6_fEq
                  & \c$case_alt_9\.Frame_sel7_fReverb
                  & std_logic_vector(\c$case_alt_9\.Frame_sel8_fAddr)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel9_fDryL)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel10_fDryR)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel11_fWetL)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel12_fWetR)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel13_fFbL)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel14_fFbR)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel15_fEqLowL)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel16_fEqLowR)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel17_fEqMidL)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel18_fEqMidR)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel19_fEqHighL)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel20_fEqHighR)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel21_fEqHighLpL)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel22_fEqHighLpR)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel23_fAccL)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel24_fAccR)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel25_fAcc2L)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel26_fAcc2R)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel27_fAcc3L)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel28_fAcc3R)))) when others;

  \c$case_alt_9\ <= ( Frame_sel0_fL => x_13.Frame_sel0_fL
                    , Frame_sel1_fR => x_13.Frame_sel1_fR
                    , Frame_sel2_fLast => x_13.Frame_sel2_fLast
                    , Frame_sel3_fGate => x_13.Frame_sel3_fGate
                    , Frame_sel4_fOd => x_13.Frame_sel4_fOd
                    , Frame_sel5_fDist => x_13.Frame_sel5_fDist
                    , Frame_sel6_fEq => x_13.Frame_sel6_fEq
                    , Frame_sel7_fReverb => x_13.Frame_sel7_fReverb
                    , Frame_sel8_fAddr => x_13.Frame_sel8_fAddr
                    , Frame_sel9_fDryL => x_13.Frame_sel9_fDryL
                    , Frame_sel10_fDryR => x_13.Frame_sel10_fDryR
                    , Frame_sel11_fWetL => x_13.Frame_sel11_fWetL
                    , Frame_sel12_fWetR => x_13.Frame_sel12_fWetR
                    , Frame_sel13_fFbL => x_13.Frame_sel13_fFbL
                    , Frame_sel14_fFbR => x_13.Frame_sel14_fFbR
                    , Frame_sel15_fEqLowL => x_13.Frame_sel15_fEqLowL
                    , Frame_sel16_fEqLowR => x_13.Frame_sel16_fEqLowR
                    , Frame_sel17_fEqMidL => result_29
                    , Frame_sel18_fEqMidR => result_28
                    , Frame_sel19_fEqHighL => result_27
                    , Frame_sel20_fEqHighR => result_26
                    , Frame_sel21_fEqHighLpL => x_13.Frame_sel21_fEqHighLpL
                    , Frame_sel22_fEqHighLpR => x_13.Frame_sel22_fEqHighLpR
                    , Frame_sel23_fAccL => x_13.Frame_sel23_fAccL
                    , Frame_sel24_fAccR => x_13.Frame_sel24_fAccR
                    , Frame_sel25_fAcc2L => x_13.Frame_sel25_fAcc2L
                    , Frame_sel26_fAcc2R => x_13.Frame_sel26_fAcc2R
                    , Frame_sel27_fAcc3L => x_13.Frame_sel27_fAcc3L
                    , Frame_sel28_fAcc3R => x_13.Frame_sel28_fAcc3R );

  x_9 <= (resize(x_13.Frame_sel1_fR,48)) - \c$app_arg_39\;

  \c$case_alt_selection_res_7\ <= x_9 < to_signed(-8388608,48);

  \c$case_alt_10\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_7\ else
                     resize(x_9,24);

  result_selection_res_10 <= x_9 > to_signed(8388607,48);

  result_26 <= to_signed(8388607,24) when result_selection_res_10 else
               \c$case_alt_10\;

  x_10 <= (resize(x_13.Frame_sel0_fL,48)) - \c$app_arg_40\;

  \c$case_alt_selection_res_8\ <= x_10 < to_signed(-8388608,48);

  \c$case_alt_11\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_8\ else
                     resize(x_10,24);

  result_selection_res_11 <= x_10 > to_signed(8388607,48);

  result_27 <= to_signed(8388607,24) when result_selection_res_11 else
               \c$case_alt_11\;

  x_11 <= \c$app_arg_39\ - (resize(x_13.Frame_sel16_fEqLowR,48));

  \c$case_alt_selection_res_9\ <= x_11 < to_signed(-8388608,48);

  \c$case_alt_12\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_9\ else
                     resize(x_11,24);

  result_selection_res_12 <= x_11 > to_signed(8388607,48);

  result_28 <= to_signed(8388607,24) when result_selection_res_12 else
               \c$case_alt_12\;

  \c$app_arg_39\ <= resize(x_13.Frame_sel22_fEqHighLpR,48);

  x_12 <= \c$app_arg_40\ - (resize(x_13.Frame_sel15_fEqLowL,48));

  \c$case_alt_selection_res_10\ <= x_12 < to_signed(-8388608,48);

  \c$case_alt_13\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_10\ else
                     resize(x_12,24);

  result_selection_res_13 <= x_12 > to_signed(8388607,48);

  result_29 <= to_signed(8388607,24) when result_selection_res_13 else
               \c$case_alt_13\;

  \c$app_arg_40\ <= resize(x_13.Frame_sel21_fEqHighLpL,48);

  -- register begin
  eqFilterPipe_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      eqFilterPipe <= std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      eqFilterPipe <= result_30;
    end if;
  end process;
  -- register end

  with (ds1_5(843 downto 843)) select
    result_30 <= std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(\c$case_alt_14\.Frame_sel0_fL)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(\c$case_alt_14\.Frame_sel2_fLast)
                  & \c$case_alt_14\.Frame_sel3_fGate
                  & \c$case_alt_14\.Frame_sel4_fOd
                  & \c$case_alt_14\.Frame_sel5_fDist
                  & \c$case_alt_14\.Frame_sel6_fEq
                  & \c$case_alt_14\.Frame_sel7_fReverb
                  & std_logic_vector(\c$case_alt_14\.Frame_sel8_fAddr)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel9_fDryL)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel10_fDryR)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel11_fWetL)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel12_fWetR)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel13_fFbL)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel14_fFbR)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel15_fEqLowL)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel16_fEqLowR)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel17_fEqMidL)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel18_fEqMidR)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel19_fEqHighL)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel20_fEqHighR)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel21_fEqHighLpL)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel22_fEqHighLpR)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel23_fAccL)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel24_fAccR)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel25_fAcc2L)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel26_fAcc2R)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel27_fAcc3L)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel28_fAcc3R)))) when others;

  \c$case_alt_14\ <= ( Frame_sel0_fL => x_14.Frame_sel0_fL
                     , Frame_sel1_fR => x_14.Frame_sel1_fR
                     , Frame_sel2_fLast => x_14.Frame_sel2_fLast
                     , Frame_sel3_fGate => x_14.Frame_sel3_fGate
                     , Frame_sel4_fOd => x_14.Frame_sel4_fOd
                     , Frame_sel5_fDist => x_14.Frame_sel5_fDist
                     , Frame_sel6_fEq => x_14.Frame_sel6_fEq
                     , Frame_sel7_fReverb => x_14.Frame_sel7_fReverb
                     , Frame_sel8_fAddr => x_14.Frame_sel8_fAddr
                     , Frame_sel9_fDryL => x_14.Frame_sel9_fDryL
                     , Frame_sel10_fDryR => x_14.Frame_sel10_fDryR
                     , Frame_sel11_fWetL => x_14.Frame_sel11_fWetL
                     , Frame_sel12_fWetR => x_14.Frame_sel12_fWetR
                     , Frame_sel13_fFbL => x_14.Frame_sel13_fFbL
                     , Frame_sel14_fFbR => x_14.Frame_sel14_fFbR
                     , Frame_sel15_fEqLowL => eqLowPrevL + (resize(\c$app_arg_45\,24))
                     , Frame_sel16_fEqLowR => eqLowPrevR + (resize(\c$app_arg_43\,24))
                     , Frame_sel17_fEqMidL => x_14.Frame_sel17_fEqMidL
                     , Frame_sel18_fEqMidR => x_14.Frame_sel18_fEqMidR
                     , Frame_sel19_fEqHighL => x_14.Frame_sel19_fEqHighL
                     , Frame_sel20_fEqHighR => x_14.Frame_sel20_fEqHighR
                     , Frame_sel21_fEqHighLpL => eqHighPrevL + (resize(\c$app_arg_42\,24))
                     , Frame_sel22_fEqHighLpR => eqHighPrevR + (resize(\c$app_arg_41\,24))
                     , Frame_sel23_fAccL => x_14.Frame_sel23_fAccL
                     , Frame_sel24_fAccR => x_14.Frame_sel24_fAccR
                     , Frame_sel25_fAcc2L => x_14.Frame_sel25_fAcc2L
                     , Frame_sel26_fAcc2R => x_14.Frame_sel26_fAcc2R
                     , Frame_sel27_fAcc3L => x_14.Frame_sel27_fAcc3L
                     , Frame_sel28_fAcc3R => x_14.Frame_sel28_fAcc3R );

  \c$shI_9\ <= (to_signed(2,64));

  capp_arg_41_shiftR : block
    signal sh_9 : natural;
  begin
    sh_9 <=
        -- pragma translate_off
        natural'high when (\c$shI_9\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_9\);
    \c$app_arg_41\ <= shift_right((\c$app_arg_44\ - (resize(eqHighPrevR,25))),sh_9)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$shI_10\ <= (to_signed(2,64));

  capp_arg_42_shiftR : block
    signal sh_10 : natural;
  begin
    sh_10 <=
        -- pragma translate_off
        natural'high when (\c$shI_10\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_10\);
    \c$app_arg_42\ <= shift_right((\c$app_arg_46\ - (resize(eqHighPrevL,25))),sh_10)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$shI_11\ <= (to_signed(5,64));

  capp_arg_43_shiftR : block
    signal sh_11 : natural;
  begin
    sh_11 <=
        -- pragma translate_off
        natural'high when (\c$shI_11\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_11\);
    \c$app_arg_43\ <= shift_right((\c$app_arg_44\ - (resize(eqLowPrevR,25))),sh_11)
        -- pragma translate_off
        when ((to_signed(5,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_44\ <= resize(x_14.Frame_sel1_fR,25);

  \c$shI_12\ <= (to_signed(5,64));

  capp_arg_45_shiftR : block
    signal sh_12 : natural;
  begin
    sh_12 <=
        -- pragma translate_off
        natural'high when (\c$shI_12\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_12\);
    \c$app_arg_45\ <= shift_right((\c$app_arg_46\ - (resize(eqLowPrevL,25))),sh_12)
        -- pragma translate_off
        when ((to_signed(5,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_46\ <= resize(x_14.Frame_sel0_fL,25);

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

  with (eqFilterPipe(843 downto 843)) select
    \c$eqHighPrevR_app_arg\ <= eqHighPrevR when "0",
                               x_13.Frame_sel22_fEqHighLpR when others;

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

  with (eqFilterPipe(843 downto 843)) select
    \c$eqHighPrevL_app_arg\ <= eqHighPrevL when "0",
                               x_13.Frame_sel21_fEqHighLpL when others;

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

  with (eqFilterPipe(843 downto 843)) select
    \c$eqLowPrevR_app_arg\ <= eqLowPrevR when "0",
                              x_13.Frame_sel16_fEqLowR when others;

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

  with (eqFilterPipe(843 downto 843)) select
    \c$eqLowPrevL_app_arg\ <= eqLowPrevL when "0",
                              x_13.Frame_sel15_fEqLowL when others;

  x_13 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(eqFilterPipe(842 downto 0)));

  x_14 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_5(842 downto 0)));

  -- register begin
  ds1_5_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_5 <= std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_5 <= result_31;
    end if;
  end process;
  -- register end

  with (distToneBlendPipe(843 downto 843)) select
    result_31 <= std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(result_32.Frame_sel0_fL)
                  & std_logic_vector(result_32.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(result_32.Frame_sel2_fLast)
                  & result_32.Frame_sel3_fGate
                  & result_32.Frame_sel4_fOd
                  & result_32.Frame_sel5_fDist
                  & result_32.Frame_sel6_fEq
                  & result_32.Frame_sel7_fReverb
                  & std_logic_vector(result_32.Frame_sel8_fAddr)
                  & std_logic_vector(result_32.Frame_sel9_fDryL)
                  & std_logic_vector(result_32.Frame_sel10_fDryR)
                  & std_logic_vector(result_32.Frame_sel11_fWetL)
                  & std_logic_vector(result_32.Frame_sel12_fWetR)
                  & std_logic_vector(result_32.Frame_sel13_fFbL)
                  & std_logic_vector(result_32.Frame_sel14_fFbR)
                  & std_logic_vector(result_32.Frame_sel15_fEqLowL)
                  & std_logic_vector(result_32.Frame_sel16_fEqLowR)
                  & std_logic_vector(result_32.Frame_sel17_fEqMidL)
                  & std_logic_vector(result_32.Frame_sel18_fEqMidR)
                  & std_logic_vector(result_32.Frame_sel19_fEqHighL)
                  & std_logic_vector(result_32.Frame_sel20_fEqHighR)
                  & std_logic_vector(result_32.Frame_sel21_fEqHighLpL)
                  & std_logic_vector(result_32.Frame_sel22_fEqHighLpR)
                  & std_logic_vector(result_32.Frame_sel23_fAccL)
                  & std_logic_vector(result_32.Frame_sel24_fAccR)
                  & std_logic_vector(result_32.Frame_sel25_fAcc2L)
                  & std_logic_vector(result_32.Frame_sel26_fAcc2R)
                  & std_logic_vector(result_32.Frame_sel27_fAcc3L)
                  & std_logic_vector(result_32.Frame_sel28_fAcc3R)))) when others;

  result_32 <= ( Frame_sel0_fL => \c$app_arg_49\
               , Frame_sel1_fR => \c$app_arg_47\
               , Frame_sel2_fLast => x_16.Frame_sel2_fLast
               , Frame_sel3_fGate => x_16.Frame_sel3_fGate
               , Frame_sel4_fOd => x_16.Frame_sel4_fOd
               , Frame_sel5_fDist => x_16.Frame_sel5_fDist
               , Frame_sel6_fEq => x_16.Frame_sel6_fEq
               , Frame_sel7_fReverb => x_16.Frame_sel7_fReverb
               , Frame_sel8_fAddr => x_16.Frame_sel8_fAddr
               , Frame_sel9_fDryL => x_16.Frame_sel9_fDryL
               , Frame_sel10_fDryR => x_16.Frame_sel10_fDryR
               , Frame_sel11_fWetL => x_16.Frame_sel11_fWetL
               , Frame_sel12_fWetR => x_16.Frame_sel12_fWetR
               , Frame_sel13_fFbL => x_16.Frame_sel13_fFbL
               , Frame_sel14_fFbR => x_16.Frame_sel14_fFbR
               , Frame_sel15_fEqLowL => x_16.Frame_sel15_fEqLowL
               , Frame_sel16_fEqLowR => x_16.Frame_sel16_fEqLowR
               , Frame_sel17_fEqMidL => x_16.Frame_sel17_fEqMidL
               , Frame_sel18_fEqMidR => x_16.Frame_sel18_fEqMidR
               , Frame_sel19_fEqHighL => x_16.Frame_sel19_fEqHighL
               , Frame_sel20_fEqHighR => x_16.Frame_sel20_fEqHighR
               , Frame_sel21_fEqHighLpL => x_16.Frame_sel21_fEqHighLpL
               , Frame_sel22_fEqHighLpR => x_16.Frame_sel22_fEqHighLpR
               , Frame_sel23_fAccL => x_16.Frame_sel23_fAccL
               , Frame_sel24_fAccR => x_16.Frame_sel24_fAccR
               , Frame_sel25_fAcc2L => x_16.Frame_sel25_fAcc2L
               , Frame_sel26_fAcc2R => x_16.Frame_sel26_fAcc2R
               , Frame_sel27_fAcc3L => x_16.Frame_sel27_fAcc3L
               , Frame_sel28_fAcc3R => x_16.Frame_sel28_fAcc3R );

  \c$app_arg_47\ <= result_33 when \on_5\ else
                    x_16.Frame_sel1_fR;

  \c$case_alt_selection_res_11\ <= \c$app_arg_48\ < to_signed(-8388608,48);

  \c$case_alt_15\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_11\ else
                     resize(\c$app_arg_48\,24);

  result_selection_res_14 <= \c$app_arg_48\ > to_signed(8388607,48);

  result_33 <= to_signed(8388607,24) when result_selection_res_14 else
               \c$case_alt_15\;

  \c$shI_13\ <= (to_signed(7,64));

  capp_arg_48_shiftR : block
    signal sh_13 : natural;
  begin
    sh_13 <=
        -- pragma translate_off
        natural'high when (\c$shI_13\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_13\);
    \c$app_arg_48\ <= shift_right((resize((resize(x_16.Frame_sel12_fWetR,48)) * \c$app_arg_51\, 48)),sh_13)
        -- pragma translate_off
        when ((to_signed(7,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_49\ <= result_34 when \on_5\ else
                    x_16.Frame_sel0_fL;

  \c$bv_8\ <= (x_16.Frame_sel3_fGate);

  \on_5\ <= (\c$bv_8\(2 downto 2)) = std_logic_vector'("1");

  \c$case_alt_selection_res_12\ <= \c$app_arg_50\ < to_signed(-8388608,48);

  \c$case_alt_16\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_12\ else
                     resize(\c$app_arg_50\,24);

  result_selection_res_15 <= \c$app_arg_50\ > to_signed(8388607,48);

  result_34 <= to_signed(8388607,24) when result_selection_res_15 else
               \c$case_alt_16\;

  \c$shI_14\ <= (to_signed(7,64));

  capp_arg_50_shiftR : block
    signal sh_14 : natural;
  begin
    sh_14 <=
        -- pragma translate_off
        natural'high when (\c$shI_14\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_14\);
    \c$app_arg_50\ <= shift_right((resize((resize(x_16.Frame_sel11_fWetL,48)) * \c$app_arg_51\, 48)),sh_14)
        -- pragma translate_off
        when ((to_signed(7,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_51\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(level)))))))),48);

  \c$bv_9\ <= (x_16.Frame_sel5_fDist);

  level <= unsigned((\c$bv_9\(15 downto 8)));

  -- register begin
  distToneBlendPipe_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      distToneBlendPipe <= std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      distToneBlendPipe <= result_35;
    end if;
  end process;
  -- register end

  with (ds1_6(843 downto 843)) select
    result_35 <= std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(result_38.Frame_sel0_fL)
                  & std_logic_vector(result_38.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(result_38.Frame_sel2_fLast)
                  & result_38.Frame_sel3_fGate
                  & result_38.Frame_sel4_fOd
                  & result_38.Frame_sel5_fDist
                  & result_38.Frame_sel6_fEq
                  & result_38.Frame_sel7_fReverb
                  & std_logic_vector(result_38.Frame_sel8_fAddr)
                  & std_logic_vector(result_38.Frame_sel9_fDryL)
                  & std_logic_vector(result_38.Frame_sel10_fDryR)
                  & std_logic_vector(result_38.Frame_sel11_fWetL)
                  & std_logic_vector(result_38.Frame_sel12_fWetR)
                  & std_logic_vector(result_38.Frame_sel13_fFbL)
                  & std_logic_vector(result_38.Frame_sel14_fFbR)
                  & std_logic_vector(result_38.Frame_sel15_fEqLowL)
                  & std_logic_vector(result_38.Frame_sel16_fEqLowR)
                  & std_logic_vector(result_38.Frame_sel17_fEqMidL)
                  & std_logic_vector(result_38.Frame_sel18_fEqMidR)
                  & std_logic_vector(result_38.Frame_sel19_fEqHighL)
                  & std_logic_vector(result_38.Frame_sel20_fEqHighR)
                  & std_logic_vector(result_38.Frame_sel21_fEqHighLpL)
                  & std_logic_vector(result_38.Frame_sel22_fEqHighLpR)
                  & std_logic_vector(result_38.Frame_sel23_fAccL)
                  & std_logic_vector(result_38.Frame_sel24_fAccR)
                  & std_logic_vector(result_38.Frame_sel25_fAcc2L)
                  & std_logic_vector(result_38.Frame_sel26_fAcc2R)
                  & std_logic_vector(result_38.Frame_sel27_fAcc3L)
                  & std_logic_vector(result_38.Frame_sel28_fAcc3R)))) when others;

  \c$shI_15\ <= (to_signed(8,64));

  capp_arg_52_shiftR : block
    signal sh_15 : natural;
  begin
    sh_15 <=
        -- pragma translate_off
        natural'high when (\c$shI_15\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_15\);
    \c$app_arg_52\ <= shift_right((x_15.Frame_sel23_fAccL + x_15.Frame_sel25_fAcc2L),sh_15)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_13\ <= \c$app_arg_52\ < to_signed(-8388608,48);

  \c$case_alt_17\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_13\ else
                     resize(\c$app_arg_52\,24);

  result_selection_res_16 <= \c$app_arg_52\ > to_signed(8388607,48);

  result_36 <= to_signed(8388607,24) when result_selection_res_16 else
               \c$case_alt_17\;

  \c$app_arg_53\ <= result_36 when \on_6\ else
                    x_15.Frame_sel0_fL;

  \c$shI_16\ <= (to_signed(8,64));

  capp_arg_54_shiftR : block
    signal sh_16 : natural;
  begin
    sh_16 <=
        -- pragma translate_off
        natural'high when (\c$shI_16\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_16\);
    \c$app_arg_54\ <= shift_right((x_15.Frame_sel24_fAccR + x_15.Frame_sel26_fAcc2R),sh_16)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_14\ <= \c$app_arg_54\ < to_signed(-8388608,48);

  \c$case_alt_18\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_14\ else
                     resize(\c$app_arg_54\,24);

  result_selection_res_17 <= \c$app_arg_54\ > to_signed(8388607,48);

  result_37 <= to_signed(8388607,24) when result_selection_res_17 else
               \c$case_alt_18\;

  \c$app_arg_55\ <= result_37 when \on_6\ else
                    x_15.Frame_sel1_fR;

  result_38 <= ( Frame_sel0_fL => x_15.Frame_sel0_fL
               , Frame_sel1_fR => x_15.Frame_sel1_fR
               , Frame_sel2_fLast => x_15.Frame_sel2_fLast
               , Frame_sel3_fGate => x_15.Frame_sel3_fGate
               , Frame_sel4_fOd => x_15.Frame_sel4_fOd
               , Frame_sel5_fDist => x_15.Frame_sel5_fDist
               , Frame_sel6_fEq => x_15.Frame_sel6_fEq
               , Frame_sel7_fReverb => x_15.Frame_sel7_fReverb
               , Frame_sel8_fAddr => x_15.Frame_sel8_fAddr
               , Frame_sel9_fDryL => x_15.Frame_sel9_fDryL
               , Frame_sel10_fDryR => x_15.Frame_sel10_fDryR
               , Frame_sel11_fWetL => \c$app_arg_53\
               , Frame_sel12_fWetR => \c$app_arg_55\
               , Frame_sel13_fFbL => x_15.Frame_sel13_fFbL
               , Frame_sel14_fFbR => x_15.Frame_sel14_fFbR
               , Frame_sel15_fEqLowL => x_15.Frame_sel15_fEqLowL
               , Frame_sel16_fEqLowR => x_15.Frame_sel16_fEqLowR
               , Frame_sel17_fEqMidL => x_15.Frame_sel17_fEqMidL
               , Frame_sel18_fEqMidR => x_15.Frame_sel18_fEqMidR
               , Frame_sel19_fEqHighL => x_15.Frame_sel19_fEqHighL
               , Frame_sel20_fEqHighR => x_15.Frame_sel20_fEqHighR
               , Frame_sel21_fEqHighLpL => x_15.Frame_sel21_fEqHighLpL
               , Frame_sel22_fEqHighLpR => x_15.Frame_sel22_fEqHighLpR
               , Frame_sel23_fAccL => x_15.Frame_sel23_fAccL
               , Frame_sel24_fAccR => x_15.Frame_sel24_fAccR
               , Frame_sel25_fAcc2L => x_15.Frame_sel25_fAcc2L
               , Frame_sel26_fAcc2R => x_15.Frame_sel26_fAcc2R
               , Frame_sel27_fAcc3L => x_15.Frame_sel27_fAcc3L
               , Frame_sel28_fAcc3R => x_15.Frame_sel28_fAcc3R );

  \c$bv_10\ <= (x_15.Frame_sel3_fGate);

  \on_6\ <= (\c$bv_10\(2 downto 2)) = std_logic_vector'("1");

  x_15 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_6(842 downto 0)));

  -- register begin
  ds1_6_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_6 <= std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_6 <= result_39;
    end if;
  end process;
  -- register end

  with (ds1_7(843 downto 843)) select
    result_39 <= std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(result_40.Frame_sel0_fL)
                  & std_logic_vector(result_40.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(result_40.Frame_sel2_fLast)
                  & result_40.Frame_sel3_fGate
                  & result_40.Frame_sel4_fOd
                  & result_40.Frame_sel5_fDist
                  & result_40.Frame_sel6_fEq
                  & result_40.Frame_sel7_fReverb
                  & std_logic_vector(result_40.Frame_sel8_fAddr)
                  & std_logic_vector(result_40.Frame_sel9_fDryL)
                  & std_logic_vector(result_40.Frame_sel10_fDryR)
                  & std_logic_vector(result_40.Frame_sel11_fWetL)
                  & std_logic_vector(result_40.Frame_sel12_fWetR)
                  & std_logic_vector(result_40.Frame_sel13_fFbL)
                  & std_logic_vector(result_40.Frame_sel14_fFbR)
                  & std_logic_vector(result_40.Frame_sel15_fEqLowL)
                  & std_logic_vector(result_40.Frame_sel16_fEqLowR)
                  & std_logic_vector(result_40.Frame_sel17_fEqMidL)
                  & std_logic_vector(result_40.Frame_sel18_fEqMidR)
                  & std_logic_vector(result_40.Frame_sel19_fEqHighL)
                  & std_logic_vector(result_40.Frame_sel20_fEqHighR)
                  & std_logic_vector(result_40.Frame_sel21_fEqHighLpL)
                  & std_logic_vector(result_40.Frame_sel22_fEqHighLpR)
                  & std_logic_vector(result_40.Frame_sel23_fAccL)
                  & std_logic_vector(result_40.Frame_sel24_fAccR)
                  & std_logic_vector(result_40.Frame_sel25_fAcc2L)
                  & std_logic_vector(result_40.Frame_sel26_fAcc2R)
                  & std_logic_vector(result_40.Frame_sel27_fAcc3L)
                  & std_logic_vector(result_40.Frame_sel28_fAcc3R)))) when others;

  result_40 <= ( Frame_sel0_fL => x_17.Frame_sel0_fL
               , Frame_sel1_fR => x_17.Frame_sel1_fR
               , Frame_sel2_fLast => x_17.Frame_sel2_fLast
               , Frame_sel3_fGate => x_17.Frame_sel3_fGate
               , Frame_sel4_fOd => x_17.Frame_sel4_fOd
               , Frame_sel5_fDist => x_17.Frame_sel5_fDist
               , Frame_sel6_fEq => x_17.Frame_sel6_fEq
               , Frame_sel7_fReverb => x_17.Frame_sel7_fReverb
               , Frame_sel8_fAddr => x_17.Frame_sel8_fAddr
               , Frame_sel9_fDryL => x_17.Frame_sel9_fDryL
               , Frame_sel10_fDryR => x_17.Frame_sel10_fDryR
               , Frame_sel11_fWetL => x_17.Frame_sel11_fWetL
               , Frame_sel12_fWetR => x_17.Frame_sel12_fWetR
               , Frame_sel13_fFbL => x_17.Frame_sel13_fFbL
               , Frame_sel14_fFbR => x_17.Frame_sel14_fFbR
               , Frame_sel15_fEqLowL => x_17.Frame_sel15_fEqLowL
               , Frame_sel16_fEqLowR => x_17.Frame_sel16_fEqLowR
               , Frame_sel17_fEqMidL => x_17.Frame_sel17_fEqMidL
               , Frame_sel18_fEqMidR => x_17.Frame_sel18_fEqMidR
               , Frame_sel19_fEqHighL => x_17.Frame_sel19_fEqHighL
               , Frame_sel20_fEqHighR => x_17.Frame_sel20_fEqHighR
               , Frame_sel21_fEqHighLpL => x_17.Frame_sel21_fEqHighLpL
               , Frame_sel22_fEqHighLpR => x_17.Frame_sel22_fEqHighLpR
               , Frame_sel23_fAccL => \c$app_arg_60\
               , Frame_sel24_fAccR => \c$app_arg_59\
               , Frame_sel25_fAcc2L => \c$app_arg_57\
               , Frame_sel26_fAcc2R => \c$app_arg_56\
               , Frame_sel27_fAcc3L => x_17.Frame_sel27_fAcc3L
               , Frame_sel28_fAcc3R => x_17.Frame_sel28_fAcc3R );

  \c$app_arg_56\ <= resize((resize(distTonePrevR,48)) * \c$app_arg_58\, 48) when \on_7\ else
                    to_signed(0,48);

  \c$app_arg_57\ <= resize((resize(distTonePrevL,48)) * \c$app_arg_58\, 48) when \on_7\ else
                    to_signed(0,48);

  \c$app_arg_58\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(toneInv)))))))),48);

  toneInv <= to_unsigned(255,8) - tone;

  \c$app_arg_59\ <= resize((resize(x_17.Frame_sel1_fR,48)) * \c$app_arg_61\, 48) when \on_7\ else
                    to_signed(0,48);

  \c$app_arg_60\ <= resize((resize(x_17.Frame_sel0_fL,48)) * \c$app_arg_61\, 48) when \on_7\ else
                    to_signed(0,48);

  \c$bv_11\ <= (x_17.Frame_sel3_fGate);

  \on_7\ <= (\c$bv_11\(2 downto 2)) = std_logic_vector'("1");

  \c$app_arg_61\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(tone)))))))),48);

  \c$bv_12\ <= (x_17.Frame_sel5_fDist);

  tone <= unsigned((\c$bv_12\(7 downto 0)));

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

  with (distToneBlendPipe(843 downto 843)) select
    \c$distTonePrevR_app_arg\ <= distTonePrevR when "0",
                                 x_16.Frame_sel12_fWetR when others;

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

  with (distToneBlendPipe(843 downto 843)) select
    \c$distTonePrevL_app_arg\ <= distTonePrevL when "0",
                                 x_16.Frame_sel11_fWetL when others;

  x_16 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(distToneBlendPipe(842 downto 0)));

  x_17 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_7(842 downto 0)));

  -- register begin
  ds1_7_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_7 <= std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_7 <= result_41;
    end if;
  end process;
  -- register end

  with (ds1_8(843 downto 843)) select
    result_41 <= std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(result_42.Frame_sel0_fL)
                  & std_logic_vector(result_42.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(result_42.Frame_sel2_fLast)
                  & result_42.Frame_sel3_fGate
                  & result_42.Frame_sel4_fOd
                  & result_42.Frame_sel5_fDist
                  & result_42.Frame_sel6_fEq
                  & result_42.Frame_sel7_fReverb
                  & std_logic_vector(result_42.Frame_sel8_fAddr)
                  & std_logic_vector(result_42.Frame_sel9_fDryL)
                  & std_logic_vector(result_42.Frame_sel10_fDryR)
                  & std_logic_vector(result_42.Frame_sel11_fWetL)
                  & std_logic_vector(result_42.Frame_sel12_fWetR)
                  & std_logic_vector(result_42.Frame_sel13_fFbL)
                  & std_logic_vector(result_42.Frame_sel14_fFbR)
                  & std_logic_vector(result_42.Frame_sel15_fEqLowL)
                  & std_logic_vector(result_42.Frame_sel16_fEqLowR)
                  & std_logic_vector(result_42.Frame_sel17_fEqMidL)
                  & std_logic_vector(result_42.Frame_sel18_fEqMidR)
                  & std_logic_vector(result_42.Frame_sel19_fEqHighL)
                  & std_logic_vector(result_42.Frame_sel20_fEqHighR)
                  & std_logic_vector(result_42.Frame_sel21_fEqHighLpL)
                  & std_logic_vector(result_42.Frame_sel22_fEqHighLpR)
                  & std_logic_vector(result_42.Frame_sel23_fAccL)
                  & std_logic_vector(result_42.Frame_sel24_fAccR)
                  & std_logic_vector(result_42.Frame_sel25_fAcc2L)
                  & std_logic_vector(result_42.Frame_sel26_fAcc2R)
                  & std_logic_vector(result_42.Frame_sel27_fAcc3L)
                  & std_logic_vector(result_42.Frame_sel28_fAcc3R)))) when others;

  threshold <= resize(x_18.Frame_sel25_fAcc2L,24);

  \c$bv_13\ <= (x_18.Frame_sel3_fGate);

  \on_8\ <= (\c$bv_13\(2 downto 2)) = std_logic_vector'("1");

  result_42 <= ( Frame_sel0_fL => \c$app_arg_64\
               , Frame_sel1_fR => \c$app_arg_62\
               , Frame_sel2_fLast => x_18.Frame_sel2_fLast
               , Frame_sel3_fGate => x_18.Frame_sel3_fGate
               , Frame_sel4_fOd => x_18.Frame_sel4_fOd
               , Frame_sel5_fDist => x_18.Frame_sel5_fDist
               , Frame_sel6_fEq => x_18.Frame_sel6_fEq
               , Frame_sel7_fReverb => x_18.Frame_sel7_fReverb
               , Frame_sel8_fAddr => x_18.Frame_sel8_fAddr
               , Frame_sel9_fDryL => x_18.Frame_sel9_fDryL
               , Frame_sel10_fDryR => x_18.Frame_sel10_fDryR
               , Frame_sel11_fWetL => x_18.Frame_sel11_fWetL
               , Frame_sel12_fWetR => x_18.Frame_sel12_fWetR
               , Frame_sel13_fFbL => x_18.Frame_sel13_fFbL
               , Frame_sel14_fFbR => x_18.Frame_sel14_fFbR
               , Frame_sel15_fEqLowL => x_18.Frame_sel15_fEqLowL
               , Frame_sel16_fEqLowR => x_18.Frame_sel16_fEqLowR
               , Frame_sel17_fEqMidL => x_18.Frame_sel17_fEqMidL
               , Frame_sel18_fEqMidR => x_18.Frame_sel18_fEqMidR
               , Frame_sel19_fEqHighL => x_18.Frame_sel19_fEqHighL
               , Frame_sel20_fEqHighR => x_18.Frame_sel20_fEqHighR
               , Frame_sel21_fEqHighLpL => x_18.Frame_sel21_fEqHighLpL
               , Frame_sel22_fEqHighLpR => x_18.Frame_sel22_fEqHighLpR
               , Frame_sel23_fAccL => x_18.Frame_sel23_fAccL
               , Frame_sel24_fAccR => x_18.Frame_sel24_fAccR
               , Frame_sel25_fAcc2L => x_18.Frame_sel25_fAcc2L
               , Frame_sel26_fAcc2R => x_18.Frame_sel26_fAcc2R
               , Frame_sel27_fAcc3L => x_18.Frame_sel27_fAcc3L
               , Frame_sel28_fAcc3R => x_18.Frame_sel28_fAcc3R );

  \c$app_arg_62\ <= result_43 when \on_8\ else
                    x_18.Frame_sel1_fR;

  result_selection_res_18 <= x_18.Frame_sel12_fWetR > threshold;

  result_43 <= threshold when result_selection_res_18 else
               \c$case_alt_19\;

  \c$case_alt_selection_res_15\ <= x_18.Frame_sel12_fWetR < \c$app_arg_63\;

  \c$case_alt_19\ <= \c$app_arg_63\ when \c$case_alt_selection_res_15\ else
                     x_18.Frame_sel12_fWetR;

  \c$app_arg_63\ <= -threshold;

  \c$app_arg_64\ <= result_44 when \on_8\ else
                    x_18.Frame_sel0_fL;

  result_selection_res_19 <= x_18.Frame_sel11_fWetL > threshold;

  result_44 <= threshold when result_selection_res_19 else
               \c$case_alt_20\;

  \c$case_alt_selection_res_16\ <= x_18.Frame_sel11_fWetL < \c$app_arg_65\;

  \c$case_alt_20\ <= \c$app_arg_65\ when \c$case_alt_selection_res_16\ else
                     x_18.Frame_sel11_fWetL;

  \c$app_arg_65\ <= -threshold;

  x_18 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_8(842 downto 0)));

  -- register begin
  ds1_8_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_8 <= std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_8 <= result_45;
    end if;
  end process;
  -- register end

  with (ds1_9(843 downto 843)) select
    result_45 <= std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(result_48.Frame_sel0_fL)
                  & std_logic_vector(result_48.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(result_48.Frame_sel2_fLast)
                  & result_48.Frame_sel3_fGate
                  & result_48.Frame_sel4_fOd
                  & result_48.Frame_sel5_fDist
                  & result_48.Frame_sel6_fEq
                  & result_48.Frame_sel7_fReverb
                  & std_logic_vector(result_48.Frame_sel8_fAddr)
                  & std_logic_vector(result_48.Frame_sel9_fDryL)
                  & std_logic_vector(result_48.Frame_sel10_fDryR)
                  & std_logic_vector(result_48.Frame_sel11_fWetL)
                  & std_logic_vector(result_48.Frame_sel12_fWetR)
                  & std_logic_vector(result_48.Frame_sel13_fFbL)
                  & std_logic_vector(result_48.Frame_sel14_fFbR)
                  & std_logic_vector(result_48.Frame_sel15_fEqLowL)
                  & std_logic_vector(result_48.Frame_sel16_fEqLowR)
                  & std_logic_vector(result_48.Frame_sel17_fEqMidL)
                  & std_logic_vector(result_48.Frame_sel18_fEqMidR)
                  & std_logic_vector(result_48.Frame_sel19_fEqHighL)
                  & std_logic_vector(result_48.Frame_sel20_fEqHighR)
                  & std_logic_vector(result_48.Frame_sel21_fEqHighLpL)
                  & std_logic_vector(result_48.Frame_sel22_fEqHighLpR)
                  & std_logic_vector(result_48.Frame_sel23_fAccL)
                  & std_logic_vector(result_48.Frame_sel24_fAccR)
                  & std_logic_vector(result_48.Frame_sel25_fAcc2L)
                  & std_logic_vector(result_48.Frame_sel26_fAcc2R)
                  & std_logic_vector(result_48.Frame_sel27_fAcc3L)
                  & std_logic_vector(result_48.Frame_sel28_fAcc3R)))) when others;

  \c$shI_17\ <= (to_signed(8,64));

  capp_arg_66_shiftR : block
    signal sh_17 : natural;
  begin
    sh_17 <=
        -- pragma translate_off
        natural'high when (\c$shI_17\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_17\);
    \c$app_arg_66\ <= shift_right(x_19.Frame_sel23_fAccL,sh_17)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_17\ <= \c$app_arg_66\ < to_signed(-8388608,48);

  \c$case_alt_21\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_17\ else
                     resize(\c$app_arg_66\,24);

  result_selection_res_20 <= \c$app_arg_66\ > to_signed(8388607,48);

  result_46 <= to_signed(8388607,24) when result_selection_res_20 else
               \c$case_alt_21\;

  \c$app_arg_67\ <= result_46 when \on_9\ else
                    x_19.Frame_sel0_fL;

  \c$shI_18\ <= (to_signed(8,64));

  capp_arg_68_shiftR : block
    signal sh_18 : natural;
  begin
    sh_18 <=
        -- pragma translate_off
        natural'high when (\c$shI_18\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_18\);
    \c$app_arg_68\ <= shift_right(x_19.Frame_sel24_fAccR,sh_18)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_18\ <= \c$app_arg_68\ < to_signed(-8388608,48);

  \c$case_alt_22\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_18\ else
                     resize(\c$app_arg_68\,24);

  result_selection_res_21 <= \c$app_arg_68\ > to_signed(8388607,48);

  result_47 <= to_signed(8388607,24) when result_selection_res_21 else
               \c$case_alt_22\;

  \c$app_arg_69\ <= result_47 when \on_9\ else
                    x_19.Frame_sel1_fR;

  result_48 <= ( Frame_sel0_fL => x_19.Frame_sel0_fL
               , Frame_sel1_fR => x_19.Frame_sel1_fR
               , Frame_sel2_fLast => x_19.Frame_sel2_fLast
               , Frame_sel3_fGate => x_19.Frame_sel3_fGate
               , Frame_sel4_fOd => x_19.Frame_sel4_fOd
               , Frame_sel5_fDist => x_19.Frame_sel5_fDist
               , Frame_sel6_fEq => x_19.Frame_sel6_fEq
               , Frame_sel7_fReverb => x_19.Frame_sel7_fReverb
               , Frame_sel8_fAddr => x_19.Frame_sel8_fAddr
               , Frame_sel9_fDryL => x_19.Frame_sel9_fDryL
               , Frame_sel10_fDryR => x_19.Frame_sel10_fDryR
               , Frame_sel11_fWetL => \c$app_arg_67\
               , Frame_sel12_fWetR => \c$app_arg_69\
               , Frame_sel13_fFbL => x_19.Frame_sel13_fFbL
               , Frame_sel14_fFbR => x_19.Frame_sel14_fFbR
               , Frame_sel15_fEqLowL => x_19.Frame_sel15_fEqLowL
               , Frame_sel16_fEqLowR => x_19.Frame_sel16_fEqLowR
               , Frame_sel17_fEqMidL => x_19.Frame_sel17_fEqMidL
               , Frame_sel18_fEqMidR => x_19.Frame_sel18_fEqMidR
               , Frame_sel19_fEqHighL => x_19.Frame_sel19_fEqHighL
               , Frame_sel20_fEqHighR => x_19.Frame_sel20_fEqHighR
               , Frame_sel21_fEqHighLpL => x_19.Frame_sel21_fEqHighLpL
               , Frame_sel22_fEqHighLpR => x_19.Frame_sel22_fEqHighLpR
               , Frame_sel23_fAccL => x_19.Frame_sel23_fAccL
               , Frame_sel24_fAccR => x_19.Frame_sel24_fAccR
               , Frame_sel25_fAcc2L => x_19.Frame_sel25_fAcc2L
               , Frame_sel26_fAcc2R => x_19.Frame_sel26_fAcc2R
               , Frame_sel27_fAcc3L => x_19.Frame_sel27_fAcc3L
               , Frame_sel28_fAcc3R => x_19.Frame_sel28_fAcc3R );

  \c$bv_14\ <= (x_19.Frame_sel3_fGate);

  \on_9\ <= (\c$bv_14\(2 downto 2)) = std_logic_vector'("1");

  x_19 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_9(842 downto 0)));

  -- register begin
  ds1_9_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_9 <= std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_9 <= result_49;
    end if;
  end process;
  -- register end

  with (ds1_10(843 downto 843)) select
    result_49 <= std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(result_50.Frame_sel0_fL)
                  & std_logic_vector(result_50.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(result_50.Frame_sel2_fLast)
                  & result_50.Frame_sel3_fGate
                  & result_50.Frame_sel4_fOd
                  & result_50.Frame_sel5_fDist
                  & result_50.Frame_sel6_fEq
                  & result_50.Frame_sel7_fReverb
                  & std_logic_vector(result_50.Frame_sel8_fAddr)
                  & std_logic_vector(result_50.Frame_sel9_fDryL)
                  & std_logic_vector(result_50.Frame_sel10_fDryR)
                  & std_logic_vector(result_50.Frame_sel11_fWetL)
                  & std_logic_vector(result_50.Frame_sel12_fWetR)
                  & std_logic_vector(result_50.Frame_sel13_fFbL)
                  & std_logic_vector(result_50.Frame_sel14_fFbR)
                  & std_logic_vector(result_50.Frame_sel15_fEqLowL)
                  & std_logic_vector(result_50.Frame_sel16_fEqLowR)
                  & std_logic_vector(result_50.Frame_sel17_fEqMidL)
                  & std_logic_vector(result_50.Frame_sel18_fEqMidR)
                  & std_logic_vector(result_50.Frame_sel19_fEqHighL)
                  & std_logic_vector(result_50.Frame_sel20_fEqHighR)
                  & std_logic_vector(result_50.Frame_sel21_fEqHighLpL)
                  & std_logic_vector(result_50.Frame_sel22_fEqHighLpR)
                  & std_logic_vector(result_50.Frame_sel23_fAccL)
                  & std_logic_vector(result_50.Frame_sel24_fAccR)
                  & std_logic_vector(result_50.Frame_sel25_fAcc2L)
                  & std_logic_vector(result_50.Frame_sel26_fAcc2R)
                  & std_logic_vector(result_50.Frame_sel27_fAcc3L)
                  & std_logic_vector(result_50.Frame_sel28_fAcc3R)))) when others;

  result_50 <= ( Frame_sel0_fL => x_20.Frame_sel0_fL
               , Frame_sel1_fR => x_20.Frame_sel1_fR
               , Frame_sel2_fLast => x_20.Frame_sel2_fLast
               , Frame_sel3_fGate => x_20.Frame_sel3_fGate
               , Frame_sel4_fOd => x_20.Frame_sel4_fOd
               , Frame_sel5_fDist => x_20.Frame_sel5_fDist
               , Frame_sel6_fEq => x_20.Frame_sel6_fEq
               , Frame_sel7_fReverb => x_20.Frame_sel7_fReverb
               , Frame_sel8_fAddr => x_20.Frame_sel8_fAddr
               , Frame_sel9_fDryL => x_20.Frame_sel9_fDryL
               , Frame_sel10_fDryR => x_20.Frame_sel10_fDryR
               , Frame_sel11_fWetL => x_20.Frame_sel11_fWetL
               , Frame_sel12_fWetR => x_20.Frame_sel12_fWetR
               , Frame_sel13_fFbL => x_20.Frame_sel13_fFbL
               , Frame_sel14_fFbR => x_20.Frame_sel14_fFbR
               , Frame_sel15_fEqLowL => x_20.Frame_sel15_fEqLowL
               , Frame_sel16_fEqLowR => x_20.Frame_sel16_fEqLowR
               , Frame_sel17_fEqMidL => x_20.Frame_sel17_fEqMidL
               , Frame_sel18_fEqMidR => x_20.Frame_sel18_fEqMidR
               , Frame_sel19_fEqHighL => x_20.Frame_sel19_fEqHighL
               , Frame_sel20_fEqHighR => x_20.Frame_sel20_fEqHighR
               , Frame_sel21_fEqHighLpL => x_20.Frame_sel21_fEqHighLpL
               , Frame_sel22_fEqHighLpR => x_20.Frame_sel22_fEqHighLpR
               , Frame_sel23_fAccL => \c$app_arg_71\
               , Frame_sel24_fAccR => \c$app_arg_70\
               , Frame_sel25_fAcc2L => resize((resize(result_51,24)),48)
               , Frame_sel26_fAcc2R => x_20.Frame_sel26_fAcc2R
               , Frame_sel27_fAcc3L => x_20.Frame_sel27_fAcc3L
               , Frame_sel28_fAcc3R => x_20.Frame_sel28_fAcc3R );

  result_selection_res_22 <= rawThreshold < to_signed(1800000,25);

  result_51 <= to_signed(1800000,25) when result_selection_res_22 else
               rawThreshold;

  rawThreshold <= to_signed(8388607,25) - (resize((resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(amount)))))))),25)) * to_signed(24000,25), 25));

  \c$app_arg_70\ <= resize((resize(x_20.Frame_sel1_fR,48)) * \c$app_arg_72\, 48) when \on_10\ else
                    to_signed(0,48);

  \c$app_arg_71\ <= resize((resize(x_20.Frame_sel0_fL,48)) * \c$app_arg_72\, 48) when \on_10\ else
                    to_signed(0,48);

  \c$bv_15\ <= (x_20.Frame_sel3_fGate);

  \on_10\ <= (\c$bv_15\(2 downto 2)) = std_logic_vector'("1");

  \c$app_arg_72\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(driveGain)))))))),48);

  driveGain <= resize((to_unsigned(256,11) + (resize((resize(amount,11)) * to_unsigned(8,11), 11))),12);

  \c$bv_16\ <= (x_20.Frame_sel5_fDist);

  amount <= unsigned((\c$bv_16\(23 downto 16)));

  x_20 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_10(842 downto 0)));

  -- register begin
  ds1_10_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_10 <= std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_10 <= result_52;
    end if;
  end process;
  -- register end

  with (odToneBlendPipe(843 downto 843)) select
    result_52 <= std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(result_53.Frame_sel0_fL)
                  & std_logic_vector(result_53.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(result_53.Frame_sel2_fLast)
                  & result_53.Frame_sel3_fGate
                  & result_53.Frame_sel4_fOd
                  & result_53.Frame_sel5_fDist
                  & result_53.Frame_sel6_fEq
                  & result_53.Frame_sel7_fReverb
                  & std_logic_vector(result_53.Frame_sel8_fAddr)
                  & std_logic_vector(result_53.Frame_sel9_fDryL)
                  & std_logic_vector(result_53.Frame_sel10_fDryR)
                  & std_logic_vector(result_53.Frame_sel11_fWetL)
                  & std_logic_vector(result_53.Frame_sel12_fWetR)
                  & std_logic_vector(result_53.Frame_sel13_fFbL)
                  & std_logic_vector(result_53.Frame_sel14_fFbR)
                  & std_logic_vector(result_53.Frame_sel15_fEqLowL)
                  & std_logic_vector(result_53.Frame_sel16_fEqLowR)
                  & std_logic_vector(result_53.Frame_sel17_fEqMidL)
                  & std_logic_vector(result_53.Frame_sel18_fEqMidR)
                  & std_logic_vector(result_53.Frame_sel19_fEqHighL)
                  & std_logic_vector(result_53.Frame_sel20_fEqHighR)
                  & std_logic_vector(result_53.Frame_sel21_fEqHighLpL)
                  & std_logic_vector(result_53.Frame_sel22_fEqHighLpR)
                  & std_logic_vector(result_53.Frame_sel23_fAccL)
                  & std_logic_vector(result_53.Frame_sel24_fAccR)
                  & std_logic_vector(result_53.Frame_sel25_fAcc2L)
                  & std_logic_vector(result_53.Frame_sel26_fAcc2R)
                  & std_logic_vector(result_53.Frame_sel27_fAcc3L)
                  & std_logic_vector(result_53.Frame_sel28_fAcc3R)))) when others;

  result_53 <= ( Frame_sel0_fL => \c$app_arg_75\
               , Frame_sel1_fR => \c$app_arg_73\
               , Frame_sel2_fLast => x_22.Frame_sel2_fLast
               , Frame_sel3_fGate => x_22.Frame_sel3_fGate
               , Frame_sel4_fOd => x_22.Frame_sel4_fOd
               , Frame_sel5_fDist => x_22.Frame_sel5_fDist
               , Frame_sel6_fEq => x_22.Frame_sel6_fEq
               , Frame_sel7_fReverb => x_22.Frame_sel7_fReverb
               , Frame_sel8_fAddr => x_22.Frame_sel8_fAddr
               , Frame_sel9_fDryL => x_22.Frame_sel9_fDryL
               , Frame_sel10_fDryR => x_22.Frame_sel10_fDryR
               , Frame_sel11_fWetL => x_22.Frame_sel11_fWetL
               , Frame_sel12_fWetR => x_22.Frame_sel12_fWetR
               , Frame_sel13_fFbL => x_22.Frame_sel13_fFbL
               , Frame_sel14_fFbR => x_22.Frame_sel14_fFbR
               , Frame_sel15_fEqLowL => x_22.Frame_sel15_fEqLowL
               , Frame_sel16_fEqLowR => x_22.Frame_sel16_fEqLowR
               , Frame_sel17_fEqMidL => x_22.Frame_sel17_fEqMidL
               , Frame_sel18_fEqMidR => x_22.Frame_sel18_fEqMidR
               , Frame_sel19_fEqHighL => x_22.Frame_sel19_fEqHighL
               , Frame_sel20_fEqHighR => x_22.Frame_sel20_fEqHighR
               , Frame_sel21_fEqHighLpL => x_22.Frame_sel21_fEqHighLpL
               , Frame_sel22_fEqHighLpR => x_22.Frame_sel22_fEqHighLpR
               , Frame_sel23_fAccL => x_22.Frame_sel23_fAccL
               , Frame_sel24_fAccR => x_22.Frame_sel24_fAccR
               , Frame_sel25_fAcc2L => x_22.Frame_sel25_fAcc2L
               , Frame_sel26_fAcc2R => x_22.Frame_sel26_fAcc2R
               , Frame_sel27_fAcc3L => x_22.Frame_sel27_fAcc3L
               , Frame_sel28_fAcc3R => x_22.Frame_sel28_fAcc3R );

  \c$app_arg_73\ <= result_54 when \on_11\ else
                    x_22.Frame_sel1_fR;

  \c$case_alt_selection_res_19\ <= \c$app_arg_74\ < to_signed(-8388608,48);

  \c$case_alt_23\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_19\ else
                     resize(\c$app_arg_74\,24);

  result_selection_res_23 <= \c$app_arg_74\ > to_signed(8388607,48);

  result_54 <= to_signed(8388607,24) when result_selection_res_23 else
               \c$case_alt_23\;

  \c$shI_19\ <= (to_signed(7,64));

  capp_arg_74_shiftR : block
    signal sh_19 : natural;
  begin
    sh_19 <=
        -- pragma translate_off
        natural'high when (\c$shI_19\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_19\);
    \c$app_arg_74\ <= shift_right((resize((resize(x_22.Frame_sel12_fWetR,48)) * \c$app_arg_77\, 48)),sh_19)
        -- pragma translate_off
        when ((to_signed(7,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_75\ <= result_55 when \on_11\ else
                    x_22.Frame_sel0_fL;

  \c$bv_17\ <= (x_22.Frame_sel3_fGate);

  \on_11\ <= (\c$bv_17\(1 downto 1)) = std_logic_vector'("1");

  \c$case_alt_selection_res_20\ <= \c$app_arg_76\ < to_signed(-8388608,48);

  \c$case_alt_24\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_20\ else
                     resize(\c$app_arg_76\,24);

  result_selection_res_24 <= \c$app_arg_76\ > to_signed(8388607,48);

  result_55 <= to_signed(8388607,24) when result_selection_res_24 else
               \c$case_alt_24\;

  \c$shI_20\ <= (to_signed(7,64));

  capp_arg_76_shiftR : block
    signal sh_20 : natural;
  begin
    sh_20 <=
        -- pragma translate_off
        natural'high when (\c$shI_20\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_20\);
    \c$app_arg_76\ <= shift_right((resize((resize(x_22.Frame_sel11_fWetL,48)) * \c$app_arg_77\, 48)),sh_20)
        -- pragma translate_off
        when ((to_signed(7,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_77\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(level_0)))))))),48);

  \c$bv_18\ <= (x_22.Frame_sel4_fOd);

  level_0 <= unsigned((\c$bv_18\(15 downto 8)));

  -- register begin
  odToneBlendPipe_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      odToneBlendPipe <= std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      odToneBlendPipe <= result_56;
    end if;
  end process;
  -- register end

  with (ds1_11(843 downto 843)) select
    result_56 <= std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(result_59.Frame_sel0_fL)
                  & std_logic_vector(result_59.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(result_59.Frame_sel2_fLast)
                  & result_59.Frame_sel3_fGate
                  & result_59.Frame_sel4_fOd
                  & result_59.Frame_sel5_fDist
                  & result_59.Frame_sel6_fEq
                  & result_59.Frame_sel7_fReverb
                  & std_logic_vector(result_59.Frame_sel8_fAddr)
                  & std_logic_vector(result_59.Frame_sel9_fDryL)
                  & std_logic_vector(result_59.Frame_sel10_fDryR)
                  & std_logic_vector(result_59.Frame_sel11_fWetL)
                  & std_logic_vector(result_59.Frame_sel12_fWetR)
                  & std_logic_vector(result_59.Frame_sel13_fFbL)
                  & std_logic_vector(result_59.Frame_sel14_fFbR)
                  & std_logic_vector(result_59.Frame_sel15_fEqLowL)
                  & std_logic_vector(result_59.Frame_sel16_fEqLowR)
                  & std_logic_vector(result_59.Frame_sel17_fEqMidL)
                  & std_logic_vector(result_59.Frame_sel18_fEqMidR)
                  & std_logic_vector(result_59.Frame_sel19_fEqHighL)
                  & std_logic_vector(result_59.Frame_sel20_fEqHighR)
                  & std_logic_vector(result_59.Frame_sel21_fEqHighLpL)
                  & std_logic_vector(result_59.Frame_sel22_fEqHighLpR)
                  & std_logic_vector(result_59.Frame_sel23_fAccL)
                  & std_logic_vector(result_59.Frame_sel24_fAccR)
                  & std_logic_vector(result_59.Frame_sel25_fAcc2L)
                  & std_logic_vector(result_59.Frame_sel26_fAcc2R)
                  & std_logic_vector(result_59.Frame_sel27_fAcc3L)
                  & std_logic_vector(result_59.Frame_sel28_fAcc3R)))) when others;

  \c$shI_21\ <= (to_signed(8,64));

  capp_arg_78_shiftR : block
    signal sh_21 : natural;
  begin
    sh_21 <=
        -- pragma translate_off
        natural'high when (\c$shI_21\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_21\);
    \c$app_arg_78\ <= shift_right((x_21.Frame_sel23_fAccL + x_21.Frame_sel25_fAcc2L),sh_21)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_21\ <= \c$app_arg_78\ < to_signed(-8388608,48);

  \c$case_alt_25\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_21\ else
                     resize(\c$app_arg_78\,24);

  result_selection_res_25 <= \c$app_arg_78\ > to_signed(8388607,48);

  result_57 <= to_signed(8388607,24) when result_selection_res_25 else
               \c$case_alt_25\;

  \c$app_arg_79\ <= result_57 when \on_12\ else
                    x_21.Frame_sel0_fL;

  \c$shI_22\ <= (to_signed(8,64));

  capp_arg_80_shiftR : block
    signal sh_22 : natural;
  begin
    sh_22 <=
        -- pragma translate_off
        natural'high when (\c$shI_22\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_22\);
    \c$app_arg_80\ <= shift_right((x_21.Frame_sel24_fAccR + x_21.Frame_sel26_fAcc2R),sh_22)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_22\ <= \c$app_arg_80\ < to_signed(-8388608,48);

  \c$case_alt_26\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_22\ else
                     resize(\c$app_arg_80\,24);

  result_selection_res_26 <= \c$app_arg_80\ > to_signed(8388607,48);

  result_58 <= to_signed(8388607,24) when result_selection_res_26 else
               \c$case_alt_26\;

  \c$app_arg_81\ <= result_58 when \on_12\ else
                    x_21.Frame_sel1_fR;

  result_59 <= ( Frame_sel0_fL => x_21.Frame_sel0_fL
               , Frame_sel1_fR => x_21.Frame_sel1_fR
               , Frame_sel2_fLast => x_21.Frame_sel2_fLast
               , Frame_sel3_fGate => x_21.Frame_sel3_fGate
               , Frame_sel4_fOd => x_21.Frame_sel4_fOd
               , Frame_sel5_fDist => x_21.Frame_sel5_fDist
               , Frame_sel6_fEq => x_21.Frame_sel6_fEq
               , Frame_sel7_fReverb => x_21.Frame_sel7_fReverb
               , Frame_sel8_fAddr => x_21.Frame_sel8_fAddr
               , Frame_sel9_fDryL => x_21.Frame_sel9_fDryL
               , Frame_sel10_fDryR => x_21.Frame_sel10_fDryR
               , Frame_sel11_fWetL => \c$app_arg_79\
               , Frame_sel12_fWetR => \c$app_arg_81\
               , Frame_sel13_fFbL => x_21.Frame_sel13_fFbL
               , Frame_sel14_fFbR => x_21.Frame_sel14_fFbR
               , Frame_sel15_fEqLowL => x_21.Frame_sel15_fEqLowL
               , Frame_sel16_fEqLowR => x_21.Frame_sel16_fEqLowR
               , Frame_sel17_fEqMidL => x_21.Frame_sel17_fEqMidL
               , Frame_sel18_fEqMidR => x_21.Frame_sel18_fEqMidR
               , Frame_sel19_fEqHighL => x_21.Frame_sel19_fEqHighL
               , Frame_sel20_fEqHighR => x_21.Frame_sel20_fEqHighR
               , Frame_sel21_fEqHighLpL => x_21.Frame_sel21_fEqHighLpL
               , Frame_sel22_fEqHighLpR => x_21.Frame_sel22_fEqHighLpR
               , Frame_sel23_fAccL => x_21.Frame_sel23_fAccL
               , Frame_sel24_fAccR => x_21.Frame_sel24_fAccR
               , Frame_sel25_fAcc2L => x_21.Frame_sel25_fAcc2L
               , Frame_sel26_fAcc2R => x_21.Frame_sel26_fAcc2R
               , Frame_sel27_fAcc3L => x_21.Frame_sel27_fAcc3L
               , Frame_sel28_fAcc3R => x_21.Frame_sel28_fAcc3R );

  \c$bv_19\ <= (x_21.Frame_sel3_fGate);

  \on_12\ <= (\c$bv_19\(1 downto 1)) = std_logic_vector'("1");

  x_21 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_11(842 downto 0)));

  -- register begin
  ds1_11_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_11 <= std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_11 <= result_60;
    end if;
  end process;
  -- register end

  with (ds1_12(843 downto 843)) select
    result_60 <= std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(result_61.Frame_sel0_fL)
                  & std_logic_vector(result_61.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(result_61.Frame_sel2_fLast)
                  & result_61.Frame_sel3_fGate
                  & result_61.Frame_sel4_fOd
                  & result_61.Frame_sel5_fDist
                  & result_61.Frame_sel6_fEq
                  & result_61.Frame_sel7_fReverb
                  & std_logic_vector(result_61.Frame_sel8_fAddr)
                  & std_logic_vector(result_61.Frame_sel9_fDryL)
                  & std_logic_vector(result_61.Frame_sel10_fDryR)
                  & std_logic_vector(result_61.Frame_sel11_fWetL)
                  & std_logic_vector(result_61.Frame_sel12_fWetR)
                  & std_logic_vector(result_61.Frame_sel13_fFbL)
                  & std_logic_vector(result_61.Frame_sel14_fFbR)
                  & std_logic_vector(result_61.Frame_sel15_fEqLowL)
                  & std_logic_vector(result_61.Frame_sel16_fEqLowR)
                  & std_logic_vector(result_61.Frame_sel17_fEqMidL)
                  & std_logic_vector(result_61.Frame_sel18_fEqMidR)
                  & std_logic_vector(result_61.Frame_sel19_fEqHighL)
                  & std_logic_vector(result_61.Frame_sel20_fEqHighR)
                  & std_logic_vector(result_61.Frame_sel21_fEqHighLpL)
                  & std_logic_vector(result_61.Frame_sel22_fEqHighLpR)
                  & std_logic_vector(result_61.Frame_sel23_fAccL)
                  & std_logic_vector(result_61.Frame_sel24_fAccR)
                  & std_logic_vector(result_61.Frame_sel25_fAcc2L)
                  & std_logic_vector(result_61.Frame_sel26_fAcc2R)
                  & std_logic_vector(result_61.Frame_sel27_fAcc3L)
                  & std_logic_vector(result_61.Frame_sel28_fAcc3R)))) when others;

  result_61 <= ( Frame_sel0_fL => x_23.Frame_sel0_fL
               , Frame_sel1_fR => x_23.Frame_sel1_fR
               , Frame_sel2_fLast => x_23.Frame_sel2_fLast
               , Frame_sel3_fGate => x_23.Frame_sel3_fGate
               , Frame_sel4_fOd => x_23.Frame_sel4_fOd
               , Frame_sel5_fDist => x_23.Frame_sel5_fDist
               , Frame_sel6_fEq => x_23.Frame_sel6_fEq
               , Frame_sel7_fReverb => x_23.Frame_sel7_fReverb
               , Frame_sel8_fAddr => x_23.Frame_sel8_fAddr
               , Frame_sel9_fDryL => x_23.Frame_sel9_fDryL
               , Frame_sel10_fDryR => x_23.Frame_sel10_fDryR
               , Frame_sel11_fWetL => x_23.Frame_sel11_fWetL
               , Frame_sel12_fWetR => x_23.Frame_sel12_fWetR
               , Frame_sel13_fFbL => x_23.Frame_sel13_fFbL
               , Frame_sel14_fFbR => x_23.Frame_sel14_fFbR
               , Frame_sel15_fEqLowL => x_23.Frame_sel15_fEqLowL
               , Frame_sel16_fEqLowR => x_23.Frame_sel16_fEqLowR
               , Frame_sel17_fEqMidL => x_23.Frame_sel17_fEqMidL
               , Frame_sel18_fEqMidR => x_23.Frame_sel18_fEqMidR
               , Frame_sel19_fEqHighL => x_23.Frame_sel19_fEqHighL
               , Frame_sel20_fEqHighR => x_23.Frame_sel20_fEqHighR
               , Frame_sel21_fEqHighLpL => x_23.Frame_sel21_fEqHighLpL
               , Frame_sel22_fEqHighLpR => x_23.Frame_sel22_fEqHighLpR
               , Frame_sel23_fAccL => \c$app_arg_86\
               , Frame_sel24_fAccR => \c$app_arg_85\
               , Frame_sel25_fAcc2L => \c$app_arg_83\
               , Frame_sel26_fAcc2R => \c$app_arg_82\
               , Frame_sel27_fAcc3L => x_23.Frame_sel27_fAcc3L
               , Frame_sel28_fAcc3R => x_23.Frame_sel28_fAcc3R );

  \c$app_arg_82\ <= resize((resize(odTonePrevR,48)) * \c$app_arg_84\, 48) when \on_13\ else
                    to_signed(0,48);

  \c$app_arg_83\ <= resize((resize(odTonePrevL,48)) * \c$app_arg_84\, 48) when \on_13\ else
                    to_signed(0,48);

  \c$app_arg_84\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(toneInv_0)))))))),48);

  toneInv_0 <= to_unsigned(255,8) - tone_0;

  \c$app_arg_85\ <= resize((resize(x_23.Frame_sel1_fR,48)) * \c$app_arg_87\, 48) when \on_13\ else
                    to_signed(0,48);

  \c$app_arg_86\ <= resize((resize(x_23.Frame_sel0_fL,48)) * \c$app_arg_87\, 48) when \on_13\ else
                    to_signed(0,48);

  \c$bv_20\ <= (x_23.Frame_sel3_fGate);

  \on_13\ <= (\c$bv_20\(1 downto 1)) = std_logic_vector'("1");

  \c$app_arg_87\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(tone_0)))))))),48);

  \c$bv_21\ <= (x_23.Frame_sel4_fOd);

  tone_0 <= unsigned((\c$bv_21\(7 downto 0)));

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

  with (odToneBlendPipe(843 downto 843)) select
    \c$odTonePrevR_app_arg\ <= odTonePrevR when "0",
                               x_22.Frame_sel12_fWetR when others;

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

  with (odToneBlendPipe(843 downto 843)) select
    \c$odTonePrevL_app_arg\ <= odTonePrevL when "0",
                               x_22.Frame_sel11_fWetL when others;

  x_22 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(odToneBlendPipe(842 downto 0)));

  x_23 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_12(842 downto 0)));

  -- register begin
  ds1_12_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_12 <= std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_12 <= result_62;
    end if;
  end process;
  -- register end

  with (ds1_13(843 downto 843)) select
    result_62 <= std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(result_63.Frame_sel0_fL)
                  & std_logic_vector(result_63.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(result_63.Frame_sel2_fLast)
                  & result_63.Frame_sel3_fGate
                  & result_63.Frame_sel4_fOd
                  & result_63.Frame_sel5_fDist
                  & result_63.Frame_sel6_fEq
                  & result_63.Frame_sel7_fReverb
                  & std_logic_vector(result_63.Frame_sel8_fAddr)
                  & std_logic_vector(result_63.Frame_sel9_fDryL)
                  & std_logic_vector(result_63.Frame_sel10_fDryR)
                  & std_logic_vector(result_63.Frame_sel11_fWetL)
                  & std_logic_vector(result_63.Frame_sel12_fWetR)
                  & std_logic_vector(result_63.Frame_sel13_fFbL)
                  & std_logic_vector(result_63.Frame_sel14_fFbR)
                  & std_logic_vector(result_63.Frame_sel15_fEqLowL)
                  & std_logic_vector(result_63.Frame_sel16_fEqLowR)
                  & std_logic_vector(result_63.Frame_sel17_fEqMidL)
                  & std_logic_vector(result_63.Frame_sel18_fEqMidR)
                  & std_logic_vector(result_63.Frame_sel19_fEqHighL)
                  & std_logic_vector(result_63.Frame_sel20_fEqHighR)
                  & std_logic_vector(result_63.Frame_sel21_fEqHighLpL)
                  & std_logic_vector(result_63.Frame_sel22_fEqHighLpR)
                  & std_logic_vector(result_63.Frame_sel23_fAccL)
                  & std_logic_vector(result_63.Frame_sel24_fAccR)
                  & std_logic_vector(result_63.Frame_sel25_fAcc2L)
                  & std_logic_vector(result_63.Frame_sel26_fAcc2R)
                  & std_logic_vector(result_63.Frame_sel27_fAcc3L)
                  & std_logic_vector(result_63.Frame_sel28_fAcc3R)))) when others;

  \c$bv_22\ <= (x_24.Frame_sel3_fGate);

  \on_14\ <= (\c$bv_22\(1 downto 1)) = std_logic_vector'("1");

  result_63 <= ( Frame_sel0_fL => \c$app_arg_92\
               , Frame_sel1_fR => \c$app_arg_88\
               , Frame_sel2_fLast => x_24.Frame_sel2_fLast
               , Frame_sel3_fGate => x_24.Frame_sel3_fGate
               , Frame_sel4_fOd => x_24.Frame_sel4_fOd
               , Frame_sel5_fDist => x_24.Frame_sel5_fDist
               , Frame_sel6_fEq => x_24.Frame_sel6_fEq
               , Frame_sel7_fReverb => x_24.Frame_sel7_fReverb
               , Frame_sel8_fAddr => x_24.Frame_sel8_fAddr
               , Frame_sel9_fDryL => x_24.Frame_sel9_fDryL
               , Frame_sel10_fDryR => x_24.Frame_sel10_fDryR
               , Frame_sel11_fWetL => x_24.Frame_sel11_fWetL
               , Frame_sel12_fWetR => x_24.Frame_sel12_fWetR
               , Frame_sel13_fFbL => x_24.Frame_sel13_fFbL
               , Frame_sel14_fFbR => x_24.Frame_sel14_fFbR
               , Frame_sel15_fEqLowL => x_24.Frame_sel15_fEqLowL
               , Frame_sel16_fEqLowR => x_24.Frame_sel16_fEqLowR
               , Frame_sel17_fEqMidL => x_24.Frame_sel17_fEqMidL
               , Frame_sel18_fEqMidR => x_24.Frame_sel18_fEqMidR
               , Frame_sel19_fEqHighL => x_24.Frame_sel19_fEqHighL
               , Frame_sel20_fEqHighR => x_24.Frame_sel20_fEqHighR
               , Frame_sel21_fEqHighLpL => x_24.Frame_sel21_fEqHighLpL
               , Frame_sel22_fEqHighLpR => x_24.Frame_sel22_fEqHighLpR
               , Frame_sel23_fAccL => x_24.Frame_sel23_fAccL
               , Frame_sel24_fAccR => x_24.Frame_sel24_fAccR
               , Frame_sel25_fAcc2L => x_24.Frame_sel25_fAcc2L
               , Frame_sel26_fAcc2R => x_24.Frame_sel26_fAcc2R
               , Frame_sel27_fAcc3L => x_24.Frame_sel27_fAcc3L
               , Frame_sel28_fAcc3R => x_24.Frame_sel28_fAcc3R );

  \c$app_arg_88\ <= result_64 when \on_14\ else
                    x_24.Frame_sel1_fR;

  result_selection_res_27 <= x_24.Frame_sel12_fWetR > to_signed(4194304,24);

  result_64 <= resize((to_signed(4194304,25) + \c$app_arg_89\),24) when result_selection_res_27 else
               \c$case_alt_27\;

  \c$case_alt_selection_res_23\ <= x_24.Frame_sel12_fWetR < to_signed(-4194304,24);

  \c$case_alt_27\ <= resize((to_signed(-4194304,25) + \c$app_arg_90\),24) when \c$case_alt_selection_res_23\ else
                     x_24.Frame_sel12_fWetR;

  \c$shI_23\ <= (to_signed(2,64));

  capp_arg_89_shiftR : block
    signal sh_23 : natural;
  begin
    sh_23 <=
        -- pragma translate_off
        natural'high when (\c$shI_23\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_23\);
    \c$app_arg_89\ <= shift_right((\c$app_arg_91\ - to_signed(4194304,25)),sh_23)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$shI_24\ <= (to_signed(2,64));

  capp_arg_90_shiftR : block
    signal sh_24 : natural;
  begin
    sh_24 <=
        -- pragma translate_off
        natural'high when (\c$shI_24\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_24\);
    \c$app_arg_90\ <= shift_right((\c$app_arg_91\ + to_signed(4194304,25)),sh_24)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_91\ <= resize(x_24.Frame_sel12_fWetR,25);

  \c$app_arg_92\ <= result_65 when \on_14\ else
                    x_24.Frame_sel0_fL;

  result_selection_res_28 <= x_24.Frame_sel11_fWetL > to_signed(4194304,24);

  result_65 <= resize((to_signed(4194304,25) + \c$app_arg_93\),24) when result_selection_res_28 else
               \c$case_alt_28\;

  \c$case_alt_selection_res_24\ <= x_24.Frame_sel11_fWetL < to_signed(-4194304,24);

  \c$case_alt_28\ <= resize((to_signed(-4194304,25) + \c$app_arg_94\),24) when \c$case_alt_selection_res_24\ else
                     x_24.Frame_sel11_fWetL;

  \c$shI_25\ <= (to_signed(2,64));

  capp_arg_93_shiftR : block
    signal sh_25 : natural;
  begin
    sh_25 <=
        -- pragma translate_off
        natural'high when (\c$shI_25\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_25\);
    \c$app_arg_93\ <= shift_right((\c$app_arg_95\ - to_signed(4194304,25)),sh_25)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$shI_26\ <= (to_signed(2,64));

  capp_arg_94_shiftR : block
    signal sh_26 : natural;
  begin
    sh_26 <=
        -- pragma translate_off
        natural'high when (\c$shI_26\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_26\);
    \c$app_arg_94\ <= shift_right((\c$app_arg_95\ + to_signed(4194304,25)),sh_26)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_95\ <= resize(x_24.Frame_sel11_fWetL,25);

  x_24 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_13(842 downto 0)));

  -- register begin
  ds1_13_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_13 <= std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_13 <= result_66;
    end if;
  end process;
  -- register end

  with (ds1_14(843 downto 843)) select
    result_66 <= std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(result_69.Frame_sel0_fL)
                  & std_logic_vector(result_69.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(result_69.Frame_sel2_fLast)
                  & result_69.Frame_sel3_fGate
                  & result_69.Frame_sel4_fOd
                  & result_69.Frame_sel5_fDist
                  & result_69.Frame_sel6_fEq
                  & result_69.Frame_sel7_fReverb
                  & std_logic_vector(result_69.Frame_sel8_fAddr)
                  & std_logic_vector(result_69.Frame_sel9_fDryL)
                  & std_logic_vector(result_69.Frame_sel10_fDryR)
                  & std_logic_vector(result_69.Frame_sel11_fWetL)
                  & std_logic_vector(result_69.Frame_sel12_fWetR)
                  & std_logic_vector(result_69.Frame_sel13_fFbL)
                  & std_logic_vector(result_69.Frame_sel14_fFbR)
                  & std_logic_vector(result_69.Frame_sel15_fEqLowL)
                  & std_logic_vector(result_69.Frame_sel16_fEqLowR)
                  & std_logic_vector(result_69.Frame_sel17_fEqMidL)
                  & std_logic_vector(result_69.Frame_sel18_fEqMidR)
                  & std_logic_vector(result_69.Frame_sel19_fEqHighL)
                  & std_logic_vector(result_69.Frame_sel20_fEqHighR)
                  & std_logic_vector(result_69.Frame_sel21_fEqHighLpL)
                  & std_logic_vector(result_69.Frame_sel22_fEqHighLpR)
                  & std_logic_vector(result_69.Frame_sel23_fAccL)
                  & std_logic_vector(result_69.Frame_sel24_fAccR)
                  & std_logic_vector(result_69.Frame_sel25_fAcc2L)
                  & std_logic_vector(result_69.Frame_sel26_fAcc2R)
                  & std_logic_vector(result_69.Frame_sel27_fAcc3L)
                  & std_logic_vector(result_69.Frame_sel28_fAcc3R)))) when others;

  \c$shI_27\ <= (to_signed(8,64));

  capp_arg_96_shiftR : block
    signal sh_27 : natural;
  begin
    sh_27 <=
        -- pragma translate_off
        natural'high when (\c$shI_27\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_27\);
    \c$app_arg_96\ <= shift_right(x_25.Frame_sel23_fAccL,sh_27)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_25\ <= \c$app_arg_96\ < to_signed(-8388608,48);

  \c$case_alt_29\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_25\ else
                     resize(\c$app_arg_96\,24);

  result_selection_res_29 <= \c$app_arg_96\ > to_signed(8388607,48);

  result_67 <= to_signed(8388607,24) when result_selection_res_29 else
               \c$case_alt_29\;

  \c$app_arg_97\ <= result_67 when \on_15\ else
                    x_25.Frame_sel0_fL;

  \c$shI_28\ <= (to_signed(8,64));

  capp_arg_98_shiftR : block
    signal sh_28 : natural;
  begin
    sh_28 <=
        -- pragma translate_off
        natural'high when (\c$shI_28\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_28\);
    \c$app_arg_98\ <= shift_right(x_25.Frame_sel24_fAccR,sh_28)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_26\ <= \c$app_arg_98\ < to_signed(-8388608,48);

  \c$case_alt_30\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_26\ else
                     resize(\c$app_arg_98\,24);

  result_selection_res_30 <= \c$app_arg_98\ > to_signed(8388607,48);

  result_68 <= to_signed(8388607,24) when result_selection_res_30 else
               \c$case_alt_30\;

  \c$app_arg_99\ <= result_68 when \on_15\ else
                    x_25.Frame_sel1_fR;

  result_69 <= ( Frame_sel0_fL => x_25.Frame_sel0_fL
               , Frame_sel1_fR => x_25.Frame_sel1_fR
               , Frame_sel2_fLast => x_25.Frame_sel2_fLast
               , Frame_sel3_fGate => x_25.Frame_sel3_fGate
               , Frame_sel4_fOd => x_25.Frame_sel4_fOd
               , Frame_sel5_fDist => x_25.Frame_sel5_fDist
               , Frame_sel6_fEq => x_25.Frame_sel6_fEq
               , Frame_sel7_fReverb => x_25.Frame_sel7_fReverb
               , Frame_sel8_fAddr => x_25.Frame_sel8_fAddr
               , Frame_sel9_fDryL => x_25.Frame_sel9_fDryL
               , Frame_sel10_fDryR => x_25.Frame_sel10_fDryR
               , Frame_sel11_fWetL => \c$app_arg_97\
               , Frame_sel12_fWetR => \c$app_arg_99\
               , Frame_sel13_fFbL => x_25.Frame_sel13_fFbL
               , Frame_sel14_fFbR => x_25.Frame_sel14_fFbR
               , Frame_sel15_fEqLowL => x_25.Frame_sel15_fEqLowL
               , Frame_sel16_fEqLowR => x_25.Frame_sel16_fEqLowR
               , Frame_sel17_fEqMidL => x_25.Frame_sel17_fEqMidL
               , Frame_sel18_fEqMidR => x_25.Frame_sel18_fEqMidR
               , Frame_sel19_fEqHighL => x_25.Frame_sel19_fEqHighL
               , Frame_sel20_fEqHighR => x_25.Frame_sel20_fEqHighR
               , Frame_sel21_fEqHighLpL => x_25.Frame_sel21_fEqHighLpL
               , Frame_sel22_fEqHighLpR => x_25.Frame_sel22_fEqHighLpR
               , Frame_sel23_fAccL => x_25.Frame_sel23_fAccL
               , Frame_sel24_fAccR => x_25.Frame_sel24_fAccR
               , Frame_sel25_fAcc2L => x_25.Frame_sel25_fAcc2L
               , Frame_sel26_fAcc2R => x_25.Frame_sel26_fAcc2R
               , Frame_sel27_fAcc3L => x_25.Frame_sel27_fAcc3L
               , Frame_sel28_fAcc3R => x_25.Frame_sel28_fAcc3R );

  \c$bv_23\ <= (x_25.Frame_sel3_fGate);

  \on_15\ <= (\c$bv_23\(1 downto 1)) = std_logic_vector'("1");

  x_25 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_14(842 downto 0)));

  -- register begin
  ds1_14_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_14 <= std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_14 <= result_70;
    end if;
  end process;
  -- register end

  with (ds1_15(843 downto 843)) select
    result_70 <= std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(result_71.Frame_sel0_fL)
                  & std_logic_vector(result_71.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(result_71.Frame_sel2_fLast)
                  & result_71.Frame_sel3_fGate
                  & result_71.Frame_sel4_fOd
                  & result_71.Frame_sel5_fDist
                  & result_71.Frame_sel6_fEq
                  & result_71.Frame_sel7_fReverb
                  & std_logic_vector(result_71.Frame_sel8_fAddr)
                  & std_logic_vector(result_71.Frame_sel9_fDryL)
                  & std_logic_vector(result_71.Frame_sel10_fDryR)
                  & std_logic_vector(result_71.Frame_sel11_fWetL)
                  & std_logic_vector(result_71.Frame_sel12_fWetR)
                  & std_logic_vector(result_71.Frame_sel13_fFbL)
                  & std_logic_vector(result_71.Frame_sel14_fFbR)
                  & std_logic_vector(result_71.Frame_sel15_fEqLowL)
                  & std_logic_vector(result_71.Frame_sel16_fEqLowR)
                  & std_logic_vector(result_71.Frame_sel17_fEqMidL)
                  & std_logic_vector(result_71.Frame_sel18_fEqMidR)
                  & std_logic_vector(result_71.Frame_sel19_fEqHighL)
                  & std_logic_vector(result_71.Frame_sel20_fEqHighR)
                  & std_logic_vector(result_71.Frame_sel21_fEqHighLpL)
                  & std_logic_vector(result_71.Frame_sel22_fEqHighLpR)
                  & std_logic_vector(result_71.Frame_sel23_fAccL)
                  & std_logic_vector(result_71.Frame_sel24_fAccR)
                  & std_logic_vector(result_71.Frame_sel25_fAcc2L)
                  & std_logic_vector(result_71.Frame_sel26_fAcc2R)
                  & std_logic_vector(result_71.Frame_sel27_fAcc3L)
                  & std_logic_vector(result_71.Frame_sel28_fAcc3R)))) when others;

  result_71 <= ( Frame_sel0_fL => x_26.Frame_sel0_fL
               , Frame_sel1_fR => x_26.Frame_sel1_fR
               , Frame_sel2_fLast => x_26.Frame_sel2_fLast
               , Frame_sel3_fGate => x_26.Frame_sel3_fGate
               , Frame_sel4_fOd => x_26.Frame_sel4_fOd
               , Frame_sel5_fDist => x_26.Frame_sel5_fDist
               , Frame_sel6_fEq => x_26.Frame_sel6_fEq
               , Frame_sel7_fReverb => x_26.Frame_sel7_fReverb
               , Frame_sel8_fAddr => x_26.Frame_sel8_fAddr
               , Frame_sel9_fDryL => x_26.Frame_sel9_fDryL
               , Frame_sel10_fDryR => x_26.Frame_sel10_fDryR
               , Frame_sel11_fWetL => x_26.Frame_sel11_fWetL
               , Frame_sel12_fWetR => x_26.Frame_sel12_fWetR
               , Frame_sel13_fFbL => x_26.Frame_sel13_fFbL
               , Frame_sel14_fFbR => x_26.Frame_sel14_fFbR
               , Frame_sel15_fEqLowL => x_26.Frame_sel15_fEqLowL
               , Frame_sel16_fEqLowR => x_26.Frame_sel16_fEqLowR
               , Frame_sel17_fEqMidL => x_26.Frame_sel17_fEqMidL
               , Frame_sel18_fEqMidR => x_26.Frame_sel18_fEqMidR
               , Frame_sel19_fEqHighL => x_26.Frame_sel19_fEqHighL
               , Frame_sel20_fEqHighR => x_26.Frame_sel20_fEqHighR
               , Frame_sel21_fEqHighLpL => x_26.Frame_sel21_fEqHighLpL
               , Frame_sel22_fEqHighLpR => x_26.Frame_sel22_fEqHighLpR
               , Frame_sel23_fAccL => \c$app_arg_101\
               , Frame_sel24_fAccR => \c$app_arg_100\
               , Frame_sel25_fAcc2L => x_26.Frame_sel25_fAcc2L
               , Frame_sel26_fAcc2R => x_26.Frame_sel26_fAcc2R
               , Frame_sel27_fAcc3L => x_26.Frame_sel27_fAcc3L
               , Frame_sel28_fAcc3R => x_26.Frame_sel28_fAcc3R );

  \c$app_arg_100\ <= resize((resize(x_26.Frame_sel1_fR,48)) * \c$app_arg_102\, 48) when \on_16\ else
                     to_signed(0,48);

  \c$app_arg_101\ <= resize((resize(x_26.Frame_sel0_fL,48)) * \c$app_arg_102\, 48) when \on_16\ else
                     to_signed(0,48);

  \c$bv_24\ <= (x_26.Frame_sel3_fGate);

  \on_16\ <= (\c$bv_24\(1 downto 1)) = std_logic_vector'("1");

  \c$app_arg_102\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(driveGain_0)))))))),48);

  \c$bv_25\ <= (x_26.Frame_sel4_fOd);

  driveGain_0 <= resize((to_unsigned(256,10) + (resize((resize((unsigned((\c$bv_25\(23 downto 16)))),10)) * to_unsigned(4,10), 10))),12);

  x_26 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_15(842 downto 0)));

  -- register begin
  ds1_15_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_15 <= std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_15 <= result_72;
    end if;
  end process;
  -- register end

  with (gateLevelPipe(843 downto 843)) select
    result_72 <= std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(result_73.Frame_sel0_fL)
                  & std_logic_vector(result_73.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(result_73.Frame_sel2_fLast)
                  & result_73.Frame_sel3_fGate
                  & result_73.Frame_sel4_fOd
                  & result_73.Frame_sel5_fDist
                  & result_73.Frame_sel6_fEq
                  & result_73.Frame_sel7_fReverb
                  & std_logic_vector(result_73.Frame_sel8_fAddr)
                  & std_logic_vector(result_73.Frame_sel9_fDryL)
                  & std_logic_vector(result_73.Frame_sel10_fDryR)
                  & std_logic_vector(result_73.Frame_sel11_fWetL)
                  & std_logic_vector(result_73.Frame_sel12_fWetR)
                  & std_logic_vector(result_73.Frame_sel13_fFbL)
                  & std_logic_vector(result_73.Frame_sel14_fFbR)
                  & std_logic_vector(result_73.Frame_sel15_fEqLowL)
                  & std_logic_vector(result_73.Frame_sel16_fEqLowR)
                  & std_logic_vector(result_73.Frame_sel17_fEqMidL)
                  & std_logic_vector(result_73.Frame_sel18_fEqMidR)
                  & std_logic_vector(result_73.Frame_sel19_fEqHighL)
                  & std_logic_vector(result_73.Frame_sel20_fEqHighR)
                  & std_logic_vector(result_73.Frame_sel21_fEqHighLpL)
                  & std_logic_vector(result_73.Frame_sel22_fEqHighLpR)
                  & std_logic_vector(result_73.Frame_sel23_fAccL)
                  & std_logic_vector(result_73.Frame_sel24_fAccR)
                  & std_logic_vector(result_73.Frame_sel25_fAcc2L)
                  & std_logic_vector(result_73.Frame_sel26_fAcc2R)
                  & std_logic_vector(result_73.Frame_sel27_fAcc3L)
                  & std_logic_vector(result_73.Frame_sel28_fAcc3R)))) when others;

  \c$bv_26\ <= (x_29.Frame_sel3_fGate);

  result_selection_res_31 <= not ((\c$bv_26\(0 downto 0)) = std_logic_vector'("1"));

  result_73 <= x_29 when result_selection_res_31 else
               ( Frame_sel0_fL => result_75
               , Frame_sel1_fR => result_74
               , Frame_sel2_fLast => x_29.Frame_sel2_fLast
               , Frame_sel3_fGate => x_29.Frame_sel3_fGate
               , Frame_sel4_fOd => x_29.Frame_sel4_fOd
               , Frame_sel5_fDist => x_29.Frame_sel5_fDist
               , Frame_sel6_fEq => x_29.Frame_sel6_fEq
               , Frame_sel7_fReverb => x_29.Frame_sel7_fReverb
               , Frame_sel8_fAddr => x_29.Frame_sel8_fAddr
               , Frame_sel9_fDryL => x_29.Frame_sel9_fDryL
               , Frame_sel10_fDryR => x_29.Frame_sel10_fDryR
               , Frame_sel11_fWetL => x_29.Frame_sel11_fWetL
               , Frame_sel12_fWetR => x_29.Frame_sel12_fWetR
               , Frame_sel13_fFbL => x_29.Frame_sel13_fFbL
               , Frame_sel14_fFbR => x_29.Frame_sel14_fFbR
               , Frame_sel15_fEqLowL => x_29.Frame_sel15_fEqLowL
               , Frame_sel16_fEqLowR => x_29.Frame_sel16_fEqLowR
               , Frame_sel17_fEqMidL => x_29.Frame_sel17_fEqMidL
               , Frame_sel18_fEqMidR => x_29.Frame_sel18_fEqMidR
               , Frame_sel19_fEqHighL => x_29.Frame_sel19_fEqHighL
               , Frame_sel20_fEqHighR => x_29.Frame_sel20_fEqHighR
               , Frame_sel21_fEqHighLpL => x_29.Frame_sel21_fEqHighLpL
               , Frame_sel22_fEqHighLpR => x_29.Frame_sel22_fEqHighLpR
               , Frame_sel23_fAccL => x_29.Frame_sel23_fAccL
               , Frame_sel24_fAccR => x_29.Frame_sel24_fAccR
               , Frame_sel25_fAcc2L => x_29.Frame_sel25_fAcc2L
               , Frame_sel26_fAcc2R => x_29.Frame_sel26_fAcc2R
               , Frame_sel27_fAcc3L => x_29.Frame_sel27_fAcc3L
               , Frame_sel28_fAcc3R => x_29.Frame_sel28_fAcc3R );

  \c$case_alt_selection_res_27\ <= \c$app_arg_103\ < to_signed(-8388608,48);

  \c$case_alt_31\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_27\ else
                     resize(\c$app_arg_103\,24);

  result_selection_res_32 <= \c$app_arg_103\ > to_signed(8388607,48);

  result_74 <= to_signed(8388607,24) when result_selection_res_32 else
               \c$case_alt_31\;

  \c$shI_29\ <= (to_signed(12,64));

  capp_arg_103_shiftR : block
    signal sh_29 : natural;
  begin
    sh_29 <=
        -- pragma translate_off
        natural'high when (\c$shI_29\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_29\);
    \c$app_arg_103\ <= shift_right((resize((resize(x_29.Frame_sel1_fR,48)) * \c$app_arg_105\, 48)),sh_29)
        -- pragma translate_off
        when ((to_signed(12,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_28\ <= \c$app_arg_104\ < to_signed(-8388608,48);

  \c$case_alt_32\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_28\ else
                     resize(\c$app_arg_104\,24);

  result_selection_res_33 <= \c$app_arg_104\ > to_signed(8388607,48);

  result_75 <= to_signed(8388607,24) when result_selection_res_33 else
               \c$case_alt_32\;

  \c$shI_30\ <= (to_signed(12,64));

  capp_arg_104_shiftR : block
    signal sh_30 : natural;
  begin
    sh_30 <=
        -- pragma translate_off
        natural'high when (\c$shI_30\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_30\);
    \c$app_arg_104\ <= shift_right((resize((resize(x_29.Frame_sel0_fL,48)) * \c$app_arg_105\, 48)),sh_30)
        -- pragma translate_off
        when ((to_signed(12,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_105\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(gateGain)))))))),48);

  -- register begin
  gateGain_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      gateGain <= to_unsigned(4095,12);
    elsif rising_edge(clk) then
      gateGain <= result_76;
    end if;
  end process;
  -- register end

  \c$case_alt_selection_res_29\ <= gateGain < to_unsigned(4,12);

  \c$case_alt_33\ <= to_unsigned(0,12) when \c$case_alt_selection_res_29\ else
                     gateGain - to_unsigned(4,12);

  \c$case_alt_selection_res_30\ <= gateGain > to_unsigned(3583,12);

  \c$case_alt_34\ <= to_unsigned(4095,12) when \c$case_alt_selection_res_30\ else
                     gateGain + to_unsigned(512,12);

  \c$case_alt_35\ <= \c$case_alt_34\ when gateOpen else
                     \c$case_alt_33\;

  \c$bv_27\ <= (f_2.Frame_sel3_fGate);

  \c$case_alt_selection_res_31\ <= not ((\c$bv_27\(0 downto 0)) = std_logic_vector'("1"));

  \c$case_alt_36\ <= to_unsigned(4095,12) when \c$case_alt_selection_res_31\ else
                     \c$case_alt_35\;

  f_2 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(gateLevelPipe(842 downto 0)));

  with (gateLevelPipe(843 downto 843)) select
    result_76 <= gateGain when "0",
                 \c$case_alt_36\ when others;

  -- register begin
  gateOpen_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      gateOpen <= true;
    elsif rising_edge(clk) then
      gateOpen <= result_77;
    end if;
  end process;
  -- register end

  with (gateLevelPipe(843 downto 843)) select
    result_77 <= gateOpen when "0",
                 \c$case_alt_37\ when others;

  \c$case_alt_selection_res_32\ <= not ((\c$app_arg_108\(0 downto 0)) = std_logic_vector'("1"));

  \c$case_alt_37\ <= true when \c$case_alt_selection_res_32\ else
                     result_78;

  result_selection_res_34 <= closeThreshold = to_signed(0,24);

  result_78 <= true when result_selection_res_34 else
               \c$case_alt_38\;

  \c$case_alt_selection_res_33\ <= gateEnv > result_79;

  \c$case_alt_38\ <= true when \c$case_alt_selection_res_33\ else
                     \c$case_alt_39\;

  \c$case_alt_selection_res_34\ <= gateEnv < closeThreshold;

  \c$case_alt_39\ <= false when \c$case_alt_selection_res_34\ else
                     gateOpen;

  x_27 <= (\c$app_arg_107\ + \c$app_arg_106\) + to_signed(65536,48);

  \c$case_alt_selection_res_35\ <= x_27 < to_signed(-8388608,48);

  \c$case_alt_40\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_35\ else
                     resize(x_27,24);

  result_selection_res_35 <= x_27 > to_signed(8388607,48);

  result_79 <= to_signed(8388607,24) when result_selection_res_35 else
               \c$case_alt_40\;

  \c$shI_31\ <= (to_signed(1,64));

  capp_arg_106_shiftR : block
    signal sh_31 : natural;
  begin
    sh_31 <=
        -- pragma translate_off
        natural'high when (\c$shI_31\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_31\);
    \c$app_arg_106\ <= shift_right(\c$app_arg_107\,sh_31)
        -- pragma translate_off
        when ((to_signed(1,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_107\ <= resize(closeThreshold,48);

  \c$shI_32\ <= (to_signed(13,64));

  closeThreshold_shiftL : block
    signal sh_32 : natural;
  begin
    sh_32 <=
        -- pragma translate_off
        natural'high when (\c$shI_32\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_32\);
    closeThreshold <= shift_left((resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(x_28)))))))),24)),sh_32)
        -- pragma translate_off
        when ((to_signed(13,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  x_28 <= unsigned((\c$app_arg_108\(15 downto 8)));

  \c$app_arg_108\ <= f_3.Frame_sel3_fGate;

  f_3 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(gateLevelPipe(842 downto 0)));

  -- register begin
  gateEnv_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      gateEnv <= to_signed(0,24);
    elsif rising_edge(clk) then
      gateEnv <= result_81;
    end if;
  end process;
  -- register end

  \c$shI_33\ <= (to_signed(8,64));

  cdecay_app_arg_shiftR : block
    signal sh_33 : natural;
  begin
    sh_33 <=
        -- pragma translate_off
        natural'high when (\c$shI_33\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_33\);
    \c$decay_app_arg\ <= shift_right((resize(gateEnv,25)),sh_33)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  result_selection_res_36 <= gateEnv > decay;

  result_80 <= gateEnv - decay when result_selection_res_36 else
               to_signed(0,24);

  \c$case_alt_selection_res_36\ <= f_4.Frame_sel11_fWetL > gateEnv;

  \c$case_alt_41\ <= f_4.Frame_sel11_fWetL when \c$case_alt_selection_res_36\ else
                     result_80;

  \c$bv_28\ <= (f_4.Frame_sel3_fGate);

  \c$case_alt_selection_res_37\ <= not ((\c$bv_28\(0 downto 0)) = std_logic_vector'("1"));

  \c$case_alt_42\ <= to_signed(0,24) when \c$case_alt_selection_res_37\ else
                     \c$case_alt_41\;

  f_4 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(gateLevelPipe(842 downto 0)));

  decay <= resize((\c$decay_app_arg\ + to_signed(1,25)),24);

  with (gateLevelPipe(843 downto 843)) select
    result_81 <= gateEnv when "0",
                 \c$case_alt_42\ when others;

  x_29 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(gateLevelPipe(842 downto 0)));

  -- register begin
  gateLevelPipe_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      gateLevelPipe <= std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      gateLevelPipe <= result_82;
    end if;
  end process;
  -- register end

  with (ds1_16(843 downto 843)) select
    result_82 <= std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(\c$case_alt_43\.Frame_sel0_fL)
                  & std_logic_vector(\c$case_alt_43\.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(\c$case_alt_43\.Frame_sel2_fLast)
                  & \c$case_alt_43\.Frame_sel3_fGate
                  & \c$case_alt_43\.Frame_sel4_fOd
                  & \c$case_alt_43\.Frame_sel5_fDist
                  & \c$case_alt_43\.Frame_sel6_fEq
                  & \c$case_alt_43\.Frame_sel7_fReverb
                  & std_logic_vector(\c$case_alt_43\.Frame_sel8_fAddr)
                  & std_logic_vector(\c$case_alt_43\.Frame_sel9_fDryL)
                  & std_logic_vector(\c$case_alt_43\.Frame_sel10_fDryR)
                  & std_logic_vector(\c$case_alt_43\.Frame_sel11_fWetL)
                  & std_logic_vector(\c$case_alt_43\.Frame_sel12_fWetR)
                  & std_logic_vector(\c$case_alt_43\.Frame_sel13_fFbL)
                  & std_logic_vector(\c$case_alt_43\.Frame_sel14_fFbR)
                  & std_logic_vector(\c$case_alt_43\.Frame_sel15_fEqLowL)
                  & std_logic_vector(\c$case_alt_43\.Frame_sel16_fEqLowR)
                  & std_logic_vector(\c$case_alt_43\.Frame_sel17_fEqMidL)
                  & std_logic_vector(\c$case_alt_43\.Frame_sel18_fEqMidR)
                  & std_logic_vector(\c$case_alt_43\.Frame_sel19_fEqHighL)
                  & std_logic_vector(\c$case_alt_43\.Frame_sel20_fEqHighR)
                  & std_logic_vector(\c$case_alt_43\.Frame_sel21_fEqHighLpL)
                  & std_logic_vector(\c$case_alt_43\.Frame_sel22_fEqHighLpR)
                  & std_logic_vector(\c$case_alt_43\.Frame_sel23_fAccL)
                  & std_logic_vector(\c$case_alt_43\.Frame_sel24_fAccR)
                  & std_logic_vector(\c$case_alt_43\.Frame_sel25_fAcc2L)
                  & std_logic_vector(\c$case_alt_43\.Frame_sel26_fAcc2R)
                  & std_logic_vector(\c$case_alt_43\.Frame_sel27_fAcc3L)
                  & std_logic_vector(\c$case_alt_43\.Frame_sel28_fAcc3R)))) when others;

  result_selection_res_37 <= result_85 > result_84;

  result_83 <= result_85 when result_selection_res_37 else
               result_84;

  \c$case_alt_43\ <= ( Frame_sel0_fL => x_30.Frame_sel0_fL
                     , Frame_sel1_fR => x_30.Frame_sel1_fR
                     , Frame_sel2_fLast => x_30.Frame_sel2_fLast
                     , Frame_sel3_fGate => x_30.Frame_sel3_fGate
                     , Frame_sel4_fOd => x_30.Frame_sel4_fOd
                     , Frame_sel5_fDist => x_30.Frame_sel5_fDist
                     , Frame_sel6_fEq => x_30.Frame_sel6_fEq
                     , Frame_sel7_fReverb => x_30.Frame_sel7_fReverb
                     , Frame_sel8_fAddr => x_30.Frame_sel8_fAddr
                     , Frame_sel9_fDryL => x_30.Frame_sel9_fDryL
                     , Frame_sel10_fDryR => x_30.Frame_sel10_fDryR
                     , Frame_sel11_fWetL => result_83
                     , Frame_sel12_fWetR => x_30.Frame_sel12_fWetR
                     , Frame_sel13_fFbL => x_30.Frame_sel13_fFbL
                     , Frame_sel14_fFbR => x_30.Frame_sel14_fFbR
                     , Frame_sel15_fEqLowL => x_30.Frame_sel15_fEqLowL
                     , Frame_sel16_fEqLowR => x_30.Frame_sel16_fEqLowR
                     , Frame_sel17_fEqMidL => x_30.Frame_sel17_fEqMidL
                     , Frame_sel18_fEqMidR => x_30.Frame_sel18_fEqMidR
                     , Frame_sel19_fEqHighL => x_30.Frame_sel19_fEqHighL
                     , Frame_sel20_fEqHighR => x_30.Frame_sel20_fEqHighR
                     , Frame_sel21_fEqHighLpL => x_30.Frame_sel21_fEqHighLpL
                     , Frame_sel22_fEqHighLpR => x_30.Frame_sel22_fEqHighLpR
                     , Frame_sel23_fAccL => x_30.Frame_sel23_fAccL
                     , Frame_sel24_fAccR => x_30.Frame_sel24_fAccR
                     , Frame_sel25_fAcc2L => x_30.Frame_sel25_fAcc2L
                     , Frame_sel26_fAcc2R => x_30.Frame_sel26_fAcc2R
                     , Frame_sel27_fAcc3L => x_30.Frame_sel27_fAcc3L
                     , Frame_sel28_fAcc3R => x_30.Frame_sel28_fAcc3R );

  \c$case_alt_selection_res_38\ <= x_30.Frame_sel1_fR < to_signed(0,24);

  \c$case_alt_44\ <= -x_30.Frame_sel1_fR when \c$case_alt_selection_res_38\ else
                     x_30.Frame_sel1_fR;

  result_selection_res_38 <= x_30.Frame_sel1_fR = to_signed(-8388608,24);

  result_84 <= to_signed(8388607,24) when result_selection_res_38 else
               \c$case_alt_44\;

  \c$case_alt_selection_res_39\ <= x_30.Frame_sel0_fL < to_signed(0,24);

  \c$case_alt_45\ <= -x_30.Frame_sel0_fL when \c$case_alt_selection_res_39\ else
                     x_30.Frame_sel0_fL;

  result_selection_res_39 <= x_30.Frame_sel0_fL = to_signed(-8388608,24);

  result_85 <= to_signed(8388607,24) when result_selection_res_39 else
               \c$case_alt_45\;

  x_30 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_16(842 downto 0)));

  -- register begin
  ds1_16_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_16 <= std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_16 <= result_87;
    end if;
  end process;
  -- register end

  validIn <= axis_in_tvalid and axis_out_tready;

  right <= result_86.Tuple2_0_sel1_signed_1;

  left <= result_86.Tuple2_0_sel0_signed_0;

  result_86 <= ( Tuple2_0_sel0_signed_0 => signed((\c$app_arg_109\(23 downto 0)))
               , Tuple2_0_sel1_signed_1 => signed((\c$app_arg_109\(47 downto 24))) );

  \c$app_arg_109\ <= axis_in_tdata;

  result_87 <= std_logic_vector'("1" & ((std_logic_vector(left)
                & std_logic_vector(right)
                & clash_lowpass_fir_types.toSLV(axis_in_tlast)
                & gate_control
                & overdrive_control
                & distortion_control
                & eq_control
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
               std_logic_vector'("0" & "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");

  \c$reverbAddr_case_alt_selection_res\ <= reverbAddr = to_unsigned(1023,10);

  \c$reverbAddr_case_alt\ <= to_unsigned(0,10) when \c$reverbAddr_case_alt_selection_res\ else
                             reverbAddr + to_unsigned(1,10);

  axis_out_tdata <= result.Tuple4_sel0_std_logic_vector;

  axis_out_tvalid <= result.Tuple4_sel1_boolean_0;

  axis_out_tlast <= result.Tuple4_sel2_boolean_1;

  axis_in_tready <= result.Tuple4_sel3_boolean_2;

end;
