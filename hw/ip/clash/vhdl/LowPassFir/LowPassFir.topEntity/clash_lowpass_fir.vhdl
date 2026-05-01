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
       amp_control        : in std_logic_vector(31 downto 0);
       amp_tone_control   : in std_logic_vector(31 downto 0);
       cab_control        : in std_logic_vector(31 downto 0);
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
  signal result_0                                    : clash_lowpass_fir_types.AxisOut;
  signal \c$case_alt\                                : clash_lowpass_fir_types.AxisOut;
  -- src/LowPassFir.hs:891:1-11
  signal \new\                                       : boolean;
  signal \c$app_arg\                                 : boolean;
  signal \c$app_arg_0\                               : std_logic_vector(47 downto 0);
  -- src/LowPassFir.hs:880:1-8
  signal f                                           : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:891:1-11
  signal consumed                                    : boolean;
  -- src/LowPassFir.hs:970:1-10
  signal outReg                                      : clash_lowpass_fir_types.AxisOut := ( AxisOut_sel0_oData => std_logic_vector'(x"000000000000")
, AxisOut_sel1_oValid => false
, AxisOut_sel2_oLast => false );
  signal result_1                                    : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_1\                               : signed(47 downto 0);
  signal \c$app_arg_2\                               : signed(47 downto 0);
  -- src/LowPassFir.hs:837:1-27
  signal \on\                                        : boolean;
  signal \c$app_arg_3\                               : signed(47 downto 0);
  -- src/LowPassFir.hs:113:1-5
  signal gain                                        : unsigned(7 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal reverbToneBlendPipe                         : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_2                                    : clash_lowpass_fir_types.Maybe;
  signal \c$app_arg_4\                               : signed(47 downto 0);
  signal \c$case_alt_0\                              : signed(23 downto 0);
  signal result_3                                    : signed(23 downto 0);
  signal \c$app_arg_5\                               : signed(47 downto 0);
  signal \c$case_alt_1\                              : signed(23 downto 0);
  signal result_4                                    : signed(23 downto 0);
  signal \c$case_alt_2\                              : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:970:1-10
  signal x                                           : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:970:1-10
  signal ds1                                         : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_5                                    : clash_lowpass_fir_types.Maybe;
  signal \c$app_arg_6\                               : signed(47 downto 0);
  -- src/LowPassFir.hs:113:1-5
  signal gain_0                                      : unsigned(7 downto 0);
  signal \c$app_arg_7\                               : signed(47 downto 0);
  -- src/LowPassFir.hs:113:1-5
  signal gain_1                                      : unsigned(7 downto 0);
  -- src/LowPassFir.hs:822:1-23
  signal x_0                                         : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:970:1-10
  signal reverbTonePrevR                             : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:970:1-10
  signal \c$reverbTonePrevR_app_arg\                 : signed(23 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal reverbTonePrevL                             : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:970:1-10
  signal \c$reverbTonePrevL_app_arg\                 : signed(23 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal x_1                                         : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:970:1-10
  signal \c$ds1_app_arg\                             : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  -- src/LowPassFir.hs:815:1-10
  signal f_0                                         : clash_lowpass_fir_types.Frame;
  signal result_6                                    : clash_lowpass_fir_types.Maybe;
  signal result_7                                    : signed(23 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal ds                                          : clash_lowpass_fir_types.Tuple2;
  -- src/LowPassFir.hs:970:1-10
  signal a1                                          : clash_lowpass_fir_types.Tuple2;
  -- src/LowPassFir.hs:970:1-10
  signal \c$ds1_app_arg_0\                           : boolean;
  -- src/LowPassFir.hs:970:1-10
  signal wrM                                         : clash_lowpass_fir_types.Maybe_0;
  signal result_8                                    : signed(23 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal ds_0                                        : clash_lowpass_fir_types.Tuple2;
  -- src/LowPassFir.hs:970:1-10
  signal a1_0                                        : clash_lowpass_fir_types.Tuple2;
  -- src/LowPassFir.hs:970:1-10
  signal \c$ds1_app_arg_1\                           : boolean;
  -- src/LowPassFir.hs:970:1-10
  signal wrM_0                                       : clash_lowpass_fir_types.Maybe_0;
  -- src/LowPassFir.hs:872:1-12
  signal f_1                                         : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:970:1-10
  signal outPipe                                     : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_9                                    : clash_lowpass_fir_types.Maybe;
  signal \c$app_arg_8\                               : signed(47 downto 0);
  signal \c$case_alt_3\                              : signed(23 downto 0);
  signal result_10                                   : signed(23 downto 0);
  signal \c$app_arg_9\                               : signed(23 downto 0);
  signal \c$app_arg_10\                              : signed(47 downto 0);
  signal \c$case_alt_4\                              : signed(23 downto 0);
  signal result_11                                   : signed(23 downto 0);
  signal \c$app_arg_11\                              : signed(23 downto 0);
  signal result_12                                   : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:864:1-14
  signal \on_0\                                      : boolean;
  -- src/LowPassFir.hs:970:1-10
  signal x_2                                         : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:970:1-10
  signal ds1_0                                       : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_13                                   : clash_lowpass_fir_types.Maybe;
  signal result_14                                   : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_12\                              : signed(47 downto 0);
  signal \c$app_arg_13\                              : signed(47 downto 0);
  signal \c$app_arg_14\                              : signed(47 downto 0);
  signal \c$app_arg_15\                              : signed(47 downto 0);
  signal \c$app_arg_16\                              : signed(47 downto 0);
  -- src/LowPassFir.hs:851:1-22
  signal \on_1\                                      : boolean;
  signal \c$app_arg_17\                              : signed(47 downto 0);
  -- src/LowPassFir.hs:851:1-22
  signal invMixGain                                  : unsigned(8 downto 0);
  -- src/LowPassFir.hs:851:1-22
  signal mixGain                                     : unsigned(7 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal x_3                                         : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:970:1-10
  signal ds1_1                                       : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_15                                   : clash_lowpass_fir_types.Maybe;
  signal \c$app_arg_18\                              : signed(47 downto 0);
  signal \c$app_arg_19\                              : signed(47 downto 0);
  -- src/LowPassFir.hs:125:1-7
  signal x_4                                         : signed(47 downto 0);
  signal \c$case_alt_5\                              : signed(23 downto 0);
  signal result_16                                   : signed(23 downto 0);
  signal \c$app_arg_20\                              : signed(23 downto 0);
  signal \c$app_arg_21\                              : signed(47 downto 0);
  signal \c$app_arg_22\                              : signed(47 downto 0);
  -- src/LowPassFir.hs:125:1-7
  signal x_5                                         : signed(47 downto 0);
  signal \c$case_alt_6\                              : signed(23 downto 0);
  signal result_17                                   : signed(23 downto 0);
  signal \c$app_arg_23\                              : signed(23 downto 0);
  signal result_18                                   : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:843:1-19
  signal \on_2\                                      : boolean;
  -- src/LowPassFir.hs:970:1-10
  signal x_6                                         : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:970:1-10
  signal ds1_2                                       : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  -- src/LowPassFir.hs:970:1-10
  signal \c$ds1_app_arg_2\                           : clash_lowpass_fir_types.Maybe;
  -- src/LowPassFir.hs:970:1-10
  signal \c$ds1_app_arg_3\                           : signed(63 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal reverbAddr                                  : clash_lowpass_fir_types.index_1024 := to_unsigned(0,10);
  -- src/LowPassFir.hs:970:1-10
  signal \c$reverbAddr_app_arg\                      : clash_lowpass_fir_types.index_1024;
  -- src/LowPassFir.hs:970:1-10
  signal eqMixPipe                                   : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_19                                   : clash_lowpass_fir_types.Maybe;
  -- src/LowPassFir.hs:807:1-10
  signal \on_3\                                      : boolean;
  signal result_20                                   : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_24\                              : signed(23 downto 0);
  signal \c$case_alt_7\                              : signed(23 downto 0);
  signal result_21                                   : signed(23 downto 0);
  signal \c$app_arg_25\                              : signed(47 downto 0);
  signal \c$app_arg_26\                              : signed(23 downto 0);
  signal \c$case_alt_8\                              : signed(23 downto 0);
  signal result_22                                   : signed(23 downto 0);
  signal \c$app_arg_27\                              : signed(47 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal x_7                                         : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:970:1-10
  signal ds1_3                                       : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_23                                   : clash_lowpass_fir_types.Maybe;
  signal result_24                                   : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_28\                              : signed(47 downto 0);
  signal \c$app_arg_29\                              : signed(47 downto 0);
  signal \c$app_arg_30\                              : signed(47 downto 0);
  -- src/LowPassFir.hs:113:1-5
  signal gain_2                                      : unsigned(7 downto 0);
  signal \c$app_arg_31\                              : signed(47 downto 0);
  signal \c$app_arg_32\                              : signed(47 downto 0);
  signal \c$app_arg_33\                              : signed(47 downto 0);
  -- src/LowPassFir.hs:113:1-5
  signal gain_3                                      : unsigned(7 downto 0);
  signal \c$app_arg_34\                              : signed(47 downto 0);
  signal \c$app_arg_35\                              : signed(47 downto 0);
  -- src/LowPassFir.hs:794:1-15
  signal \on_4\                                      : boolean;
  signal \c$app_arg_36\                              : signed(47 downto 0);
  -- src/LowPassFir.hs:113:1-5
  signal gain_4                                      : unsigned(7 downto 0);
  -- src/LowPassFir.hs:113:1-5
  signal \c$gain_app_arg\                            : std_logic_vector(31 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal x_8                                         : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:970:1-10
  signal ds1_4                                       : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_25                                   : clash_lowpass_fir_types.Maybe;
  signal \c$case_alt_9\                              : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:125:1-7
  signal x_9                                         : signed(47 downto 0);
  signal \c$case_alt_10\                             : signed(23 downto 0);
  signal result_26                                   : signed(23 downto 0);
  -- src/LowPassFir.hs:125:1-7
  signal x_10                                        : signed(47 downto 0);
  signal \c$case_alt_11\                             : signed(23 downto 0);
  signal result_27                                   : signed(23 downto 0);
  -- src/LowPassFir.hs:125:1-7
  signal x_11                                        : signed(47 downto 0);
  signal \c$case_alt_12\                             : signed(23 downto 0);
  signal result_28                                   : signed(23 downto 0);
  signal \c$app_arg_37\                              : signed(47 downto 0);
  -- src/LowPassFir.hs:125:1-7
  signal x_12                                        : signed(47 downto 0);
  signal \c$case_alt_13\                             : signed(23 downto 0);
  signal result_29                                   : signed(23 downto 0);
  signal \c$app_arg_38\                              : signed(47 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal eqFilterPipe                                : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_30                                   : clash_lowpass_fir_types.Maybe;
  signal \c$case_alt_14\                             : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_39\                              : signed(24 downto 0);
  signal \c$app_arg_40\                              : signed(24 downto 0);
  signal \c$app_arg_41\                              : signed(24 downto 0);
  signal \c$app_arg_42\                              : signed(24 downto 0);
  signal \c$app_arg_43\                              : signed(24 downto 0);
  signal \c$app_arg_44\                              : signed(24 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal eqHighPrevR                                 : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:970:1-10
  signal \c$eqHighPrevR_app_arg\                     : signed(23 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal eqHighPrevL                                 : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:970:1-10
  signal \c$eqHighPrevL_app_arg\                     : signed(23 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal eqLowPrevR                                  : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:970:1-10
  signal \c$eqLowPrevR_app_arg\                      : signed(23 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal eqLowPrevL                                  : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:970:1-10
  signal \c$eqLowPrevL_app_arg\                      : signed(23 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal x_13                                        : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:166:1-7
  signal x_14                                        : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:166:1-7
  signal ds1_5                                       : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_31                                   : clash_lowpass_fir_types.Maybe;
  signal result_32                                   : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_45\                              : signed(23 downto 0);
  signal result_33                                   : signed(23 downto 0);
  signal \c$case_alt_15\                             : signed(23 downto 0);
  signal \c$app_arg_46\                              : signed(24 downto 0);
  signal \c$app_arg_47\                              : signed(24 downto 0);
  signal \c$app_arg_48\                              : signed(24 downto 0);
  signal \c$case_alt_16\                             : signed(23 downto 0);
  signal result_34                                   : signed(23 downto 0);
  signal \c$app_arg_49\                              : signed(47 downto 0);
  signal \c$case_alt_17\                             : signed(23 downto 0);
  signal result_35                                   : signed(23 downto 0);
  -- src/LowPassFir.hs:113:1-5
  signal \c$x_app_arg\                               : signed(47 downto 0);
  signal \c$app_arg_50\                              : signed(23 downto 0);
  -- src/LowPassFir.hs:756:1-16
  signal \on_5\                                      : boolean;
  signal result_36                                   : signed(23 downto 0);
  signal \c$case_alt_18\                             : signed(23 downto 0);
  signal \c$app_arg_51\                              : signed(24 downto 0);
  signal \c$app_arg_52\                              : signed(24 downto 0);
  signal \c$app_arg_53\                              : signed(24 downto 0);
  signal \c$case_alt_19\                             : signed(23 downto 0);
  signal result_37                                   : signed(23 downto 0);
  signal \c$app_arg_54\                              : signed(47 downto 0);
  signal \c$app_arg_55\                              : signed(47 downto 0);
  signal \c$case_alt_20\                             : signed(23 downto 0);
  signal result_38                                   : signed(23 downto 0);
  -- src/LowPassFir.hs:113:1-5
  signal \c$x_app_arg_0\                             : signed(47 downto 0);
  -- src/LowPassFir.hs:113:1-5
  signal \c$x_app_arg_1\                             : signed(47 downto 0);
  -- src/LowPassFir.hs:756:1-16
  signal level                                       : unsigned(7 downto 0);
  signal \c$app_arg_56\                              : signed(47 downto 0);
  -- src/LowPassFir.hs:756:1-16
  signal invMix                                      : unsigned(7 downto 0);
  -- src/LowPassFir.hs:756:1-16
  signal mix                                         : unsigned(7 downto 0);
  -- src/LowPassFir.hs:756:1-16
  signal \c$level_app_arg\                           : std_logic_vector(31 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal x_15                                        : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:970:1-10
  signal ds1_6                                       : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_39                                   : clash_lowpass_fir_types.Maybe;
  signal \c$app_arg_57\                              : signed(47 downto 0);
  signal \c$case_alt_21\                             : signed(23 downto 0);
  signal result_40                                   : signed(23 downto 0);
  signal \c$app_arg_58\                              : signed(23 downto 0);
  signal \c$app_arg_59\                              : signed(47 downto 0);
  signal \c$case_alt_22\                             : signed(23 downto 0);
  signal result_41                                   : signed(23 downto 0);
  signal \c$app_arg_60\                              : signed(23 downto 0);
  signal result_42                                   : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:748:1-10
  signal \on_6\                                      : boolean;
  -- src/LowPassFir.hs:970:1-10
  signal x_16                                        : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:970:1-10
  signal ds1_7                                       : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_43                                   : clash_lowpass_fir_types.Maybe;
  signal result_44                                   : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_61\                              : signed(47 downto 0);
  signal \c$app_arg_62\                              : signed(47 downto 0);
  signal \c$app_arg_63\                              : signed(47 downto 0);
  -- src/LowPassFir.hs:660:1-8
  signal ds_1                                        : unsigned(7 downto 0);
  signal result_45                                   : signed(9 downto 0);
  signal \c$case_alt_23\                             : signed(9 downto 0);
  signal \c$case_alt_24\                             : signed(9 downto 0);
  signal \c$case_alt_25\                             : signed(9 downto 0);
  signal \c$cabCoeff_$jOut_app_arg\                  : unsigned(1 downto 0);
  signal \c$cabCoeff_$jOut_case_alt\                 : unsigned(1 downto 0);
  signal \c$app_arg_64\                              : signed(47 downto 0);
  -- src/LowPassFir.hs:660:1-8
  signal ds_2                                        : unsigned(7 downto 0);
  signal result_46                                   : signed(9 downto 0);
  signal \c$case_alt_26\                             : signed(9 downto 0);
  signal \c$case_alt_27\                             : signed(9 downto 0);
  signal \c$case_alt_28\                             : signed(9 downto 0);
  signal \c$cabCoeff_$jOut_app_arg_0\                : unsigned(1 downto 0);
  signal \c$cabCoeff_$jOut_case_alt_0\               : unsigned(1 downto 0);
  signal \c$app_arg_65\                              : signed(47 downto 0);
  signal \c$app_arg_66\                              : signed(47 downto 0);
  -- src/LowPassFir.hs:725:1-16
  signal \on_7\                                      : boolean;
  signal \c$app_arg_67\                              : signed(47 downto 0);
  -- src/LowPassFir.hs:660:1-8
  signal ds_3                                        : unsigned(7 downto 0);
  signal result_47                                   : signed(9 downto 0);
  signal \c$case_alt_29\                             : signed(9 downto 0);
  signal \c$case_alt_30\                             : signed(9 downto 0);
  signal \c$case_alt_31\                             : signed(9 downto 0);
  signal \c$cabCoeff_$jOut_app_arg_1\                : unsigned(1 downto 0);
  signal \c$cabCoeff_$jOut_case_alt_1\               : unsigned(1 downto 0);
  signal \c$app_arg_68\                              : signed(47 downto 0);
  -- src/LowPassFir.hs:660:1-8
  signal ds_4                                        : unsigned(7 downto 0);
  signal result_48                                   : signed(9 downto 0);
  signal \c$case_alt_32\                             : signed(9 downto 0);
  signal \c$case_alt_33\                             : signed(9 downto 0);
  signal \c$case_alt_34\                             : signed(9 downto 0);
  signal \c$cabCoeff_$jOut_app_arg_2\                : unsigned(1 downto 0);
  signal \c$cabCoeff_$jOut_case_alt_2\               : unsigned(1 downto 0);
  -- src/LowPassFir.hs:725:1-16
  signal air                                         : unsigned(7 downto 0);
  -- src/LowPassFir.hs:725:1-16
  signal model                                       : unsigned(7 downto 0);
  -- src/LowPassFir.hs:725:1-16
  signal \c$air_app_arg\                             : std_logic_vector(31 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal cabD3L                                      : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:970:1-10
  signal \c$cabD3L_app_arg\                          : signed(23 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal cabD2L                                      : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:970:1-10
  signal \c$cabD2L_app_arg\                          : signed(23 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal cabD1L                                      : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:970:1-10
  signal \c$cabD1L_app_arg\                          : signed(23 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal \c$cabD1L_case_alt\                         : signed(23 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal cabD3R                                      : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:970:1-10
  signal \c$cabD3R_app_arg\                          : signed(23 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal cabD2R                                      : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:970:1-10
  signal \c$cabD2R_app_arg\                          : signed(23 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal cabD1R                                      : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:970:1-10
  signal \c$cabD1R_app_arg\                          : signed(23 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal \c$cabD1R_case_alt\                         : signed(23 downto 0);
  -- src/LowPassFir.hs:166:1-7
  signal x_17                                        : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:970:1-10
  signal ampMasterPipe                               : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_49                                   : clash_lowpass_fir_types.Maybe;
  signal result_50                                   : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_69\                              : signed(23 downto 0);
  signal result_51                                   : signed(23 downto 0);
  signal \c$case_alt_35\                             : signed(23 downto 0);
  signal \c$app_arg_70\                              : signed(24 downto 0);
  signal \c$app_arg_71\                              : signed(24 downto 0);
  signal \c$app_arg_72\                              : signed(24 downto 0);
  signal \c$case_alt_36\                             : signed(23 downto 0);
  signal result_52                                   : signed(23 downto 0);
  signal \c$app_arg_73\                              : signed(47 downto 0);
  signal \c$app_arg_74\                              : signed(23 downto 0);
  -- src/LowPassFir.hs:651:1-14
  signal \on_8\                                      : boolean;
  signal result_53                                   : signed(23 downto 0);
  signal \c$case_alt_37\                             : signed(23 downto 0);
  signal \c$app_arg_75\                              : signed(24 downto 0);
  signal \c$app_arg_76\                              : signed(24 downto 0);
  signal \c$app_arg_77\                              : signed(24 downto 0);
  signal \c$case_alt_38\                             : signed(23 downto 0);
  signal result_54                                   : signed(23 downto 0);
  signal \c$app_arg_78\                              : signed(47 downto 0);
  signal \c$app_arg_79\                              : signed(47 downto 0);
  -- src/LowPassFir.hs:651:1-14
  signal level_0                                     : unsigned(7 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal x_18                                        : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:970:1-10
  signal ds1_8                                       : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_55                                   : clash_lowpass_fir_types.Maybe;
  signal \c$app_arg_80\                              : signed(47 downto 0);
  signal \c$case_alt_39\                             : signed(23 downto 0);
  signal result_56                                   : signed(23 downto 0);
  signal \c$app_arg_81\                              : signed(47 downto 0);
  signal \c$case_alt_40\                             : signed(23 downto 0);
  signal result_57                                   : signed(23 downto 0);
  -- src/LowPassFir.hs:125:1-7
  signal x_19                                        : signed(47 downto 0);
  signal \c$case_alt_41\                             : signed(23 downto 0);
  signal result_58                                   : signed(23 downto 0);
  signal result_59                                   : signed(23 downto 0);
  signal \c$case_alt_42\                             : signed(23 downto 0);
  signal \c$app_arg_82\                              : signed(24 downto 0);
  signal \c$app_arg_83\                              : signed(24 downto 0);
  signal \c$app_arg_84\                              : signed(24 downto 0);
  signal \c$app_arg_85\                              : signed(23 downto 0);
  signal \c$app_arg_86\                              : signed(47 downto 0);
  signal \c$case_alt_43\                             : signed(23 downto 0);
  signal result_60                                   : signed(23 downto 0);
  signal \c$app_arg_87\                              : signed(47 downto 0);
  signal \c$case_alt_44\                             : signed(23 downto 0);
  signal result_61                                   : signed(23 downto 0);
  -- src/LowPassFir.hs:125:1-7
  signal x_20                                        : signed(47 downto 0);
  signal \c$case_alt_45\                             : signed(23 downto 0);
  signal result_62                                   : signed(23 downto 0);
  signal result_63                                   : signed(23 downto 0);
  signal \c$case_alt_46\                             : signed(23 downto 0);
  signal \c$app_arg_88\                              : signed(24 downto 0);
  signal \c$app_arg_89\                              : signed(24 downto 0);
  signal \c$app_arg_90\                              : signed(24 downto 0);
  signal \c$app_arg_91\                              : signed(23 downto 0);
  signal result_64                                   : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:618:1-22
  signal \on_9\                                      : boolean;
  -- src/LowPassFir.hs:970:1-10
  signal x_21                                        : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:970:1-10
  signal ds1_9                                       : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_65                                   : clash_lowpass_fir_types.Maybe;
  signal result_66                                   : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_92\                              : signed(47 downto 0);
  -- src/LowPassFir.hs:125:1-7
  signal x_22                                        : signed(47 downto 0);
  signal \c$case_alt_47\                             : signed(23 downto 0);
  signal result_67                                   : signed(23 downto 0);
  signal \c$app_arg_93\                              : signed(47 downto 0);
  signal \c$app_arg_94\                              : signed(47 downto 0);
  -- src/LowPassFir.hs:626:1-27
  signal presence                                    : unsigned(7 downto 0);
  -- src/LowPassFir.hs:125:1-7
  signal x_23                                        : signed(47 downto 0);
  signal \c$case_alt_48\                             : signed(23 downto 0);
  signal result_68                                   : signed(23 downto 0);
  signal \c$app_arg_95\                              : signed(47 downto 0);
  signal \c$app_arg_96\                              : signed(47 downto 0);
  signal \c$app_arg_97\                              : signed(47 downto 0);
  -- src/LowPassFir.hs:626:1-27
  signal resonance                                   : unsigned(7 downto 0);
  signal \c$app_arg_98\                              : signed(47 downto 0);
  signal \c$app_arg_99\                              : signed(47 downto 0);
  -- src/LowPassFir.hs:626:1-27
  signal \on_10\                                     : boolean;
  -- src/LowPassFir.hs:626:1-27
  signal \c$presence_app_arg\                        : std_logic_vector(31 downto 0);
  -- src/LowPassFir.hs:626:1-27
  signal \c$highL_app_arg\                           : signed(47 downto 0);
  -- src/LowPassFir.hs:626:1-27
  signal \c$highR_app_arg\                           : signed(47 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal ampResPresenceFilterPipe                    : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_69                                   : clash_lowpass_fir_types.Maybe;
  signal \c$case_alt_49\                             : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_100\                             : signed(24 downto 0);
  signal \c$app_arg_101\                             : signed(24 downto 0);
  signal \c$app_arg_102\                             : signed(24 downto 0);
  signal \c$app_arg_103\                             : signed(24 downto 0);
  signal \c$app_arg_104\                             : signed(24 downto 0);
  signal \c$app_arg_105\                             : signed(24 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal ampPresencePrevR                            : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:970:1-10
  signal \c$ampPresencePrevR_app_arg\                : signed(23 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal ampPresencePrevL                            : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:970:1-10
  signal \c$ampPresencePrevL_app_arg\                : signed(23 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal ampResPrevR                                 : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:970:1-10
  signal \c$ampResPrevR_app_arg\                     : signed(23 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal ampResPrevL                                 : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:970:1-10
  signal \c$ampResPrevL_app_arg\                     : signed(23 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal x_24                                        : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:166:1-7
  signal x_25                                        : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:166:1-7
  signal ds1_10                                      : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_70                                   : clash_lowpass_fir_types.Maybe;
  -- src/LowPassFir.hs:595:1-13
  signal \on_11\                                     : boolean;
  signal result_71                                   : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_106\                             : signed(23 downto 0);
  signal result_72                                   : signed(23 downto 0);
  signal \c$case_alt_50\                             : signed(23 downto 0);
  signal \c$app_arg_107\                             : signed(24 downto 0);
  signal \c$app_arg_108\                             : signed(24 downto 0);
  signal \c$app_arg_109\                             : signed(24 downto 0);
  signal \c$app_arg_110\                             : signed(23 downto 0);
  signal result_73                                   : signed(23 downto 0);
  signal \c$case_alt_51\                             : signed(23 downto 0);
  signal \c$app_arg_111\                             : signed(24 downto 0);
  signal \c$app_arg_112\                             : signed(24 downto 0);
  signal \c$app_arg_113\                             : signed(24 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal x_26                                        : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:970:1-10
  signal ds1_11                                      : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_74                                   : clash_lowpass_fir_types.Maybe;
  signal \c$app_arg_114\                             : signed(47 downto 0);
  signal \c$case_alt_52\                             : signed(23 downto 0);
  signal result_75                                   : signed(23 downto 0);
  signal \c$app_arg_115\                             : signed(23 downto 0);
  signal \c$app_arg_116\                             : signed(47 downto 0);
  signal \c$case_alt_53\                             : signed(23 downto 0);
  signal result_76                                   : signed(23 downto 0);
  signal \c$app_arg_117\                             : signed(23 downto 0);
  signal result_77                                   : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:587:1-15
  signal \on_12\                                     : boolean;
  -- src/LowPassFir.hs:970:1-10
  signal x_27                                        : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:970:1-10
  signal ds1_12                                      : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_78                                   : clash_lowpass_fir_types.Maybe;
  signal result_79                                   : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_118\                             : signed(47 downto 0);
  signal \c$app_arg_119\                             : signed(47 downto 0);
  signal \c$app_arg_120\                             : signed(47 downto 0);
  -- src/LowPassFir.hs:113:1-5
  signal \c$gain_app_arg_0\                          : unsigned(7 downto 0);
  -- src/LowPassFir.hs:571:1-11
  signal x_28                                        : unsigned(7 downto 0);
  signal \c$app_arg_121\                             : signed(47 downto 0);
  signal \c$app_arg_122\                             : signed(47 downto 0);
  signal \c$app_arg_123\                             : signed(47 downto 0);
  -- src/LowPassFir.hs:113:1-5
  signal \c$gain_app_arg_1\                          : unsigned(7 downto 0);
  -- src/LowPassFir.hs:571:1-11
  signal x_29                                        : unsigned(7 downto 0);
  signal \c$app_arg_124\                             : signed(47 downto 0);
  signal \c$app_arg_125\                             : signed(47 downto 0);
  -- src/LowPassFir.hs:574:1-20
  signal \on_13\                                     : boolean;
  signal \c$app_arg_126\                             : signed(47 downto 0);
  -- src/LowPassFir.hs:113:1-5
  signal \c$gain_app_arg_2\                          : unsigned(7 downto 0);
  -- src/LowPassFir.hs:571:1-11
  signal x_30                                        : unsigned(7 downto 0);
  -- src/LowPassFir.hs:571:1-11
  signal \c$x_app_arg_2\                             : std_logic_vector(31 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal x_31                                        : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:970:1-10
  signal ds1_13                                      : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_80                                   : clash_lowpass_fir_types.Maybe;
  signal \c$case_alt_54\                             : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:125:1-7
  signal x_32                                        : signed(47 downto 0);
  signal \c$case_alt_55\                             : signed(23 downto 0);
  signal result_81                                   : signed(23 downto 0);
  -- src/LowPassFir.hs:125:1-7
  signal x_33                                        : signed(47 downto 0);
  signal \c$case_alt_56\                             : signed(23 downto 0);
  signal result_82                                   : signed(23 downto 0);
  -- src/LowPassFir.hs:125:1-7
  signal x_34                                        : signed(47 downto 0);
  signal \c$case_alt_57\                             : signed(23 downto 0);
  signal result_83                                   : signed(23 downto 0);
  signal \c$app_arg_127\                             : signed(47 downto 0);
  -- src/LowPassFir.hs:125:1-7
  signal x_35                                        : signed(47 downto 0);
  signal \c$case_alt_58\                             : signed(23 downto 0);
  signal result_84                                   : signed(23 downto 0);
  signal \c$app_arg_128\                             : signed(47 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal ampToneFilterPipe                           : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_85                                   : clash_lowpass_fir_types.Maybe;
  signal \c$case_alt_59\                             : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_129\                             : signed(24 downto 0);
  signal \c$app_arg_130\                             : signed(24 downto 0);
  signal \c$app_arg_131\                             : signed(24 downto 0);
  signal \c$app_arg_132\                             : signed(24 downto 0);
  signal \c$app_arg_133\                             : signed(24 downto 0);
  signal \c$app_arg_134\                             : signed(24 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal ampToneHighPrevR                            : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:970:1-10
  signal \c$ampToneHighPrevR_app_arg\                : signed(23 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal ampToneHighPrevL                            : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:970:1-10
  signal \c$ampToneHighPrevL_app_arg\                : signed(23 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal ampToneLowPrevR                             : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:970:1-10
  signal \c$ampToneLowPrevR_app_arg\                 : signed(23 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal ampToneLowPrevL                             : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:970:1-10
  signal \c$ampToneLowPrevL_app_arg\                 : signed(23 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal x_36                                        : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:166:1-7
  signal x_37                                        : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:166:1-7
  signal ds1_14                                      : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_86                                   : clash_lowpass_fir_types.Maybe;
  signal \c$app_arg_135\                             : signed(47 downto 0);
  signal \c$case_alt_60\                             : signed(23 downto 0);
  signal result_87                                   : signed(23 downto 0);
  signal result_88                                   : signed(23 downto 0);
  signal result_89                                   : signed(23 downto 0);
  signal \c$case_alt_61\                             : signed(23 downto 0);
  signal result_90                                   : signed(23 downto 0);
  signal \c$satWideOut_app_arg\                      : signed(47 downto 0);
  signal \c$satWideOut_app_arg_0\                    : signed(24 downto 0);
  signal \c$satWideOut_app_arg_1\                    : signed(24 downto 0);
  signal \c$satWideOut_case_scrut\                   : boolean;
  -- src/LowPassFir.hs:505:1-11
  signal positiveKnee                                : signed(23 downto 0);
  signal \c$satWideOut_app_arg_2\                    : signed(24 downto 0);
  signal \c$satWideOut_app_arg_3\                    : signed(24 downto 0);
  signal \c$satWideOut_app_arg_4\                    : signed(23 downto 0);
  -- src/LowPassFir.hs:505:1-11
  signal negativeKnee                                : signed(23 downto 0);
  -- src/LowPassFir.hs:505:1-11
  signal ch                                          : signed(24 downto 0);
  signal \c$app_arg_136\                             : signed(23 downto 0);
  signal \c$app_arg_137\                             : signed(47 downto 0);
  signal \c$case_alt_62\                             : signed(23 downto 0);
  signal result_91                                   : signed(23 downto 0);
  signal result_92                                   : signed(23 downto 0);
  signal result_93                                   : signed(23 downto 0);
  signal \c$case_alt_63\                             : signed(23 downto 0);
  signal result_94                                   : signed(23 downto 0);
  signal \c$satWideOut_app_arg_5\                    : signed(47 downto 0);
  signal \c$satWideOut_app_arg_6\                    : signed(24 downto 0);
  signal \c$satWideOut_app_arg_7\                    : signed(24 downto 0);
  signal \c$satWideOut_case_scrut_0\                 : boolean;
  -- src/LowPassFir.hs:505:1-11
  signal positiveKnee_0                              : signed(23 downto 0);
  signal \c$satWideOut_app_arg_8\                    : signed(24 downto 0);
  signal \c$satWideOut_app_arg_9\                    : signed(24 downto 0);
  signal \c$satWideOut_app_arg_10\                   : signed(23 downto 0);
  -- src/LowPassFir.hs:505:1-11
  signal negativeKnee_0                              : signed(23 downto 0);
  -- src/LowPassFir.hs:505:1-11
  signal ch_0                                        : signed(24 downto 0);
  signal \c$app_arg_138\                             : signed(23 downto 0);
  signal result_95                                   : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:538:1-19
  signal \on_14\                                     : boolean;
  -- src/LowPassFir.hs:538:1-19
  signal character                                   : unsigned(7 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal x_38                                        : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:970:1-10
  signal ds1_15                                      : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_96                                   : clash_lowpass_fir_types.Maybe;
  signal result_97                                   : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_139\                             : signed(47 downto 0);
  signal \c$app_arg_140\                             : signed(47 downto 0);
  -- src/LowPassFir.hs:531:1-27
  signal \on_15\                                     : boolean;
  signal \c$app_arg_141\                             : signed(47 downto 0);
  -- src/LowPassFir.hs:531:1-27
  signal gain_5                                      : unsigned(8 downto 0);
  -- src/LowPassFir.hs:531:1-27
  signal \c$gain_app_arg_3\                          : unsigned(7 downto 0);
  -- src/LowPassFir.hs:531:1-27
  signal \c$gain_app_arg_4\                          : unsigned(7 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal ampPreLowpassPipe                           : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_98                                   : clash_lowpass_fir_types.Maybe;
  -- src/LowPassFir.hs:523:1-18
  signal alpha                                       : unsigned(7 downto 0);
  -- src/LowPassFir.hs:523:1-18
  signal \on_16\                                     : boolean;
  signal result_99                                   : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_142\                             : signed(23 downto 0);
  signal \c$app_arg_143\                             : signed(47 downto 0);
  -- src/LowPassFir.hs:113:1-5
  signal gain_6                                      : unsigned(7 downto 0);
  signal \c$case_alt_64\                             : signed(23 downto 0);
  signal result_100                                  : signed(23 downto 0);
  signal \c$app_arg_144\                             : signed(23 downto 0);
  signal \c$app_arg_145\                             : signed(47 downto 0);
  -- src/LowPassFir.hs:113:1-5
  signal gain_7                                      : unsigned(7 downto 0);
  signal \c$case_alt_65\                             : signed(23 downto 0);
  signal result_101                                  : signed(23 downto 0);
  -- src/LowPassFir.hs:523:1-18
  signal \c$alpha_app_arg\                           : unsigned(7 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal ampPreLpPrevR                               : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:970:1-10
  signal \c$ampPreLpPrevR_app_arg\                   : signed(23 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal ampPreLpPrevL                               : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:970:1-10
  signal \c$ampPreLpPrevL_app_arg\                   : signed(23 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal x_39                                        : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:166:1-7
  signal x_40                                        : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:166:1-7
  signal ds1_16                                      : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_102                                  : clash_lowpass_fir_types.Maybe;
  -- src/LowPassFir.hs:516:1-17
  signal character_0                                 : unsigned(7 downto 0);
  -- src/LowPassFir.hs:516:1-17
  signal \on_17\                                     : boolean;
  signal result_103                                  : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_146\                             : signed(23 downto 0);
  signal result_104                                  : signed(23 downto 0);
  signal result_105                                  : signed(23 downto 0);
  signal \c$case_alt_66\                             : signed(23 downto 0);
  signal result_106                                  : signed(23 downto 0);
  signal \c$satWideOut_app_arg_11\                   : signed(47 downto 0);
  signal \c$satWideOut_app_arg_12\                   : signed(24 downto 0);
  signal \c$satWideOut_app_arg_13\                   : signed(24 downto 0);
  signal \c$satWideOut_case_scrut_1\                 : boolean;
  -- src/LowPassFir.hs:505:1-11
  signal positiveKnee_1                              : signed(23 downto 0);
  signal \c$satWideOut_app_arg_14\                   : signed(24 downto 0);
  signal \c$satWideOut_app_arg_15\                   : signed(24 downto 0);
  signal \c$satWideOut_app_arg_16\                   : signed(23 downto 0);
  -- src/LowPassFir.hs:505:1-11
  signal negativeKnee_1                              : signed(23 downto 0);
  -- src/LowPassFir.hs:505:1-11
  signal ch_1                                        : signed(24 downto 0);
  signal \c$app_arg_147\                             : signed(23 downto 0);
  signal result_107                                  : signed(23 downto 0);
  signal result_108                                  : signed(23 downto 0);
  signal \c$case_alt_67\                             : signed(23 downto 0);
  signal result_109                                  : signed(23 downto 0);
  signal \c$satWideOut_app_arg_17\                   : signed(47 downto 0);
  signal \c$satWideOut_app_arg_18\                   : signed(24 downto 0);
  signal \c$satWideOut_app_arg_19\                   : signed(24 downto 0);
  signal \c$satWideOut_case_scrut_2\                 : boolean;
  -- src/LowPassFir.hs:505:1-11
  signal positiveKnee_2                              : signed(23 downto 0);
  signal \c$satWideOut_app_arg_20\                   : signed(24 downto 0);
  signal \c$satWideOut_app_arg_21\                   : signed(24 downto 0);
  signal \c$satWideOut_app_arg_22\                   : signed(23 downto 0);
  -- src/LowPassFir.hs:505:1-11
  signal negativeKnee_2                              : signed(23 downto 0);
  -- src/LowPassFir.hs:505:1-11
  signal ch_2                                        : signed(24 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal x_41                                        : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:970:1-10
  signal ds1_17                                      : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_110                                  : clash_lowpass_fir_types.Maybe;
  signal \c$app_arg_148\                             : signed(47 downto 0);
  signal \c$case_alt_68\                             : signed(23 downto 0);
  signal result_111                                  : signed(23 downto 0);
  signal \c$app_arg_149\                             : signed(23 downto 0);
  signal \c$app_arg_150\                             : signed(47 downto 0);
  signal \c$case_alt_69\                             : signed(23 downto 0);
  signal result_112                                  : signed(23 downto 0);
  signal \c$app_arg_151\                             : signed(23 downto 0);
  signal result_113                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:499:1-18
  signal \on_18\                                     : boolean;
  -- src/LowPassFir.hs:970:1-10
  signal x_42                                        : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:970:1-10
  signal ds1_18                                      : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_114                                  : clash_lowpass_fir_types.Maybe;
  signal result_115                                  : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_152\                             : signed(47 downto 0);
  signal \c$app_arg_153\                             : signed(47 downto 0);
  -- src/LowPassFir.hs:491:1-21
  signal \on_19\                                     : boolean;
  signal \c$app_arg_154\                             : signed(47 downto 0);
  -- src/LowPassFir.hs:491:1-21
  signal gain_8                                      : unsigned(11 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal ampHighpassPipe                             : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_116                                  : clash_lowpass_fir_types.Maybe;
  -- src/LowPassFir.hs:125:1-7
  signal x_43                                        : signed(47 downto 0);
  signal \c$case_alt_70\                             : signed(23 downto 0);
  signal result_117                                  : signed(23 downto 0);
  signal \c$app_arg_155\                             : signed(23 downto 0);
  -- src/LowPassFir.hs:125:1-7
  signal x_44                                        : signed(47 downto 0);
  signal \c$case_alt_71\                             : signed(23 downto 0);
  signal result_118                                  : signed(23 downto 0);
  signal \c$app_arg_156\                             : signed(23 downto 0);
  signal result_119                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:478:1-16
  signal \on_20\                                     : boolean;
  -- src/LowPassFir.hs:970:1-10
  signal ampHpOutPrevR                               : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:970:1-10
  signal \c$ampHpOutPrevR_app_arg\                   : signed(23 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal ampHpOutPrevL                               : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:970:1-10
  signal \c$ampHpOutPrevL_app_arg\                   : signed(23 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal ampHpInPrevR                                : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:970:1-10
  signal \c$ampHpInPrevR_app_arg\                    : signed(23 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal ampHpInPrevL                                : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:970:1-10
  signal \c$ampHpInPrevL_app_arg\                    : signed(23 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal x_45                                        : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:166:1-7
  signal x_46                                        : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:166:1-7
  signal ds1_19                                      : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_120                                  : clash_lowpass_fir_types.Maybe;
  signal result_121                                  : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_157\                             : signed(23 downto 0);
  signal result_122                                  : signed(23 downto 0);
  signal \c$case_alt_72\                             : signed(23 downto 0);
  signal \c$app_arg_158\                             : signed(24 downto 0);
  signal \c$app_arg_159\                             : signed(24 downto 0);
  signal \c$app_arg_160\                             : signed(24 downto 0);
  signal \c$case_alt_73\                             : signed(23 downto 0);
  signal result_123                                  : signed(23 downto 0);
  signal \c$app_arg_161\                             : signed(47 downto 0);
  signal \c$app_arg_162\                             : signed(23 downto 0);
  -- src/LowPassFir.hs:468:1-11
  signal \on_21\                                     : boolean;
  signal result_124                                  : signed(23 downto 0);
  signal \c$case_alt_74\                             : signed(23 downto 0);
  signal \c$app_arg_163\                             : signed(24 downto 0);
  signal \c$app_arg_164\                             : signed(24 downto 0);
  signal \c$app_arg_165\                             : signed(24 downto 0);
  signal \c$case_alt_75\                             : signed(23 downto 0);
  signal result_125                                  : signed(23 downto 0);
  signal \c$app_arg_166\                             : signed(47 downto 0);
  signal \c$app_arg_167\                             : signed(47 downto 0);
  signal \c$app_arg_168\                             : signed(47 downto 0);
  -- src/LowPassFir.hs:468:1-11
  signal invMix_0                                    : unsigned(7 downto 0);
  -- src/LowPassFir.hs:468:1-11
  signal mix_0                                       : unsigned(7 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal x_47                                        : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:970:1-10
  signal ds1_20                                      : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_126                                  : clash_lowpass_fir_types.Maybe;
  signal result_127                                  : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_169\                             : signed(23 downto 0);
  signal \c$case_alt_76\                             : signed(23 downto 0);
  signal result_128                                  : signed(23 downto 0);
  signal \c$app_arg_170\                             : signed(47 downto 0);
  signal \c$app_arg_171\                             : signed(23 downto 0);
  -- src/LowPassFir.hs:459:1-13
  signal \on_22\                                     : boolean;
  signal \c$case_alt_77\                             : signed(23 downto 0);
  signal result_129                                  : signed(23 downto 0);
  signal \c$app_arg_172\                             : signed(47 downto 0);
  signal \c$app_arg_173\                             : signed(47 downto 0);
  -- src/LowPassFir.hs:459:1-13
  signal level_1                                     : unsigned(7 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal ratTonePipe                                 : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_130                                  : clash_lowpass_fir_types.Maybe;
  -- src/LowPassFir.hs:451:1-12
  signal alpha_0                                     : unsigned(7 downto 0);
  -- src/LowPassFir.hs:451:1-12
  signal \on_23\                                     : boolean;
  signal result_131                                  : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_174\                             : signed(23 downto 0);
  signal \c$app_arg_175\                             : signed(47 downto 0);
  -- src/LowPassFir.hs:113:1-5
  signal gain_9                                      : unsigned(7 downto 0);
  signal \c$case_alt_78\                             : signed(23 downto 0);
  signal result_132                                  : signed(23 downto 0);
  signal \c$app_arg_176\                             : signed(23 downto 0);
  signal \c$app_arg_177\                             : signed(47 downto 0);
  -- src/LowPassFir.hs:113:1-5
  signal gain_10                                     : unsigned(7 downto 0);
  signal \c$case_alt_79\                             : signed(23 downto 0);
  signal result_133                                  : signed(23 downto 0);
  -- src/LowPassFir.hs:451:1-12
  signal \c$alpha_app_arg_0\                         : unsigned(9 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal ratTonePrevR                                : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:970:1-10
  signal \c$ratTonePrevR_app_arg\                    : signed(23 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal ratTonePrevL                                : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:970:1-10
  signal \c$ratTonePrevL_app_arg\                    : signed(23 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal x_48                                        : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:970:1-10
  signal ratPostPipe                                 : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_134                                  : clash_lowpass_fir_types.Maybe;
  -- src/LowPassFir.hs:445:1-19
  signal \on_24\                                     : boolean;
  signal result_135                                  : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_178\                             : signed(23 downto 0);
  signal \c$app_arg_179\                             : signed(47 downto 0);
  signal \c$case_alt_80\                             : signed(23 downto 0);
  signal result_136                                  : signed(23 downto 0);
  signal \c$app_arg_180\                             : signed(23 downto 0);
  signal \c$app_arg_181\                             : signed(47 downto 0);
  signal \c$case_alt_81\                             : signed(23 downto 0);
  signal result_137                                  : signed(23 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal ratPostPrevR                                : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:970:1-10
  signal \c$ratPostPrevR_app_arg\                    : signed(23 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal ratPostPrevL                                : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:970:1-10
  signal \c$ratPostPrevL_app_arg\                    : signed(23 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal x_49                                        : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:166:1-7
  signal x_50                                        : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:166:1-7
  signal ds1_21                                      : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_138                                  : clash_lowpass_fir_types.Maybe;
  -- src/LowPassFir.hs:435:1-12
  signal threshold                                   : signed(23 downto 0);
  -- src/LowPassFir.hs:435:1-12
  signal \on_25\                                     : boolean;
  signal result_139                                  : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_182\                             : signed(23 downto 0);
  signal result_140                                  : signed(23 downto 0);
  signal \c$case_alt_82\                             : signed(23 downto 0);
  signal \c$app_arg_183\                             : signed(23 downto 0);
  signal \c$app_arg_184\                             : signed(23 downto 0);
  signal result_141                                  : signed(23 downto 0);
  signal \c$case_alt_83\                             : signed(23 downto 0);
  signal \c$app_arg_185\                             : signed(23 downto 0);
  -- src/LowPassFir.hs:435:1-12
  signal rawThreshold                                : signed(24 downto 0);
  signal result_142                                  : signed(24 downto 0);
  -- src/LowPassFir.hs:98:1-9
  signal x_51                                        : unsigned(7 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal ratOpAmpPipe                                : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_143                                  : clash_lowpass_fir_types.Maybe;
  -- src/LowPassFir.hs:426:1-20
  signal alpha_1                                     : unsigned(7 downto 0);
  -- src/LowPassFir.hs:426:1-20
  signal \on_26\                                     : boolean;
  signal result_144                                  : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_186\                             : signed(23 downto 0);
  signal \c$app_arg_187\                             : signed(47 downto 0);
  -- src/LowPassFir.hs:113:1-5
  signal gain_11                                     : unsigned(7 downto 0);
  signal \c$case_alt_84\                             : signed(23 downto 0);
  signal result_145                                  : signed(23 downto 0);
  signal \c$app_arg_188\                             : signed(23 downto 0);
  signal \c$app_arg_189\                             : signed(47 downto 0);
  -- src/LowPassFir.hs:113:1-5
  signal gain_12                                     : unsigned(7 downto 0);
  signal \c$case_alt_85\                             : signed(23 downto 0);
  signal result_146                                  : signed(23 downto 0);
  -- src/LowPassFir.hs:426:1-20
  signal \c$alpha_app_arg_1\                         : unsigned(7 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal ratOpAmpPrevR                               : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:970:1-10
  signal \c$ratOpAmpPrevR_app_arg\                   : signed(23 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal ratOpAmpPrevL                               : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:970:1-10
  signal \c$ratOpAmpPrevL_app_arg\                   : signed(23 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal x_52                                        : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:166:1-7
  signal x_53                                        : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:166:1-7
  signal ds1_22                                      : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_147                                  : clash_lowpass_fir_types.Maybe;
  signal \c$app_arg_190\                             : signed(47 downto 0);
  signal \c$case_alt_86\                             : signed(23 downto 0);
  signal result_148                                  : signed(23 downto 0);
  signal \c$app_arg_191\                             : signed(23 downto 0);
  signal \c$app_arg_192\                             : signed(47 downto 0);
  signal \c$case_alt_87\                             : signed(23 downto 0);
  signal result_149                                  : signed(23 downto 0);
  signal \c$app_arg_193\                             : signed(23 downto 0);
  signal result_150                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:420:1-18
  signal \on_27\                                     : boolean;
  -- src/LowPassFir.hs:970:1-10
  signal x_54                                        : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:970:1-10
  signal ds1_23                                      : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_151                                  : clash_lowpass_fir_types.Maybe;
  signal result_152                                  : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_194\                             : signed(47 downto 0);
  signal \c$app_arg_195\                             : signed(47 downto 0);
  -- src/LowPassFir.hs:413:1-21
  signal \on_28\                                     : boolean;
  signal \c$app_arg_196\                             : signed(47 downto 0);
  -- src/LowPassFir.hs:413:1-21
  signal driveGain                                   : unsigned(11 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal ratHighpassPipe                             : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_153                                  : clash_lowpass_fir_types.Maybe;
  -- src/LowPassFir.hs:125:1-7
  signal x_55                                        : signed(47 downto 0);
  signal \c$case_alt_88\                             : signed(23 downto 0);
  signal result_154                                  : signed(23 downto 0);
  signal \c$app_arg_197\                             : signed(23 downto 0);
  -- src/LowPassFir.hs:125:1-7
  signal x_56                                        : signed(47 downto 0);
  signal \c$case_alt_89\                             : signed(23 downto 0);
  signal result_155                                  : signed(23 downto 0);
  signal \c$app_arg_198\                             : signed(23 downto 0);
  signal result_156                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:400:1-16
  signal \on_29\                                     : boolean;
  -- src/LowPassFir.hs:970:1-10
  signal ratHpOutPrevR                               : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:970:1-10
  signal \c$ratHpOutPrevR_app_arg\                   : signed(23 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal ratHpOutPrevL                               : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:970:1-10
  signal \c$ratHpOutPrevL_app_arg\                   : signed(23 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal ratHpInPrevR                                : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:970:1-10
  signal \c$ratHpInPrevR_app_arg\                    : signed(23 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal ratHpInPrevL                                : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:970:1-10
  signal \c$ratHpInPrevL_app_arg\                    : signed(23 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal x_57                                        : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:166:1-7
  signal x_58                                        : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:166:1-7
  signal ds1_24                                      : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_157                                  : clash_lowpass_fir_types.Maybe;
  signal result_158                                  : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_199\                             : signed(23 downto 0);
  signal \c$case_alt_90\                             : signed(23 downto 0);
  signal result_159                                  : signed(23 downto 0);
  signal \c$app_arg_200\                             : signed(47 downto 0);
  signal \c$app_arg_201\                             : signed(23 downto 0);
  -- src/LowPassFir.hs:391:1-20
  signal \on_30\                                     : boolean;
  signal \c$case_alt_91\                             : signed(23 downto 0);
  signal result_160                                  : signed(23 downto 0);
  signal \c$app_arg_202\                             : signed(47 downto 0);
  signal \c$app_arg_203\                             : signed(47 downto 0);
  -- src/LowPassFir.hs:391:1-20
  signal level_2                                     : unsigned(7 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal distToneBlendPipe                           : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_161                                  : clash_lowpass_fir_types.Maybe;
  signal \c$app_arg_204\                             : signed(47 downto 0);
  signal \c$case_alt_92\                             : signed(23 downto 0);
  signal result_162                                  : signed(23 downto 0);
  signal \c$app_arg_205\                             : signed(23 downto 0);
  signal \c$app_arg_206\                             : signed(47 downto 0);
  signal \c$case_alt_93\                             : signed(23 downto 0);
  signal result_163                                  : signed(23 downto 0);
  signal \c$app_arg_207\                             : signed(23 downto 0);
  signal result_164                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:380:1-24
  signal \on_31\                                     : boolean;
  -- src/LowPassFir.hs:970:1-10
  signal x_59                                        : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:970:1-10
  signal ds1_25                                      : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_165                                  : clash_lowpass_fir_types.Maybe;
  signal result_166                                  : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_208\                             : signed(47 downto 0);
  signal \c$app_arg_209\                             : signed(47 downto 0);
  signal \c$app_arg_210\                             : signed(47 downto 0);
  -- src/LowPassFir.hs:367:1-27
  signal toneInv                                     : unsigned(7 downto 0);
  signal \c$app_arg_211\                             : signed(47 downto 0);
  signal \c$app_arg_212\                             : signed(47 downto 0);
  -- src/LowPassFir.hs:367:1-27
  signal \on_32\                                     : boolean;
  signal \c$app_arg_213\                             : signed(47 downto 0);
  -- src/LowPassFir.hs:367:1-27
  signal tone                                        : unsigned(7 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal distTonePrevR                               : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:970:1-10
  signal \c$distTonePrevR_app_arg\                   : signed(23 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal distTonePrevL                               : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:970:1-10
  signal \c$distTonePrevL_app_arg\                   : signed(23 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal x_60                                        : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:166:1-7
  signal x_61                                        : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:166:1-7
  signal ds1_26                                      : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_167                                  : clash_lowpass_fir_types.Maybe;
  -- src/LowPassFir.hs:360:1-24
  signal threshold_0                                 : signed(23 downto 0);
  -- src/LowPassFir.hs:360:1-24
  signal \on_33\                                     : boolean;
  signal result_168                                  : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_214\                             : signed(23 downto 0);
  signal result_169                                  : signed(23 downto 0);
  signal \c$case_alt_94\                             : signed(23 downto 0);
  signal \c$app_arg_215\                             : signed(23 downto 0);
  signal \c$app_arg_216\                             : signed(23 downto 0);
  signal result_170                                  : signed(23 downto 0);
  signal \c$case_alt_95\                             : signed(23 downto 0);
  signal \c$app_arg_217\                             : signed(23 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal x_62                                        : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:970:1-10
  signal ds1_27                                      : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_171                                  : clash_lowpass_fir_types.Maybe;
  signal \c$app_arg_218\                             : signed(47 downto 0);
  signal \c$case_alt_96\                             : signed(23 downto 0);
  signal result_172                                  : signed(23 downto 0);
  signal \c$app_arg_219\                             : signed(23 downto 0);
  signal \c$app_arg_220\                             : signed(47 downto 0);
  signal \c$case_alt_97\                             : signed(23 downto 0);
  signal result_173                                  : signed(23 downto 0);
  signal \c$app_arg_221\                             : signed(23 downto 0);
  signal result_174                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:354:1-25
  signal \on_34\                                     : boolean;
  -- src/LowPassFir.hs:970:1-10
  signal x_63                                        : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:970:1-10
  signal ds1_28                                      : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_175                                  : clash_lowpass_fir_types.Maybe;
  signal result_176                                  : clash_lowpass_fir_types.Frame;
  signal result_177                                  : signed(24 downto 0);
  -- src/LowPassFir.hs:339:1-28
  signal rawThreshold_0                              : signed(24 downto 0);
  signal \c$app_arg_222\                             : signed(47 downto 0);
  signal \c$app_arg_223\                             : signed(47 downto 0);
  -- src/LowPassFir.hs:339:1-28
  signal \on_35\                                     : boolean;
  signal \c$app_arg_224\                             : signed(47 downto 0);
  -- src/LowPassFir.hs:339:1-28
  signal driveGain_0                                 : unsigned(11 downto 0);
  -- src/LowPassFir.hs:339:1-28
  signal amount                                      : unsigned(7 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal x_64                                        : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:970:1-10
  signal ds1_29                                      : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_178                                  : clash_lowpass_fir_types.Maybe;
  signal result_179                                  : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_225\                             : signed(23 downto 0);
  signal \c$case_alt_98\                             : signed(23 downto 0);
  signal result_180                                  : signed(23 downto 0);
  signal \c$app_arg_226\                             : signed(47 downto 0);
  signal \c$app_arg_227\                             : signed(23 downto 0);
  -- src/LowPassFir.hs:330:1-19
  signal \on_36\                                     : boolean;
  signal \c$case_alt_99\                             : signed(23 downto 0);
  signal result_181                                  : signed(23 downto 0);
  signal \c$app_arg_228\                             : signed(47 downto 0);
  signal \c$app_arg_229\                             : signed(47 downto 0);
  -- src/LowPassFir.hs:330:1-19
  signal level_3                                     : unsigned(7 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal odToneBlendPipe                             : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_182                                  : clash_lowpass_fir_types.Maybe;
  signal \c$app_arg_230\                             : signed(47 downto 0);
  signal \c$case_alt_100\                            : signed(23 downto 0);
  signal result_183                                  : signed(23 downto 0);
  signal \c$app_arg_231\                             : signed(23 downto 0);
  signal \c$app_arg_232\                             : signed(47 downto 0);
  signal \c$case_alt_101\                            : signed(23 downto 0);
  signal result_184                                  : signed(23 downto 0);
  signal \c$app_arg_233\                             : signed(23 downto 0);
  signal result_185                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:319:1-23
  signal \on_37\                                     : boolean;
  -- src/LowPassFir.hs:970:1-10
  signal x_65                                        : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:970:1-10
  signal ds1_30                                      : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_186                                  : clash_lowpass_fir_types.Maybe;
  signal result_187                                  : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_234\                             : signed(47 downto 0);
  signal \c$app_arg_235\                             : signed(47 downto 0);
  signal \c$app_arg_236\                             : signed(47 downto 0);
  -- src/LowPassFir.hs:306:1-26
  signal toneInv_0                                   : unsigned(7 downto 0);
  signal \c$app_arg_237\                             : signed(47 downto 0);
  signal \c$app_arg_238\                             : signed(47 downto 0);
  -- src/LowPassFir.hs:306:1-26
  signal \on_38\                                     : boolean;
  signal \c$app_arg_239\                             : signed(47 downto 0);
  -- src/LowPassFir.hs:306:1-26
  signal tone_0                                      : unsigned(7 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal odTonePrevR                                 : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:970:1-10
  signal \c$odTonePrevR_app_arg\                     : signed(23 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal odTonePrevL                                 : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:970:1-10
  signal \c$odTonePrevL_app_arg\                     : signed(23 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal x_66                                        : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:166:1-7
  signal x_67                                        : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:166:1-7
  signal ds1_31                                      : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_188                                  : clash_lowpass_fir_types.Maybe;
  -- src/LowPassFir.hs:300:1-23
  signal \on_39\                                     : boolean;
  signal result_189                                  : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_240\                             : signed(23 downto 0);
  signal result_190                                  : signed(23 downto 0);
  signal \c$case_alt_102\                            : signed(23 downto 0);
  signal \c$app_arg_241\                             : signed(24 downto 0);
  signal \c$app_arg_242\                             : signed(24 downto 0);
  signal \c$app_arg_243\                             : signed(24 downto 0);
  signal \c$app_arg_244\                             : signed(23 downto 0);
  signal result_191                                  : signed(23 downto 0);
  signal \c$case_alt_103\                            : signed(23 downto 0);
  signal \c$app_arg_245\                             : signed(24 downto 0);
  signal \c$app_arg_246\                             : signed(24 downto 0);
  signal \c$app_arg_247\                             : signed(24 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal x_68                                        : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:970:1-10
  signal ds1_32                                      : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_192                                  : clash_lowpass_fir_types.Maybe;
  signal \c$app_arg_248\                             : signed(47 downto 0);
  signal \c$case_alt_104\                            : signed(23 downto 0);
  signal result_193                                  : signed(23 downto 0);
  signal \c$app_arg_249\                             : signed(23 downto 0);
  signal \c$app_arg_250\                             : signed(47 downto 0);
  signal \c$case_alt_105\                            : signed(23 downto 0);
  signal result_194                                  : signed(23 downto 0);
  signal \c$app_arg_251\                             : signed(23 downto 0);
  signal result_195                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:294:1-24
  signal \on_40\                                     : boolean;
  -- src/LowPassFir.hs:970:1-10
  signal x_69                                        : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:970:1-10
  signal ds1_33                                      : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_196                                  : clash_lowpass_fir_types.Maybe;
  signal result_197                                  : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_252\                             : signed(47 downto 0);
  signal \c$app_arg_253\                             : signed(47 downto 0);
  -- src/LowPassFir.hs:287:1-27
  signal \on_41\                                     : boolean;
  signal \c$app_arg_254\                             : signed(47 downto 0);
  -- src/LowPassFir.hs:287:1-27
  signal driveGain_1                                 : unsigned(11 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal x_70                                        : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:970:1-10
  signal ds1_34                                      : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_198                                  : clash_lowpass_fir_types.Maybe;
  signal result_199                                  : clash_lowpass_fir_types.Frame;
  signal \c$case_alt_106\                            : signed(23 downto 0);
  signal result_200                                  : signed(23 downto 0);
  signal \c$app_arg_255\                             : signed(47 downto 0);
  signal \c$case_alt_107\                            : signed(23 downto 0);
  signal result_201                                  : signed(23 downto 0);
  signal \c$app_arg_256\                             : signed(47 downto 0);
  signal \c$app_arg_257\                             : signed(47 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal gateGain                                    : unsigned(11 downto 0) := to_unsigned(4095,12);
  signal \c$case_alt_108\                            : unsigned(11 downto 0);
  signal \c$case_alt_109\                            : unsigned(11 downto 0);
  signal \c$case_alt_110\                            : unsigned(11 downto 0);
  signal \c$case_alt_111\                            : unsigned(11 downto 0);
  -- src/LowPassFir.hs:272:1-12
  signal f_2                                         : clash_lowpass_fir_types.Frame;
  signal result_202                                  : unsigned(11 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal gateOpen                                    : boolean := true;
  signal result_203                                  : boolean;
  signal \c$case_alt_112\                            : boolean;
  signal result_204                                  : boolean;
  signal \c$case_alt_113\                            : boolean;
  signal \c$case_alt_114\                            : boolean;
  -- src/LowPassFir.hs:125:1-7
  signal x_71                                        : signed(47 downto 0);
  signal \c$case_alt_115\                            : signed(23 downto 0);
  signal result_205                                  : signed(23 downto 0);
  signal \c$app_arg_258\                             : signed(47 downto 0);
  signal \c$app_arg_259\                             : signed(47 downto 0);
  -- src/LowPassFir.hs:260:1-12
  signal closeThreshold                              : signed(23 downto 0);
  -- src/LowPassFir.hs:98:1-9
  signal x_72                                        : unsigned(7 downto 0);
  signal \c$app_arg_260\                             : std_logic_vector(31 downto 0);
  -- src/LowPassFir.hs:260:1-12
  signal f_3                                         : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:970:1-10
  signal gateEnv                                     : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:249:1-11
  signal \c$decay_app_arg\                           : signed(24 downto 0);
  signal result_206                                  : signed(23 downto 0);
  signal \c$case_alt_116\                            : signed(23 downto 0);
  signal \c$case_alt_117\                            : signed(23 downto 0);
  -- src/LowPassFir.hs:249:1-11
  signal f_4                                         : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:249:1-11
  signal decay                                       : signed(23 downto 0);
  signal result_207                                  : signed(23 downto 0);
  -- src/LowPassFir.hs:166:1-7
  signal x_73                                        : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:970:1-10
  signal gateLevelPipe                               : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_208                                  : clash_lowpass_fir_types.Maybe;
  signal result_209                                  : signed(23 downto 0);
  signal \c$case_alt_118\                            : clash_lowpass_fir_types.Frame;
  signal \c$case_alt_119\                            : signed(23 downto 0);
  signal result_210                                  : signed(23 downto 0);
  signal \c$case_alt_120\                            : signed(23 downto 0);
  signal result_211                                  : signed(23 downto 0);
  -- src/LowPassFir.hs:970:1-10
  signal x_74                                        : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:970:1-10
  signal ds1_35                                      : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  -- src/LowPassFir.hs:206:1-9
  signal validIn                                     : boolean;
  -- src/LowPassFir.hs:206:1-9
  signal right                                       : signed(23 downto 0);
  -- src/LowPassFir.hs:206:1-9
  signal left                                        : signed(23 downto 0);
  signal result_212                                  : clash_lowpass_fir_types.Tuple2_0;
  signal \c$app_arg_261\                             : std_logic_vector(47 downto 0);
  signal result_213                                  : clash_lowpass_fir_types.Maybe;
  -- src/LowPassFir.hs:970:1-10
  signal \c$reverbAddr_case_alt\                     : clash_lowpass_fir_types.index_1024;
  signal result_selection_res                        : boolean;
  signal \c$bv\                                      : std_logic_vector(31 downto 0);
  signal \c$bv_0\                                    : std_logic_vector(31 downto 0);
  signal \c$shI\                                     : signed(63 downto 0);
  signal \c$case_alt_selection_res\                  : boolean;
  signal result_selection_res_2                      : boolean;
  signal \c$shI_0\                                   : signed(63 downto 0);
  signal \c$case_alt_selection_res_0\                : boolean;
  signal result_selection_res_3                      : boolean;
  signal \c$bv_1\                                    : std_logic_vector(31 downto 0);
  signal \c$wrI\                                     : signed(63 downto 0);
  signal \c$wrI_0\                                   : signed(63 downto 0);
  signal \c$shI_1\                                   : signed(63 downto 0);
  signal \c$case_alt_selection_res_1\                : boolean;
  signal result_selection_res_4                      : boolean;
  signal \c$shI_2\                                   : signed(63 downto 0);
  signal \c$case_alt_selection_res_2\                : boolean;
  signal result_selection_res_5                      : boolean;
  signal \c$bv_2\                                    : std_logic_vector(31 downto 0);
  signal \c$bv_3\                                    : std_logic_vector(31 downto 0);
  signal \c$bv_4\                                    : std_logic_vector(31 downto 0);
  signal \c$shI_3\                                   : signed(63 downto 0);
  signal \c$shI_4\                                   : signed(63 downto 0);
  signal \c$case_alt_selection_res_3\                : boolean;
  signal result_selection_res_6                      : boolean;
  signal \c$shI_5\                                   : signed(63 downto 0);
  signal \c$shI_6\                                   : signed(63 downto 0);
  signal \c$case_alt_selection_res_4\                : boolean;
  signal result_selection_res_7                      : boolean;
  signal \c$bv_5\                                    : std_logic_vector(31 downto 0);
  signal \c$bv_6\                                    : std_logic_vector(31 downto 0);
  signal \c$case_alt_selection_res_5\                : boolean;
  signal result_selection_res_8                      : boolean;
  signal \c$shI_7\                                   : signed(63 downto 0);
  signal \c$case_alt_selection_res_6\                : boolean;
  signal result_selection_res_9                      : boolean;
  signal \c$shI_8\                                   : signed(63 downto 0);
  signal \c$bv_7\                                    : std_logic_vector(31 downto 0);
  signal \c$case_alt_selection_res_7\                : boolean;
  signal result_selection_res_10                     : boolean;
  signal \c$case_alt_selection_res_8\                : boolean;
  signal result_selection_res_11                     : boolean;
  signal \c$case_alt_selection_res_9\                : boolean;
  signal result_selection_res_12                     : boolean;
  signal \c$case_alt_selection_res_10\               : boolean;
  signal result_selection_res_13                     : boolean;
  signal \c$shI_9\                                   : signed(63 downto 0);
  signal \c$shI_10\                                  : signed(63 downto 0);
  signal \c$shI_11\                                  : signed(63 downto 0);
  signal \c$shI_12\                                  : signed(63 downto 0);
  signal result_selection_res_14                     : boolean;
  signal \c$case_alt_selection_res_11\               : boolean;
  signal \c$shI_13\                                  : signed(63 downto 0);
  signal \c$shI_14\                                  : signed(63 downto 0);
  signal \c$case_alt_selection_res_12\               : boolean;
  signal result_selection_res_15                     : boolean;
  signal \c$shI_15\                                  : signed(63 downto 0);
  signal \c$case_alt_selection_res_13\               : boolean;
  signal result_selection_res_16                     : boolean;
  signal \c$shI_16\                                  : signed(63 downto 0);
  signal \c$bv_8\                                    : std_logic_vector(31 downto 0);
  signal result_selection_res_17                     : boolean;
  signal \c$case_alt_selection_res_14\               : boolean;
  signal \c$shI_17\                                  : signed(63 downto 0);
  signal \c$shI_18\                                  : signed(63 downto 0);
  signal \c$case_alt_selection_res_15\               : boolean;
  signal result_selection_res_18                     : boolean;
  signal \c$shI_19\                                  : signed(63 downto 0);
  signal \c$case_alt_selection_res_16\               : boolean;
  signal result_selection_res_19                     : boolean;
  signal \c$shI_20\                                  : signed(63 downto 0);
  signal \c$shI_21\                                  : signed(63 downto 0);
  signal \c$case_alt_selection_res_17\               : boolean;
  signal result_selection_res_20                     : boolean;
  signal \c$shI_22\                                  : signed(63 downto 0);
  signal \c$case_alt_selection_res_18\               : boolean;
  signal result_selection_res_21                     : boolean;
  signal \c$bv_9\                                    : std_logic_vector(31 downto 0);
  signal \c$shI_23\                                  : signed(63 downto 0);
  signal \c$cabCoeff_$jOut_app_arg_selection_res\    : boolean;
  signal \c$cabCoeff_$jOut_case_alt_selection_res\   : boolean;
  signal \c$shI_24\                                  : signed(63 downto 0);
  signal \c$cabCoeff_$jOut_app_arg_selection_res_0\  : boolean;
  signal \c$cabCoeff_$jOut_case_alt_selection_res_0\ : boolean;
  signal \c$bv_10\                                   : std_logic_vector(31 downto 0);
  signal \c$shI_25\                                  : signed(63 downto 0);
  signal \c$cabCoeff_$jOut_app_arg_selection_res_1\  : boolean;
  signal \c$cabCoeff_$jOut_case_alt_selection_res_1\ : boolean;
  signal \c$shI_26\                                  : signed(63 downto 0);
  signal \c$cabCoeff_$jOut_app_arg_selection_res_2\  : boolean;
  signal \c$cabCoeff_$jOut_case_alt_selection_res_2\ : boolean;
  signal result_selection_res_22                     : boolean;
  signal \c$case_alt_selection_res_19\               : boolean;
  signal \c$shI_27\                                  : signed(63 downto 0);
  signal \c$shI_28\                                  : signed(63 downto 0);
  signal \c$case_alt_selection_res_20\               : boolean;
  signal result_selection_res_23                     : boolean;
  signal \c$shI_29\                                  : signed(63 downto 0);
  signal \c$bv_11\                                   : std_logic_vector(31 downto 0);
  signal result_selection_res_24                     : boolean;
  signal \c$case_alt_selection_res_21\               : boolean;
  signal \c$shI_30\                                  : signed(63 downto 0);
  signal \c$shI_31\                                  : signed(63 downto 0);
  signal \c$case_alt_selection_res_22\               : boolean;
  signal result_selection_res_25                     : boolean;
  signal \c$shI_32\                                  : signed(63 downto 0);
  signal \c$bv_12\                                   : std_logic_vector(31 downto 0);
  signal \c$shI_33\                                  : signed(63 downto 0);
  signal \c$case_alt_selection_res_23\               : boolean;
  signal result_selection_res_26                     : boolean;
  signal \c$shI_34\                                  : signed(63 downto 0);
  signal \c$case_alt_selection_res_24\               : boolean;
  signal result_selection_res_27                     : boolean;
  signal \c$case_alt_selection_res_25\               : boolean;
  signal result_selection_res_28                     : boolean;
  signal result_selection_res_29                     : boolean;
  signal \c$case_alt_selection_res_26\               : boolean;
  signal \c$shI_35\                                  : signed(63 downto 0);
  signal \c$shI_36\                                  : signed(63 downto 0);
  signal \c$shI_37\                                  : signed(63 downto 0);
  signal \c$case_alt_selection_res_27\               : boolean;
  signal result_selection_res_30                     : boolean;
  signal \c$shI_38\                                  : signed(63 downto 0);
  signal \c$case_alt_selection_res_28\               : boolean;
  signal result_selection_res_31                     : boolean;
  signal \c$case_alt_selection_res_29\               : boolean;
  signal result_selection_res_32                     : boolean;
  signal result_selection_res_33                     : boolean;
  signal \c$case_alt_selection_res_30\               : boolean;
  signal \c$shI_39\                                  : signed(63 downto 0);
  signal \c$shI_40\                                  : signed(63 downto 0);
  signal \c$bv_13\                                   : std_logic_vector(31 downto 0);
  signal \c$case_alt_selection_res_31\               : boolean;
  signal result_selection_res_34                     : boolean;
  signal \c$case_alt_selection_res_32\               : boolean;
  signal result_selection_res_35                     : boolean;
  signal \c$bv_14\                                   : std_logic_vector(31 downto 0);
  signal \c$shI_41\                                  : signed(63 downto 0);
  signal \c$shI_42\                                  : signed(63 downto 0);
  signal \c$shI_43\                                  : signed(63 downto 0);
  signal \c$shI_44\                                  : signed(63 downto 0);
  signal \c$bv_15\                                   : std_logic_vector(31 downto 0);
  signal result_selection_res_36                     : boolean;
  signal \c$case_alt_selection_res_33\               : boolean;
  signal \c$shI_45\                                  : signed(63 downto 0);
  signal \c$shI_46\                                  : signed(63 downto 0);
  signal result_selection_res_37                     : boolean;
  signal \c$case_alt_selection_res_34\               : boolean;
  signal \c$shI_47\                                  : signed(63 downto 0);
  signal \c$shI_48\                                  : signed(63 downto 0);
  signal \c$shI_49\                                  : signed(63 downto 0);
  signal \c$case_alt_selection_res_35\               : boolean;
  signal result_selection_res_38                     : boolean;
  signal \c$shI_50\                                  : signed(63 downto 0);
  signal \c$case_alt_selection_res_36\               : boolean;
  signal result_selection_res_39                     : boolean;
  signal \c$bv_16\                                   : std_logic_vector(31 downto 0);
  signal \c$shI_51\                                  : signed(63 downto 0);
  signal \c$shI_52\                                  : signed(63 downto 0);
  signal \c$bv_17\                                   : std_logic_vector(31 downto 0);
  signal \c$shI_53\                                  : signed(63 downto 0);
  signal \c$case_alt_selection_res_37\               : boolean;
  signal result_selection_res_40                     : boolean;
  signal \c$case_alt_selection_res_38\               : boolean;
  signal result_selection_res_41                     : boolean;
  signal \c$case_alt_selection_res_39\               : boolean;
  signal result_selection_res_42                     : boolean;
  signal \c$case_alt_selection_res_40\               : boolean;
  signal result_selection_res_43                     : boolean;
  signal \c$shI_54\                                  : signed(63 downto 0);
  signal \c$shI_55\                                  : signed(63 downto 0);
  signal \c$shI_56\                                  : signed(63 downto 0);
  signal \c$shI_57\                                  : signed(63 downto 0);
  signal \c$shI_58\                                  : signed(63 downto 0);
  signal \c$case_alt_selection_res_41\               : boolean;
  signal result_selection_res_44                     : boolean;
  signal result_selection_res_45                     : boolean;
  signal \c$case_alt_selection_res_42\               : boolean;
  signal result_selection_res_46                     : boolean;
  signal \c$shI_59\                                  : signed(63 downto 0);
  signal \c$shI_60\                                  : signed(63 downto 0);
  signal \c$shI_61\                                  : signed(63 downto 0);
  signal \c$case_alt_selection_res_43\               : boolean;
  signal result_selection_res_47                     : boolean;
  signal result_selection_res_48                     : boolean;
  signal \c$case_alt_selection_res_44\               : boolean;
  signal result_selection_res_49                     : boolean;
  signal \c$shI_62\                                  : signed(63 downto 0);
  signal \c$shI_63\                                  : signed(63 downto 0);
  signal \c$bv_18\                                   : std_logic_vector(31 downto 0);
  signal \c$bv_19\                                   : std_logic_vector(31 downto 0);
  signal \c$shI_64\                                  : signed(63 downto 0);
  signal \c$bv_20\                                   : std_logic_vector(31 downto 0);
  signal \c$bv_21\                                   : std_logic_vector(31 downto 0);
  signal \c$shI_65\                                  : signed(63 downto 0);
  signal \c$bv_22\                                   : std_logic_vector(31 downto 0);
  signal \c$shI_66\                                  : signed(63 downto 0);
  signal \c$bv_23\                                   : std_logic_vector(31 downto 0);
  signal \c$shI_67\                                  : signed(63 downto 0);
  signal \c$case_alt_selection_res_45\               : boolean;
  signal result_selection_res_50                     : boolean;
  signal \c$shI_68\                                  : signed(63 downto 0);
  signal \c$case_alt_selection_res_46\               : boolean;
  signal result_selection_res_51                     : boolean;
  signal \c$bv_24\                                   : std_logic_vector(31 downto 0);
  signal \c$shI_69\                                  : signed(63 downto 0);
  signal \c$bv_25\                                   : std_logic_vector(31 downto 0);
  signal \c$bv_26\                                   : std_logic_vector(31 downto 0);
  signal result_selection_res_52                     : boolean;
  signal \c$case_alt_selection_res_47\               : boolean;
  signal result_selection_res_53                     : boolean;
  signal \c$shI_70\                                  : signed(63 downto 0);
  signal \c$shI_71\                                  : signed(63 downto 0);
  signal result_selection_res_54                     : boolean;
  signal \c$case_alt_selection_res_48\               : boolean;
  signal result_selection_res_55                     : boolean;
  signal \c$shI_72\                                  : signed(63 downto 0);
  signal \c$shI_73\                                  : signed(63 downto 0);
  signal \c$shI_74\                                  : signed(63 downto 0);
  signal \c$case_alt_selection_res_49\               : boolean;
  signal result_selection_res_56                     : boolean;
  signal \c$shI_75\                                  : signed(63 downto 0);
  signal \c$case_alt_selection_res_50\               : boolean;
  signal result_selection_res_57                     : boolean;
  signal \c$bv_27\                                   : std_logic_vector(31 downto 0);
  signal \c$bv_28\                                   : std_logic_vector(31 downto 0);
  signal \c$bv_29\                                   : std_logic_vector(31 downto 0);
  signal \c$case_alt_selection_res_51\               : boolean;
  signal result_selection_res_58                     : boolean;
  signal \c$case_alt_selection_res_52\               : boolean;
  signal result_selection_res_59                     : boolean;
  signal \c$bv_30\                                   : std_logic_vector(31 downto 0);
  signal result_selection_res_60                     : boolean;
  signal \c$case_alt_selection_res_53\               : boolean;
  signal \c$shI_76\                                  : signed(63 downto 0);
  signal \c$shI_77\                                  : signed(63 downto 0);
  signal \c$case_alt_selection_res_54\               : boolean;
  signal result_selection_res_61                     : boolean;
  signal \c$shI_78\                                  : signed(63 downto 0);
  signal \c$bv_31\                                   : std_logic_vector(31 downto 0);
  signal result_selection_res_62                     : boolean;
  signal \c$case_alt_selection_res_55\               : boolean;
  signal \c$shI_79\                                  : signed(63 downto 0);
  signal \c$shI_80\                                  : signed(63 downto 0);
  signal \c$case_alt_selection_res_56\               : boolean;
  signal result_selection_res_63                     : boolean;
  signal \c$shI_81\                                  : signed(63 downto 0);
  signal \c$bv_32\                                   : std_logic_vector(31 downto 0);
  signal \c$case_alt_selection_res_57\               : boolean;
  signal result_selection_res_64                     : boolean;
  signal \c$shI_82\                                  : signed(63 downto 0);
  signal \c$bv_33\                                   : std_logic_vector(31 downto 0);
  signal \c$case_alt_selection_res_58\               : boolean;
  signal result_selection_res_65                     : boolean;
  signal \c$shI_83\                                  : signed(63 downto 0);
  signal \c$bv_34\                                   : std_logic_vector(31 downto 0);
  signal \c$bv_35\                                   : std_logic_vector(31 downto 0);
  signal \c$shI_84\                                  : signed(63 downto 0);
  signal \c$case_alt_selection_res_59\               : boolean;
  signal result_selection_res_66                     : boolean;
  signal \c$shI_85\                                  : signed(63 downto 0);
  signal \c$case_alt_selection_res_60\               : boolean;
  signal result_selection_res_67                     : boolean;
  signal \c$bv_36\                                   : std_logic_vector(31 downto 0);
  signal \c$shI_86\                                  : signed(63 downto 0);
  signal \c$bv_37\                                   : std_logic_vector(31 downto 0);
  signal \c$shI_87\                                  : signed(63 downto 0);
  signal \c$case_alt_selection_res_61\               : boolean;
  signal result_selection_res_68                     : boolean;
  signal \c$shI_88\                                  : signed(63 downto 0);
  signal \c$case_alt_selection_res_62\               : boolean;
  signal result_selection_res_69                     : boolean;
  signal \c$bv_38\                                   : std_logic_vector(31 downto 0);
  signal result_selection_res_70                     : boolean;
  signal \c$case_alt_selection_res_63\               : boolean;
  signal result_selection_res_71                     : boolean;
  signal \c$case_alt_selection_res_64\               : boolean;
  signal result_selection_res_72                     : boolean;
  signal \c$bv_39\                                   : std_logic_vector(31 downto 0);
  signal \c$bv_40\                                   : std_logic_vector(31 downto 0);
  signal \c$shI_89\                                  : signed(63 downto 0);
  signal \c$case_alt_selection_res_65\               : boolean;
  signal result_selection_res_73                     : boolean;
  signal \c$shI_90\                                  : signed(63 downto 0);
  signal \c$case_alt_selection_res_66\               : boolean;
  signal result_selection_res_74                     : boolean;
  signal \c$bv_41\                                   : std_logic_vector(31 downto 0);
  signal \c$shI_91\                                  : signed(63 downto 0);
  signal \c$shI_92\                                  : signed(63 downto 0);
  signal \c$case_alt_selection_res_67\               : boolean;
  signal result_selection_res_75                     : boolean;
  signal \c$shI_93\                                  : signed(63 downto 0);
  signal \c$case_alt_selection_res_68\               : boolean;
  signal result_selection_res_76                     : boolean;
  signal \c$bv_42\                                   : std_logic_vector(31 downto 0);
  signal \c$bv_43\                                   : std_logic_vector(31 downto 0);
  signal \c$bv_44\                                   : std_logic_vector(31 downto 0);
  signal \c$case_alt_selection_res_69\               : boolean;
  signal result_selection_res_77                     : boolean;
  signal \c$case_alt_selection_res_70\               : boolean;
  signal result_selection_res_78                     : boolean;
  signal \c$bv_45\                                   : std_logic_vector(31 downto 0);
  signal \c$case_alt_selection_res_71\               : boolean;
  signal result_selection_res_79                     : boolean;
  signal \c$shI_94\                                  : signed(63 downto 0);
  signal \c$bv_46\                                   : std_logic_vector(31 downto 0);
  signal \c$case_alt_selection_res_72\               : boolean;
  signal result_selection_res_80                     : boolean;
  signal \c$shI_95\                                  : signed(63 downto 0);
  signal \c$bv_47\                                   : std_logic_vector(31 downto 0);
  signal \c$shI_96\                                  : signed(63 downto 0);
  signal \c$case_alt_selection_res_73\               : boolean;
  signal result_selection_res_81                     : boolean;
  signal \c$shI_97\                                  : signed(63 downto 0);
  signal \c$case_alt_selection_res_74\               : boolean;
  signal result_selection_res_82                     : boolean;
  signal \c$bv_48\                                   : std_logic_vector(31 downto 0);
  signal \c$bv_49\                                   : std_logic_vector(31 downto 0);
  signal \c$bv_50\                                   : std_logic_vector(31 downto 0);
  signal \c$bv_51\                                   : std_logic_vector(31 downto 0);
  signal result_selection_res_83                     : boolean;
  signal \c$case_alt_selection_res_75\               : boolean;
  signal result_selection_res_84                     : boolean;
  signal \c$case_alt_selection_res_76\               : boolean;
  signal \c$shI_98\                                  : signed(63 downto 0);
  signal \c$case_alt_selection_res_77\               : boolean;
  signal result_selection_res_85                     : boolean;
  signal \c$shI_99\                                  : signed(63 downto 0);
  signal \c$case_alt_selection_res_78\               : boolean;
  signal result_selection_res_86                     : boolean;
  signal \c$bv_52\                                   : std_logic_vector(31 downto 0);
  signal result_selection_res_87                     : boolean;
  signal \c$bv_53\                                   : std_logic_vector(31 downto 0);
  signal \c$bv_54\                                   : std_logic_vector(31 downto 0);
  signal \c$case_alt_selection_res_79\               : boolean;
  signal result_selection_res_88                     : boolean;
  signal \c$shI_100\                                 : signed(63 downto 0);
  signal \c$bv_55\                                   : std_logic_vector(31 downto 0);
  signal \c$case_alt_selection_res_80\               : boolean;
  signal result_selection_res_89                     : boolean;
  signal \c$shI_101\                                 : signed(63 downto 0);
  signal \c$bv_56\                                   : std_logic_vector(31 downto 0);
  signal \c$shI_102\                                 : signed(63 downto 0);
  signal \c$case_alt_selection_res_81\               : boolean;
  signal result_selection_res_90                     : boolean;
  signal \c$shI_103\                                 : signed(63 downto 0);
  signal \c$case_alt_selection_res_82\               : boolean;
  signal result_selection_res_91                     : boolean;
  signal \c$bv_57\                                   : std_logic_vector(31 downto 0);
  signal \c$bv_58\                                   : std_logic_vector(31 downto 0);
  signal \c$bv_59\                                   : std_logic_vector(31 downto 0);
  signal \c$bv_60\                                   : std_logic_vector(31 downto 0);
  signal result_selection_res_92                     : boolean;
  signal \c$case_alt_selection_res_83\               : boolean;
  signal \c$shI_104\                                 : signed(63 downto 0);
  signal \c$shI_105\                                 : signed(63 downto 0);
  signal result_selection_res_93                     : boolean;
  signal \c$case_alt_selection_res_84\               : boolean;
  signal \c$shI_106\                                 : signed(63 downto 0);
  signal \c$shI_107\                                 : signed(63 downto 0);
  signal \c$shI_108\                                 : signed(63 downto 0);
  signal \c$case_alt_selection_res_85\               : boolean;
  signal result_selection_res_94                     : boolean;
  signal \c$shI_109\                                 : signed(63 downto 0);
  signal \c$case_alt_selection_res_86\               : boolean;
  signal result_selection_res_95                     : boolean;
  signal \c$bv_61\                                   : std_logic_vector(31 downto 0);
  signal \c$bv_62\                                   : std_logic_vector(31 downto 0);
  signal \c$bv_63\                                   : std_logic_vector(31 downto 0);
  signal result_selection_res_96                     : boolean;
  signal \c$bv_64\                                   : std_logic_vector(31 downto 0);
  signal \c$case_alt_selection_res_87\               : boolean;
  signal result_selection_res_97                     : boolean;
  signal \c$shI_110\                                 : signed(63 downto 0);
  signal \c$case_alt_selection_res_88\               : boolean;
  signal result_selection_res_98                     : boolean;
  signal \c$shI_111\                                 : signed(63 downto 0);
  signal \c$case_alt_selection_res_89\               : boolean;
  signal \c$case_alt_selection_res_90\               : boolean;
  signal \c$case_alt_selection_res_91\               : boolean;
  signal \c$bv_65\                                   : std_logic_vector(31 downto 0);
  signal \c$case_alt_selection_res_92\               : boolean;
  signal \c$case_alt_selection_res_93\               : boolean;
  signal \c$case_alt_selection_res_94\               : boolean;
  signal \c$case_alt_selection_res_95\               : boolean;
  signal result_selection_res_99                     : boolean;
  signal \c$shI_112\                                 : signed(63 downto 0);
  signal \c$shI_113\                                 : signed(63 downto 0);
  signal \c$shI_114\                                 : signed(63 downto 0);
  signal result_selection_res_100                    : boolean;
  signal \c$case_alt_selection_res_96\               : boolean;
  signal \c$case_alt_selection_res_97\               : boolean;
  signal \c$bv_66\                                   : std_logic_vector(31 downto 0);
  signal result_selection_res_101                    : boolean;
  signal \c$case_alt_selection_res_98\               : boolean;
  signal result_selection_res_102                    : boolean;
  signal \c$case_alt_selection_res_99\               : boolean;
  signal result_selection_res_103                    : boolean;
  signal \c$reverbAddr_case_alt_selection_res\       : boolean;
  signal result                                      : clash_lowpass_fir_types.Tuple4;

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

  with (outPipe(971 downto 971)) select
    \new\ <= false when "0",
             true when others;

  with (outPipe(971 downto 971)) select
    \c$app_arg\ <= false when "0",
                   f.Frame_sel2_fLast when others;

  with (outPipe(971 downto 971)) select
    \c$app_arg_0\ <= std_logic_vector'(x"000000000000") when "0",
                     std_logic_vector'(std_logic_vector'(((std_logic_vector(f.Frame_sel1_fR)))) & std_logic_vector'(((std_logic_vector(f.Frame_sel0_fL))))) when others;

  f <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(outPipe(970 downto 0)));

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
              , Frame_sel8_fAmp => x_1.Frame_sel8_fAmp
              , Frame_sel9_fAmpTone => x_1.Frame_sel9_fAmpTone
              , Frame_sel10_fCab => x_1.Frame_sel10_fCab
              , Frame_sel11_fReverb => x_1.Frame_sel11_fReverb
              , Frame_sel12_fAddr => x_1.Frame_sel12_fAddr
              , Frame_sel13_fDryL => x_1.Frame_sel13_fDryL
              , Frame_sel14_fDryR => x_1.Frame_sel14_fDryR
              , Frame_sel15_fWetL => x_1.Frame_sel15_fWetL
              , Frame_sel16_fWetR => x_1.Frame_sel16_fWetR
              , Frame_sel17_fFbL => x_1.Frame_sel17_fFbL
              , Frame_sel18_fFbR => x_1.Frame_sel18_fFbR
              , Frame_sel19_fEqLowL => x_1.Frame_sel19_fEqLowL
              , Frame_sel20_fEqLowR => x_1.Frame_sel20_fEqLowR
              , Frame_sel21_fEqMidL => x_1.Frame_sel21_fEqMidL
              , Frame_sel22_fEqMidR => x_1.Frame_sel22_fEqMidR
              , Frame_sel23_fEqHighL => x_1.Frame_sel23_fEqHighL
              , Frame_sel24_fEqHighR => x_1.Frame_sel24_fEqHighR
              , Frame_sel25_fEqHighLpL => x_1.Frame_sel25_fEqHighLpL
              , Frame_sel26_fEqHighLpR => x_1.Frame_sel26_fEqHighLpR
              , Frame_sel27_fAccL => x_1.Frame_sel27_fAccL
              , Frame_sel28_fAccR => x_1.Frame_sel28_fAccR
              , Frame_sel29_fAcc2L => x_1.Frame_sel29_fAcc2L
              , Frame_sel30_fAcc2R => x_1.Frame_sel30_fAcc2R
              , Frame_sel31_fAcc3L => \c$app_arg_2\
              , Frame_sel32_fAcc3R => \c$app_arg_1\ );

  \c$app_arg_1\ <= resize((resize(x_1.Frame_sel16_fWetR,48)) * \c$app_arg_3\, 48) when \on\ else
                   to_signed(0,48);

  \c$app_arg_2\ <= resize((resize(x_1.Frame_sel15_fWetL,48)) * \c$app_arg_3\, 48) when \on\ else
                   to_signed(0,48);

  \c$bv\ <= (x_1.Frame_sel3_fGate);

  \on\ <= (\c$bv\(5 downto 5)) = std_logic_vector'("1");

  \c$app_arg_3\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(gain)))))))),48);

  \c$bv_0\ <= (x_1.Frame_sel11_fReverb);

  gain <= unsigned((\c$bv_0\(7 downto 0)));

  -- register begin
  reverbToneBlendPipe_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      reverbToneBlendPipe <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      reverbToneBlendPipe <= result_2;
    end if;
  end process;
  -- register end

  with (ds1(971 downto 971)) select
    result_2 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                std_logic_vector'("1" & ((std_logic_vector(\c$case_alt_2\.Frame_sel0_fL)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel1_fR)
                 & clash_lowpass_fir_types.toSLV(\c$case_alt_2\.Frame_sel2_fLast)
                 & \c$case_alt_2\.Frame_sel3_fGate
                 & \c$case_alt_2\.Frame_sel4_fOd
                 & \c$case_alt_2\.Frame_sel5_fDist
                 & \c$case_alt_2\.Frame_sel6_fEq
                 & \c$case_alt_2\.Frame_sel7_fRat
                 & \c$case_alt_2\.Frame_sel8_fAmp
                 & \c$case_alt_2\.Frame_sel9_fAmpTone
                 & \c$case_alt_2\.Frame_sel10_fCab
                 & \c$case_alt_2\.Frame_sel11_fReverb
                 & std_logic_vector(\c$case_alt_2\.Frame_sel12_fAddr)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel13_fDryL)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel14_fDryR)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel15_fWetL)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel16_fWetR)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel17_fFbL)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel18_fFbR)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel19_fEqLowL)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel20_fEqLowR)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel21_fEqMidL)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel22_fEqMidR)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel23_fEqHighL)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel24_fEqHighR)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel25_fEqHighLpL)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel26_fEqHighLpR)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel27_fAccL)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel28_fAccR)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel29_fAcc2L)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel30_fAcc2R)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel31_fAcc3L)
                 & std_logic_vector(\c$case_alt_2\.Frame_sel32_fAcc3R)))) when others;

  \c$shI\ <= (to_signed(8,64));

  capp_arg_4_shiftR : block
    signal sh : natural;
  begin
    sh <=
        -- pragma translate_off
        natural'high when (\c$shI\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI\);
    \c$app_arg_4\ <= shift_right((x.Frame_sel27_fAccL + x.Frame_sel29_fAcc2L),sh)
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
    \c$app_arg_5\ <= shift_right((x.Frame_sel28_fAccR + x.Frame_sel30_fAcc2R),sh_0)
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
                    , Frame_sel8_fAmp => x.Frame_sel8_fAmp
                    , Frame_sel9_fAmpTone => x.Frame_sel9_fAmpTone
                    , Frame_sel10_fCab => x.Frame_sel10_fCab
                    , Frame_sel11_fReverb => x.Frame_sel11_fReverb
                    , Frame_sel12_fAddr => x.Frame_sel12_fAddr
                    , Frame_sel13_fDryL => x.Frame_sel13_fDryL
                    , Frame_sel14_fDryR => x.Frame_sel14_fDryR
                    , Frame_sel15_fWetL => result_3
                    , Frame_sel16_fWetR => result_4
                    , Frame_sel17_fFbL => x.Frame_sel17_fFbL
                    , Frame_sel18_fFbR => x.Frame_sel18_fFbR
                    , Frame_sel19_fEqLowL => x.Frame_sel19_fEqLowL
                    , Frame_sel20_fEqLowR => x.Frame_sel20_fEqLowR
                    , Frame_sel21_fEqMidL => x.Frame_sel21_fEqMidL
                    , Frame_sel22_fEqMidR => x.Frame_sel22_fEqMidR
                    , Frame_sel23_fEqHighL => x.Frame_sel23_fEqHighL
                    , Frame_sel24_fEqHighR => x.Frame_sel24_fEqHighR
                    , Frame_sel25_fEqHighLpL => x.Frame_sel25_fEqHighLpL
                    , Frame_sel26_fEqHighLpR => x.Frame_sel26_fEqHighLpR
                    , Frame_sel27_fAccL => x.Frame_sel27_fAccL
                    , Frame_sel28_fAccR => x.Frame_sel28_fAccR
                    , Frame_sel29_fAcc2L => x.Frame_sel29_fAcc2L
                    , Frame_sel30_fAcc2R => x.Frame_sel30_fAcc2R
                    , Frame_sel31_fAcc3L => x.Frame_sel31_fAcc3L
                    , Frame_sel32_fAcc3R => x.Frame_sel32_fAcc3R );

  x <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1(970 downto 0)));

  -- register begin
  ds1_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1 <= result_5;
    end if;
  end process;
  -- register end

  with (\c$ds1_app_arg\(971 downto 971)) select
    result_5 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                std_logic_vector'("1" & ((std_logic_vector(x_0.Frame_sel0_fL)
                 & std_logic_vector(x_0.Frame_sel1_fR)
                 & clash_lowpass_fir_types.toSLV(x_0.Frame_sel2_fLast)
                 & x_0.Frame_sel3_fGate
                 & x_0.Frame_sel4_fOd
                 & x_0.Frame_sel5_fDist
                 & x_0.Frame_sel6_fEq
                 & x_0.Frame_sel7_fRat
                 & x_0.Frame_sel8_fAmp
                 & x_0.Frame_sel9_fAmpTone
                 & x_0.Frame_sel10_fCab
                 & x_0.Frame_sel11_fReverb
                 & std_logic_vector(x_0.Frame_sel12_fAddr)
                 & std_logic_vector(x_0.Frame_sel13_fDryL)
                 & std_logic_vector(x_0.Frame_sel14_fDryR)
                 & std_logic_vector(x_0.Frame_sel15_fWetL)
                 & std_logic_vector(x_0.Frame_sel16_fWetR)
                 & std_logic_vector(x_0.Frame_sel17_fFbL)
                 & std_logic_vector(x_0.Frame_sel18_fFbR)
                 & std_logic_vector(x_0.Frame_sel19_fEqLowL)
                 & std_logic_vector(x_0.Frame_sel20_fEqLowR)
                 & std_logic_vector(x_0.Frame_sel21_fEqMidL)
                 & std_logic_vector(x_0.Frame_sel22_fEqMidR)
                 & std_logic_vector(x_0.Frame_sel23_fEqHighL)
                 & std_logic_vector(x_0.Frame_sel24_fEqHighR)
                 & std_logic_vector(x_0.Frame_sel25_fEqHighLpL)
                 & std_logic_vector(x_0.Frame_sel26_fEqHighLpR)
                 & std_logic_vector(resize((resize(result_8,48)) * \c$app_arg_7\, 48))
                 & std_logic_vector(resize((resize(result_7,48)) * \c$app_arg_7\, 48))
                 & std_logic_vector(resize((resize(reverbTonePrevL,48)) * \c$app_arg_6\, 48))
                 & std_logic_vector(resize((resize(reverbTonePrevR,48)) * \c$app_arg_6\, 48))
                 & std_logic_vector(x_0.Frame_sel31_fAcc3L)
                 & std_logic_vector(x_0.Frame_sel32_fAcc3R)))) when others;

  \c$app_arg_6\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(gain_0)))))))),48);

  gain_0 <= to_unsigned(255,8) - gain_1;

  \c$app_arg_7\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(gain_1)))))))),48);

  \c$bv_1\ <= (x_0.Frame_sel11_fReverb);

  gain_1 <= unsigned((\c$bv_1\(15 downto 8)));

  x_0 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(\c$ds1_app_arg\(970 downto 0)));

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

  with (reverbToneBlendPipe(971 downto 971)) select
    \c$reverbTonePrevR_app_arg\ <= reverbTonePrevR when "0",
                                   x_1.Frame_sel16_fWetR when others;

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

  with (reverbToneBlendPipe(971 downto 971)) select
    \c$reverbTonePrevL_app_arg\ <= reverbTonePrevL when "0",
                                   x_1.Frame_sel15_fWetL when others;

  x_1 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(reverbToneBlendPipe(970 downto 0)));

  -- register begin
  cds1_app_arg_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      \c$ds1_app_arg\ <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      \c$ds1_app_arg\ <= result_6;
    end if;
  end process;
  -- register end

  f_0 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(eqMixPipe(970 downto 0)));

  with (eqMixPipe(971 downto 971)) select
    result_6 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                std_logic_vector'("1" & ((std_logic_vector(f_0.Frame_sel0_fL)
                 & std_logic_vector(f_0.Frame_sel1_fR)
                 & clash_lowpass_fir_types.toSLV(f_0.Frame_sel2_fLast)
                 & f_0.Frame_sel3_fGate
                 & f_0.Frame_sel4_fOd
                 & f_0.Frame_sel5_fDist
                 & f_0.Frame_sel6_fEq
                 & f_0.Frame_sel7_fRat
                 & f_0.Frame_sel8_fAmp
                 & f_0.Frame_sel9_fAmpTone
                 & f_0.Frame_sel10_fCab
                 & f_0.Frame_sel11_fReverb
                 & std_logic_vector(reverbAddr)
                 & std_logic_vector(f_0.Frame_sel0_fL)
                 & std_logic_vector(f_0.Frame_sel1_fR)
                 & std_logic_vector(f_0.Frame_sel15_fWetL)
                 & std_logic_vector(f_0.Frame_sel16_fWetR)
                 & std_logic_vector(f_0.Frame_sel17_fFbL)
                 & std_logic_vector(f_0.Frame_sel18_fFbR)
                 & std_logic_vector(f_0.Frame_sel19_fEqLowL)
                 & std_logic_vector(f_0.Frame_sel20_fEqLowR)
                 & std_logic_vector(f_0.Frame_sel21_fEqMidL)
                 & std_logic_vector(f_0.Frame_sel22_fEqMidR)
                 & std_logic_vector(f_0.Frame_sel23_fEqHighL)
                 & std_logic_vector(f_0.Frame_sel24_fEqHighR)
                 & std_logic_vector(f_0.Frame_sel25_fEqHighLpL)
                 & std_logic_vector(f_0.Frame_sel26_fEqHighLpR)
                 & std_logic_vector(f_0.Frame_sel27_fAccL)
                 & std_logic_vector(f_0.Frame_sel28_fAccR)
                 & std_logic_vector(f_0.Frame_sel29_fAcc2L)
                 & std_logic_vector(f_0.Frame_sel30_fAcc2R)
                 & std_logic_vector(f_0.Frame_sel31_fAcc3L)
                 & std_logic_vector(f_0.Frame_sel32_fAcc3R)))) when others;

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

  with (outPipe(971 downto 971)) select
    wrM <= std_logic_vector'("0" & "----------------------------------") when "0",
           std_logic_vector'("1" & ((std_logic_vector(f_1.Frame_sel12_fAddr)
            & std_logic_vector(f_1.Frame_sel18_fFbR)))) when others;

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

  with (outPipe(971 downto 971)) select
    wrM_0 <= std_logic_vector'("0" & "----------------------------------") when "0",
             std_logic_vector'("1" & ((std_logic_vector(f_1.Frame_sel12_fAddr)
              & std_logic_vector(f_1.Frame_sel17_fFbL)))) when others;

  f_1 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(outPipe(970 downto 0)));

  -- register begin
  outPipe_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      outPipe <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      outPipe <= result_9;
    end if;
  end process;
  -- register end

  with (ds1_0(971 downto 971)) select
    result_9 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                std_logic_vector'("1" & ((std_logic_vector(result_12.Frame_sel0_fL)
                 & std_logic_vector(result_12.Frame_sel1_fR)
                 & clash_lowpass_fir_types.toSLV(result_12.Frame_sel2_fLast)
                 & result_12.Frame_sel3_fGate
                 & result_12.Frame_sel4_fOd
                 & result_12.Frame_sel5_fDist
                 & result_12.Frame_sel6_fEq
                 & result_12.Frame_sel7_fRat
                 & result_12.Frame_sel8_fAmp
                 & result_12.Frame_sel9_fAmpTone
                 & result_12.Frame_sel10_fCab
                 & result_12.Frame_sel11_fReverb
                 & std_logic_vector(result_12.Frame_sel12_fAddr)
                 & std_logic_vector(result_12.Frame_sel13_fDryL)
                 & std_logic_vector(result_12.Frame_sel14_fDryR)
                 & std_logic_vector(result_12.Frame_sel15_fWetL)
                 & std_logic_vector(result_12.Frame_sel16_fWetR)
                 & std_logic_vector(result_12.Frame_sel17_fFbL)
                 & std_logic_vector(result_12.Frame_sel18_fFbR)
                 & std_logic_vector(result_12.Frame_sel19_fEqLowL)
                 & std_logic_vector(result_12.Frame_sel20_fEqLowR)
                 & std_logic_vector(result_12.Frame_sel21_fEqMidL)
                 & std_logic_vector(result_12.Frame_sel22_fEqMidR)
                 & std_logic_vector(result_12.Frame_sel23_fEqHighL)
                 & std_logic_vector(result_12.Frame_sel24_fEqHighR)
                 & std_logic_vector(result_12.Frame_sel25_fEqHighLpL)
                 & std_logic_vector(result_12.Frame_sel26_fEqHighLpR)
                 & std_logic_vector(result_12.Frame_sel27_fAccL)
                 & std_logic_vector(result_12.Frame_sel28_fAccR)
                 & std_logic_vector(result_12.Frame_sel29_fAcc2L)
                 & std_logic_vector(result_12.Frame_sel30_fAcc2R)
                 & std_logic_vector(result_12.Frame_sel31_fAcc3L)
                 & std_logic_vector(result_12.Frame_sel32_fAcc3R)))) when others;

  \c$shI_1\ <= (to_signed(8,64));

  capp_arg_8_shiftR : block
    signal sh_1 : natural;
  begin
    sh_1 <=
        -- pragma translate_off
        natural'high when (\c$shI_1\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_1\);
    \c$app_arg_8\ <= shift_right((x_2.Frame_sel27_fAccL + x_2.Frame_sel29_fAcc2L),sh_1)
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
                   x_2.Frame_sel13_fDryL;

  \c$shI_2\ <= (to_signed(8,64));

  capp_arg_10_shiftR : block
    signal sh_2 : natural;
  begin
    sh_2 <=
        -- pragma translate_off
        natural'high when (\c$shI_2\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_2\);
    \c$app_arg_10\ <= shift_right((x_2.Frame_sel28_fAccR + x_2.Frame_sel30_fAcc2R),sh_2)
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
                    x_2.Frame_sel14_fDryR;

  result_12 <= ( Frame_sel0_fL => \c$app_arg_9\
               , Frame_sel1_fR => \c$app_arg_11\
               , Frame_sel2_fLast => x_2.Frame_sel2_fLast
               , Frame_sel3_fGate => x_2.Frame_sel3_fGate
               , Frame_sel4_fOd => x_2.Frame_sel4_fOd
               , Frame_sel5_fDist => x_2.Frame_sel5_fDist
               , Frame_sel6_fEq => x_2.Frame_sel6_fEq
               , Frame_sel7_fRat => x_2.Frame_sel7_fRat
               , Frame_sel8_fAmp => x_2.Frame_sel8_fAmp
               , Frame_sel9_fAmpTone => x_2.Frame_sel9_fAmpTone
               , Frame_sel10_fCab => x_2.Frame_sel10_fCab
               , Frame_sel11_fReverb => x_2.Frame_sel11_fReverb
               , Frame_sel12_fAddr => x_2.Frame_sel12_fAddr
               , Frame_sel13_fDryL => x_2.Frame_sel13_fDryL
               , Frame_sel14_fDryR => x_2.Frame_sel14_fDryR
               , Frame_sel15_fWetL => x_2.Frame_sel15_fWetL
               , Frame_sel16_fWetR => x_2.Frame_sel16_fWetR
               , Frame_sel17_fFbL => x_2.Frame_sel17_fFbL
               , Frame_sel18_fFbR => x_2.Frame_sel18_fFbR
               , Frame_sel19_fEqLowL => x_2.Frame_sel19_fEqLowL
               , Frame_sel20_fEqLowR => x_2.Frame_sel20_fEqLowR
               , Frame_sel21_fEqMidL => x_2.Frame_sel21_fEqMidL
               , Frame_sel22_fEqMidR => x_2.Frame_sel22_fEqMidR
               , Frame_sel23_fEqHighL => x_2.Frame_sel23_fEqHighL
               , Frame_sel24_fEqHighR => x_2.Frame_sel24_fEqHighR
               , Frame_sel25_fEqHighLpL => x_2.Frame_sel25_fEqHighLpL
               , Frame_sel26_fEqHighLpR => x_2.Frame_sel26_fEqHighLpR
               , Frame_sel27_fAccL => x_2.Frame_sel27_fAccL
               , Frame_sel28_fAccR => x_2.Frame_sel28_fAccR
               , Frame_sel29_fAcc2L => x_2.Frame_sel29_fAcc2L
               , Frame_sel30_fAcc2R => x_2.Frame_sel30_fAcc2R
               , Frame_sel31_fAcc3L => x_2.Frame_sel31_fAcc3L
               , Frame_sel32_fAcc3R => x_2.Frame_sel32_fAcc3R );

  \c$bv_2\ <= (x_2.Frame_sel3_fGate);

  \on_0\ <= (\c$bv_2\(5 downto 5)) = std_logic_vector'("1");

  x_2 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_0(970 downto 0)));

  -- register begin
  ds1_0_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_0 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_0 <= result_13;
    end if;
  end process;
  -- register end

  with (ds1_1(971 downto 971)) select
    result_13 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(result_14.Frame_sel0_fL)
                  & std_logic_vector(result_14.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(result_14.Frame_sel2_fLast)
                  & result_14.Frame_sel3_fGate
                  & result_14.Frame_sel4_fOd
                  & result_14.Frame_sel5_fDist
                  & result_14.Frame_sel6_fEq
                  & result_14.Frame_sel7_fRat
                  & result_14.Frame_sel8_fAmp
                  & result_14.Frame_sel9_fAmpTone
                  & result_14.Frame_sel10_fCab
                  & result_14.Frame_sel11_fReverb
                  & std_logic_vector(result_14.Frame_sel12_fAddr)
                  & std_logic_vector(result_14.Frame_sel13_fDryL)
                  & std_logic_vector(result_14.Frame_sel14_fDryR)
                  & std_logic_vector(result_14.Frame_sel15_fWetL)
                  & std_logic_vector(result_14.Frame_sel16_fWetR)
                  & std_logic_vector(result_14.Frame_sel17_fFbL)
                  & std_logic_vector(result_14.Frame_sel18_fFbR)
                  & std_logic_vector(result_14.Frame_sel19_fEqLowL)
                  & std_logic_vector(result_14.Frame_sel20_fEqLowR)
                  & std_logic_vector(result_14.Frame_sel21_fEqMidL)
                  & std_logic_vector(result_14.Frame_sel22_fEqMidR)
                  & std_logic_vector(result_14.Frame_sel23_fEqHighL)
                  & std_logic_vector(result_14.Frame_sel24_fEqHighR)
                  & std_logic_vector(result_14.Frame_sel25_fEqHighLpL)
                  & std_logic_vector(result_14.Frame_sel26_fEqHighLpR)
                  & std_logic_vector(result_14.Frame_sel27_fAccL)
                  & std_logic_vector(result_14.Frame_sel28_fAccR)
                  & std_logic_vector(result_14.Frame_sel29_fAcc2L)
                  & std_logic_vector(result_14.Frame_sel30_fAcc2R)
                  & std_logic_vector(result_14.Frame_sel31_fAcc3L)
                  & std_logic_vector(result_14.Frame_sel32_fAcc3R)))) when others;

  result_14 <= ( Frame_sel0_fL => x_3.Frame_sel0_fL
               , Frame_sel1_fR => x_3.Frame_sel1_fR
               , Frame_sel2_fLast => x_3.Frame_sel2_fLast
               , Frame_sel3_fGate => x_3.Frame_sel3_fGate
               , Frame_sel4_fOd => x_3.Frame_sel4_fOd
               , Frame_sel5_fDist => x_3.Frame_sel5_fDist
               , Frame_sel6_fEq => x_3.Frame_sel6_fEq
               , Frame_sel7_fRat => x_3.Frame_sel7_fRat
               , Frame_sel8_fAmp => x_3.Frame_sel8_fAmp
               , Frame_sel9_fAmpTone => x_3.Frame_sel9_fAmpTone
               , Frame_sel10_fCab => x_3.Frame_sel10_fCab
               , Frame_sel11_fReverb => x_3.Frame_sel11_fReverb
               , Frame_sel12_fAddr => x_3.Frame_sel12_fAddr
               , Frame_sel13_fDryL => x_3.Frame_sel13_fDryL
               , Frame_sel14_fDryR => x_3.Frame_sel14_fDryR
               , Frame_sel15_fWetL => x_3.Frame_sel15_fWetL
               , Frame_sel16_fWetR => x_3.Frame_sel16_fWetR
               , Frame_sel17_fFbL => x_3.Frame_sel17_fFbL
               , Frame_sel18_fFbR => x_3.Frame_sel18_fFbR
               , Frame_sel19_fEqLowL => x_3.Frame_sel19_fEqLowL
               , Frame_sel20_fEqLowR => x_3.Frame_sel20_fEqLowR
               , Frame_sel21_fEqMidL => x_3.Frame_sel21_fEqMidL
               , Frame_sel22_fEqMidR => x_3.Frame_sel22_fEqMidR
               , Frame_sel23_fEqHighL => x_3.Frame_sel23_fEqHighL
               , Frame_sel24_fEqHighR => x_3.Frame_sel24_fEqHighR
               , Frame_sel25_fEqHighLpL => x_3.Frame_sel25_fEqHighLpL
               , Frame_sel26_fEqHighLpR => x_3.Frame_sel26_fEqHighLpR
               , Frame_sel27_fAccL => \c$app_arg_16\
               , Frame_sel28_fAccR => \c$app_arg_15\
               , Frame_sel29_fAcc2L => \c$app_arg_13\
               , Frame_sel30_fAcc2R => \c$app_arg_12\
               , Frame_sel31_fAcc3L => x_3.Frame_sel31_fAcc3L
               , Frame_sel32_fAcc3R => x_3.Frame_sel32_fAcc3R );

  \c$app_arg_12\ <= resize((resize(x_3.Frame_sel16_fWetR,48)) * \c$app_arg_14\, 48) when \on_1\ else
                    to_signed(0,48);

  \c$app_arg_13\ <= resize((resize(x_3.Frame_sel15_fWetL,48)) * \c$app_arg_14\, 48) when \on_1\ else
                    to_signed(0,48);

  \c$app_arg_14\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(mixGain)))))))),48);

  \c$app_arg_15\ <= resize((resize(x_3.Frame_sel14_fDryR,48)) * \c$app_arg_17\, 48) when \on_1\ else
                    to_signed(0,48);

  \c$app_arg_16\ <= resize((resize(x_3.Frame_sel13_fDryL,48)) * \c$app_arg_17\, 48) when \on_1\ else
                    to_signed(0,48);

  \c$bv_3\ <= (x_3.Frame_sel3_fGate);

  \on_1\ <= (\c$bv_3\(5 downto 5)) = std_logic_vector'("1");

  \c$app_arg_17\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(invMixGain)))))))),48);

  invMixGain <= to_unsigned(256,9) - (resize(mixGain,9));

  \c$bv_4\ <= (x_3.Frame_sel11_fReverb);

  mixGain <= unsigned((\c$bv_4\(23 downto 16)));

  x_3 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_1(970 downto 0)));

  -- register begin
  ds1_1_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_1 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_1 <= result_15;
    end if;
  end process;
  -- register end

  with (ds1_2(971 downto 971)) select
    result_15 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(result_18.Frame_sel0_fL)
                  & std_logic_vector(result_18.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(result_18.Frame_sel2_fLast)
                  & result_18.Frame_sel3_fGate
                  & result_18.Frame_sel4_fOd
                  & result_18.Frame_sel5_fDist
                  & result_18.Frame_sel6_fEq
                  & result_18.Frame_sel7_fRat
                  & result_18.Frame_sel8_fAmp
                  & result_18.Frame_sel9_fAmpTone
                  & result_18.Frame_sel10_fCab
                  & result_18.Frame_sel11_fReverb
                  & std_logic_vector(result_18.Frame_sel12_fAddr)
                  & std_logic_vector(result_18.Frame_sel13_fDryL)
                  & std_logic_vector(result_18.Frame_sel14_fDryR)
                  & std_logic_vector(result_18.Frame_sel15_fWetL)
                  & std_logic_vector(result_18.Frame_sel16_fWetR)
                  & std_logic_vector(result_18.Frame_sel17_fFbL)
                  & std_logic_vector(result_18.Frame_sel18_fFbR)
                  & std_logic_vector(result_18.Frame_sel19_fEqLowL)
                  & std_logic_vector(result_18.Frame_sel20_fEqLowR)
                  & std_logic_vector(result_18.Frame_sel21_fEqMidL)
                  & std_logic_vector(result_18.Frame_sel22_fEqMidR)
                  & std_logic_vector(result_18.Frame_sel23_fEqHighL)
                  & std_logic_vector(result_18.Frame_sel24_fEqHighR)
                  & std_logic_vector(result_18.Frame_sel25_fEqHighLpL)
                  & std_logic_vector(result_18.Frame_sel26_fEqHighLpR)
                  & std_logic_vector(result_18.Frame_sel27_fAccL)
                  & std_logic_vector(result_18.Frame_sel28_fAccR)
                  & std_logic_vector(result_18.Frame_sel29_fAcc2L)
                  & std_logic_vector(result_18.Frame_sel30_fAcc2R)
                  & std_logic_vector(result_18.Frame_sel31_fAcc3L)
                  & std_logic_vector(result_18.Frame_sel32_fAcc3R)))) when others;

  \c$shI_3\ <= (to_signed(1,64));

  capp_arg_18_shiftR : block
    signal sh_3 : natural;
  begin
    sh_3 <=
        -- pragma translate_off
        natural'high when (\c$shI_3\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_3\);
    \c$app_arg_18\ <= shift_right((resize(x_6.Frame_sel13_fDryL,48)),sh_3)
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
    \c$app_arg_19\ <= shift_right(x_6.Frame_sel31_fAcc3L,sh_4)
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
    \c$app_arg_21\ <= shift_right((resize(x_6.Frame_sel14_fDryR,48)),sh_5)
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
    \c$app_arg_22\ <= shift_right(x_6.Frame_sel32_fAcc3R,sh_6)
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
               , Frame_sel8_fAmp => x_6.Frame_sel8_fAmp
               , Frame_sel9_fAmpTone => x_6.Frame_sel9_fAmpTone
               , Frame_sel10_fCab => x_6.Frame_sel10_fCab
               , Frame_sel11_fReverb => x_6.Frame_sel11_fReverb
               , Frame_sel12_fAddr => x_6.Frame_sel12_fAddr
               , Frame_sel13_fDryL => x_6.Frame_sel13_fDryL
               , Frame_sel14_fDryR => x_6.Frame_sel14_fDryR
               , Frame_sel15_fWetL => x_6.Frame_sel15_fWetL
               , Frame_sel16_fWetR => x_6.Frame_sel16_fWetR
               , Frame_sel17_fFbL => \c$app_arg_20\
               , Frame_sel18_fFbR => \c$app_arg_23\
               , Frame_sel19_fEqLowL => x_6.Frame_sel19_fEqLowL
               , Frame_sel20_fEqLowR => x_6.Frame_sel20_fEqLowR
               , Frame_sel21_fEqMidL => x_6.Frame_sel21_fEqMidL
               , Frame_sel22_fEqMidR => x_6.Frame_sel22_fEqMidR
               , Frame_sel23_fEqHighL => x_6.Frame_sel23_fEqHighL
               , Frame_sel24_fEqHighR => x_6.Frame_sel24_fEqHighR
               , Frame_sel25_fEqHighLpL => x_6.Frame_sel25_fEqHighLpL
               , Frame_sel26_fEqHighLpR => x_6.Frame_sel26_fEqHighLpR
               , Frame_sel27_fAccL => x_6.Frame_sel27_fAccL
               , Frame_sel28_fAccR => x_6.Frame_sel28_fAccR
               , Frame_sel29_fAcc2L => x_6.Frame_sel29_fAcc2L
               , Frame_sel30_fAcc2R => x_6.Frame_sel30_fAcc2R
               , Frame_sel31_fAcc3L => x_6.Frame_sel31_fAcc3L
               , Frame_sel32_fAcc3R => x_6.Frame_sel32_fAcc3R );

  \c$bv_5\ <= (x_6.Frame_sel3_fGate);

  \on_2\ <= (\c$bv_5\(5 downto 5)) = std_logic_vector'("1");

  x_6 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_2(970 downto 0)));

  -- register begin
  ds1_2_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_2 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_2 <= \c$ds1_app_arg_2\;
    end if;
  end process;
  -- register end

  with (reverbToneBlendPipe(971 downto 971)) select
    \c$ds1_app_arg_2\ <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                         std_logic_vector'("1" & ((std_logic_vector(result_1.Frame_sel0_fL)
                          & std_logic_vector(result_1.Frame_sel1_fR)
                          & clash_lowpass_fir_types.toSLV(result_1.Frame_sel2_fLast)
                          & result_1.Frame_sel3_fGate
                          & result_1.Frame_sel4_fOd
                          & result_1.Frame_sel5_fDist
                          & result_1.Frame_sel6_fEq
                          & result_1.Frame_sel7_fRat
                          & result_1.Frame_sel8_fAmp
                          & result_1.Frame_sel9_fAmpTone
                          & result_1.Frame_sel10_fCab
                          & result_1.Frame_sel11_fReverb
                          & std_logic_vector(result_1.Frame_sel12_fAddr)
                          & std_logic_vector(result_1.Frame_sel13_fDryL)
                          & std_logic_vector(result_1.Frame_sel14_fDryR)
                          & std_logic_vector(result_1.Frame_sel15_fWetL)
                          & std_logic_vector(result_1.Frame_sel16_fWetR)
                          & std_logic_vector(result_1.Frame_sel17_fFbL)
                          & std_logic_vector(result_1.Frame_sel18_fFbR)
                          & std_logic_vector(result_1.Frame_sel19_fEqLowL)
                          & std_logic_vector(result_1.Frame_sel20_fEqLowR)
                          & std_logic_vector(result_1.Frame_sel21_fEqMidL)
                          & std_logic_vector(result_1.Frame_sel22_fEqMidR)
                          & std_logic_vector(result_1.Frame_sel23_fEqHighL)
                          & std_logic_vector(result_1.Frame_sel24_fEqHighR)
                          & std_logic_vector(result_1.Frame_sel25_fEqHighLpL)
                          & std_logic_vector(result_1.Frame_sel26_fEqHighLpR)
                          & std_logic_vector(result_1.Frame_sel27_fAccL)
                          & std_logic_vector(result_1.Frame_sel28_fAccR)
                          & std_logic_vector(result_1.Frame_sel29_fAcc2L)
                          & std_logic_vector(result_1.Frame_sel30_fAcc2R)
                          & std_logic_vector(result_1.Frame_sel31_fAcc3L)
                          & std_logic_vector(result_1.Frame_sel32_fAcc3R)))) when others;

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

  with (eqMixPipe(971 downto 971)) select
    \c$reverbAddr_app_arg\ <= reverbAddr when "0",
                              \c$reverbAddr_case_alt\ when others;

  -- register begin
  eqMixPipe_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      eqMixPipe <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      eqMixPipe <= result_19;
    end if;
  end process;
  -- register end

  with (ds1_3(971 downto 971)) select
    result_19 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(result_20.Frame_sel0_fL)
                  & std_logic_vector(result_20.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(result_20.Frame_sel2_fLast)
                  & result_20.Frame_sel3_fGate
                  & result_20.Frame_sel4_fOd
                  & result_20.Frame_sel5_fDist
                  & result_20.Frame_sel6_fEq
                  & result_20.Frame_sel7_fRat
                  & result_20.Frame_sel8_fAmp
                  & result_20.Frame_sel9_fAmpTone
                  & result_20.Frame_sel10_fCab
                  & result_20.Frame_sel11_fReverb
                  & std_logic_vector(result_20.Frame_sel12_fAddr)
                  & std_logic_vector(result_20.Frame_sel13_fDryL)
                  & std_logic_vector(result_20.Frame_sel14_fDryR)
                  & std_logic_vector(result_20.Frame_sel15_fWetL)
                  & std_logic_vector(result_20.Frame_sel16_fWetR)
                  & std_logic_vector(result_20.Frame_sel17_fFbL)
                  & std_logic_vector(result_20.Frame_sel18_fFbR)
                  & std_logic_vector(result_20.Frame_sel19_fEqLowL)
                  & std_logic_vector(result_20.Frame_sel20_fEqLowR)
                  & std_logic_vector(result_20.Frame_sel21_fEqMidL)
                  & std_logic_vector(result_20.Frame_sel22_fEqMidR)
                  & std_logic_vector(result_20.Frame_sel23_fEqHighL)
                  & std_logic_vector(result_20.Frame_sel24_fEqHighR)
                  & std_logic_vector(result_20.Frame_sel25_fEqHighLpL)
                  & std_logic_vector(result_20.Frame_sel26_fEqHighLpR)
                  & std_logic_vector(result_20.Frame_sel27_fAccL)
                  & std_logic_vector(result_20.Frame_sel28_fAccR)
                  & std_logic_vector(result_20.Frame_sel29_fAcc2L)
                  & std_logic_vector(result_20.Frame_sel30_fAcc2R)
                  & std_logic_vector(result_20.Frame_sel31_fAcc3L)
                  & std_logic_vector(result_20.Frame_sel32_fAcc3R)))) when others;

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
               , Frame_sel8_fAmp => x_7.Frame_sel8_fAmp
               , Frame_sel9_fAmpTone => x_7.Frame_sel9_fAmpTone
               , Frame_sel10_fCab => x_7.Frame_sel10_fCab
               , Frame_sel11_fReverb => x_7.Frame_sel11_fReverb
               , Frame_sel12_fAddr => x_7.Frame_sel12_fAddr
               , Frame_sel13_fDryL => x_7.Frame_sel13_fDryL
               , Frame_sel14_fDryR => x_7.Frame_sel14_fDryR
               , Frame_sel15_fWetL => x_7.Frame_sel15_fWetL
               , Frame_sel16_fWetR => x_7.Frame_sel16_fWetR
               , Frame_sel17_fFbL => x_7.Frame_sel17_fFbL
               , Frame_sel18_fFbR => x_7.Frame_sel18_fFbR
               , Frame_sel19_fEqLowL => x_7.Frame_sel19_fEqLowL
               , Frame_sel20_fEqLowR => x_7.Frame_sel20_fEqLowR
               , Frame_sel21_fEqMidL => x_7.Frame_sel21_fEqMidL
               , Frame_sel22_fEqMidR => x_7.Frame_sel22_fEqMidR
               , Frame_sel23_fEqHighL => x_7.Frame_sel23_fEqHighL
               , Frame_sel24_fEqHighR => x_7.Frame_sel24_fEqHighR
               , Frame_sel25_fEqHighLpL => x_7.Frame_sel25_fEqHighLpL
               , Frame_sel26_fEqHighLpR => x_7.Frame_sel26_fEqHighLpR
               , Frame_sel27_fAccL => x_7.Frame_sel27_fAccL
               , Frame_sel28_fAccR => x_7.Frame_sel28_fAccR
               , Frame_sel29_fAcc2L => x_7.Frame_sel29_fAcc2L
               , Frame_sel30_fAcc2R => x_7.Frame_sel30_fAcc2R
               , Frame_sel31_fAcc3L => x_7.Frame_sel31_fAcc3L
               , Frame_sel32_fAcc3R => x_7.Frame_sel32_fAcc3R );

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
    \c$app_arg_25\ <= shift_right(((x_7.Frame_sel28_fAccR + x_7.Frame_sel30_fAcc2R) + x_7.Frame_sel32_fAcc3R),sh_7)
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
    \c$app_arg_27\ <= shift_right(((x_7.Frame_sel27_fAccL + x_7.Frame_sel29_fAcc2L) + x_7.Frame_sel31_fAcc3L),sh_8)
        -- pragma translate_off
        when ((to_signed(7,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  x_7 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_3(970 downto 0)));

  -- register begin
  ds1_3_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_3 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_3 <= result_23;
    end if;
  end process;
  -- register end

  with (ds1_4(971 downto 971)) select
    result_23 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(result_24.Frame_sel0_fL)
                  & std_logic_vector(result_24.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(result_24.Frame_sel2_fLast)
                  & result_24.Frame_sel3_fGate
                  & result_24.Frame_sel4_fOd
                  & result_24.Frame_sel5_fDist
                  & result_24.Frame_sel6_fEq
                  & result_24.Frame_sel7_fRat
                  & result_24.Frame_sel8_fAmp
                  & result_24.Frame_sel9_fAmpTone
                  & result_24.Frame_sel10_fCab
                  & result_24.Frame_sel11_fReverb
                  & std_logic_vector(result_24.Frame_sel12_fAddr)
                  & std_logic_vector(result_24.Frame_sel13_fDryL)
                  & std_logic_vector(result_24.Frame_sel14_fDryR)
                  & std_logic_vector(result_24.Frame_sel15_fWetL)
                  & std_logic_vector(result_24.Frame_sel16_fWetR)
                  & std_logic_vector(result_24.Frame_sel17_fFbL)
                  & std_logic_vector(result_24.Frame_sel18_fFbR)
                  & std_logic_vector(result_24.Frame_sel19_fEqLowL)
                  & std_logic_vector(result_24.Frame_sel20_fEqLowR)
                  & std_logic_vector(result_24.Frame_sel21_fEqMidL)
                  & std_logic_vector(result_24.Frame_sel22_fEqMidR)
                  & std_logic_vector(result_24.Frame_sel23_fEqHighL)
                  & std_logic_vector(result_24.Frame_sel24_fEqHighR)
                  & std_logic_vector(result_24.Frame_sel25_fEqHighLpL)
                  & std_logic_vector(result_24.Frame_sel26_fEqHighLpR)
                  & std_logic_vector(result_24.Frame_sel27_fAccL)
                  & std_logic_vector(result_24.Frame_sel28_fAccR)
                  & std_logic_vector(result_24.Frame_sel29_fAcc2L)
                  & std_logic_vector(result_24.Frame_sel30_fAcc2R)
                  & std_logic_vector(result_24.Frame_sel31_fAcc3L)
                  & std_logic_vector(result_24.Frame_sel32_fAcc3R)))) when others;

  result_24 <= ( Frame_sel0_fL => x_8.Frame_sel0_fL
               , Frame_sel1_fR => x_8.Frame_sel1_fR
               , Frame_sel2_fLast => x_8.Frame_sel2_fLast
               , Frame_sel3_fGate => x_8.Frame_sel3_fGate
               , Frame_sel4_fOd => x_8.Frame_sel4_fOd
               , Frame_sel5_fDist => x_8.Frame_sel5_fDist
               , Frame_sel6_fEq => x_8.Frame_sel6_fEq
               , Frame_sel7_fRat => x_8.Frame_sel7_fRat
               , Frame_sel8_fAmp => x_8.Frame_sel8_fAmp
               , Frame_sel9_fAmpTone => x_8.Frame_sel9_fAmpTone
               , Frame_sel10_fCab => x_8.Frame_sel10_fCab
               , Frame_sel11_fReverb => x_8.Frame_sel11_fReverb
               , Frame_sel12_fAddr => x_8.Frame_sel12_fAddr
               , Frame_sel13_fDryL => x_8.Frame_sel13_fDryL
               , Frame_sel14_fDryR => x_8.Frame_sel14_fDryR
               , Frame_sel15_fWetL => x_8.Frame_sel15_fWetL
               , Frame_sel16_fWetR => x_8.Frame_sel16_fWetR
               , Frame_sel17_fFbL => x_8.Frame_sel17_fFbL
               , Frame_sel18_fFbR => x_8.Frame_sel18_fFbR
               , Frame_sel19_fEqLowL => x_8.Frame_sel19_fEqLowL
               , Frame_sel20_fEqLowR => x_8.Frame_sel20_fEqLowR
               , Frame_sel21_fEqMidL => x_8.Frame_sel21_fEqMidL
               , Frame_sel22_fEqMidR => x_8.Frame_sel22_fEqMidR
               , Frame_sel23_fEqHighL => x_8.Frame_sel23_fEqHighL
               , Frame_sel24_fEqHighR => x_8.Frame_sel24_fEqHighR
               , Frame_sel25_fEqHighLpL => x_8.Frame_sel25_fEqHighLpL
               , Frame_sel26_fEqHighLpR => x_8.Frame_sel26_fEqHighLpR
               , Frame_sel27_fAccL => \c$app_arg_35\
               , Frame_sel28_fAccR => \c$app_arg_34\
               , Frame_sel29_fAcc2L => \c$app_arg_32\
               , Frame_sel30_fAcc2R => \c$app_arg_31\
               , Frame_sel31_fAcc3L => \c$app_arg_29\
               , Frame_sel32_fAcc3R => \c$app_arg_28\ );

  \c$app_arg_28\ <= resize((resize(x_8.Frame_sel24_fEqHighR,48)) * \c$app_arg_30\, 48) when \on_4\ else
                    to_signed(0,48);

  \c$app_arg_29\ <= resize((resize(x_8.Frame_sel23_fEqHighL,48)) * \c$app_arg_30\, 48) when \on_4\ else
                    to_signed(0,48);

  \c$app_arg_30\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(gain_2)))))))),48);

  gain_2 <= unsigned((\c$gain_app_arg\(23 downto 16)));

  \c$app_arg_31\ <= resize((resize(x_8.Frame_sel22_fEqMidR,48)) * \c$app_arg_33\, 48) when \on_4\ else
                    to_signed(0,48);

  \c$app_arg_32\ <= resize((resize(x_8.Frame_sel21_fEqMidL,48)) * \c$app_arg_33\, 48) when \on_4\ else
                    to_signed(0,48);

  \c$app_arg_33\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(gain_3)))))))),48);

  gain_3 <= unsigned((\c$gain_app_arg\(15 downto 8)));

  \c$app_arg_34\ <= resize((resize(x_8.Frame_sel20_fEqLowR,48)) * \c$app_arg_36\, 48) when \on_4\ else
                    to_signed(0,48);

  \c$app_arg_35\ <= resize((resize(x_8.Frame_sel19_fEqLowL,48)) * \c$app_arg_36\, 48) when \on_4\ else
                    to_signed(0,48);

  \c$bv_7\ <= (x_8.Frame_sel3_fGate);

  \on_4\ <= (\c$bv_7\(3 downto 3)) = std_logic_vector'("1");

  \c$app_arg_36\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(gain_4)))))))),48);

  gain_4 <= unsigned((\c$gain_app_arg\(7 downto 0)));

  \c$gain_app_arg\ <= x_8.Frame_sel6_fEq;

  x_8 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_4(970 downto 0)));

  -- register begin
  ds1_4_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_4 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_4 <= result_25;
    end if;
  end process;
  -- register end

  with (eqFilterPipe(971 downto 971)) select
    result_25 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(\c$case_alt_9\.Frame_sel0_fL)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(\c$case_alt_9\.Frame_sel2_fLast)
                  & \c$case_alt_9\.Frame_sel3_fGate
                  & \c$case_alt_9\.Frame_sel4_fOd
                  & \c$case_alt_9\.Frame_sel5_fDist
                  & \c$case_alt_9\.Frame_sel6_fEq
                  & \c$case_alt_9\.Frame_sel7_fRat
                  & \c$case_alt_9\.Frame_sel8_fAmp
                  & \c$case_alt_9\.Frame_sel9_fAmpTone
                  & \c$case_alt_9\.Frame_sel10_fCab
                  & \c$case_alt_9\.Frame_sel11_fReverb
                  & std_logic_vector(\c$case_alt_9\.Frame_sel12_fAddr)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel13_fDryL)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel14_fDryR)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel15_fWetL)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel16_fWetR)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel17_fFbL)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel18_fFbR)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel19_fEqLowL)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel20_fEqLowR)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel21_fEqMidL)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel22_fEqMidR)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel23_fEqHighL)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel24_fEqHighR)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel25_fEqHighLpL)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel26_fEqHighLpR)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel27_fAccL)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel28_fAccR)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel29_fAcc2L)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel30_fAcc2R)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel31_fAcc3L)
                  & std_logic_vector(\c$case_alt_9\.Frame_sel32_fAcc3R)))) when others;

  \c$case_alt_9\ <= ( Frame_sel0_fL => x_13.Frame_sel0_fL
                    , Frame_sel1_fR => x_13.Frame_sel1_fR
                    , Frame_sel2_fLast => x_13.Frame_sel2_fLast
                    , Frame_sel3_fGate => x_13.Frame_sel3_fGate
                    , Frame_sel4_fOd => x_13.Frame_sel4_fOd
                    , Frame_sel5_fDist => x_13.Frame_sel5_fDist
                    , Frame_sel6_fEq => x_13.Frame_sel6_fEq
                    , Frame_sel7_fRat => x_13.Frame_sel7_fRat
                    , Frame_sel8_fAmp => x_13.Frame_sel8_fAmp
                    , Frame_sel9_fAmpTone => x_13.Frame_sel9_fAmpTone
                    , Frame_sel10_fCab => x_13.Frame_sel10_fCab
                    , Frame_sel11_fReverb => x_13.Frame_sel11_fReverb
                    , Frame_sel12_fAddr => x_13.Frame_sel12_fAddr
                    , Frame_sel13_fDryL => x_13.Frame_sel13_fDryL
                    , Frame_sel14_fDryR => x_13.Frame_sel14_fDryR
                    , Frame_sel15_fWetL => x_13.Frame_sel15_fWetL
                    , Frame_sel16_fWetR => x_13.Frame_sel16_fWetR
                    , Frame_sel17_fFbL => x_13.Frame_sel17_fFbL
                    , Frame_sel18_fFbR => x_13.Frame_sel18_fFbR
                    , Frame_sel19_fEqLowL => x_13.Frame_sel19_fEqLowL
                    , Frame_sel20_fEqLowR => x_13.Frame_sel20_fEqLowR
                    , Frame_sel21_fEqMidL => result_29
                    , Frame_sel22_fEqMidR => result_28
                    , Frame_sel23_fEqHighL => result_27
                    , Frame_sel24_fEqHighR => result_26
                    , Frame_sel25_fEqHighLpL => x_13.Frame_sel25_fEqHighLpL
                    , Frame_sel26_fEqHighLpR => x_13.Frame_sel26_fEqHighLpR
                    , Frame_sel27_fAccL => x_13.Frame_sel27_fAccL
                    , Frame_sel28_fAccR => x_13.Frame_sel28_fAccR
                    , Frame_sel29_fAcc2L => x_13.Frame_sel29_fAcc2L
                    , Frame_sel30_fAcc2R => x_13.Frame_sel30_fAcc2R
                    , Frame_sel31_fAcc3L => x_13.Frame_sel31_fAcc3L
                    , Frame_sel32_fAcc3R => x_13.Frame_sel32_fAcc3R );

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

  x_11 <= \c$app_arg_37\ - (resize(x_13.Frame_sel20_fEqLowR,48));

  \c$case_alt_selection_res_9\ <= x_11 < to_signed(-8388608,48);

  \c$case_alt_12\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_9\ else
                     resize(x_11,24);

  result_selection_res_12 <= x_11 > to_signed(8388607,48);

  result_28 <= to_signed(8388607,24) when result_selection_res_12 else
               \c$case_alt_12\;

  \c$app_arg_37\ <= resize(x_13.Frame_sel26_fEqHighLpR,48);

  x_12 <= \c$app_arg_38\ - (resize(x_13.Frame_sel19_fEqLowL,48));

  \c$case_alt_selection_res_10\ <= x_12 < to_signed(-8388608,48);

  \c$case_alt_13\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_10\ else
                     resize(x_12,24);

  result_selection_res_13 <= x_12 > to_signed(8388607,48);

  result_29 <= to_signed(8388607,24) when result_selection_res_13 else
               \c$case_alt_13\;

  \c$app_arg_38\ <= resize(x_13.Frame_sel25_fEqHighLpL,48);

  -- register begin
  eqFilterPipe_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      eqFilterPipe <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      eqFilterPipe <= result_30;
    end if;
  end process;
  -- register end

  with (ds1_5(971 downto 971)) select
    result_30 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(\c$case_alt_14\.Frame_sel0_fL)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(\c$case_alt_14\.Frame_sel2_fLast)
                  & \c$case_alt_14\.Frame_sel3_fGate
                  & \c$case_alt_14\.Frame_sel4_fOd
                  & \c$case_alt_14\.Frame_sel5_fDist
                  & \c$case_alt_14\.Frame_sel6_fEq
                  & \c$case_alt_14\.Frame_sel7_fRat
                  & \c$case_alt_14\.Frame_sel8_fAmp
                  & \c$case_alt_14\.Frame_sel9_fAmpTone
                  & \c$case_alt_14\.Frame_sel10_fCab
                  & \c$case_alt_14\.Frame_sel11_fReverb
                  & std_logic_vector(\c$case_alt_14\.Frame_sel12_fAddr)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel13_fDryL)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel14_fDryR)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel15_fWetL)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel16_fWetR)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel17_fFbL)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel18_fFbR)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel19_fEqLowL)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel20_fEqLowR)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel21_fEqMidL)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel22_fEqMidR)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel23_fEqHighL)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel24_fEqHighR)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel25_fEqHighLpL)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel26_fEqHighLpR)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel27_fAccL)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel28_fAccR)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel29_fAcc2L)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel30_fAcc2R)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel31_fAcc3L)
                  & std_logic_vector(\c$case_alt_14\.Frame_sel32_fAcc3R)))) when others;

  \c$case_alt_14\ <= ( Frame_sel0_fL => x_14.Frame_sel0_fL
                     , Frame_sel1_fR => x_14.Frame_sel1_fR
                     , Frame_sel2_fLast => x_14.Frame_sel2_fLast
                     , Frame_sel3_fGate => x_14.Frame_sel3_fGate
                     , Frame_sel4_fOd => x_14.Frame_sel4_fOd
                     , Frame_sel5_fDist => x_14.Frame_sel5_fDist
                     , Frame_sel6_fEq => x_14.Frame_sel6_fEq
                     , Frame_sel7_fRat => x_14.Frame_sel7_fRat
                     , Frame_sel8_fAmp => x_14.Frame_sel8_fAmp
                     , Frame_sel9_fAmpTone => x_14.Frame_sel9_fAmpTone
                     , Frame_sel10_fCab => x_14.Frame_sel10_fCab
                     , Frame_sel11_fReverb => x_14.Frame_sel11_fReverb
                     , Frame_sel12_fAddr => x_14.Frame_sel12_fAddr
                     , Frame_sel13_fDryL => x_14.Frame_sel13_fDryL
                     , Frame_sel14_fDryR => x_14.Frame_sel14_fDryR
                     , Frame_sel15_fWetL => x_14.Frame_sel15_fWetL
                     , Frame_sel16_fWetR => x_14.Frame_sel16_fWetR
                     , Frame_sel17_fFbL => x_14.Frame_sel17_fFbL
                     , Frame_sel18_fFbR => x_14.Frame_sel18_fFbR
                     , Frame_sel19_fEqLowL => eqLowPrevL + (resize(\c$app_arg_43\,24))
                     , Frame_sel20_fEqLowR => eqLowPrevR + (resize(\c$app_arg_41\,24))
                     , Frame_sel21_fEqMidL => x_14.Frame_sel21_fEqMidL
                     , Frame_sel22_fEqMidR => x_14.Frame_sel22_fEqMidR
                     , Frame_sel23_fEqHighL => x_14.Frame_sel23_fEqHighL
                     , Frame_sel24_fEqHighR => x_14.Frame_sel24_fEqHighR
                     , Frame_sel25_fEqHighLpL => eqHighPrevL + (resize(\c$app_arg_40\,24))
                     , Frame_sel26_fEqHighLpR => eqHighPrevR + (resize(\c$app_arg_39\,24))
                     , Frame_sel27_fAccL => x_14.Frame_sel27_fAccL
                     , Frame_sel28_fAccR => x_14.Frame_sel28_fAccR
                     , Frame_sel29_fAcc2L => x_14.Frame_sel29_fAcc2L
                     , Frame_sel30_fAcc2R => x_14.Frame_sel30_fAcc2R
                     , Frame_sel31_fAcc3L => x_14.Frame_sel31_fAcc3L
                     , Frame_sel32_fAcc3R => x_14.Frame_sel32_fAcc3R );

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

  with (eqFilterPipe(971 downto 971)) select
    \c$eqHighPrevR_app_arg\ <= eqHighPrevR when "0",
                               x_13.Frame_sel26_fEqHighLpR when others;

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

  with (eqFilterPipe(971 downto 971)) select
    \c$eqHighPrevL_app_arg\ <= eqHighPrevL when "0",
                               x_13.Frame_sel25_fEqHighLpL when others;

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

  with (eqFilterPipe(971 downto 971)) select
    \c$eqLowPrevR_app_arg\ <= eqLowPrevR when "0",
                              x_13.Frame_sel20_fEqLowR when others;

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

  with (eqFilterPipe(971 downto 971)) select
    \c$eqLowPrevL_app_arg\ <= eqLowPrevL when "0",
                              x_13.Frame_sel19_fEqLowL when others;

  x_13 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(eqFilterPipe(970 downto 0)));

  x_14 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_5(970 downto 0)));

  -- register begin
  ds1_5_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_5 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_5 <= result_31;
    end if;
  end process;
  -- register end

  with (ds1_6(971 downto 971)) select
    result_31 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(result_32.Frame_sel0_fL)
                  & std_logic_vector(result_32.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(result_32.Frame_sel2_fLast)
                  & result_32.Frame_sel3_fGate
                  & result_32.Frame_sel4_fOd
                  & result_32.Frame_sel5_fDist
                  & result_32.Frame_sel6_fEq
                  & result_32.Frame_sel7_fRat
                  & result_32.Frame_sel8_fAmp
                  & result_32.Frame_sel9_fAmpTone
                  & result_32.Frame_sel10_fCab
                  & result_32.Frame_sel11_fReverb
                  & std_logic_vector(result_32.Frame_sel12_fAddr)
                  & std_logic_vector(result_32.Frame_sel13_fDryL)
                  & std_logic_vector(result_32.Frame_sel14_fDryR)
                  & std_logic_vector(result_32.Frame_sel15_fWetL)
                  & std_logic_vector(result_32.Frame_sel16_fWetR)
                  & std_logic_vector(result_32.Frame_sel17_fFbL)
                  & std_logic_vector(result_32.Frame_sel18_fFbR)
                  & std_logic_vector(result_32.Frame_sel19_fEqLowL)
                  & std_logic_vector(result_32.Frame_sel20_fEqLowR)
                  & std_logic_vector(result_32.Frame_sel21_fEqMidL)
                  & std_logic_vector(result_32.Frame_sel22_fEqMidR)
                  & std_logic_vector(result_32.Frame_sel23_fEqHighL)
                  & std_logic_vector(result_32.Frame_sel24_fEqHighR)
                  & std_logic_vector(result_32.Frame_sel25_fEqHighLpL)
                  & std_logic_vector(result_32.Frame_sel26_fEqHighLpR)
                  & std_logic_vector(result_32.Frame_sel27_fAccL)
                  & std_logic_vector(result_32.Frame_sel28_fAccR)
                  & std_logic_vector(result_32.Frame_sel29_fAcc2L)
                  & std_logic_vector(result_32.Frame_sel30_fAcc2R)
                  & std_logic_vector(result_32.Frame_sel31_fAcc3L)
                  & std_logic_vector(result_32.Frame_sel32_fAcc3R)))) when others;

  result_32 <= ( Frame_sel0_fL => \c$app_arg_50\
               , Frame_sel1_fR => \c$app_arg_45\
               , Frame_sel2_fLast => x_15.Frame_sel2_fLast
               , Frame_sel3_fGate => x_15.Frame_sel3_fGate
               , Frame_sel4_fOd => x_15.Frame_sel4_fOd
               , Frame_sel5_fDist => x_15.Frame_sel5_fDist
               , Frame_sel6_fEq => x_15.Frame_sel6_fEq
               , Frame_sel7_fRat => x_15.Frame_sel7_fRat
               , Frame_sel8_fAmp => x_15.Frame_sel8_fAmp
               , Frame_sel9_fAmpTone => x_15.Frame_sel9_fAmpTone
               , Frame_sel10_fCab => x_15.Frame_sel10_fCab
               , Frame_sel11_fReverb => x_15.Frame_sel11_fReverb
               , Frame_sel12_fAddr => x_15.Frame_sel12_fAddr
               , Frame_sel13_fDryL => x_15.Frame_sel13_fDryL
               , Frame_sel14_fDryR => x_15.Frame_sel14_fDryR
               , Frame_sel15_fWetL => x_15.Frame_sel15_fWetL
               , Frame_sel16_fWetR => x_15.Frame_sel16_fWetR
               , Frame_sel17_fFbL => x_15.Frame_sel17_fFbL
               , Frame_sel18_fFbR => x_15.Frame_sel18_fFbR
               , Frame_sel19_fEqLowL => x_15.Frame_sel19_fEqLowL
               , Frame_sel20_fEqLowR => x_15.Frame_sel20_fEqLowR
               , Frame_sel21_fEqMidL => x_15.Frame_sel21_fEqMidL
               , Frame_sel22_fEqMidR => x_15.Frame_sel22_fEqMidR
               , Frame_sel23_fEqHighL => x_15.Frame_sel23_fEqHighL
               , Frame_sel24_fEqHighR => x_15.Frame_sel24_fEqHighR
               , Frame_sel25_fEqHighLpL => x_15.Frame_sel25_fEqHighLpL
               , Frame_sel26_fEqHighLpR => x_15.Frame_sel26_fEqHighLpR
               , Frame_sel27_fAccL => x_15.Frame_sel27_fAccL
               , Frame_sel28_fAccR => x_15.Frame_sel28_fAccR
               , Frame_sel29_fAcc2L => x_15.Frame_sel29_fAcc2L
               , Frame_sel30_fAcc2R => x_15.Frame_sel30_fAcc2R
               , Frame_sel31_fAcc3L => x_15.Frame_sel31_fAcc3L
               , Frame_sel32_fAcc3R => x_15.Frame_sel32_fAcc3R );

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
    \c$app_arg_49\ <= shift_right(((resize((resize(x_15.Frame_sel1_fR,48)) * \c$app_arg_56\, 48)) + (resize((resize(result_35,48)) * \c$app_arg_55\, 48))),sh_15)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_13\ <= \c$x_app_arg\ < to_signed(-8388608,48);

  \c$case_alt_17\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_13\ else
                     resize(\c$x_app_arg\,24);

  result_selection_res_16 <= \c$x_app_arg\ > to_signed(8388607,48);

  result_35 <= to_signed(8388607,24) when result_selection_res_16 else
               \c$case_alt_17\;

  \c$shI_16\ <= (to_signed(7,64));

  cx_app_arg_shiftR : block
    signal sh_16 : natural;
  begin
    sh_16 <=
        -- pragma translate_off
        natural'high when (\c$shI_16\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_16\);
    \c$x_app_arg\ <= shift_right((resize((resize(x_15.Frame_sel16_fWetR,48)) * \c$x_app_arg_1\, 48)),sh_16)
        -- pragma translate_off
        when ((to_signed(7,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_50\ <= result_36 when \on_5\ else
                    x_15.Frame_sel0_fL;

  \c$bv_8\ <= (x_15.Frame_sel3_fGate);

  \on_5\ <= (\c$bv_8\(7 downto 7)) = std_logic_vector'("1");

  result_selection_res_17 <= result_37 > to_signed(4194304,24);

  result_36 <= resize((to_signed(4194304,25) + \c$app_arg_51\),24) when result_selection_res_17 else
               \c$case_alt_18\;

  \c$case_alt_selection_res_14\ <= result_37 < to_signed(-4194304,24);

  \c$case_alt_18\ <= resize((to_signed(-4194304,25) + \c$app_arg_52\),24) when \c$case_alt_selection_res_14\ else
                     result_37;

  \c$shI_17\ <= (to_signed(2,64));

  capp_arg_51_shiftR : block
    signal sh_17 : natural;
  begin
    sh_17 <=
        -- pragma translate_off
        natural'high when (\c$shI_17\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_17\);
    \c$app_arg_51\ <= shift_right((\c$app_arg_53\ - to_signed(4194304,25)),sh_17)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$shI_18\ <= (to_signed(2,64));

  capp_arg_52_shiftR : block
    signal sh_18 : natural;
  begin
    sh_18 <=
        -- pragma translate_off
        natural'high when (\c$shI_18\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_18\);
    \c$app_arg_52\ <= shift_right((\c$app_arg_53\ + to_signed(4194304,25)),sh_18)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_53\ <= resize(result_37,25);

  \c$case_alt_selection_res_15\ <= \c$app_arg_54\ < to_signed(-8388608,48);

  \c$case_alt_19\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_15\ else
                     resize(\c$app_arg_54\,24);

  result_selection_res_18 <= \c$app_arg_54\ > to_signed(8388607,48);

  result_37 <= to_signed(8388607,24) when result_selection_res_18 else
               \c$case_alt_19\;

  \c$shI_19\ <= (to_signed(8,64));

  capp_arg_54_shiftR : block
    signal sh_19 : natural;
  begin
    sh_19 <=
        -- pragma translate_off
        natural'high when (\c$shI_19\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_19\);
    \c$app_arg_54\ <= shift_right(((resize((resize(x_15.Frame_sel0_fL,48)) * \c$app_arg_56\, 48)) + (resize((resize(result_38,48)) * \c$app_arg_55\, 48))),sh_19)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_55\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(mix)))))))),48);

  \c$case_alt_selection_res_16\ <= \c$x_app_arg_0\ < to_signed(-8388608,48);

  \c$case_alt_20\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_16\ else
                     resize(\c$x_app_arg_0\,24);

  result_selection_res_19 <= \c$x_app_arg_0\ > to_signed(8388607,48);

  result_38 <= to_signed(8388607,24) when result_selection_res_19 else
               \c$case_alt_20\;

  \c$shI_20\ <= (to_signed(7,64));

  cx_app_arg_0_shiftR : block
    signal sh_20 : natural;
  begin
    sh_20 <=
        -- pragma translate_off
        natural'high when (\c$shI_20\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_20\);
    \c$x_app_arg_0\ <= shift_right((resize((resize(x_15.Frame_sel15_fWetL,48)) * \c$x_app_arg_1\, 48)),sh_20)
        -- pragma translate_off
        when ((to_signed(7,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$x_app_arg_1\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(level)))))))),48);

  level <= unsigned((\c$level_app_arg\(15 downto 8)));

  \c$app_arg_56\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(invMix)))))))),48);

  invMix <= to_unsigned(255,8) - mix;

  mix <= unsigned((\c$level_app_arg\(7 downto 0)));

  \c$level_app_arg\ <= x_15.Frame_sel10_fCab;

  x_15 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_6(970 downto 0)));

  -- register begin
  ds1_6_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_6 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_6 <= result_39;
    end if;
  end process;
  -- register end

  with (ds1_7(971 downto 971)) select
    result_39 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(result_42.Frame_sel0_fL)
                  & std_logic_vector(result_42.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(result_42.Frame_sel2_fLast)
                  & result_42.Frame_sel3_fGate
                  & result_42.Frame_sel4_fOd
                  & result_42.Frame_sel5_fDist
                  & result_42.Frame_sel6_fEq
                  & result_42.Frame_sel7_fRat
                  & result_42.Frame_sel8_fAmp
                  & result_42.Frame_sel9_fAmpTone
                  & result_42.Frame_sel10_fCab
                  & result_42.Frame_sel11_fReverb
                  & std_logic_vector(result_42.Frame_sel12_fAddr)
                  & std_logic_vector(result_42.Frame_sel13_fDryL)
                  & std_logic_vector(result_42.Frame_sel14_fDryR)
                  & std_logic_vector(result_42.Frame_sel15_fWetL)
                  & std_logic_vector(result_42.Frame_sel16_fWetR)
                  & std_logic_vector(result_42.Frame_sel17_fFbL)
                  & std_logic_vector(result_42.Frame_sel18_fFbR)
                  & std_logic_vector(result_42.Frame_sel19_fEqLowL)
                  & std_logic_vector(result_42.Frame_sel20_fEqLowR)
                  & std_logic_vector(result_42.Frame_sel21_fEqMidL)
                  & std_logic_vector(result_42.Frame_sel22_fEqMidR)
                  & std_logic_vector(result_42.Frame_sel23_fEqHighL)
                  & std_logic_vector(result_42.Frame_sel24_fEqHighR)
                  & std_logic_vector(result_42.Frame_sel25_fEqHighLpL)
                  & std_logic_vector(result_42.Frame_sel26_fEqHighLpR)
                  & std_logic_vector(result_42.Frame_sel27_fAccL)
                  & std_logic_vector(result_42.Frame_sel28_fAccR)
                  & std_logic_vector(result_42.Frame_sel29_fAcc2L)
                  & std_logic_vector(result_42.Frame_sel30_fAcc2R)
                  & std_logic_vector(result_42.Frame_sel31_fAcc3L)
                  & std_logic_vector(result_42.Frame_sel32_fAcc3R)))) when others;

  \c$shI_21\ <= (to_signed(8,64));

  capp_arg_57_shiftR : block
    signal sh_21 : natural;
  begin
    sh_21 <=
        -- pragma translate_off
        natural'high when (\c$shI_21\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_21\);
    \c$app_arg_57\ <= shift_right(((x_16.Frame_sel27_fAccL + x_16.Frame_sel29_fAcc2L) + x_16.Frame_sel31_fAcc3L),sh_21)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_17\ <= \c$app_arg_57\ < to_signed(-8388608,48);

  \c$case_alt_21\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_17\ else
                     resize(\c$app_arg_57\,24);

  result_selection_res_20 <= \c$app_arg_57\ > to_signed(8388607,48);

  result_40 <= to_signed(8388607,24) when result_selection_res_20 else
               \c$case_alt_21\;

  \c$app_arg_58\ <= result_40 when \on_6\ else
                    x_16.Frame_sel0_fL;

  \c$shI_22\ <= (to_signed(8,64));

  capp_arg_59_shiftR : block
    signal sh_22 : natural;
  begin
    sh_22 <=
        -- pragma translate_off
        natural'high when (\c$shI_22\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_22\);
    \c$app_arg_59\ <= shift_right(((x_16.Frame_sel28_fAccR + x_16.Frame_sel30_fAcc2R) + x_16.Frame_sel32_fAcc3R),sh_22)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_18\ <= \c$app_arg_59\ < to_signed(-8388608,48);

  \c$case_alt_22\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_18\ else
                     resize(\c$app_arg_59\,24);

  result_selection_res_21 <= \c$app_arg_59\ > to_signed(8388607,48);

  result_41 <= to_signed(8388607,24) when result_selection_res_21 else
               \c$case_alt_22\;

  \c$app_arg_60\ <= result_41 when \on_6\ else
                    x_16.Frame_sel1_fR;

  result_42 <= ( Frame_sel0_fL => x_16.Frame_sel0_fL
               , Frame_sel1_fR => x_16.Frame_sel1_fR
               , Frame_sel2_fLast => x_16.Frame_sel2_fLast
               , Frame_sel3_fGate => x_16.Frame_sel3_fGate
               , Frame_sel4_fOd => x_16.Frame_sel4_fOd
               , Frame_sel5_fDist => x_16.Frame_sel5_fDist
               , Frame_sel6_fEq => x_16.Frame_sel6_fEq
               , Frame_sel7_fRat => x_16.Frame_sel7_fRat
               , Frame_sel8_fAmp => x_16.Frame_sel8_fAmp
               , Frame_sel9_fAmpTone => x_16.Frame_sel9_fAmpTone
               , Frame_sel10_fCab => x_16.Frame_sel10_fCab
               , Frame_sel11_fReverb => x_16.Frame_sel11_fReverb
               , Frame_sel12_fAddr => x_16.Frame_sel12_fAddr
               , Frame_sel13_fDryL => x_16.Frame_sel13_fDryL
               , Frame_sel14_fDryR => x_16.Frame_sel14_fDryR
               , Frame_sel15_fWetL => \c$app_arg_58\
               , Frame_sel16_fWetR => \c$app_arg_60\
               , Frame_sel17_fFbL => x_16.Frame_sel17_fFbL
               , Frame_sel18_fFbR => x_16.Frame_sel18_fFbR
               , Frame_sel19_fEqLowL => x_16.Frame_sel19_fEqLowL
               , Frame_sel20_fEqLowR => x_16.Frame_sel20_fEqLowR
               , Frame_sel21_fEqMidL => x_16.Frame_sel21_fEqMidL
               , Frame_sel22_fEqMidR => x_16.Frame_sel22_fEqMidR
               , Frame_sel23_fEqHighL => x_16.Frame_sel23_fEqHighL
               , Frame_sel24_fEqHighR => x_16.Frame_sel24_fEqHighR
               , Frame_sel25_fEqHighLpL => x_16.Frame_sel25_fEqHighLpL
               , Frame_sel26_fEqHighLpR => x_16.Frame_sel26_fEqHighLpR
               , Frame_sel27_fAccL => x_16.Frame_sel27_fAccL
               , Frame_sel28_fAccR => x_16.Frame_sel28_fAccR
               , Frame_sel29_fAcc2L => x_16.Frame_sel29_fAcc2L
               , Frame_sel30_fAcc2R => x_16.Frame_sel30_fAcc2R
               , Frame_sel31_fAcc3L => x_16.Frame_sel31_fAcc3L
               , Frame_sel32_fAcc3R => x_16.Frame_sel32_fAcc3R );

  \c$bv_9\ <= (x_16.Frame_sel3_fGate);

  \on_6\ <= (\c$bv_9\(7 downto 7)) = std_logic_vector'("1");

  x_16 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_7(970 downto 0)));

  -- register begin
  ds1_7_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_7 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_7 <= result_43;
    end if;
  end process;
  -- register end

  with (ampMasterPipe(971 downto 971)) select
    result_43 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(result_44.Frame_sel0_fL)
                  & std_logic_vector(result_44.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(result_44.Frame_sel2_fLast)
                  & result_44.Frame_sel3_fGate
                  & result_44.Frame_sel4_fOd
                  & result_44.Frame_sel5_fDist
                  & result_44.Frame_sel6_fEq
                  & result_44.Frame_sel7_fRat
                  & result_44.Frame_sel8_fAmp
                  & result_44.Frame_sel9_fAmpTone
                  & result_44.Frame_sel10_fCab
                  & result_44.Frame_sel11_fReverb
                  & std_logic_vector(result_44.Frame_sel12_fAddr)
                  & std_logic_vector(result_44.Frame_sel13_fDryL)
                  & std_logic_vector(result_44.Frame_sel14_fDryR)
                  & std_logic_vector(result_44.Frame_sel15_fWetL)
                  & std_logic_vector(result_44.Frame_sel16_fWetR)
                  & std_logic_vector(result_44.Frame_sel17_fFbL)
                  & std_logic_vector(result_44.Frame_sel18_fFbR)
                  & std_logic_vector(result_44.Frame_sel19_fEqLowL)
                  & std_logic_vector(result_44.Frame_sel20_fEqLowR)
                  & std_logic_vector(result_44.Frame_sel21_fEqMidL)
                  & std_logic_vector(result_44.Frame_sel22_fEqMidR)
                  & std_logic_vector(result_44.Frame_sel23_fEqHighL)
                  & std_logic_vector(result_44.Frame_sel24_fEqHighR)
                  & std_logic_vector(result_44.Frame_sel25_fEqHighLpL)
                  & std_logic_vector(result_44.Frame_sel26_fEqHighLpR)
                  & std_logic_vector(result_44.Frame_sel27_fAccL)
                  & std_logic_vector(result_44.Frame_sel28_fAccR)
                  & std_logic_vector(result_44.Frame_sel29_fAcc2L)
                  & std_logic_vector(result_44.Frame_sel30_fAcc2R)
                  & std_logic_vector(result_44.Frame_sel31_fAcc3L)
                  & std_logic_vector(result_44.Frame_sel32_fAcc3R)))) when others;

  result_44 <= ( Frame_sel0_fL => x_17.Frame_sel0_fL
               , Frame_sel1_fR => x_17.Frame_sel1_fR
               , Frame_sel2_fLast => x_17.Frame_sel2_fLast
               , Frame_sel3_fGate => x_17.Frame_sel3_fGate
               , Frame_sel4_fOd => x_17.Frame_sel4_fOd
               , Frame_sel5_fDist => x_17.Frame_sel5_fDist
               , Frame_sel6_fEq => x_17.Frame_sel6_fEq
               , Frame_sel7_fRat => x_17.Frame_sel7_fRat
               , Frame_sel8_fAmp => x_17.Frame_sel8_fAmp
               , Frame_sel9_fAmpTone => x_17.Frame_sel9_fAmpTone
               , Frame_sel10_fCab => x_17.Frame_sel10_fCab
               , Frame_sel11_fReverb => x_17.Frame_sel11_fReverb
               , Frame_sel12_fAddr => x_17.Frame_sel12_fAddr
               , Frame_sel13_fDryL => x_17.Frame_sel13_fDryL
               , Frame_sel14_fDryR => x_17.Frame_sel14_fDryR
               , Frame_sel15_fWetL => x_17.Frame_sel15_fWetL
               , Frame_sel16_fWetR => x_17.Frame_sel16_fWetR
               , Frame_sel17_fFbL => x_17.Frame_sel17_fFbL
               , Frame_sel18_fFbR => x_17.Frame_sel18_fFbR
               , Frame_sel19_fEqLowL => x_17.Frame_sel19_fEqLowL
               , Frame_sel20_fEqLowR => x_17.Frame_sel20_fEqLowR
               , Frame_sel21_fEqMidL => x_17.Frame_sel21_fEqMidL
               , Frame_sel22_fEqMidR => x_17.Frame_sel22_fEqMidR
               , Frame_sel23_fEqHighL => x_17.Frame_sel23_fEqHighL
               , Frame_sel24_fEqHighR => x_17.Frame_sel24_fEqHighR
               , Frame_sel25_fEqHighLpL => x_17.Frame_sel25_fEqHighLpL
               , Frame_sel26_fEqHighLpR => x_17.Frame_sel26_fEqHighLpR
               , Frame_sel27_fAccL => \c$app_arg_66\
               , Frame_sel28_fAccR => \c$app_arg_65\
               , Frame_sel29_fAcc2L => \c$app_arg_62\
               , Frame_sel30_fAcc2R => \c$app_arg_61\
               , Frame_sel31_fAcc3L => to_signed(0,48)
               , Frame_sel32_fAcc3R => to_signed(0,48) );

  \c$app_arg_61\ <= (resize((resize(cabD2R,48)) * \c$app_arg_64\, 48)) + (resize((resize(cabD3R,48)) * \c$app_arg_63\, 48)) when \on_7\ else
                    to_signed(0,48);

  \c$app_arg_62\ <= (resize((resize(cabD2L,48)) * \c$app_arg_64\, 48)) + (resize((resize(cabD3L,48)) * \c$app_arg_63\, 48)) when \on_7\ else
                    to_signed(0,48);

  \c$app_arg_63\ <= resize(result_45,48);

  \c$shI_23\ <= (to_signed(6,64));

  ds_1_shiftL : block
    signal sh_23 : natural;
  begin
    sh_23 <=
        -- pragma translate_off
        natural'high when (\c$shI_23\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_23\);
    ds_1 <= shift_right(model,sh_23)
        -- pragma translate_off
        when ((to_signed(6,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  with (ds_1) select
    result_45 <= \c$case_alt_24\ when x"00",
                 \c$case_alt_23\ when x"01",
                 \c$case_alt_25\ when others;

  with (\c$cabCoeff_$jOut_app_arg\) select
    \c$case_alt_23\ <= to_signed(30,10) when "00",
                       to_signed(24,10) when "01",
                       to_signed(16,10) when others;

  with (\c$cabCoeff_$jOut_app_arg\) select
    \c$case_alt_24\ <= to_signed(22,10) when "00",
                       to_signed(14,10) when "01",
                       to_signed(8,10) when others;

  with (\c$cabCoeff_$jOut_app_arg\) select
    \c$case_alt_25\ <= to_signed(46,10) when "00",
                       to_signed(38,10) when "01",
                       to_signed(26,10) when others;

  \c$cabCoeff_$jOut_app_arg_selection_res\ <= air < to_unsigned(86,8);

  \c$cabCoeff_$jOut_app_arg\ <= to_unsigned(0,2) when \c$cabCoeff_$jOut_app_arg_selection_res\ else
                                \c$cabCoeff_$jOut_case_alt\;

  \c$cabCoeff_$jOut_case_alt_selection_res\ <= air < to_unsigned(171,8);

  \c$cabCoeff_$jOut_case_alt\ <= to_unsigned(1,2) when \c$cabCoeff_$jOut_case_alt_selection_res\ else
                                 to_unsigned(2,2);

  \c$app_arg_64\ <= resize(result_46,48);

  \c$shI_24\ <= (to_signed(6,64));

  ds_2_shiftL : block
    signal sh_24 : natural;
  begin
    sh_24 <=
        -- pragma translate_off
        natural'high when (\c$shI_24\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_24\);
    ds_2 <= shift_right(model,sh_24)
        -- pragma translate_off
        when ((to_signed(6,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  with (ds_2) select
    result_46 <= \c$case_alt_27\ when x"00",
                 \c$case_alt_26\ when x"01",
                 \c$case_alt_28\ when others;

  with (\c$cabCoeff_$jOut_app_arg_0\) select
    \c$case_alt_26\ <= to_signed(58,10) when "00",
                       to_signed(52,10) when "01",
                       to_signed(40,10) when others;

  with (\c$cabCoeff_$jOut_app_arg_0\) select
    \c$case_alt_27\ <= to_signed(42,10) when "00",
                       to_signed(34,10) when "01",
                       to_signed(24,10) when others;

  with (\c$cabCoeff_$jOut_app_arg_0\) select
    \c$case_alt_28\ <= to_signed(74,10) when "00",
                       to_signed(66,10) when "01",
                       to_signed(54,10) when others;

  \c$cabCoeff_$jOut_app_arg_selection_res_0\ <= air < to_unsigned(86,8);

  \c$cabCoeff_$jOut_app_arg_0\ <= to_unsigned(0,2) when \c$cabCoeff_$jOut_app_arg_selection_res_0\ else
                                  \c$cabCoeff_$jOut_case_alt_0\;

  \c$cabCoeff_$jOut_case_alt_selection_res_0\ <= air < to_unsigned(171,8);

  \c$cabCoeff_$jOut_case_alt_0\ <= to_unsigned(1,2) when \c$cabCoeff_$jOut_case_alt_selection_res_0\ else
                                   to_unsigned(2,2);

  \c$app_arg_65\ <= (resize((resize(x_17.Frame_sel1_fR,48)) * \c$app_arg_68\, 48)) + (resize((resize(cabD1R,48)) * \c$app_arg_67\, 48)) when \on_7\ else
                    to_signed(0,48);

  \c$app_arg_66\ <= (resize((resize(x_17.Frame_sel0_fL,48)) * \c$app_arg_68\, 48)) + (resize((resize(cabD1L,48)) * \c$app_arg_67\, 48)) when \on_7\ else
                    to_signed(0,48);

  \c$bv_10\ <= (x_17.Frame_sel3_fGate);

  \on_7\ <= (\c$bv_10\(7 downto 7)) = std_logic_vector'("1");

  \c$app_arg_67\ <= resize(result_47,48);

  \c$shI_25\ <= (to_signed(6,64));

  ds_3_shiftL : block
    signal sh_25 : natural;
  begin
    sh_25 <=
        -- pragma translate_off
        natural'high when (\c$shI_25\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_25\);
    ds_3 <= shift_right(model,sh_25)
        -- pragma translate_off
        when ((to_signed(6,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  with (ds_3) select
    result_47 <= \c$case_alt_30\ when x"00",
                 \c$case_alt_29\ when x"01",
                 \c$case_alt_31\ when others;

  with (\c$cabCoeff_$jOut_app_arg_1\) select
    \c$case_alt_29\ <= to_signed(94,10) when "00",
                       to_signed(86,10) when "01",
                       to_signed(76,10) when others;

  with (\c$cabCoeff_$jOut_app_arg_1\) select
    \c$case_alt_30\ <= to_signed(78,10) when "00",
                       to_signed(72,10) when "01",
                       to_signed(62,10) when others;

  with (\c$cabCoeff_$jOut_app_arg_1\) select
    \c$case_alt_31\ <= to_signed(104,10) when "00",
                       to_signed(96,10) when "01",
                       to_signed(86,10) when others;

  \c$cabCoeff_$jOut_app_arg_selection_res_1\ <= air < to_unsigned(86,8);

  \c$cabCoeff_$jOut_app_arg_1\ <= to_unsigned(0,2) when \c$cabCoeff_$jOut_app_arg_selection_res_1\ else
                                  \c$cabCoeff_$jOut_case_alt_1\;

  \c$cabCoeff_$jOut_case_alt_selection_res_1\ <= air < to_unsigned(171,8);

  \c$cabCoeff_$jOut_case_alt_1\ <= to_unsigned(1,2) when \c$cabCoeff_$jOut_case_alt_selection_res_1\ else
                                   to_unsigned(2,2);

  \c$app_arg_68\ <= resize(result_48,48);

  \c$shI_26\ <= (to_signed(6,64));

  ds_4_shiftL : block
    signal sh_26 : natural;
  begin
    sh_26 <=
        -- pragma translate_off
        natural'high when (\c$shI_26\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_26\);
    ds_4 <= shift_right(model,sh_26)
        -- pragma translate_off
        when ((to_signed(6,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  with (ds_4) select
    result_48 <= \c$case_alt_33\ when x"00",
                 \c$case_alt_32\ when x"01",
                 \c$case_alt_34\ when others;

  with (\c$cabCoeff_$jOut_app_arg_2\) select
    \c$case_alt_32\ <= to_signed(88,10) when "00",
                       to_signed(100,10) when "01",
                       to_signed(112,10) when others;

  with (\c$cabCoeff_$jOut_app_arg_2\) select
    \c$case_alt_33\ <= to_signed(104,10) when "00",
                       to_signed(112,10) when "01",
                       to_signed(124,10) when others;

  with (\c$cabCoeff_$jOut_app_arg_2\) select
    \c$case_alt_34\ <= to_signed(78,10) when "00",
                       to_signed(88,10) when "01",
                       to_signed(100,10) when others;

  \c$cabCoeff_$jOut_app_arg_selection_res_2\ <= air < to_unsigned(86,8);

  \c$cabCoeff_$jOut_app_arg_2\ <= to_unsigned(0,2) when \c$cabCoeff_$jOut_app_arg_selection_res_2\ else
                                  \c$cabCoeff_$jOut_case_alt_2\;

  \c$cabCoeff_$jOut_case_alt_selection_res_2\ <= air < to_unsigned(171,8);

  \c$cabCoeff_$jOut_case_alt_2\ <= to_unsigned(1,2) when \c$cabCoeff_$jOut_case_alt_selection_res_2\ else
                                   to_unsigned(2,2);

  air <= unsigned((\c$air_app_arg\(31 downto 24)));

  model <= unsigned((\c$air_app_arg\(23 downto 16)));

  \c$air_app_arg\ <= x_17.Frame_sel10_fCab;

  -- register begin
  cabD3L_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      cabD3L <= to_signed(0,24);
    elsif rising_edge(clk) then
      cabD3L <= \c$cabD3L_app_arg\;
    end if;
  end process;
  -- register end

  with (ampMasterPipe(971 downto 971)) select
    \c$cabD3L_app_arg\ <= cabD3L when "0",
                          cabD2L when others;

  -- register begin
  cabD2L_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      cabD2L <= to_signed(0,24);
    elsif rising_edge(clk) then
      cabD2L <= \c$cabD2L_app_arg\;
    end if;
  end process;
  -- register end

  with (ampMasterPipe(971 downto 971)) select
    \c$cabD2L_app_arg\ <= cabD2L when "0",
                          cabD1L when others;

  -- register begin
  cabD1L_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      cabD1L <= to_signed(0,24);
    elsif rising_edge(clk) then
      cabD1L <= \c$cabD1L_app_arg\;
    end if;
  end process;
  -- register end

  with (ampMasterPipe(971 downto 971)) select
    \c$cabD1L_app_arg\ <= cabD1L when "0",
                          \c$cabD1L_case_alt\ when others;

  with (ampMasterPipe(971 downto 971)) select
    \c$cabD1L_case_alt\ <= to_signed(0,24) when "0",
                           x_17.Frame_sel0_fL when others;

  -- register begin
  cabD3R_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      cabD3R <= to_signed(0,24);
    elsif rising_edge(clk) then
      cabD3R <= \c$cabD3R_app_arg\;
    end if;
  end process;
  -- register end

  with (ampMasterPipe(971 downto 971)) select
    \c$cabD3R_app_arg\ <= cabD3R when "0",
                          cabD2R when others;

  -- register begin
  cabD2R_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      cabD2R <= to_signed(0,24);
    elsif rising_edge(clk) then
      cabD2R <= \c$cabD2R_app_arg\;
    end if;
  end process;
  -- register end

  with (ampMasterPipe(971 downto 971)) select
    \c$cabD2R_app_arg\ <= cabD2R when "0",
                          cabD1R when others;

  -- register begin
  cabD1R_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      cabD1R <= to_signed(0,24);
    elsif rising_edge(clk) then
      cabD1R <= \c$cabD1R_app_arg\;
    end if;
  end process;
  -- register end

  with (ampMasterPipe(971 downto 971)) select
    \c$cabD1R_app_arg\ <= cabD1R when "0",
                          \c$cabD1R_case_alt\ when others;

  with (ampMasterPipe(971 downto 971)) select
    \c$cabD1R_case_alt\ <= to_signed(0,24) when "0",
                           x_17.Frame_sel1_fR when others;

  x_17 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ampMasterPipe(970 downto 0)));

  -- register begin
  ampMasterPipe_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ampMasterPipe <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ampMasterPipe <= result_49;
    end if;
  end process;
  -- register end

  with (ds1_8(971 downto 971)) select
    result_49 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(result_50.Frame_sel0_fL)
                  & std_logic_vector(result_50.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(result_50.Frame_sel2_fLast)
                  & result_50.Frame_sel3_fGate
                  & result_50.Frame_sel4_fOd
                  & result_50.Frame_sel5_fDist
                  & result_50.Frame_sel6_fEq
                  & result_50.Frame_sel7_fRat
                  & result_50.Frame_sel8_fAmp
                  & result_50.Frame_sel9_fAmpTone
                  & result_50.Frame_sel10_fCab
                  & result_50.Frame_sel11_fReverb
                  & std_logic_vector(result_50.Frame_sel12_fAddr)
                  & std_logic_vector(result_50.Frame_sel13_fDryL)
                  & std_logic_vector(result_50.Frame_sel14_fDryR)
                  & std_logic_vector(result_50.Frame_sel15_fWetL)
                  & std_logic_vector(result_50.Frame_sel16_fWetR)
                  & std_logic_vector(result_50.Frame_sel17_fFbL)
                  & std_logic_vector(result_50.Frame_sel18_fFbR)
                  & std_logic_vector(result_50.Frame_sel19_fEqLowL)
                  & std_logic_vector(result_50.Frame_sel20_fEqLowR)
                  & std_logic_vector(result_50.Frame_sel21_fEqMidL)
                  & std_logic_vector(result_50.Frame_sel22_fEqMidR)
                  & std_logic_vector(result_50.Frame_sel23_fEqHighL)
                  & std_logic_vector(result_50.Frame_sel24_fEqHighR)
                  & std_logic_vector(result_50.Frame_sel25_fEqHighLpL)
                  & std_logic_vector(result_50.Frame_sel26_fEqHighLpR)
                  & std_logic_vector(result_50.Frame_sel27_fAccL)
                  & std_logic_vector(result_50.Frame_sel28_fAccR)
                  & std_logic_vector(result_50.Frame_sel29_fAcc2L)
                  & std_logic_vector(result_50.Frame_sel30_fAcc2R)
                  & std_logic_vector(result_50.Frame_sel31_fAcc3L)
                  & std_logic_vector(result_50.Frame_sel32_fAcc3R)))) when others;

  result_50 <= ( Frame_sel0_fL => \c$app_arg_74\
               , Frame_sel1_fR => \c$app_arg_69\
               , Frame_sel2_fLast => x_18.Frame_sel2_fLast
               , Frame_sel3_fGate => x_18.Frame_sel3_fGate
               , Frame_sel4_fOd => x_18.Frame_sel4_fOd
               , Frame_sel5_fDist => x_18.Frame_sel5_fDist
               , Frame_sel6_fEq => x_18.Frame_sel6_fEq
               , Frame_sel7_fRat => x_18.Frame_sel7_fRat
               , Frame_sel8_fAmp => x_18.Frame_sel8_fAmp
               , Frame_sel9_fAmpTone => x_18.Frame_sel9_fAmpTone
               , Frame_sel10_fCab => x_18.Frame_sel10_fCab
               , Frame_sel11_fReverb => x_18.Frame_sel11_fReverb
               , Frame_sel12_fAddr => x_18.Frame_sel12_fAddr
               , Frame_sel13_fDryL => x_18.Frame_sel13_fDryL
               , Frame_sel14_fDryR => x_18.Frame_sel14_fDryR
               , Frame_sel15_fWetL => x_18.Frame_sel15_fWetL
               , Frame_sel16_fWetR => x_18.Frame_sel16_fWetR
               , Frame_sel17_fFbL => x_18.Frame_sel17_fFbL
               , Frame_sel18_fFbR => x_18.Frame_sel18_fFbR
               , Frame_sel19_fEqLowL => x_18.Frame_sel19_fEqLowL
               , Frame_sel20_fEqLowR => x_18.Frame_sel20_fEqLowR
               , Frame_sel21_fEqMidL => x_18.Frame_sel21_fEqMidL
               , Frame_sel22_fEqMidR => x_18.Frame_sel22_fEqMidR
               , Frame_sel23_fEqHighL => x_18.Frame_sel23_fEqHighL
               , Frame_sel24_fEqHighR => x_18.Frame_sel24_fEqHighR
               , Frame_sel25_fEqHighLpL => x_18.Frame_sel25_fEqHighLpL
               , Frame_sel26_fEqHighLpR => x_18.Frame_sel26_fEqHighLpR
               , Frame_sel27_fAccL => x_18.Frame_sel27_fAccL
               , Frame_sel28_fAccR => x_18.Frame_sel28_fAccR
               , Frame_sel29_fAcc2L => x_18.Frame_sel29_fAcc2L
               , Frame_sel30_fAcc2R => x_18.Frame_sel30_fAcc2R
               , Frame_sel31_fAcc3L => x_18.Frame_sel31_fAcc3L
               , Frame_sel32_fAcc3R => x_18.Frame_sel32_fAcc3R );

  \c$app_arg_69\ <= result_51 when \on_8\ else
                    x_18.Frame_sel1_fR;

  result_selection_res_22 <= result_52 > to_signed(4194304,24);

  result_51 <= resize((to_signed(4194304,25) + \c$app_arg_70\),24) when result_selection_res_22 else
               \c$case_alt_35\;

  \c$case_alt_selection_res_19\ <= result_52 < to_signed(-4194304,24);

  \c$case_alt_35\ <= resize((to_signed(-4194304,25) + \c$app_arg_71\),24) when \c$case_alt_selection_res_19\ else
                     result_52;

  \c$shI_27\ <= (to_signed(2,64));

  capp_arg_70_shiftR : block
    signal sh_27 : natural;
  begin
    sh_27 <=
        -- pragma translate_off
        natural'high when (\c$shI_27\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_27\);
    \c$app_arg_70\ <= shift_right((\c$app_arg_72\ - to_signed(4194304,25)),sh_27)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$shI_28\ <= (to_signed(2,64));

  capp_arg_71_shiftR : block
    signal sh_28 : natural;
  begin
    sh_28 <=
        -- pragma translate_off
        natural'high when (\c$shI_28\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_28\);
    \c$app_arg_71\ <= shift_right((\c$app_arg_72\ + to_signed(4194304,25)),sh_28)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_72\ <= resize(result_52,25);

  \c$case_alt_selection_res_20\ <= \c$app_arg_73\ < to_signed(-8388608,48);

  \c$case_alt_36\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_20\ else
                     resize(\c$app_arg_73\,24);

  result_selection_res_23 <= \c$app_arg_73\ > to_signed(8388607,48);

  result_52 <= to_signed(8388607,24) when result_selection_res_23 else
               \c$case_alt_36\;

  \c$shI_29\ <= (to_signed(7,64));

  capp_arg_73_shiftR : block
    signal sh_29 : natural;
  begin
    sh_29 <=
        -- pragma translate_off
        natural'high when (\c$shI_29\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_29\);
    \c$app_arg_73\ <= shift_right((resize((resize(x_18.Frame_sel16_fWetR,48)) * \c$app_arg_79\, 48)),sh_29)
        -- pragma translate_off
        when ((to_signed(7,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_74\ <= result_53 when \on_8\ else
                    x_18.Frame_sel0_fL;

  \c$bv_11\ <= (x_18.Frame_sel3_fGate);

  \on_8\ <= (\c$bv_11\(6 downto 6)) = std_logic_vector'("1");

  result_selection_res_24 <= result_54 > to_signed(4194304,24);

  result_53 <= resize((to_signed(4194304,25) + \c$app_arg_75\),24) when result_selection_res_24 else
               \c$case_alt_37\;

  \c$case_alt_selection_res_21\ <= result_54 < to_signed(-4194304,24);

  \c$case_alt_37\ <= resize((to_signed(-4194304,25) + \c$app_arg_76\),24) when \c$case_alt_selection_res_21\ else
                     result_54;

  \c$shI_30\ <= (to_signed(2,64));

  capp_arg_75_shiftR : block
    signal sh_30 : natural;
  begin
    sh_30 <=
        -- pragma translate_off
        natural'high when (\c$shI_30\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_30\);
    \c$app_arg_75\ <= shift_right((\c$app_arg_77\ - to_signed(4194304,25)),sh_30)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$shI_31\ <= (to_signed(2,64));

  capp_arg_76_shiftR : block
    signal sh_31 : natural;
  begin
    sh_31 <=
        -- pragma translate_off
        natural'high when (\c$shI_31\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_31\);
    \c$app_arg_76\ <= shift_right((\c$app_arg_77\ + to_signed(4194304,25)),sh_31)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_77\ <= resize(result_54,25);

  \c$case_alt_selection_res_22\ <= \c$app_arg_78\ < to_signed(-8388608,48);

  \c$case_alt_38\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_22\ else
                     resize(\c$app_arg_78\,24);

  result_selection_res_25 <= \c$app_arg_78\ > to_signed(8388607,48);

  result_54 <= to_signed(8388607,24) when result_selection_res_25 else
               \c$case_alt_38\;

  \c$shI_32\ <= (to_signed(7,64));

  capp_arg_78_shiftR : block
    signal sh_32 : natural;
  begin
    sh_32 <=
        -- pragma translate_off
        natural'high when (\c$shI_32\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_32\);
    \c$app_arg_78\ <= shift_right((resize((resize(x_18.Frame_sel15_fWetL,48)) * \c$app_arg_79\, 48)),sh_32)
        -- pragma translate_off
        when ((to_signed(7,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_79\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(level_0)))))))),48);

  \c$bv_12\ <= (x_18.Frame_sel8_fAmp);

  level_0 <= unsigned((\c$bv_12\(15 downto 8)));

  x_18 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_8(970 downto 0)));

  -- register begin
  ds1_8_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_8 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_8 <= result_55;
    end if;
  end process;
  -- register end

  with (ds1_9(971 downto 971)) select
    result_55 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(result_64.Frame_sel0_fL)
                  & std_logic_vector(result_64.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(result_64.Frame_sel2_fLast)
                  & result_64.Frame_sel3_fGate
                  & result_64.Frame_sel4_fOd
                  & result_64.Frame_sel5_fDist
                  & result_64.Frame_sel6_fEq
                  & result_64.Frame_sel7_fRat
                  & result_64.Frame_sel8_fAmp
                  & result_64.Frame_sel9_fAmpTone
                  & result_64.Frame_sel10_fCab
                  & result_64.Frame_sel11_fReverb
                  & std_logic_vector(result_64.Frame_sel12_fAddr)
                  & std_logic_vector(result_64.Frame_sel13_fDryL)
                  & std_logic_vector(result_64.Frame_sel14_fDryR)
                  & std_logic_vector(result_64.Frame_sel15_fWetL)
                  & std_logic_vector(result_64.Frame_sel16_fWetR)
                  & std_logic_vector(result_64.Frame_sel17_fFbL)
                  & std_logic_vector(result_64.Frame_sel18_fFbR)
                  & std_logic_vector(result_64.Frame_sel19_fEqLowL)
                  & std_logic_vector(result_64.Frame_sel20_fEqLowR)
                  & std_logic_vector(result_64.Frame_sel21_fEqMidL)
                  & std_logic_vector(result_64.Frame_sel22_fEqMidR)
                  & std_logic_vector(result_64.Frame_sel23_fEqHighL)
                  & std_logic_vector(result_64.Frame_sel24_fEqHighR)
                  & std_logic_vector(result_64.Frame_sel25_fEqHighLpL)
                  & std_logic_vector(result_64.Frame_sel26_fEqHighLpR)
                  & std_logic_vector(result_64.Frame_sel27_fAccL)
                  & std_logic_vector(result_64.Frame_sel28_fAccR)
                  & std_logic_vector(result_64.Frame_sel29_fAcc2L)
                  & std_logic_vector(result_64.Frame_sel30_fAcc2R)
                  & std_logic_vector(result_64.Frame_sel31_fAcc3L)
                  & std_logic_vector(result_64.Frame_sel32_fAcc3R)))) when others;

  \c$shI_33\ <= (to_signed(10,64));

  capp_arg_80_shiftR : block
    signal sh_33 : natural;
  begin
    sh_33 <=
        -- pragma translate_off
        natural'high when (\c$shI_33\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_33\);
    \c$app_arg_80\ <= shift_right(x_21.Frame_sel29_fAcc2L,sh_33)
        -- pragma translate_off
        when ((to_signed(10,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_23\ <= \c$app_arg_80\ < to_signed(-8388608,48);

  \c$case_alt_39\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_23\ else
                     resize(\c$app_arg_80\,24);

  result_selection_res_26 <= \c$app_arg_80\ > to_signed(8388607,48);

  result_56 <= to_signed(8388607,24) when result_selection_res_26 else
               \c$case_alt_39\;

  \c$shI_34\ <= (to_signed(9,64));

  capp_arg_81_shiftR : block
    signal sh_34 : natural;
  begin
    sh_34 <=
        -- pragma translate_off
        natural'high when (\c$shI_34\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_34\);
    \c$app_arg_81\ <= shift_right(x_21.Frame_sel31_fAcc3L,sh_34)
        -- pragma translate_off
        when ((to_signed(9,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_24\ <= \c$app_arg_81\ < to_signed(-8388608,48);

  \c$case_alt_40\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_24\ else
                     resize(\c$app_arg_81\,24);

  result_selection_res_27 <= \c$app_arg_81\ > to_signed(8388607,48);

  result_57 <= to_signed(8388607,24) when result_selection_res_27 else
               \c$case_alt_40\;

  x_19 <= (x_21.Frame_sel27_fAccL + (resize(result_56,48))) + (resize(result_57,48));

  \c$case_alt_selection_res_25\ <= x_19 < to_signed(-8388608,48);

  \c$case_alt_41\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_25\ else
                     resize(x_19,24);

  result_selection_res_28 <= x_19 > to_signed(8388607,48);

  result_58 <= to_signed(8388607,24) when result_selection_res_28 else
               \c$case_alt_41\;

  result_selection_res_29 <= result_58 > to_signed(4194304,24);

  result_59 <= resize((to_signed(4194304,25) + \c$app_arg_82\),24) when result_selection_res_29 else
               \c$case_alt_42\;

  \c$case_alt_selection_res_26\ <= result_58 < to_signed(-4194304,24);

  \c$case_alt_42\ <= resize((to_signed(-4194304,25) + \c$app_arg_83\),24) when \c$case_alt_selection_res_26\ else
                     result_58;

  \c$shI_35\ <= (to_signed(2,64));

  capp_arg_82_shiftR : block
    signal sh_35 : natural;
  begin
    sh_35 <=
        -- pragma translate_off
        natural'high when (\c$shI_35\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_35\);
    \c$app_arg_82\ <= shift_right((\c$app_arg_84\ - to_signed(4194304,25)),sh_35)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$shI_36\ <= (to_signed(2,64));

  capp_arg_83_shiftR : block
    signal sh_36 : natural;
  begin
    sh_36 <=
        -- pragma translate_off
        natural'high when (\c$shI_36\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_36\);
    \c$app_arg_83\ <= shift_right((\c$app_arg_84\ + to_signed(4194304,25)),sh_36)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_84\ <= resize(result_58,25);

  \c$app_arg_85\ <= result_59 when \on_9\ else
                    x_21.Frame_sel0_fL;

  \c$shI_37\ <= (to_signed(10,64));

  capp_arg_86_shiftR : block
    signal sh_37 : natural;
  begin
    sh_37 <=
        -- pragma translate_off
        natural'high when (\c$shI_37\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_37\);
    \c$app_arg_86\ <= shift_right(x_21.Frame_sel30_fAcc2R,sh_37)
        -- pragma translate_off
        when ((to_signed(10,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_27\ <= \c$app_arg_86\ < to_signed(-8388608,48);

  \c$case_alt_43\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_27\ else
                     resize(\c$app_arg_86\,24);

  result_selection_res_30 <= \c$app_arg_86\ > to_signed(8388607,48);

  result_60 <= to_signed(8388607,24) when result_selection_res_30 else
               \c$case_alt_43\;

  \c$shI_38\ <= (to_signed(9,64));

  capp_arg_87_shiftR : block
    signal sh_38 : natural;
  begin
    sh_38 <=
        -- pragma translate_off
        natural'high when (\c$shI_38\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_38\);
    \c$app_arg_87\ <= shift_right(x_21.Frame_sel32_fAcc3R,sh_38)
        -- pragma translate_off
        when ((to_signed(9,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_28\ <= \c$app_arg_87\ < to_signed(-8388608,48);

  \c$case_alt_44\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_28\ else
                     resize(\c$app_arg_87\,24);

  result_selection_res_31 <= \c$app_arg_87\ > to_signed(8388607,48);

  result_61 <= to_signed(8388607,24) when result_selection_res_31 else
               \c$case_alt_44\;

  x_20 <= (x_21.Frame_sel28_fAccR + (resize(result_60,48))) + (resize(result_61,48));

  \c$case_alt_selection_res_29\ <= x_20 < to_signed(-8388608,48);

  \c$case_alt_45\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_29\ else
                     resize(x_20,24);

  result_selection_res_32 <= x_20 > to_signed(8388607,48);

  result_62 <= to_signed(8388607,24) when result_selection_res_32 else
               \c$case_alt_45\;

  result_selection_res_33 <= result_62 > to_signed(4194304,24);

  result_63 <= resize((to_signed(4194304,25) + \c$app_arg_88\),24) when result_selection_res_33 else
               \c$case_alt_46\;

  \c$case_alt_selection_res_30\ <= result_62 < to_signed(-4194304,24);

  \c$case_alt_46\ <= resize((to_signed(-4194304,25) + \c$app_arg_89\),24) when \c$case_alt_selection_res_30\ else
                     result_62;

  \c$shI_39\ <= (to_signed(2,64));

  capp_arg_88_shiftR : block
    signal sh_39 : natural;
  begin
    sh_39 <=
        -- pragma translate_off
        natural'high when (\c$shI_39\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_39\);
    \c$app_arg_88\ <= shift_right((\c$app_arg_90\ - to_signed(4194304,25)),sh_39)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$shI_40\ <= (to_signed(2,64));

  capp_arg_89_shiftR : block
    signal sh_40 : natural;
  begin
    sh_40 <=
        -- pragma translate_off
        natural'high when (\c$shI_40\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_40\);
    \c$app_arg_89\ <= shift_right((\c$app_arg_90\ + to_signed(4194304,25)),sh_40)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_90\ <= resize(result_62,25);

  \c$app_arg_91\ <= result_63 when \on_9\ else
                    x_21.Frame_sel1_fR;

  result_64 <= ( Frame_sel0_fL => x_21.Frame_sel0_fL
               , Frame_sel1_fR => x_21.Frame_sel1_fR
               , Frame_sel2_fLast => x_21.Frame_sel2_fLast
               , Frame_sel3_fGate => x_21.Frame_sel3_fGate
               , Frame_sel4_fOd => x_21.Frame_sel4_fOd
               , Frame_sel5_fDist => x_21.Frame_sel5_fDist
               , Frame_sel6_fEq => x_21.Frame_sel6_fEq
               , Frame_sel7_fRat => x_21.Frame_sel7_fRat
               , Frame_sel8_fAmp => x_21.Frame_sel8_fAmp
               , Frame_sel9_fAmpTone => x_21.Frame_sel9_fAmpTone
               , Frame_sel10_fCab => x_21.Frame_sel10_fCab
               , Frame_sel11_fReverb => x_21.Frame_sel11_fReverb
               , Frame_sel12_fAddr => x_21.Frame_sel12_fAddr
               , Frame_sel13_fDryL => x_21.Frame_sel13_fDryL
               , Frame_sel14_fDryR => x_21.Frame_sel14_fDryR
               , Frame_sel15_fWetL => \c$app_arg_85\
               , Frame_sel16_fWetR => \c$app_arg_91\
               , Frame_sel17_fFbL => x_21.Frame_sel17_fFbL
               , Frame_sel18_fFbR => x_21.Frame_sel18_fFbR
               , Frame_sel19_fEqLowL => x_21.Frame_sel19_fEqLowL
               , Frame_sel20_fEqLowR => x_21.Frame_sel20_fEqLowR
               , Frame_sel21_fEqMidL => x_21.Frame_sel21_fEqMidL
               , Frame_sel22_fEqMidR => x_21.Frame_sel22_fEqMidR
               , Frame_sel23_fEqHighL => x_21.Frame_sel23_fEqHighL
               , Frame_sel24_fEqHighR => x_21.Frame_sel24_fEqHighR
               , Frame_sel25_fEqHighLpL => x_21.Frame_sel25_fEqHighLpL
               , Frame_sel26_fEqHighLpR => x_21.Frame_sel26_fEqHighLpR
               , Frame_sel27_fAccL => x_21.Frame_sel27_fAccL
               , Frame_sel28_fAccR => x_21.Frame_sel28_fAccR
               , Frame_sel29_fAcc2L => x_21.Frame_sel29_fAcc2L
               , Frame_sel30_fAcc2R => x_21.Frame_sel30_fAcc2R
               , Frame_sel31_fAcc3L => x_21.Frame_sel31_fAcc3L
               , Frame_sel32_fAcc3R => x_21.Frame_sel32_fAcc3R );

  \c$bv_13\ <= (x_21.Frame_sel3_fGate);

  \on_9\ <= (\c$bv_13\(6 downto 6)) = std_logic_vector'("1");

  x_21 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_9(970 downto 0)));

  -- register begin
  ds1_9_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_9 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_9 <= result_65;
    end if;
  end process;
  -- register end

  with (ampResPresenceFilterPipe(971 downto 971)) select
    result_65 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(result_66.Frame_sel0_fL)
                  & std_logic_vector(result_66.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(result_66.Frame_sel2_fLast)
                  & result_66.Frame_sel3_fGate
                  & result_66.Frame_sel4_fOd
                  & result_66.Frame_sel5_fDist
                  & result_66.Frame_sel6_fEq
                  & result_66.Frame_sel7_fRat
                  & result_66.Frame_sel8_fAmp
                  & result_66.Frame_sel9_fAmpTone
                  & result_66.Frame_sel10_fCab
                  & result_66.Frame_sel11_fReverb
                  & std_logic_vector(result_66.Frame_sel12_fAddr)
                  & std_logic_vector(result_66.Frame_sel13_fDryL)
                  & std_logic_vector(result_66.Frame_sel14_fDryR)
                  & std_logic_vector(result_66.Frame_sel15_fWetL)
                  & std_logic_vector(result_66.Frame_sel16_fWetR)
                  & std_logic_vector(result_66.Frame_sel17_fFbL)
                  & std_logic_vector(result_66.Frame_sel18_fFbR)
                  & std_logic_vector(result_66.Frame_sel19_fEqLowL)
                  & std_logic_vector(result_66.Frame_sel20_fEqLowR)
                  & std_logic_vector(result_66.Frame_sel21_fEqMidL)
                  & std_logic_vector(result_66.Frame_sel22_fEqMidR)
                  & std_logic_vector(result_66.Frame_sel23_fEqHighL)
                  & std_logic_vector(result_66.Frame_sel24_fEqHighR)
                  & std_logic_vector(result_66.Frame_sel25_fEqHighLpL)
                  & std_logic_vector(result_66.Frame_sel26_fEqHighLpR)
                  & std_logic_vector(result_66.Frame_sel27_fAccL)
                  & std_logic_vector(result_66.Frame_sel28_fAccR)
                  & std_logic_vector(result_66.Frame_sel29_fAcc2L)
                  & std_logic_vector(result_66.Frame_sel30_fAcc2R)
                  & std_logic_vector(result_66.Frame_sel31_fAcc3L)
                  & std_logic_vector(result_66.Frame_sel32_fAcc3R)))) when others;

  result_66 <= ( Frame_sel0_fL => x_24.Frame_sel0_fL
               , Frame_sel1_fR => x_24.Frame_sel1_fR
               , Frame_sel2_fLast => x_24.Frame_sel2_fLast
               , Frame_sel3_fGate => x_24.Frame_sel3_fGate
               , Frame_sel4_fOd => x_24.Frame_sel4_fOd
               , Frame_sel5_fDist => x_24.Frame_sel5_fDist
               , Frame_sel6_fEq => x_24.Frame_sel6_fEq
               , Frame_sel7_fRat => x_24.Frame_sel7_fRat
               , Frame_sel8_fAmp => x_24.Frame_sel8_fAmp
               , Frame_sel9_fAmpTone => x_24.Frame_sel9_fAmpTone
               , Frame_sel10_fCab => x_24.Frame_sel10_fCab
               , Frame_sel11_fReverb => x_24.Frame_sel11_fReverb
               , Frame_sel12_fAddr => x_24.Frame_sel12_fAddr
               , Frame_sel13_fDryL => x_24.Frame_sel13_fDryL
               , Frame_sel14_fDryR => x_24.Frame_sel14_fDryR
               , Frame_sel15_fWetL => x_24.Frame_sel15_fWetL
               , Frame_sel16_fWetR => x_24.Frame_sel16_fWetR
               , Frame_sel17_fFbL => x_24.Frame_sel17_fFbL
               , Frame_sel18_fFbR => x_24.Frame_sel18_fFbR
               , Frame_sel19_fEqLowL => x_24.Frame_sel19_fEqLowL
               , Frame_sel20_fEqLowR => x_24.Frame_sel20_fEqLowR
               , Frame_sel21_fEqMidL => x_24.Frame_sel21_fEqMidL
               , Frame_sel22_fEqMidR => x_24.Frame_sel22_fEqMidR
               , Frame_sel23_fEqHighL => result_68
               , Frame_sel24_fEqHighR => result_67
               , Frame_sel25_fEqHighLpL => x_24.Frame_sel25_fEqHighLpL
               , Frame_sel26_fEqHighLpR => x_24.Frame_sel26_fEqHighLpR
               , Frame_sel27_fAccL => \c$app_arg_99\
               , Frame_sel28_fAccR => \c$app_arg_98\
               , Frame_sel29_fAcc2L => \c$app_arg_96\
               , Frame_sel30_fAcc2R => \c$app_arg_95\
               , Frame_sel31_fAcc3L => \c$app_arg_93\
               , Frame_sel32_fAcc3R => \c$app_arg_92\ );

  \c$app_arg_92\ <= resize((resize(result_67,48)) * \c$app_arg_94\, 48) when \on_10\ else
                    to_signed(0,48);

  x_22 <= \c$highR_app_arg\ - (resize(x_24.Frame_sel26_fEqHighLpR,48));

  \c$case_alt_selection_res_31\ <= x_22 < to_signed(-8388608,48);

  \c$case_alt_47\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_31\ else
                     resize(x_22,24);

  result_selection_res_34 <= x_22 > to_signed(8388607,48);

  result_67 <= to_signed(8388607,24) when result_selection_res_34 else
               \c$case_alt_47\;

  \c$app_arg_93\ <= resize((resize(result_68,48)) * \c$app_arg_94\, 48) when \on_10\ else
                    to_signed(0,48);

  \c$app_arg_94\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(presence)))))))),48);

  presence <= unsigned((\c$presence_app_arg\(23 downto 16)));

  x_23 <= \c$highL_app_arg\ - (resize(x_24.Frame_sel25_fEqHighLpL,48));

  \c$case_alt_selection_res_32\ <= x_23 < to_signed(-8388608,48);

  \c$case_alt_48\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_32\ else
                     resize(x_23,24);

  result_selection_res_35 <= x_23 > to_signed(8388607,48);

  result_68 <= to_signed(8388607,24) when result_selection_res_35 else
               \c$case_alt_48\;

  \c$app_arg_95\ <= resize((resize(x_24.Frame_sel20_fEqLowR,48)) * \c$app_arg_97\, 48) when \on_10\ else
                    to_signed(0,48);

  \c$app_arg_96\ <= resize((resize(x_24.Frame_sel19_fEqLowL,48)) * \c$app_arg_97\, 48) when \on_10\ else
                    to_signed(0,48);

  \c$app_arg_97\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(resonance)))))))),48);

  resonance <= unsigned((\c$presence_app_arg\(31 downto 24)));

  \c$app_arg_98\ <= \c$highR_app_arg\ when \on_10\ else
                    to_signed(0,48);

  \c$app_arg_99\ <= \c$highL_app_arg\ when \on_10\ else
                    to_signed(0,48);

  \c$bv_14\ <= (x_24.Frame_sel3_fGate);

  \on_10\ <= (\c$bv_14\(6 downto 6)) = std_logic_vector'("1");

  \c$presence_app_arg\ <= x_24.Frame_sel8_fAmp;

  \c$highL_app_arg\ <= resize(x_24.Frame_sel15_fWetL,48);

  \c$highR_app_arg\ <= resize(x_24.Frame_sel16_fWetR,48);

  -- register begin
  ampResPresenceFilterPipe_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ampResPresenceFilterPipe <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ampResPresenceFilterPipe <= result_69;
    end if;
  end process;
  -- register end

  with (ds1_10(971 downto 971)) select
    result_69 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(\c$case_alt_49\.Frame_sel0_fL)
                  & std_logic_vector(\c$case_alt_49\.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(\c$case_alt_49\.Frame_sel2_fLast)
                  & \c$case_alt_49\.Frame_sel3_fGate
                  & \c$case_alt_49\.Frame_sel4_fOd
                  & \c$case_alt_49\.Frame_sel5_fDist
                  & \c$case_alt_49\.Frame_sel6_fEq
                  & \c$case_alt_49\.Frame_sel7_fRat
                  & \c$case_alt_49\.Frame_sel8_fAmp
                  & \c$case_alt_49\.Frame_sel9_fAmpTone
                  & \c$case_alt_49\.Frame_sel10_fCab
                  & \c$case_alt_49\.Frame_sel11_fReverb
                  & std_logic_vector(\c$case_alt_49\.Frame_sel12_fAddr)
                  & std_logic_vector(\c$case_alt_49\.Frame_sel13_fDryL)
                  & std_logic_vector(\c$case_alt_49\.Frame_sel14_fDryR)
                  & std_logic_vector(\c$case_alt_49\.Frame_sel15_fWetL)
                  & std_logic_vector(\c$case_alt_49\.Frame_sel16_fWetR)
                  & std_logic_vector(\c$case_alt_49\.Frame_sel17_fFbL)
                  & std_logic_vector(\c$case_alt_49\.Frame_sel18_fFbR)
                  & std_logic_vector(\c$case_alt_49\.Frame_sel19_fEqLowL)
                  & std_logic_vector(\c$case_alt_49\.Frame_sel20_fEqLowR)
                  & std_logic_vector(\c$case_alt_49\.Frame_sel21_fEqMidL)
                  & std_logic_vector(\c$case_alt_49\.Frame_sel22_fEqMidR)
                  & std_logic_vector(\c$case_alt_49\.Frame_sel23_fEqHighL)
                  & std_logic_vector(\c$case_alt_49\.Frame_sel24_fEqHighR)
                  & std_logic_vector(\c$case_alt_49\.Frame_sel25_fEqHighLpL)
                  & std_logic_vector(\c$case_alt_49\.Frame_sel26_fEqHighLpR)
                  & std_logic_vector(\c$case_alt_49\.Frame_sel27_fAccL)
                  & std_logic_vector(\c$case_alt_49\.Frame_sel28_fAccR)
                  & std_logic_vector(\c$case_alt_49\.Frame_sel29_fAcc2L)
                  & std_logic_vector(\c$case_alt_49\.Frame_sel30_fAcc2R)
                  & std_logic_vector(\c$case_alt_49\.Frame_sel31_fAcc3L)
                  & std_logic_vector(\c$case_alt_49\.Frame_sel32_fAcc3R)))) when others;

  \c$case_alt_49\ <= ( Frame_sel0_fL => x_25.Frame_sel0_fL
                     , Frame_sel1_fR => x_25.Frame_sel1_fR
                     , Frame_sel2_fLast => x_25.Frame_sel2_fLast
                     , Frame_sel3_fGate => x_25.Frame_sel3_fGate
                     , Frame_sel4_fOd => x_25.Frame_sel4_fOd
                     , Frame_sel5_fDist => x_25.Frame_sel5_fDist
                     , Frame_sel6_fEq => x_25.Frame_sel6_fEq
                     , Frame_sel7_fRat => x_25.Frame_sel7_fRat
                     , Frame_sel8_fAmp => x_25.Frame_sel8_fAmp
                     , Frame_sel9_fAmpTone => x_25.Frame_sel9_fAmpTone
                     , Frame_sel10_fCab => x_25.Frame_sel10_fCab
                     , Frame_sel11_fReverb => x_25.Frame_sel11_fReverb
                     , Frame_sel12_fAddr => x_25.Frame_sel12_fAddr
                     , Frame_sel13_fDryL => x_25.Frame_sel13_fDryL
                     , Frame_sel14_fDryR => x_25.Frame_sel14_fDryR
                     , Frame_sel15_fWetL => x_25.Frame_sel15_fWetL
                     , Frame_sel16_fWetR => x_25.Frame_sel16_fWetR
                     , Frame_sel17_fFbL => x_25.Frame_sel17_fFbL
                     , Frame_sel18_fFbR => x_25.Frame_sel18_fFbR
                     , Frame_sel19_fEqLowL => ampResPrevL + (resize(\c$app_arg_104\,24))
                     , Frame_sel20_fEqLowR => ampResPrevR + (resize(\c$app_arg_102\,24))
                     , Frame_sel21_fEqMidL => x_25.Frame_sel21_fEqMidL
                     , Frame_sel22_fEqMidR => x_25.Frame_sel22_fEqMidR
                     , Frame_sel23_fEqHighL => x_25.Frame_sel23_fEqHighL
                     , Frame_sel24_fEqHighR => x_25.Frame_sel24_fEqHighR
                     , Frame_sel25_fEqHighLpL => ampPresencePrevL + (resize(\c$app_arg_101\,24))
                     , Frame_sel26_fEqHighLpR => ampPresencePrevR + (resize(\c$app_arg_100\,24))
                     , Frame_sel27_fAccL => x_25.Frame_sel27_fAccL
                     , Frame_sel28_fAccR => x_25.Frame_sel28_fAccR
                     , Frame_sel29_fAcc2L => x_25.Frame_sel29_fAcc2L
                     , Frame_sel30_fAcc2R => x_25.Frame_sel30_fAcc2R
                     , Frame_sel31_fAcc3L => x_25.Frame_sel31_fAcc3L
                     , Frame_sel32_fAcc3R => x_25.Frame_sel32_fAcc3R );

  \c$shI_41\ <= (to_signed(3,64));

  capp_arg_100_shiftR : block
    signal sh_41 : natural;
  begin
    sh_41 <=
        -- pragma translate_off
        natural'high when (\c$shI_41\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_41\);
    \c$app_arg_100\ <= shift_right((\c$app_arg_103\ - (resize(ampPresencePrevR,25))),sh_41)
        -- pragma translate_off
        when ((to_signed(3,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$shI_42\ <= (to_signed(3,64));

  capp_arg_101_shiftR : block
    signal sh_42 : natural;
  begin
    sh_42 <=
        -- pragma translate_off
        natural'high when (\c$shI_42\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_42\);
    \c$app_arg_101\ <= shift_right((\c$app_arg_105\ - (resize(ampPresencePrevL,25))),sh_42)
        -- pragma translate_off
        when ((to_signed(3,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$shI_43\ <= (to_signed(8,64));

  capp_arg_102_shiftR : block
    signal sh_43 : natural;
  begin
    sh_43 <=
        -- pragma translate_off
        natural'high when (\c$shI_43\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_43\);
    \c$app_arg_102\ <= shift_right((\c$app_arg_103\ - (resize(ampResPrevR,25))),sh_43)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_103\ <= resize(x_25.Frame_sel16_fWetR,25);

  \c$shI_44\ <= (to_signed(8,64));

  capp_arg_104_shiftR : block
    signal sh_44 : natural;
  begin
    sh_44 <=
        -- pragma translate_off
        natural'high when (\c$shI_44\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_44\);
    \c$app_arg_104\ <= shift_right((\c$app_arg_105\ - (resize(ampResPrevL,25))),sh_44)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_105\ <= resize(x_25.Frame_sel15_fWetL,25);

  -- register begin
  ampPresencePrevR_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ampPresencePrevR <= to_signed(0,24);
    elsif rising_edge(clk) then
      ampPresencePrevR <= \c$ampPresencePrevR_app_arg\;
    end if;
  end process;
  -- register end

  with (ampResPresenceFilterPipe(971 downto 971)) select
    \c$ampPresencePrevR_app_arg\ <= ampPresencePrevR when "0",
                                    x_24.Frame_sel26_fEqHighLpR when others;

  -- register begin
  ampPresencePrevL_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ampPresencePrevL <= to_signed(0,24);
    elsif rising_edge(clk) then
      ampPresencePrevL <= \c$ampPresencePrevL_app_arg\;
    end if;
  end process;
  -- register end

  with (ampResPresenceFilterPipe(971 downto 971)) select
    \c$ampPresencePrevL_app_arg\ <= ampPresencePrevL when "0",
                                    x_24.Frame_sel25_fEqHighLpL when others;

  -- register begin
  ampResPrevR_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ampResPrevR <= to_signed(0,24);
    elsif rising_edge(clk) then
      ampResPrevR <= \c$ampResPrevR_app_arg\;
    end if;
  end process;
  -- register end

  with (ampResPresenceFilterPipe(971 downto 971)) select
    \c$ampResPrevR_app_arg\ <= ampResPrevR when "0",
                               x_24.Frame_sel20_fEqLowR when others;

  -- register begin
  ampResPrevL_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ampResPrevL <= to_signed(0,24);
    elsif rising_edge(clk) then
      ampResPrevL <= \c$ampResPrevL_app_arg\;
    end if;
  end process;
  -- register end

  with (ampResPresenceFilterPipe(971 downto 971)) select
    \c$ampResPrevL_app_arg\ <= ampResPrevL when "0",
                               x_24.Frame_sel19_fEqLowL when others;

  x_24 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ampResPresenceFilterPipe(970 downto 0)));

  x_25 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_10(970 downto 0)));

  -- register begin
  ds1_10_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_10 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_10 <= result_70;
    end if;
  end process;
  -- register end

  with (ds1_11(971 downto 971)) select
    result_70 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(result_71.Frame_sel0_fL)
                  & std_logic_vector(result_71.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(result_71.Frame_sel2_fLast)
                  & result_71.Frame_sel3_fGate
                  & result_71.Frame_sel4_fOd
                  & result_71.Frame_sel5_fDist
                  & result_71.Frame_sel6_fEq
                  & result_71.Frame_sel7_fRat
                  & result_71.Frame_sel8_fAmp
                  & result_71.Frame_sel9_fAmpTone
                  & result_71.Frame_sel10_fCab
                  & result_71.Frame_sel11_fReverb
                  & std_logic_vector(result_71.Frame_sel12_fAddr)
                  & std_logic_vector(result_71.Frame_sel13_fDryL)
                  & std_logic_vector(result_71.Frame_sel14_fDryR)
                  & std_logic_vector(result_71.Frame_sel15_fWetL)
                  & std_logic_vector(result_71.Frame_sel16_fWetR)
                  & std_logic_vector(result_71.Frame_sel17_fFbL)
                  & std_logic_vector(result_71.Frame_sel18_fFbR)
                  & std_logic_vector(result_71.Frame_sel19_fEqLowL)
                  & std_logic_vector(result_71.Frame_sel20_fEqLowR)
                  & std_logic_vector(result_71.Frame_sel21_fEqMidL)
                  & std_logic_vector(result_71.Frame_sel22_fEqMidR)
                  & std_logic_vector(result_71.Frame_sel23_fEqHighL)
                  & std_logic_vector(result_71.Frame_sel24_fEqHighR)
                  & std_logic_vector(result_71.Frame_sel25_fEqHighLpL)
                  & std_logic_vector(result_71.Frame_sel26_fEqHighLpR)
                  & std_logic_vector(result_71.Frame_sel27_fAccL)
                  & std_logic_vector(result_71.Frame_sel28_fAccR)
                  & std_logic_vector(result_71.Frame_sel29_fAcc2L)
                  & std_logic_vector(result_71.Frame_sel30_fAcc2R)
                  & std_logic_vector(result_71.Frame_sel31_fAcc3L)
                  & std_logic_vector(result_71.Frame_sel32_fAcc3R)))) when others;

  \c$bv_15\ <= (x_26.Frame_sel3_fGate);

  \on_11\ <= (\c$bv_15\(6 downto 6)) = std_logic_vector'("1");

  result_71 <= ( Frame_sel0_fL => x_26.Frame_sel0_fL
               , Frame_sel1_fR => x_26.Frame_sel1_fR
               , Frame_sel2_fLast => x_26.Frame_sel2_fLast
               , Frame_sel3_fGate => x_26.Frame_sel3_fGate
               , Frame_sel4_fOd => x_26.Frame_sel4_fOd
               , Frame_sel5_fDist => x_26.Frame_sel5_fDist
               , Frame_sel6_fEq => x_26.Frame_sel6_fEq
               , Frame_sel7_fRat => x_26.Frame_sel7_fRat
               , Frame_sel8_fAmp => x_26.Frame_sel8_fAmp
               , Frame_sel9_fAmpTone => x_26.Frame_sel9_fAmpTone
               , Frame_sel10_fCab => x_26.Frame_sel10_fCab
               , Frame_sel11_fReverb => x_26.Frame_sel11_fReverb
               , Frame_sel12_fAddr => x_26.Frame_sel12_fAddr
               , Frame_sel13_fDryL => x_26.Frame_sel13_fDryL
               , Frame_sel14_fDryR => x_26.Frame_sel14_fDryR
               , Frame_sel15_fWetL => \c$app_arg_110\
               , Frame_sel16_fWetR => \c$app_arg_106\
               , Frame_sel17_fFbL => x_26.Frame_sel17_fFbL
               , Frame_sel18_fFbR => x_26.Frame_sel18_fFbR
               , Frame_sel19_fEqLowL => x_26.Frame_sel19_fEqLowL
               , Frame_sel20_fEqLowR => x_26.Frame_sel20_fEqLowR
               , Frame_sel21_fEqMidL => x_26.Frame_sel21_fEqMidL
               , Frame_sel22_fEqMidR => x_26.Frame_sel22_fEqMidR
               , Frame_sel23_fEqHighL => x_26.Frame_sel23_fEqHighL
               , Frame_sel24_fEqHighR => x_26.Frame_sel24_fEqHighR
               , Frame_sel25_fEqHighLpL => x_26.Frame_sel25_fEqHighLpL
               , Frame_sel26_fEqHighLpR => x_26.Frame_sel26_fEqHighLpR
               , Frame_sel27_fAccL => x_26.Frame_sel27_fAccL
               , Frame_sel28_fAccR => x_26.Frame_sel28_fAccR
               , Frame_sel29_fAcc2L => x_26.Frame_sel29_fAcc2L
               , Frame_sel30_fAcc2R => x_26.Frame_sel30_fAcc2R
               , Frame_sel31_fAcc3L => x_26.Frame_sel31_fAcc3L
               , Frame_sel32_fAcc3R => x_26.Frame_sel32_fAcc3R );

  \c$app_arg_106\ <= result_72 when \on_11\ else
                     x_26.Frame_sel1_fR;

  result_selection_res_36 <= x_26.Frame_sel16_fWetR > to_signed(4194304,24);

  result_72 <= resize((to_signed(4194304,25) + \c$app_arg_107\),24) when result_selection_res_36 else
               \c$case_alt_50\;

  \c$case_alt_selection_res_33\ <= x_26.Frame_sel16_fWetR < to_signed(-4194304,24);

  \c$case_alt_50\ <= resize((to_signed(-4194304,25) + \c$app_arg_108\),24) when \c$case_alt_selection_res_33\ else
                     x_26.Frame_sel16_fWetR;

  \c$shI_45\ <= (to_signed(2,64));

  capp_arg_107_shiftR : block
    signal sh_45 : natural;
  begin
    sh_45 <=
        -- pragma translate_off
        natural'high when (\c$shI_45\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_45\);
    \c$app_arg_107\ <= shift_right((\c$app_arg_109\ - to_signed(4194304,25)),sh_45)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$shI_46\ <= (to_signed(2,64));

  capp_arg_108_shiftR : block
    signal sh_46 : natural;
  begin
    sh_46 <=
        -- pragma translate_off
        natural'high when (\c$shI_46\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_46\);
    \c$app_arg_108\ <= shift_right((\c$app_arg_109\ + to_signed(4194304,25)),sh_46)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_109\ <= resize(x_26.Frame_sel16_fWetR,25);

  \c$app_arg_110\ <= result_73 when \on_11\ else
                     x_26.Frame_sel0_fL;

  result_selection_res_37 <= x_26.Frame_sel15_fWetL > to_signed(4194304,24);

  result_73 <= resize((to_signed(4194304,25) + \c$app_arg_111\),24) when result_selection_res_37 else
               \c$case_alt_51\;

  \c$case_alt_selection_res_34\ <= x_26.Frame_sel15_fWetL < to_signed(-4194304,24);

  \c$case_alt_51\ <= resize((to_signed(-4194304,25) + \c$app_arg_112\),24) when \c$case_alt_selection_res_34\ else
                     x_26.Frame_sel15_fWetL;

  \c$shI_47\ <= (to_signed(2,64));

  capp_arg_111_shiftR : block
    signal sh_47 : natural;
  begin
    sh_47 <=
        -- pragma translate_off
        natural'high when (\c$shI_47\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_47\);
    \c$app_arg_111\ <= shift_right((\c$app_arg_113\ - to_signed(4194304,25)),sh_47)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$shI_48\ <= (to_signed(2,64));

  capp_arg_112_shiftR : block
    signal sh_48 : natural;
  begin
    sh_48 <=
        -- pragma translate_off
        natural'high when (\c$shI_48\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_48\);
    \c$app_arg_112\ <= shift_right((\c$app_arg_113\ + to_signed(4194304,25)),sh_48)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_113\ <= resize(x_26.Frame_sel15_fWetL,25);

  x_26 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_11(970 downto 0)));

  -- register begin
  ds1_11_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_11 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_11 <= result_74;
    end if;
  end process;
  -- register end

  with (ds1_12(971 downto 971)) select
    result_74 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(result_77.Frame_sel0_fL)
                  & std_logic_vector(result_77.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(result_77.Frame_sel2_fLast)
                  & result_77.Frame_sel3_fGate
                  & result_77.Frame_sel4_fOd
                  & result_77.Frame_sel5_fDist
                  & result_77.Frame_sel6_fEq
                  & result_77.Frame_sel7_fRat
                  & result_77.Frame_sel8_fAmp
                  & result_77.Frame_sel9_fAmpTone
                  & result_77.Frame_sel10_fCab
                  & result_77.Frame_sel11_fReverb
                  & std_logic_vector(result_77.Frame_sel12_fAddr)
                  & std_logic_vector(result_77.Frame_sel13_fDryL)
                  & std_logic_vector(result_77.Frame_sel14_fDryR)
                  & std_logic_vector(result_77.Frame_sel15_fWetL)
                  & std_logic_vector(result_77.Frame_sel16_fWetR)
                  & std_logic_vector(result_77.Frame_sel17_fFbL)
                  & std_logic_vector(result_77.Frame_sel18_fFbR)
                  & std_logic_vector(result_77.Frame_sel19_fEqLowL)
                  & std_logic_vector(result_77.Frame_sel20_fEqLowR)
                  & std_logic_vector(result_77.Frame_sel21_fEqMidL)
                  & std_logic_vector(result_77.Frame_sel22_fEqMidR)
                  & std_logic_vector(result_77.Frame_sel23_fEqHighL)
                  & std_logic_vector(result_77.Frame_sel24_fEqHighR)
                  & std_logic_vector(result_77.Frame_sel25_fEqHighLpL)
                  & std_logic_vector(result_77.Frame_sel26_fEqHighLpR)
                  & std_logic_vector(result_77.Frame_sel27_fAccL)
                  & std_logic_vector(result_77.Frame_sel28_fAccR)
                  & std_logic_vector(result_77.Frame_sel29_fAcc2L)
                  & std_logic_vector(result_77.Frame_sel30_fAcc2R)
                  & std_logic_vector(result_77.Frame_sel31_fAcc3L)
                  & std_logic_vector(result_77.Frame_sel32_fAcc3R)))) when others;

  \c$shI_49\ <= (to_signed(7,64));

  capp_arg_114_shiftR : block
    signal sh_49 : natural;
  begin
    sh_49 <=
        -- pragma translate_off
        natural'high when (\c$shI_49\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_49\);
    \c$app_arg_114\ <= shift_right(((x_27.Frame_sel27_fAccL + x_27.Frame_sel29_fAcc2L) + x_27.Frame_sel31_fAcc3L),sh_49)
        -- pragma translate_off
        when ((to_signed(7,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_35\ <= \c$app_arg_114\ < to_signed(-8388608,48);

  \c$case_alt_52\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_35\ else
                     resize(\c$app_arg_114\,24);

  result_selection_res_38 <= \c$app_arg_114\ > to_signed(8388607,48);

  result_75 <= to_signed(8388607,24) when result_selection_res_38 else
               \c$case_alt_52\;

  \c$app_arg_115\ <= result_75 when \on_12\ else
                     x_27.Frame_sel0_fL;

  \c$shI_50\ <= (to_signed(7,64));

  capp_arg_116_shiftR : block
    signal sh_50 : natural;
  begin
    sh_50 <=
        -- pragma translate_off
        natural'high when (\c$shI_50\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_50\);
    \c$app_arg_116\ <= shift_right(((x_27.Frame_sel28_fAccR + x_27.Frame_sel30_fAcc2R) + x_27.Frame_sel32_fAcc3R),sh_50)
        -- pragma translate_off
        when ((to_signed(7,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_36\ <= \c$app_arg_116\ < to_signed(-8388608,48);

  \c$case_alt_53\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_36\ else
                     resize(\c$app_arg_116\,24);

  result_selection_res_39 <= \c$app_arg_116\ > to_signed(8388607,48);

  result_76 <= to_signed(8388607,24) when result_selection_res_39 else
               \c$case_alt_53\;

  \c$app_arg_117\ <= result_76 when \on_12\ else
                     x_27.Frame_sel1_fR;

  result_77 <= ( Frame_sel0_fL => x_27.Frame_sel0_fL
               , Frame_sel1_fR => x_27.Frame_sel1_fR
               , Frame_sel2_fLast => x_27.Frame_sel2_fLast
               , Frame_sel3_fGate => x_27.Frame_sel3_fGate
               , Frame_sel4_fOd => x_27.Frame_sel4_fOd
               , Frame_sel5_fDist => x_27.Frame_sel5_fDist
               , Frame_sel6_fEq => x_27.Frame_sel6_fEq
               , Frame_sel7_fRat => x_27.Frame_sel7_fRat
               , Frame_sel8_fAmp => x_27.Frame_sel8_fAmp
               , Frame_sel9_fAmpTone => x_27.Frame_sel9_fAmpTone
               , Frame_sel10_fCab => x_27.Frame_sel10_fCab
               , Frame_sel11_fReverb => x_27.Frame_sel11_fReverb
               , Frame_sel12_fAddr => x_27.Frame_sel12_fAddr
               , Frame_sel13_fDryL => x_27.Frame_sel13_fDryL
               , Frame_sel14_fDryR => x_27.Frame_sel14_fDryR
               , Frame_sel15_fWetL => \c$app_arg_115\
               , Frame_sel16_fWetR => \c$app_arg_117\
               , Frame_sel17_fFbL => x_27.Frame_sel17_fFbL
               , Frame_sel18_fFbR => x_27.Frame_sel18_fFbR
               , Frame_sel19_fEqLowL => x_27.Frame_sel19_fEqLowL
               , Frame_sel20_fEqLowR => x_27.Frame_sel20_fEqLowR
               , Frame_sel21_fEqMidL => x_27.Frame_sel21_fEqMidL
               , Frame_sel22_fEqMidR => x_27.Frame_sel22_fEqMidR
               , Frame_sel23_fEqHighL => x_27.Frame_sel23_fEqHighL
               , Frame_sel24_fEqHighR => x_27.Frame_sel24_fEqHighR
               , Frame_sel25_fEqHighLpL => x_27.Frame_sel25_fEqHighLpL
               , Frame_sel26_fEqHighLpR => x_27.Frame_sel26_fEqHighLpR
               , Frame_sel27_fAccL => x_27.Frame_sel27_fAccL
               , Frame_sel28_fAccR => x_27.Frame_sel28_fAccR
               , Frame_sel29_fAcc2L => x_27.Frame_sel29_fAcc2L
               , Frame_sel30_fAcc2R => x_27.Frame_sel30_fAcc2R
               , Frame_sel31_fAcc3L => x_27.Frame_sel31_fAcc3L
               , Frame_sel32_fAcc3R => x_27.Frame_sel32_fAcc3R );

  \c$bv_16\ <= (x_27.Frame_sel3_fGate);

  \on_12\ <= (\c$bv_16\(6 downto 6)) = std_logic_vector'("1");

  x_27 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_12(970 downto 0)));

  -- register begin
  ds1_12_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_12 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_12 <= result_78;
    end if;
  end process;
  -- register end

  with (ds1_13(971 downto 971)) select
    result_78 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(result_79.Frame_sel0_fL)
                  & std_logic_vector(result_79.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(result_79.Frame_sel2_fLast)
                  & result_79.Frame_sel3_fGate
                  & result_79.Frame_sel4_fOd
                  & result_79.Frame_sel5_fDist
                  & result_79.Frame_sel6_fEq
                  & result_79.Frame_sel7_fRat
                  & result_79.Frame_sel8_fAmp
                  & result_79.Frame_sel9_fAmpTone
                  & result_79.Frame_sel10_fCab
                  & result_79.Frame_sel11_fReverb
                  & std_logic_vector(result_79.Frame_sel12_fAddr)
                  & std_logic_vector(result_79.Frame_sel13_fDryL)
                  & std_logic_vector(result_79.Frame_sel14_fDryR)
                  & std_logic_vector(result_79.Frame_sel15_fWetL)
                  & std_logic_vector(result_79.Frame_sel16_fWetR)
                  & std_logic_vector(result_79.Frame_sel17_fFbL)
                  & std_logic_vector(result_79.Frame_sel18_fFbR)
                  & std_logic_vector(result_79.Frame_sel19_fEqLowL)
                  & std_logic_vector(result_79.Frame_sel20_fEqLowR)
                  & std_logic_vector(result_79.Frame_sel21_fEqMidL)
                  & std_logic_vector(result_79.Frame_sel22_fEqMidR)
                  & std_logic_vector(result_79.Frame_sel23_fEqHighL)
                  & std_logic_vector(result_79.Frame_sel24_fEqHighR)
                  & std_logic_vector(result_79.Frame_sel25_fEqHighLpL)
                  & std_logic_vector(result_79.Frame_sel26_fEqHighLpR)
                  & std_logic_vector(result_79.Frame_sel27_fAccL)
                  & std_logic_vector(result_79.Frame_sel28_fAccR)
                  & std_logic_vector(result_79.Frame_sel29_fAcc2L)
                  & std_logic_vector(result_79.Frame_sel30_fAcc2R)
                  & std_logic_vector(result_79.Frame_sel31_fAcc3L)
                  & std_logic_vector(result_79.Frame_sel32_fAcc3R)))) when others;

  result_79 <= ( Frame_sel0_fL => x_31.Frame_sel0_fL
               , Frame_sel1_fR => x_31.Frame_sel1_fR
               , Frame_sel2_fLast => x_31.Frame_sel2_fLast
               , Frame_sel3_fGate => x_31.Frame_sel3_fGate
               , Frame_sel4_fOd => x_31.Frame_sel4_fOd
               , Frame_sel5_fDist => x_31.Frame_sel5_fDist
               , Frame_sel6_fEq => x_31.Frame_sel6_fEq
               , Frame_sel7_fRat => x_31.Frame_sel7_fRat
               , Frame_sel8_fAmp => x_31.Frame_sel8_fAmp
               , Frame_sel9_fAmpTone => x_31.Frame_sel9_fAmpTone
               , Frame_sel10_fCab => x_31.Frame_sel10_fCab
               , Frame_sel11_fReverb => x_31.Frame_sel11_fReverb
               , Frame_sel12_fAddr => x_31.Frame_sel12_fAddr
               , Frame_sel13_fDryL => x_31.Frame_sel13_fDryL
               , Frame_sel14_fDryR => x_31.Frame_sel14_fDryR
               , Frame_sel15_fWetL => x_31.Frame_sel15_fWetL
               , Frame_sel16_fWetR => x_31.Frame_sel16_fWetR
               , Frame_sel17_fFbL => x_31.Frame_sel17_fFbL
               , Frame_sel18_fFbR => x_31.Frame_sel18_fFbR
               , Frame_sel19_fEqLowL => x_31.Frame_sel19_fEqLowL
               , Frame_sel20_fEqLowR => x_31.Frame_sel20_fEqLowR
               , Frame_sel21_fEqMidL => x_31.Frame_sel21_fEqMidL
               , Frame_sel22_fEqMidR => x_31.Frame_sel22_fEqMidR
               , Frame_sel23_fEqHighL => x_31.Frame_sel23_fEqHighL
               , Frame_sel24_fEqHighR => x_31.Frame_sel24_fEqHighR
               , Frame_sel25_fEqHighLpL => x_31.Frame_sel25_fEqHighLpL
               , Frame_sel26_fEqHighLpR => x_31.Frame_sel26_fEqHighLpR
               , Frame_sel27_fAccL => \c$app_arg_125\
               , Frame_sel28_fAccR => \c$app_arg_124\
               , Frame_sel29_fAcc2L => \c$app_arg_122\
               , Frame_sel30_fAcc2R => \c$app_arg_121\
               , Frame_sel31_fAcc3L => \c$app_arg_119\
               , Frame_sel32_fAcc3R => \c$app_arg_118\ );

  \c$app_arg_118\ <= resize((resize(x_31.Frame_sel24_fEqHighR,48)) * \c$app_arg_120\, 48) when \on_13\ else
                     to_signed(0,48);

  \c$app_arg_119\ <= resize((resize(x_31.Frame_sel23_fEqHighL,48)) * \c$app_arg_120\, 48) when \on_13\ else
                     to_signed(0,48);

  \c$app_arg_120\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector((to_unsigned(64,8) + \c$gain_app_arg_0\))))))))),48);

  \c$shI_51\ <= (to_signed(1,64));

  cgain_app_arg_0_shiftL : block
    signal sh_51 : natural;
  begin
    sh_51 <=
        -- pragma translate_off
        natural'high when (\c$shI_51\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_51\);
    \c$gain_app_arg_0\ <= shift_right(x_28,sh_51)
        -- pragma translate_off
        when ((to_signed(1,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  x_28 <= unsigned((\c$x_app_arg_2\(23 downto 16)));

  \c$app_arg_121\ <= resize((resize(x_31.Frame_sel22_fEqMidR,48)) * \c$app_arg_123\, 48) when \on_13\ else
                     to_signed(0,48);

  \c$app_arg_122\ <= resize((resize(x_31.Frame_sel21_fEqMidL,48)) * \c$app_arg_123\, 48) when \on_13\ else
                     to_signed(0,48);

  \c$app_arg_123\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector((to_unsigned(64,8) + \c$gain_app_arg_1\))))))))),48);

  \c$shI_52\ <= (to_signed(1,64));

  cgain_app_arg_1_shiftL : block
    signal sh_52 : natural;
  begin
    sh_52 <=
        -- pragma translate_off
        natural'high when (\c$shI_52\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_52\);
    \c$gain_app_arg_1\ <= shift_right(x_29,sh_52)
        -- pragma translate_off
        when ((to_signed(1,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  x_29 <= unsigned((\c$x_app_arg_2\(15 downto 8)));

  \c$app_arg_124\ <= resize((resize(x_31.Frame_sel20_fEqLowR,48)) * \c$app_arg_126\, 48) when \on_13\ else
                     to_signed(0,48);

  \c$app_arg_125\ <= resize((resize(x_31.Frame_sel19_fEqLowL,48)) * \c$app_arg_126\, 48) when \on_13\ else
                     to_signed(0,48);

  \c$bv_17\ <= (x_31.Frame_sel3_fGate);

  \on_13\ <= (\c$bv_17\(6 downto 6)) = std_logic_vector'("1");

  \c$app_arg_126\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector((to_unsigned(64,8) + \c$gain_app_arg_2\))))))))),48);

  \c$shI_53\ <= (to_signed(1,64));

  cgain_app_arg_2_shiftL : block
    signal sh_53 : natural;
  begin
    sh_53 <=
        -- pragma translate_off
        natural'high when (\c$shI_53\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_53\);
    \c$gain_app_arg_2\ <= shift_right(x_30,sh_53)
        -- pragma translate_off
        when ((to_signed(1,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  x_30 <= unsigned((\c$x_app_arg_2\(7 downto 0)));

  \c$x_app_arg_2\ <= x_31.Frame_sel9_fAmpTone;

  x_31 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_13(970 downto 0)));

  -- register begin
  ds1_13_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_13 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_13 <= result_80;
    end if;
  end process;
  -- register end

  with (ampToneFilterPipe(971 downto 971)) select
    result_80 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(\c$case_alt_54\.Frame_sel0_fL)
                  & std_logic_vector(\c$case_alt_54\.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(\c$case_alt_54\.Frame_sel2_fLast)
                  & \c$case_alt_54\.Frame_sel3_fGate
                  & \c$case_alt_54\.Frame_sel4_fOd
                  & \c$case_alt_54\.Frame_sel5_fDist
                  & \c$case_alt_54\.Frame_sel6_fEq
                  & \c$case_alt_54\.Frame_sel7_fRat
                  & \c$case_alt_54\.Frame_sel8_fAmp
                  & \c$case_alt_54\.Frame_sel9_fAmpTone
                  & \c$case_alt_54\.Frame_sel10_fCab
                  & \c$case_alt_54\.Frame_sel11_fReverb
                  & std_logic_vector(\c$case_alt_54\.Frame_sel12_fAddr)
                  & std_logic_vector(\c$case_alt_54\.Frame_sel13_fDryL)
                  & std_logic_vector(\c$case_alt_54\.Frame_sel14_fDryR)
                  & std_logic_vector(\c$case_alt_54\.Frame_sel15_fWetL)
                  & std_logic_vector(\c$case_alt_54\.Frame_sel16_fWetR)
                  & std_logic_vector(\c$case_alt_54\.Frame_sel17_fFbL)
                  & std_logic_vector(\c$case_alt_54\.Frame_sel18_fFbR)
                  & std_logic_vector(\c$case_alt_54\.Frame_sel19_fEqLowL)
                  & std_logic_vector(\c$case_alt_54\.Frame_sel20_fEqLowR)
                  & std_logic_vector(\c$case_alt_54\.Frame_sel21_fEqMidL)
                  & std_logic_vector(\c$case_alt_54\.Frame_sel22_fEqMidR)
                  & std_logic_vector(\c$case_alt_54\.Frame_sel23_fEqHighL)
                  & std_logic_vector(\c$case_alt_54\.Frame_sel24_fEqHighR)
                  & std_logic_vector(\c$case_alt_54\.Frame_sel25_fEqHighLpL)
                  & std_logic_vector(\c$case_alt_54\.Frame_sel26_fEqHighLpR)
                  & std_logic_vector(\c$case_alt_54\.Frame_sel27_fAccL)
                  & std_logic_vector(\c$case_alt_54\.Frame_sel28_fAccR)
                  & std_logic_vector(\c$case_alt_54\.Frame_sel29_fAcc2L)
                  & std_logic_vector(\c$case_alt_54\.Frame_sel30_fAcc2R)
                  & std_logic_vector(\c$case_alt_54\.Frame_sel31_fAcc3L)
                  & std_logic_vector(\c$case_alt_54\.Frame_sel32_fAcc3R)))) when others;

  \c$case_alt_54\ <= ( Frame_sel0_fL => x_36.Frame_sel0_fL
                     , Frame_sel1_fR => x_36.Frame_sel1_fR
                     , Frame_sel2_fLast => x_36.Frame_sel2_fLast
                     , Frame_sel3_fGate => x_36.Frame_sel3_fGate
                     , Frame_sel4_fOd => x_36.Frame_sel4_fOd
                     , Frame_sel5_fDist => x_36.Frame_sel5_fDist
                     , Frame_sel6_fEq => x_36.Frame_sel6_fEq
                     , Frame_sel7_fRat => x_36.Frame_sel7_fRat
                     , Frame_sel8_fAmp => x_36.Frame_sel8_fAmp
                     , Frame_sel9_fAmpTone => x_36.Frame_sel9_fAmpTone
                     , Frame_sel10_fCab => x_36.Frame_sel10_fCab
                     , Frame_sel11_fReverb => x_36.Frame_sel11_fReverb
                     , Frame_sel12_fAddr => x_36.Frame_sel12_fAddr
                     , Frame_sel13_fDryL => x_36.Frame_sel13_fDryL
                     , Frame_sel14_fDryR => x_36.Frame_sel14_fDryR
                     , Frame_sel15_fWetL => x_36.Frame_sel15_fWetL
                     , Frame_sel16_fWetR => x_36.Frame_sel16_fWetR
                     , Frame_sel17_fFbL => x_36.Frame_sel17_fFbL
                     , Frame_sel18_fFbR => x_36.Frame_sel18_fFbR
                     , Frame_sel19_fEqLowL => x_36.Frame_sel19_fEqLowL
                     , Frame_sel20_fEqLowR => x_36.Frame_sel20_fEqLowR
                     , Frame_sel21_fEqMidL => result_84
                     , Frame_sel22_fEqMidR => result_83
                     , Frame_sel23_fEqHighL => result_82
                     , Frame_sel24_fEqHighR => result_81
                     , Frame_sel25_fEqHighLpL => x_36.Frame_sel25_fEqHighLpL
                     , Frame_sel26_fEqHighLpR => x_36.Frame_sel26_fEqHighLpR
                     , Frame_sel27_fAccL => x_36.Frame_sel27_fAccL
                     , Frame_sel28_fAccR => x_36.Frame_sel28_fAccR
                     , Frame_sel29_fAcc2L => x_36.Frame_sel29_fAcc2L
                     , Frame_sel30_fAcc2R => x_36.Frame_sel30_fAcc2R
                     , Frame_sel31_fAcc3L => x_36.Frame_sel31_fAcc3L
                     , Frame_sel32_fAcc3R => x_36.Frame_sel32_fAcc3R );

  x_32 <= (resize(x_36.Frame_sel16_fWetR,48)) - \c$app_arg_127\;

  \c$case_alt_selection_res_37\ <= x_32 < to_signed(-8388608,48);

  \c$case_alt_55\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_37\ else
                     resize(x_32,24);

  result_selection_res_40 <= x_32 > to_signed(8388607,48);

  result_81 <= to_signed(8388607,24) when result_selection_res_40 else
               \c$case_alt_55\;

  x_33 <= (resize(x_36.Frame_sel15_fWetL,48)) - \c$app_arg_128\;

  \c$case_alt_selection_res_38\ <= x_33 < to_signed(-8388608,48);

  \c$case_alt_56\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_38\ else
                     resize(x_33,24);

  result_selection_res_41 <= x_33 > to_signed(8388607,48);

  result_82 <= to_signed(8388607,24) when result_selection_res_41 else
               \c$case_alt_56\;

  x_34 <= \c$app_arg_127\ - (resize(x_36.Frame_sel20_fEqLowR,48));

  \c$case_alt_selection_res_39\ <= x_34 < to_signed(-8388608,48);

  \c$case_alt_57\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_39\ else
                     resize(x_34,24);

  result_selection_res_42 <= x_34 > to_signed(8388607,48);

  result_83 <= to_signed(8388607,24) when result_selection_res_42 else
               \c$case_alt_57\;

  \c$app_arg_127\ <= resize(x_36.Frame_sel26_fEqHighLpR,48);

  x_35 <= \c$app_arg_128\ - (resize(x_36.Frame_sel19_fEqLowL,48));

  \c$case_alt_selection_res_40\ <= x_35 < to_signed(-8388608,48);

  \c$case_alt_58\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_40\ else
                     resize(x_35,24);

  result_selection_res_43 <= x_35 > to_signed(8388607,48);

  result_84 <= to_signed(8388607,24) when result_selection_res_43 else
               \c$case_alt_58\;

  \c$app_arg_128\ <= resize(x_36.Frame_sel25_fEqHighLpL,48);

  -- register begin
  ampToneFilterPipe_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ampToneFilterPipe <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ampToneFilterPipe <= result_85;
    end if;
  end process;
  -- register end

  with (ds1_14(971 downto 971)) select
    result_85 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(\c$case_alt_59\.Frame_sel0_fL)
                  & std_logic_vector(\c$case_alt_59\.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(\c$case_alt_59\.Frame_sel2_fLast)
                  & \c$case_alt_59\.Frame_sel3_fGate
                  & \c$case_alt_59\.Frame_sel4_fOd
                  & \c$case_alt_59\.Frame_sel5_fDist
                  & \c$case_alt_59\.Frame_sel6_fEq
                  & \c$case_alt_59\.Frame_sel7_fRat
                  & \c$case_alt_59\.Frame_sel8_fAmp
                  & \c$case_alt_59\.Frame_sel9_fAmpTone
                  & \c$case_alt_59\.Frame_sel10_fCab
                  & \c$case_alt_59\.Frame_sel11_fReverb
                  & std_logic_vector(\c$case_alt_59\.Frame_sel12_fAddr)
                  & std_logic_vector(\c$case_alt_59\.Frame_sel13_fDryL)
                  & std_logic_vector(\c$case_alt_59\.Frame_sel14_fDryR)
                  & std_logic_vector(\c$case_alt_59\.Frame_sel15_fWetL)
                  & std_logic_vector(\c$case_alt_59\.Frame_sel16_fWetR)
                  & std_logic_vector(\c$case_alt_59\.Frame_sel17_fFbL)
                  & std_logic_vector(\c$case_alt_59\.Frame_sel18_fFbR)
                  & std_logic_vector(\c$case_alt_59\.Frame_sel19_fEqLowL)
                  & std_logic_vector(\c$case_alt_59\.Frame_sel20_fEqLowR)
                  & std_logic_vector(\c$case_alt_59\.Frame_sel21_fEqMidL)
                  & std_logic_vector(\c$case_alt_59\.Frame_sel22_fEqMidR)
                  & std_logic_vector(\c$case_alt_59\.Frame_sel23_fEqHighL)
                  & std_logic_vector(\c$case_alt_59\.Frame_sel24_fEqHighR)
                  & std_logic_vector(\c$case_alt_59\.Frame_sel25_fEqHighLpL)
                  & std_logic_vector(\c$case_alt_59\.Frame_sel26_fEqHighLpR)
                  & std_logic_vector(\c$case_alt_59\.Frame_sel27_fAccL)
                  & std_logic_vector(\c$case_alt_59\.Frame_sel28_fAccR)
                  & std_logic_vector(\c$case_alt_59\.Frame_sel29_fAcc2L)
                  & std_logic_vector(\c$case_alt_59\.Frame_sel30_fAcc2R)
                  & std_logic_vector(\c$case_alt_59\.Frame_sel31_fAcc3L)
                  & std_logic_vector(\c$case_alt_59\.Frame_sel32_fAcc3R)))) when others;

  \c$case_alt_59\ <= ( Frame_sel0_fL => x_37.Frame_sel0_fL
                     , Frame_sel1_fR => x_37.Frame_sel1_fR
                     , Frame_sel2_fLast => x_37.Frame_sel2_fLast
                     , Frame_sel3_fGate => x_37.Frame_sel3_fGate
                     , Frame_sel4_fOd => x_37.Frame_sel4_fOd
                     , Frame_sel5_fDist => x_37.Frame_sel5_fDist
                     , Frame_sel6_fEq => x_37.Frame_sel6_fEq
                     , Frame_sel7_fRat => x_37.Frame_sel7_fRat
                     , Frame_sel8_fAmp => x_37.Frame_sel8_fAmp
                     , Frame_sel9_fAmpTone => x_37.Frame_sel9_fAmpTone
                     , Frame_sel10_fCab => x_37.Frame_sel10_fCab
                     , Frame_sel11_fReverb => x_37.Frame_sel11_fReverb
                     , Frame_sel12_fAddr => x_37.Frame_sel12_fAddr
                     , Frame_sel13_fDryL => x_37.Frame_sel13_fDryL
                     , Frame_sel14_fDryR => x_37.Frame_sel14_fDryR
                     , Frame_sel15_fWetL => x_37.Frame_sel15_fWetL
                     , Frame_sel16_fWetR => x_37.Frame_sel16_fWetR
                     , Frame_sel17_fFbL => x_37.Frame_sel17_fFbL
                     , Frame_sel18_fFbR => x_37.Frame_sel18_fFbR
                     , Frame_sel19_fEqLowL => ampToneLowPrevL + (resize(\c$app_arg_133\,24))
                     , Frame_sel20_fEqLowR => ampToneLowPrevR + (resize(\c$app_arg_131\,24))
                     , Frame_sel21_fEqMidL => x_37.Frame_sel21_fEqMidL
                     , Frame_sel22_fEqMidR => x_37.Frame_sel22_fEqMidR
                     , Frame_sel23_fEqHighL => x_37.Frame_sel23_fEqHighL
                     , Frame_sel24_fEqHighR => x_37.Frame_sel24_fEqHighR
                     , Frame_sel25_fEqHighLpL => ampToneHighPrevL + (resize(\c$app_arg_130\,24))
                     , Frame_sel26_fEqHighLpR => ampToneHighPrevR + (resize(\c$app_arg_129\,24))
                     , Frame_sel27_fAccL => x_37.Frame_sel27_fAccL
                     , Frame_sel28_fAccR => x_37.Frame_sel28_fAccR
                     , Frame_sel29_fAcc2L => x_37.Frame_sel29_fAcc2L
                     , Frame_sel30_fAcc2R => x_37.Frame_sel30_fAcc2R
                     , Frame_sel31_fAcc3L => x_37.Frame_sel31_fAcc3L
                     , Frame_sel32_fAcc3R => x_37.Frame_sel32_fAcc3R );

  \c$shI_54\ <= (to_signed(2,64));

  capp_arg_129_shiftR : block
    signal sh_54 : natural;
  begin
    sh_54 <=
        -- pragma translate_off
        natural'high when (\c$shI_54\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_54\);
    \c$app_arg_129\ <= shift_right((\c$app_arg_132\ - (resize(ampToneHighPrevR,25))),sh_54)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$shI_55\ <= (to_signed(2,64));

  capp_arg_130_shiftR : block
    signal sh_55 : natural;
  begin
    sh_55 <=
        -- pragma translate_off
        natural'high when (\c$shI_55\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_55\);
    \c$app_arg_130\ <= shift_right((\c$app_arg_134\ - (resize(ampToneHighPrevL,25))),sh_55)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$shI_56\ <= (to_signed(5,64));

  capp_arg_131_shiftR : block
    signal sh_56 : natural;
  begin
    sh_56 <=
        -- pragma translate_off
        natural'high when (\c$shI_56\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_56\);
    \c$app_arg_131\ <= shift_right((\c$app_arg_132\ - (resize(ampToneLowPrevR,25))),sh_56)
        -- pragma translate_off
        when ((to_signed(5,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_132\ <= resize(x_37.Frame_sel16_fWetR,25);

  \c$shI_57\ <= (to_signed(5,64));

  capp_arg_133_shiftR : block
    signal sh_57 : natural;
  begin
    sh_57 <=
        -- pragma translate_off
        natural'high when (\c$shI_57\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_57\);
    \c$app_arg_133\ <= shift_right((\c$app_arg_134\ - (resize(ampToneLowPrevL,25))),sh_57)
        -- pragma translate_off
        when ((to_signed(5,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_134\ <= resize(x_37.Frame_sel15_fWetL,25);

  -- register begin
  ampToneHighPrevR_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ampToneHighPrevR <= to_signed(0,24);
    elsif rising_edge(clk) then
      ampToneHighPrevR <= \c$ampToneHighPrevR_app_arg\;
    end if;
  end process;
  -- register end

  with (ampToneFilterPipe(971 downto 971)) select
    \c$ampToneHighPrevR_app_arg\ <= ampToneHighPrevR when "0",
                                    x_36.Frame_sel26_fEqHighLpR when others;

  -- register begin
  ampToneHighPrevL_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ampToneHighPrevL <= to_signed(0,24);
    elsif rising_edge(clk) then
      ampToneHighPrevL <= \c$ampToneHighPrevL_app_arg\;
    end if;
  end process;
  -- register end

  with (ampToneFilterPipe(971 downto 971)) select
    \c$ampToneHighPrevL_app_arg\ <= ampToneHighPrevL when "0",
                                    x_36.Frame_sel25_fEqHighLpL when others;

  -- register begin
  ampToneLowPrevR_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ampToneLowPrevR <= to_signed(0,24);
    elsif rising_edge(clk) then
      ampToneLowPrevR <= \c$ampToneLowPrevR_app_arg\;
    end if;
  end process;
  -- register end

  with (ampToneFilterPipe(971 downto 971)) select
    \c$ampToneLowPrevR_app_arg\ <= ampToneLowPrevR when "0",
                                   x_36.Frame_sel20_fEqLowR when others;

  -- register begin
  ampToneLowPrevL_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ampToneLowPrevL <= to_signed(0,24);
    elsif rising_edge(clk) then
      ampToneLowPrevL <= \c$ampToneLowPrevL_app_arg\;
    end if;
  end process;
  -- register end

  with (ampToneFilterPipe(971 downto 971)) select
    \c$ampToneLowPrevL_app_arg\ <= ampToneLowPrevL when "0",
                                   x_36.Frame_sel19_fEqLowL when others;

  x_36 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ampToneFilterPipe(970 downto 0)));

  x_37 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_14(970 downto 0)));

  -- register begin
  ds1_14_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_14 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_14 <= result_86;
    end if;
  end process;
  -- register end

  with (ds1_15(971 downto 971)) select
    result_86 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(result_95.Frame_sel0_fL)
                  & std_logic_vector(result_95.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(result_95.Frame_sel2_fLast)
                  & result_95.Frame_sel3_fGate
                  & result_95.Frame_sel4_fOd
                  & result_95.Frame_sel5_fDist
                  & result_95.Frame_sel6_fEq
                  & result_95.Frame_sel7_fRat
                  & result_95.Frame_sel8_fAmp
                  & result_95.Frame_sel9_fAmpTone
                  & result_95.Frame_sel10_fCab
                  & result_95.Frame_sel11_fReverb
                  & std_logic_vector(result_95.Frame_sel12_fAddr)
                  & std_logic_vector(result_95.Frame_sel13_fDryL)
                  & std_logic_vector(result_95.Frame_sel14_fDryR)
                  & std_logic_vector(result_95.Frame_sel15_fWetL)
                  & std_logic_vector(result_95.Frame_sel16_fWetR)
                  & std_logic_vector(result_95.Frame_sel17_fFbL)
                  & std_logic_vector(result_95.Frame_sel18_fFbR)
                  & std_logic_vector(result_95.Frame_sel19_fEqLowL)
                  & std_logic_vector(result_95.Frame_sel20_fEqLowR)
                  & std_logic_vector(result_95.Frame_sel21_fEqMidL)
                  & std_logic_vector(result_95.Frame_sel22_fEqMidR)
                  & std_logic_vector(result_95.Frame_sel23_fEqHighL)
                  & std_logic_vector(result_95.Frame_sel24_fEqHighR)
                  & std_logic_vector(result_95.Frame_sel25_fEqHighLpL)
                  & std_logic_vector(result_95.Frame_sel26_fEqHighLpR)
                  & std_logic_vector(result_95.Frame_sel27_fAccL)
                  & std_logic_vector(result_95.Frame_sel28_fAccR)
                  & std_logic_vector(result_95.Frame_sel29_fAcc2L)
                  & std_logic_vector(result_95.Frame_sel30_fAcc2R)
                  & std_logic_vector(result_95.Frame_sel31_fAcc3L)
                  & std_logic_vector(result_95.Frame_sel32_fAcc3R)))) when others;

  \c$shI_58\ <= (to_signed(7,64));

  capp_arg_135_shiftR : block
    signal sh_58 : natural;
  begin
    sh_58 <=
        -- pragma translate_off
        natural'high when (\c$shI_58\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_58\);
    \c$app_arg_135\ <= shift_right(x_38.Frame_sel27_fAccL,sh_58)
        -- pragma translate_off
        when ((to_signed(7,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_41\ <= \c$app_arg_135\ < to_signed(-8388608,48);

  \c$case_alt_60\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_41\ else
                     resize(\c$app_arg_135\,24);

  result_selection_res_44 <= \c$app_arg_135\ > to_signed(8388607,48);

  result_87 <= to_signed(8388607,24) when result_selection_res_44 else
               \c$case_alt_60\;

  result_88 <= result_90 when \c$satWideOut_case_scrut\ else
               result_89;

  result_selection_res_45 <= result_87 < \c$satWideOut_app_arg_4\;

  result_89 <= result_90 when result_selection_res_45 else
               result_87;

  \c$case_alt_selection_res_42\ <= \c$satWideOut_app_arg\ < to_signed(-8388608,48);

  \c$case_alt_61\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_42\ else
                     resize(\c$satWideOut_app_arg\,24);

  result_selection_res_46 <= \c$satWideOut_app_arg\ > to_signed(8388607,48);

  result_90 <= to_signed(8388607,24) when result_selection_res_46 else
               \c$case_alt_61\;

  \c$satWideOut_app_arg\ <= resize((\c$satWideOut_app_arg_1\ + \c$satWideOut_app_arg_0\),48) when \c$satWideOut_case_scrut\ else
                            resize(((resize(\c$satWideOut_app_arg_4\,25)) + \c$satWideOut_app_arg_2\),48);

  \c$shI_59\ <= (to_signed(2,64));

  csatWideOut_app_arg_0_shiftR : block
    signal sh_59 : natural;
  begin
    sh_59 <=
        -- pragma translate_off
        natural'high when (\c$shI_59\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_59\);
    \c$satWideOut_app_arg_0\ <= shift_right((\c$satWideOut_app_arg_3\ - \c$satWideOut_app_arg_1\),sh_59)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$satWideOut_app_arg_1\ <= resize(positiveKnee,25);

  \c$satWideOut_case_scrut\ <= result_87 > positiveKnee;

  positiveKnee <= resize((to_signed(5200000,25) - (resize(ch * to_signed(8500,25), 25))),24);

  \c$shI_60\ <= (to_signed(3,64));

  csatWideOut_app_arg_2_shiftR : block
    signal sh_60 : natural;
  begin
    sh_60 <=
        -- pragma translate_off
        natural'high when (\c$shI_60\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_60\);
    \c$satWideOut_app_arg_2\ <= shift_right((\c$satWideOut_app_arg_3\ + (resize(negativeKnee,25))),sh_60)
        -- pragma translate_off
        when ((to_signed(3,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$satWideOut_app_arg_3\ <= resize(result_87,25);

  \c$satWideOut_app_arg_4\ <= -negativeKnee;

  negativeKnee <= resize((to_signed(4700000,25) - (resize(ch * to_signed(7000,25), 25))),24);

  ch <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(character)))))))),25);

  \c$app_arg_136\ <= result_88 when \on_14\ else
                     x_38.Frame_sel0_fL;

  \c$shI_61\ <= (to_signed(7,64));

  capp_arg_137_shiftR : block
    signal sh_61 : natural;
  begin
    sh_61 <=
        -- pragma translate_off
        natural'high when (\c$shI_61\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_61\);
    \c$app_arg_137\ <= shift_right(x_38.Frame_sel28_fAccR,sh_61)
        -- pragma translate_off
        when ((to_signed(7,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_43\ <= \c$app_arg_137\ < to_signed(-8388608,48);

  \c$case_alt_62\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_43\ else
                     resize(\c$app_arg_137\,24);

  result_selection_res_47 <= \c$app_arg_137\ > to_signed(8388607,48);

  result_91 <= to_signed(8388607,24) when result_selection_res_47 else
               \c$case_alt_62\;

  result_92 <= result_94 when \c$satWideOut_case_scrut_0\ else
               result_93;

  result_selection_res_48 <= result_91 < \c$satWideOut_app_arg_10\;

  result_93 <= result_94 when result_selection_res_48 else
               result_91;

  \c$case_alt_selection_res_44\ <= \c$satWideOut_app_arg_5\ < to_signed(-8388608,48);

  \c$case_alt_63\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_44\ else
                     resize(\c$satWideOut_app_arg_5\,24);

  result_selection_res_49 <= \c$satWideOut_app_arg_5\ > to_signed(8388607,48);

  result_94 <= to_signed(8388607,24) when result_selection_res_49 else
               \c$case_alt_63\;

  \c$satWideOut_app_arg_5\ <= resize((\c$satWideOut_app_arg_7\ + \c$satWideOut_app_arg_6\),48) when \c$satWideOut_case_scrut_0\ else
                              resize(((resize(\c$satWideOut_app_arg_10\,25)) + \c$satWideOut_app_arg_8\),48);

  \c$shI_62\ <= (to_signed(2,64));

  csatWideOut_app_arg_6_shiftR : block
    signal sh_62 : natural;
  begin
    sh_62 <=
        -- pragma translate_off
        natural'high when (\c$shI_62\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_62\);
    \c$satWideOut_app_arg_6\ <= shift_right((\c$satWideOut_app_arg_9\ - \c$satWideOut_app_arg_7\),sh_62)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$satWideOut_app_arg_7\ <= resize(positiveKnee_0,25);

  \c$satWideOut_case_scrut_0\ <= result_91 > positiveKnee_0;

  positiveKnee_0 <= resize((to_signed(5200000,25) - (resize(ch_0 * to_signed(8500,25), 25))),24);

  \c$shI_63\ <= (to_signed(3,64));

  csatWideOut_app_arg_8_shiftR : block
    signal sh_63 : natural;
  begin
    sh_63 <=
        -- pragma translate_off
        natural'high when (\c$shI_63\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_63\);
    \c$satWideOut_app_arg_8\ <= shift_right((\c$satWideOut_app_arg_9\ + (resize(negativeKnee_0,25))),sh_63)
        -- pragma translate_off
        when ((to_signed(3,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$satWideOut_app_arg_9\ <= resize(result_91,25);

  \c$satWideOut_app_arg_10\ <= -negativeKnee_0;

  negativeKnee_0 <= resize((to_signed(4700000,25) - (resize(ch_0 * to_signed(7000,25), 25))),24);

  ch_0 <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(character)))))))),25);

  \c$app_arg_138\ <= result_92 when \on_14\ else
                     x_38.Frame_sel1_fR;

  result_95 <= ( Frame_sel0_fL => x_38.Frame_sel0_fL
               , Frame_sel1_fR => x_38.Frame_sel1_fR
               , Frame_sel2_fLast => x_38.Frame_sel2_fLast
               , Frame_sel3_fGate => x_38.Frame_sel3_fGate
               , Frame_sel4_fOd => x_38.Frame_sel4_fOd
               , Frame_sel5_fDist => x_38.Frame_sel5_fDist
               , Frame_sel6_fEq => x_38.Frame_sel6_fEq
               , Frame_sel7_fRat => x_38.Frame_sel7_fRat
               , Frame_sel8_fAmp => x_38.Frame_sel8_fAmp
               , Frame_sel9_fAmpTone => x_38.Frame_sel9_fAmpTone
               , Frame_sel10_fCab => x_38.Frame_sel10_fCab
               , Frame_sel11_fReverb => x_38.Frame_sel11_fReverb
               , Frame_sel12_fAddr => x_38.Frame_sel12_fAddr
               , Frame_sel13_fDryL => x_38.Frame_sel13_fDryL
               , Frame_sel14_fDryR => x_38.Frame_sel14_fDryR
               , Frame_sel15_fWetL => \c$app_arg_136\
               , Frame_sel16_fWetR => \c$app_arg_138\
               , Frame_sel17_fFbL => x_38.Frame_sel17_fFbL
               , Frame_sel18_fFbR => x_38.Frame_sel18_fFbR
               , Frame_sel19_fEqLowL => x_38.Frame_sel19_fEqLowL
               , Frame_sel20_fEqLowR => x_38.Frame_sel20_fEqLowR
               , Frame_sel21_fEqMidL => x_38.Frame_sel21_fEqMidL
               , Frame_sel22_fEqMidR => x_38.Frame_sel22_fEqMidR
               , Frame_sel23_fEqHighL => x_38.Frame_sel23_fEqHighL
               , Frame_sel24_fEqHighR => x_38.Frame_sel24_fEqHighR
               , Frame_sel25_fEqHighLpL => x_38.Frame_sel25_fEqHighLpL
               , Frame_sel26_fEqHighLpR => x_38.Frame_sel26_fEqHighLpR
               , Frame_sel27_fAccL => x_38.Frame_sel27_fAccL
               , Frame_sel28_fAccR => x_38.Frame_sel28_fAccR
               , Frame_sel29_fAcc2L => x_38.Frame_sel29_fAcc2L
               , Frame_sel30_fAcc2R => x_38.Frame_sel30_fAcc2R
               , Frame_sel31_fAcc3L => x_38.Frame_sel31_fAcc3L
               , Frame_sel32_fAcc3R => x_38.Frame_sel32_fAcc3R );

  \c$bv_18\ <= (x_38.Frame_sel3_fGate);

  \on_14\ <= (\c$bv_18\(6 downto 6)) = std_logic_vector'("1");

  \c$bv_19\ <= (x_38.Frame_sel9_fAmpTone);

  \c$shI_64\ <= (to_signed(1,64));

  character_shiftL : block
    signal sh_64 : natural;
  begin
    sh_64 <=
        -- pragma translate_off
        natural'high when (\c$shI_64\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_64\);
    character <= shift_right((unsigned((\c$bv_19\(31 downto 24)))),sh_64)
        -- pragma translate_off
        when ((to_signed(1,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  x_38 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_15(970 downto 0)));

  -- register begin
  ds1_15_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_15 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_15 <= result_96;
    end if;
  end process;
  -- register end

  with (ampPreLowpassPipe(971 downto 971)) select
    result_96 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(result_97.Frame_sel0_fL)
                  & std_logic_vector(result_97.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(result_97.Frame_sel2_fLast)
                  & result_97.Frame_sel3_fGate
                  & result_97.Frame_sel4_fOd
                  & result_97.Frame_sel5_fDist
                  & result_97.Frame_sel6_fEq
                  & result_97.Frame_sel7_fRat
                  & result_97.Frame_sel8_fAmp
                  & result_97.Frame_sel9_fAmpTone
                  & result_97.Frame_sel10_fCab
                  & result_97.Frame_sel11_fReverb
                  & std_logic_vector(result_97.Frame_sel12_fAddr)
                  & std_logic_vector(result_97.Frame_sel13_fDryL)
                  & std_logic_vector(result_97.Frame_sel14_fDryR)
                  & std_logic_vector(result_97.Frame_sel15_fWetL)
                  & std_logic_vector(result_97.Frame_sel16_fWetR)
                  & std_logic_vector(result_97.Frame_sel17_fFbL)
                  & std_logic_vector(result_97.Frame_sel18_fFbR)
                  & std_logic_vector(result_97.Frame_sel19_fEqLowL)
                  & std_logic_vector(result_97.Frame_sel20_fEqLowR)
                  & std_logic_vector(result_97.Frame_sel21_fEqMidL)
                  & std_logic_vector(result_97.Frame_sel22_fEqMidR)
                  & std_logic_vector(result_97.Frame_sel23_fEqHighL)
                  & std_logic_vector(result_97.Frame_sel24_fEqHighR)
                  & std_logic_vector(result_97.Frame_sel25_fEqHighLpL)
                  & std_logic_vector(result_97.Frame_sel26_fEqHighLpR)
                  & std_logic_vector(result_97.Frame_sel27_fAccL)
                  & std_logic_vector(result_97.Frame_sel28_fAccR)
                  & std_logic_vector(result_97.Frame_sel29_fAcc2L)
                  & std_logic_vector(result_97.Frame_sel30_fAcc2R)
                  & std_logic_vector(result_97.Frame_sel31_fAcc3L)
                  & std_logic_vector(result_97.Frame_sel32_fAcc3R)))) when others;

  result_97 <= ( Frame_sel0_fL => x_39.Frame_sel0_fL
               , Frame_sel1_fR => x_39.Frame_sel1_fR
               , Frame_sel2_fLast => x_39.Frame_sel2_fLast
               , Frame_sel3_fGate => x_39.Frame_sel3_fGate
               , Frame_sel4_fOd => x_39.Frame_sel4_fOd
               , Frame_sel5_fDist => x_39.Frame_sel5_fDist
               , Frame_sel6_fEq => x_39.Frame_sel6_fEq
               , Frame_sel7_fRat => x_39.Frame_sel7_fRat
               , Frame_sel8_fAmp => x_39.Frame_sel8_fAmp
               , Frame_sel9_fAmpTone => x_39.Frame_sel9_fAmpTone
               , Frame_sel10_fCab => x_39.Frame_sel10_fCab
               , Frame_sel11_fReverb => x_39.Frame_sel11_fReverb
               , Frame_sel12_fAddr => x_39.Frame_sel12_fAddr
               , Frame_sel13_fDryL => x_39.Frame_sel13_fDryL
               , Frame_sel14_fDryR => x_39.Frame_sel14_fDryR
               , Frame_sel15_fWetL => x_39.Frame_sel15_fWetL
               , Frame_sel16_fWetR => x_39.Frame_sel16_fWetR
               , Frame_sel17_fFbL => x_39.Frame_sel17_fFbL
               , Frame_sel18_fFbR => x_39.Frame_sel18_fFbR
               , Frame_sel19_fEqLowL => x_39.Frame_sel19_fEqLowL
               , Frame_sel20_fEqLowR => x_39.Frame_sel20_fEqLowR
               , Frame_sel21_fEqMidL => x_39.Frame_sel21_fEqMidL
               , Frame_sel22_fEqMidR => x_39.Frame_sel22_fEqMidR
               , Frame_sel23_fEqHighL => x_39.Frame_sel23_fEqHighL
               , Frame_sel24_fEqHighR => x_39.Frame_sel24_fEqHighR
               , Frame_sel25_fEqHighLpL => x_39.Frame_sel25_fEqHighLpL
               , Frame_sel26_fEqHighLpR => x_39.Frame_sel26_fEqHighLpR
               , Frame_sel27_fAccL => \c$app_arg_140\
               , Frame_sel28_fAccR => \c$app_arg_139\
               , Frame_sel29_fAcc2L => x_39.Frame_sel29_fAcc2L
               , Frame_sel30_fAcc2R => x_39.Frame_sel30_fAcc2R
               , Frame_sel31_fAcc3L => x_39.Frame_sel31_fAcc3L
               , Frame_sel32_fAcc3R => x_39.Frame_sel32_fAcc3R );

  \c$app_arg_139\ <= resize((resize(x_39.Frame_sel16_fWetR,48)) * \c$app_arg_141\, 48) when \on_15\ else
                     to_signed(0,48);

  \c$app_arg_140\ <= resize((resize(x_39.Frame_sel15_fWetL,48)) * \c$app_arg_141\, 48) when \on_15\ else
                     to_signed(0,48);

  \c$bv_20\ <= (x_39.Frame_sel3_fGate);

  \on_15\ <= (\c$bv_20\(6 downto 6)) = std_logic_vector'("1");

  \c$app_arg_141\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(gain_5)))))))),48);

  gain_5 <= resize(((to_unsigned(118,8) + \c$gain_app_arg_4\) + \c$gain_app_arg_3\),9);

  \c$bv_21\ <= (x_39.Frame_sel9_fAmpTone);

  \c$shI_65\ <= (to_signed(3,64));

  cgain_app_arg_3_shiftL : block
    signal sh_65 : natural;
  begin
    sh_65 <=
        -- pragma translate_off
        natural'high when (\c$shI_65\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_65\);
    \c$gain_app_arg_3\ <= shift_right((unsigned((\c$bv_21\(31 downto 24)))),sh_65)
        -- pragma translate_off
        when ((to_signed(3,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$bv_22\ <= (x_39.Frame_sel8_fAmp);

  \c$shI_66\ <= (to_signed(2,64));

  cgain_app_arg_4_shiftL : block
    signal sh_66 : natural;
  begin
    sh_66 <=
        -- pragma translate_off
        natural'high when (\c$shI_66\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_66\);
    \c$gain_app_arg_4\ <= shift_right((unsigned((\c$bv_22\(7 downto 0)))),sh_66)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  -- register begin
  ampPreLowpassPipe_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ampPreLowpassPipe <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ampPreLowpassPipe <= result_98;
    end if;
  end process;
  -- register end

  with (ds1_16(971 downto 971)) select
    result_98 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(result_99.Frame_sel0_fL)
                  & std_logic_vector(result_99.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(result_99.Frame_sel2_fLast)
                  & result_99.Frame_sel3_fGate
                  & result_99.Frame_sel4_fOd
                  & result_99.Frame_sel5_fDist
                  & result_99.Frame_sel6_fEq
                  & result_99.Frame_sel7_fRat
                  & result_99.Frame_sel8_fAmp
                  & result_99.Frame_sel9_fAmpTone
                  & result_99.Frame_sel10_fCab
                  & result_99.Frame_sel11_fReverb
                  & std_logic_vector(result_99.Frame_sel12_fAddr)
                  & std_logic_vector(result_99.Frame_sel13_fDryL)
                  & std_logic_vector(result_99.Frame_sel14_fDryR)
                  & std_logic_vector(result_99.Frame_sel15_fWetL)
                  & std_logic_vector(result_99.Frame_sel16_fWetR)
                  & std_logic_vector(result_99.Frame_sel17_fFbL)
                  & std_logic_vector(result_99.Frame_sel18_fFbR)
                  & std_logic_vector(result_99.Frame_sel19_fEqLowL)
                  & std_logic_vector(result_99.Frame_sel20_fEqLowR)
                  & std_logic_vector(result_99.Frame_sel21_fEqMidL)
                  & std_logic_vector(result_99.Frame_sel22_fEqMidR)
                  & std_logic_vector(result_99.Frame_sel23_fEqHighL)
                  & std_logic_vector(result_99.Frame_sel24_fEqHighR)
                  & std_logic_vector(result_99.Frame_sel25_fEqHighLpL)
                  & std_logic_vector(result_99.Frame_sel26_fEqHighLpR)
                  & std_logic_vector(result_99.Frame_sel27_fAccL)
                  & std_logic_vector(result_99.Frame_sel28_fAccR)
                  & std_logic_vector(result_99.Frame_sel29_fAcc2L)
                  & std_logic_vector(result_99.Frame_sel30_fAcc2R)
                  & std_logic_vector(result_99.Frame_sel31_fAcc3L)
                  & std_logic_vector(result_99.Frame_sel32_fAcc3R)))) when others;

  alpha <= to_unsigned(160,8) + \c$alpha_app_arg\;

  \c$bv_23\ <= (x_40.Frame_sel3_fGate);

  \on_16\ <= (\c$bv_23\(6 downto 6)) = std_logic_vector'("1");

  result_99 <= ( Frame_sel0_fL => x_40.Frame_sel0_fL
               , Frame_sel1_fR => x_40.Frame_sel1_fR
               , Frame_sel2_fLast => x_40.Frame_sel2_fLast
               , Frame_sel3_fGate => x_40.Frame_sel3_fGate
               , Frame_sel4_fOd => x_40.Frame_sel4_fOd
               , Frame_sel5_fDist => x_40.Frame_sel5_fDist
               , Frame_sel6_fEq => x_40.Frame_sel6_fEq
               , Frame_sel7_fRat => x_40.Frame_sel7_fRat
               , Frame_sel8_fAmp => x_40.Frame_sel8_fAmp
               , Frame_sel9_fAmpTone => x_40.Frame_sel9_fAmpTone
               , Frame_sel10_fCab => x_40.Frame_sel10_fCab
               , Frame_sel11_fReverb => x_40.Frame_sel11_fReverb
               , Frame_sel12_fAddr => x_40.Frame_sel12_fAddr
               , Frame_sel13_fDryL => x_40.Frame_sel13_fDryL
               , Frame_sel14_fDryR => x_40.Frame_sel14_fDryR
               , Frame_sel15_fWetL => \c$app_arg_144\
               , Frame_sel16_fWetR => \c$app_arg_142\
               , Frame_sel17_fFbL => x_40.Frame_sel17_fFbL
               , Frame_sel18_fFbR => x_40.Frame_sel18_fFbR
               , Frame_sel19_fEqLowL => x_40.Frame_sel19_fEqLowL
               , Frame_sel20_fEqLowR => x_40.Frame_sel20_fEqLowR
               , Frame_sel21_fEqMidL => x_40.Frame_sel21_fEqMidL
               , Frame_sel22_fEqMidR => x_40.Frame_sel22_fEqMidR
               , Frame_sel23_fEqHighL => x_40.Frame_sel23_fEqHighL
               , Frame_sel24_fEqHighR => x_40.Frame_sel24_fEqHighR
               , Frame_sel25_fEqHighLpL => x_40.Frame_sel25_fEqHighLpL
               , Frame_sel26_fEqHighLpR => x_40.Frame_sel26_fEqHighLpR
               , Frame_sel27_fAccL => x_40.Frame_sel27_fAccL
               , Frame_sel28_fAccR => x_40.Frame_sel28_fAccR
               , Frame_sel29_fAcc2L => x_40.Frame_sel29_fAcc2L
               , Frame_sel30_fAcc2R => x_40.Frame_sel30_fAcc2R
               , Frame_sel31_fAcc3L => x_40.Frame_sel31_fAcc3L
               , Frame_sel32_fAcc3R => x_40.Frame_sel32_fAcc3R );

  \c$app_arg_142\ <= result_100 when \on_16\ else
                     x_40.Frame_sel1_fR;

  \c$shI_67\ <= (to_signed(8,64));

  capp_arg_143_shiftR : block
    signal sh_67 : natural;
  begin
    sh_67 <=
        -- pragma translate_off
        natural'high when (\c$shI_67\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_67\);
    \c$app_arg_143\ <= shift_right(((resize((resize(x_40.Frame_sel16_fWetR,48)) * (resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(alpha)))))))),48)), 48)) + (resize((resize(ampPreLpPrevR,48)) * (resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(gain_6)))))))),48)), 48))),sh_67)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  gain_6 <= to_unsigned(255,8) - alpha;

  \c$case_alt_selection_res_45\ <= \c$app_arg_143\ < to_signed(-8388608,48);

  \c$case_alt_64\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_45\ else
                     resize(\c$app_arg_143\,24);

  result_selection_res_50 <= \c$app_arg_143\ > to_signed(8388607,48);

  result_100 <= to_signed(8388607,24) when result_selection_res_50 else
                \c$case_alt_64\;

  \c$app_arg_144\ <= result_101 when \on_16\ else
                     x_40.Frame_sel0_fL;

  \c$shI_68\ <= (to_signed(8,64));

  capp_arg_145_shiftR : block
    signal sh_68 : natural;
  begin
    sh_68 <=
        -- pragma translate_off
        natural'high when (\c$shI_68\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_68\);
    \c$app_arg_145\ <= shift_right(((resize((resize(x_40.Frame_sel15_fWetL,48)) * (resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(alpha)))))))),48)), 48)) + (resize((resize(ampPreLpPrevL,48)) * (resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(gain_7)))))))),48)), 48))),sh_68)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  gain_7 <= to_unsigned(255,8) - alpha;

  \c$case_alt_selection_res_46\ <= \c$app_arg_145\ < to_signed(-8388608,48);

  \c$case_alt_65\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_46\ else
                     resize(\c$app_arg_145\,24);

  result_selection_res_51 <= \c$app_arg_145\ > to_signed(8388607,48);

  result_101 <= to_signed(8388607,24) when result_selection_res_51 else
                \c$case_alt_65\;

  \c$bv_24\ <= (x_40.Frame_sel9_fAmpTone);

  \c$shI_69\ <= (to_signed(2,64));

  calpha_app_arg_shiftL : block
    signal sh_69 : natural;
  begin
    sh_69 <=
        -- pragma translate_off
        natural'high when (\c$shI_69\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_69\);
    \c$alpha_app_arg\ <= shift_right((unsigned((\c$bv_24\(31 downto 24)))),sh_69)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  -- register begin
  ampPreLpPrevR_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ampPreLpPrevR <= to_signed(0,24);
    elsif rising_edge(clk) then
      ampPreLpPrevR <= \c$ampPreLpPrevR_app_arg\;
    end if;
  end process;
  -- register end

  with (ampPreLowpassPipe(971 downto 971)) select
    \c$ampPreLpPrevR_app_arg\ <= ampPreLpPrevR when "0",
                                 x_39.Frame_sel16_fWetR when others;

  -- register begin
  ampPreLpPrevL_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ampPreLpPrevL <= to_signed(0,24);
    elsif rising_edge(clk) then
      ampPreLpPrevL <= \c$ampPreLpPrevL_app_arg\;
    end if;
  end process;
  -- register end

  with (ampPreLowpassPipe(971 downto 971)) select
    \c$ampPreLpPrevL_app_arg\ <= ampPreLpPrevL when "0",
                                 x_39.Frame_sel15_fWetL when others;

  x_39 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ampPreLowpassPipe(970 downto 0)));

  x_40 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_16(970 downto 0)));

  -- register begin
  ds1_16_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_16 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_16 <= result_102;
    end if;
  end process;
  -- register end

  with (ds1_17(971 downto 971)) select
    result_102 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                  std_logic_vector'("1" & ((std_logic_vector(result_103.Frame_sel0_fL)
                   & std_logic_vector(result_103.Frame_sel1_fR)
                   & clash_lowpass_fir_types.toSLV(result_103.Frame_sel2_fLast)
                   & result_103.Frame_sel3_fGate
                   & result_103.Frame_sel4_fOd
                   & result_103.Frame_sel5_fDist
                   & result_103.Frame_sel6_fEq
                   & result_103.Frame_sel7_fRat
                   & result_103.Frame_sel8_fAmp
                   & result_103.Frame_sel9_fAmpTone
                   & result_103.Frame_sel10_fCab
                   & result_103.Frame_sel11_fReverb
                   & std_logic_vector(result_103.Frame_sel12_fAddr)
                   & std_logic_vector(result_103.Frame_sel13_fDryL)
                   & std_logic_vector(result_103.Frame_sel14_fDryR)
                   & std_logic_vector(result_103.Frame_sel15_fWetL)
                   & std_logic_vector(result_103.Frame_sel16_fWetR)
                   & std_logic_vector(result_103.Frame_sel17_fFbL)
                   & std_logic_vector(result_103.Frame_sel18_fFbR)
                   & std_logic_vector(result_103.Frame_sel19_fEqLowL)
                   & std_logic_vector(result_103.Frame_sel20_fEqLowR)
                   & std_logic_vector(result_103.Frame_sel21_fEqMidL)
                   & std_logic_vector(result_103.Frame_sel22_fEqMidR)
                   & std_logic_vector(result_103.Frame_sel23_fEqHighL)
                   & std_logic_vector(result_103.Frame_sel24_fEqHighR)
                   & std_logic_vector(result_103.Frame_sel25_fEqHighLpL)
                   & std_logic_vector(result_103.Frame_sel26_fEqHighLpR)
                   & std_logic_vector(result_103.Frame_sel27_fAccL)
                   & std_logic_vector(result_103.Frame_sel28_fAccR)
                   & std_logic_vector(result_103.Frame_sel29_fAcc2L)
                   & std_logic_vector(result_103.Frame_sel30_fAcc2R)
                   & std_logic_vector(result_103.Frame_sel31_fAcc3L)
                   & std_logic_vector(result_103.Frame_sel32_fAcc3R)))) when others;

  \c$bv_25\ <= (x_41.Frame_sel9_fAmpTone);

  character_0 <= unsigned((\c$bv_25\(31 downto 24)));

  \c$bv_26\ <= (x_41.Frame_sel3_fGate);

  \on_17\ <= (\c$bv_26\(6 downto 6)) = std_logic_vector'("1");

  result_103 <= ( Frame_sel0_fL => x_41.Frame_sel0_fL
                , Frame_sel1_fR => x_41.Frame_sel1_fR
                , Frame_sel2_fLast => x_41.Frame_sel2_fLast
                , Frame_sel3_fGate => x_41.Frame_sel3_fGate
                , Frame_sel4_fOd => x_41.Frame_sel4_fOd
                , Frame_sel5_fDist => x_41.Frame_sel5_fDist
                , Frame_sel6_fEq => x_41.Frame_sel6_fEq
                , Frame_sel7_fRat => x_41.Frame_sel7_fRat
                , Frame_sel8_fAmp => x_41.Frame_sel8_fAmp
                , Frame_sel9_fAmpTone => x_41.Frame_sel9_fAmpTone
                , Frame_sel10_fCab => x_41.Frame_sel10_fCab
                , Frame_sel11_fReverb => x_41.Frame_sel11_fReverb
                , Frame_sel12_fAddr => x_41.Frame_sel12_fAddr
                , Frame_sel13_fDryL => x_41.Frame_sel13_fDryL
                , Frame_sel14_fDryR => x_41.Frame_sel14_fDryR
                , Frame_sel15_fWetL => \c$app_arg_147\
                , Frame_sel16_fWetR => \c$app_arg_146\
                , Frame_sel17_fFbL => x_41.Frame_sel17_fFbL
                , Frame_sel18_fFbR => x_41.Frame_sel18_fFbR
                , Frame_sel19_fEqLowL => x_41.Frame_sel19_fEqLowL
                , Frame_sel20_fEqLowR => x_41.Frame_sel20_fEqLowR
                , Frame_sel21_fEqMidL => x_41.Frame_sel21_fEqMidL
                , Frame_sel22_fEqMidR => x_41.Frame_sel22_fEqMidR
                , Frame_sel23_fEqHighL => x_41.Frame_sel23_fEqHighL
                , Frame_sel24_fEqHighR => x_41.Frame_sel24_fEqHighR
                , Frame_sel25_fEqHighLpL => x_41.Frame_sel25_fEqHighLpL
                , Frame_sel26_fEqHighLpR => x_41.Frame_sel26_fEqHighLpR
                , Frame_sel27_fAccL => x_41.Frame_sel27_fAccL
                , Frame_sel28_fAccR => x_41.Frame_sel28_fAccR
                , Frame_sel29_fAcc2L => x_41.Frame_sel29_fAcc2L
                , Frame_sel30_fAcc2R => x_41.Frame_sel30_fAcc2R
                , Frame_sel31_fAcc3L => x_41.Frame_sel31_fAcc3L
                , Frame_sel32_fAcc3R => x_41.Frame_sel32_fAcc3R );

  \c$app_arg_146\ <= result_104 when \on_17\ else
                     x_41.Frame_sel1_fR;

  result_104 <= result_106 when \c$satWideOut_case_scrut_1\ else
                result_105;

  result_selection_res_52 <= x_41.Frame_sel16_fWetR < \c$satWideOut_app_arg_16\;

  result_105 <= result_106 when result_selection_res_52 else
                x_41.Frame_sel16_fWetR;

  \c$case_alt_selection_res_47\ <= \c$satWideOut_app_arg_11\ < to_signed(-8388608,48);

  \c$case_alt_66\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_47\ else
                     resize(\c$satWideOut_app_arg_11\,24);

  result_selection_res_53 <= \c$satWideOut_app_arg_11\ > to_signed(8388607,48);

  result_106 <= to_signed(8388607,24) when result_selection_res_53 else
                \c$case_alt_66\;

  \c$satWideOut_app_arg_11\ <= resize((\c$satWideOut_app_arg_13\ + \c$satWideOut_app_arg_12\),48) when \c$satWideOut_case_scrut_1\ else
                               resize(((resize(\c$satWideOut_app_arg_16\,25)) + \c$satWideOut_app_arg_14\),48);

  \c$shI_70\ <= (to_signed(2,64));

  csatWideOut_app_arg_12_shiftR : block
    signal sh_70 : natural;
  begin
    sh_70 <=
        -- pragma translate_off
        natural'high when (\c$shI_70\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_70\);
    \c$satWideOut_app_arg_12\ <= shift_right((\c$satWideOut_app_arg_15\ - \c$satWideOut_app_arg_13\),sh_70)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$satWideOut_app_arg_13\ <= resize(positiveKnee_1,25);

  \c$satWideOut_case_scrut_1\ <= x_41.Frame_sel16_fWetR > positiveKnee_1;

  positiveKnee_1 <= resize((to_signed(5200000,25) - (resize(ch_1 * to_signed(8500,25), 25))),24);

  \c$shI_71\ <= (to_signed(3,64));

  csatWideOut_app_arg_14_shiftR : block
    signal sh_71 : natural;
  begin
    sh_71 <=
        -- pragma translate_off
        natural'high when (\c$shI_71\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_71\);
    \c$satWideOut_app_arg_14\ <= shift_right((\c$satWideOut_app_arg_15\ + (resize(negativeKnee_1,25))),sh_71)
        -- pragma translate_off
        when ((to_signed(3,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$satWideOut_app_arg_15\ <= resize(x_41.Frame_sel16_fWetR,25);

  \c$satWideOut_app_arg_16\ <= -negativeKnee_1;

  negativeKnee_1 <= resize((to_signed(4700000,25) - (resize(ch_1 * to_signed(7000,25), 25))),24);

  ch_1 <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(character_0)))))))),25);

  \c$app_arg_147\ <= result_107 when \on_17\ else
                     x_41.Frame_sel0_fL;

  result_107 <= result_109 when \c$satWideOut_case_scrut_2\ else
                result_108;

  result_selection_res_54 <= x_41.Frame_sel15_fWetL < \c$satWideOut_app_arg_22\;

  result_108 <= result_109 when result_selection_res_54 else
                x_41.Frame_sel15_fWetL;

  \c$case_alt_selection_res_48\ <= \c$satWideOut_app_arg_17\ < to_signed(-8388608,48);

  \c$case_alt_67\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_48\ else
                     resize(\c$satWideOut_app_arg_17\,24);

  result_selection_res_55 <= \c$satWideOut_app_arg_17\ > to_signed(8388607,48);

  result_109 <= to_signed(8388607,24) when result_selection_res_55 else
                \c$case_alt_67\;

  \c$satWideOut_app_arg_17\ <= resize((\c$satWideOut_app_arg_19\ + \c$satWideOut_app_arg_18\),48) when \c$satWideOut_case_scrut_2\ else
                               resize(((resize(\c$satWideOut_app_arg_22\,25)) + \c$satWideOut_app_arg_20\),48);

  \c$shI_72\ <= (to_signed(2,64));

  csatWideOut_app_arg_18_shiftR : block
    signal sh_72 : natural;
  begin
    sh_72 <=
        -- pragma translate_off
        natural'high when (\c$shI_72\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_72\);
    \c$satWideOut_app_arg_18\ <= shift_right((\c$satWideOut_app_arg_21\ - \c$satWideOut_app_arg_19\),sh_72)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$satWideOut_app_arg_19\ <= resize(positiveKnee_2,25);

  \c$satWideOut_case_scrut_2\ <= x_41.Frame_sel15_fWetL > positiveKnee_2;

  positiveKnee_2 <= resize((to_signed(5200000,25) - (resize(ch_2 * to_signed(8500,25), 25))),24);

  \c$shI_73\ <= (to_signed(3,64));

  csatWideOut_app_arg_20_shiftR : block
    signal sh_73 : natural;
  begin
    sh_73 <=
        -- pragma translate_off
        natural'high when (\c$shI_73\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_73\);
    \c$satWideOut_app_arg_20\ <= shift_right((\c$satWideOut_app_arg_21\ + (resize(negativeKnee_2,25))),sh_73)
        -- pragma translate_off
        when ((to_signed(3,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$satWideOut_app_arg_21\ <= resize(x_41.Frame_sel15_fWetL,25);

  \c$satWideOut_app_arg_22\ <= -negativeKnee_2;

  negativeKnee_2 <= resize((to_signed(4700000,25) - (resize(ch_2 * to_signed(7000,25), 25))),24);

  ch_2 <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(character_0)))))))),25);

  x_41 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_17(970 downto 0)));

  -- register begin
  ds1_17_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_17 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_17 <= result_110;
    end if;
  end process;
  -- register end

  with (ds1_18(971 downto 971)) select
    result_110 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                  std_logic_vector'("1" & ((std_logic_vector(result_113.Frame_sel0_fL)
                   & std_logic_vector(result_113.Frame_sel1_fR)
                   & clash_lowpass_fir_types.toSLV(result_113.Frame_sel2_fLast)
                   & result_113.Frame_sel3_fGate
                   & result_113.Frame_sel4_fOd
                   & result_113.Frame_sel5_fDist
                   & result_113.Frame_sel6_fEq
                   & result_113.Frame_sel7_fRat
                   & result_113.Frame_sel8_fAmp
                   & result_113.Frame_sel9_fAmpTone
                   & result_113.Frame_sel10_fCab
                   & result_113.Frame_sel11_fReverb
                   & std_logic_vector(result_113.Frame_sel12_fAddr)
                   & std_logic_vector(result_113.Frame_sel13_fDryL)
                   & std_logic_vector(result_113.Frame_sel14_fDryR)
                   & std_logic_vector(result_113.Frame_sel15_fWetL)
                   & std_logic_vector(result_113.Frame_sel16_fWetR)
                   & std_logic_vector(result_113.Frame_sel17_fFbL)
                   & std_logic_vector(result_113.Frame_sel18_fFbR)
                   & std_logic_vector(result_113.Frame_sel19_fEqLowL)
                   & std_logic_vector(result_113.Frame_sel20_fEqLowR)
                   & std_logic_vector(result_113.Frame_sel21_fEqMidL)
                   & std_logic_vector(result_113.Frame_sel22_fEqMidR)
                   & std_logic_vector(result_113.Frame_sel23_fEqHighL)
                   & std_logic_vector(result_113.Frame_sel24_fEqHighR)
                   & std_logic_vector(result_113.Frame_sel25_fEqHighLpL)
                   & std_logic_vector(result_113.Frame_sel26_fEqHighLpR)
                   & std_logic_vector(result_113.Frame_sel27_fAccL)
                   & std_logic_vector(result_113.Frame_sel28_fAccR)
                   & std_logic_vector(result_113.Frame_sel29_fAcc2L)
                   & std_logic_vector(result_113.Frame_sel30_fAcc2R)
                   & std_logic_vector(result_113.Frame_sel31_fAcc3L)
                   & std_logic_vector(result_113.Frame_sel32_fAcc3R)))) when others;

  \c$shI_74\ <= (to_signed(7,64));

  capp_arg_148_shiftR : block
    signal sh_74 : natural;
  begin
    sh_74 <=
        -- pragma translate_off
        natural'high when (\c$shI_74\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_74\);
    \c$app_arg_148\ <= shift_right(x_42.Frame_sel27_fAccL,sh_74)
        -- pragma translate_off
        when ((to_signed(7,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_49\ <= \c$app_arg_148\ < to_signed(-8388608,48);

  \c$case_alt_68\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_49\ else
                     resize(\c$app_arg_148\,24);

  result_selection_res_56 <= \c$app_arg_148\ > to_signed(8388607,48);

  result_111 <= to_signed(8388607,24) when result_selection_res_56 else
                \c$case_alt_68\;

  \c$app_arg_149\ <= result_111 when \on_18\ else
                     x_42.Frame_sel0_fL;

  \c$shI_75\ <= (to_signed(7,64));

  capp_arg_150_shiftR : block
    signal sh_75 : natural;
  begin
    sh_75 <=
        -- pragma translate_off
        natural'high when (\c$shI_75\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_75\);
    \c$app_arg_150\ <= shift_right(x_42.Frame_sel28_fAccR,sh_75)
        -- pragma translate_off
        when ((to_signed(7,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_50\ <= \c$app_arg_150\ < to_signed(-8388608,48);

  \c$case_alt_69\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_50\ else
                     resize(\c$app_arg_150\,24);

  result_selection_res_57 <= \c$app_arg_150\ > to_signed(8388607,48);

  result_112 <= to_signed(8388607,24) when result_selection_res_57 else
                \c$case_alt_69\;

  \c$app_arg_151\ <= result_112 when \on_18\ else
                     x_42.Frame_sel1_fR;

  result_113 <= ( Frame_sel0_fL => x_42.Frame_sel0_fL
                , Frame_sel1_fR => x_42.Frame_sel1_fR
                , Frame_sel2_fLast => x_42.Frame_sel2_fLast
                , Frame_sel3_fGate => x_42.Frame_sel3_fGate
                , Frame_sel4_fOd => x_42.Frame_sel4_fOd
                , Frame_sel5_fDist => x_42.Frame_sel5_fDist
                , Frame_sel6_fEq => x_42.Frame_sel6_fEq
                , Frame_sel7_fRat => x_42.Frame_sel7_fRat
                , Frame_sel8_fAmp => x_42.Frame_sel8_fAmp
                , Frame_sel9_fAmpTone => x_42.Frame_sel9_fAmpTone
                , Frame_sel10_fCab => x_42.Frame_sel10_fCab
                , Frame_sel11_fReverb => x_42.Frame_sel11_fReverb
                , Frame_sel12_fAddr => x_42.Frame_sel12_fAddr
                , Frame_sel13_fDryL => x_42.Frame_sel13_fDryL
                , Frame_sel14_fDryR => x_42.Frame_sel14_fDryR
                , Frame_sel15_fWetL => \c$app_arg_149\
                , Frame_sel16_fWetR => \c$app_arg_151\
                , Frame_sel17_fFbL => x_42.Frame_sel17_fFbL
                , Frame_sel18_fFbR => x_42.Frame_sel18_fFbR
                , Frame_sel19_fEqLowL => x_42.Frame_sel19_fEqLowL
                , Frame_sel20_fEqLowR => x_42.Frame_sel20_fEqLowR
                , Frame_sel21_fEqMidL => x_42.Frame_sel21_fEqMidL
                , Frame_sel22_fEqMidR => x_42.Frame_sel22_fEqMidR
                , Frame_sel23_fEqHighL => x_42.Frame_sel23_fEqHighL
                , Frame_sel24_fEqHighR => x_42.Frame_sel24_fEqHighR
                , Frame_sel25_fEqHighLpL => x_42.Frame_sel25_fEqHighLpL
                , Frame_sel26_fEqHighLpR => x_42.Frame_sel26_fEqHighLpR
                , Frame_sel27_fAccL => x_42.Frame_sel27_fAccL
                , Frame_sel28_fAccR => x_42.Frame_sel28_fAccR
                , Frame_sel29_fAcc2L => x_42.Frame_sel29_fAcc2L
                , Frame_sel30_fAcc2R => x_42.Frame_sel30_fAcc2R
                , Frame_sel31_fAcc3L => x_42.Frame_sel31_fAcc3L
                , Frame_sel32_fAcc3R => x_42.Frame_sel32_fAcc3R );

  \c$bv_27\ <= (x_42.Frame_sel3_fGate);

  \on_18\ <= (\c$bv_27\(6 downto 6)) = std_logic_vector'("1");

  x_42 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_18(970 downto 0)));

  -- register begin
  ds1_18_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_18 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_18 <= result_114;
    end if;
  end process;
  -- register end

  with (ampHighpassPipe(971 downto 971)) select
    result_114 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                  std_logic_vector'("1" & ((std_logic_vector(result_115.Frame_sel0_fL)
                   & std_logic_vector(result_115.Frame_sel1_fR)
                   & clash_lowpass_fir_types.toSLV(result_115.Frame_sel2_fLast)
                   & result_115.Frame_sel3_fGate
                   & result_115.Frame_sel4_fOd
                   & result_115.Frame_sel5_fDist
                   & result_115.Frame_sel6_fEq
                   & result_115.Frame_sel7_fRat
                   & result_115.Frame_sel8_fAmp
                   & result_115.Frame_sel9_fAmpTone
                   & result_115.Frame_sel10_fCab
                   & result_115.Frame_sel11_fReverb
                   & std_logic_vector(result_115.Frame_sel12_fAddr)
                   & std_logic_vector(result_115.Frame_sel13_fDryL)
                   & std_logic_vector(result_115.Frame_sel14_fDryR)
                   & std_logic_vector(result_115.Frame_sel15_fWetL)
                   & std_logic_vector(result_115.Frame_sel16_fWetR)
                   & std_logic_vector(result_115.Frame_sel17_fFbL)
                   & std_logic_vector(result_115.Frame_sel18_fFbR)
                   & std_logic_vector(result_115.Frame_sel19_fEqLowL)
                   & std_logic_vector(result_115.Frame_sel20_fEqLowR)
                   & std_logic_vector(result_115.Frame_sel21_fEqMidL)
                   & std_logic_vector(result_115.Frame_sel22_fEqMidR)
                   & std_logic_vector(result_115.Frame_sel23_fEqHighL)
                   & std_logic_vector(result_115.Frame_sel24_fEqHighR)
                   & std_logic_vector(result_115.Frame_sel25_fEqHighLpL)
                   & std_logic_vector(result_115.Frame_sel26_fEqHighLpR)
                   & std_logic_vector(result_115.Frame_sel27_fAccL)
                   & std_logic_vector(result_115.Frame_sel28_fAccR)
                   & std_logic_vector(result_115.Frame_sel29_fAcc2L)
                   & std_logic_vector(result_115.Frame_sel30_fAcc2R)
                   & std_logic_vector(result_115.Frame_sel31_fAcc3L)
                   & std_logic_vector(result_115.Frame_sel32_fAcc3R)))) when others;

  result_115 <= ( Frame_sel0_fL => x_45.Frame_sel0_fL
                , Frame_sel1_fR => x_45.Frame_sel1_fR
                , Frame_sel2_fLast => x_45.Frame_sel2_fLast
                , Frame_sel3_fGate => x_45.Frame_sel3_fGate
                , Frame_sel4_fOd => x_45.Frame_sel4_fOd
                , Frame_sel5_fDist => x_45.Frame_sel5_fDist
                , Frame_sel6_fEq => x_45.Frame_sel6_fEq
                , Frame_sel7_fRat => x_45.Frame_sel7_fRat
                , Frame_sel8_fAmp => x_45.Frame_sel8_fAmp
                , Frame_sel9_fAmpTone => x_45.Frame_sel9_fAmpTone
                , Frame_sel10_fCab => x_45.Frame_sel10_fCab
                , Frame_sel11_fReverb => x_45.Frame_sel11_fReverb
                , Frame_sel12_fAddr => x_45.Frame_sel12_fAddr
                , Frame_sel13_fDryL => x_45.Frame_sel13_fDryL
                , Frame_sel14_fDryR => x_45.Frame_sel14_fDryR
                , Frame_sel15_fWetL => x_45.Frame_sel15_fWetL
                , Frame_sel16_fWetR => x_45.Frame_sel16_fWetR
                , Frame_sel17_fFbL => x_45.Frame_sel17_fFbL
                , Frame_sel18_fFbR => x_45.Frame_sel18_fFbR
                , Frame_sel19_fEqLowL => x_45.Frame_sel19_fEqLowL
                , Frame_sel20_fEqLowR => x_45.Frame_sel20_fEqLowR
                , Frame_sel21_fEqMidL => x_45.Frame_sel21_fEqMidL
                , Frame_sel22_fEqMidR => x_45.Frame_sel22_fEqMidR
                , Frame_sel23_fEqHighL => x_45.Frame_sel23_fEqHighL
                , Frame_sel24_fEqHighR => x_45.Frame_sel24_fEqHighR
                , Frame_sel25_fEqHighLpL => x_45.Frame_sel25_fEqHighLpL
                , Frame_sel26_fEqHighLpR => x_45.Frame_sel26_fEqHighLpR
                , Frame_sel27_fAccL => \c$app_arg_153\
                , Frame_sel28_fAccR => \c$app_arg_152\
                , Frame_sel29_fAcc2L => x_45.Frame_sel29_fAcc2L
                , Frame_sel30_fAcc2R => x_45.Frame_sel30_fAcc2R
                , Frame_sel31_fAcc3L => x_45.Frame_sel31_fAcc3L
                , Frame_sel32_fAcc3R => x_45.Frame_sel32_fAcc3R );

  \c$app_arg_152\ <= resize((resize(x_45.Frame_sel16_fWetR,48)) * \c$app_arg_154\, 48) when \on_19\ else
                     to_signed(0,48);

  \c$app_arg_153\ <= resize((resize(x_45.Frame_sel15_fWetL,48)) * \c$app_arg_154\, 48) when \on_19\ else
                     to_signed(0,48);

  \c$bv_28\ <= (x_45.Frame_sel3_fGate);

  \on_19\ <= (\c$bv_28\(6 downto 6)) = std_logic_vector'("1");

  \c$app_arg_154\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(gain_8)))))))),48);

  \c$bv_29\ <= (x_45.Frame_sel8_fAmp);

  gain_8 <= resize((to_unsigned(128,12) + (resize((resize((unsigned((\c$bv_29\(7 downto 0)))),12)) * to_unsigned(15,12), 12))),12);

  -- register begin
  ampHighpassPipe_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ampHighpassPipe <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ampHighpassPipe <= result_116;
    end if;
  end process;
  -- register end

  with (ds1_19(971 downto 971)) select
    result_116 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                  std_logic_vector'("1" & ((std_logic_vector(result_119.Frame_sel0_fL)
                   & std_logic_vector(result_119.Frame_sel1_fR)
                   & clash_lowpass_fir_types.toSLV(result_119.Frame_sel2_fLast)
                   & result_119.Frame_sel3_fGate
                   & result_119.Frame_sel4_fOd
                   & result_119.Frame_sel5_fDist
                   & result_119.Frame_sel6_fEq
                   & result_119.Frame_sel7_fRat
                   & result_119.Frame_sel8_fAmp
                   & result_119.Frame_sel9_fAmpTone
                   & result_119.Frame_sel10_fCab
                   & result_119.Frame_sel11_fReverb
                   & std_logic_vector(result_119.Frame_sel12_fAddr)
                   & std_logic_vector(result_119.Frame_sel13_fDryL)
                   & std_logic_vector(result_119.Frame_sel14_fDryR)
                   & std_logic_vector(result_119.Frame_sel15_fWetL)
                   & std_logic_vector(result_119.Frame_sel16_fWetR)
                   & std_logic_vector(result_119.Frame_sel17_fFbL)
                   & std_logic_vector(result_119.Frame_sel18_fFbR)
                   & std_logic_vector(result_119.Frame_sel19_fEqLowL)
                   & std_logic_vector(result_119.Frame_sel20_fEqLowR)
                   & std_logic_vector(result_119.Frame_sel21_fEqMidL)
                   & std_logic_vector(result_119.Frame_sel22_fEqMidR)
                   & std_logic_vector(result_119.Frame_sel23_fEqHighL)
                   & std_logic_vector(result_119.Frame_sel24_fEqHighR)
                   & std_logic_vector(result_119.Frame_sel25_fEqHighLpL)
                   & std_logic_vector(result_119.Frame_sel26_fEqHighLpR)
                   & std_logic_vector(result_119.Frame_sel27_fAccL)
                   & std_logic_vector(result_119.Frame_sel28_fAccR)
                   & std_logic_vector(result_119.Frame_sel29_fAcc2L)
                   & std_logic_vector(result_119.Frame_sel30_fAcc2R)
                   & std_logic_vector(result_119.Frame_sel31_fAcc3L)
                   & std_logic_vector(result_119.Frame_sel32_fAcc3R)))) when others;

  x_43 <= ((resize(x_46.Frame_sel0_fL,48)) - (resize(ampHpInPrevL,48))) + (resize((resize(ampHpOutPrevL,48)) * to_signed(0,48), 48));

  \c$case_alt_selection_res_51\ <= x_43 < to_signed(-8388608,48);

  \c$case_alt_70\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_51\ else
                     resize(x_43,24);

  result_selection_res_58 <= x_43 > to_signed(8388607,48);

  result_117 <= to_signed(8388607,24) when result_selection_res_58 else
                \c$case_alt_70\;

  \c$app_arg_155\ <= result_117 when \on_20\ else
                     x_46.Frame_sel0_fL;

  x_44 <= ((resize(x_46.Frame_sel1_fR,48)) - (resize(ampHpInPrevR,48))) + (resize((resize(ampHpOutPrevR,48)) * to_signed(0,48), 48));

  \c$case_alt_selection_res_52\ <= x_44 < to_signed(-8388608,48);

  \c$case_alt_71\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_52\ else
                     resize(x_44,24);

  result_selection_res_59 <= x_44 > to_signed(8388607,48);

  result_118 <= to_signed(8388607,24) when result_selection_res_59 else
                \c$case_alt_71\;

  \c$app_arg_156\ <= result_118 when \on_20\ else
                     x_46.Frame_sel1_fR;

  result_119 <= ( Frame_sel0_fL => x_46.Frame_sel0_fL
                , Frame_sel1_fR => x_46.Frame_sel1_fR
                , Frame_sel2_fLast => x_46.Frame_sel2_fLast
                , Frame_sel3_fGate => x_46.Frame_sel3_fGate
                , Frame_sel4_fOd => x_46.Frame_sel4_fOd
                , Frame_sel5_fDist => x_46.Frame_sel5_fDist
                , Frame_sel6_fEq => x_46.Frame_sel6_fEq
                , Frame_sel7_fRat => x_46.Frame_sel7_fRat
                , Frame_sel8_fAmp => x_46.Frame_sel8_fAmp
                , Frame_sel9_fAmpTone => x_46.Frame_sel9_fAmpTone
                , Frame_sel10_fCab => x_46.Frame_sel10_fCab
                , Frame_sel11_fReverb => x_46.Frame_sel11_fReverb
                , Frame_sel12_fAddr => x_46.Frame_sel12_fAddr
                , Frame_sel13_fDryL => x_46.Frame_sel0_fL
                , Frame_sel14_fDryR => x_46.Frame_sel1_fR
                , Frame_sel15_fWetL => \c$app_arg_155\
                , Frame_sel16_fWetR => \c$app_arg_156\
                , Frame_sel17_fFbL => x_46.Frame_sel17_fFbL
                , Frame_sel18_fFbR => x_46.Frame_sel18_fFbR
                , Frame_sel19_fEqLowL => x_46.Frame_sel19_fEqLowL
                , Frame_sel20_fEqLowR => x_46.Frame_sel20_fEqLowR
                , Frame_sel21_fEqMidL => x_46.Frame_sel21_fEqMidL
                , Frame_sel22_fEqMidR => x_46.Frame_sel22_fEqMidR
                , Frame_sel23_fEqHighL => x_46.Frame_sel23_fEqHighL
                , Frame_sel24_fEqHighR => x_46.Frame_sel24_fEqHighR
                , Frame_sel25_fEqHighLpL => x_46.Frame_sel25_fEqHighLpL
                , Frame_sel26_fEqHighLpR => x_46.Frame_sel26_fEqHighLpR
                , Frame_sel27_fAccL => x_46.Frame_sel27_fAccL
                , Frame_sel28_fAccR => x_46.Frame_sel28_fAccR
                , Frame_sel29_fAcc2L => x_46.Frame_sel29_fAcc2L
                , Frame_sel30_fAcc2R => x_46.Frame_sel30_fAcc2R
                , Frame_sel31_fAcc3L => x_46.Frame_sel31_fAcc3L
                , Frame_sel32_fAcc3R => x_46.Frame_sel32_fAcc3R );

  \c$bv_30\ <= (x_46.Frame_sel3_fGate);

  \on_20\ <= (\c$bv_30\(6 downto 6)) = std_logic_vector'("1");

  -- register begin
  ampHpOutPrevR_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ampHpOutPrevR <= to_signed(0,24);
    elsif rising_edge(clk) then
      ampHpOutPrevR <= \c$ampHpOutPrevR_app_arg\;
    end if;
  end process;
  -- register end

  with (ampHighpassPipe(971 downto 971)) select
    \c$ampHpOutPrevR_app_arg\ <= ampHpOutPrevR when "0",
                                 x_45.Frame_sel16_fWetR when others;

  -- register begin
  ampHpOutPrevL_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ampHpOutPrevL <= to_signed(0,24);
    elsif rising_edge(clk) then
      ampHpOutPrevL <= \c$ampHpOutPrevL_app_arg\;
    end if;
  end process;
  -- register end

  with (ampHighpassPipe(971 downto 971)) select
    \c$ampHpOutPrevL_app_arg\ <= ampHpOutPrevL when "0",
                                 x_45.Frame_sel15_fWetL when others;

  -- register begin
  ampHpInPrevR_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ampHpInPrevR <= to_signed(0,24);
    elsif rising_edge(clk) then
      ampHpInPrevR <= \c$ampHpInPrevR_app_arg\;
    end if;
  end process;
  -- register end

  with (ampHighpassPipe(971 downto 971)) select
    \c$ampHpInPrevR_app_arg\ <= ampHpInPrevR when "0",
                                x_45.Frame_sel14_fDryR when others;

  -- register begin
  ampHpInPrevL_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ampHpInPrevL <= to_signed(0,24);
    elsif rising_edge(clk) then
      ampHpInPrevL <= \c$ampHpInPrevL_app_arg\;
    end if;
  end process;
  -- register end

  with (ampHighpassPipe(971 downto 971)) select
    \c$ampHpInPrevL_app_arg\ <= ampHpInPrevL when "0",
                                x_45.Frame_sel13_fDryL when others;

  x_45 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ampHighpassPipe(970 downto 0)));

  x_46 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_19(970 downto 0)));

  -- register begin
  ds1_19_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_19 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_19 <= result_120;
    end if;
  end process;
  -- register end

  with (ds1_20(971 downto 971)) select
    result_120 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                  std_logic_vector'("1" & ((std_logic_vector(result_121.Frame_sel0_fL)
                   & std_logic_vector(result_121.Frame_sel1_fR)
                   & clash_lowpass_fir_types.toSLV(result_121.Frame_sel2_fLast)
                   & result_121.Frame_sel3_fGate
                   & result_121.Frame_sel4_fOd
                   & result_121.Frame_sel5_fDist
                   & result_121.Frame_sel6_fEq
                   & result_121.Frame_sel7_fRat
                   & result_121.Frame_sel8_fAmp
                   & result_121.Frame_sel9_fAmpTone
                   & result_121.Frame_sel10_fCab
                   & result_121.Frame_sel11_fReverb
                   & std_logic_vector(result_121.Frame_sel12_fAddr)
                   & std_logic_vector(result_121.Frame_sel13_fDryL)
                   & std_logic_vector(result_121.Frame_sel14_fDryR)
                   & std_logic_vector(result_121.Frame_sel15_fWetL)
                   & std_logic_vector(result_121.Frame_sel16_fWetR)
                   & std_logic_vector(result_121.Frame_sel17_fFbL)
                   & std_logic_vector(result_121.Frame_sel18_fFbR)
                   & std_logic_vector(result_121.Frame_sel19_fEqLowL)
                   & std_logic_vector(result_121.Frame_sel20_fEqLowR)
                   & std_logic_vector(result_121.Frame_sel21_fEqMidL)
                   & std_logic_vector(result_121.Frame_sel22_fEqMidR)
                   & std_logic_vector(result_121.Frame_sel23_fEqHighL)
                   & std_logic_vector(result_121.Frame_sel24_fEqHighR)
                   & std_logic_vector(result_121.Frame_sel25_fEqHighLpL)
                   & std_logic_vector(result_121.Frame_sel26_fEqHighLpR)
                   & std_logic_vector(result_121.Frame_sel27_fAccL)
                   & std_logic_vector(result_121.Frame_sel28_fAccR)
                   & std_logic_vector(result_121.Frame_sel29_fAcc2L)
                   & std_logic_vector(result_121.Frame_sel30_fAcc2R)
                   & std_logic_vector(result_121.Frame_sel31_fAcc3L)
                   & std_logic_vector(result_121.Frame_sel32_fAcc3R)))) when others;

  result_121 <= ( Frame_sel0_fL => \c$app_arg_162\
                , Frame_sel1_fR => \c$app_arg_157\
                , Frame_sel2_fLast => x_47.Frame_sel2_fLast
                , Frame_sel3_fGate => x_47.Frame_sel3_fGate
                , Frame_sel4_fOd => x_47.Frame_sel4_fOd
                , Frame_sel5_fDist => x_47.Frame_sel5_fDist
                , Frame_sel6_fEq => x_47.Frame_sel6_fEq
                , Frame_sel7_fRat => x_47.Frame_sel7_fRat
                , Frame_sel8_fAmp => x_47.Frame_sel8_fAmp
                , Frame_sel9_fAmpTone => x_47.Frame_sel9_fAmpTone
                , Frame_sel10_fCab => x_47.Frame_sel10_fCab
                , Frame_sel11_fReverb => x_47.Frame_sel11_fReverb
                , Frame_sel12_fAddr => x_47.Frame_sel12_fAddr
                , Frame_sel13_fDryL => x_47.Frame_sel13_fDryL
                , Frame_sel14_fDryR => x_47.Frame_sel14_fDryR
                , Frame_sel15_fWetL => x_47.Frame_sel15_fWetL
                , Frame_sel16_fWetR => x_47.Frame_sel16_fWetR
                , Frame_sel17_fFbL => x_47.Frame_sel17_fFbL
                , Frame_sel18_fFbR => x_47.Frame_sel18_fFbR
                , Frame_sel19_fEqLowL => x_47.Frame_sel19_fEqLowL
                , Frame_sel20_fEqLowR => x_47.Frame_sel20_fEqLowR
                , Frame_sel21_fEqMidL => x_47.Frame_sel21_fEqMidL
                , Frame_sel22_fEqMidR => x_47.Frame_sel22_fEqMidR
                , Frame_sel23_fEqHighL => x_47.Frame_sel23_fEqHighL
                , Frame_sel24_fEqHighR => x_47.Frame_sel24_fEqHighR
                , Frame_sel25_fEqHighLpL => x_47.Frame_sel25_fEqHighLpL
                , Frame_sel26_fEqHighLpR => x_47.Frame_sel26_fEqHighLpR
                , Frame_sel27_fAccL => x_47.Frame_sel27_fAccL
                , Frame_sel28_fAccR => x_47.Frame_sel28_fAccR
                , Frame_sel29_fAcc2L => x_47.Frame_sel29_fAcc2L
                , Frame_sel30_fAcc2R => x_47.Frame_sel30_fAcc2R
                , Frame_sel31_fAcc3L => x_47.Frame_sel31_fAcc3L
                , Frame_sel32_fAcc3R => x_47.Frame_sel32_fAcc3R );

  \c$app_arg_157\ <= result_122 when \on_21\ else
                     x_47.Frame_sel1_fR;

  result_selection_res_60 <= result_123 > to_signed(4194304,24);

  result_122 <= resize((to_signed(4194304,25) + \c$app_arg_158\),24) when result_selection_res_60 else
                \c$case_alt_72\;

  \c$case_alt_selection_res_53\ <= result_123 < to_signed(-4194304,24);

  \c$case_alt_72\ <= resize((to_signed(-4194304,25) + \c$app_arg_159\),24) when \c$case_alt_selection_res_53\ else
                     result_123;

  \c$shI_76\ <= (to_signed(2,64));

  capp_arg_158_shiftR : block
    signal sh_76 : natural;
  begin
    sh_76 <=
        -- pragma translate_off
        natural'high when (\c$shI_76\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_76\);
    \c$app_arg_158\ <= shift_right((\c$app_arg_160\ - to_signed(4194304,25)),sh_76)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$shI_77\ <= (to_signed(2,64));

  capp_arg_159_shiftR : block
    signal sh_77 : natural;
  begin
    sh_77 <=
        -- pragma translate_off
        natural'high when (\c$shI_77\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_77\);
    \c$app_arg_159\ <= shift_right((\c$app_arg_160\ + to_signed(4194304,25)),sh_77)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_160\ <= resize(result_123,25);

  \c$case_alt_selection_res_54\ <= \c$app_arg_161\ < to_signed(-8388608,48);

  \c$case_alt_73\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_54\ else
                     resize(\c$app_arg_161\,24);

  result_selection_res_61 <= \c$app_arg_161\ > to_signed(8388607,48);

  result_123 <= to_signed(8388607,24) when result_selection_res_61 else
                \c$case_alt_73\;

  \c$shI_78\ <= (to_signed(8,64));

  capp_arg_161_shiftR : block
    signal sh_78 : natural;
  begin
    sh_78 <=
        -- pragma translate_off
        natural'high when (\c$shI_78\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_78\);
    \c$app_arg_161\ <= shift_right(((resize((resize(x_47.Frame_sel14_fDryR,48)) * \c$app_arg_168\, 48)) + (resize((resize(x_47.Frame_sel16_fWetR,48)) * \c$app_arg_167\, 48))),sh_78)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_162\ <= result_124 when \on_21\ else
                     x_47.Frame_sel0_fL;

  \c$bv_31\ <= (x_47.Frame_sel3_fGate);

  \on_21\ <= (\c$bv_31\(4 downto 4)) = std_logic_vector'("1");

  result_selection_res_62 <= result_125 > to_signed(4194304,24);

  result_124 <= resize((to_signed(4194304,25) + \c$app_arg_163\),24) when result_selection_res_62 else
                \c$case_alt_74\;

  \c$case_alt_selection_res_55\ <= result_125 < to_signed(-4194304,24);

  \c$case_alt_74\ <= resize((to_signed(-4194304,25) + \c$app_arg_164\),24) when \c$case_alt_selection_res_55\ else
                     result_125;

  \c$shI_79\ <= (to_signed(2,64));

  capp_arg_163_shiftR : block
    signal sh_79 : natural;
  begin
    sh_79 <=
        -- pragma translate_off
        natural'high when (\c$shI_79\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_79\);
    \c$app_arg_163\ <= shift_right((\c$app_arg_165\ - to_signed(4194304,25)),sh_79)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$shI_80\ <= (to_signed(2,64));

  capp_arg_164_shiftR : block
    signal sh_80 : natural;
  begin
    sh_80 <=
        -- pragma translate_off
        natural'high when (\c$shI_80\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_80\);
    \c$app_arg_164\ <= shift_right((\c$app_arg_165\ + to_signed(4194304,25)),sh_80)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_165\ <= resize(result_125,25);

  \c$case_alt_selection_res_56\ <= \c$app_arg_166\ < to_signed(-8388608,48);

  \c$case_alt_75\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_56\ else
                     resize(\c$app_arg_166\,24);

  result_selection_res_63 <= \c$app_arg_166\ > to_signed(8388607,48);

  result_125 <= to_signed(8388607,24) when result_selection_res_63 else
                \c$case_alt_75\;

  \c$shI_81\ <= (to_signed(8,64));

  capp_arg_166_shiftR : block
    signal sh_81 : natural;
  begin
    sh_81 <=
        -- pragma translate_off
        natural'high when (\c$shI_81\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_81\);
    \c$app_arg_166\ <= shift_right(((resize((resize(x_47.Frame_sel13_fDryL,48)) * \c$app_arg_168\, 48)) + (resize((resize(x_47.Frame_sel15_fWetL,48)) * \c$app_arg_167\, 48))),sh_81)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_167\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(mix_0)))))))),48);

  \c$app_arg_168\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(invMix_0)))))))),48);

  invMix_0 <= to_unsigned(255,8) - mix_0;

  \c$bv_32\ <= (x_47.Frame_sel7_fRat);

  mix_0 <= unsigned((\c$bv_32\(31 downto 24)));

  x_47 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_20(970 downto 0)));

  -- register begin
  ds1_20_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_20 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_20 <= result_126;
    end if;
  end process;
  -- register end

  with (ratTonePipe(971 downto 971)) select
    result_126 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                  std_logic_vector'("1" & ((std_logic_vector(result_127.Frame_sel0_fL)
                   & std_logic_vector(result_127.Frame_sel1_fR)
                   & clash_lowpass_fir_types.toSLV(result_127.Frame_sel2_fLast)
                   & result_127.Frame_sel3_fGate
                   & result_127.Frame_sel4_fOd
                   & result_127.Frame_sel5_fDist
                   & result_127.Frame_sel6_fEq
                   & result_127.Frame_sel7_fRat
                   & result_127.Frame_sel8_fAmp
                   & result_127.Frame_sel9_fAmpTone
                   & result_127.Frame_sel10_fCab
                   & result_127.Frame_sel11_fReverb
                   & std_logic_vector(result_127.Frame_sel12_fAddr)
                   & std_logic_vector(result_127.Frame_sel13_fDryL)
                   & std_logic_vector(result_127.Frame_sel14_fDryR)
                   & std_logic_vector(result_127.Frame_sel15_fWetL)
                   & std_logic_vector(result_127.Frame_sel16_fWetR)
                   & std_logic_vector(result_127.Frame_sel17_fFbL)
                   & std_logic_vector(result_127.Frame_sel18_fFbR)
                   & std_logic_vector(result_127.Frame_sel19_fEqLowL)
                   & std_logic_vector(result_127.Frame_sel20_fEqLowR)
                   & std_logic_vector(result_127.Frame_sel21_fEqMidL)
                   & std_logic_vector(result_127.Frame_sel22_fEqMidR)
                   & std_logic_vector(result_127.Frame_sel23_fEqHighL)
                   & std_logic_vector(result_127.Frame_sel24_fEqHighR)
                   & std_logic_vector(result_127.Frame_sel25_fEqHighLpL)
                   & std_logic_vector(result_127.Frame_sel26_fEqHighLpR)
                   & std_logic_vector(result_127.Frame_sel27_fAccL)
                   & std_logic_vector(result_127.Frame_sel28_fAccR)
                   & std_logic_vector(result_127.Frame_sel29_fAcc2L)
                   & std_logic_vector(result_127.Frame_sel30_fAcc2R)
                   & std_logic_vector(result_127.Frame_sel31_fAcc3L)
                   & std_logic_vector(result_127.Frame_sel32_fAcc3R)))) when others;

  result_127 <= ( Frame_sel0_fL => x_48.Frame_sel0_fL
                , Frame_sel1_fR => x_48.Frame_sel1_fR
                , Frame_sel2_fLast => x_48.Frame_sel2_fLast
                , Frame_sel3_fGate => x_48.Frame_sel3_fGate
                , Frame_sel4_fOd => x_48.Frame_sel4_fOd
                , Frame_sel5_fDist => x_48.Frame_sel5_fDist
                , Frame_sel6_fEq => x_48.Frame_sel6_fEq
                , Frame_sel7_fRat => x_48.Frame_sel7_fRat
                , Frame_sel8_fAmp => x_48.Frame_sel8_fAmp
                , Frame_sel9_fAmpTone => x_48.Frame_sel9_fAmpTone
                , Frame_sel10_fCab => x_48.Frame_sel10_fCab
                , Frame_sel11_fReverb => x_48.Frame_sel11_fReverb
                , Frame_sel12_fAddr => x_48.Frame_sel12_fAddr
                , Frame_sel13_fDryL => x_48.Frame_sel13_fDryL
                , Frame_sel14_fDryR => x_48.Frame_sel14_fDryR
                , Frame_sel15_fWetL => \c$app_arg_171\
                , Frame_sel16_fWetR => \c$app_arg_169\
                , Frame_sel17_fFbL => x_48.Frame_sel17_fFbL
                , Frame_sel18_fFbR => x_48.Frame_sel18_fFbR
                , Frame_sel19_fEqLowL => x_48.Frame_sel19_fEqLowL
                , Frame_sel20_fEqLowR => x_48.Frame_sel20_fEqLowR
                , Frame_sel21_fEqMidL => x_48.Frame_sel21_fEqMidL
                , Frame_sel22_fEqMidR => x_48.Frame_sel22_fEqMidR
                , Frame_sel23_fEqHighL => x_48.Frame_sel23_fEqHighL
                , Frame_sel24_fEqHighR => x_48.Frame_sel24_fEqHighR
                , Frame_sel25_fEqHighLpL => x_48.Frame_sel25_fEqHighLpL
                , Frame_sel26_fEqHighLpR => x_48.Frame_sel26_fEqHighLpR
                , Frame_sel27_fAccL => x_48.Frame_sel27_fAccL
                , Frame_sel28_fAccR => x_48.Frame_sel28_fAccR
                , Frame_sel29_fAcc2L => x_48.Frame_sel29_fAcc2L
                , Frame_sel30_fAcc2R => x_48.Frame_sel30_fAcc2R
                , Frame_sel31_fAcc3L => x_48.Frame_sel31_fAcc3L
                , Frame_sel32_fAcc3R => x_48.Frame_sel32_fAcc3R );

  \c$app_arg_169\ <= result_128 when \on_22\ else
                     x_48.Frame_sel1_fR;

  \c$case_alt_selection_res_57\ <= \c$app_arg_170\ < to_signed(-8388608,48);

  \c$case_alt_76\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_57\ else
                     resize(\c$app_arg_170\,24);

  result_selection_res_64 <= \c$app_arg_170\ > to_signed(8388607,48);

  result_128 <= to_signed(8388607,24) when result_selection_res_64 else
                \c$case_alt_76\;

  \c$shI_82\ <= (to_signed(7,64));

  capp_arg_170_shiftR : block
    signal sh_82 : natural;
  begin
    sh_82 <=
        -- pragma translate_off
        natural'high when (\c$shI_82\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_82\);
    \c$app_arg_170\ <= shift_right((resize((resize(x_48.Frame_sel16_fWetR,48)) * \c$app_arg_173\, 48)),sh_82)
        -- pragma translate_off
        when ((to_signed(7,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_171\ <= result_129 when \on_22\ else
                     x_48.Frame_sel0_fL;

  \c$bv_33\ <= (x_48.Frame_sel3_fGate);

  \on_22\ <= (\c$bv_33\(4 downto 4)) = std_logic_vector'("1");

  \c$case_alt_selection_res_58\ <= \c$app_arg_172\ < to_signed(-8388608,48);

  \c$case_alt_77\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_58\ else
                     resize(\c$app_arg_172\,24);

  result_selection_res_65 <= \c$app_arg_172\ > to_signed(8388607,48);

  result_129 <= to_signed(8388607,24) when result_selection_res_65 else
                \c$case_alt_77\;

  \c$shI_83\ <= (to_signed(7,64));

  capp_arg_172_shiftR : block
    signal sh_83 : natural;
  begin
    sh_83 <=
        -- pragma translate_off
        natural'high when (\c$shI_83\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_83\);
    \c$app_arg_172\ <= shift_right((resize((resize(x_48.Frame_sel15_fWetL,48)) * \c$app_arg_173\, 48)),sh_83)
        -- pragma translate_off
        when ((to_signed(7,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_173\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(level_1)))))))),48);

  \c$bv_34\ <= (x_48.Frame_sel7_fRat);

  level_1 <= unsigned((\c$bv_34\(15 downto 8)));

  -- register begin
  ratTonePipe_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ratTonePipe <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ratTonePipe <= result_130;
    end if;
  end process;
  -- register end

  with (ratPostPipe(971 downto 971)) select
    result_130 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                  std_logic_vector'("1" & ((std_logic_vector(result_131.Frame_sel0_fL)
                   & std_logic_vector(result_131.Frame_sel1_fR)
                   & clash_lowpass_fir_types.toSLV(result_131.Frame_sel2_fLast)
                   & result_131.Frame_sel3_fGate
                   & result_131.Frame_sel4_fOd
                   & result_131.Frame_sel5_fDist
                   & result_131.Frame_sel6_fEq
                   & result_131.Frame_sel7_fRat
                   & result_131.Frame_sel8_fAmp
                   & result_131.Frame_sel9_fAmpTone
                   & result_131.Frame_sel10_fCab
                   & result_131.Frame_sel11_fReverb
                   & std_logic_vector(result_131.Frame_sel12_fAddr)
                   & std_logic_vector(result_131.Frame_sel13_fDryL)
                   & std_logic_vector(result_131.Frame_sel14_fDryR)
                   & std_logic_vector(result_131.Frame_sel15_fWetL)
                   & std_logic_vector(result_131.Frame_sel16_fWetR)
                   & std_logic_vector(result_131.Frame_sel17_fFbL)
                   & std_logic_vector(result_131.Frame_sel18_fFbR)
                   & std_logic_vector(result_131.Frame_sel19_fEqLowL)
                   & std_logic_vector(result_131.Frame_sel20_fEqLowR)
                   & std_logic_vector(result_131.Frame_sel21_fEqMidL)
                   & std_logic_vector(result_131.Frame_sel22_fEqMidR)
                   & std_logic_vector(result_131.Frame_sel23_fEqHighL)
                   & std_logic_vector(result_131.Frame_sel24_fEqHighR)
                   & std_logic_vector(result_131.Frame_sel25_fEqHighLpL)
                   & std_logic_vector(result_131.Frame_sel26_fEqHighLpR)
                   & std_logic_vector(result_131.Frame_sel27_fAccL)
                   & std_logic_vector(result_131.Frame_sel28_fAccR)
                   & std_logic_vector(result_131.Frame_sel29_fAcc2L)
                   & std_logic_vector(result_131.Frame_sel30_fAcc2R)
                   & std_logic_vector(result_131.Frame_sel31_fAcc3L)
                   & std_logic_vector(result_131.Frame_sel32_fAcc3R)))) when others;

  alpha_0 <= to_unsigned(224,8) - (resize(\c$alpha_app_arg_0\,8));

  \c$bv_35\ <= (x_49.Frame_sel3_fGate);

  \on_23\ <= (\c$bv_35\(4 downto 4)) = std_logic_vector'("1");

  result_131 <= ( Frame_sel0_fL => x_49.Frame_sel0_fL
                , Frame_sel1_fR => x_49.Frame_sel1_fR
                , Frame_sel2_fLast => x_49.Frame_sel2_fLast
                , Frame_sel3_fGate => x_49.Frame_sel3_fGate
                , Frame_sel4_fOd => x_49.Frame_sel4_fOd
                , Frame_sel5_fDist => x_49.Frame_sel5_fDist
                , Frame_sel6_fEq => x_49.Frame_sel6_fEq
                , Frame_sel7_fRat => x_49.Frame_sel7_fRat
                , Frame_sel8_fAmp => x_49.Frame_sel8_fAmp
                , Frame_sel9_fAmpTone => x_49.Frame_sel9_fAmpTone
                , Frame_sel10_fCab => x_49.Frame_sel10_fCab
                , Frame_sel11_fReverb => x_49.Frame_sel11_fReverb
                , Frame_sel12_fAddr => x_49.Frame_sel12_fAddr
                , Frame_sel13_fDryL => x_49.Frame_sel13_fDryL
                , Frame_sel14_fDryR => x_49.Frame_sel14_fDryR
                , Frame_sel15_fWetL => \c$app_arg_176\
                , Frame_sel16_fWetR => \c$app_arg_174\
                , Frame_sel17_fFbL => x_49.Frame_sel17_fFbL
                , Frame_sel18_fFbR => x_49.Frame_sel18_fFbR
                , Frame_sel19_fEqLowL => x_49.Frame_sel19_fEqLowL
                , Frame_sel20_fEqLowR => x_49.Frame_sel20_fEqLowR
                , Frame_sel21_fEqMidL => x_49.Frame_sel21_fEqMidL
                , Frame_sel22_fEqMidR => x_49.Frame_sel22_fEqMidR
                , Frame_sel23_fEqHighL => x_49.Frame_sel23_fEqHighL
                , Frame_sel24_fEqHighR => x_49.Frame_sel24_fEqHighR
                , Frame_sel25_fEqHighLpL => x_49.Frame_sel25_fEqHighLpL
                , Frame_sel26_fEqHighLpR => x_49.Frame_sel26_fEqHighLpR
                , Frame_sel27_fAccL => x_49.Frame_sel27_fAccL
                , Frame_sel28_fAccR => x_49.Frame_sel28_fAccR
                , Frame_sel29_fAcc2L => x_49.Frame_sel29_fAcc2L
                , Frame_sel30_fAcc2R => x_49.Frame_sel30_fAcc2R
                , Frame_sel31_fAcc3L => x_49.Frame_sel31_fAcc3L
                , Frame_sel32_fAcc3R => x_49.Frame_sel32_fAcc3R );

  \c$app_arg_174\ <= result_132 when \on_23\ else
                     x_49.Frame_sel1_fR;

  \c$shI_84\ <= (to_signed(8,64));

  capp_arg_175_shiftR : block
    signal sh_84 : natural;
  begin
    sh_84 <=
        -- pragma translate_off
        natural'high when (\c$shI_84\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_84\);
    \c$app_arg_175\ <= shift_right(((resize((resize(x_49.Frame_sel16_fWetR,48)) * (resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(alpha_0)))))))),48)), 48)) + (resize((resize(ratTonePrevR,48)) * (resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(gain_9)))))))),48)), 48))),sh_84)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  gain_9 <= to_unsigned(255,8) - alpha_0;

  \c$case_alt_selection_res_59\ <= \c$app_arg_175\ < to_signed(-8388608,48);

  \c$case_alt_78\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_59\ else
                     resize(\c$app_arg_175\,24);

  result_selection_res_66 <= \c$app_arg_175\ > to_signed(8388607,48);

  result_132 <= to_signed(8388607,24) when result_selection_res_66 else
                \c$case_alt_78\;

  \c$app_arg_176\ <= result_133 when \on_23\ else
                     x_49.Frame_sel0_fL;

  \c$shI_85\ <= (to_signed(8,64));

  capp_arg_177_shiftR : block
    signal sh_85 : natural;
  begin
    sh_85 <=
        -- pragma translate_off
        natural'high when (\c$shI_85\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_85\);
    \c$app_arg_177\ <= shift_right(((resize((resize(x_49.Frame_sel15_fWetL,48)) * (resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(alpha_0)))))))),48)), 48)) + (resize((resize(ratTonePrevL,48)) * (resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(gain_10)))))))),48)), 48))),sh_85)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  gain_10 <= to_unsigned(255,8) - alpha_0;

  \c$case_alt_selection_res_60\ <= \c$app_arg_177\ < to_signed(-8388608,48);

  \c$case_alt_79\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_60\ else
                     resize(\c$app_arg_177\,24);

  result_selection_res_67 <= \c$app_arg_177\ > to_signed(8388607,48);

  result_133 <= to_signed(8388607,24) when result_selection_res_67 else
                \c$case_alt_79\;

  \c$bv_36\ <= (x_49.Frame_sel7_fRat);

  \c$shI_86\ <= (to_signed(2,64));

  calpha_app_arg_0_shiftL : block
    signal sh_86 : natural;
  begin
    sh_86 <=
        -- pragma translate_off
        natural'high when (\c$shI_86\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_86\);
    \c$alpha_app_arg_0\ <= shift_right((resize((resize((unsigned((\c$bv_36\(7 downto 0)))),10)) * to_unsigned(3,10), 10)),sh_86)
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

  with (ratTonePipe(971 downto 971)) select
    \c$ratTonePrevR_app_arg\ <= ratTonePrevR when "0",
                                x_48.Frame_sel16_fWetR when others;

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

  with (ratTonePipe(971 downto 971)) select
    \c$ratTonePrevL_app_arg\ <= ratTonePrevL when "0",
                                x_48.Frame_sel15_fWetL when others;

  x_48 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ratTonePipe(970 downto 0)));

  -- register begin
  ratPostPipe_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ratPostPipe <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ratPostPipe <= result_134;
    end if;
  end process;
  -- register end

  with (ds1_21(971 downto 971)) select
    result_134 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                  std_logic_vector'("1" & ((std_logic_vector(result_135.Frame_sel0_fL)
                   & std_logic_vector(result_135.Frame_sel1_fR)
                   & clash_lowpass_fir_types.toSLV(result_135.Frame_sel2_fLast)
                   & result_135.Frame_sel3_fGate
                   & result_135.Frame_sel4_fOd
                   & result_135.Frame_sel5_fDist
                   & result_135.Frame_sel6_fEq
                   & result_135.Frame_sel7_fRat
                   & result_135.Frame_sel8_fAmp
                   & result_135.Frame_sel9_fAmpTone
                   & result_135.Frame_sel10_fCab
                   & result_135.Frame_sel11_fReverb
                   & std_logic_vector(result_135.Frame_sel12_fAddr)
                   & std_logic_vector(result_135.Frame_sel13_fDryL)
                   & std_logic_vector(result_135.Frame_sel14_fDryR)
                   & std_logic_vector(result_135.Frame_sel15_fWetL)
                   & std_logic_vector(result_135.Frame_sel16_fWetR)
                   & std_logic_vector(result_135.Frame_sel17_fFbL)
                   & std_logic_vector(result_135.Frame_sel18_fFbR)
                   & std_logic_vector(result_135.Frame_sel19_fEqLowL)
                   & std_logic_vector(result_135.Frame_sel20_fEqLowR)
                   & std_logic_vector(result_135.Frame_sel21_fEqMidL)
                   & std_logic_vector(result_135.Frame_sel22_fEqMidR)
                   & std_logic_vector(result_135.Frame_sel23_fEqHighL)
                   & std_logic_vector(result_135.Frame_sel24_fEqHighR)
                   & std_logic_vector(result_135.Frame_sel25_fEqHighLpL)
                   & std_logic_vector(result_135.Frame_sel26_fEqHighLpR)
                   & std_logic_vector(result_135.Frame_sel27_fAccL)
                   & std_logic_vector(result_135.Frame_sel28_fAccR)
                   & std_logic_vector(result_135.Frame_sel29_fAcc2L)
                   & std_logic_vector(result_135.Frame_sel30_fAcc2R)
                   & std_logic_vector(result_135.Frame_sel31_fAcc3L)
                   & std_logic_vector(result_135.Frame_sel32_fAcc3R)))) when others;

  \c$bv_37\ <= (x_50.Frame_sel3_fGate);

  \on_24\ <= (\c$bv_37\(4 downto 4)) = std_logic_vector'("1");

  result_135 <= ( Frame_sel0_fL => x_50.Frame_sel0_fL
                , Frame_sel1_fR => x_50.Frame_sel1_fR
                , Frame_sel2_fLast => x_50.Frame_sel2_fLast
                , Frame_sel3_fGate => x_50.Frame_sel3_fGate
                , Frame_sel4_fOd => x_50.Frame_sel4_fOd
                , Frame_sel5_fDist => x_50.Frame_sel5_fDist
                , Frame_sel6_fEq => x_50.Frame_sel6_fEq
                , Frame_sel7_fRat => x_50.Frame_sel7_fRat
                , Frame_sel8_fAmp => x_50.Frame_sel8_fAmp
                , Frame_sel9_fAmpTone => x_50.Frame_sel9_fAmpTone
                , Frame_sel10_fCab => x_50.Frame_sel10_fCab
                , Frame_sel11_fReverb => x_50.Frame_sel11_fReverb
                , Frame_sel12_fAddr => x_50.Frame_sel12_fAddr
                , Frame_sel13_fDryL => x_50.Frame_sel13_fDryL
                , Frame_sel14_fDryR => x_50.Frame_sel14_fDryR
                , Frame_sel15_fWetL => \c$app_arg_180\
                , Frame_sel16_fWetR => \c$app_arg_178\
                , Frame_sel17_fFbL => x_50.Frame_sel17_fFbL
                , Frame_sel18_fFbR => x_50.Frame_sel18_fFbR
                , Frame_sel19_fEqLowL => x_50.Frame_sel19_fEqLowL
                , Frame_sel20_fEqLowR => x_50.Frame_sel20_fEqLowR
                , Frame_sel21_fEqMidL => x_50.Frame_sel21_fEqMidL
                , Frame_sel22_fEqMidR => x_50.Frame_sel22_fEqMidR
                , Frame_sel23_fEqHighL => x_50.Frame_sel23_fEqHighL
                , Frame_sel24_fEqHighR => x_50.Frame_sel24_fEqHighR
                , Frame_sel25_fEqHighLpL => x_50.Frame_sel25_fEqHighLpL
                , Frame_sel26_fEqHighLpR => x_50.Frame_sel26_fEqHighLpR
                , Frame_sel27_fAccL => x_50.Frame_sel27_fAccL
                , Frame_sel28_fAccR => x_50.Frame_sel28_fAccR
                , Frame_sel29_fAcc2L => x_50.Frame_sel29_fAcc2L
                , Frame_sel30_fAcc2R => x_50.Frame_sel30_fAcc2R
                , Frame_sel31_fAcc3L => x_50.Frame_sel31_fAcc3L
                , Frame_sel32_fAcc3R => x_50.Frame_sel32_fAcc3R );

  \c$app_arg_178\ <= result_136 when \on_24\ else
                     x_50.Frame_sel1_fR;

  \c$shI_87\ <= (to_signed(8,64));

  capp_arg_179_shiftR : block
    signal sh_87 : natural;
  begin
    sh_87 <=
        -- pragma translate_off
        natural'high when (\c$shI_87\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_87\);
    \c$app_arg_179\ <= shift_right(((resize((resize(x_50.Frame_sel16_fWetR,48)) * to_signed(192,48), 48)) + (resize((resize(ratPostPrevR,48)) * to_signed(63,48), 48))),sh_87)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_61\ <= \c$app_arg_179\ < to_signed(-8388608,48);

  \c$case_alt_80\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_61\ else
                     resize(\c$app_arg_179\,24);

  result_selection_res_68 <= \c$app_arg_179\ > to_signed(8388607,48);

  result_136 <= to_signed(8388607,24) when result_selection_res_68 else
                \c$case_alt_80\;

  \c$app_arg_180\ <= result_137 when \on_24\ else
                     x_50.Frame_sel0_fL;

  \c$shI_88\ <= (to_signed(8,64));

  capp_arg_181_shiftR : block
    signal sh_88 : natural;
  begin
    sh_88 <=
        -- pragma translate_off
        natural'high when (\c$shI_88\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_88\);
    \c$app_arg_181\ <= shift_right(((resize((resize(x_50.Frame_sel15_fWetL,48)) * to_signed(192,48), 48)) + (resize((resize(ratPostPrevL,48)) * to_signed(63,48), 48))),sh_88)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_62\ <= \c$app_arg_181\ < to_signed(-8388608,48);

  \c$case_alt_81\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_62\ else
                     resize(\c$app_arg_181\,24);

  result_selection_res_69 <= \c$app_arg_181\ > to_signed(8388607,48);

  result_137 <= to_signed(8388607,24) when result_selection_res_69 else
                \c$case_alt_81\;

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

  with (ratPostPipe(971 downto 971)) select
    \c$ratPostPrevR_app_arg\ <= ratPostPrevR when "0",
                                x_49.Frame_sel16_fWetR when others;

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

  with (ratPostPipe(971 downto 971)) select
    \c$ratPostPrevL_app_arg\ <= ratPostPrevL when "0",
                                x_49.Frame_sel15_fWetL when others;

  x_49 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ratPostPipe(970 downto 0)));

  x_50 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_21(970 downto 0)));

  -- register begin
  ds1_21_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_21 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_21 <= result_138;
    end if;
  end process;
  -- register end

  with (ratOpAmpPipe(971 downto 971)) select
    result_138 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                  std_logic_vector'("1" & ((std_logic_vector(result_139.Frame_sel0_fL)
                   & std_logic_vector(result_139.Frame_sel1_fR)
                   & clash_lowpass_fir_types.toSLV(result_139.Frame_sel2_fLast)
                   & result_139.Frame_sel3_fGate
                   & result_139.Frame_sel4_fOd
                   & result_139.Frame_sel5_fDist
                   & result_139.Frame_sel6_fEq
                   & result_139.Frame_sel7_fRat
                   & result_139.Frame_sel8_fAmp
                   & result_139.Frame_sel9_fAmpTone
                   & result_139.Frame_sel10_fCab
                   & result_139.Frame_sel11_fReverb
                   & std_logic_vector(result_139.Frame_sel12_fAddr)
                   & std_logic_vector(result_139.Frame_sel13_fDryL)
                   & std_logic_vector(result_139.Frame_sel14_fDryR)
                   & std_logic_vector(result_139.Frame_sel15_fWetL)
                   & std_logic_vector(result_139.Frame_sel16_fWetR)
                   & std_logic_vector(result_139.Frame_sel17_fFbL)
                   & std_logic_vector(result_139.Frame_sel18_fFbR)
                   & std_logic_vector(result_139.Frame_sel19_fEqLowL)
                   & std_logic_vector(result_139.Frame_sel20_fEqLowR)
                   & std_logic_vector(result_139.Frame_sel21_fEqMidL)
                   & std_logic_vector(result_139.Frame_sel22_fEqMidR)
                   & std_logic_vector(result_139.Frame_sel23_fEqHighL)
                   & std_logic_vector(result_139.Frame_sel24_fEqHighR)
                   & std_logic_vector(result_139.Frame_sel25_fEqHighLpL)
                   & std_logic_vector(result_139.Frame_sel26_fEqHighLpR)
                   & std_logic_vector(result_139.Frame_sel27_fAccL)
                   & std_logic_vector(result_139.Frame_sel28_fAccR)
                   & std_logic_vector(result_139.Frame_sel29_fAcc2L)
                   & std_logic_vector(result_139.Frame_sel30_fAcc2R)
                   & std_logic_vector(result_139.Frame_sel31_fAcc3L)
                   & std_logic_vector(result_139.Frame_sel32_fAcc3R)))) when others;

  threshold <= resize(result_142,24);

  \c$bv_38\ <= (x_52.Frame_sel3_fGate);

  \on_25\ <= (\c$bv_38\(4 downto 4)) = std_logic_vector'("1");

  result_139 <= ( Frame_sel0_fL => x_52.Frame_sel0_fL
                , Frame_sel1_fR => x_52.Frame_sel1_fR
                , Frame_sel2_fLast => x_52.Frame_sel2_fLast
                , Frame_sel3_fGate => x_52.Frame_sel3_fGate
                , Frame_sel4_fOd => x_52.Frame_sel4_fOd
                , Frame_sel5_fDist => x_52.Frame_sel5_fDist
                , Frame_sel6_fEq => x_52.Frame_sel6_fEq
                , Frame_sel7_fRat => x_52.Frame_sel7_fRat
                , Frame_sel8_fAmp => x_52.Frame_sel8_fAmp
                , Frame_sel9_fAmpTone => x_52.Frame_sel9_fAmpTone
                , Frame_sel10_fCab => x_52.Frame_sel10_fCab
                , Frame_sel11_fReverb => x_52.Frame_sel11_fReverb
                , Frame_sel12_fAddr => x_52.Frame_sel12_fAddr
                , Frame_sel13_fDryL => x_52.Frame_sel13_fDryL
                , Frame_sel14_fDryR => x_52.Frame_sel14_fDryR
                , Frame_sel15_fWetL => \c$app_arg_184\
                , Frame_sel16_fWetR => \c$app_arg_182\
                , Frame_sel17_fFbL => x_52.Frame_sel17_fFbL
                , Frame_sel18_fFbR => x_52.Frame_sel18_fFbR
                , Frame_sel19_fEqLowL => x_52.Frame_sel19_fEqLowL
                , Frame_sel20_fEqLowR => x_52.Frame_sel20_fEqLowR
                , Frame_sel21_fEqMidL => x_52.Frame_sel21_fEqMidL
                , Frame_sel22_fEqMidR => x_52.Frame_sel22_fEqMidR
                , Frame_sel23_fEqHighL => x_52.Frame_sel23_fEqHighL
                , Frame_sel24_fEqHighR => x_52.Frame_sel24_fEqHighR
                , Frame_sel25_fEqHighLpL => x_52.Frame_sel25_fEqHighLpL
                , Frame_sel26_fEqHighLpR => x_52.Frame_sel26_fEqHighLpR
                , Frame_sel27_fAccL => x_52.Frame_sel27_fAccL
                , Frame_sel28_fAccR => x_52.Frame_sel28_fAccR
                , Frame_sel29_fAcc2L => x_52.Frame_sel29_fAcc2L
                , Frame_sel30_fAcc2R => x_52.Frame_sel30_fAcc2R
                , Frame_sel31_fAcc3L => x_52.Frame_sel31_fAcc3L
                , Frame_sel32_fAcc3R => x_52.Frame_sel32_fAcc3R );

  \c$app_arg_182\ <= result_140 when \on_25\ else
                     x_52.Frame_sel1_fR;

  result_selection_res_70 <= x_52.Frame_sel16_fWetR > threshold;

  result_140 <= threshold when result_selection_res_70 else
                \c$case_alt_82\;

  \c$case_alt_selection_res_63\ <= x_52.Frame_sel16_fWetR < \c$app_arg_183\;

  \c$case_alt_82\ <= \c$app_arg_183\ when \c$case_alt_selection_res_63\ else
                     x_52.Frame_sel16_fWetR;

  \c$app_arg_183\ <= -threshold;

  \c$app_arg_184\ <= result_141 when \on_25\ else
                     x_52.Frame_sel0_fL;

  result_selection_res_71 <= x_52.Frame_sel15_fWetL > threshold;

  result_141 <= threshold when result_selection_res_71 else
                \c$case_alt_83\;

  \c$case_alt_selection_res_64\ <= x_52.Frame_sel15_fWetL < \c$app_arg_185\;

  \c$case_alt_83\ <= \c$app_arg_185\ when \c$case_alt_selection_res_64\ else
                     x_52.Frame_sel15_fWetL;

  \c$app_arg_185\ <= -threshold;

  rawThreshold <= to_signed(6291456,25) - (resize((resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(x_51)))))))),25)) * to_signed(9000,25), 25));

  result_selection_res_72 <= rawThreshold < to_signed(3750000,25);

  result_142 <= to_signed(3750000,25) when result_selection_res_72 else
                rawThreshold;

  \c$bv_39\ <= (x_52.Frame_sel7_fRat);

  x_51 <= unsigned((\c$bv_39\(23 downto 16)));

  -- register begin
  ratOpAmpPipe_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ratOpAmpPipe <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ratOpAmpPipe <= result_143;
    end if;
  end process;
  -- register end

  with (ds1_22(971 downto 971)) select
    result_143 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                  std_logic_vector'("1" & ((std_logic_vector(result_144.Frame_sel0_fL)
                   & std_logic_vector(result_144.Frame_sel1_fR)
                   & clash_lowpass_fir_types.toSLV(result_144.Frame_sel2_fLast)
                   & result_144.Frame_sel3_fGate
                   & result_144.Frame_sel4_fOd
                   & result_144.Frame_sel5_fDist
                   & result_144.Frame_sel6_fEq
                   & result_144.Frame_sel7_fRat
                   & result_144.Frame_sel8_fAmp
                   & result_144.Frame_sel9_fAmpTone
                   & result_144.Frame_sel10_fCab
                   & result_144.Frame_sel11_fReverb
                   & std_logic_vector(result_144.Frame_sel12_fAddr)
                   & std_logic_vector(result_144.Frame_sel13_fDryL)
                   & std_logic_vector(result_144.Frame_sel14_fDryR)
                   & std_logic_vector(result_144.Frame_sel15_fWetL)
                   & std_logic_vector(result_144.Frame_sel16_fWetR)
                   & std_logic_vector(result_144.Frame_sel17_fFbL)
                   & std_logic_vector(result_144.Frame_sel18_fFbR)
                   & std_logic_vector(result_144.Frame_sel19_fEqLowL)
                   & std_logic_vector(result_144.Frame_sel20_fEqLowR)
                   & std_logic_vector(result_144.Frame_sel21_fEqMidL)
                   & std_logic_vector(result_144.Frame_sel22_fEqMidR)
                   & std_logic_vector(result_144.Frame_sel23_fEqHighL)
                   & std_logic_vector(result_144.Frame_sel24_fEqHighR)
                   & std_logic_vector(result_144.Frame_sel25_fEqHighLpL)
                   & std_logic_vector(result_144.Frame_sel26_fEqHighLpR)
                   & std_logic_vector(result_144.Frame_sel27_fAccL)
                   & std_logic_vector(result_144.Frame_sel28_fAccR)
                   & std_logic_vector(result_144.Frame_sel29_fAcc2L)
                   & std_logic_vector(result_144.Frame_sel30_fAcc2R)
                   & std_logic_vector(result_144.Frame_sel31_fAcc3L)
                   & std_logic_vector(result_144.Frame_sel32_fAcc3R)))) when others;

  alpha_1 <= to_unsigned(192,8) - (resize(\c$alpha_app_arg_1\,8));

  \c$bv_40\ <= (x_53.Frame_sel3_fGate);

  \on_26\ <= (\c$bv_40\(4 downto 4)) = std_logic_vector'("1");

  result_144 <= ( Frame_sel0_fL => x_53.Frame_sel0_fL
                , Frame_sel1_fR => x_53.Frame_sel1_fR
                , Frame_sel2_fLast => x_53.Frame_sel2_fLast
                , Frame_sel3_fGate => x_53.Frame_sel3_fGate
                , Frame_sel4_fOd => x_53.Frame_sel4_fOd
                , Frame_sel5_fDist => x_53.Frame_sel5_fDist
                , Frame_sel6_fEq => x_53.Frame_sel6_fEq
                , Frame_sel7_fRat => x_53.Frame_sel7_fRat
                , Frame_sel8_fAmp => x_53.Frame_sel8_fAmp
                , Frame_sel9_fAmpTone => x_53.Frame_sel9_fAmpTone
                , Frame_sel10_fCab => x_53.Frame_sel10_fCab
                , Frame_sel11_fReverb => x_53.Frame_sel11_fReverb
                , Frame_sel12_fAddr => x_53.Frame_sel12_fAddr
                , Frame_sel13_fDryL => x_53.Frame_sel13_fDryL
                , Frame_sel14_fDryR => x_53.Frame_sel14_fDryR
                , Frame_sel15_fWetL => \c$app_arg_188\
                , Frame_sel16_fWetR => \c$app_arg_186\
                , Frame_sel17_fFbL => x_53.Frame_sel17_fFbL
                , Frame_sel18_fFbR => x_53.Frame_sel18_fFbR
                , Frame_sel19_fEqLowL => x_53.Frame_sel19_fEqLowL
                , Frame_sel20_fEqLowR => x_53.Frame_sel20_fEqLowR
                , Frame_sel21_fEqMidL => x_53.Frame_sel21_fEqMidL
                , Frame_sel22_fEqMidR => x_53.Frame_sel22_fEqMidR
                , Frame_sel23_fEqHighL => x_53.Frame_sel23_fEqHighL
                , Frame_sel24_fEqHighR => x_53.Frame_sel24_fEqHighR
                , Frame_sel25_fEqHighLpL => x_53.Frame_sel25_fEqHighLpL
                , Frame_sel26_fEqHighLpR => x_53.Frame_sel26_fEqHighLpR
                , Frame_sel27_fAccL => x_53.Frame_sel27_fAccL
                , Frame_sel28_fAccR => x_53.Frame_sel28_fAccR
                , Frame_sel29_fAcc2L => x_53.Frame_sel29_fAcc2L
                , Frame_sel30_fAcc2R => x_53.Frame_sel30_fAcc2R
                , Frame_sel31_fAcc3L => x_53.Frame_sel31_fAcc3L
                , Frame_sel32_fAcc3R => x_53.Frame_sel32_fAcc3R );

  \c$app_arg_186\ <= result_145 when \on_26\ else
                     x_53.Frame_sel1_fR;

  \c$shI_89\ <= (to_signed(8,64));

  capp_arg_187_shiftR : block
    signal sh_89 : natural;
  begin
    sh_89 <=
        -- pragma translate_off
        natural'high when (\c$shI_89\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_89\);
    \c$app_arg_187\ <= shift_right(((resize((resize(x_53.Frame_sel16_fWetR,48)) * (resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(alpha_1)))))))),48)), 48)) + (resize((resize(ratOpAmpPrevR,48)) * (resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(gain_11)))))))),48)), 48))),sh_89)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  gain_11 <= to_unsigned(255,8) - alpha_1;

  \c$case_alt_selection_res_65\ <= \c$app_arg_187\ < to_signed(-8388608,48);

  \c$case_alt_84\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_65\ else
                     resize(\c$app_arg_187\,24);

  result_selection_res_73 <= \c$app_arg_187\ > to_signed(8388607,48);

  result_145 <= to_signed(8388607,24) when result_selection_res_73 else
                \c$case_alt_84\;

  \c$app_arg_188\ <= result_146 when \on_26\ else
                     x_53.Frame_sel0_fL;

  \c$shI_90\ <= (to_signed(8,64));

  capp_arg_189_shiftR : block
    signal sh_90 : natural;
  begin
    sh_90 <=
        -- pragma translate_off
        natural'high when (\c$shI_90\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_90\);
    \c$app_arg_189\ <= shift_right(((resize((resize(x_53.Frame_sel15_fWetL,48)) * (resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(alpha_1)))))))),48)), 48)) + (resize((resize(ratOpAmpPrevL,48)) * (resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(gain_12)))))))),48)), 48))),sh_90)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  gain_12 <= to_unsigned(255,8) - alpha_1;

  \c$case_alt_selection_res_66\ <= \c$app_arg_189\ < to_signed(-8388608,48);

  \c$case_alt_85\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_66\ else
                     resize(\c$app_arg_189\,24);

  result_selection_res_74 <= \c$app_arg_189\ > to_signed(8388607,48);

  result_146 <= to_signed(8388607,24) when result_selection_res_74 else
                \c$case_alt_85\;

  \c$bv_41\ <= (x_53.Frame_sel7_fRat);

  \c$shI_91\ <= (to_signed(1,64));

  calpha_app_arg_1_shiftL : block
    signal sh_91 : natural;
  begin
    sh_91 <=
        -- pragma translate_off
        natural'high when (\c$shI_91\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_91\);
    \c$alpha_app_arg_1\ <= shift_right((unsigned((\c$bv_41\(23 downto 16)))),sh_91)
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

  with (ratOpAmpPipe(971 downto 971)) select
    \c$ratOpAmpPrevR_app_arg\ <= ratOpAmpPrevR when "0",
                                 x_52.Frame_sel16_fWetR when others;

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

  with (ratOpAmpPipe(971 downto 971)) select
    \c$ratOpAmpPrevL_app_arg\ <= ratOpAmpPrevL when "0",
                                 x_52.Frame_sel15_fWetL when others;

  x_52 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ratOpAmpPipe(970 downto 0)));

  x_53 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_22(970 downto 0)));

  -- register begin
  ds1_22_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_22 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_22 <= result_147;
    end if;
  end process;
  -- register end

  with (ds1_23(971 downto 971)) select
    result_147 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                  std_logic_vector'("1" & ((std_logic_vector(result_150.Frame_sel0_fL)
                   & std_logic_vector(result_150.Frame_sel1_fR)
                   & clash_lowpass_fir_types.toSLV(result_150.Frame_sel2_fLast)
                   & result_150.Frame_sel3_fGate
                   & result_150.Frame_sel4_fOd
                   & result_150.Frame_sel5_fDist
                   & result_150.Frame_sel6_fEq
                   & result_150.Frame_sel7_fRat
                   & result_150.Frame_sel8_fAmp
                   & result_150.Frame_sel9_fAmpTone
                   & result_150.Frame_sel10_fCab
                   & result_150.Frame_sel11_fReverb
                   & std_logic_vector(result_150.Frame_sel12_fAddr)
                   & std_logic_vector(result_150.Frame_sel13_fDryL)
                   & std_logic_vector(result_150.Frame_sel14_fDryR)
                   & std_logic_vector(result_150.Frame_sel15_fWetL)
                   & std_logic_vector(result_150.Frame_sel16_fWetR)
                   & std_logic_vector(result_150.Frame_sel17_fFbL)
                   & std_logic_vector(result_150.Frame_sel18_fFbR)
                   & std_logic_vector(result_150.Frame_sel19_fEqLowL)
                   & std_logic_vector(result_150.Frame_sel20_fEqLowR)
                   & std_logic_vector(result_150.Frame_sel21_fEqMidL)
                   & std_logic_vector(result_150.Frame_sel22_fEqMidR)
                   & std_logic_vector(result_150.Frame_sel23_fEqHighL)
                   & std_logic_vector(result_150.Frame_sel24_fEqHighR)
                   & std_logic_vector(result_150.Frame_sel25_fEqHighLpL)
                   & std_logic_vector(result_150.Frame_sel26_fEqHighLpR)
                   & std_logic_vector(result_150.Frame_sel27_fAccL)
                   & std_logic_vector(result_150.Frame_sel28_fAccR)
                   & std_logic_vector(result_150.Frame_sel29_fAcc2L)
                   & std_logic_vector(result_150.Frame_sel30_fAcc2R)
                   & std_logic_vector(result_150.Frame_sel31_fAcc3L)
                   & std_logic_vector(result_150.Frame_sel32_fAcc3R)))) when others;

  \c$shI_92\ <= (to_signed(8,64));

  capp_arg_190_shiftR : block
    signal sh_92 : natural;
  begin
    sh_92 <=
        -- pragma translate_off
        natural'high when (\c$shI_92\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_92\);
    \c$app_arg_190\ <= shift_right(x_54.Frame_sel27_fAccL,sh_92)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_67\ <= \c$app_arg_190\ < to_signed(-8388608,48);

  \c$case_alt_86\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_67\ else
                     resize(\c$app_arg_190\,24);

  result_selection_res_75 <= \c$app_arg_190\ > to_signed(8388607,48);

  result_148 <= to_signed(8388607,24) when result_selection_res_75 else
                \c$case_alt_86\;

  \c$app_arg_191\ <= result_148 when \on_27\ else
                     x_54.Frame_sel0_fL;

  \c$shI_93\ <= (to_signed(8,64));

  capp_arg_192_shiftR : block
    signal sh_93 : natural;
  begin
    sh_93 <=
        -- pragma translate_off
        natural'high when (\c$shI_93\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_93\);
    \c$app_arg_192\ <= shift_right(x_54.Frame_sel28_fAccR,sh_93)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_68\ <= \c$app_arg_192\ < to_signed(-8388608,48);

  \c$case_alt_87\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_68\ else
                     resize(\c$app_arg_192\,24);

  result_selection_res_76 <= \c$app_arg_192\ > to_signed(8388607,48);

  result_149 <= to_signed(8388607,24) when result_selection_res_76 else
                \c$case_alt_87\;

  \c$app_arg_193\ <= result_149 when \on_27\ else
                     x_54.Frame_sel1_fR;

  result_150 <= ( Frame_sel0_fL => x_54.Frame_sel0_fL
                , Frame_sel1_fR => x_54.Frame_sel1_fR
                , Frame_sel2_fLast => x_54.Frame_sel2_fLast
                , Frame_sel3_fGate => x_54.Frame_sel3_fGate
                , Frame_sel4_fOd => x_54.Frame_sel4_fOd
                , Frame_sel5_fDist => x_54.Frame_sel5_fDist
                , Frame_sel6_fEq => x_54.Frame_sel6_fEq
                , Frame_sel7_fRat => x_54.Frame_sel7_fRat
                , Frame_sel8_fAmp => x_54.Frame_sel8_fAmp
                , Frame_sel9_fAmpTone => x_54.Frame_sel9_fAmpTone
                , Frame_sel10_fCab => x_54.Frame_sel10_fCab
                , Frame_sel11_fReverb => x_54.Frame_sel11_fReverb
                , Frame_sel12_fAddr => x_54.Frame_sel12_fAddr
                , Frame_sel13_fDryL => x_54.Frame_sel13_fDryL
                , Frame_sel14_fDryR => x_54.Frame_sel14_fDryR
                , Frame_sel15_fWetL => \c$app_arg_191\
                , Frame_sel16_fWetR => \c$app_arg_193\
                , Frame_sel17_fFbL => x_54.Frame_sel17_fFbL
                , Frame_sel18_fFbR => x_54.Frame_sel18_fFbR
                , Frame_sel19_fEqLowL => x_54.Frame_sel19_fEqLowL
                , Frame_sel20_fEqLowR => x_54.Frame_sel20_fEqLowR
                , Frame_sel21_fEqMidL => x_54.Frame_sel21_fEqMidL
                , Frame_sel22_fEqMidR => x_54.Frame_sel22_fEqMidR
                , Frame_sel23_fEqHighL => x_54.Frame_sel23_fEqHighL
                , Frame_sel24_fEqHighR => x_54.Frame_sel24_fEqHighR
                , Frame_sel25_fEqHighLpL => x_54.Frame_sel25_fEqHighLpL
                , Frame_sel26_fEqHighLpR => x_54.Frame_sel26_fEqHighLpR
                , Frame_sel27_fAccL => x_54.Frame_sel27_fAccL
                , Frame_sel28_fAccR => x_54.Frame_sel28_fAccR
                , Frame_sel29_fAcc2L => x_54.Frame_sel29_fAcc2L
                , Frame_sel30_fAcc2R => x_54.Frame_sel30_fAcc2R
                , Frame_sel31_fAcc3L => x_54.Frame_sel31_fAcc3L
                , Frame_sel32_fAcc3R => x_54.Frame_sel32_fAcc3R );

  \c$bv_42\ <= (x_54.Frame_sel3_fGate);

  \on_27\ <= (\c$bv_42\(4 downto 4)) = std_logic_vector'("1");

  x_54 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_23(970 downto 0)));

  -- register begin
  ds1_23_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_23 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_23 <= result_151;
    end if;
  end process;
  -- register end

  with (ratHighpassPipe(971 downto 971)) select
    result_151 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                  std_logic_vector'("1" & ((std_logic_vector(result_152.Frame_sel0_fL)
                   & std_logic_vector(result_152.Frame_sel1_fR)
                   & clash_lowpass_fir_types.toSLV(result_152.Frame_sel2_fLast)
                   & result_152.Frame_sel3_fGate
                   & result_152.Frame_sel4_fOd
                   & result_152.Frame_sel5_fDist
                   & result_152.Frame_sel6_fEq
                   & result_152.Frame_sel7_fRat
                   & result_152.Frame_sel8_fAmp
                   & result_152.Frame_sel9_fAmpTone
                   & result_152.Frame_sel10_fCab
                   & result_152.Frame_sel11_fReverb
                   & std_logic_vector(result_152.Frame_sel12_fAddr)
                   & std_logic_vector(result_152.Frame_sel13_fDryL)
                   & std_logic_vector(result_152.Frame_sel14_fDryR)
                   & std_logic_vector(result_152.Frame_sel15_fWetL)
                   & std_logic_vector(result_152.Frame_sel16_fWetR)
                   & std_logic_vector(result_152.Frame_sel17_fFbL)
                   & std_logic_vector(result_152.Frame_sel18_fFbR)
                   & std_logic_vector(result_152.Frame_sel19_fEqLowL)
                   & std_logic_vector(result_152.Frame_sel20_fEqLowR)
                   & std_logic_vector(result_152.Frame_sel21_fEqMidL)
                   & std_logic_vector(result_152.Frame_sel22_fEqMidR)
                   & std_logic_vector(result_152.Frame_sel23_fEqHighL)
                   & std_logic_vector(result_152.Frame_sel24_fEqHighR)
                   & std_logic_vector(result_152.Frame_sel25_fEqHighLpL)
                   & std_logic_vector(result_152.Frame_sel26_fEqHighLpR)
                   & std_logic_vector(result_152.Frame_sel27_fAccL)
                   & std_logic_vector(result_152.Frame_sel28_fAccR)
                   & std_logic_vector(result_152.Frame_sel29_fAcc2L)
                   & std_logic_vector(result_152.Frame_sel30_fAcc2R)
                   & std_logic_vector(result_152.Frame_sel31_fAcc3L)
                   & std_logic_vector(result_152.Frame_sel32_fAcc3R)))) when others;

  result_152 <= ( Frame_sel0_fL => x_57.Frame_sel0_fL
                , Frame_sel1_fR => x_57.Frame_sel1_fR
                , Frame_sel2_fLast => x_57.Frame_sel2_fLast
                , Frame_sel3_fGate => x_57.Frame_sel3_fGate
                , Frame_sel4_fOd => x_57.Frame_sel4_fOd
                , Frame_sel5_fDist => x_57.Frame_sel5_fDist
                , Frame_sel6_fEq => x_57.Frame_sel6_fEq
                , Frame_sel7_fRat => x_57.Frame_sel7_fRat
                , Frame_sel8_fAmp => x_57.Frame_sel8_fAmp
                , Frame_sel9_fAmpTone => x_57.Frame_sel9_fAmpTone
                , Frame_sel10_fCab => x_57.Frame_sel10_fCab
                , Frame_sel11_fReverb => x_57.Frame_sel11_fReverb
                , Frame_sel12_fAddr => x_57.Frame_sel12_fAddr
                , Frame_sel13_fDryL => x_57.Frame_sel13_fDryL
                , Frame_sel14_fDryR => x_57.Frame_sel14_fDryR
                , Frame_sel15_fWetL => x_57.Frame_sel15_fWetL
                , Frame_sel16_fWetR => x_57.Frame_sel16_fWetR
                , Frame_sel17_fFbL => x_57.Frame_sel17_fFbL
                , Frame_sel18_fFbR => x_57.Frame_sel18_fFbR
                , Frame_sel19_fEqLowL => x_57.Frame_sel19_fEqLowL
                , Frame_sel20_fEqLowR => x_57.Frame_sel20_fEqLowR
                , Frame_sel21_fEqMidL => x_57.Frame_sel21_fEqMidL
                , Frame_sel22_fEqMidR => x_57.Frame_sel22_fEqMidR
                , Frame_sel23_fEqHighL => x_57.Frame_sel23_fEqHighL
                , Frame_sel24_fEqHighR => x_57.Frame_sel24_fEqHighR
                , Frame_sel25_fEqHighLpL => x_57.Frame_sel25_fEqHighLpL
                , Frame_sel26_fEqHighLpR => x_57.Frame_sel26_fEqHighLpR
                , Frame_sel27_fAccL => \c$app_arg_195\
                , Frame_sel28_fAccR => \c$app_arg_194\
                , Frame_sel29_fAcc2L => x_57.Frame_sel29_fAcc2L
                , Frame_sel30_fAcc2R => x_57.Frame_sel30_fAcc2R
                , Frame_sel31_fAcc3L => x_57.Frame_sel31_fAcc3L
                , Frame_sel32_fAcc3R => x_57.Frame_sel32_fAcc3R );

  \c$app_arg_194\ <= resize((resize(x_57.Frame_sel16_fWetR,48)) * \c$app_arg_196\, 48) when \on_28\ else
                     to_signed(0,48);

  \c$app_arg_195\ <= resize((resize(x_57.Frame_sel15_fWetL,48)) * \c$app_arg_196\, 48) when \on_28\ else
                     to_signed(0,48);

  \c$bv_43\ <= (x_57.Frame_sel3_fGate);

  \on_28\ <= (\c$bv_43\(4 downto 4)) = std_logic_vector'("1");

  \c$app_arg_196\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(driveGain)))))))),48);

  \c$bv_44\ <= (x_57.Frame_sel7_fRat);

  driveGain <= resize((to_unsigned(512,12) + (resize((resize((unsigned((\c$bv_44\(23 downto 16)))),12)) * to_unsigned(14,12), 12))),12);

  -- register begin
  ratHighpassPipe_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ratHighpassPipe <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ratHighpassPipe <= result_153;
    end if;
  end process;
  -- register end

  with (ds1_24(971 downto 971)) select
    result_153 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                  std_logic_vector'("1" & ((std_logic_vector(result_156.Frame_sel0_fL)
                   & std_logic_vector(result_156.Frame_sel1_fR)
                   & clash_lowpass_fir_types.toSLV(result_156.Frame_sel2_fLast)
                   & result_156.Frame_sel3_fGate
                   & result_156.Frame_sel4_fOd
                   & result_156.Frame_sel5_fDist
                   & result_156.Frame_sel6_fEq
                   & result_156.Frame_sel7_fRat
                   & result_156.Frame_sel8_fAmp
                   & result_156.Frame_sel9_fAmpTone
                   & result_156.Frame_sel10_fCab
                   & result_156.Frame_sel11_fReverb
                   & std_logic_vector(result_156.Frame_sel12_fAddr)
                   & std_logic_vector(result_156.Frame_sel13_fDryL)
                   & std_logic_vector(result_156.Frame_sel14_fDryR)
                   & std_logic_vector(result_156.Frame_sel15_fWetL)
                   & std_logic_vector(result_156.Frame_sel16_fWetR)
                   & std_logic_vector(result_156.Frame_sel17_fFbL)
                   & std_logic_vector(result_156.Frame_sel18_fFbR)
                   & std_logic_vector(result_156.Frame_sel19_fEqLowL)
                   & std_logic_vector(result_156.Frame_sel20_fEqLowR)
                   & std_logic_vector(result_156.Frame_sel21_fEqMidL)
                   & std_logic_vector(result_156.Frame_sel22_fEqMidR)
                   & std_logic_vector(result_156.Frame_sel23_fEqHighL)
                   & std_logic_vector(result_156.Frame_sel24_fEqHighR)
                   & std_logic_vector(result_156.Frame_sel25_fEqHighLpL)
                   & std_logic_vector(result_156.Frame_sel26_fEqHighLpR)
                   & std_logic_vector(result_156.Frame_sel27_fAccL)
                   & std_logic_vector(result_156.Frame_sel28_fAccR)
                   & std_logic_vector(result_156.Frame_sel29_fAcc2L)
                   & std_logic_vector(result_156.Frame_sel30_fAcc2R)
                   & std_logic_vector(result_156.Frame_sel31_fAcc3L)
                   & std_logic_vector(result_156.Frame_sel32_fAcc3R)))) when others;

  x_55 <= ((resize(x_58.Frame_sel0_fL,48)) - (resize(ratHpInPrevL,48))) + (resize((resize(ratHpOutPrevL,48)) * to_signed(0,48), 48));

  \c$case_alt_selection_res_69\ <= x_55 < to_signed(-8388608,48);

  \c$case_alt_88\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_69\ else
                     resize(x_55,24);

  result_selection_res_77 <= x_55 > to_signed(8388607,48);

  result_154 <= to_signed(8388607,24) when result_selection_res_77 else
                \c$case_alt_88\;

  \c$app_arg_197\ <= result_154 when \on_29\ else
                     x_58.Frame_sel0_fL;

  x_56 <= ((resize(x_58.Frame_sel1_fR,48)) - (resize(ratHpInPrevR,48))) + (resize((resize(ratHpOutPrevR,48)) * to_signed(0,48), 48));

  \c$case_alt_selection_res_70\ <= x_56 < to_signed(-8388608,48);

  \c$case_alt_89\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_70\ else
                     resize(x_56,24);

  result_selection_res_78 <= x_56 > to_signed(8388607,48);

  result_155 <= to_signed(8388607,24) when result_selection_res_78 else
                \c$case_alt_89\;

  \c$app_arg_198\ <= result_155 when \on_29\ else
                     x_58.Frame_sel1_fR;

  result_156 <= ( Frame_sel0_fL => x_58.Frame_sel0_fL
                , Frame_sel1_fR => x_58.Frame_sel1_fR
                , Frame_sel2_fLast => x_58.Frame_sel2_fLast
                , Frame_sel3_fGate => x_58.Frame_sel3_fGate
                , Frame_sel4_fOd => x_58.Frame_sel4_fOd
                , Frame_sel5_fDist => x_58.Frame_sel5_fDist
                , Frame_sel6_fEq => x_58.Frame_sel6_fEq
                , Frame_sel7_fRat => x_58.Frame_sel7_fRat
                , Frame_sel8_fAmp => x_58.Frame_sel8_fAmp
                , Frame_sel9_fAmpTone => x_58.Frame_sel9_fAmpTone
                , Frame_sel10_fCab => x_58.Frame_sel10_fCab
                , Frame_sel11_fReverb => x_58.Frame_sel11_fReverb
                , Frame_sel12_fAddr => x_58.Frame_sel12_fAddr
                , Frame_sel13_fDryL => x_58.Frame_sel0_fL
                , Frame_sel14_fDryR => x_58.Frame_sel1_fR
                , Frame_sel15_fWetL => \c$app_arg_197\
                , Frame_sel16_fWetR => \c$app_arg_198\
                , Frame_sel17_fFbL => x_58.Frame_sel17_fFbL
                , Frame_sel18_fFbR => x_58.Frame_sel18_fFbR
                , Frame_sel19_fEqLowL => x_58.Frame_sel19_fEqLowL
                , Frame_sel20_fEqLowR => x_58.Frame_sel20_fEqLowR
                , Frame_sel21_fEqMidL => x_58.Frame_sel21_fEqMidL
                , Frame_sel22_fEqMidR => x_58.Frame_sel22_fEqMidR
                , Frame_sel23_fEqHighL => x_58.Frame_sel23_fEqHighL
                , Frame_sel24_fEqHighR => x_58.Frame_sel24_fEqHighR
                , Frame_sel25_fEqHighLpL => x_58.Frame_sel25_fEqHighLpL
                , Frame_sel26_fEqHighLpR => x_58.Frame_sel26_fEqHighLpR
                , Frame_sel27_fAccL => x_58.Frame_sel27_fAccL
                , Frame_sel28_fAccR => x_58.Frame_sel28_fAccR
                , Frame_sel29_fAcc2L => x_58.Frame_sel29_fAcc2L
                , Frame_sel30_fAcc2R => x_58.Frame_sel30_fAcc2R
                , Frame_sel31_fAcc3L => x_58.Frame_sel31_fAcc3L
                , Frame_sel32_fAcc3R => x_58.Frame_sel32_fAcc3R );

  \c$bv_45\ <= (x_58.Frame_sel3_fGate);

  \on_29\ <= (\c$bv_45\(4 downto 4)) = std_logic_vector'("1");

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

  with (ratHighpassPipe(971 downto 971)) select
    \c$ratHpOutPrevR_app_arg\ <= ratHpOutPrevR when "0",
                                 x_57.Frame_sel16_fWetR when others;

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

  with (ratHighpassPipe(971 downto 971)) select
    \c$ratHpOutPrevL_app_arg\ <= ratHpOutPrevL when "0",
                                 x_57.Frame_sel15_fWetL when others;

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

  with (ratHighpassPipe(971 downto 971)) select
    \c$ratHpInPrevR_app_arg\ <= ratHpInPrevR when "0",
                                x_57.Frame_sel14_fDryR when others;

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

  with (ratHighpassPipe(971 downto 971)) select
    \c$ratHpInPrevL_app_arg\ <= ratHpInPrevL when "0",
                                x_57.Frame_sel13_fDryL when others;

  x_57 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ratHighpassPipe(970 downto 0)));

  x_58 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_24(970 downto 0)));

  -- register begin
  ds1_24_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_24 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_24 <= result_157;
    end if;
  end process;
  -- register end

  with (distToneBlendPipe(971 downto 971)) select
    result_157 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                  std_logic_vector'("1" & ((std_logic_vector(result_158.Frame_sel0_fL)
                   & std_logic_vector(result_158.Frame_sel1_fR)
                   & clash_lowpass_fir_types.toSLV(result_158.Frame_sel2_fLast)
                   & result_158.Frame_sel3_fGate
                   & result_158.Frame_sel4_fOd
                   & result_158.Frame_sel5_fDist
                   & result_158.Frame_sel6_fEq
                   & result_158.Frame_sel7_fRat
                   & result_158.Frame_sel8_fAmp
                   & result_158.Frame_sel9_fAmpTone
                   & result_158.Frame_sel10_fCab
                   & result_158.Frame_sel11_fReverb
                   & std_logic_vector(result_158.Frame_sel12_fAddr)
                   & std_logic_vector(result_158.Frame_sel13_fDryL)
                   & std_logic_vector(result_158.Frame_sel14_fDryR)
                   & std_logic_vector(result_158.Frame_sel15_fWetL)
                   & std_logic_vector(result_158.Frame_sel16_fWetR)
                   & std_logic_vector(result_158.Frame_sel17_fFbL)
                   & std_logic_vector(result_158.Frame_sel18_fFbR)
                   & std_logic_vector(result_158.Frame_sel19_fEqLowL)
                   & std_logic_vector(result_158.Frame_sel20_fEqLowR)
                   & std_logic_vector(result_158.Frame_sel21_fEqMidL)
                   & std_logic_vector(result_158.Frame_sel22_fEqMidR)
                   & std_logic_vector(result_158.Frame_sel23_fEqHighL)
                   & std_logic_vector(result_158.Frame_sel24_fEqHighR)
                   & std_logic_vector(result_158.Frame_sel25_fEqHighLpL)
                   & std_logic_vector(result_158.Frame_sel26_fEqHighLpR)
                   & std_logic_vector(result_158.Frame_sel27_fAccL)
                   & std_logic_vector(result_158.Frame_sel28_fAccR)
                   & std_logic_vector(result_158.Frame_sel29_fAcc2L)
                   & std_logic_vector(result_158.Frame_sel30_fAcc2R)
                   & std_logic_vector(result_158.Frame_sel31_fAcc3L)
                   & std_logic_vector(result_158.Frame_sel32_fAcc3R)))) when others;

  result_158 <= ( Frame_sel0_fL => \c$app_arg_201\
                , Frame_sel1_fR => \c$app_arg_199\
                , Frame_sel2_fLast => x_60.Frame_sel2_fLast
                , Frame_sel3_fGate => x_60.Frame_sel3_fGate
                , Frame_sel4_fOd => x_60.Frame_sel4_fOd
                , Frame_sel5_fDist => x_60.Frame_sel5_fDist
                , Frame_sel6_fEq => x_60.Frame_sel6_fEq
                , Frame_sel7_fRat => x_60.Frame_sel7_fRat
                , Frame_sel8_fAmp => x_60.Frame_sel8_fAmp
                , Frame_sel9_fAmpTone => x_60.Frame_sel9_fAmpTone
                , Frame_sel10_fCab => x_60.Frame_sel10_fCab
                , Frame_sel11_fReverb => x_60.Frame_sel11_fReverb
                , Frame_sel12_fAddr => x_60.Frame_sel12_fAddr
                , Frame_sel13_fDryL => x_60.Frame_sel13_fDryL
                , Frame_sel14_fDryR => x_60.Frame_sel14_fDryR
                , Frame_sel15_fWetL => x_60.Frame_sel15_fWetL
                , Frame_sel16_fWetR => x_60.Frame_sel16_fWetR
                , Frame_sel17_fFbL => x_60.Frame_sel17_fFbL
                , Frame_sel18_fFbR => x_60.Frame_sel18_fFbR
                , Frame_sel19_fEqLowL => x_60.Frame_sel19_fEqLowL
                , Frame_sel20_fEqLowR => x_60.Frame_sel20_fEqLowR
                , Frame_sel21_fEqMidL => x_60.Frame_sel21_fEqMidL
                , Frame_sel22_fEqMidR => x_60.Frame_sel22_fEqMidR
                , Frame_sel23_fEqHighL => x_60.Frame_sel23_fEqHighL
                , Frame_sel24_fEqHighR => x_60.Frame_sel24_fEqHighR
                , Frame_sel25_fEqHighLpL => x_60.Frame_sel25_fEqHighLpL
                , Frame_sel26_fEqHighLpR => x_60.Frame_sel26_fEqHighLpR
                , Frame_sel27_fAccL => x_60.Frame_sel27_fAccL
                , Frame_sel28_fAccR => x_60.Frame_sel28_fAccR
                , Frame_sel29_fAcc2L => x_60.Frame_sel29_fAcc2L
                , Frame_sel30_fAcc2R => x_60.Frame_sel30_fAcc2R
                , Frame_sel31_fAcc3L => x_60.Frame_sel31_fAcc3L
                , Frame_sel32_fAcc3R => x_60.Frame_sel32_fAcc3R );

  \c$app_arg_199\ <= result_159 when \on_30\ else
                     x_60.Frame_sel1_fR;

  \c$case_alt_selection_res_71\ <= \c$app_arg_200\ < to_signed(-8388608,48);

  \c$case_alt_90\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_71\ else
                     resize(\c$app_arg_200\,24);

  result_selection_res_79 <= \c$app_arg_200\ > to_signed(8388607,48);

  result_159 <= to_signed(8388607,24) when result_selection_res_79 else
                \c$case_alt_90\;

  \c$shI_94\ <= (to_signed(7,64));

  capp_arg_200_shiftR : block
    signal sh_94 : natural;
  begin
    sh_94 <=
        -- pragma translate_off
        natural'high when (\c$shI_94\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_94\);
    \c$app_arg_200\ <= shift_right((resize((resize(x_60.Frame_sel16_fWetR,48)) * \c$app_arg_203\, 48)),sh_94)
        -- pragma translate_off
        when ((to_signed(7,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_201\ <= result_160 when \on_30\ else
                     x_60.Frame_sel0_fL;

  \c$bv_46\ <= (x_60.Frame_sel3_fGate);

  \on_30\ <= (\c$bv_46\(2 downto 2)) = std_logic_vector'("1");

  \c$case_alt_selection_res_72\ <= \c$app_arg_202\ < to_signed(-8388608,48);

  \c$case_alt_91\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_72\ else
                     resize(\c$app_arg_202\,24);

  result_selection_res_80 <= \c$app_arg_202\ > to_signed(8388607,48);

  result_160 <= to_signed(8388607,24) when result_selection_res_80 else
                \c$case_alt_91\;

  \c$shI_95\ <= (to_signed(7,64));

  capp_arg_202_shiftR : block
    signal sh_95 : natural;
  begin
    sh_95 <=
        -- pragma translate_off
        natural'high when (\c$shI_95\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_95\);
    \c$app_arg_202\ <= shift_right((resize((resize(x_60.Frame_sel15_fWetL,48)) * \c$app_arg_203\, 48)),sh_95)
        -- pragma translate_off
        when ((to_signed(7,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_203\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(level_2)))))))),48);

  \c$bv_47\ <= (x_60.Frame_sel5_fDist);

  level_2 <= unsigned((\c$bv_47\(15 downto 8)));

  -- register begin
  distToneBlendPipe_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      distToneBlendPipe <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      distToneBlendPipe <= result_161;
    end if;
  end process;
  -- register end

  with (ds1_25(971 downto 971)) select
    result_161 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                  std_logic_vector'("1" & ((std_logic_vector(result_164.Frame_sel0_fL)
                   & std_logic_vector(result_164.Frame_sel1_fR)
                   & clash_lowpass_fir_types.toSLV(result_164.Frame_sel2_fLast)
                   & result_164.Frame_sel3_fGate
                   & result_164.Frame_sel4_fOd
                   & result_164.Frame_sel5_fDist
                   & result_164.Frame_sel6_fEq
                   & result_164.Frame_sel7_fRat
                   & result_164.Frame_sel8_fAmp
                   & result_164.Frame_sel9_fAmpTone
                   & result_164.Frame_sel10_fCab
                   & result_164.Frame_sel11_fReverb
                   & std_logic_vector(result_164.Frame_sel12_fAddr)
                   & std_logic_vector(result_164.Frame_sel13_fDryL)
                   & std_logic_vector(result_164.Frame_sel14_fDryR)
                   & std_logic_vector(result_164.Frame_sel15_fWetL)
                   & std_logic_vector(result_164.Frame_sel16_fWetR)
                   & std_logic_vector(result_164.Frame_sel17_fFbL)
                   & std_logic_vector(result_164.Frame_sel18_fFbR)
                   & std_logic_vector(result_164.Frame_sel19_fEqLowL)
                   & std_logic_vector(result_164.Frame_sel20_fEqLowR)
                   & std_logic_vector(result_164.Frame_sel21_fEqMidL)
                   & std_logic_vector(result_164.Frame_sel22_fEqMidR)
                   & std_logic_vector(result_164.Frame_sel23_fEqHighL)
                   & std_logic_vector(result_164.Frame_sel24_fEqHighR)
                   & std_logic_vector(result_164.Frame_sel25_fEqHighLpL)
                   & std_logic_vector(result_164.Frame_sel26_fEqHighLpR)
                   & std_logic_vector(result_164.Frame_sel27_fAccL)
                   & std_logic_vector(result_164.Frame_sel28_fAccR)
                   & std_logic_vector(result_164.Frame_sel29_fAcc2L)
                   & std_logic_vector(result_164.Frame_sel30_fAcc2R)
                   & std_logic_vector(result_164.Frame_sel31_fAcc3L)
                   & std_logic_vector(result_164.Frame_sel32_fAcc3R)))) when others;

  \c$shI_96\ <= (to_signed(8,64));

  capp_arg_204_shiftR : block
    signal sh_96 : natural;
  begin
    sh_96 <=
        -- pragma translate_off
        natural'high when (\c$shI_96\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_96\);
    \c$app_arg_204\ <= shift_right((x_59.Frame_sel27_fAccL + x_59.Frame_sel29_fAcc2L),sh_96)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_73\ <= \c$app_arg_204\ < to_signed(-8388608,48);

  \c$case_alt_92\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_73\ else
                     resize(\c$app_arg_204\,24);

  result_selection_res_81 <= \c$app_arg_204\ > to_signed(8388607,48);

  result_162 <= to_signed(8388607,24) when result_selection_res_81 else
                \c$case_alt_92\;

  \c$app_arg_205\ <= result_162 when \on_31\ else
                     x_59.Frame_sel0_fL;

  \c$shI_97\ <= (to_signed(8,64));

  capp_arg_206_shiftR : block
    signal sh_97 : natural;
  begin
    sh_97 <=
        -- pragma translate_off
        natural'high when (\c$shI_97\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_97\);
    \c$app_arg_206\ <= shift_right((x_59.Frame_sel28_fAccR + x_59.Frame_sel30_fAcc2R),sh_97)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_74\ <= \c$app_arg_206\ < to_signed(-8388608,48);

  \c$case_alt_93\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_74\ else
                     resize(\c$app_arg_206\,24);

  result_selection_res_82 <= \c$app_arg_206\ > to_signed(8388607,48);

  result_163 <= to_signed(8388607,24) when result_selection_res_82 else
                \c$case_alt_93\;

  \c$app_arg_207\ <= result_163 when \on_31\ else
                     x_59.Frame_sel1_fR;

  result_164 <= ( Frame_sel0_fL => x_59.Frame_sel0_fL
                , Frame_sel1_fR => x_59.Frame_sel1_fR
                , Frame_sel2_fLast => x_59.Frame_sel2_fLast
                , Frame_sel3_fGate => x_59.Frame_sel3_fGate
                , Frame_sel4_fOd => x_59.Frame_sel4_fOd
                , Frame_sel5_fDist => x_59.Frame_sel5_fDist
                , Frame_sel6_fEq => x_59.Frame_sel6_fEq
                , Frame_sel7_fRat => x_59.Frame_sel7_fRat
                , Frame_sel8_fAmp => x_59.Frame_sel8_fAmp
                , Frame_sel9_fAmpTone => x_59.Frame_sel9_fAmpTone
                , Frame_sel10_fCab => x_59.Frame_sel10_fCab
                , Frame_sel11_fReverb => x_59.Frame_sel11_fReverb
                , Frame_sel12_fAddr => x_59.Frame_sel12_fAddr
                , Frame_sel13_fDryL => x_59.Frame_sel13_fDryL
                , Frame_sel14_fDryR => x_59.Frame_sel14_fDryR
                , Frame_sel15_fWetL => \c$app_arg_205\
                , Frame_sel16_fWetR => \c$app_arg_207\
                , Frame_sel17_fFbL => x_59.Frame_sel17_fFbL
                , Frame_sel18_fFbR => x_59.Frame_sel18_fFbR
                , Frame_sel19_fEqLowL => x_59.Frame_sel19_fEqLowL
                , Frame_sel20_fEqLowR => x_59.Frame_sel20_fEqLowR
                , Frame_sel21_fEqMidL => x_59.Frame_sel21_fEqMidL
                , Frame_sel22_fEqMidR => x_59.Frame_sel22_fEqMidR
                , Frame_sel23_fEqHighL => x_59.Frame_sel23_fEqHighL
                , Frame_sel24_fEqHighR => x_59.Frame_sel24_fEqHighR
                , Frame_sel25_fEqHighLpL => x_59.Frame_sel25_fEqHighLpL
                , Frame_sel26_fEqHighLpR => x_59.Frame_sel26_fEqHighLpR
                , Frame_sel27_fAccL => x_59.Frame_sel27_fAccL
                , Frame_sel28_fAccR => x_59.Frame_sel28_fAccR
                , Frame_sel29_fAcc2L => x_59.Frame_sel29_fAcc2L
                , Frame_sel30_fAcc2R => x_59.Frame_sel30_fAcc2R
                , Frame_sel31_fAcc3L => x_59.Frame_sel31_fAcc3L
                , Frame_sel32_fAcc3R => x_59.Frame_sel32_fAcc3R );

  \c$bv_48\ <= (x_59.Frame_sel3_fGate);

  \on_31\ <= (\c$bv_48\(2 downto 2)) = std_logic_vector'("1");

  x_59 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_25(970 downto 0)));

  -- register begin
  ds1_25_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_25 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_25 <= result_165;
    end if;
  end process;
  -- register end

  with (ds1_26(971 downto 971)) select
    result_165 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                  std_logic_vector'("1" & ((std_logic_vector(result_166.Frame_sel0_fL)
                   & std_logic_vector(result_166.Frame_sel1_fR)
                   & clash_lowpass_fir_types.toSLV(result_166.Frame_sel2_fLast)
                   & result_166.Frame_sel3_fGate
                   & result_166.Frame_sel4_fOd
                   & result_166.Frame_sel5_fDist
                   & result_166.Frame_sel6_fEq
                   & result_166.Frame_sel7_fRat
                   & result_166.Frame_sel8_fAmp
                   & result_166.Frame_sel9_fAmpTone
                   & result_166.Frame_sel10_fCab
                   & result_166.Frame_sel11_fReverb
                   & std_logic_vector(result_166.Frame_sel12_fAddr)
                   & std_logic_vector(result_166.Frame_sel13_fDryL)
                   & std_logic_vector(result_166.Frame_sel14_fDryR)
                   & std_logic_vector(result_166.Frame_sel15_fWetL)
                   & std_logic_vector(result_166.Frame_sel16_fWetR)
                   & std_logic_vector(result_166.Frame_sel17_fFbL)
                   & std_logic_vector(result_166.Frame_sel18_fFbR)
                   & std_logic_vector(result_166.Frame_sel19_fEqLowL)
                   & std_logic_vector(result_166.Frame_sel20_fEqLowR)
                   & std_logic_vector(result_166.Frame_sel21_fEqMidL)
                   & std_logic_vector(result_166.Frame_sel22_fEqMidR)
                   & std_logic_vector(result_166.Frame_sel23_fEqHighL)
                   & std_logic_vector(result_166.Frame_sel24_fEqHighR)
                   & std_logic_vector(result_166.Frame_sel25_fEqHighLpL)
                   & std_logic_vector(result_166.Frame_sel26_fEqHighLpR)
                   & std_logic_vector(result_166.Frame_sel27_fAccL)
                   & std_logic_vector(result_166.Frame_sel28_fAccR)
                   & std_logic_vector(result_166.Frame_sel29_fAcc2L)
                   & std_logic_vector(result_166.Frame_sel30_fAcc2R)
                   & std_logic_vector(result_166.Frame_sel31_fAcc3L)
                   & std_logic_vector(result_166.Frame_sel32_fAcc3R)))) when others;

  result_166 <= ( Frame_sel0_fL => x_61.Frame_sel0_fL
                , Frame_sel1_fR => x_61.Frame_sel1_fR
                , Frame_sel2_fLast => x_61.Frame_sel2_fLast
                , Frame_sel3_fGate => x_61.Frame_sel3_fGate
                , Frame_sel4_fOd => x_61.Frame_sel4_fOd
                , Frame_sel5_fDist => x_61.Frame_sel5_fDist
                , Frame_sel6_fEq => x_61.Frame_sel6_fEq
                , Frame_sel7_fRat => x_61.Frame_sel7_fRat
                , Frame_sel8_fAmp => x_61.Frame_sel8_fAmp
                , Frame_sel9_fAmpTone => x_61.Frame_sel9_fAmpTone
                , Frame_sel10_fCab => x_61.Frame_sel10_fCab
                , Frame_sel11_fReverb => x_61.Frame_sel11_fReverb
                , Frame_sel12_fAddr => x_61.Frame_sel12_fAddr
                , Frame_sel13_fDryL => x_61.Frame_sel13_fDryL
                , Frame_sel14_fDryR => x_61.Frame_sel14_fDryR
                , Frame_sel15_fWetL => x_61.Frame_sel15_fWetL
                , Frame_sel16_fWetR => x_61.Frame_sel16_fWetR
                , Frame_sel17_fFbL => x_61.Frame_sel17_fFbL
                , Frame_sel18_fFbR => x_61.Frame_sel18_fFbR
                , Frame_sel19_fEqLowL => x_61.Frame_sel19_fEqLowL
                , Frame_sel20_fEqLowR => x_61.Frame_sel20_fEqLowR
                , Frame_sel21_fEqMidL => x_61.Frame_sel21_fEqMidL
                , Frame_sel22_fEqMidR => x_61.Frame_sel22_fEqMidR
                , Frame_sel23_fEqHighL => x_61.Frame_sel23_fEqHighL
                , Frame_sel24_fEqHighR => x_61.Frame_sel24_fEqHighR
                , Frame_sel25_fEqHighLpL => x_61.Frame_sel25_fEqHighLpL
                , Frame_sel26_fEqHighLpR => x_61.Frame_sel26_fEqHighLpR
                , Frame_sel27_fAccL => \c$app_arg_212\
                , Frame_sel28_fAccR => \c$app_arg_211\
                , Frame_sel29_fAcc2L => \c$app_arg_209\
                , Frame_sel30_fAcc2R => \c$app_arg_208\
                , Frame_sel31_fAcc3L => x_61.Frame_sel31_fAcc3L
                , Frame_sel32_fAcc3R => x_61.Frame_sel32_fAcc3R );

  \c$app_arg_208\ <= resize((resize(distTonePrevR,48)) * \c$app_arg_210\, 48) when \on_32\ else
                     to_signed(0,48);

  \c$app_arg_209\ <= resize((resize(distTonePrevL,48)) * \c$app_arg_210\, 48) when \on_32\ else
                     to_signed(0,48);

  \c$app_arg_210\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(toneInv)))))))),48);

  toneInv <= to_unsigned(255,8) - tone;

  \c$app_arg_211\ <= resize((resize(x_61.Frame_sel1_fR,48)) * \c$app_arg_213\, 48) when \on_32\ else
                     to_signed(0,48);

  \c$app_arg_212\ <= resize((resize(x_61.Frame_sel0_fL,48)) * \c$app_arg_213\, 48) when \on_32\ else
                     to_signed(0,48);

  \c$bv_49\ <= (x_61.Frame_sel3_fGate);

  \on_32\ <= (\c$bv_49\(2 downto 2)) = std_logic_vector'("1");

  \c$app_arg_213\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(tone)))))))),48);

  \c$bv_50\ <= (x_61.Frame_sel5_fDist);

  tone <= unsigned((\c$bv_50\(7 downto 0)));

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

  with (distToneBlendPipe(971 downto 971)) select
    \c$distTonePrevR_app_arg\ <= distTonePrevR when "0",
                                 x_60.Frame_sel16_fWetR when others;

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

  with (distToneBlendPipe(971 downto 971)) select
    \c$distTonePrevL_app_arg\ <= distTonePrevL when "0",
                                 x_60.Frame_sel15_fWetL when others;

  x_60 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(distToneBlendPipe(970 downto 0)));

  x_61 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_26(970 downto 0)));

  -- register begin
  ds1_26_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_26 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_26 <= result_167;
    end if;
  end process;
  -- register end

  with (ds1_27(971 downto 971)) select
    result_167 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                  std_logic_vector'("1" & ((std_logic_vector(result_168.Frame_sel0_fL)
                   & std_logic_vector(result_168.Frame_sel1_fR)
                   & clash_lowpass_fir_types.toSLV(result_168.Frame_sel2_fLast)
                   & result_168.Frame_sel3_fGate
                   & result_168.Frame_sel4_fOd
                   & result_168.Frame_sel5_fDist
                   & result_168.Frame_sel6_fEq
                   & result_168.Frame_sel7_fRat
                   & result_168.Frame_sel8_fAmp
                   & result_168.Frame_sel9_fAmpTone
                   & result_168.Frame_sel10_fCab
                   & result_168.Frame_sel11_fReverb
                   & std_logic_vector(result_168.Frame_sel12_fAddr)
                   & std_logic_vector(result_168.Frame_sel13_fDryL)
                   & std_logic_vector(result_168.Frame_sel14_fDryR)
                   & std_logic_vector(result_168.Frame_sel15_fWetL)
                   & std_logic_vector(result_168.Frame_sel16_fWetR)
                   & std_logic_vector(result_168.Frame_sel17_fFbL)
                   & std_logic_vector(result_168.Frame_sel18_fFbR)
                   & std_logic_vector(result_168.Frame_sel19_fEqLowL)
                   & std_logic_vector(result_168.Frame_sel20_fEqLowR)
                   & std_logic_vector(result_168.Frame_sel21_fEqMidL)
                   & std_logic_vector(result_168.Frame_sel22_fEqMidR)
                   & std_logic_vector(result_168.Frame_sel23_fEqHighL)
                   & std_logic_vector(result_168.Frame_sel24_fEqHighR)
                   & std_logic_vector(result_168.Frame_sel25_fEqHighLpL)
                   & std_logic_vector(result_168.Frame_sel26_fEqHighLpR)
                   & std_logic_vector(result_168.Frame_sel27_fAccL)
                   & std_logic_vector(result_168.Frame_sel28_fAccR)
                   & std_logic_vector(result_168.Frame_sel29_fAcc2L)
                   & std_logic_vector(result_168.Frame_sel30_fAcc2R)
                   & std_logic_vector(result_168.Frame_sel31_fAcc3L)
                   & std_logic_vector(result_168.Frame_sel32_fAcc3R)))) when others;

  threshold_0 <= resize(x_62.Frame_sel29_fAcc2L,24);

  \c$bv_51\ <= (x_62.Frame_sel3_fGate);

  \on_33\ <= (\c$bv_51\(2 downto 2)) = std_logic_vector'("1");

  result_168 <= ( Frame_sel0_fL => \c$app_arg_216\
                , Frame_sel1_fR => \c$app_arg_214\
                , Frame_sel2_fLast => x_62.Frame_sel2_fLast
                , Frame_sel3_fGate => x_62.Frame_sel3_fGate
                , Frame_sel4_fOd => x_62.Frame_sel4_fOd
                , Frame_sel5_fDist => x_62.Frame_sel5_fDist
                , Frame_sel6_fEq => x_62.Frame_sel6_fEq
                , Frame_sel7_fRat => x_62.Frame_sel7_fRat
                , Frame_sel8_fAmp => x_62.Frame_sel8_fAmp
                , Frame_sel9_fAmpTone => x_62.Frame_sel9_fAmpTone
                , Frame_sel10_fCab => x_62.Frame_sel10_fCab
                , Frame_sel11_fReverb => x_62.Frame_sel11_fReverb
                , Frame_sel12_fAddr => x_62.Frame_sel12_fAddr
                , Frame_sel13_fDryL => x_62.Frame_sel13_fDryL
                , Frame_sel14_fDryR => x_62.Frame_sel14_fDryR
                , Frame_sel15_fWetL => x_62.Frame_sel15_fWetL
                , Frame_sel16_fWetR => x_62.Frame_sel16_fWetR
                , Frame_sel17_fFbL => x_62.Frame_sel17_fFbL
                , Frame_sel18_fFbR => x_62.Frame_sel18_fFbR
                , Frame_sel19_fEqLowL => x_62.Frame_sel19_fEqLowL
                , Frame_sel20_fEqLowR => x_62.Frame_sel20_fEqLowR
                , Frame_sel21_fEqMidL => x_62.Frame_sel21_fEqMidL
                , Frame_sel22_fEqMidR => x_62.Frame_sel22_fEqMidR
                , Frame_sel23_fEqHighL => x_62.Frame_sel23_fEqHighL
                , Frame_sel24_fEqHighR => x_62.Frame_sel24_fEqHighR
                , Frame_sel25_fEqHighLpL => x_62.Frame_sel25_fEqHighLpL
                , Frame_sel26_fEqHighLpR => x_62.Frame_sel26_fEqHighLpR
                , Frame_sel27_fAccL => x_62.Frame_sel27_fAccL
                , Frame_sel28_fAccR => x_62.Frame_sel28_fAccR
                , Frame_sel29_fAcc2L => x_62.Frame_sel29_fAcc2L
                , Frame_sel30_fAcc2R => x_62.Frame_sel30_fAcc2R
                , Frame_sel31_fAcc3L => x_62.Frame_sel31_fAcc3L
                , Frame_sel32_fAcc3R => x_62.Frame_sel32_fAcc3R );

  \c$app_arg_214\ <= result_169 when \on_33\ else
                     x_62.Frame_sel1_fR;

  result_selection_res_83 <= x_62.Frame_sel16_fWetR > threshold_0;

  result_169 <= threshold_0 when result_selection_res_83 else
                \c$case_alt_94\;

  \c$case_alt_selection_res_75\ <= x_62.Frame_sel16_fWetR < \c$app_arg_215\;

  \c$case_alt_94\ <= \c$app_arg_215\ when \c$case_alt_selection_res_75\ else
                     x_62.Frame_sel16_fWetR;

  \c$app_arg_215\ <= -threshold_0;

  \c$app_arg_216\ <= result_170 when \on_33\ else
                     x_62.Frame_sel0_fL;

  result_selection_res_84 <= x_62.Frame_sel15_fWetL > threshold_0;

  result_170 <= threshold_0 when result_selection_res_84 else
                \c$case_alt_95\;

  \c$case_alt_selection_res_76\ <= x_62.Frame_sel15_fWetL < \c$app_arg_217\;

  \c$case_alt_95\ <= \c$app_arg_217\ when \c$case_alt_selection_res_76\ else
                     x_62.Frame_sel15_fWetL;

  \c$app_arg_217\ <= -threshold_0;

  x_62 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_27(970 downto 0)));

  -- register begin
  ds1_27_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_27 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_27 <= result_171;
    end if;
  end process;
  -- register end

  with (ds1_28(971 downto 971)) select
    result_171 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                  std_logic_vector'("1" & ((std_logic_vector(result_174.Frame_sel0_fL)
                   & std_logic_vector(result_174.Frame_sel1_fR)
                   & clash_lowpass_fir_types.toSLV(result_174.Frame_sel2_fLast)
                   & result_174.Frame_sel3_fGate
                   & result_174.Frame_sel4_fOd
                   & result_174.Frame_sel5_fDist
                   & result_174.Frame_sel6_fEq
                   & result_174.Frame_sel7_fRat
                   & result_174.Frame_sel8_fAmp
                   & result_174.Frame_sel9_fAmpTone
                   & result_174.Frame_sel10_fCab
                   & result_174.Frame_sel11_fReverb
                   & std_logic_vector(result_174.Frame_sel12_fAddr)
                   & std_logic_vector(result_174.Frame_sel13_fDryL)
                   & std_logic_vector(result_174.Frame_sel14_fDryR)
                   & std_logic_vector(result_174.Frame_sel15_fWetL)
                   & std_logic_vector(result_174.Frame_sel16_fWetR)
                   & std_logic_vector(result_174.Frame_sel17_fFbL)
                   & std_logic_vector(result_174.Frame_sel18_fFbR)
                   & std_logic_vector(result_174.Frame_sel19_fEqLowL)
                   & std_logic_vector(result_174.Frame_sel20_fEqLowR)
                   & std_logic_vector(result_174.Frame_sel21_fEqMidL)
                   & std_logic_vector(result_174.Frame_sel22_fEqMidR)
                   & std_logic_vector(result_174.Frame_sel23_fEqHighL)
                   & std_logic_vector(result_174.Frame_sel24_fEqHighR)
                   & std_logic_vector(result_174.Frame_sel25_fEqHighLpL)
                   & std_logic_vector(result_174.Frame_sel26_fEqHighLpR)
                   & std_logic_vector(result_174.Frame_sel27_fAccL)
                   & std_logic_vector(result_174.Frame_sel28_fAccR)
                   & std_logic_vector(result_174.Frame_sel29_fAcc2L)
                   & std_logic_vector(result_174.Frame_sel30_fAcc2R)
                   & std_logic_vector(result_174.Frame_sel31_fAcc3L)
                   & std_logic_vector(result_174.Frame_sel32_fAcc3R)))) when others;

  \c$shI_98\ <= (to_signed(8,64));

  capp_arg_218_shiftR : block
    signal sh_98 : natural;
  begin
    sh_98 <=
        -- pragma translate_off
        natural'high when (\c$shI_98\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_98\);
    \c$app_arg_218\ <= shift_right(x_63.Frame_sel27_fAccL,sh_98)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_77\ <= \c$app_arg_218\ < to_signed(-8388608,48);

  \c$case_alt_96\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_77\ else
                     resize(\c$app_arg_218\,24);

  result_selection_res_85 <= \c$app_arg_218\ > to_signed(8388607,48);

  result_172 <= to_signed(8388607,24) when result_selection_res_85 else
                \c$case_alt_96\;

  \c$app_arg_219\ <= result_172 when \on_34\ else
                     x_63.Frame_sel0_fL;

  \c$shI_99\ <= (to_signed(8,64));

  capp_arg_220_shiftR : block
    signal sh_99 : natural;
  begin
    sh_99 <=
        -- pragma translate_off
        natural'high when (\c$shI_99\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_99\);
    \c$app_arg_220\ <= shift_right(x_63.Frame_sel28_fAccR,sh_99)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_78\ <= \c$app_arg_220\ < to_signed(-8388608,48);

  \c$case_alt_97\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_78\ else
                     resize(\c$app_arg_220\,24);

  result_selection_res_86 <= \c$app_arg_220\ > to_signed(8388607,48);

  result_173 <= to_signed(8388607,24) when result_selection_res_86 else
                \c$case_alt_97\;

  \c$app_arg_221\ <= result_173 when \on_34\ else
                     x_63.Frame_sel1_fR;

  result_174 <= ( Frame_sel0_fL => x_63.Frame_sel0_fL
                , Frame_sel1_fR => x_63.Frame_sel1_fR
                , Frame_sel2_fLast => x_63.Frame_sel2_fLast
                , Frame_sel3_fGate => x_63.Frame_sel3_fGate
                , Frame_sel4_fOd => x_63.Frame_sel4_fOd
                , Frame_sel5_fDist => x_63.Frame_sel5_fDist
                , Frame_sel6_fEq => x_63.Frame_sel6_fEq
                , Frame_sel7_fRat => x_63.Frame_sel7_fRat
                , Frame_sel8_fAmp => x_63.Frame_sel8_fAmp
                , Frame_sel9_fAmpTone => x_63.Frame_sel9_fAmpTone
                , Frame_sel10_fCab => x_63.Frame_sel10_fCab
                , Frame_sel11_fReverb => x_63.Frame_sel11_fReverb
                , Frame_sel12_fAddr => x_63.Frame_sel12_fAddr
                , Frame_sel13_fDryL => x_63.Frame_sel13_fDryL
                , Frame_sel14_fDryR => x_63.Frame_sel14_fDryR
                , Frame_sel15_fWetL => \c$app_arg_219\
                , Frame_sel16_fWetR => \c$app_arg_221\
                , Frame_sel17_fFbL => x_63.Frame_sel17_fFbL
                , Frame_sel18_fFbR => x_63.Frame_sel18_fFbR
                , Frame_sel19_fEqLowL => x_63.Frame_sel19_fEqLowL
                , Frame_sel20_fEqLowR => x_63.Frame_sel20_fEqLowR
                , Frame_sel21_fEqMidL => x_63.Frame_sel21_fEqMidL
                , Frame_sel22_fEqMidR => x_63.Frame_sel22_fEqMidR
                , Frame_sel23_fEqHighL => x_63.Frame_sel23_fEqHighL
                , Frame_sel24_fEqHighR => x_63.Frame_sel24_fEqHighR
                , Frame_sel25_fEqHighLpL => x_63.Frame_sel25_fEqHighLpL
                , Frame_sel26_fEqHighLpR => x_63.Frame_sel26_fEqHighLpR
                , Frame_sel27_fAccL => x_63.Frame_sel27_fAccL
                , Frame_sel28_fAccR => x_63.Frame_sel28_fAccR
                , Frame_sel29_fAcc2L => x_63.Frame_sel29_fAcc2L
                , Frame_sel30_fAcc2R => x_63.Frame_sel30_fAcc2R
                , Frame_sel31_fAcc3L => x_63.Frame_sel31_fAcc3L
                , Frame_sel32_fAcc3R => x_63.Frame_sel32_fAcc3R );

  \c$bv_52\ <= (x_63.Frame_sel3_fGate);

  \on_34\ <= (\c$bv_52\(2 downto 2)) = std_logic_vector'("1");

  x_63 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_28(970 downto 0)));

  -- register begin
  ds1_28_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_28 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_28 <= result_175;
    end if;
  end process;
  -- register end

  with (ds1_29(971 downto 971)) select
    result_175 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                  std_logic_vector'("1" & ((std_logic_vector(result_176.Frame_sel0_fL)
                   & std_logic_vector(result_176.Frame_sel1_fR)
                   & clash_lowpass_fir_types.toSLV(result_176.Frame_sel2_fLast)
                   & result_176.Frame_sel3_fGate
                   & result_176.Frame_sel4_fOd
                   & result_176.Frame_sel5_fDist
                   & result_176.Frame_sel6_fEq
                   & result_176.Frame_sel7_fRat
                   & result_176.Frame_sel8_fAmp
                   & result_176.Frame_sel9_fAmpTone
                   & result_176.Frame_sel10_fCab
                   & result_176.Frame_sel11_fReverb
                   & std_logic_vector(result_176.Frame_sel12_fAddr)
                   & std_logic_vector(result_176.Frame_sel13_fDryL)
                   & std_logic_vector(result_176.Frame_sel14_fDryR)
                   & std_logic_vector(result_176.Frame_sel15_fWetL)
                   & std_logic_vector(result_176.Frame_sel16_fWetR)
                   & std_logic_vector(result_176.Frame_sel17_fFbL)
                   & std_logic_vector(result_176.Frame_sel18_fFbR)
                   & std_logic_vector(result_176.Frame_sel19_fEqLowL)
                   & std_logic_vector(result_176.Frame_sel20_fEqLowR)
                   & std_logic_vector(result_176.Frame_sel21_fEqMidL)
                   & std_logic_vector(result_176.Frame_sel22_fEqMidR)
                   & std_logic_vector(result_176.Frame_sel23_fEqHighL)
                   & std_logic_vector(result_176.Frame_sel24_fEqHighR)
                   & std_logic_vector(result_176.Frame_sel25_fEqHighLpL)
                   & std_logic_vector(result_176.Frame_sel26_fEqHighLpR)
                   & std_logic_vector(result_176.Frame_sel27_fAccL)
                   & std_logic_vector(result_176.Frame_sel28_fAccR)
                   & std_logic_vector(result_176.Frame_sel29_fAcc2L)
                   & std_logic_vector(result_176.Frame_sel30_fAcc2R)
                   & std_logic_vector(result_176.Frame_sel31_fAcc3L)
                   & std_logic_vector(result_176.Frame_sel32_fAcc3R)))) when others;

  result_176 <= ( Frame_sel0_fL => x_64.Frame_sel0_fL
                , Frame_sel1_fR => x_64.Frame_sel1_fR
                , Frame_sel2_fLast => x_64.Frame_sel2_fLast
                , Frame_sel3_fGate => x_64.Frame_sel3_fGate
                , Frame_sel4_fOd => x_64.Frame_sel4_fOd
                , Frame_sel5_fDist => x_64.Frame_sel5_fDist
                , Frame_sel6_fEq => x_64.Frame_sel6_fEq
                , Frame_sel7_fRat => x_64.Frame_sel7_fRat
                , Frame_sel8_fAmp => x_64.Frame_sel8_fAmp
                , Frame_sel9_fAmpTone => x_64.Frame_sel9_fAmpTone
                , Frame_sel10_fCab => x_64.Frame_sel10_fCab
                , Frame_sel11_fReverb => x_64.Frame_sel11_fReverb
                , Frame_sel12_fAddr => x_64.Frame_sel12_fAddr
                , Frame_sel13_fDryL => x_64.Frame_sel13_fDryL
                , Frame_sel14_fDryR => x_64.Frame_sel14_fDryR
                , Frame_sel15_fWetL => x_64.Frame_sel15_fWetL
                , Frame_sel16_fWetR => x_64.Frame_sel16_fWetR
                , Frame_sel17_fFbL => x_64.Frame_sel17_fFbL
                , Frame_sel18_fFbR => x_64.Frame_sel18_fFbR
                , Frame_sel19_fEqLowL => x_64.Frame_sel19_fEqLowL
                , Frame_sel20_fEqLowR => x_64.Frame_sel20_fEqLowR
                , Frame_sel21_fEqMidL => x_64.Frame_sel21_fEqMidL
                , Frame_sel22_fEqMidR => x_64.Frame_sel22_fEqMidR
                , Frame_sel23_fEqHighL => x_64.Frame_sel23_fEqHighL
                , Frame_sel24_fEqHighR => x_64.Frame_sel24_fEqHighR
                , Frame_sel25_fEqHighLpL => x_64.Frame_sel25_fEqHighLpL
                , Frame_sel26_fEqHighLpR => x_64.Frame_sel26_fEqHighLpR
                , Frame_sel27_fAccL => \c$app_arg_223\
                , Frame_sel28_fAccR => \c$app_arg_222\
                , Frame_sel29_fAcc2L => resize((resize(result_177,24)),48)
                , Frame_sel30_fAcc2R => x_64.Frame_sel30_fAcc2R
                , Frame_sel31_fAcc3L => x_64.Frame_sel31_fAcc3L
                , Frame_sel32_fAcc3R => x_64.Frame_sel32_fAcc3R );

  result_selection_res_87 <= rawThreshold_0 < to_signed(1800000,25);

  result_177 <= to_signed(1800000,25) when result_selection_res_87 else
                rawThreshold_0;

  rawThreshold_0 <= to_signed(8388607,25) - (resize((resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(amount)))))))),25)) * to_signed(24000,25), 25));

  \c$app_arg_222\ <= resize((resize(x_64.Frame_sel1_fR,48)) * \c$app_arg_224\, 48) when \on_35\ else
                     to_signed(0,48);

  \c$app_arg_223\ <= resize((resize(x_64.Frame_sel0_fL,48)) * \c$app_arg_224\, 48) when \on_35\ else
                     to_signed(0,48);

  \c$bv_53\ <= (x_64.Frame_sel3_fGate);

  \on_35\ <= (\c$bv_53\(2 downto 2)) = std_logic_vector'("1");

  \c$app_arg_224\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(driveGain_0)))))))),48);

  driveGain_0 <= resize((to_unsigned(256,11) + (resize((resize(amount,11)) * to_unsigned(8,11), 11))),12);

  \c$bv_54\ <= (x_64.Frame_sel5_fDist);

  amount <= unsigned((\c$bv_54\(23 downto 16)));

  x_64 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_29(970 downto 0)));

  -- register begin
  ds1_29_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_29 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_29 <= result_178;
    end if;
  end process;
  -- register end

  with (odToneBlendPipe(971 downto 971)) select
    result_178 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                  std_logic_vector'("1" & ((std_logic_vector(result_179.Frame_sel0_fL)
                   & std_logic_vector(result_179.Frame_sel1_fR)
                   & clash_lowpass_fir_types.toSLV(result_179.Frame_sel2_fLast)
                   & result_179.Frame_sel3_fGate
                   & result_179.Frame_sel4_fOd
                   & result_179.Frame_sel5_fDist
                   & result_179.Frame_sel6_fEq
                   & result_179.Frame_sel7_fRat
                   & result_179.Frame_sel8_fAmp
                   & result_179.Frame_sel9_fAmpTone
                   & result_179.Frame_sel10_fCab
                   & result_179.Frame_sel11_fReverb
                   & std_logic_vector(result_179.Frame_sel12_fAddr)
                   & std_logic_vector(result_179.Frame_sel13_fDryL)
                   & std_logic_vector(result_179.Frame_sel14_fDryR)
                   & std_logic_vector(result_179.Frame_sel15_fWetL)
                   & std_logic_vector(result_179.Frame_sel16_fWetR)
                   & std_logic_vector(result_179.Frame_sel17_fFbL)
                   & std_logic_vector(result_179.Frame_sel18_fFbR)
                   & std_logic_vector(result_179.Frame_sel19_fEqLowL)
                   & std_logic_vector(result_179.Frame_sel20_fEqLowR)
                   & std_logic_vector(result_179.Frame_sel21_fEqMidL)
                   & std_logic_vector(result_179.Frame_sel22_fEqMidR)
                   & std_logic_vector(result_179.Frame_sel23_fEqHighL)
                   & std_logic_vector(result_179.Frame_sel24_fEqHighR)
                   & std_logic_vector(result_179.Frame_sel25_fEqHighLpL)
                   & std_logic_vector(result_179.Frame_sel26_fEqHighLpR)
                   & std_logic_vector(result_179.Frame_sel27_fAccL)
                   & std_logic_vector(result_179.Frame_sel28_fAccR)
                   & std_logic_vector(result_179.Frame_sel29_fAcc2L)
                   & std_logic_vector(result_179.Frame_sel30_fAcc2R)
                   & std_logic_vector(result_179.Frame_sel31_fAcc3L)
                   & std_logic_vector(result_179.Frame_sel32_fAcc3R)))) when others;

  result_179 <= ( Frame_sel0_fL => \c$app_arg_227\
                , Frame_sel1_fR => \c$app_arg_225\
                , Frame_sel2_fLast => x_66.Frame_sel2_fLast
                , Frame_sel3_fGate => x_66.Frame_sel3_fGate
                , Frame_sel4_fOd => x_66.Frame_sel4_fOd
                , Frame_sel5_fDist => x_66.Frame_sel5_fDist
                , Frame_sel6_fEq => x_66.Frame_sel6_fEq
                , Frame_sel7_fRat => x_66.Frame_sel7_fRat
                , Frame_sel8_fAmp => x_66.Frame_sel8_fAmp
                , Frame_sel9_fAmpTone => x_66.Frame_sel9_fAmpTone
                , Frame_sel10_fCab => x_66.Frame_sel10_fCab
                , Frame_sel11_fReverb => x_66.Frame_sel11_fReverb
                , Frame_sel12_fAddr => x_66.Frame_sel12_fAddr
                , Frame_sel13_fDryL => x_66.Frame_sel13_fDryL
                , Frame_sel14_fDryR => x_66.Frame_sel14_fDryR
                , Frame_sel15_fWetL => x_66.Frame_sel15_fWetL
                , Frame_sel16_fWetR => x_66.Frame_sel16_fWetR
                , Frame_sel17_fFbL => x_66.Frame_sel17_fFbL
                , Frame_sel18_fFbR => x_66.Frame_sel18_fFbR
                , Frame_sel19_fEqLowL => x_66.Frame_sel19_fEqLowL
                , Frame_sel20_fEqLowR => x_66.Frame_sel20_fEqLowR
                , Frame_sel21_fEqMidL => x_66.Frame_sel21_fEqMidL
                , Frame_sel22_fEqMidR => x_66.Frame_sel22_fEqMidR
                , Frame_sel23_fEqHighL => x_66.Frame_sel23_fEqHighL
                , Frame_sel24_fEqHighR => x_66.Frame_sel24_fEqHighR
                , Frame_sel25_fEqHighLpL => x_66.Frame_sel25_fEqHighLpL
                , Frame_sel26_fEqHighLpR => x_66.Frame_sel26_fEqHighLpR
                , Frame_sel27_fAccL => x_66.Frame_sel27_fAccL
                , Frame_sel28_fAccR => x_66.Frame_sel28_fAccR
                , Frame_sel29_fAcc2L => x_66.Frame_sel29_fAcc2L
                , Frame_sel30_fAcc2R => x_66.Frame_sel30_fAcc2R
                , Frame_sel31_fAcc3L => x_66.Frame_sel31_fAcc3L
                , Frame_sel32_fAcc3R => x_66.Frame_sel32_fAcc3R );

  \c$app_arg_225\ <= result_180 when \on_36\ else
                     x_66.Frame_sel1_fR;

  \c$case_alt_selection_res_79\ <= \c$app_arg_226\ < to_signed(-8388608,48);

  \c$case_alt_98\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_79\ else
                     resize(\c$app_arg_226\,24);

  result_selection_res_88 <= \c$app_arg_226\ > to_signed(8388607,48);

  result_180 <= to_signed(8388607,24) when result_selection_res_88 else
                \c$case_alt_98\;

  \c$shI_100\ <= (to_signed(7,64));

  capp_arg_226_shiftR : block
    signal sh_100 : natural;
  begin
    sh_100 <=
        -- pragma translate_off
        natural'high when (\c$shI_100\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_100\);
    \c$app_arg_226\ <= shift_right((resize((resize(x_66.Frame_sel16_fWetR,48)) * \c$app_arg_229\, 48)),sh_100)
        -- pragma translate_off
        when ((to_signed(7,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_227\ <= result_181 when \on_36\ else
                     x_66.Frame_sel0_fL;

  \c$bv_55\ <= (x_66.Frame_sel3_fGate);

  \on_36\ <= (\c$bv_55\(1 downto 1)) = std_logic_vector'("1");

  \c$case_alt_selection_res_80\ <= \c$app_arg_228\ < to_signed(-8388608,48);

  \c$case_alt_99\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_80\ else
                     resize(\c$app_arg_228\,24);

  result_selection_res_89 <= \c$app_arg_228\ > to_signed(8388607,48);

  result_181 <= to_signed(8388607,24) when result_selection_res_89 else
                \c$case_alt_99\;

  \c$shI_101\ <= (to_signed(7,64));

  capp_arg_228_shiftR : block
    signal sh_101 : natural;
  begin
    sh_101 <=
        -- pragma translate_off
        natural'high when (\c$shI_101\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_101\);
    \c$app_arg_228\ <= shift_right((resize((resize(x_66.Frame_sel15_fWetL,48)) * \c$app_arg_229\, 48)),sh_101)
        -- pragma translate_off
        when ((to_signed(7,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_229\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(level_3)))))))),48);

  \c$bv_56\ <= (x_66.Frame_sel4_fOd);

  level_3 <= unsigned((\c$bv_56\(15 downto 8)));

  -- register begin
  odToneBlendPipe_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      odToneBlendPipe <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      odToneBlendPipe <= result_182;
    end if;
  end process;
  -- register end

  with (ds1_30(971 downto 971)) select
    result_182 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                  std_logic_vector'("1" & ((std_logic_vector(result_185.Frame_sel0_fL)
                   & std_logic_vector(result_185.Frame_sel1_fR)
                   & clash_lowpass_fir_types.toSLV(result_185.Frame_sel2_fLast)
                   & result_185.Frame_sel3_fGate
                   & result_185.Frame_sel4_fOd
                   & result_185.Frame_sel5_fDist
                   & result_185.Frame_sel6_fEq
                   & result_185.Frame_sel7_fRat
                   & result_185.Frame_sel8_fAmp
                   & result_185.Frame_sel9_fAmpTone
                   & result_185.Frame_sel10_fCab
                   & result_185.Frame_sel11_fReverb
                   & std_logic_vector(result_185.Frame_sel12_fAddr)
                   & std_logic_vector(result_185.Frame_sel13_fDryL)
                   & std_logic_vector(result_185.Frame_sel14_fDryR)
                   & std_logic_vector(result_185.Frame_sel15_fWetL)
                   & std_logic_vector(result_185.Frame_sel16_fWetR)
                   & std_logic_vector(result_185.Frame_sel17_fFbL)
                   & std_logic_vector(result_185.Frame_sel18_fFbR)
                   & std_logic_vector(result_185.Frame_sel19_fEqLowL)
                   & std_logic_vector(result_185.Frame_sel20_fEqLowR)
                   & std_logic_vector(result_185.Frame_sel21_fEqMidL)
                   & std_logic_vector(result_185.Frame_sel22_fEqMidR)
                   & std_logic_vector(result_185.Frame_sel23_fEqHighL)
                   & std_logic_vector(result_185.Frame_sel24_fEqHighR)
                   & std_logic_vector(result_185.Frame_sel25_fEqHighLpL)
                   & std_logic_vector(result_185.Frame_sel26_fEqHighLpR)
                   & std_logic_vector(result_185.Frame_sel27_fAccL)
                   & std_logic_vector(result_185.Frame_sel28_fAccR)
                   & std_logic_vector(result_185.Frame_sel29_fAcc2L)
                   & std_logic_vector(result_185.Frame_sel30_fAcc2R)
                   & std_logic_vector(result_185.Frame_sel31_fAcc3L)
                   & std_logic_vector(result_185.Frame_sel32_fAcc3R)))) when others;

  \c$shI_102\ <= (to_signed(8,64));

  capp_arg_230_shiftR : block
    signal sh_102 : natural;
  begin
    sh_102 <=
        -- pragma translate_off
        natural'high when (\c$shI_102\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_102\);
    \c$app_arg_230\ <= shift_right((x_65.Frame_sel27_fAccL + x_65.Frame_sel29_fAcc2L),sh_102)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_81\ <= \c$app_arg_230\ < to_signed(-8388608,48);

  \c$case_alt_100\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_81\ else
                      resize(\c$app_arg_230\,24);

  result_selection_res_90 <= \c$app_arg_230\ > to_signed(8388607,48);

  result_183 <= to_signed(8388607,24) when result_selection_res_90 else
                \c$case_alt_100\;

  \c$app_arg_231\ <= result_183 when \on_37\ else
                     x_65.Frame_sel0_fL;

  \c$shI_103\ <= (to_signed(8,64));

  capp_arg_232_shiftR : block
    signal sh_103 : natural;
  begin
    sh_103 <=
        -- pragma translate_off
        natural'high when (\c$shI_103\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_103\);
    \c$app_arg_232\ <= shift_right((x_65.Frame_sel28_fAccR + x_65.Frame_sel30_fAcc2R),sh_103)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_82\ <= \c$app_arg_232\ < to_signed(-8388608,48);

  \c$case_alt_101\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_82\ else
                      resize(\c$app_arg_232\,24);

  result_selection_res_91 <= \c$app_arg_232\ > to_signed(8388607,48);

  result_184 <= to_signed(8388607,24) when result_selection_res_91 else
                \c$case_alt_101\;

  \c$app_arg_233\ <= result_184 when \on_37\ else
                     x_65.Frame_sel1_fR;

  result_185 <= ( Frame_sel0_fL => x_65.Frame_sel0_fL
                , Frame_sel1_fR => x_65.Frame_sel1_fR
                , Frame_sel2_fLast => x_65.Frame_sel2_fLast
                , Frame_sel3_fGate => x_65.Frame_sel3_fGate
                , Frame_sel4_fOd => x_65.Frame_sel4_fOd
                , Frame_sel5_fDist => x_65.Frame_sel5_fDist
                , Frame_sel6_fEq => x_65.Frame_sel6_fEq
                , Frame_sel7_fRat => x_65.Frame_sel7_fRat
                , Frame_sel8_fAmp => x_65.Frame_sel8_fAmp
                , Frame_sel9_fAmpTone => x_65.Frame_sel9_fAmpTone
                , Frame_sel10_fCab => x_65.Frame_sel10_fCab
                , Frame_sel11_fReverb => x_65.Frame_sel11_fReverb
                , Frame_sel12_fAddr => x_65.Frame_sel12_fAddr
                , Frame_sel13_fDryL => x_65.Frame_sel13_fDryL
                , Frame_sel14_fDryR => x_65.Frame_sel14_fDryR
                , Frame_sel15_fWetL => \c$app_arg_231\
                , Frame_sel16_fWetR => \c$app_arg_233\
                , Frame_sel17_fFbL => x_65.Frame_sel17_fFbL
                , Frame_sel18_fFbR => x_65.Frame_sel18_fFbR
                , Frame_sel19_fEqLowL => x_65.Frame_sel19_fEqLowL
                , Frame_sel20_fEqLowR => x_65.Frame_sel20_fEqLowR
                , Frame_sel21_fEqMidL => x_65.Frame_sel21_fEqMidL
                , Frame_sel22_fEqMidR => x_65.Frame_sel22_fEqMidR
                , Frame_sel23_fEqHighL => x_65.Frame_sel23_fEqHighL
                , Frame_sel24_fEqHighR => x_65.Frame_sel24_fEqHighR
                , Frame_sel25_fEqHighLpL => x_65.Frame_sel25_fEqHighLpL
                , Frame_sel26_fEqHighLpR => x_65.Frame_sel26_fEqHighLpR
                , Frame_sel27_fAccL => x_65.Frame_sel27_fAccL
                , Frame_sel28_fAccR => x_65.Frame_sel28_fAccR
                , Frame_sel29_fAcc2L => x_65.Frame_sel29_fAcc2L
                , Frame_sel30_fAcc2R => x_65.Frame_sel30_fAcc2R
                , Frame_sel31_fAcc3L => x_65.Frame_sel31_fAcc3L
                , Frame_sel32_fAcc3R => x_65.Frame_sel32_fAcc3R );

  \c$bv_57\ <= (x_65.Frame_sel3_fGate);

  \on_37\ <= (\c$bv_57\(1 downto 1)) = std_logic_vector'("1");

  x_65 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_30(970 downto 0)));

  -- register begin
  ds1_30_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_30 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_30 <= result_186;
    end if;
  end process;
  -- register end

  with (ds1_31(971 downto 971)) select
    result_186 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                  std_logic_vector'("1" & ((std_logic_vector(result_187.Frame_sel0_fL)
                   & std_logic_vector(result_187.Frame_sel1_fR)
                   & clash_lowpass_fir_types.toSLV(result_187.Frame_sel2_fLast)
                   & result_187.Frame_sel3_fGate
                   & result_187.Frame_sel4_fOd
                   & result_187.Frame_sel5_fDist
                   & result_187.Frame_sel6_fEq
                   & result_187.Frame_sel7_fRat
                   & result_187.Frame_sel8_fAmp
                   & result_187.Frame_sel9_fAmpTone
                   & result_187.Frame_sel10_fCab
                   & result_187.Frame_sel11_fReverb
                   & std_logic_vector(result_187.Frame_sel12_fAddr)
                   & std_logic_vector(result_187.Frame_sel13_fDryL)
                   & std_logic_vector(result_187.Frame_sel14_fDryR)
                   & std_logic_vector(result_187.Frame_sel15_fWetL)
                   & std_logic_vector(result_187.Frame_sel16_fWetR)
                   & std_logic_vector(result_187.Frame_sel17_fFbL)
                   & std_logic_vector(result_187.Frame_sel18_fFbR)
                   & std_logic_vector(result_187.Frame_sel19_fEqLowL)
                   & std_logic_vector(result_187.Frame_sel20_fEqLowR)
                   & std_logic_vector(result_187.Frame_sel21_fEqMidL)
                   & std_logic_vector(result_187.Frame_sel22_fEqMidR)
                   & std_logic_vector(result_187.Frame_sel23_fEqHighL)
                   & std_logic_vector(result_187.Frame_sel24_fEqHighR)
                   & std_logic_vector(result_187.Frame_sel25_fEqHighLpL)
                   & std_logic_vector(result_187.Frame_sel26_fEqHighLpR)
                   & std_logic_vector(result_187.Frame_sel27_fAccL)
                   & std_logic_vector(result_187.Frame_sel28_fAccR)
                   & std_logic_vector(result_187.Frame_sel29_fAcc2L)
                   & std_logic_vector(result_187.Frame_sel30_fAcc2R)
                   & std_logic_vector(result_187.Frame_sel31_fAcc3L)
                   & std_logic_vector(result_187.Frame_sel32_fAcc3R)))) when others;

  result_187 <= ( Frame_sel0_fL => x_67.Frame_sel0_fL
                , Frame_sel1_fR => x_67.Frame_sel1_fR
                , Frame_sel2_fLast => x_67.Frame_sel2_fLast
                , Frame_sel3_fGate => x_67.Frame_sel3_fGate
                , Frame_sel4_fOd => x_67.Frame_sel4_fOd
                , Frame_sel5_fDist => x_67.Frame_sel5_fDist
                , Frame_sel6_fEq => x_67.Frame_sel6_fEq
                , Frame_sel7_fRat => x_67.Frame_sel7_fRat
                , Frame_sel8_fAmp => x_67.Frame_sel8_fAmp
                , Frame_sel9_fAmpTone => x_67.Frame_sel9_fAmpTone
                , Frame_sel10_fCab => x_67.Frame_sel10_fCab
                , Frame_sel11_fReverb => x_67.Frame_sel11_fReverb
                , Frame_sel12_fAddr => x_67.Frame_sel12_fAddr
                , Frame_sel13_fDryL => x_67.Frame_sel13_fDryL
                , Frame_sel14_fDryR => x_67.Frame_sel14_fDryR
                , Frame_sel15_fWetL => x_67.Frame_sel15_fWetL
                , Frame_sel16_fWetR => x_67.Frame_sel16_fWetR
                , Frame_sel17_fFbL => x_67.Frame_sel17_fFbL
                , Frame_sel18_fFbR => x_67.Frame_sel18_fFbR
                , Frame_sel19_fEqLowL => x_67.Frame_sel19_fEqLowL
                , Frame_sel20_fEqLowR => x_67.Frame_sel20_fEqLowR
                , Frame_sel21_fEqMidL => x_67.Frame_sel21_fEqMidL
                , Frame_sel22_fEqMidR => x_67.Frame_sel22_fEqMidR
                , Frame_sel23_fEqHighL => x_67.Frame_sel23_fEqHighL
                , Frame_sel24_fEqHighR => x_67.Frame_sel24_fEqHighR
                , Frame_sel25_fEqHighLpL => x_67.Frame_sel25_fEqHighLpL
                , Frame_sel26_fEqHighLpR => x_67.Frame_sel26_fEqHighLpR
                , Frame_sel27_fAccL => \c$app_arg_238\
                , Frame_sel28_fAccR => \c$app_arg_237\
                , Frame_sel29_fAcc2L => \c$app_arg_235\
                , Frame_sel30_fAcc2R => \c$app_arg_234\
                , Frame_sel31_fAcc3L => x_67.Frame_sel31_fAcc3L
                , Frame_sel32_fAcc3R => x_67.Frame_sel32_fAcc3R );

  \c$app_arg_234\ <= resize((resize(odTonePrevR,48)) * \c$app_arg_236\, 48) when \on_38\ else
                     to_signed(0,48);

  \c$app_arg_235\ <= resize((resize(odTonePrevL,48)) * \c$app_arg_236\, 48) when \on_38\ else
                     to_signed(0,48);

  \c$app_arg_236\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(toneInv_0)))))))),48);

  toneInv_0 <= to_unsigned(255,8) - tone_0;

  \c$app_arg_237\ <= resize((resize(x_67.Frame_sel1_fR,48)) * \c$app_arg_239\, 48) when \on_38\ else
                     to_signed(0,48);

  \c$app_arg_238\ <= resize((resize(x_67.Frame_sel0_fL,48)) * \c$app_arg_239\, 48) when \on_38\ else
                     to_signed(0,48);

  \c$bv_58\ <= (x_67.Frame_sel3_fGate);

  \on_38\ <= (\c$bv_58\(1 downto 1)) = std_logic_vector'("1");

  \c$app_arg_239\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(tone_0)))))))),48);

  \c$bv_59\ <= (x_67.Frame_sel4_fOd);

  tone_0 <= unsigned((\c$bv_59\(7 downto 0)));

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

  with (odToneBlendPipe(971 downto 971)) select
    \c$odTonePrevR_app_arg\ <= odTonePrevR when "0",
                               x_66.Frame_sel16_fWetR when others;

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

  with (odToneBlendPipe(971 downto 971)) select
    \c$odTonePrevL_app_arg\ <= odTonePrevL when "0",
                               x_66.Frame_sel15_fWetL when others;

  x_66 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(odToneBlendPipe(970 downto 0)));

  x_67 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_31(970 downto 0)));

  -- register begin
  ds1_31_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_31 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_31 <= result_188;
    end if;
  end process;
  -- register end

  with (ds1_32(971 downto 971)) select
    result_188 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                  std_logic_vector'("1" & ((std_logic_vector(result_189.Frame_sel0_fL)
                   & std_logic_vector(result_189.Frame_sel1_fR)
                   & clash_lowpass_fir_types.toSLV(result_189.Frame_sel2_fLast)
                   & result_189.Frame_sel3_fGate
                   & result_189.Frame_sel4_fOd
                   & result_189.Frame_sel5_fDist
                   & result_189.Frame_sel6_fEq
                   & result_189.Frame_sel7_fRat
                   & result_189.Frame_sel8_fAmp
                   & result_189.Frame_sel9_fAmpTone
                   & result_189.Frame_sel10_fCab
                   & result_189.Frame_sel11_fReverb
                   & std_logic_vector(result_189.Frame_sel12_fAddr)
                   & std_logic_vector(result_189.Frame_sel13_fDryL)
                   & std_logic_vector(result_189.Frame_sel14_fDryR)
                   & std_logic_vector(result_189.Frame_sel15_fWetL)
                   & std_logic_vector(result_189.Frame_sel16_fWetR)
                   & std_logic_vector(result_189.Frame_sel17_fFbL)
                   & std_logic_vector(result_189.Frame_sel18_fFbR)
                   & std_logic_vector(result_189.Frame_sel19_fEqLowL)
                   & std_logic_vector(result_189.Frame_sel20_fEqLowR)
                   & std_logic_vector(result_189.Frame_sel21_fEqMidL)
                   & std_logic_vector(result_189.Frame_sel22_fEqMidR)
                   & std_logic_vector(result_189.Frame_sel23_fEqHighL)
                   & std_logic_vector(result_189.Frame_sel24_fEqHighR)
                   & std_logic_vector(result_189.Frame_sel25_fEqHighLpL)
                   & std_logic_vector(result_189.Frame_sel26_fEqHighLpR)
                   & std_logic_vector(result_189.Frame_sel27_fAccL)
                   & std_logic_vector(result_189.Frame_sel28_fAccR)
                   & std_logic_vector(result_189.Frame_sel29_fAcc2L)
                   & std_logic_vector(result_189.Frame_sel30_fAcc2R)
                   & std_logic_vector(result_189.Frame_sel31_fAcc3L)
                   & std_logic_vector(result_189.Frame_sel32_fAcc3R)))) when others;

  \c$bv_60\ <= (x_68.Frame_sel3_fGate);

  \on_39\ <= (\c$bv_60\(1 downto 1)) = std_logic_vector'("1");

  result_189 <= ( Frame_sel0_fL => \c$app_arg_244\
                , Frame_sel1_fR => \c$app_arg_240\
                , Frame_sel2_fLast => x_68.Frame_sel2_fLast
                , Frame_sel3_fGate => x_68.Frame_sel3_fGate
                , Frame_sel4_fOd => x_68.Frame_sel4_fOd
                , Frame_sel5_fDist => x_68.Frame_sel5_fDist
                , Frame_sel6_fEq => x_68.Frame_sel6_fEq
                , Frame_sel7_fRat => x_68.Frame_sel7_fRat
                , Frame_sel8_fAmp => x_68.Frame_sel8_fAmp
                , Frame_sel9_fAmpTone => x_68.Frame_sel9_fAmpTone
                , Frame_sel10_fCab => x_68.Frame_sel10_fCab
                , Frame_sel11_fReverb => x_68.Frame_sel11_fReverb
                , Frame_sel12_fAddr => x_68.Frame_sel12_fAddr
                , Frame_sel13_fDryL => x_68.Frame_sel13_fDryL
                , Frame_sel14_fDryR => x_68.Frame_sel14_fDryR
                , Frame_sel15_fWetL => x_68.Frame_sel15_fWetL
                , Frame_sel16_fWetR => x_68.Frame_sel16_fWetR
                , Frame_sel17_fFbL => x_68.Frame_sel17_fFbL
                , Frame_sel18_fFbR => x_68.Frame_sel18_fFbR
                , Frame_sel19_fEqLowL => x_68.Frame_sel19_fEqLowL
                , Frame_sel20_fEqLowR => x_68.Frame_sel20_fEqLowR
                , Frame_sel21_fEqMidL => x_68.Frame_sel21_fEqMidL
                , Frame_sel22_fEqMidR => x_68.Frame_sel22_fEqMidR
                , Frame_sel23_fEqHighL => x_68.Frame_sel23_fEqHighL
                , Frame_sel24_fEqHighR => x_68.Frame_sel24_fEqHighR
                , Frame_sel25_fEqHighLpL => x_68.Frame_sel25_fEqHighLpL
                , Frame_sel26_fEqHighLpR => x_68.Frame_sel26_fEqHighLpR
                , Frame_sel27_fAccL => x_68.Frame_sel27_fAccL
                , Frame_sel28_fAccR => x_68.Frame_sel28_fAccR
                , Frame_sel29_fAcc2L => x_68.Frame_sel29_fAcc2L
                , Frame_sel30_fAcc2R => x_68.Frame_sel30_fAcc2R
                , Frame_sel31_fAcc3L => x_68.Frame_sel31_fAcc3L
                , Frame_sel32_fAcc3R => x_68.Frame_sel32_fAcc3R );

  \c$app_arg_240\ <= result_190 when \on_39\ else
                     x_68.Frame_sel1_fR;

  result_selection_res_92 <= x_68.Frame_sel16_fWetR > to_signed(4194304,24);

  result_190 <= resize((to_signed(4194304,25) + \c$app_arg_241\),24) when result_selection_res_92 else
                \c$case_alt_102\;

  \c$case_alt_selection_res_83\ <= x_68.Frame_sel16_fWetR < to_signed(-4194304,24);

  \c$case_alt_102\ <= resize((to_signed(-4194304,25) + \c$app_arg_242\),24) when \c$case_alt_selection_res_83\ else
                      x_68.Frame_sel16_fWetR;

  \c$shI_104\ <= (to_signed(2,64));

  capp_arg_241_shiftR : block
    signal sh_104 : natural;
  begin
    sh_104 <=
        -- pragma translate_off
        natural'high when (\c$shI_104\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_104\);
    \c$app_arg_241\ <= shift_right((\c$app_arg_243\ - to_signed(4194304,25)),sh_104)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$shI_105\ <= (to_signed(2,64));

  capp_arg_242_shiftR : block
    signal sh_105 : natural;
  begin
    sh_105 <=
        -- pragma translate_off
        natural'high when (\c$shI_105\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_105\);
    \c$app_arg_242\ <= shift_right((\c$app_arg_243\ + to_signed(4194304,25)),sh_105)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_243\ <= resize(x_68.Frame_sel16_fWetR,25);

  \c$app_arg_244\ <= result_191 when \on_39\ else
                     x_68.Frame_sel0_fL;

  result_selection_res_93 <= x_68.Frame_sel15_fWetL > to_signed(4194304,24);

  result_191 <= resize((to_signed(4194304,25) + \c$app_arg_245\),24) when result_selection_res_93 else
                \c$case_alt_103\;

  \c$case_alt_selection_res_84\ <= x_68.Frame_sel15_fWetL < to_signed(-4194304,24);

  \c$case_alt_103\ <= resize((to_signed(-4194304,25) + \c$app_arg_246\),24) when \c$case_alt_selection_res_84\ else
                      x_68.Frame_sel15_fWetL;

  \c$shI_106\ <= (to_signed(2,64));

  capp_arg_245_shiftR : block
    signal sh_106 : natural;
  begin
    sh_106 <=
        -- pragma translate_off
        natural'high when (\c$shI_106\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_106\);
    \c$app_arg_245\ <= shift_right((\c$app_arg_247\ - to_signed(4194304,25)),sh_106)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$shI_107\ <= (to_signed(2,64));

  capp_arg_246_shiftR : block
    signal sh_107 : natural;
  begin
    sh_107 <=
        -- pragma translate_off
        natural'high when (\c$shI_107\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_107\);
    \c$app_arg_246\ <= shift_right((\c$app_arg_247\ + to_signed(4194304,25)),sh_107)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_247\ <= resize(x_68.Frame_sel15_fWetL,25);

  x_68 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_32(970 downto 0)));

  -- register begin
  ds1_32_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_32 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_32 <= result_192;
    end if;
  end process;
  -- register end

  with (ds1_33(971 downto 971)) select
    result_192 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                  std_logic_vector'("1" & ((std_logic_vector(result_195.Frame_sel0_fL)
                   & std_logic_vector(result_195.Frame_sel1_fR)
                   & clash_lowpass_fir_types.toSLV(result_195.Frame_sel2_fLast)
                   & result_195.Frame_sel3_fGate
                   & result_195.Frame_sel4_fOd
                   & result_195.Frame_sel5_fDist
                   & result_195.Frame_sel6_fEq
                   & result_195.Frame_sel7_fRat
                   & result_195.Frame_sel8_fAmp
                   & result_195.Frame_sel9_fAmpTone
                   & result_195.Frame_sel10_fCab
                   & result_195.Frame_sel11_fReverb
                   & std_logic_vector(result_195.Frame_sel12_fAddr)
                   & std_logic_vector(result_195.Frame_sel13_fDryL)
                   & std_logic_vector(result_195.Frame_sel14_fDryR)
                   & std_logic_vector(result_195.Frame_sel15_fWetL)
                   & std_logic_vector(result_195.Frame_sel16_fWetR)
                   & std_logic_vector(result_195.Frame_sel17_fFbL)
                   & std_logic_vector(result_195.Frame_sel18_fFbR)
                   & std_logic_vector(result_195.Frame_sel19_fEqLowL)
                   & std_logic_vector(result_195.Frame_sel20_fEqLowR)
                   & std_logic_vector(result_195.Frame_sel21_fEqMidL)
                   & std_logic_vector(result_195.Frame_sel22_fEqMidR)
                   & std_logic_vector(result_195.Frame_sel23_fEqHighL)
                   & std_logic_vector(result_195.Frame_sel24_fEqHighR)
                   & std_logic_vector(result_195.Frame_sel25_fEqHighLpL)
                   & std_logic_vector(result_195.Frame_sel26_fEqHighLpR)
                   & std_logic_vector(result_195.Frame_sel27_fAccL)
                   & std_logic_vector(result_195.Frame_sel28_fAccR)
                   & std_logic_vector(result_195.Frame_sel29_fAcc2L)
                   & std_logic_vector(result_195.Frame_sel30_fAcc2R)
                   & std_logic_vector(result_195.Frame_sel31_fAcc3L)
                   & std_logic_vector(result_195.Frame_sel32_fAcc3R)))) when others;

  \c$shI_108\ <= (to_signed(8,64));

  capp_arg_248_shiftR : block
    signal sh_108 : natural;
  begin
    sh_108 <=
        -- pragma translate_off
        natural'high when (\c$shI_108\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_108\);
    \c$app_arg_248\ <= shift_right(x_69.Frame_sel27_fAccL,sh_108)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_85\ <= \c$app_arg_248\ < to_signed(-8388608,48);

  \c$case_alt_104\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_85\ else
                      resize(\c$app_arg_248\,24);

  result_selection_res_94 <= \c$app_arg_248\ > to_signed(8388607,48);

  result_193 <= to_signed(8388607,24) when result_selection_res_94 else
                \c$case_alt_104\;

  \c$app_arg_249\ <= result_193 when \on_40\ else
                     x_69.Frame_sel0_fL;

  \c$shI_109\ <= (to_signed(8,64));

  capp_arg_250_shiftR : block
    signal sh_109 : natural;
  begin
    sh_109 <=
        -- pragma translate_off
        natural'high when (\c$shI_109\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_109\);
    \c$app_arg_250\ <= shift_right(x_69.Frame_sel28_fAccR,sh_109)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_86\ <= \c$app_arg_250\ < to_signed(-8388608,48);

  \c$case_alt_105\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_86\ else
                      resize(\c$app_arg_250\,24);

  result_selection_res_95 <= \c$app_arg_250\ > to_signed(8388607,48);

  result_194 <= to_signed(8388607,24) when result_selection_res_95 else
                \c$case_alt_105\;

  \c$app_arg_251\ <= result_194 when \on_40\ else
                     x_69.Frame_sel1_fR;

  result_195 <= ( Frame_sel0_fL => x_69.Frame_sel0_fL
                , Frame_sel1_fR => x_69.Frame_sel1_fR
                , Frame_sel2_fLast => x_69.Frame_sel2_fLast
                , Frame_sel3_fGate => x_69.Frame_sel3_fGate
                , Frame_sel4_fOd => x_69.Frame_sel4_fOd
                , Frame_sel5_fDist => x_69.Frame_sel5_fDist
                , Frame_sel6_fEq => x_69.Frame_sel6_fEq
                , Frame_sel7_fRat => x_69.Frame_sel7_fRat
                , Frame_sel8_fAmp => x_69.Frame_sel8_fAmp
                , Frame_sel9_fAmpTone => x_69.Frame_sel9_fAmpTone
                , Frame_sel10_fCab => x_69.Frame_sel10_fCab
                , Frame_sel11_fReverb => x_69.Frame_sel11_fReverb
                , Frame_sel12_fAddr => x_69.Frame_sel12_fAddr
                , Frame_sel13_fDryL => x_69.Frame_sel13_fDryL
                , Frame_sel14_fDryR => x_69.Frame_sel14_fDryR
                , Frame_sel15_fWetL => \c$app_arg_249\
                , Frame_sel16_fWetR => \c$app_arg_251\
                , Frame_sel17_fFbL => x_69.Frame_sel17_fFbL
                , Frame_sel18_fFbR => x_69.Frame_sel18_fFbR
                , Frame_sel19_fEqLowL => x_69.Frame_sel19_fEqLowL
                , Frame_sel20_fEqLowR => x_69.Frame_sel20_fEqLowR
                , Frame_sel21_fEqMidL => x_69.Frame_sel21_fEqMidL
                , Frame_sel22_fEqMidR => x_69.Frame_sel22_fEqMidR
                , Frame_sel23_fEqHighL => x_69.Frame_sel23_fEqHighL
                , Frame_sel24_fEqHighR => x_69.Frame_sel24_fEqHighR
                , Frame_sel25_fEqHighLpL => x_69.Frame_sel25_fEqHighLpL
                , Frame_sel26_fEqHighLpR => x_69.Frame_sel26_fEqHighLpR
                , Frame_sel27_fAccL => x_69.Frame_sel27_fAccL
                , Frame_sel28_fAccR => x_69.Frame_sel28_fAccR
                , Frame_sel29_fAcc2L => x_69.Frame_sel29_fAcc2L
                , Frame_sel30_fAcc2R => x_69.Frame_sel30_fAcc2R
                , Frame_sel31_fAcc3L => x_69.Frame_sel31_fAcc3L
                , Frame_sel32_fAcc3R => x_69.Frame_sel32_fAcc3R );

  \c$bv_61\ <= (x_69.Frame_sel3_fGate);

  \on_40\ <= (\c$bv_61\(1 downto 1)) = std_logic_vector'("1");

  x_69 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_33(970 downto 0)));

  -- register begin
  ds1_33_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_33 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_33 <= result_196;
    end if;
  end process;
  -- register end

  with (ds1_34(971 downto 971)) select
    result_196 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                  std_logic_vector'("1" & ((std_logic_vector(result_197.Frame_sel0_fL)
                   & std_logic_vector(result_197.Frame_sel1_fR)
                   & clash_lowpass_fir_types.toSLV(result_197.Frame_sel2_fLast)
                   & result_197.Frame_sel3_fGate
                   & result_197.Frame_sel4_fOd
                   & result_197.Frame_sel5_fDist
                   & result_197.Frame_sel6_fEq
                   & result_197.Frame_sel7_fRat
                   & result_197.Frame_sel8_fAmp
                   & result_197.Frame_sel9_fAmpTone
                   & result_197.Frame_sel10_fCab
                   & result_197.Frame_sel11_fReverb
                   & std_logic_vector(result_197.Frame_sel12_fAddr)
                   & std_logic_vector(result_197.Frame_sel13_fDryL)
                   & std_logic_vector(result_197.Frame_sel14_fDryR)
                   & std_logic_vector(result_197.Frame_sel15_fWetL)
                   & std_logic_vector(result_197.Frame_sel16_fWetR)
                   & std_logic_vector(result_197.Frame_sel17_fFbL)
                   & std_logic_vector(result_197.Frame_sel18_fFbR)
                   & std_logic_vector(result_197.Frame_sel19_fEqLowL)
                   & std_logic_vector(result_197.Frame_sel20_fEqLowR)
                   & std_logic_vector(result_197.Frame_sel21_fEqMidL)
                   & std_logic_vector(result_197.Frame_sel22_fEqMidR)
                   & std_logic_vector(result_197.Frame_sel23_fEqHighL)
                   & std_logic_vector(result_197.Frame_sel24_fEqHighR)
                   & std_logic_vector(result_197.Frame_sel25_fEqHighLpL)
                   & std_logic_vector(result_197.Frame_sel26_fEqHighLpR)
                   & std_logic_vector(result_197.Frame_sel27_fAccL)
                   & std_logic_vector(result_197.Frame_sel28_fAccR)
                   & std_logic_vector(result_197.Frame_sel29_fAcc2L)
                   & std_logic_vector(result_197.Frame_sel30_fAcc2R)
                   & std_logic_vector(result_197.Frame_sel31_fAcc3L)
                   & std_logic_vector(result_197.Frame_sel32_fAcc3R)))) when others;

  result_197 <= ( Frame_sel0_fL => x_70.Frame_sel0_fL
                , Frame_sel1_fR => x_70.Frame_sel1_fR
                , Frame_sel2_fLast => x_70.Frame_sel2_fLast
                , Frame_sel3_fGate => x_70.Frame_sel3_fGate
                , Frame_sel4_fOd => x_70.Frame_sel4_fOd
                , Frame_sel5_fDist => x_70.Frame_sel5_fDist
                , Frame_sel6_fEq => x_70.Frame_sel6_fEq
                , Frame_sel7_fRat => x_70.Frame_sel7_fRat
                , Frame_sel8_fAmp => x_70.Frame_sel8_fAmp
                , Frame_sel9_fAmpTone => x_70.Frame_sel9_fAmpTone
                , Frame_sel10_fCab => x_70.Frame_sel10_fCab
                , Frame_sel11_fReverb => x_70.Frame_sel11_fReverb
                , Frame_sel12_fAddr => x_70.Frame_sel12_fAddr
                , Frame_sel13_fDryL => x_70.Frame_sel13_fDryL
                , Frame_sel14_fDryR => x_70.Frame_sel14_fDryR
                , Frame_sel15_fWetL => x_70.Frame_sel15_fWetL
                , Frame_sel16_fWetR => x_70.Frame_sel16_fWetR
                , Frame_sel17_fFbL => x_70.Frame_sel17_fFbL
                , Frame_sel18_fFbR => x_70.Frame_sel18_fFbR
                , Frame_sel19_fEqLowL => x_70.Frame_sel19_fEqLowL
                , Frame_sel20_fEqLowR => x_70.Frame_sel20_fEqLowR
                , Frame_sel21_fEqMidL => x_70.Frame_sel21_fEqMidL
                , Frame_sel22_fEqMidR => x_70.Frame_sel22_fEqMidR
                , Frame_sel23_fEqHighL => x_70.Frame_sel23_fEqHighL
                , Frame_sel24_fEqHighR => x_70.Frame_sel24_fEqHighR
                , Frame_sel25_fEqHighLpL => x_70.Frame_sel25_fEqHighLpL
                , Frame_sel26_fEqHighLpR => x_70.Frame_sel26_fEqHighLpR
                , Frame_sel27_fAccL => \c$app_arg_253\
                , Frame_sel28_fAccR => \c$app_arg_252\
                , Frame_sel29_fAcc2L => x_70.Frame_sel29_fAcc2L
                , Frame_sel30_fAcc2R => x_70.Frame_sel30_fAcc2R
                , Frame_sel31_fAcc3L => x_70.Frame_sel31_fAcc3L
                , Frame_sel32_fAcc3R => x_70.Frame_sel32_fAcc3R );

  \c$app_arg_252\ <= resize((resize(x_70.Frame_sel1_fR,48)) * \c$app_arg_254\, 48) when \on_41\ else
                     to_signed(0,48);

  \c$app_arg_253\ <= resize((resize(x_70.Frame_sel0_fL,48)) * \c$app_arg_254\, 48) when \on_41\ else
                     to_signed(0,48);

  \c$bv_62\ <= (x_70.Frame_sel3_fGate);

  \on_41\ <= (\c$bv_62\(1 downto 1)) = std_logic_vector'("1");

  \c$app_arg_254\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(driveGain_1)))))))),48);

  \c$bv_63\ <= (x_70.Frame_sel4_fOd);

  driveGain_1 <= resize((to_unsigned(256,10) + (resize((resize((unsigned((\c$bv_63\(23 downto 16)))),10)) * to_unsigned(4,10), 10))),12);

  x_70 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_34(970 downto 0)));

  -- register begin
  ds1_34_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_34 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_34 <= result_198;
    end if;
  end process;
  -- register end

  with (gateLevelPipe(971 downto 971)) select
    result_198 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                  std_logic_vector'("1" & ((std_logic_vector(result_199.Frame_sel0_fL)
                   & std_logic_vector(result_199.Frame_sel1_fR)
                   & clash_lowpass_fir_types.toSLV(result_199.Frame_sel2_fLast)
                   & result_199.Frame_sel3_fGate
                   & result_199.Frame_sel4_fOd
                   & result_199.Frame_sel5_fDist
                   & result_199.Frame_sel6_fEq
                   & result_199.Frame_sel7_fRat
                   & result_199.Frame_sel8_fAmp
                   & result_199.Frame_sel9_fAmpTone
                   & result_199.Frame_sel10_fCab
                   & result_199.Frame_sel11_fReverb
                   & std_logic_vector(result_199.Frame_sel12_fAddr)
                   & std_logic_vector(result_199.Frame_sel13_fDryL)
                   & std_logic_vector(result_199.Frame_sel14_fDryR)
                   & std_logic_vector(result_199.Frame_sel15_fWetL)
                   & std_logic_vector(result_199.Frame_sel16_fWetR)
                   & std_logic_vector(result_199.Frame_sel17_fFbL)
                   & std_logic_vector(result_199.Frame_sel18_fFbR)
                   & std_logic_vector(result_199.Frame_sel19_fEqLowL)
                   & std_logic_vector(result_199.Frame_sel20_fEqLowR)
                   & std_logic_vector(result_199.Frame_sel21_fEqMidL)
                   & std_logic_vector(result_199.Frame_sel22_fEqMidR)
                   & std_logic_vector(result_199.Frame_sel23_fEqHighL)
                   & std_logic_vector(result_199.Frame_sel24_fEqHighR)
                   & std_logic_vector(result_199.Frame_sel25_fEqHighLpL)
                   & std_logic_vector(result_199.Frame_sel26_fEqHighLpR)
                   & std_logic_vector(result_199.Frame_sel27_fAccL)
                   & std_logic_vector(result_199.Frame_sel28_fAccR)
                   & std_logic_vector(result_199.Frame_sel29_fAcc2L)
                   & std_logic_vector(result_199.Frame_sel30_fAcc2R)
                   & std_logic_vector(result_199.Frame_sel31_fAcc3L)
                   & std_logic_vector(result_199.Frame_sel32_fAcc3R)))) when others;

  \c$bv_64\ <= (x_73.Frame_sel3_fGate);

  result_selection_res_96 <= not ((\c$bv_64\(0 downto 0)) = std_logic_vector'("1"));

  result_199 <= x_73 when result_selection_res_96 else
                ( Frame_sel0_fL => result_201
                , Frame_sel1_fR => result_200
                , Frame_sel2_fLast => x_73.Frame_sel2_fLast
                , Frame_sel3_fGate => x_73.Frame_sel3_fGate
                , Frame_sel4_fOd => x_73.Frame_sel4_fOd
                , Frame_sel5_fDist => x_73.Frame_sel5_fDist
                , Frame_sel6_fEq => x_73.Frame_sel6_fEq
                , Frame_sel7_fRat => x_73.Frame_sel7_fRat
                , Frame_sel8_fAmp => x_73.Frame_sel8_fAmp
                , Frame_sel9_fAmpTone => x_73.Frame_sel9_fAmpTone
                , Frame_sel10_fCab => x_73.Frame_sel10_fCab
                , Frame_sel11_fReverb => x_73.Frame_sel11_fReverb
                , Frame_sel12_fAddr => x_73.Frame_sel12_fAddr
                , Frame_sel13_fDryL => x_73.Frame_sel13_fDryL
                , Frame_sel14_fDryR => x_73.Frame_sel14_fDryR
                , Frame_sel15_fWetL => x_73.Frame_sel15_fWetL
                , Frame_sel16_fWetR => x_73.Frame_sel16_fWetR
                , Frame_sel17_fFbL => x_73.Frame_sel17_fFbL
                , Frame_sel18_fFbR => x_73.Frame_sel18_fFbR
                , Frame_sel19_fEqLowL => x_73.Frame_sel19_fEqLowL
                , Frame_sel20_fEqLowR => x_73.Frame_sel20_fEqLowR
                , Frame_sel21_fEqMidL => x_73.Frame_sel21_fEqMidL
                , Frame_sel22_fEqMidR => x_73.Frame_sel22_fEqMidR
                , Frame_sel23_fEqHighL => x_73.Frame_sel23_fEqHighL
                , Frame_sel24_fEqHighR => x_73.Frame_sel24_fEqHighR
                , Frame_sel25_fEqHighLpL => x_73.Frame_sel25_fEqHighLpL
                , Frame_sel26_fEqHighLpR => x_73.Frame_sel26_fEqHighLpR
                , Frame_sel27_fAccL => x_73.Frame_sel27_fAccL
                , Frame_sel28_fAccR => x_73.Frame_sel28_fAccR
                , Frame_sel29_fAcc2L => x_73.Frame_sel29_fAcc2L
                , Frame_sel30_fAcc2R => x_73.Frame_sel30_fAcc2R
                , Frame_sel31_fAcc3L => x_73.Frame_sel31_fAcc3L
                , Frame_sel32_fAcc3R => x_73.Frame_sel32_fAcc3R );

  \c$case_alt_selection_res_87\ <= \c$app_arg_255\ < to_signed(-8388608,48);

  \c$case_alt_106\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_87\ else
                      resize(\c$app_arg_255\,24);

  result_selection_res_97 <= \c$app_arg_255\ > to_signed(8388607,48);

  result_200 <= to_signed(8388607,24) when result_selection_res_97 else
                \c$case_alt_106\;

  \c$shI_110\ <= (to_signed(12,64));

  capp_arg_255_shiftR : block
    signal sh_110 : natural;
  begin
    sh_110 <=
        -- pragma translate_off
        natural'high when (\c$shI_110\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_110\);
    \c$app_arg_255\ <= shift_right((resize((resize(x_73.Frame_sel1_fR,48)) * \c$app_arg_257\, 48)),sh_110)
        -- pragma translate_off
        when ((to_signed(12,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_88\ <= \c$app_arg_256\ < to_signed(-8388608,48);

  \c$case_alt_107\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_88\ else
                      resize(\c$app_arg_256\,24);

  result_selection_res_98 <= \c$app_arg_256\ > to_signed(8388607,48);

  result_201 <= to_signed(8388607,24) when result_selection_res_98 else
                \c$case_alt_107\;

  \c$shI_111\ <= (to_signed(12,64));

  capp_arg_256_shiftR : block
    signal sh_111 : natural;
  begin
    sh_111 <=
        -- pragma translate_off
        natural'high when (\c$shI_111\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_111\);
    \c$app_arg_256\ <= shift_right((resize((resize(x_73.Frame_sel0_fL,48)) * \c$app_arg_257\, 48)),sh_111)
        -- pragma translate_off
        when ((to_signed(12,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_257\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(gateGain)))))))),48);

  -- register begin
  gateGain_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      gateGain <= to_unsigned(4095,12);
    elsif rising_edge(clk) then
      gateGain <= result_202;
    end if;
  end process;
  -- register end

  \c$case_alt_selection_res_89\ <= gateGain < to_unsigned(4,12);

  \c$case_alt_108\ <= to_unsigned(0,12) when \c$case_alt_selection_res_89\ else
                      gateGain - to_unsigned(4,12);

  \c$case_alt_selection_res_90\ <= gateGain > to_unsigned(3583,12);

  \c$case_alt_109\ <= to_unsigned(4095,12) when \c$case_alt_selection_res_90\ else
                      gateGain + to_unsigned(512,12);

  \c$case_alt_110\ <= \c$case_alt_109\ when gateOpen else
                      \c$case_alt_108\;

  \c$bv_65\ <= (f_2.Frame_sel3_fGate);

  \c$case_alt_selection_res_91\ <= not ((\c$bv_65\(0 downto 0)) = std_logic_vector'("1"));

  \c$case_alt_111\ <= to_unsigned(4095,12) when \c$case_alt_selection_res_91\ else
                      \c$case_alt_110\;

  f_2 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(gateLevelPipe(970 downto 0)));

  with (gateLevelPipe(971 downto 971)) select
    result_202 <= gateGain when "0",
                  \c$case_alt_111\ when others;

  -- register begin
  gateOpen_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      gateOpen <= true;
    elsif rising_edge(clk) then
      gateOpen <= result_203;
    end if;
  end process;
  -- register end

  with (gateLevelPipe(971 downto 971)) select
    result_203 <= gateOpen when "0",
                  \c$case_alt_112\ when others;

  \c$case_alt_selection_res_92\ <= not ((\c$app_arg_260\(0 downto 0)) = std_logic_vector'("1"));

  \c$case_alt_112\ <= true when \c$case_alt_selection_res_92\ else
                      result_204;

  with (closeThreshold) select
    result_204 <= true when x"000000",
                  \c$case_alt_113\ when others;

  \c$case_alt_selection_res_93\ <= gateEnv > result_205;

  \c$case_alt_113\ <= true when \c$case_alt_selection_res_93\ else
                      \c$case_alt_114\;

  \c$case_alt_selection_res_94\ <= gateEnv < closeThreshold;

  \c$case_alt_114\ <= false when \c$case_alt_selection_res_94\ else
                      gateOpen;

  x_71 <= (\c$app_arg_259\ + \c$app_arg_258\) + to_signed(65536,48);

  \c$case_alt_selection_res_95\ <= x_71 < to_signed(-8388608,48);

  \c$case_alt_115\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_95\ else
                      resize(x_71,24);

  result_selection_res_99 <= x_71 > to_signed(8388607,48);

  result_205 <= to_signed(8388607,24) when result_selection_res_99 else
                \c$case_alt_115\;

  \c$shI_112\ <= (to_signed(1,64));

  capp_arg_258_shiftR : block
    signal sh_112 : natural;
  begin
    sh_112 <=
        -- pragma translate_off
        natural'high when (\c$shI_112\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_112\);
    \c$app_arg_258\ <= shift_right(\c$app_arg_259\,sh_112)
        -- pragma translate_off
        when ((to_signed(1,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_259\ <= resize(closeThreshold,48);

  \c$shI_113\ <= (to_signed(13,64));

  closeThreshold_shiftL : block
    signal sh_113 : natural;
  begin
    sh_113 <=
        -- pragma translate_off
        natural'high when (\c$shI_113\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_113\);
    closeThreshold <= shift_left((resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(x_72)))))))),24)),sh_113)
        -- pragma translate_off
        when ((to_signed(13,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  x_72 <= unsigned((\c$app_arg_260\(15 downto 8)));

  \c$app_arg_260\ <= f_3.Frame_sel3_fGate;

  f_3 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(gateLevelPipe(970 downto 0)));

  -- register begin
  gateEnv_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      gateEnv <= to_signed(0,24);
    elsif rising_edge(clk) then
      gateEnv <= result_207;
    end if;
  end process;
  -- register end

  \c$shI_114\ <= (to_signed(8,64));

  cdecay_app_arg_shiftR : block
    signal sh_114 : natural;
  begin
    sh_114 <=
        -- pragma translate_off
        natural'high when (\c$shI_114\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_114\);
    \c$decay_app_arg\ <= shift_right((resize(gateEnv,25)),sh_114)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  result_selection_res_100 <= gateEnv > decay;

  result_206 <= gateEnv - decay when result_selection_res_100 else
                to_signed(0,24);

  \c$case_alt_selection_res_96\ <= f_4.Frame_sel15_fWetL > gateEnv;

  \c$case_alt_116\ <= f_4.Frame_sel15_fWetL when \c$case_alt_selection_res_96\ else
                      result_206;

  \c$bv_66\ <= (f_4.Frame_sel3_fGate);

  \c$case_alt_selection_res_97\ <= not ((\c$bv_66\(0 downto 0)) = std_logic_vector'("1"));

  \c$case_alt_117\ <= to_signed(0,24) when \c$case_alt_selection_res_97\ else
                      \c$case_alt_116\;

  f_4 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(gateLevelPipe(970 downto 0)));

  decay <= resize((\c$decay_app_arg\ + to_signed(1,25)),24);

  with (gateLevelPipe(971 downto 971)) select
    result_207 <= gateEnv when "0",
                  \c$case_alt_117\ when others;

  x_73 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(gateLevelPipe(970 downto 0)));

  -- register begin
  gateLevelPipe_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      gateLevelPipe <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      gateLevelPipe <= result_208;
    end if;
  end process;
  -- register end

  with (ds1_35(971 downto 971)) select
    result_208 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                  std_logic_vector'("1" & ((std_logic_vector(\c$case_alt_118\.Frame_sel0_fL)
                   & std_logic_vector(\c$case_alt_118\.Frame_sel1_fR)
                   & clash_lowpass_fir_types.toSLV(\c$case_alt_118\.Frame_sel2_fLast)
                   & \c$case_alt_118\.Frame_sel3_fGate
                   & \c$case_alt_118\.Frame_sel4_fOd
                   & \c$case_alt_118\.Frame_sel5_fDist
                   & \c$case_alt_118\.Frame_sel6_fEq
                   & \c$case_alt_118\.Frame_sel7_fRat
                   & \c$case_alt_118\.Frame_sel8_fAmp
                   & \c$case_alt_118\.Frame_sel9_fAmpTone
                   & \c$case_alt_118\.Frame_sel10_fCab
                   & \c$case_alt_118\.Frame_sel11_fReverb
                   & std_logic_vector(\c$case_alt_118\.Frame_sel12_fAddr)
                   & std_logic_vector(\c$case_alt_118\.Frame_sel13_fDryL)
                   & std_logic_vector(\c$case_alt_118\.Frame_sel14_fDryR)
                   & std_logic_vector(\c$case_alt_118\.Frame_sel15_fWetL)
                   & std_logic_vector(\c$case_alt_118\.Frame_sel16_fWetR)
                   & std_logic_vector(\c$case_alt_118\.Frame_sel17_fFbL)
                   & std_logic_vector(\c$case_alt_118\.Frame_sel18_fFbR)
                   & std_logic_vector(\c$case_alt_118\.Frame_sel19_fEqLowL)
                   & std_logic_vector(\c$case_alt_118\.Frame_sel20_fEqLowR)
                   & std_logic_vector(\c$case_alt_118\.Frame_sel21_fEqMidL)
                   & std_logic_vector(\c$case_alt_118\.Frame_sel22_fEqMidR)
                   & std_logic_vector(\c$case_alt_118\.Frame_sel23_fEqHighL)
                   & std_logic_vector(\c$case_alt_118\.Frame_sel24_fEqHighR)
                   & std_logic_vector(\c$case_alt_118\.Frame_sel25_fEqHighLpL)
                   & std_logic_vector(\c$case_alt_118\.Frame_sel26_fEqHighLpR)
                   & std_logic_vector(\c$case_alt_118\.Frame_sel27_fAccL)
                   & std_logic_vector(\c$case_alt_118\.Frame_sel28_fAccR)
                   & std_logic_vector(\c$case_alt_118\.Frame_sel29_fAcc2L)
                   & std_logic_vector(\c$case_alt_118\.Frame_sel30_fAcc2R)
                   & std_logic_vector(\c$case_alt_118\.Frame_sel31_fAcc3L)
                   & std_logic_vector(\c$case_alt_118\.Frame_sel32_fAcc3R)))) when others;

  result_selection_res_101 <= result_211 > result_210;

  result_209 <= result_211 when result_selection_res_101 else
                result_210;

  \c$case_alt_118\ <= ( Frame_sel0_fL => x_74.Frame_sel0_fL
                      , Frame_sel1_fR => x_74.Frame_sel1_fR
                      , Frame_sel2_fLast => x_74.Frame_sel2_fLast
                      , Frame_sel3_fGate => x_74.Frame_sel3_fGate
                      , Frame_sel4_fOd => x_74.Frame_sel4_fOd
                      , Frame_sel5_fDist => x_74.Frame_sel5_fDist
                      , Frame_sel6_fEq => x_74.Frame_sel6_fEq
                      , Frame_sel7_fRat => x_74.Frame_sel7_fRat
                      , Frame_sel8_fAmp => x_74.Frame_sel8_fAmp
                      , Frame_sel9_fAmpTone => x_74.Frame_sel9_fAmpTone
                      , Frame_sel10_fCab => x_74.Frame_sel10_fCab
                      , Frame_sel11_fReverb => x_74.Frame_sel11_fReverb
                      , Frame_sel12_fAddr => x_74.Frame_sel12_fAddr
                      , Frame_sel13_fDryL => x_74.Frame_sel13_fDryL
                      , Frame_sel14_fDryR => x_74.Frame_sel14_fDryR
                      , Frame_sel15_fWetL => result_209
                      , Frame_sel16_fWetR => x_74.Frame_sel16_fWetR
                      , Frame_sel17_fFbL => x_74.Frame_sel17_fFbL
                      , Frame_sel18_fFbR => x_74.Frame_sel18_fFbR
                      , Frame_sel19_fEqLowL => x_74.Frame_sel19_fEqLowL
                      , Frame_sel20_fEqLowR => x_74.Frame_sel20_fEqLowR
                      , Frame_sel21_fEqMidL => x_74.Frame_sel21_fEqMidL
                      , Frame_sel22_fEqMidR => x_74.Frame_sel22_fEqMidR
                      , Frame_sel23_fEqHighL => x_74.Frame_sel23_fEqHighL
                      , Frame_sel24_fEqHighR => x_74.Frame_sel24_fEqHighR
                      , Frame_sel25_fEqHighLpL => x_74.Frame_sel25_fEqHighLpL
                      , Frame_sel26_fEqHighLpR => x_74.Frame_sel26_fEqHighLpR
                      , Frame_sel27_fAccL => x_74.Frame_sel27_fAccL
                      , Frame_sel28_fAccR => x_74.Frame_sel28_fAccR
                      , Frame_sel29_fAcc2L => x_74.Frame_sel29_fAcc2L
                      , Frame_sel30_fAcc2R => x_74.Frame_sel30_fAcc2R
                      , Frame_sel31_fAcc3L => x_74.Frame_sel31_fAcc3L
                      , Frame_sel32_fAcc3R => x_74.Frame_sel32_fAcc3R );

  \c$case_alt_selection_res_98\ <= x_74.Frame_sel1_fR < to_signed(0,24);

  \c$case_alt_119\ <= -x_74.Frame_sel1_fR when \c$case_alt_selection_res_98\ else
                      x_74.Frame_sel1_fR;

  result_selection_res_102 <= x_74.Frame_sel1_fR = to_signed(-8388608,24);

  result_210 <= to_signed(8388607,24) when result_selection_res_102 else
                \c$case_alt_119\;

  \c$case_alt_selection_res_99\ <= x_74.Frame_sel0_fL < to_signed(0,24);

  \c$case_alt_120\ <= -x_74.Frame_sel0_fL when \c$case_alt_selection_res_99\ else
                      x_74.Frame_sel0_fL;

  result_selection_res_103 <= x_74.Frame_sel0_fL = to_signed(-8388608,24);

  result_211 <= to_signed(8388607,24) when result_selection_res_103 else
                \c$case_alt_120\;

  x_74 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_35(970 downto 0)));

  -- register begin
  ds1_35_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_35 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_35 <= result_213;
    end if;
  end process;
  -- register end

  validIn <= axis_in_tvalid and axis_out_tready;

  right <= result_212.Tuple2_0_sel1_signed_1;

  left <= result_212.Tuple2_0_sel0_signed_0;

  result_212 <= ( Tuple2_0_sel0_signed_0 => signed((\c$app_arg_261\(23 downto 0)))
                , Tuple2_0_sel1_signed_1 => signed((\c$app_arg_261\(47 downto 24))) );

  \c$app_arg_261\ <= axis_in_tdata;

  result_213 <= std_logic_vector'("1" & ((std_logic_vector(left)
                 & std_logic_vector(right)
                 & clash_lowpass_fir_types.toSLV(axis_in_tlast)
                 & gate_control
                 & overdrive_control
                 & distortion_control
                 & eq_control
                 & delay_control
                 & amp_control
                 & amp_tone_control
                 & cab_control
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
                std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");

  \c$reverbAddr_case_alt_selection_res\ <= reverbAddr = to_unsigned(1023,10);

  \c$reverbAddr_case_alt\ <= to_unsigned(0,10) when \c$reverbAddr_case_alt_selection_res\ else
                             reverbAddr + to_unsigned(1,10);

  axis_out_tdata <= result.Tuple4_sel0_std_logic_vector;

  axis_out_tvalid <= result.Tuple4_sel1_boolean_0;

  axis_out_tlast <= result.Tuple4_sel2_boolean_1;

  axis_in_tready <= result.Tuple4_sel3_boolean_2;


end;
