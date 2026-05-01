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
  signal result_0                              : clash_lowpass_fir_types.AxisOut;
  signal \c$case_alt\                          : clash_lowpass_fir_types.AxisOut;
  -- src/LowPassFir.hs:765:1-11
  signal \new\                                 : boolean;
  signal \c$app_arg\                           : boolean;
  signal \c$app_arg_0\                         : std_logic_vector(47 downto 0);
  -- src/LowPassFir.hs:754:1-8
  signal f                                     : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:765:1-11
  signal consumed                              : boolean;
  -- src/LowPassFir.hs:844:1-10
  signal outReg                                : clash_lowpass_fir_types.AxisOut := ( AxisOut_sel0_oData => std_logic_vector'(x"000000000000")
, AxisOut_sel1_oValid => false
, AxisOut_sel2_oLast => false );
  signal result_1                              : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_1\                         : signed(47 downto 0);
  signal \c$app_arg_2\                         : signed(47 downto 0);
  -- src/LowPassFir.hs:711:1-27
  signal \on\                                  : boolean;
  signal \c$app_arg_3\                         : signed(47 downto 0);
  -- src/LowPassFir.hs:113:1-5
  signal gain                                  : unsigned(7 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal reverbToneBlendPipe                   : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_2                              : clash_lowpass_fir_types.Maybe;
  signal \c$app_arg_4\                         : signed(47 downto 0);
  signal \c$case_alt_0\                        : signed(23 downto 0);
  signal result_3                              : signed(23 downto 0);
  signal \c$app_arg_5\                         : signed(47 downto 0);
  signal \c$case_alt_1\                        : signed(23 downto 0);
  signal result_4                              : signed(23 downto 0);
  signal \c$case_alt_2\                        : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:844:1-10
  signal x                                     : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:844:1-10
  signal ds1                                   : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_5                              : clash_lowpass_fir_types.Maybe;
  signal \c$app_arg_6\                         : signed(47 downto 0);
  -- src/LowPassFir.hs:113:1-5
  signal gain_0                                : unsigned(7 downto 0);
  signal \c$app_arg_7\                         : signed(47 downto 0);
  -- src/LowPassFir.hs:113:1-5
  signal gain_1                                : unsigned(7 downto 0);
  -- src/LowPassFir.hs:696:1-23
  signal x_0                                   : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:844:1-10
  signal reverbTonePrevR                       : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:844:1-10
  signal \c$reverbTonePrevR_app_arg\           : signed(23 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal reverbTonePrevL                       : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:844:1-10
  signal \c$reverbTonePrevL_app_arg\           : signed(23 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal x_1                                   : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:844:1-10
  signal \c$ds1_app_arg\                       : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  -- src/LowPassFir.hs:689:1-10
  signal f_0                                   : clash_lowpass_fir_types.Frame;
  signal result_6                              : clash_lowpass_fir_types.Maybe;
  signal result_7                              : signed(23 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal ds                                    : clash_lowpass_fir_types.Tuple2;
  -- src/LowPassFir.hs:844:1-10
  signal a1                                    : clash_lowpass_fir_types.Tuple2;
  -- src/LowPassFir.hs:844:1-10
  signal \c$ds1_app_arg_0\                     : boolean;
  -- src/LowPassFir.hs:844:1-10
  signal wrM                                   : clash_lowpass_fir_types.Maybe_0;
  signal result_8                              : signed(23 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal ds_0                                  : clash_lowpass_fir_types.Tuple2;
  -- src/LowPassFir.hs:844:1-10
  signal a1_0                                  : clash_lowpass_fir_types.Tuple2;
  -- src/LowPassFir.hs:844:1-10
  signal \c$ds1_app_arg_1\                     : boolean;
  -- src/LowPassFir.hs:844:1-10
  signal wrM_0                                 : clash_lowpass_fir_types.Maybe_0;
  -- src/LowPassFir.hs:746:1-12
  signal f_1                                   : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:844:1-10
  signal outPipe                               : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
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
  -- src/LowPassFir.hs:738:1-14
  signal \on_0\                                : boolean;
  -- src/LowPassFir.hs:844:1-10
  signal x_2                                   : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:844:1-10
  signal ds1_0                                 : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_13                             : clash_lowpass_fir_types.Maybe;
  signal result_14                             : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_12\                        : signed(47 downto 0);
  signal \c$app_arg_13\                        : signed(47 downto 0);
  signal \c$app_arg_14\                        : signed(47 downto 0);
  signal \c$app_arg_15\                        : signed(47 downto 0);
  signal \c$app_arg_16\                        : signed(47 downto 0);
  -- src/LowPassFir.hs:725:1-22
  signal \on_1\                                : boolean;
  signal \c$app_arg_17\                        : signed(47 downto 0);
  -- src/LowPassFir.hs:725:1-22
  signal invMixGain                            : unsigned(8 downto 0);
  -- src/LowPassFir.hs:725:1-22
  signal mixGain                               : unsigned(7 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal x_3                                   : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:844:1-10
  signal ds1_1                                 : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_15                             : clash_lowpass_fir_types.Maybe;
  signal \c$app_arg_18\                        : signed(47 downto 0);
  signal \c$app_arg_19\                        : signed(47 downto 0);
  -- src/LowPassFir.hs:122:1-7
  signal x_4                                   : signed(47 downto 0);
  signal \c$case_alt_5\                        : signed(23 downto 0);
  signal result_16                             : signed(23 downto 0);
  signal \c$app_arg_20\                        : signed(23 downto 0);
  signal \c$app_arg_21\                        : signed(47 downto 0);
  signal \c$app_arg_22\                        : signed(47 downto 0);
  -- src/LowPassFir.hs:122:1-7
  signal x_5                                   : signed(47 downto 0);
  signal \c$case_alt_6\                        : signed(23 downto 0);
  signal result_17                             : signed(23 downto 0);
  signal \c$app_arg_23\                        : signed(23 downto 0);
  signal result_18                             : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:717:1-19
  signal \on_2\                                : boolean;
  -- src/LowPassFir.hs:844:1-10
  signal x_6                                   : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:844:1-10
  signal ds1_2                                 : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  -- src/LowPassFir.hs:844:1-10
  signal \c$ds1_app_arg_2\                     : clash_lowpass_fir_types.Maybe;
  -- src/LowPassFir.hs:844:1-10
  signal \c$ds1_app_arg_3\                     : signed(63 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal reverbAddr                            : clash_lowpass_fir_types.index_1024 := to_unsigned(0,10);
  -- src/LowPassFir.hs:844:1-10
  signal \c$reverbAddr_app_arg\                : clash_lowpass_fir_types.index_1024;
  -- src/LowPassFir.hs:844:1-10
  signal eqMixPipe                             : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_19                             : clash_lowpass_fir_types.Maybe;
  -- src/LowPassFir.hs:681:1-10
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
  -- src/LowPassFir.hs:844:1-10
  signal x_7                                   : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:844:1-10
  signal ds1_3                                 : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_23                             : clash_lowpass_fir_types.Maybe;
  signal result_24                             : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_28\                        : signed(47 downto 0);
  signal \c$app_arg_29\                        : signed(47 downto 0);
  signal \c$app_arg_30\                        : signed(47 downto 0);
  -- src/LowPassFir.hs:113:1-5
  signal gain_2                                : unsigned(7 downto 0);
  signal \c$app_arg_31\                        : signed(47 downto 0);
  signal \c$app_arg_32\                        : signed(47 downto 0);
  signal \c$app_arg_33\                        : signed(47 downto 0);
  -- src/LowPassFir.hs:113:1-5
  signal gain_3                                : unsigned(7 downto 0);
  signal \c$app_arg_34\                        : signed(47 downto 0);
  signal \c$app_arg_35\                        : signed(47 downto 0);
  -- src/LowPassFir.hs:668:1-15
  signal \on_4\                                : boolean;
  signal \c$app_arg_36\                        : signed(47 downto 0);
  -- src/LowPassFir.hs:113:1-5
  signal gain_4                                : unsigned(7 downto 0);
  -- src/LowPassFir.hs:113:1-5
  signal \c$gain_app_arg\                      : std_logic_vector(31 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal x_8                                   : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:844:1-10
  signal ds1_4                                 : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_25                             : clash_lowpass_fir_types.Maybe;
  signal \c$case_alt_9\                        : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:122:1-7
  signal x_9                                   : signed(47 downto 0);
  signal \c$case_alt_10\                       : signed(23 downto 0);
  signal result_26                             : signed(23 downto 0);
  -- src/LowPassFir.hs:122:1-7
  signal x_10                                  : signed(47 downto 0);
  signal \c$case_alt_11\                       : signed(23 downto 0);
  signal result_27                             : signed(23 downto 0);
  -- src/LowPassFir.hs:122:1-7
  signal x_11                                  : signed(47 downto 0);
  signal \c$case_alt_12\                       : signed(23 downto 0);
  signal result_28                             : signed(23 downto 0);
  signal \c$app_arg_37\                        : signed(47 downto 0);
  -- src/LowPassFir.hs:122:1-7
  signal x_12                                  : signed(47 downto 0);
  signal \c$case_alt_13\                       : signed(23 downto 0);
  signal result_29                             : signed(23 downto 0);
  signal \c$app_arg_38\                        : signed(47 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal eqFilterPipe                          : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_30                             : clash_lowpass_fir_types.Maybe;
  signal \c$case_alt_14\                       : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_39\                        : signed(24 downto 0);
  signal \c$app_arg_40\                        : signed(24 downto 0);
  signal \c$app_arg_41\                        : signed(24 downto 0);
  signal \c$app_arg_42\                        : signed(24 downto 0);
  signal \c$app_arg_43\                        : signed(24 downto 0);
  signal \c$app_arg_44\                        : signed(24 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal eqHighPrevR                           : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:844:1-10
  signal \c$eqHighPrevR_app_arg\               : signed(23 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal eqHighPrevL                           : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:844:1-10
  signal \c$eqHighPrevL_app_arg\               : signed(23 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal eqLowPrevR                            : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:844:1-10
  signal \c$eqLowPrevR_app_arg\                : signed(23 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal eqLowPrevL                            : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:844:1-10
  signal \c$eqLowPrevL_app_arg\                : signed(23 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal x_13                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:163:1-7
  signal x_14                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:163:1-7
  signal ds1_5                                 : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
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
  signal \c$case_alt_17\                       : signed(23 downto 0);
  signal result_35                             : signed(23 downto 0);
  -- src/LowPassFir.hs:113:1-5
  signal \c$x_app_arg\                         : signed(47 downto 0);
  signal \c$app_arg_50\                        : signed(23 downto 0);
  -- src/LowPassFir.hs:630:1-16
  signal \on_5\                                : boolean;
  signal result_36                             : signed(23 downto 0);
  signal \c$case_alt_18\                       : signed(23 downto 0);
  signal \c$app_arg_51\                        : signed(24 downto 0);
  signal \c$app_arg_52\                        : signed(24 downto 0);
  signal \c$app_arg_53\                        : signed(24 downto 0);
  signal \c$case_alt_19\                       : signed(23 downto 0);
  signal result_37                             : signed(23 downto 0);
  signal \c$app_arg_54\                        : signed(47 downto 0);
  signal \c$app_arg_55\                        : signed(47 downto 0);
  signal \c$case_alt_20\                       : signed(23 downto 0);
  signal result_38                             : signed(23 downto 0);
  -- src/LowPassFir.hs:113:1-5
  signal \c$x_app_arg_0\                       : signed(47 downto 0);
  -- src/LowPassFir.hs:113:1-5
  signal \c$x_app_arg_1\                       : signed(47 downto 0);
  -- src/LowPassFir.hs:630:1-16
  signal level                                 : unsigned(7 downto 0);
  signal \c$app_arg_56\                        : signed(47 downto 0);
  -- src/LowPassFir.hs:630:1-16
  signal invMix                                : unsigned(7 downto 0);
  -- src/LowPassFir.hs:630:1-16
  signal mix                                   : unsigned(7 downto 0);
  -- src/LowPassFir.hs:630:1-16
  signal \c$level_app_arg\                     : std_logic_vector(31 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal x_15                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:844:1-10
  signal ds1_6                                 : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_39                             : clash_lowpass_fir_types.Maybe;
  signal \c$app_arg_57\                        : signed(47 downto 0);
  signal \c$case_alt_21\                       : signed(23 downto 0);
  signal result_40                             : signed(23 downto 0);
  signal \c$app_arg_58\                        : signed(23 downto 0);
  signal \c$app_arg_59\                        : signed(47 downto 0);
  signal \c$case_alt_22\                       : signed(23 downto 0);
  signal result_41                             : signed(23 downto 0);
  signal \c$app_arg_60\                        : signed(23 downto 0);
  signal result_42                             : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:621:1-10
  signal \on_6\                                : boolean;
  -- src/LowPassFir.hs:844:1-10
  signal cabD3L                                : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:844:1-10
  signal \c$cabD3L_app_arg\                    : signed(23 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal cabD2L                                : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:844:1-10
  signal \c$cabD2L_app_arg\                    : signed(23 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal cabD1L                                : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:844:1-10
  signal \c$cabD1L_app_arg\                    : signed(23 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal \c$cabD1L_case_alt\                   : signed(23 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal cabD3R                                : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:844:1-10
  signal \c$cabD3R_app_arg\                    : signed(23 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal cabD2R                                : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:844:1-10
  signal \c$cabD2R_app_arg\                    : signed(23 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal cabD1R                                : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:844:1-10
  signal \c$cabD1R_app_arg\                    : signed(23 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal \c$cabD1R_case_alt\                   : signed(23 downto 0);
  -- src/LowPassFir.hs:163:1-7
  signal x_16                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:844:1-10
  signal ampMasterPipe                         : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_43                             : clash_lowpass_fir_types.Maybe;
  signal result_44                             : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_61\                        : signed(23 downto 0);
  signal result_45                             : signed(23 downto 0);
  signal \c$case_alt_23\                       : signed(23 downto 0);
  signal \c$app_arg_62\                        : signed(24 downto 0);
  signal \c$app_arg_63\                        : signed(24 downto 0);
  signal \c$app_arg_64\                        : signed(24 downto 0);
  signal \c$case_alt_24\                       : signed(23 downto 0);
  signal result_46                             : signed(23 downto 0);
  signal \c$app_arg_65\                        : signed(47 downto 0);
  signal \c$app_arg_66\                        : signed(23 downto 0);
  -- src/LowPassFir.hs:612:1-14
  signal \on_7\                                : boolean;
  signal result_47                             : signed(23 downto 0);
  signal \c$case_alt_25\                       : signed(23 downto 0);
  signal \c$app_arg_67\                        : signed(24 downto 0);
  signal \c$app_arg_68\                        : signed(24 downto 0);
  signal \c$app_arg_69\                        : signed(24 downto 0);
  signal \c$case_alt_26\                       : signed(23 downto 0);
  signal result_48                             : signed(23 downto 0);
  signal \c$app_arg_70\                        : signed(47 downto 0);
  signal \c$app_arg_71\                        : signed(47 downto 0);
  -- src/LowPassFir.hs:612:1-14
  signal level_0                               : unsigned(7 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal x_17                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:844:1-10
  signal ds1_7                                 : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_49                             : clash_lowpass_fir_types.Maybe;
  signal result_50                             : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_72\                        : signed(23 downto 0);
  signal result_51                             : signed(23 downto 0);
  signal \c$case_alt_27\                       : signed(23 downto 0);
  signal \c$app_arg_73\                        : signed(24 downto 0);
  signal \c$app_arg_74\                        : signed(24 downto 0);
  signal \c$app_arg_75\                        : signed(24 downto 0);
  -- src/LowPassFir.hs:122:1-7
  signal x_18                                  : signed(47 downto 0);
  signal \c$case_alt_28\                       : signed(23 downto 0);
  signal result_52                             : signed(23 downto 0);
  signal \c$case_alt_29\                       : signed(23 downto 0);
  signal result_53                             : signed(23 downto 0);
  signal \c$app_arg_76\                        : signed(47 downto 0);
  -- src/LowPassFir.hs:122:1-7
  signal x_19                                  : signed(47 downto 0);
  signal \c$case_alt_30\                       : signed(23 downto 0);
  signal result_54                             : signed(23 downto 0);
  signal \c$case_alt_31\                       : signed(23 downto 0);
  signal result_55                             : signed(23 downto 0);
  signal \c$app_arg_77\                        : signed(47 downto 0);
  signal \c$app_arg_78\                        : signed(47 downto 0);
  signal \c$app_arg_79\                        : signed(23 downto 0);
  -- src/LowPassFir.hs:600:1-22
  signal \on_8\                                : boolean;
  signal result_56                             : signed(23 downto 0);
  signal \c$case_alt_32\                       : signed(23 downto 0);
  signal \c$app_arg_80\                        : signed(24 downto 0);
  signal \c$app_arg_81\                        : signed(24 downto 0);
  signal \c$app_arg_82\                        : signed(24 downto 0);
  -- src/LowPassFir.hs:122:1-7
  signal x_20                                  : signed(47 downto 0);
  signal \c$case_alt_33\                       : signed(23 downto 0);
  signal result_57                             : signed(23 downto 0);
  signal \c$case_alt_34\                       : signed(23 downto 0);
  signal result_58                             : signed(23 downto 0);
  signal \c$app_arg_83\                        : signed(47 downto 0);
  signal \c$app_arg_84\                        : signed(47 downto 0);
  -- src/LowPassFir.hs:600:1-22
  signal presence                              : unsigned(7 downto 0);
  -- src/LowPassFir.hs:122:1-7
  signal x_21                                  : signed(47 downto 0);
  signal \c$case_alt_35\                       : signed(23 downto 0);
  signal result_59                             : signed(23 downto 0);
  signal \c$case_alt_36\                       : signed(23 downto 0);
  signal result_60                             : signed(23 downto 0);
  signal \c$app_arg_85\                        : signed(47 downto 0);
  signal \c$app_arg_86\                        : signed(47 downto 0);
  -- src/LowPassFir.hs:600:1-22
  signal resonance                             : unsigned(7 downto 0);
  signal \c$app_arg_87\                        : signed(47 downto 0);
  -- src/LowPassFir.hs:600:1-22
  signal \c$presence_app_arg\                  : std_logic_vector(31 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal ampResPresenceFilterPipe              : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_61                             : clash_lowpass_fir_types.Maybe;
  signal \c$case_alt_37\                       : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_88\                        : signed(24 downto 0);
  signal \c$app_arg_89\                        : signed(24 downto 0);
  signal \c$app_arg_90\                        : signed(24 downto 0);
  signal \c$app_arg_91\                        : signed(24 downto 0);
  signal \c$app_arg_92\                        : signed(24 downto 0);
  signal \c$app_arg_93\                        : signed(24 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal ampPresencePrevR                      : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:844:1-10
  signal \c$ampPresencePrevR_app_arg\          : signed(23 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal ampPresencePrevL                      : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:844:1-10
  signal \c$ampPresencePrevL_app_arg\          : signed(23 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal ampResPrevR                           : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:844:1-10
  signal \c$ampResPrevR_app_arg\               : signed(23 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal ampResPrevL                           : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:844:1-10
  signal \c$ampResPrevL_app_arg\               : signed(23 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal x_22                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:163:1-7
  signal x_23                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:163:1-7
  signal ds1_8                                 : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_62                             : clash_lowpass_fir_types.Maybe;
  -- src/LowPassFir.hs:577:1-13
  signal \on_9\                                : boolean;
  signal result_63                             : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_94\                        : signed(23 downto 0);
  signal result_64                             : signed(23 downto 0);
  signal \c$case_alt_38\                       : signed(23 downto 0);
  signal \c$app_arg_95\                        : signed(24 downto 0);
  signal \c$app_arg_96\                        : signed(24 downto 0);
  signal \c$app_arg_97\                        : signed(24 downto 0);
  signal \c$app_arg_98\                        : signed(23 downto 0);
  signal result_65                             : signed(23 downto 0);
  signal \c$case_alt_39\                       : signed(23 downto 0);
  signal \c$app_arg_99\                        : signed(24 downto 0);
  signal \c$app_arg_100\                       : signed(24 downto 0);
  signal \c$app_arg_101\                       : signed(24 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal x_24                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:844:1-10
  signal ds1_9                                 : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_66                             : clash_lowpass_fir_types.Maybe;
  signal \c$app_arg_102\                       : signed(47 downto 0);
  signal \c$case_alt_40\                       : signed(23 downto 0);
  signal result_67                             : signed(23 downto 0);
  signal \c$app_arg_103\                       : signed(23 downto 0);
  signal \c$app_arg_104\                       : signed(47 downto 0);
  signal \c$case_alt_41\                       : signed(23 downto 0);
  signal result_68                             : signed(23 downto 0);
  signal \c$app_arg_105\                       : signed(23 downto 0);
  signal result_69                             : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:569:1-15
  signal \on_10\                               : boolean;
  -- src/LowPassFir.hs:844:1-10
  signal x_25                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:844:1-10
  signal ds1_10                                : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_70                             : clash_lowpass_fir_types.Maybe;
  signal result_71                             : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_106\                       : signed(47 downto 0);
  signal \c$app_arg_107\                       : signed(47 downto 0);
  signal \c$app_arg_108\                       : signed(47 downto 0);
  -- src/LowPassFir.hs:113:1-5
  signal \c$gain_app_arg_0\                    : unsigned(7 downto 0);
  -- src/LowPassFir.hs:553:1-11
  signal x_26                                  : unsigned(7 downto 0);
  signal \c$app_arg_109\                       : signed(47 downto 0);
  signal \c$app_arg_110\                       : signed(47 downto 0);
  signal \c$app_arg_111\                       : signed(47 downto 0);
  -- src/LowPassFir.hs:113:1-5
  signal \c$gain_app_arg_1\                    : unsigned(7 downto 0);
  -- src/LowPassFir.hs:553:1-11
  signal x_27                                  : unsigned(7 downto 0);
  signal \c$app_arg_112\                       : signed(47 downto 0);
  signal \c$app_arg_113\                       : signed(47 downto 0);
  -- src/LowPassFir.hs:556:1-20
  signal \on_11\                               : boolean;
  signal \c$app_arg_114\                       : signed(47 downto 0);
  -- src/LowPassFir.hs:113:1-5
  signal \c$gain_app_arg_2\                    : unsigned(7 downto 0);
  -- src/LowPassFir.hs:553:1-11
  signal x_28                                  : unsigned(7 downto 0);
  -- src/LowPassFir.hs:553:1-11
  signal \c$x_app_arg_2\                       : std_logic_vector(31 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal x_29                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:844:1-10
  signal ds1_11                                : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_72                             : clash_lowpass_fir_types.Maybe;
  signal \c$case_alt_42\                       : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:122:1-7
  signal x_30                                  : signed(47 downto 0);
  signal \c$case_alt_43\                       : signed(23 downto 0);
  signal result_73                             : signed(23 downto 0);
  -- src/LowPassFir.hs:122:1-7
  signal x_31                                  : signed(47 downto 0);
  signal \c$case_alt_44\                       : signed(23 downto 0);
  signal result_74                             : signed(23 downto 0);
  -- src/LowPassFir.hs:122:1-7
  signal x_32                                  : signed(47 downto 0);
  signal \c$case_alt_45\                       : signed(23 downto 0);
  signal result_75                             : signed(23 downto 0);
  signal \c$app_arg_115\                       : signed(47 downto 0);
  -- src/LowPassFir.hs:122:1-7
  signal x_33                                  : signed(47 downto 0);
  signal \c$case_alt_46\                       : signed(23 downto 0);
  signal result_76                             : signed(23 downto 0);
  signal \c$app_arg_116\                       : signed(47 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal ampToneFilterPipe                     : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_77                             : clash_lowpass_fir_types.Maybe;
  signal \c$case_alt_47\                       : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_117\                       : signed(24 downto 0);
  signal \c$app_arg_118\                       : signed(24 downto 0);
  signal \c$app_arg_119\                       : signed(24 downto 0);
  signal \c$app_arg_120\                       : signed(24 downto 0);
  signal \c$app_arg_121\                       : signed(24 downto 0);
  signal \c$app_arg_122\                       : signed(24 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal ampToneHighPrevR                      : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:844:1-10
  signal \c$ampToneHighPrevR_app_arg\          : signed(23 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal ampToneHighPrevL                      : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:844:1-10
  signal \c$ampToneHighPrevL_app_arg\          : signed(23 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal ampToneLowPrevR                       : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:844:1-10
  signal \c$ampToneLowPrevR_app_arg\           : signed(23 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal ampToneLowPrevL                       : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:844:1-10
  signal \c$ampToneLowPrevL_app_arg\           : signed(23 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal x_34                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:844:1-10
  signal ampPreLowpassPipe                     : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_78                             : clash_lowpass_fir_types.Maybe;
  -- src/LowPassFir.hs:520:1-18
  signal alpha                                 : unsigned(7 downto 0);
  -- src/LowPassFir.hs:520:1-18
  signal \on_12\                               : boolean;
  signal result_79                             : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_123\                       : signed(23 downto 0);
  signal \c$app_arg_124\                       : signed(47 downto 0);
  -- src/LowPassFir.hs:113:1-5
  signal gain_5                                : unsigned(7 downto 0);
  signal \c$case_alt_48\                       : signed(23 downto 0);
  signal result_80                             : signed(23 downto 0);
  signal \c$app_arg_125\                       : signed(23 downto 0);
  signal \c$app_arg_126\                       : signed(47 downto 0);
  -- src/LowPassFir.hs:113:1-5
  signal gain_6                                : unsigned(7 downto 0);
  signal \c$case_alt_49\                       : signed(23 downto 0);
  signal result_81                             : signed(23 downto 0);
  -- src/LowPassFir.hs:520:1-18
  signal \c$alpha_app_arg\                     : unsigned(7 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal ampPreLpPrevR                         : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:844:1-10
  signal \c$ampPreLpPrevR_app_arg\             : signed(23 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal ampPreLpPrevL                         : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:844:1-10
  signal \c$ampPreLpPrevL_app_arg\             : signed(23 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal x_35                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:163:1-7
  signal x_36                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:163:1-7
  signal ds1_12                                : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_82                             : clash_lowpass_fir_types.Maybe;
  -- src/LowPassFir.hs:513:1-17
  signal character                             : unsigned(7 downto 0);
  -- src/LowPassFir.hs:513:1-17
  signal \on_13\                               : boolean;
  signal result_83                             : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_127\                       : signed(23 downto 0);
  signal result_84                             : signed(23 downto 0);
  signal result_85                             : signed(23 downto 0);
  signal \c$case_alt_50\                       : signed(23 downto 0);
  signal result_86                             : signed(23 downto 0);
  signal \c$satWideOut_app_arg\                : signed(47 downto 0);
  signal \c$satWideOut_app_arg_0\              : signed(24 downto 0);
  signal \c$satWideOut_app_arg_1\              : signed(24 downto 0);
  signal \c$satWideOut_case_scrut\             : boolean;
  -- src/LowPassFir.hs:502:1-11
  signal positiveKnee                          : signed(23 downto 0);
  signal \c$satWideOut_app_arg_2\              : signed(24 downto 0);
  signal \c$satWideOut_app_arg_3\              : signed(24 downto 0);
  signal \c$satWideOut_app_arg_4\              : signed(23 downto 0);
  -- src/LowPassFir.hs:502:1-11
  signal negativeKnee                          : signed(23 downto 0);
  -- src/LowPassFir.hs:502:1-11
  signal ch                                    : signed(24 downto 0);
  signal \c$app_arg_128\                       : signed(23 downto 0);
  signal result_87                             : signed(23 downto 0);
  signal result_88                             : signed(23 downto 0);
  signal \c$case_alt_51\                       : signed(23 downto 0);
  signal result_89                             : signed(23 downto 0);
  signal \c$satWideOut_app_arg_5\              : signed(47 downto 0);
  signal \c$satWideOut_app_arg_6\              : signed(24 downto 0);
  signal \c$satWideOut_app_arg_7\              : signed(24 downto 0);
  signal \c$satWideOut_case_scrut_0\           : boolean;
  -- src/LowPassFir.hs:502:1-11
  signal positiveKnee_0                        : signed(23 downto 0);
  signal \c$satWideOut_app_arg_8\              : signed(24 downto 0);
  signal \c$satWideOut_app_arg_9\              : signed(24 downto 0);
  signal \c$satWideOut_app_arg_10\             : signed(23 downto 0);
  -- src/LowPassFir.hs:502:1-11
  signal negativeKnee_0                        : signed(23 downto 0);
  -- src/LowPassFir.hs:502:1-11
  signal ch_0                                  : signed(24 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal x_37                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:844:1-10
  signal ds1_13                                : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_90                             : clash_lowpass_fir_types.Maybe;
  signal \c$app_arg_129\                       : signed(47 downto 0);
  signal \c$case_alt_52\                       : signed(23 downto 0);
  signal result_91                             : signed(23 downto 0);
  signal \c$app_arg_130\                       : signed(23 downto 0);
  signal \c$app_arg_131\                       : signed(47 downto 0);
  signal \c$case_alt_53\                       : signed(23 downto 0);
  signal result_92                             : signed(23 downto 0);
  signal \c$app_arg_132\                       : signed(23 downto 0);
  signal result_93                             : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:496:1-18
  signal \on_14\                               : boolean;
  -- src/LowPassFir.hs:844:1-10
  signal x_38                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:844:1-10
  signal ds1_14                                : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_94                             : clash_lowpass_fir_types.Maybe;
  signal result_95                             : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_133\                       : signed(47 downto 0);
  signal \c$app_arg_134\                       : signed(47 downto 0);
  -- src/LowPassFir.hs:488:1-21
  signal \on_15\                               : boolean;
  signal \c$app_arg_135\                       : signed(47 downto 0);
  -- src/LowPassFir.hs:488:1-21
  signal gain_7                                : unsigned(11 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal ampHighpassPipe                       : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_96                             : clash_lowpass_fir_types.Maybe;
  -- src/LowPassFir.hs:122:1-7
  signal x_39                                  : signed(47 downto 0);
  signal \c$case_alt_54\                       : signed(23 downto 0);
  signal result_97                             : signed(23 downto 0);
  signal \c$app_arg_136\                       : signed(23 downto 0);
  -- src/LowPassFir.hs:122:1-7
  signal x_40                                  : signed(47 downto 0);
  signal \c$case_alt_55\                       : signed(23 downto 0);
  signal result_98                             : signed(23 downto 0);
  signal \c$app_arg_137\                       : signed(23 downto 0);
  signal result_99                             : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:475:1-16
  signal \on_16\                               : boolean;
  -- src/LowPassFir.hs:844:1-10
  signal ampHpOutPrevR                         : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:844:1-10
  signal \c$ampHpOutPrevR_app_arg\             : signed(23 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal ampHpOutPrevL                         : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:844:1-10
  signal \c$ampHpOutPrevL_app_arg\             : signed(23 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal ampHpInPrevR                          : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:844:1-10
  signal \c$ampHpInPrevR_app_arg\              : signed(23 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal ampHpInPrevL                          : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:844:1-10
  signal \c$ampHpInPrevL_app_arg\              : signed(23 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal x_41                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:163:1-7
  signal x_42                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:163:1-7
  signal ds1_15                                : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_100                            : clash_lowpass_fir_types.Maybe;
  signal result_101                            : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_138\                       : signed(23 downto 0);
  signal result_102                            : signed(23 downto 0);
  signal \c$case_alt_56\                       : signed(23 downto 0);
  signal \c$app_arg_139\                       : signed(24 downto 0);
  signal \c$app_arg_140\                       : signed(24 downto 0);
  signal \c$app_arg_141\                       : signed(24 downto 0);
  signal \c$case_alt_57\                       : signed(23 downto 0);
  signal result_103                            : signed(23 downto 0);
  signal \c$app_arg_142\                       : signed(47 downto 0);
  signal \c$app_arg_143\                       : signed(23 downto 0);
  -- src/LowPassFir.hs:465:1-11
  signal \on_17\                               : boolean;
  signal result_104                            : signed(23 downto 0);
  signal \c$case_alt_58\                       : signed(23 downto 0);
  signal \c$app_arg_144\                       : signed(24 downto 0);
  signal \c$app_arg_145\                       : signed(24 downto 0);
  signal \c$app_arg_146\                       : signed(24 downto 0);
  signal \c$case_alt_59\                       : signed(23 downto 0);
  signal result_105                            : signed(23 downto 0);
  signal \c$app_arg_147\                       : signed(47 downto 0);
  signal \c$app_arg_148\                       : signed(47 downto 0);
  signal \c$app_arg_149\                       : signed(47 downto 0);
  -- src/LowPassFir.hs:465:1-11
  signal invMix_0                              : unsigned(7 downto 0);
  -- src/LowPassFir.hs:465:1-11
  signal mix_0                                 : unsigned(7 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal x_43                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:844:1-10
  signal ds1_16                                : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_106                            : clash_lowpass_fir_types.Maybe;
  signal result_107                            : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_150\                       : signed(23 downto 0);
  signal \c$case_alt_60\                       : signed(23 downto 0);
  signal result_108                            : signed(23 downto 0);
  signal \c$app_arg_151\                       : signed(47 downto 0);
  signal \c$app_arg_152\                       : signed(23 downto 0);
  -- src/LowPassFir.hs:456:1-13
  signal \on_18\                               : boolean;
  signal \c$case_alt_61\                       : signed(23 downto 0);
  signal result_109                            : signed(23 downto 0);
  signal \c$app_arg_153\                       : signed(47 downto 0);
  signal \c$app_arg_154\                       : signed(47 downto 0);
  -- src/LowPassFir.hs:456:1-13
  signal level_1                               : unsigned(7 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal ratTonePipe                           : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_110                            : clash_lowpass_fir_types.Maybe;
  -- src/LowPassFir.hs:448:1-12
  signal alpha_0                               : unsigned(7 downto 0);
  -- src/LowPassFir.hs:448:1-12
  signal \on_19\                               : boolean;
  signal result_111                            : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_155\                       : signed(23 downto 0);
  signal \c$app_arg_156\                       : signed(47 downto 0);
  -- src/LowPassFir.hs:113:1-5
  signal gain_8                                : unsigned(7 downto 0);
  signal \c$case_alt_62\                       : signed(23 downto 0);
  signal result_112                            : signed(23 downto 0);
  signal \c$app_arg_157\                       : signed(23 downto 0);
  signal \c$app_arg_158\                       : signed(47 downto 0);
  -- src/LowPassFir.hs:113:1-5
  signal gain_9                                : unsigned(7 downto 0);
  signal \c$case_alt_63\                       : signed(23 downto 0);
  signal result_113                            : signed(23 downto 0);
  -- src/LowPassFir.hs:448:1-12
  signal \c$alpha_app_arg_0\                   : unsigned(9 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal ratTonePrevR                          : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:844:1-10
  signal \c$ratTonePrevR_app_arg\              : signed(23 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal ratTonePrevL                          : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:844:1-10
  signal \c$ratTonePrevL_app_arg\              : signed(23 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal x_44                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:844:1-10
  signal ratPostPipe                           : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_114                            : clash_lowpass_fir_types.Maybe;
  -- src/LowPassFir.hs:442:1-19
  signal \on_20\                               : boolean;
  signal result_115                            : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_159\                       : signed(23 downto 0);
  signal \c$app_arg_160\                       : signed(47 downto 0);
  signal \c$case_alt_64\                       : signed(23 downto 0);
  signal result_116                            : signed(23 downto 0);
  signal \c$app_arg_161\                       : signed(23 downto 0);
  signal \c$app_arg_162\                       : signed(47 downto 0);
  signal \c$case_alt_65\                       : signed(23 downto 0);
  signal result_117                            : signed(23 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal ratPostPrevR                          : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:844:1-10
  signal \c$ratPostPrevR_app_arg\              : signed(23 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal ratPostPrevL                          : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:844:1-10
  signal \c$ratPostPrevL_app_arg\              : signed(23 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal x_45                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:163:1-7
  signal x_46                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:163:1-7
  signal ds1_17                                : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_118                            : clash_lowpass_fir_types.Maybe;
  -- src/LowPassFir.hs:432:1-12
  signal threshold                             : signed(23 downto 0);
  -- src/LowPassFir.hs:432:1-12
  signal \on_21\                               : boolean;
  signal result_119                            : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_163\                       : signed(23 downto 0);
  signal result_120                            : signed(23 downto 0);
  signal \c$case_alt_66\                       : signed(23 downto 0);
  signal \c$app_arg_164\                       : signed(23 downto 0);
  signal \c$app_arg_165\                       : signed(23 downto 0);
  signal result_121                            : signed(23 downto 0);
  signal \c$case_alt_67\                       : signed(23 downto 0);
  signal \c$app_arg_166\                       : signed(23 downto 0);
  -- src/LowPassFir.hs:432:1-12
  signal rawThreshold                          : signed(24 downto 0);
  signal result_122                            : signed(24 downto 0);
  -- src/LowPassFir.hs:98:1-9
  signal x_47                                  : unsigned(7 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal ratOpAmpPipe                          : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_123                            : clash_lowpass_fir_types.Maybe;
  -- src/LowPassFir.hs:423:1-20
  signal alpha_1                               : unsigned(7 downto 0);
  -- src/LowPassFir.hs:423:1-20
  signal \on_22\                               : boolean;
  signal result_124                            : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_167\                       : signed(23 downto 0);
  signal \c$app_arg_168\                       : signed(47 downto 0);
  -- src/LowPassFir.hs:113:1-5
  signal gain_10                               : unsigned(7 downto 0);
  signal \c$case_alt_68\                       : signed(23 downto 0);
  signal result_125                            : signed(23 downto 0);
  signal \c$app_arg_169\                       : signed(23 downto 0);
  signal \c$app_arg_170\                       : signed(47 downto 0);
  -- src/LowPassFir.hs:113:1-5
  signal gain_11                               : unsigned(7 downto 0);
  signal \c$case_alt_69\                       : signed(23 downto 0);
  signal result_126                            : signed(23 downto 0);
  -- src/LowPassFir.hs:423:1-20
  signal \c$alpha_app_arg_1\                   : unsigned(7 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal ratOpAmpPrevR                         : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:844:1-10
  signal \c$ratOpAmpPrevR_app_arg\             : signed(23 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal ratOpAmpPrevL                         : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:844:1-10
  signal \c$ratOpAmpPrevL_app_arg\             : signed(23 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal x_48                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:163:1-7
  signal x_49                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:163:1-7
  signal ds1_18                                : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_127                            : clash_lowpass_fir_types.Maybe;
  signal \c$app_arg_171\                       : signed(47 downto 0);
  signal \c$case_alt_70\                       : signed(23 downto 0);
  signal result_128                            : signed(23 downto 0);
  signal \c$app_arg_172\                       : signed(23 downto 0);
  signal \c$app_arg_173\                       : signed(47 downto 0);
  signal \c$case_alt_71\                       : signed(23 downto 0);
  signal result_129                            : signed(23 downto 0);
  signal \c$app_arg_174\                       : signed(23 downto 0);
  signal result_130                            : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:417:1-18
  signal \on_23\                               : boolean;
  -- src/LowPassFir.hs:844:1-10
  signal x_50                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:844:1-10
  signal ds1_19                                : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_131                            : clash_lowpass_fir_types.Maybe;
  signal result_132                            : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_175\                       : signed(47 downto 0);
  signal \c$app_arg_176\                       : signed(47 downto 0);
  -- src/LowPassFir.hs:410:1-21
  signal \on_24\                               : boolean;
  signal \c$app_arg_177\                       : signed(47 downto 0);
  -- src/LowPassFir.hs:410:1-21
  signal driveGain                             : unsigned(11 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal ratHighpassPipe                       : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_133                            : clash_lowpass_fir_types.Maybe;
  -- src/LowPassFir.hs:122:1-7
  signal x_51                                  : signed(47 downto 0);
  signal \c$case_alt_72\                       : signed(23 downto 0);
  signal result_134                            : signed(23 downto 0);
  signal \c$app_arg_178\                       : signed(23 downto 0);
  -- src/LowPassFir.hs:122:1-7
  signal x_52                                  : signed(47 downto 0);
  signal \c$case_alt_73\                       : signed(23 downto 0);
  signal result_135                            : signed(23 downto 0);
  signal \c$app_arg_179\                       : signed(23 downto 0);
  signal result_136                            : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:397:1-16
  signal \on_25\                               : boolean;
  -- src/LowPassFir.hs:844:1-10
  signal ratHpOutPrevR                         : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:844:1-10
  signal \c$ratHpOutPrevR_app_arg\             : signed(23 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal ratHpOutPrevL                         : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:844:1-10
  signal \c$ratHpOutPrevL_app_arg\             : signed(23 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal ratHpInPrevR                          : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:844:1-10
  signal \c$ratHpInPrevR_app_arg\              : signed(23 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal ratHpInPrevL                          : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:844:1-10
  signal \c$ratHpInPrevL_app_arg\              : signed(23 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal x_53                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:163:1-7
  signal x_54                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:163:1-7
  signal ds1_20                                : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_137                            : clash_lowpass_fir_types.Maybe;
  signal result_138                            : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_180\                       : signed(23 downto 0);
  signal \c$case_alt_74\                       : signed(23 downto 0);
  signal result_139                            : signed(23 downto 0);
  signal \c$app_arg_181\                       : signed(47 downto 0);
  signal \c$app_arg_182\                       : signed(23 downto 0);
  -- src/LowPassFir.hs:388:1-20
  signal \on_26\                               : boolean;
  signal \c$case_alt_75\                       : signed(23 downto 0);
  signal result_140                            : signed(23 downto 0);
  signal \c$app_arg_183\                       : signed(47 downto 0);
  signal \c$app_arg_184\                       : signed(47 downto 0);
  -- src/LowPassFir.hs:388:1-20
  signal level_2                               : unsigned(7 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal distToneBlendPipe                     : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_141                            : clash_lowpass_fir_types.Maybe;
  signal \c$app_arg_185\                       : signed(47 downto 0);
  signal \c$case_alt_76\                       : signed(23 downto 0);
  signal result_142                            : signed(23 downto 0);
  signal \c$app_arg_186\                       : signed(23 downto 0);
  signal \c$app_arg_187\                       : signed(47 downto 0);
  signal \c$case_alt_77\                       : signed(23 downto 0);
  signal result_143                            : signed(23 downto 0);
  signal \c$app_arg_188\                       : signed(23 downto 0);
  signal result_144                            : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:377:1-24
  signal \on_27\                               : boolean;
  -- src/LowPassFir.hs:844:1-10
  signal x_55                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:844:1-10
  signal ds1_21                                : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_145                            : clash_lowpass_fir_types.Maybe;
  signal result_146                            : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_189\                       : signed(47 downto 0);
  signal \c$app_arg_190\                       : signed(47 downto 0);
  signal \c$app_arg_191\                       : signed(47 downto 0);
  -- src/LowPassFir.hs:364:1-27
  signal toneInv                               : unsigned(7 downto 0);
  signal \c$app_arg_192\                       : signed(47 downto 0);
  signal \c$app_arg_193\                       : signed(47 downto 0);
  -- src/LowPassFir.hs:364:1-27
  signal \on_28\                               : boolean;
  signal \c$app_arg_194\                       : signed(47 downto 0);
  -- src/LowPassFir.hs:364:1-27
  signal tone                                  : unsigned(7 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal distTonePrevR                         : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:844:1-10
  signal \c$distTonePrevR_app_arg\             : signed(23 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal distTonePrevL                         : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:844:1-10
  signal \c$distTonePrevL_app_arg\             : signed(23 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal x_56                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:163:1-7
  signal x_57                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:163:1-7
  signal ds1_22                                : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_147                            : clash_lowpass_fir_types.Maybe;
  -- src/LowPassFir.hs:357:1-24
  signal threshold_0                           : signed(23 downto 0);
  -- src/LowPassFir.hs:357:1-24
  signal \on_29\                               : boolean;
  signal result_148                            : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_195\                       : signed(23 downto 0);
  signal result_149                            : signed(23 downto 0);
  signal \c$case_alt_78\                       : signed(23 downto 0);
  signal \c$app_arg_196\                       : signed(23 downto 0);
  signal \c$app_arg_197\                       : signed(23 downto 0);
  signal result_150                            : signed(23 downto 0);
  signal \c$case_alt_79\                       : signed(23 downto 0);
  signal \c$app_arg_198\                       : signed(23 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal x_58                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:844:1-10
  signal ds1_23                                : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_151                            : clash_lowpass_fir_types.Maybe;
  signal \c$app_arg_199\                       : signed(47 downto 0);
  signal \c$case_alt_80\                       : signed(23 downto 0);
  signal result_152                            : signed(23 downto 0);
  signal \c$app_arg_200\                       : signed(23 downto 0);
  signal \c$app_arg_201\                       : signed(47 downto 0);
  signal \c$case_alt_81\                       : signed(23 downto 0);
  signal result_153                            : signed(23 downto 0);
  signal \c$app_arg_202\                       : signed(23 downto 0);
  signal result_154                            : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:351:1-25
  signal \on_30\                               : boolean;
  -- src/LowPassFir.hs:844:1-10
  signal x_59                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:844:1-10
  signal ds1_24                                : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_155                            : clash_lowpass_fir_types.Maybe;
  signal result_156                            : clash_lowpass_fir_types.Frame;
  signal result_157                            : signed(24 downto 0);
  -- src/LowPassFir.hs:336:1-28
  signal rawThreshold_0                        : signed(24 downto 0);
  signal \c$app_arg_203\                       : signed(47 downto 0);
  signal \c$app_arg_204\                       : signed(47 downto 0);
  -- src/LowPassFir.hs:336:1-28
  signal \on_31\                               : boolean;
  signal \c$app_arg_205\                       : signed(47 downto 0);
  -- src/LowPassFir.hs:336:1-28
  signal driveGain_0                           : unsigned(11 downto 0);
  -- src/LowPassFir.hs:336:1-28
  signal amount                                : unsigned(7 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal x_60                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:844:1-10
  signal ds1_25                                : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_158                            : clash_lowpass_fir_types.Maybe;
  signal result_159                            : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_206\                       : signed(23 downto 0);
  signal \c$case_alt_82\                       : signed(23 downto 0);
  signal result_160                            : signed(23 downto 0);
  signal \c$app_arg_207\                       : signed(47 downto 0);
  signal \c$app_arg_208\                       : signed(23 downto 0);
  -- src/LowPassFir.hs:327:1-19
  signal \on_32\                               : boolean;
  signal \c$case_alt_83\                       : signed(23 downto 0);
  signal result_161                            : signed(23 downto 0);
  signal \c$app_arg_209\                       : signed(47 downto 0);
  signal \c$app_arg_210\                       : signed(47 downto 0);
  -- src/LowPassFir.hs:327:1-19
  signal level_3                               : unsigned(7 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal odToneBlendPipe                       : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_162                            : clash_lowpass_fir_types.Maybe;
  signal \c$app_arg_211\                       : signed(47 downto 0);
  signal \c$case_alt_84\                       : signed(23 downto 0);
  signal result_163                            : signed(23 downto 0);
  signal \c$app_arg_212\                       : signed(23 downto 0);
  signal \c$app_arg_213\                       : signed(47 downto 0);
  signal \c$case_alt_85\                       : signed(23 downto 0);
  signal result_164                            : signed(23 downto 0);
  signal \c$app_arg_214\                       : signed(23 downto 0);
  signal result_165                            : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:316:1-23
  signal \on_33\                               : boolean;
  -- src/LowPassFir.hs:844:1-10
  signal x_61                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:844:1-10
  signal ds1_26                                : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_166                            : clash_lowpass_fir_types.Maybe;
  signal result_167                            : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_215\                       : signed(47 downto 0);
  signal \c$app_arg_216\                       : signed(47 downto 0);
  signal \c$app_arg_217\                       : signed(47 downto 0);
  -- src/LowPassFir.hs:303:1-26
  signal toneInv_0                             : unsigned(7 downto 0);
  signal \c$app_arg_218\                       : signed(47 downto 0);
  signal \c$app_arg_219\                       : signed(47 downto 0);
  -- src/LowPassFir.hs:303:1-26
  signal \on_34\                               : boolean;
  signal \c$app_arg_220\                       : signed(47 downto 0);
  -- src/LowPassFir.hs:303:1-26
  signal tone_0                                : unsigned(7 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal odTonePrevR                           : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:844:1-10
  signal \c$odTonePrevR_app_arg\               : signed(23 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal odTonePrevL                           : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:844:1-10
  signal \c$odTonePrevL_app_arg\               : signed(23 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal x_62                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:163:1-7
  signal x_63                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:163:1-7
  signal ds1_27                                : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_168                            : clash_lowpass_fir_types.Maybe;
  -- src/LowPassFir.hs:297:1-23
  signal \on_35\                               : boolean;
  signal result_169                            : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_221\                       : signed(23 downto 0);
  signal result_170                            : signed(23 downto 0);
  signal \c$case_alt_86\                       : signed(23 downto 0);
  signal \c$app_arg_222\                       : signed(24 downto 0);
  signal \c$app_arg_223\                       : signed(24 downto 0);
  signal \c$app_arg_224\                       : signed(24 downto 0);
  signal \c$app_arg_225\                       : signed(23 downto 0);
  signal result_171                            : signed(23 downto 0);
  signal \c$case_alt_87\                       : signed(23 downto 0);
  signal \c$app_arg_226\                       : signed(24 downto 0);
  signal \c$app_arg_227\                       : signed(24 downto 0);
  signal \c$app_arg_228\                       : signed(24 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal x_64                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:844:1-10
  signal ds1_28                                : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_172                            : clash_lowpass_fir_types.Maybe;
  signal \c$app_arg_229\                       : signed(47 downto 0);
  signal \c$case_alt_88\                       : signed(23 downto 0);
  signal result_173                            : signed(23 downto 0);
  signal \c$app_arg_230\                       : signed(23 downto 0);
  signal \c$app_arg_231\                       : signed(47 downto 0);
  signal \c$case_alt_89\                       : signed(23 downto 0);
  signal result_174                            : signed(23 downto 0);
  signal \c$app_arg_232\                       : signed(23 downto 0);
  signal result_175                            : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:291:1-24
  signal \on_36\                               : boolean;
  -- src/LowPassFir.hs:844:1-10
  signal x_65                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:844:1-10
  signal ds1_29                                : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_176                            : clash_lowpass_fir_types.Maybe;
  signal result_177                            : clash_lowpass_fir_types.Frame;
  signal \c$app_arg_233\                       : signed(47 downto 0);
  signal \c$app_arg_234\                       : signed(47 downto 0);
  -- src/LowPassFir.hs:284:1-27
  signal \on_37\                               : boolean;
  signal \c$app_arg_235\                       : signed(47 downto 0);
  -- src/LowPassFir.hs:284:1-27
  signal driveGain_1                           : unsigned(11 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal x_66                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:844:1-10
  signal ds1_30                                : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_178                            : clash_lowpass_fir_types.Maybe;
  signal result_179                            : clash_lowpass_fir_types.Frame;
  signal \c$case_alt_90\                       : signed(23 downto 0);
  signal result_180                            : signed(23 downto 0);
  signal \c$app_arg_236\                       : signed(47 downto 0);
  signal \c$case_alt_91\                       : signed(23 downto 0);
  signal result_181                            : signed(23 downto 0);
  signal \c$app_arg_237\                       : signed(47 downto 0);
  signal \c$app_arg_238\                       : signed(47 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal gateGain                              : unsigned(11 downto 0) := to_unsigned(4095,12);
  signal \c$case_alt_92\                       : unsigned(11 downto 0);
  signal \c$case_alt_93\                       : unsigned(11 downto 0);
  signal \c$case_alt_94\                       : unsigned(11 downto 0);
  signal \c$case_alt_95\                       : unsigned(11 downto 0);
  -- src/LowPassFir.hs:269:1-12
  signal f_2                                   : clash_lowpass_fir_types.Frame;
  signal result_182                            : unsigned(11 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal gateOpen                              : boolean := true;
  signal result_183                            : boolean;
  signal \c$case_alt_96\                       : boolean;
  signal result_184                            : boolean;
  signal \c$case_alt_97\                       : boolean;
  signal \c$case_alt_98\                       : boolean;
  -- src/LowPassFir.hs:122:1-7
  signal x_67                                  : signed(47 downto 0);
  signal \c$case_alt_99\                       : signed(23 downto 0);
  signal result_185                            : signed(23 downto 0);
  signal \c$app_arg_239\                       : signed(47 downto 0);
  signal \c$app_arg_240\                       : signed(47 downto 0);
  -- src/LowPassFir.hs:257:1-12
  signal closeThreshold                        : signed(23 downto 0);
  -- src/LowPassFir.hs:98:1-9
  signal x_68                                  : unsigned(7 downto 0);
  signal \c$app_arg_241\                       : std_logic_vector(31 downto 0);
  -- src/LowPassFir.hs:257:1-12
  signal f_3                                   : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:844:1-10
  signal gateEnv                               : signed(23 downto 0) := to_signed(0,24);
  -- src/LowPassFir.hs:246:1-11
  signal \c$decay_app_arg\                     : signed(24 downto 0);
  signal result_186                            : signed(23 downto 0);
  signal \c$case_alt_100\                      : signed(23 downto 0);
  signal \c$case_alt_101\                      : signed(23 downto 0);
  -- src/LowPassFir.hs:246:1-11
  signal f_4                                   : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:246:1-11
  signal decay                                 : signed(23 downto 0);
  signal result_187                            : signed(23 downto 0);
  -- src/LowPassFir.hs:163:1-7
  signal x_69                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:844:1-10
  signal gateLevelPipe                         : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  signal result_188                            : clash_lowpass_fir_types.Maybe;
  signal result_189                            : signed(23 downto 0);
  signal \c$case_alt_102\                      : clash_lowpass_fir_types.Frame;
  signal \c$case_alt_103\                      : signed(23 downto 0);
  signal result_190                            : signed(23 downto 0);
  signal \c$case_alt_104\                      : signed(23 downto 0);
  signal result_191                            : signed(23 downto 0);
  -- src/LowPassFir.hs:844:1-10
  signal x_70                                  : clash_lowpass_fir_types.Frame;
  -- src/LowPassFir.hs:844:1-10
  signal ds1_31                                : clash_lowpass_fir_types.Maybe := std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
  -- src/LowPassFir.hs:203:1-9
  signal validIn                               : boolean;
  -- src/LowPassFir.hs:203:1-9
  signal right                                 : signed(23 downto 0);
  -- src/LowPassFir.hs:203:1-9
  signal left                                  : signed(23 downto 0);
  signal result_192                            : clash_lowpass_fir_types.Tuple2_0;
  signal \c$app_arg_242\                       : std_logic_vector(47 downto 0);
  signal result_193                            : clash_lowpass_fir_types.Maybe;
  -- src/LowPassFir.hs:844:1-10
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
  signal \c$case_alt_selection_res_13\         : boolean;
  signal result_selection_res_16               : boolean;
  signal \c$shI_16\                            : signed(63 downto 0);
  signal \c$bv_8\                              : std_logic_vector(31 downto 0);
  signal result_selection_res_17               : boolean;
  signal \c$case_alt_selection_res_14\         : boolean;
  signal \c$shI_17\                            : signed(63 downto 0);
  signal \c$shI_18\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_15\         : boolean;
  signal result_selection_res_18               : boolean;
  signal \c$shI_19\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_16\         : boolean;
  signal result_selection_res_19               : boolean;
  signal \c$shI_20\                            : signed(63 downto 0);
  signal \c$shI_21\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_17\         : boolean;
  signal result_selection_res_20               : boolean;
  signal \c$shI_22\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_18\         : boolean;
  signal result_selection_res_21               : boolean;
  signal \c$bv_9\                              : std_logic_vector(31 downto 0);
  signal result_selection_res_22               : boolean;
  signal \c$case_alt_selection_res_19\         : boolean;
  signal \c$shI_23\                            : signed(63 downto 0);
  signal \c$shI_24\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_20\         : boolean;
  signal result_selection_res_23               : boolean;
  signal \c$shI_25\                            : signed(63 downto 0);
  signal \c$bv_10\                             : std_logic_vector(31 downto 0);
  signal result_selection_res_24               : boolean;
  signal \c$case_alt_selection_res_21\         : boolean;
  signal \c$shI_26\                            : signed(63 downto 0);
  signal \c$shI_27\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_22\         : boolean;
  signal result_selection_res_25               : boolean;
  signal \c$shI_28\                            : signed(63 downto 0);
  signal \c$bv_11\                             : std_logic_vector(31 downto 0);
  signal result_selection_res_26               : boolean;
  signal \c$case_alt_selection_res_23\         : boolean;
  signal \c$shI_29\                            : signed(63 downto 0);
  signal \c$shI_30\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_24\         : boolean;
  signal result_selection_res_27               : boolean;
  signal \c$case_alt_selection_res_25\         : boolean;
  signal result_selection_res_28               : boolean;
  signal \c$shI_31\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_26\         : boolean;
  signal result_selection_res_29               : boolean;
  signal \c$case_alt_selection_res_27\         : boolean;
  signal result_selection_res_30               : boolean;
  signal \c$shI_32\                            : signed(63 downto 0);
  signal \c$bv_12\                             : std_logic_vector(31 downto 0);
  signal result_selection_res_31               : boolean;
  signal \c$case_alt_selection_res_28\         : boolean;
  signal \c$shI_33\                            : signed(63 downto 0);
  signal \c$shI_34\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_29\         : boolean;
  signal result_selection_res_32               : boolean;
  signal \c$case_alt_selection_res_30\         : boolean;
  signal result_selection_res_33               : boolean;
  signal \c$shI_35\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_31\         : boolean;
  signal result_selection_res_34               : boolean;
  signal \c$case_alt_selection_res_32\         : boolean;
  signal result_selection_res_35               : boolean;
  signal \c$shI_36\                            : signed(63 downto 0);
  signal \c$shI_37\                            : signed(63 downto 0);
  signal \c$shI_38\                            : signed(63 downto 0);
  signal \c$shI_39\                            : signed(63 downto 0);
  signal \c$shI_40\                            : signed(63 downto 0);
  signal \c$bv_13\                             : std_logic_vector(31 downto 0);
  signal result_selection_res_36               : boolean;
  signal \c$case_alt_selection_res_33\         : boolean;
  signal \c$shI_41\                            : signed(63 downto 0);
  signal \c$shI_42\                            : signed(63 downto 0);
  signal result_selection_res_37               : boolean;
  signal \c$case_alt_selection_res_34\         : boolean;
  signal \c$shI_43\                            : signed(63 downto 0);
  signal \c$shI_44\                            : signed(63 downto 0);
  signal \c$shI_45\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_35\         : boolean;
  signal result_selection_res_38               : boolean;
  signal \c$shI_46\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_36\         : boolean;
  signal result_selection_res_39               : boolean;
  signal \c$bv_14\                             : std_logic_vector(31 downto 0);
  signal \c$shI_47\                            : signed(63 downto 0);
  signal \c$shI_48\                            : signed(63 downto 0);
  signal \c$bv_15\                             : std_logic_vector(31 downto 0);
  signal \c$shI_49\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_37\         : boolean;
  signal result_selection_res_40               : boolean;
  signal \c$case_alt_selection_res_38\         : boolean;
  signal result_selection_res_41               : boolean;
  signal \c$case_alt_selection_res_39\         : boolean;
  signal result_selection_res_42               : boolean;
  signal \c$case_alt_selection_res_40\         : boolean;
  signal result_selection_res_43               : boolean;
  signal \c$shI_50\                            : signed(63 downto 0);
  signal \c$shI_51\                            : signed(63 downto 0);
  signal \c$shI_52\                            : signed(63 downto 0);
  signal \c$shI_53\                            : signed(63 downto 0);
  signal \c$bv_16\                             : std_logic_vector(31 downto 0);
  signal \c$shI_54\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_41\         : boolean;
  signal result_selection_res_44               : boolean;
  signal \c$shI_55\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_42\         : boolean;
  signal result_selection_res_45               : boolean;
  signal \c$bv_17\                             : std_logic_vector(31 downto 0);
  signal \c$shI_56\                            : signed(63 downto 0);
  signal \c$bv_18\                             : std_logic_vector(31 downto 0);
  signal \c$bv_19\                             : std_logic_vector(31 downto 0);
  signal result_selection_res_46               : boolean;
  signal \c$case_alt_selection_res_43\         : boolean;
  signal result_selection_res_47               : boolean;
  signal \c$shI_57\                            : signed(63 downto 0);
  signal \c$shI_58\                            : signed(63 downto 0);
  signal result_selection_res_48               : boolean;
  signal \c$case_alt_selection_res_44\         : boolean;
  signal result_selection_res_49               : boolean;
  signal \c$shI_59\                            : signed(63 downto 0);
  signal \c$shI_60\                            : signed(63 downto 0);
  signal \c$shI_61\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_45\         : boolean;
  signal result_selection_res_50               : boolean;
  signal \c$shI_62\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_46\         : boolean;
  signal result_selection_res_51               : boolean;
  signal \c$bv_20\                             : std_logic_vector(31 downto 0);
  signal \c$bv_21\                             : std_logic_vector(31 downto 0);
  signal \c$bv_22\                             : std_logic_vector(31 downto 0);
  signal \c$case_alt_selection_res_47\         : boolean;
  signal result_selection_res_52               : boolean;
  signal \c$case_alt_selection_res_48\         : boolean;
  signal result_selection_res_53               : boolean;
  signal \c$bv_23\                             : std_logic_vector(31 downto 0);
  signal result_selection_res_54               : boolean;
  signal \c$case_alt_selection_res_49\         : boolean;
  signal \c$shI_63\                            : signed(63 downto 0);
  signal \c$shI_64\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_50\         : boolean;
  signal result_selection_res_55               : boolean;
  signal \c$shI_65\                            : signed(63 downto 0);
  signal \c$bv_24\                             : std_logic_vector(31 downto 0);
  signal result_selection_res_56               : boolean;
  signal \c$case_alt_selection_res_51\         : boolean;
  signal \c$shI_66\                            : signed(63 downto 0);
  signal \c$shI_67\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_52\         : boolean;
  signal result_selection_res_57               : boolean;
  signal \c$shI_68\                            : signed(63 downto 0);
  signal \c$bv_25\                             : std_logic_vector(31 downto 0);
  signal \c$case_alt_selection_res_53\         : boolean;
  signal result_selection_res_58               : boolean;
  signal \c$shI_69\                            : signed(63 downto 0);
  signal \c$bv_26\                             : std_logic_vector(31 downto 0);
  signal \c$case_alt_selection_res_54\         : boolean;
  signal result_selection_res_59               : boolean;
  signal \c$shI_70\                            : signed(63 downto 0);
  signal \c$bv_27\                             : std_logic_vector(31 downto 0);
  signal \c$bv_28\                             : std_logic_vector(31 downto 0);
  signal \c$shI_71\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_55\         : boolean;
  signal result_selection_res_60               : boolean;
  signal \c$shI_72\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_56\         : boolean;
  signal result_selection_res_61               : boolean;
  signal \c$bv_29\                             : std_logic_vector(31 downto 0);
  signal \c$shI_73\                            : signed(63 downto 0);
  signal \c$bv_30\                             : std_logic_vector(31 downto 0);
  signal \c$shI_74\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_57\         : boolean;
  signal result_selection_res_62               : boolean;
  signal \c$shI_75\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_58\         : boolean;
  signal result_selection_res_63               : boolean;
  signal \c$bv_31\                             : std_logic_vector(31 downto 0);
  signal result_selection_res_64               : boolean;
  signal \c$case_alt_selection_res_59\         : boolean;
  signal result_selection_res_65               : boolean;
  signal \c$case_alt_selection_res_60\         : boolean;
  signal result_selection_res_66               : boolean;
  signal \c$bv_32\                             : std_logic_vector(31 downto 0);
  signal \c$bv_33\                             : std_logic_vector(31 downto 0);
  signal \c$shI_76\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_61\         : boolean;
  signal result_selection_res_67               : boolean;
  signal \c$shI_77\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_62\         : boolean;
  signal result_selection_res_68               : boolean;
  signal \c$bv_34\                             : std_logic_vector(31 downto 0);
  signal \c$shI_78\                            : signed(63 downto 0);
  signal \c$shI_79\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_63\         : boolean;
  signal result_selection_res_69               : boolean;
  signal \c$shI_80\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_64\         : boolean;
  signal result_selection_res_70               : boolean;
  signal \c$bv_35\                             : std_logic_vector(31 downto 0);
  signal \c$bv_36\                             : std_logic_vector(31 downto 0);
  signal \c$bv_37\                             : std_logic_vector(31 downto 0);
  signal \c$case_alt_selection_res_65\         : boolean;
  signal result_selection_res_71               : boolean;
  signal \c$case_alt_selection_res_66\         : boolean;
  signal result_selection_res_72               : boolean;
  signal \c$bv_38\                             : std_logic_vector(31 downto 0);
  signal \c$case_alt_selection_res_67\         : boolean;
  signal result_selection_res_73               : boolean;
  signal \c$shI_81\                            : signed(63 downto 0);
  signal \c$bv_39\                             : std_logic_vector(31 downto 0);
  signal \c$case_alt_selection_res_68\         : boolean;
  signal result_selection_res_74               : boolean;
  signal \c$shI_82\                            : signed(63 downto 0);
  signal \c$bv_40\                             : std_logic_vector(31 downto 0);
  signal \c$shI_83\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_69\         : boolean;
  signal result_selection_res_75               : boolean;
  signal \c$shI_84\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_70\         : boolean;
  signal result_selection_res_76               : boolean;
  signal \c$bv_41\                             : std_logic_vector(31 downto 0);
  signal \c$bv_42\                             : std_logic_vector(31 downto 0);
  signal \c$bv_43\                             : std_logic_vector(31 downto 0);
  signal \c$bv_44\                             : std_logic_vector(31 downto 0);
  signal result_selection_res_77               : boolean;
  signal \c$case_alt_selection_res_71\         : boolean;
  signal result_selection_res_78               : boolean;
  signal \c$case_alt_selection_res_72\         : boolean;
  signal \c$shI_85\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_73\         : boolean;
  signal result_selection_res_79               : boolean;
  signal \c$shI_86\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_74\         : boolean;
  signal result_selection_res_80               : boolean;
  signal \c$bv_45\                             : std_logic_vector(31 downto 0);
  signal result_selection_res_81               : boolean;
  signal \c$bv_46\                             : std_logic_vector(31 downto 0);
  signal \c$bv_47\                             : std_logic_vector(31 downto 0);
  signal \c$case_alt_selection_res_75\         : boolean;
  signal result_selection_res_82               : boolean;
  signal \c$shI_87\                            : signed(63 downto 0);
  signal \c$bv_48\                             : std_logic_vector(31 downto 0);
  signal \c$case_alt_selection_res_76\         : boolean;
  signal result_selection_res_83               : boolean;
  signal \c$shI_88\                            : signed(63 downto 0);
  signal \c$bv_49\                             : std_logic_vector(31 downto 0);
  signal \c$shI_89\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_77\         : boolean;
  signal result_selection_res_84               : boolean;
  signal \c$shI_90\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_78\         : boolean;
  signal result_selection_res_85               : boolean;
  signal \c$bv_50\                             : std_logic_vector(31 downto 0);
  signal \c$bv_51\                             : std_logic_vector(31 downto 0);
  signal \c$bv_52\                             : std_logic_vector(31 downto 0);
  signal \c$bv_53\                             : std_logic_vector(31 downto 0);
  signal result_selection_res_86               : boolean;
  signal \c$case_alt_selection_res_79\         : boolean;
  signal \c$shI_91\                            : signed(63 downto 0);
  signal \c$shI_92\                            : signed(63 downto 0);
  signal result_selection_res_87               : boolean;
  signal \c$case_alt_selection_res_80\         : boolean;
  signal \c$shI_93\                            : signed(63 downto 0);
  signal \c$shI_94\                            : signed(63 downto 0);
  signal \c$shI_95\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_81\         : boolean;
  signal result_selection_res_88               : boolean;
  signal \c$shI_96\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_82\         : boolean;
  signal result_selection_res_89               : boolean;
  signal \c$bv_54\                             : std_logic_vector(31 downto 0);
  signal \c$bv_55\                             : std_logic_vector(31 downto 0);
  signal \c$bv_56\                             : std_logic_vector(31 downto 0);
  signal result_selection_res_90               : boolean;
  signal \c$bv_57\                             : std_logic_vector(31 downto 0);
  signal \c$case_alt_selection_res_83\         : boolean;
  signal result_selection_res_91               : boolean;
  signal \c$shI_97\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_84\         : boolean;
  signal result_selection_res_92               : boolean;
  signal \c$shI_98\                            : signed(63 downto 0);
  signal \c$case_alt_selection_res_85\         : boolean;
  signal \c$case_alt_selection_res_86\         : boolean;
  signal \c$case_alt_selection_res_87\         : boolean;
  signal \c$bv_58\                             : std_logic_vector(31 downto 0);
  signal \c$case_alt_selection_res_88\         : boolean;
  signal \c$case_alt_selection_res_89\         : boolean;
  signal \c$case_alt_selection_res_90\         : boolean;
  signal \c$case_alt_selection_res_91\         : boolean;
  signal result_selection_res_93               : boolean;
  signal \c$shI_99\                            : signed(63 downto 0);
  signal \c$shI_100\                           : signed(63 downto 0);
  signal \c$shI_101\                           : signed(63 downto 0);
  signal result_selection_res_94               : boolean;
  signal \c$case_alt_selection_res_92\         : boolean;
  signal \c$case_alt_selection_res_93\         : boolean;
  signal \c$bv_59\                             : std_logic_vector(31 downto 0);
  signal result_selection_res_95               : boolean;
  signal \c$case_alt_selection_res_94\         : boolean;
  signal result_selection_res_96               : boolean;
  signal \c$case_alt_selection_res_95\         : boolean;
  signal result_selection_res_97               : boolean;
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

  with (ampMasterPipe(971 downto 971)) select
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
    \c$app_arg_57\ <= shift_right(((((resize((resize(x_16.Frame_sel0_fL,48)) * to_signed(112,48), 48)) + (resize((resize(cabD1L,48)) * to_signed(80,48), 48))) + (resize((resize(cabD2L,48)) * to_signed(48,48), 48))) + (resize((resize(cabD3L,48)) * to_signed(24,48), 48))),sh_21)
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
    \c$app_arg_59\ <= shift_right(((((resize((resize(x_16.Frame_sel1_fR,48)) * to_signed(112,48), 48)) + (resize((resize(cabD1R,48)) * to_signed(80,48), 48))) + (resize((resize(cabD2R,48)) * to_signed(48,48), 48))) + (resize((resize(cabD3R,48)) * to_signed(24,48), 48))),sh_22)
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
                           x_16.Frame_sel0_fL when others;

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
                           x_16.Frame_sel1_fR when others;

  x_16 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ampMasterPipe(970 downto 0)));

  -- register begin
  ampMasterPipe_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ampMasterPipe <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ampMasterPipe <= result_43;
    end if;
  end process;
  -- register end

  with (ds1_7(971 downto 971)) select
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

  result_44 <= ( Frame_sel0_fL => \c$app_arg_66\
               , Frame_sel1_fR => \c$app_arg_61\
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
               , Frame_sel27_fAccL => x_17.Frame_sel27_fAccL
               , Frame_sel28_fAccR => x_17.Frame_sel28_fAccR
               , Frame_sel29_fAcc2L => x_17.Frame_sel29_fAcc2L
               , Frame_sel30_fAcc2R => x_17.Frame_sel30_fAcc2R
               , Frame_sel31_fAcc3L => x_17.Frame_sel31_fAcc3L
               , Frame_sel32_fAcc3R => x_17.Frame_sel32_fAcc3R );

  \c$app_arg_61\ <= result_45 when \on_7\ else
                    x_17.Frame_sel1_fR;

  result_selection_res_22 <= result_46 > to_signed(4194304,24);

  result_45 <= resize((to_signed(4194304,25) + \c$app_arg_62\),24) when result_selection_res_22 else
               \c$case_alt_23\;

  \c$case_alt_selection_res_19\ <= result_46 < to_signed(-4194304,24);

  \c$case_alt_23\ <= resize((to_signed(-4194304,25) + \c$app_arg_63\),24) when \c$case_alt_selection_res_19\ else
                     result_46;

  \c$shI_23\ <= (to_signed(2,64));

  capp_arg_62_shiftR : block
    signal sh_23 : natural;
  begin
    sh_23 <=
        -- pragma translate_off
        natural'high when (\c$shI_23\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_23\);
    \c$app_arg_62\ <= shift_right((\c$app_arg_64\ - to_signed(4194304,25)),sh_23)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$shI_24\ <= (to_signed(2,64));

  capp_arg_63_shiftR : block
    signal sh_24 : natural;
  begin
    sh_24 <=
        -- pragma translate_off
        natural'high when (\c$shI_24\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_24\);
    \c$app_arg_63\ <= shift_right((\c$app_arg_64\ + to_signed(4194304,25)),sh_24)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_64\ <= resize(result_46,25);

  \c$case_alt_selection_res_20\ <= \c$app_arg_65\ < to_signed(-8388608,48);

  \c$case_alt_24\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_20\ else
                     resize(\c$app_arg_65\,24);

  result_selection_res_23 <= \c$app_arg_65\ > to_signed(8388607,48);

  result_46 <= to_signed(8388607,24) when result_selection_res_23 else
               \c$case_alt_24\;

  \c$shI_25\ <= (to_signed(7,64));

  capp_arg_65_shiftR : block
    signal sh_25 : natural;
  begin
    sh_25 <=
        -- pragma translate_off
        natural'high when (\c$shI_25\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_25\);
    \c$app_arg_65\ <= shift_right((resize((resize(x_17.Frame_sel16_fWetR,48)) * \c$app_arg_71\, 48)),sh_25)
        -- pragma translate_off
        when ((to_signed(7,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_66\ <= result_47 when \on_7\ else
                    x_17.Frame_sel0_fL;

  \c$bv_10\ <= (x_17.Frame_sel3_fGate);

  \on_7\ <= (\c$bv_10\(6 downto 6)) = std_logic_vector'("1");

  result_selection_res_24 <= result_48 > to_signed(4194304,24);

  result_47 <= resize((to_signed(4194304,25) + \c$app_arg_67\),24) when result_selection_res_24 else
               \c$case_alt_25\;

  \c$case_alt_selection_res_21\ <= result_48 < to_signed(-4194304,24);

  \c$case_alt_25\ <= resize((to_signed(-4194304,25) + \c$app_arg_68\),24) when \c$case_alt_selection_res_21\ else
                     result_48;

  \c$shI_26\ <= (to_signed(2,64));

  capp_arg_67_shiftR : block
    signal sh_26 : natural;
  begin
    sh_26 <=
        -- pragma translate_off
        natural'high when (\c$shI_26\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_26\);
    \c$app_arg_67\ <= shift_right((\c$app_arg_69\ - to_signed(4194304,25)),sh_26)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$shI_27\ <= (to_signed(2,64));

  capp_arg_68_shiftR : block
    signal sh_27 : natural;
  begin
    sh_27 <=
        -- pragma translate_off
        natural'high when (\c$shI_27\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_27\);
    \c$app_arg_68\ <= shift_right((\c$app_arg_69\ + to_signed(4194304,25)),sh_27)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_69\ <= resize(result_48,25);

  \c$case_alt_selection_res_22\ <= \c$app_arg_70\ < to_signed(-8388608,48);

  \c$case_alt_26\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_22\ else
                     resize(\c$app_arg_70\,24);

  result_selection_res_25 <= \c$app_arg_70\ > to_signed(8388607,48);

  result_48 <= to_signed(8388607,24) when result_selection_res_25 else
               \c$case_alt_26\;

  \c$shI_28\ <= (to_signed(7,64));

  capp_arg_70_shiftR : block
    signal sh_28 : natural;
  begin
    sh_28 <=
        -- pragma translate_off
        natural'high when (\c$shI_28\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_28\);
    \c$app_arg_70\ <= shift_right((resize((resize(x_17.Frame_sel15_fWetL,48)) * \c$app_arg_71\, 48)),sh_28)
        -- pragma translate_off
        when ((to_signed(7,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_71\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(level_0)))))))),48);

  \c$bv_11\ <= (x_17.Frame_sel8_fAmp);

  level_0 <= unsigned((\c$bv_11\(15 downto 8)));

  x_17 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_7(970 downto 0)));

  -- register begin
  ds1_7_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_7 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_7 <= result_49;
    end if;
  end process;
  -- register end

  with (ampResPresenceFilterPipe(971 downto 971)) select
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

  result_50 <= ( Frame_sel0_fL => x_22.Frame_sel0_fL
               , Frame_sel1_fR => x_22.Frame_sel1_fR
               , Frame_sel2_fLast => x_22.Frame_sel2_fLast
               , Frame_sel3_fGate => x_22.Frame_sel3_fGate
               , Frame_sel4_fOd => x_22.Frame_sel4_fOd
               , Frame_sel5_fDist => x_22.Frame_sel5_fDist
               , Frame_sel6_fEq => x_22.Frame_sel6_fEq
               , Frame_sel7_fRat => x_22.Frame_sel7_fRat
               , Frame_sel8_fAmp => x_22.Frame_sel8_fAmp
               , Frame_sel9_fAmpTone => x_22.Frame_sel9_fAmpTone
               , Frame_sel10_fCab => x_22.Frame_sel10_fCab
               , Frame_sel11_fReverb => x_22.Frame_sel11_fReverb
               , Frame_sel12_fAddr => x_22.Frame_sel12_fAddr
               , Frame_sel13_fDryL => x_22.Frame_sel13_fDryL
               , Frame_sel14_fDryR => x_22.Frame_sel14_fDryR
               , Frame_sel15_fWetL => \c$app_arg_79\
               , Frame_sel16_fWetR => \c$app_arg_72\
               , Frame_sel17_fFbL => x_22.Frame_sel17_fFbL
               , Frame_sel18_fFbR => x_22.Frame_sel18_fFbR
               , Frame_sel19_fEqLowL => x_22.Frame_sel19_fEqLowL
               , Frame_sel20_fEqLowR => x_22.Frame_sel20_fEqLowR
               , Frame_sel21_fEqMidL => x_22.Frame_sel21_fEqMidL
               , Frame_sel22_fEqMidR => x_22.Frame_sel22_fEqMidR
               , Frame_sel23_fEqHighL => x_22.Frame_sel23_fEqHighL
               , Frame_sel24_fEqHighR => x_22.Frame_sel24_fEqHighR
               , Frame_sel25_fEqHighLpL => x_22.Frame_sel25_fEqHighLpL
               , Frame_sel26_fEqHighLpR => x_22.Frame_sel26_fEqHighLpR
               , Frame_sel27_fAccL => x_22.Frame_sel27_fAccL
               , Frame_sel28_fAccR => x_22.Frame_sel28_fAccR
               , Frame_sel29_fAcc2L => x_22.Frame_sel29_fAcc2L
               , Frame_sel30_fAcc2R => x_22.Frame_sel30_fAcc2R
               , Frame_sel31_fAcc3L => x_22.Frame_sel31_fAcc3L
               , Frame_sel32_fAcc3R => x_22.Frame_sel32_fAcc3R );

  \c$app_arg_72\ <= result_51 when \on_8\ else
                    x_22.Frame_sel1_fR;

  result_selection_res_26 <= result_52 > to_signed(4194304,24);

  result_51 <= resize((to_signed(4194304,25) + \c$app_arg_73\),24) when result_selection_res_26 else
               \c$case_alt_27\;

  \c$case_alt_selection_res_23\ <= result_52 < to_signed(-4194304,24);

  \c$case_alt_27\ <= resize((to_signed(-4194304,25) + \c$app_arg_74\),24) when \c$case_alt_selection_res_23\ else
                     result_52;

  \c$shI_29\ <= (to_signed(2,64));

  capp_arg_73_shiftR : block
    signal sh_29 : natural;
  begin
    sh_29 <=
        -- pragma translate_off
        natural'high when (\c$shI_29\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_29\);
    \c$app_arg_73\ <= shift_right((\c$app_arg_75\ - to_signed(4194304,25)),sh_29)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$shI_30\ <= (to_signed(2,64));

  capp_arg_74_shiftR : block
    signal sh_30 : natural;
  begin
    sh_30 <=
        -- pragma translate_off
        natural'high when (\c$shI_30\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_30\);
    \c$app_arg_74\ <= shift_right((\c$app_arg_75\ + to_signed(4194304,25)),sh_30)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_75\ <= resize(result_52,25);

  x_18 <= (\c$app_arg_78\ + (resize(result_55,48))) + (resize(result_53,48));

  \c$case_alt_selection_res_24\ <= x_18 < to_signed(-8388608,48);

  \c$case_alt_28\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_24\ else
                     resize(x_18,24);

  result_selection_res_27 <= x_18 > to_signed(8388607,48);

  result_52 <= to_signed(8388607,24) when result_selection_res_27 else
               \c$case_alt_28\;

  \c$case_alt_selection_res_25\ <= \c$app_arg_76\ < to_signed(-8388608,48);

  \c$case_alt_29\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_25\ else
                     resize(\c$app_arg_76\,24);

  result_selection_res_28 <= \c$app_arg_76\ > to_signed(8388607,48);

  result_53 <= to_signed(8388607,24) when result_selection_res_28 else
               \c$case_alt_29\;

  \c$shI_31\ <= (to_signed(9,64));

  capp_arg_76_shiftR : block
    signal sh_31 : natural;
  begin
    sh_31 <=
        -- pragma translate_off
        natural'high when (\c$shI_31\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_31\);
    \c$app_arg_76\ <= shift_right((resize((resize(result_54,48)) * \c$app_arg_84\, 48)),sh_31)
        -- pragma translate_off
        when ((to_signed(9,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  x_19 <= \c$app_arg_78\ - (resize(x_22.Frame_sel26_fEqHighLpR,48));

  \c$case_alt_selection_res_26\ <= x_19 < to_signed(-8388608,48);

  \c$case_alt_30\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_26\ else
                     resize(x_19,24);

  result_selection_res_29 <= x_19 > to_signed(8388607,48);

  result_54 <= to_signed(8388607,24) when result_selection_res_29 else
               \c$case_alt_30\;

  \c$case_alt_selection_res_27\ <= \c$app_arg_77\ < to_signed(-8388608,48);

  \c$case_alt_31\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_27\ else
                     resize(\c$app_arg_77\,24);

  result_selection_res_30 <= \c$app_arg_77\ > to_signed(8388607,48);

  result_55 <= to_signed(8388607,24) when result_selection_res_30 else
               \c$case_alt_31\;

  \c$shI_32\ <= (to_signed(10,64));

  capp_arg_77_shiftR : block
    signal sh_32 : natural;
  begin
    sh_32 <=
        -- pragma translate_off
        natural'high when (\c$shI_32\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_32\);
    \c$app_arg_77\ <= shift_right((resize((resize(x_22.Frame_sel20_fEqLowR,48)) * \c$app_arg_86\, 48)),sh_32)
        -- pragma translate_off
        when ((to_signed(10,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_78\ <= resize(x_22.Frame_sel16_fWetR,48);

  \c$app_arg_79\ <= result_56 when \on_8\ else
                    x_22.Frame_sel0_fL;

  \c$bv_12\ <= (x_22.Frame_sel3_fGate);

  \on_8\ <= (\c$bv_12\(6 downto 6)) = std_logic_vector'("1");

  result_selection_res_31 <= result_57 > to_signed(4194304,24);

  result_56 <= resize((to_signed(4194304,25) + \c$app_arg_80\),24) when result_selection_res_31 else
               \c$case_alt_32\;

  \c$case_alt_selection_res_28\ <= result_57 < to_signed(-4194304,24);

  \c$case_alt_32\ <= resize((to_signed(-4194304,25) + \c$app_arg_81\),24) when \c$case_alt_selection_res_28\ else
                     result_57;

  \c$shI_33\ <= (to_signed(2,64));

  capp_arg_80_shiftR : block
    signal sh_33 : natural;
  begin
    sh_33 <=
        -- pragma translate_off
        natural'high when (\c$shI_33\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_33\);
    \c$app_arg_80\ <= shift_right((\c$app_arg_82\ - to_signed(4194304,25)),sh_33)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$shI_34\ <= (to_signed(2,64));

  capp_arg_81_shiftR : block
    signal sh_34 : natural;
  begin
    sh_34 <=
        -- pragma translate_off
        natural'high when (\c$shI_34\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_34\);
    \c$app_arg_81\ <= shift_right((\c$app_arg_82\ + to_signed(4194304,25)),sh_34)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_82\ <= resize(result_57,25);

  x_20 <= (\c$app_arg_87\ + (resize(result_60,48))) + (resize(result_58,48));

  \c$case_alt_selection_res_29\ <= x_20 < to_signed(-8388608,48);

  \c$case_alt_33\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_29\ else
                     resize(x_20,24);

  result_selection_res_32 <= x_20 > to_signed(8388607,48);

  result_57 <= to_signed(8388607,24) when result_selection_res_32 else
               \c$case_alt_33\;

  \c$case_alt_selection_res_30\ <= \c$app_arg_83\ < to_signed(-8388608,48);

  \c$case_alt_34\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_30\ else
                     resize(\c$app_arg_83\,24);

  result_selection_res_33 <= \c$app_arg_83\ > to_signed(8388607,48);

  result_58 <= to_signed(8388607,24) when result_selection_res_33 else
               \c$case_alt_34\;

  \c$shI_35\ <= (to_signed(9,64));

  capp_arg_83_shiftR : block
    signal sh_35 : natural;
  begin
    sh_35 <=
        -- pragma translate_off
        natural'high when (\c$shI_35\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_35\);
    \c$app_arg_83\ <= shift_right((resize((resize(result_59,48)) * \c$app_arg_84\, 48)),sh_35)
        -- pragma translate_off
        when ((to_signed(9,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_84\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(presence)))))))),48);

  presence <= unsigned((\c$presence_app_arg\(23 downto 16)));

  x_21 <= \c$app_arg_87\ - (resize(x_22.Frame_sel25_fEqHighLpL,48));

  \c$case_alt_selection_res_31\ <= x_21 < to_signed(-8388608,48);

  \c$case_alt_35\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_31\ else
                     resize(x_21,24);

  result_selection_res_34 <= x_21 > to_signed(8388607,48);

  result_59 <= to_signed(8388607,24) when result_selection_res_34 else
               \c$case_alt_35\;

  \c$case_alt_selection_res_32\ <= \c$app_arg_85\ < to_signed(-8388608,48);

  \c$case_alt_36\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_32\ else
                     resize(\c$app_arg_85\,24);

  result_selection_res_35 <= \c$app_arg_85\ > to_signed(8388607,48);

  result_60 <= to_signed(8388607,24) when result_selection_res_35 else
               \c$case_alt_36\;

  \c$shI_36\ <= (to_signed(10,64));

  capp_arg_85_shiftR : block
    signal sh_36 : natural;
  begin
    sh_36 <=
        -- pragma translate_off
        natural'high when (\c$shI_36\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_36\);
    \c$app_arg_85\ <= shift_right((resize((resize(x_22.Frame_sel19_fEqLowL,48)) * \c$app_arg_86\, 48)),sh_36)
        -- pragma translate_off
        when ((to_signed(10,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_86\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(resonance)))))))),48);

  resonance <= unsigned((\c$presence_app_arg\(31 downto 24)));

  \c$app_arg_87\ <= resize(x_22.Frame_sel15_fWetL,48);

  \c$presence_app_arg\ <= x_22.Frame_sel8_fAmp;

  -- register begin
  ampResPresenceFilterPipe_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ampResPresenceFilterPipe <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ampResPresenceFilterPipe <= result_61;
    end if;
  end process;
  -- register end

  with (ds1_8(971 downto 971)) select
    result_61 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(\c$case_alt_37\.Frame_sel0_fL)
                  & std_logic_vector(\c$case_alt_37\.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(\c$case_alt_37\.Frame_sel2_fLast)
                  & \c$case_alt_37\.Frame_sel3_fGate
                  & \c$case_alt_37\.Frame_sel4_fOd
                  & \c$case_alt_37\.Frame_sel5_fDist
                  & \c$case_alt_37\.Frame_sel6_fEq
                  & \c$case_alt_37\.Frame_sel7_fRat
                  & \c$case_alt_37\.Frame_sel8_fAmp
                  & \c$case_alt_37\.Frame_sel9_fAmpTone
                  & \c$case_alt_37\.Frame_sel10_fCab
                  & \c$case_alt_37\.Frame_sel11_fReverb
                  & std_logic_vector(\c$case_alt_37\.Frame_sel12_fAddr)
                  & std_logic_vector(\c$case_alt_37\.Frame_sel13_fDryL)
                  & std_logic_vector(\c$case_alt_37\.Frame_sel14_fDryR)
                  & std_logic_vector(\c$case_alt_37\.Frame_sel15_fWetL)
                  & std_logic_vector(\c$case_alt_37\.Frame_sel16_fWetR)
                  & std_logic_vector(\c$case_alt_37\.Frame_sel17_fFbL)
                  & std_logic_vector(\c$case_alt_37\.Frame_sel18_fFbR)
                  & std_logic_vector(\c$case_alt_37\.Frame_sel19_fEqLowL)
                  & std_logic_vector(\c$case_alt_37\.Frame_sel20_fEqLowR)
                  & std_logic_vector(\c$case_alt_37\.Frame_sel21_fEqMidL)
                  & std_logic_vector(\c$case_alt_37\.Frame_sel22_fEqMidR)
                  & std_logic_vector(\c$case_alt_37\.Frame_sel23_fEqHighL)
                  & std_logic_vector(\c$case_alt_37\.Frame_sel24_fEqHighR)
                  & std_logic_vector(\c$case_alt_37\.Frame_sel25_fEqHighLpL)
                  & std_logic_vector(\c$case_alt_37\.Frame_sel26_fEqHighLpR)
                  & std_logic_vector(\c$case_alt_37\.Frame_sel27_fAccL)
                  & std_logic_vector(\c$case_alt_37\.Frame_sel28_fAccR)
                  & std_logic_vector(\c$case_alt_37\.Frame_sel29_fAcc2L)
                  & std_logic_vector(\c$case_alt_37\.Frame_sel30_fAcc2R)
                  & std_logic_vector(\c$case_alt_37\.Frame_sel31_fAcc3L)
                  & std_logic_vector(\c$case_alt_37\.Frame_sel32_fAcc3R)))) when others;

  \c$case_alt_37\ <= ( Frame_sel0_fL => x_23.Frame_sel0_fL
                     , Frame_sel1_fR => x_23.Frame_sel1_fR
                     , Frame_sel2_fLast => x_23.Frame_sel2_fLast
                     , Frame_sel3_fGate => x_23.Frame_sel3_fGate
                     , Frame_sel4_fOd => x_23.Frame_sel4_fOd
                     , Frame_sel5_fDist => x_23.Frame_sel5_fDist
                     , Frame_sel6_fEq => x_23.Frame_sel6_fEq
                     , Frame_sel7_fRat => x_23.Frame_sel7_fRat
                     , Frame_sel8_fAmp => x_23.Frame_sel8_fAmp
                     , Frame_sel9_fAmpTone => x_23.Frame_sel9_fAmpTone
                     , Frame_sel10_fCab => x_23.Frame_sel10_fCab
                     , Frame_sel11_fReverb => x_23.Frame_sel11_fReverb
                     , Frame_sel12_fAddr => x_23.Frame_sel12_fAddr
                     , Frame_sel13_fDryL => x_23.Frame_sel13_fDryL
                     , Frame_sel14_fDryR => x_23.Frame_sel14_fDryR
                     , Frame_sel15_fWetL => x_23.Frame_sel15_fWetL
                     , Frame_sel16_fWetR => x_23.Frame_sel16_fWetR
                     , Frame_sel17_fFbL => x_23.Frame_sel17_fFbL
                     , Frame_sel18_fFbR => x_23.Frame_sel18_fFbR
                     , Frame_sel19_fEqLowL => ampResPrevL + (resize(\c$app_arg_92\,24))
                     , Frame_sel20_fEqLowR => ampResPrevR + (resize(\c$app_arg_90\,24))
                     , Frame_sel21_fEqMidL => x_23.Frame_sel21_fEqMidL
                     , Frame_sel22_fEqMidR => x_23.Frame_sel22_fEqMidR
                     , Frame_sel23_fEqHighL => x_23.Frame_sel23_fEqHighL
                     , Frame_sel24_fEqHighR => x_23.Frame_sel24_fEqHighR
                     , Frame_sel25_fEqHighLpL => ampPresencePrevL + (resize(\c$app_arg_89\,24))
                     , Frame_sel26_fEqHighLpR => ampPresencePrevR + (resize(\c$app_arg_88\,24))
                     , Frame_sel27_fAccL => x_23.Frame_sel27_fAccL
                     , Frame_sel28_fAccR => x_23.Frame_sel28_fAccR
                     , Frame_sel29_fAcc2L => x_23.Frame_sel29_fAcc2L
                     , Frame_sel30_fAcc2R => x_23.Frame_sel30_fAcc2R
                     , Frame_sel31_fAcc3L => x_23.Frame_sel31_fAcc3L
                     , Frame_sel32_fAcc3R => x_23.Frame_sel32_fAcc3R );

  \c$shI_37\ <= (to_signed(3,64));

  capp_arg_88_shiftR : block
    signal sh_37 : natural;
  begin
    sh_37 <=
        -- pragma translate_off
        natural'high when (\c$shI_37\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_37\);
    \c$app_arg_88\ <= shift_right((\c$app_arg_91\ - (resize(ampPresencePrevR,25))),sh_37)
        -- pragma translate_off
        when ((to_signed(3,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$shI_38\ <= (to_signed(3,64));

  capp_arg_89_shiftR : block
    signal sh_38 : natural;
  begin
    sh_38 <=
        -- pragma translate_off
        natural'high when (\c$shI_38\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_38\);
    \c$app_arg_89\ <= shift_right((\c$app_arg_93\ - (resize(ampPresencePrevL,25))),sh_38)
        -- pragma translate_off
        when ((to_signed(3,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$shI_39\ <= (to_signed(8,64));

  capp_arg_90_shiftR : block
    signal sh_39 : natural;
  begin
    sh_39 <=
        -- pragma translate_off
        natural'high when (\c$shI_39\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_39\);
    \c$app_arg_90\ <= shift_right((\c$app_arg_91\ - (resize(ampResPrevR,25))),sh_39)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_91\ <= resize(x_23.Frame_sel16_fWetR,25);

  \c$shI_40\ <= (to_signed(8,64));

  capp_arg_92_shiftR : block
    signal sh_40 : natural;
  begin
    sh_40 <=
        -- pragma translate_off
        natural'high when (\c$shI_40\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_40\);
    \c$app_arg_92\ <= shift_right((\c$app_arg_93\ - (resize(ampResPrevL,25))),sh_40)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_93\ <= resize(x_23.Frame_sel15_fWetL,25);

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
                                    x_22.Frame_sel26_fEqHighLpR when others;

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
                                    x_22.Frame_sel25_fEqHighLpL when others;

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
                               x_22.Frame_sel20_fEqLowR when others;

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
                               x_22.Frame_sel19_fEqLowL when others;

  x_22 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ampResPresenceFilterPipe(970 downto 0)));

  x_23 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_8(970 downto 0)));

  -- register begin
  ds1_8_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_8 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_8 <= result_62;
    end if;
  end process;
  -- register end

  with (ds1_9(971 downto 971)) select
    result_62 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(result_63.Frame_sel0_fL)
                  & std_logic_vector(result_63.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(result_63.Frame_sel2_fLast)
                  & result_63.Frame_sel3_fGate
                  & result_63.Frame_sel4_fOd
                  & result_63.Frame_sel5_fDist
                  & result_63.Frame_sel6_fEq
                  & result_63.Frame_sel7_fRat
                  & result_63.Frame_sel8_fAmp
                  & result_63.Frame_sel9_fAmpTone
                  & result_63.Frame_sel10_fCab
                  & result_63.Frame_sel11_fReverb
                  & std_logic_vector(result_63.Frame_sel12_fAddr)
                  & std_logic_vector(result_63.Frame_sel13_fDryL)
                  & std_logic_vector(result_63.Frame_sel14_fDryR)
                  & std_logic_vector(result_63.Frame_sel15_fWetL)
                  & std_logic_vector(result_63.Frame_sel16_fWetR)
                  & std_logic_vector(result_63.Frame_sel17_fFbL)
                  & std_logic_vector(result_63.Frame_sel18_fFbR)
                  & std_logic_vector(result_63.Frame_sel19_fEqLowL)
                  & std_logic_vector(result_63.Frame_sel20_fEqLowR)
                  & std_logic_vector(result_63.Frame_sel21_fEqMidL)
                  & std_logic_vector(result_63.Frame_sel22_fEqMidR)
                  & std_logic_vector(result_63.Frame_sel23_fEqHighL)
                  & std_logic_vector(result_63.Frame_sel24_fEqHighR)
                  & std_logic_vector(result_63.Frame_sel25_fEqHighLpL)
                  & std_logic_vector(result_63.Frame_sel26_fEqHighLpR)
                  & std_logic_vector(result_63.Frame_sel27_fAccL)
                  & std_logic_vector(result_63.Frame_sel28_fAccR)
                  & std_logic_vector(result_63.Frame_sel29_fAcc2L)
                  & std_logic_vector(result_63.Frame_sel30_fAcc2R)
                  & std_logic_vector(result_63.Frame_sel31_fAcc3L)
                  & std_logic_vector(result_63.Frame_sel32_fAcc3R)))) when others;

  \c$bv_13\ <= (x_24.Frame_sel3_fGate);

  \on_9\ <= (\c$bv_13\(6 downto 6)) = std_logic_vector'("1");

  result_63 <= ( Frame_sel0_fL => x_24.Frame_sel0_fL
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
               , Frame_sel15_fWetL => \c$app_arg_98\
               , Frame_sel16_fWetR => \c$app_arg_94\
               , Frame_sel17_fFbL => x_24.Frame_sel17_fFbL
               , Frame_sel18_fFbR => x_24.Frame_sel18_fFbR
               , Frame_sel19_fEqLowL => x_24.Frame_sel19_fEqLowL
               , Frame_sel20_fEqLowR => x_24.Frame_sel20_fEqLowR
               , Frame_sel21_fEqMidL => x_24.Frame_sel21_fEqMidL
               , Frame_sel22_fEqMidR => x_24.Frame_sel22_fEqMidR
               , Frame_sel23_fEqHighL => x_24.Frame_sel23_fEqHighL
               , Frame_sel24_fEqHighR => x_24.Frame_sel24_fEqHighR
               , Frame_sel25_fEqHighLpL => x_24.Frame_sel25_fEqHighLpL
               , Frame_sel26_fEqHighLpR => x_24.Frame_sel26_fEqHighLpR
               , Frame_sel27_fAccL => x_24.Frame_sel27_fAccL
               , Frame_sel28_fAccR => x_24.Frame_sel28_fAccR
               , Frame_sel29_fAcc2L => x_24.Frame_sel29_fAcc2L
               , Frame_sel30_fAcc2R => x_24.Frame_sel30_fAcc2R
               , Frame_sel31_fAcc3L => x_24.Frame_sel31_fAcc3L
               , Frame_sel32_fAcc3R => x_24.Frame_sel32_fAcc3R );

  \c$app_arg_94\ <= result_64 when \on_9\ else
                    x_24.Frame_sel1_fR;

  result_selection_res_36 <= x_24.Frame_sel16_fWetR > to_signed(4194304,24);

  result_64 <= resize((to_signed(4194304,25) + \c$app_arg_95\),24) when result_selection_res_36 else
               \c$case_alt_38\;

  \c$case_alt_selection_res_33\ <= x_24.Frame_sel16_fWetR < to_signed(-4194304,24);

  \c$case_alt_38\ <= resize((to_signed(-4194304,25) + \c$app_arg_96\),24) when \c$case_alt_selection_res_33\ else
                     x_24.Frame_sel16_fWetR;

  \c$shI_41\ <= (to_signed(2,64));

  capp_arg_95_shiftR : block
    signal sh_41 : natural;
  begin
    sh_41 <=
        -- pragma translate_off
        natural'high when (\c$shI_41\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_41\);
    \c$app_arg_95\ <= shift_right((\c$app_arg_97\ - to_signed(4194304,25)),sh_41)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$shI_42\ <= (to_signed(2,64));

  capp_arg_96_shiftR : block
    signal sh_42 : natural;
  begin
    sh_42 <=
        -- pragma translate_off
        natural'high when (\c$shI_42\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_42\);
    \c$app_arg_96\ <= shift_right((\c$app_arg_97\ + to_signed(4194304,25)),sh_42)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_97\ <= resize(x_24.Frame_sel16_fWetR,25);

  \c$app_arg_98\ <= result_65 when \on_9\ else
                    x_24.Frame_sel0_fL;

  result_selection_res_37 <= x_24.Frame_sel15_fWetL > to_signed(4194304,24);

  result_65 <= resize((to_signed(4194304,25) + \c$app_arg_99\),24) when result_selection_res_37 else
               \c$case_alt_39\;

  \c$case_alt_selection_res_34\ <= x_24.Frame_sel15_fWetL < to_signed(-4194304,24);

  \c$case_alt_39\ <= resize((to_signed(-4194304,25) + \c$app_arg_100\),24) when \c$case_alt_selection_res_34\ else
                     x_24.Frame_sel15_fWetL;

  \c$shI_43\ <= (to_signed(2,64));

  capp_arg_99_shiftR : block
    signal sh_43 : natural;
  begin
    sh_43 <=
        -- pragma translate_off
        natural'high when (\c$shI_43\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_43\);
    \c$app_arg_99\ <= shift_right((\c$app_arg_101\ - to_signed(4194304,25)),sh_43)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$shI_44\ <= (to_signed(2,64));

  capp_arg_100_shiftR : block
    signal sh_44 : natural;
  begin
    sh_44 <=
        -- pragma translate_off
        natural'high when (\c$shI_44\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_44\);
    \c$app_arg_100\ <= shift_right((\c$app_arg_101\ + to_signed(4194304,25)),sh_44)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_101\ <= resize(x_24.Frame_sel15_fWetL,25);

  x_24 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_9(970 downto 0)));

  -- register begin
  ds1_9_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_9 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_9 <= result_66;
    end if;
  end process;
  -- register end

  with (ds1_10(971 downto 971)) select
    result_66 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(result_69.Frame_sel0_fL)
                  & std_logic_vector(result_69.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(result_69.Frame_sel2_fLast)
                  & result_69.Frame_sel3_fGate
                  & result_69.Frame_sel4_fOd
                  & result_69.Frame_sel5_fDist
                  & result_69.Frame_sel6_fEq
                  & result_69.Frame_sel7_fRat
                  & result_69.Frame_sel8_fAmp
                  & result_69.Frame_sel9_fAmpTone
                  & result_69.Frame_sel10_fCab
                  & result_69.Frame_sel11_fReverb
                  & std_logic_vector(result_69.Frame_sel12_fAddr)
                  & std_logic_vector(result_69.Frame_sel13_fDryL)
                  & std_logic_vector(result_69.Frame_sel14_fDryR)
                  & std_logic_vector(result_69.Frame_sel15_fWetL)
                  & std_logic_vector(result_69.Frame_sel16_fWetR)
                  & std_logic_vector(result_69.Frame_sel17_fFbL)
                  & std_logic_vector(result_69.Frame_sel18_fFbR)
                  & std_logic_vector(result_69.Frame_sel19_fEqLowL)
                  & std_logic_vector(result_69.Frame_sel20_fEqLowR)
                  & std_logic_vector(result_69.Frame_sel21_fEqMidL)
                  & std_logic_vector(result_69.Frame_sel22_fEqMidR)
                  & std_logic_vector(result_69.Frame_sel23_fEqHighL)
                  & std_logic_vector(result_69.Frame_sel24_fEqHighR)
                  & std_logic_vector(result_69.Frame_sel25_fEqHighLpL)
                  & std_logic_vector(result_69.Frame_sel26_fEqHighLpR)
                  & std_logic_vector(result_69.Frame_sel27_fAccL)
                  & std_logic_vector(result_69.Frame_sel28_fAccR)
                  & std_logic_vector(result_69.Frame_sel29_fAcc2L)
                  & std_logic_vector(result_69.Frame_sel30_fAcc2R)
                  & std_logic_vector(result_69.Frame_sel31_fAcc3L)
                  & std_logic_vector(result_69.Frame_sel32_fAcc3R)))) when others;

  \c$shI_45\ <= (to_signed(7,64));

  capp_arg_102_shiftR : block
    signal sh_45 : natural;
  begin
    sh_45 <=
        -- pragma translate_off
        natural'high when (\c$shI_45\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_45\);
    \c$app_arg_102\ <= shift_right(((x_25.Frame_sel27_fAccL + x_25.Frame_sel29_fAcc2L) + x_25.Frame_sel31_fAcc3L),sh_45)
        -- pragma translate_off
        when ((to_signed(7,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_35\ <= \c$app_arg_102\ < to_signed(-8388608,48);

  \c$case_alt_40\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_35\ else
                     resize(\c$app_arg_102\,24);

  result_selection_res_38 <= \c$app_arg_102\ > to_signed(8388607,48);

  result_67 <= to_signed(8388607,24) when result_selection_res_38 else
               \c$case_alt_40\;

  \c$app_arg_103\ <= result_67 when \on_10\ else
                     x_25.Frame_sel0_fL;

  \c$shI_46\ <= (to_signed(7,64));

  capp_arg_104_shiftR : block
    signal sh_46 : natural;
  begin
    sh_46 <=
        -- pragma translate_off
        natural'high when (\c$shI_46\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_46\);
    \c$app_arg_104\ <= shift_right(((x_25.Frame_sel28_fAccR + x_25.Frame_sel30_fAcc2R) + x_25.Frame_sel32_fAcc3R),sh_46)
        -- pragma translate_off
        when ((to_signed(7,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_36\ <= \c$app_arg_104\ < to_signed(-8388608,48);

  \c$case_alt_41\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_36\ else
                     resize(\c$app_arg_104\,24);

  result_selection_res_39 <= \c$app_arg_104\ > to_signed(8388607,48);

  result_68 <= to_signed(8388607,24) when result_selection_res_39 else
               \c$case_alt_41\;

  \c$app_arg_105\ <= result_68 when \on_10\ else
                     x_25.Frame_sel1_fR;

  result_69 <= ( Frame_sel0_fL => x_25.Frame_sel0_fL
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
               , Frame_sel15_fWetL => \c$app_arg_103\
               , Frame_sel16_fWetR => \c$app_arg_105\
               , Frame_sel17_fFbL => x_25.Frame_sel17_fFbL
               , Frame_sel18_fFbR => x_25.Frame_sel18_fFbR
               , Frame_sel19_fEqLowL => x_25.Frame_sel19_fEqLowL
               , Frame_sel20_fEqLowR => x_25.Frame_sel20_fEqLowR
               , Frame_sel21_fEqMidL => x_25.Frame_sel21_fEqMidL
               , Frame_sel22_fEqMidR => x_25.Frame_sel22_fEqMidR
               , Frame_sel23_fEqHighL => x_25.Frame_sel23_fEqHighL
               , Frame_sel24_fEqHighR => x_25.Frame_sel24_fEqHighR
               , Frame_sel25_fEqHighLpL => x_25.Frame_sel25_fEqHighLpL
               , Frame_sel26_fEqHighLpR => x_25.Frame_sel26_fEqHighLpR
               , Frame_sel27_fAccL => x_25.Frame_sel27_fAccL
               , Frame_sel28_fAccR => x_25.Frame_sel28_fAccR
               , Frame_sel29_fAcc2L => x_25.Frame_sel29_fAcc2L
               , Frame_sel30_fAcc2R => x_25.Frame_sel30_fAcc2R
               , Frame_sel31_fAcc3L => x_25.Frame_sel31_fAcc3L
               , Frame_sel32_fAcc3R => x_25.Frame_sel32_fAcc3R );

  \c$bv_14\ <= (x_25.Frame_sel3_fGate);

  \on_10\ <= (\c$bv_14\(6 downto 6)) = std_logic_vector'("1");

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

  result_71 <= ( Frame_sel0_fL => x_29.Frame_sel0_fL
               , Frame_sel1_fR => x_29.Frame_sel1_fR
               , Frame_sel2_fLast => x_29.Frame_sel2_fLast
               , Frame_sel3_fGate => x_29.Frame_sel3_fGate
               , Frame_sel4_fOd => x_29.Frame_sel4_fOd
               , Frame_sel5_fDist => x_29.Frame_sel5_fDist
               , Frame_sel6_fEq => x_29.Frame_sel6_fEq
               , Frame_sel7_fRat => x_29.Frame_sel7_fRat
               , Frame_sel8_fAmp => x_29.Frame_sel8_fAmp
               , Frame_sel9_fAmpTone => x_29.Frame_sel9_fAmpTone
               , Frame_sel10_fCab => x_29.Frame_sel10_fCab
               , Frame_sel11_fReverb => x_29.Frame_sel11_fReverb
               , Frame_sel12_fAddr => x_29.Frame_sel12_fAddr
               , Frame_sel13_fDryL => x_29.Frame_sel13_fDryL
               , Frame_sel14_fDryR => x_29.Frame_sel14_fDryR
               , Frame_sel15_fWetL => x_29.Frame_sel15_fWetL
               , Frame_sel16_fWetR => x_29.Frame_sel16_fWetR
               , Frame_sel17_fFbL => x_29.Frame_sel17_fFbL
               , Frame_sel18_fFbR => x_29.Frame_sel18_fFbR
               , Frame_sel19_fEqLowL => x_29.Frame_sel19_fEqLowL
               , Frame_sel20_fEqLowR => x_29.Frame_sel20_fEqLowR
               , Frame_sel21_fEqMidL => x_29.Frame_sel21_fEqMidL
               , Frame_sel22_fEqMidR => x_29.Frame_sel22_fEqMidR
               , Frame_sel23_fEqHighL => x_29.Frame_sel23_fEqHighL
               , Frame_sel24_fEqHighR => x_29.Frame_sel24_fEqHighR
               , Frame_sel25_fEqHighLpL => x_29.Frame_sel25_fEqHighLpL
               , Frame_sel26_fEqHighLpR => x_29.Frame_sel26_fEqHighLpR
               , Frame_sel27_fAccL => \c$app_arg_113\
               , Frame_sel28_fAccR => \c$app_arg_112\
               , Frame_sel29_fAcc2L => \c$app_arg_110\
               , Frame_sel30_fAcc2R => \c$app_arg_109\
               , Frame_sel31_fAcc3L => \c$app_arg_107\
               , Frame_sel32_fAcc3R => \c$app_arg_106\ );

  \c$app_arg_106\ <= resize((resize(x_29.Frame_sel24_fEqHighR,48)) * \c$app_arg_108\, 48) when \on_11\ else
                     to_signed(0,48);

  \c$app_arg_107\ <= resize((resize(x_29.Frame_sel23_fEqHighL,48)) * \c$app_arg_108\, 48) when \on_11\ else
                     to_signed(0,48);

  \c$app_arg_108\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector((to_unsigned(64,8) + \c$gain_app_arg_0\))))))))),48);

  \c$shI_47\ <= (to_signed(1,64));

  cgain_app_arg_0_shiftL : block
    signal sh_47 : natural;
  begin
    sh_47 <=
        -- pragma translate_off
        natural'high when (\c$shI_47\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_47\);
    \c$gain_app_arg_0\ <= shift_right(x_26,sh_47)
        -- pragma translate_off
        when ((to_signed(1,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  x_26 <= unsigned((\c$x_app_arg_2\(23 downto 16)));

  \c$app_arg_109\ <= resize((resize(x_29.Frame_sel22_fEqMidR,48)) * \c$app_arg_111\, 48) when \on_11\ else
                     to_signed(0,48);

  \c$app_arg_110\ <= resize((resize(x_29.Frame_sel21_fEqMidL,48)) * \c$app_arg_111\, 48) when \on_11\ else
                     to_signed(0,48);

  \c$app_arg_111\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector((to_unsigned(64,8) + \c$gain_app_arg_1\))))))))),48);

  \c$shI_48\ <= (to_signed(1,64));

  cgain_app_arg_1_shiftL : block
    signal sh_48 : natural;
  begin
    sh_48 <=
        -- pragma translate_off
        natural'high when (\c$shI_48\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_48\);
    \c$gain_app_arg_1\ <= shift_right(x_27,sh_48)
        -- pragma translate_off
        when ((to_signed(1,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  x_27 <= unsigned((\c$x_app_arg_2\(15 downto 8)));

  \c$app_arg_112\ <= resize((resize(x_29.Frame_sel20_fEqLowR,48)) * \c$app_arg_114\, 48) when \on_11\ else
                     to_signed(0,48);

  \c$app_arg_113\ <= resize((resize(x_29.Frame_sel19_fEqLowL,48)) * \c$app_arg_114\, 48) when \on_11\ else
                     to_signed(0,48);

  \c$bv_15\ <= (x_29.Frame_sel3_fGate);

  \on_11\ <= (\c$bv_15\(6 downto 6)) = std_logic_vector'("1");

  \c$app_arg_114\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector((to_unsigned(64,8) + \c$gain_app_arg_2\))))))))),48);

  \c$shI_49\ <= (to_signed(1,64));

  cgain_app_arg_2_shiftL : block
    signal sh_49 : natural;
  begin
    sh_49 <=
        -- pragma translate_off
        natural'high when (\c$shI_49\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_49\);
    \c$gain_app_arg_2\ <= shift_right(x_28,sh_49)
        -- pragma translate_off
        when ((to_signed(1,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  x_28 <= unsigned((\c$x_app_arg_2\(7 downto 0)));

  \c$x_app_arg_2\ <= x_29.Frame_sel9_fAmpTone;

  x_29 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_11(970 downto 0)));

  -- register begin
  ds1_11_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_11 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_11 <= result_72;
    end if;
  end process;
  -- register end

  with (ampToneFilterPipe(971 downto 971)) select
    result_72 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(\c$case_alt_42\.Frame_sel0_fL)
                  & std_logic_vector(\c$case_alt_42\.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(\c$case_alt_42\.Frame_sel2_fLast)
                  & \c$case_alt_42\.Frame_sel3_fGate
                  & \c$case_alt_42\.Frame_sel4_fOd
                  & \c$case_alt_42\.Frame_sel5_fDist
                  & \c$case_alt_42\.Frame_sel6_fEq
                  & \c$case_alt_42\.Frame_sel7_fRat
                  & \c$case_alt_42\.Frame_sel8_fAmp
                  & \c$case_alt_42\.Frame_sel9_fAmpTone
                  & \c$case_alt_42\.Frame_sel10_fCab
                  & \c$case_alt_42\.Frame_sel11_fReverb
                  & std_logic_vector(\c$case_alt_42\.Frame_sel12_fAddr)
                  & std_logic_vector(\c$case_alt_42\.Frame_sel13_fDryL)
                  & std_logic_vector(\c$case_alt_42\.Frame_sel14_fDryR)
                  & std_logic_vector(\c$case_alt_42\.Frame_sel15_fWetL)
                  & std_logic_vector(\c$case_alt_42\.Frame_sel16_fWetR)
                  & std_logic_vector(\c$case_alt_42\.Frame_sel17_fFbL)
                  & std_logic_vector(\c$case_alt_42\.Frame_sel18_fFbR)
                  & std_logic_vector(\c$case_alt_42\.Frame_sel19_fEqLowL)
                  & std_logic_vector(\c$case_alt_42\.Frame_sel20_fEqLowR)
                  & std_logic_vector(\c$case_alt_42\.Frame_sel21_fEqMidL)
                  & std_logic_vector(\c$case_alt_42\.Frame_sel22_fEqMidR)
                  & std_logic_vector(\c$case_alt_42\.Frame_sel23_fEqHighL)
                  & std_logic_vector(\c$case_alt_42\.Frame_sel24_fEqHighR)
                  & std_logic_vector(\c$case_alt_42\.Frame_sel25_fEqHighLpL)
                  & std_logic_vector(\c$case_alt_42\.Frame_sel26_fEqHighLpR)
                  & std_logic_vector(\c$case_alt_42\.Frame_sel27_fAccL)
                  & std_logic_vector(\c$case_alt_42\.Frame_sel28_fAccR)
                  & std_logic_vector(\c$case_alt_42\.Frame_sel29_fAcc2L)
                  & std_logic_vector(\c$case_alt_42\.Frame_sel30_fAcc2R)
                  & std_logic_vector(\c$case_alt_42\.Frame_sel31_fAcc3L)
                  & std_logic_vector(\c$case_alt_42\.Frame_sel32_fAcc3R)))) when others;

  \c$case_alt_42\ <= ( Frame_sel0_fL => x_34.Frame_sel0_fL
                     , Frame_sel1_fR => x_34.Frame_sel1_fR
                     , Frame_sel2_fLast => x_34.Frame_sel2_fLast
                     , Frame_sel3_fGate => x_34.Frame_sel3_fGate
                     , Frame_sel4_fOd => x_34.Frame_sel4_fOd
                     , Frame_sel5_fDist => x_34.Frame_sel5_fDist
                     , Frame_sel6_fEq => x_34.Frame_sel6_fEq
                     , Frame_sel7_fRat => x_34.Frame_sel7_fRat
                     , Frame_sel8_fAmp => x_34.Frame_sel8_fAmp
                     , Frame_sel9_fAmpTone => x_34.Frame_sel9_fAmpTone
                     , Frame_sel10_fCab => x_34.Frame_sel10_fCab
                     , Frame_sel11_fReverb => x_34.Frame_sel11_fReverb
                     , Frame_sel12_fAddr => x_34.Frame_sel12_fAddr
                     , Frame_sel13_fDryL => x_34.Frame_sel13_fDryL
                     , Frame_sel14_fDryR => x_34.Frame_sel14_fDryR
                     , Frame_sel15_fWetL => x_34.Frame_sel15_fWetL
                     , Frame_sel16_fWetR => x_34.Frame_sel16_fWetR
                     , Frame_sel17_fFbL => x_34.Frame_sel17_fFbL
                     , Frame_sel18_fFbR => x_34.Frame_sel18_fFbR
                     , Frame_sel19_fEqLowL => x_34.Frame_sel19_fEqLowL
                     , Frame_sel20_fEqLowR => x_34.Frame_sel20_fEqLowR
                     , Frame_sel21_fEqMidL => result_76
                     , Frame_sel22_fEqMidR => result_75
                     , Frame_sel23_fEqHighL => result_74
                     , Frame_sel24_fEqHighR => result_73
                     , Frame_sel25_fEqHighLpL => x_34.Frame_sel25_fEqHighLpL
                     , Frame_sel26_fEqHighLpR => x_34.Frame_sel26_fEqHighLpR
                     , Frame_sel27_fAccL => x_34.Frame_sel27_fAccL
                     , Frame_sel28_fAccR => x_34.Frame_sel28_fAccR
                     , Frame_sel29_fAcc2L => x_34.Frame_sel29_fAcc2L
                     , Frame_sel30_fAcc2R => x_34.Frame_sel30_fAcc2R
                     , Frame_sel31_fAcc3L => x_34.Frame_sel31_fAcc3L
                     , Frame_sel32_fAcc3R => x_34.Frame_sel32_fAcc3R );

  x_30 <= (resize(x_34.Frame_sel16_fWetR,48)) - \c$app_arg_115\;

  \c$case_alt_selection_res_37\ <= x_30 < to_signed(-8388608,48);

  \c$case_alt_43\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_37\ else
                     resize(x_30,24);

  result_selection_res_40 <= x_30 > to_signed(8388607,48);

  result_73 <= to_signed(8388607,24) when result_selection_res_40 else
               \c$case_alt_43\;

  x_31 <= (resize(x_34.Frame_sel15_fWetL,48)) - \c$app_arg_116\;

  \c$case_alt_selection_res_38\ <= x_31 < to_signed(-8388608,48);

  \c$case_alt_44\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_38\ else
                     resize(x_31,24);

  result_selection_res_41 <= x_31 > to_signed(8388607,48);

  result_74 <= to_signed(8388607,24) when result_selection_res_41 else
               \c$case_alt_44\;

  x_32 <= \c$app_arg_115\ - (resize(x_34.Frame_sel20_fEqLowR,48));

  \c$case_alt_selection_res_39\ <= x_32 < to_signed(-8388608,48);

  \c$case_alt_45\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_39\ else
                     resize(x_32,24);

  result_selection_res_42 <= x_32 > to_signed(8388607,48);

  result_75 <= to_signed(8388607,24) when result_selection_res_42 else
               \c$case_alt_45\;

  \c$app_arg_115\ <= resize(x_34.Frame_sel26_fEqHighLpR,48);

  x_33 <= \c$app_arg_116\ - (resize(x_34.Frame_sel19_fEqLowL,48));

  \c$case_alt_selection_res_40\ <= x_33 < to_signed(-8388608,48);

  \c$case_alt_46\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_40\ else
                     resize(x_33,24);

  result_selection_res_43 <= x_33 > to_signed(8388607,48);

  result_76 <= to_signed(8388607,24) when result_selection_res_43 else
               \c$case_alt_46\;

  \c$app_arg_116\ <= resize(x_34.Frame_sel25_fEqHighLpL,48);

  -- register begin
  ampToneFilterPipe_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ampToneFilterPipe <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ampToneFilterPipe <= result_77;
    end if;
  end process;
  -- register end

  with (ampPreLowpassPipe(971 downto 971)) select
    result_77 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(\c$case_alt_47\.Frame_sel0_fL)
                  & std_logic_vector(\c$case_alt_47\.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(\c$case_alt_47\.Frame_sel2_fLast)
                  & \c$case_alt_47\.Frame_sel3_fGate
                  & \c$case_alt_47\.Frame_sel4_fOd
                  & \c$case_alt_47\.Frame_sel5_fDist
                  & \c$case_alt_47\.Frame_sel6_fEq
                  & \c$case_alt_47\.Frame_sel7_fRat
                  & \c$case_alt_47\.Frame_sel8_fAmp
                  & \c$case_alt_47\.Frame_sel9_fAmpTone
                  & \c$case_alt_47\.Frame_sel10_fCab
                  & \c$case_alt_47\.Frame_sel11_fReverb
                  & std_logic_vector(\c$case_alt_47\.Frame_sel12_fAddr)
                  & std_logic_vector(\c$case_alt_47\.Frame_sel13_fDryL)
                  & std_logic_vector(\c$case_alt_47\.Frame_sel14_fDryR)
                  & std_logic_vector(\c$case_alt_47\.Frame_sel15_fWetL)
                  & std_logic_vector(\c$case_alt_47\.Frame_sel16_fWetR)
                  & std_logic_vector(\c$case_alt_47\.Frame_sel17_fFbL)
                  & std_logic_vector(\c$case_alt_47\.Frame_sel18_fFbR)
                  & std_logic_vector(\c$case_alt_47\.Frame_sel19_fEqLowL)
                  & std_logic_vector(\c$case_alt_47\.Frame_sel20_fEqLowR)
                  & std_logic_vector(\c$case_alt_47\.Frame_sel21_fEqMidL)
                  & std_logic_vector(\c$case_alt_47\.Frame_sel22_fEqMidR)
                  & std_logic_vector(\c$case_alt_47\.Frame_sel23_fEqHighL)
                  & std_logic_vector(\c$case_alt_47\.Frame_sel24_fEqHighR)
                  & std_logic_vector(\c$case_alt_47\.Frame_sel25_fEqHighLpL)
                  & std_logic_vector(\c$case_alt_47\.Frame_sel26_fEqHighLpR)
                  & std_logic_vector(\c$case_alt_47\.Frame_sel27_fAccL)
                  & std_logic_vector(\c$case_alt_47\.Frame_sel28_fAccR)
                  & std_logic_vector(\c$case_alt_47\.Frame_sel29_fAcc2L)
                  & std_logic_vector(\c$case_alt_47\.Frame_sel30_fAcc2R)
                  & std_logic_vector(\c$case_alt_47\.Frame_sel31_fAcc3L)
                  & std_logic_vector(\c$case_alt_47\.Frame_sel32_fAcc3R)))) when others;

  \c$case_alt_47\ <= ( Frame_sel0_fL => x_35.Frame_sel0_fL
                     , Frame_sel1_fR => x_35.Frame_sel1_fR
                     , Frame_sel2_fLast => x_35.Frame_sel2_fLast
                     , Frame_sel3_fGate => x_35.Frame_sel3_fGate
                     , Frame_sel4_fOd => x_35.Frame_sel4_fOd
                     , Frame_sel5_fDist => x_35.Frame_sel5_fDist
                     , Frame_sel6_fEq => x_35.Frame_sel6_fEq
                     , Frame_sel7_fRat => x_35.Frame_sel7_fRat
                     , Frame_sel8_fAmp => x_35.Frame_sel8_fAmp
                     , Frame_sel9_fAmpTone => x_35.Frame_sel9_fAmpTone
                     , Frame_sel10_fCab => x_35.Frame_sel10_fCab
                     , Frame_sel11_fReverb => x_35.Frame_sel11_fReverb
                     , Frame_sel12_fAddr => x_35.Frame_sel12_fAddr
                     , Frame_sel13_fDryL => x_35.Frame_sel13_fDryL
                     , Frame_sel14_fDryR => x_35.Frame_sel14_fDryR
                     , Frame_sel15_fWetL => x_35.Frame_sel15_fWetL
                     , Frame_sel16_fWetR => x_35.Frame_sel16_fWetR
                     , Frame_sel17_fFbL => x_35.Frame_sel17_fFbL
                     , Frame_sel18_fFbR => x_35.Frame_sel18_fFbR
                     , Frame_sel19_fEqLowL => ampToneLowPrevL + (resize(\c$app_arg_121\,24))
                     , Frame_sel20_fEqLowR => ampToneLowPrevR + (resize(\c$app_arg_119\,24))
                     , Frame_sel21_fEqMidL => x_35.Frame_sel21_fEqMidL
                     , Frame_sel22_fEqMidR => x_35.Frame_sel22_fEqMidR
                     , Frame_sel23_fEqHighL => x_35.Frame_sel23_fEqHighL
                     , Frame_sel24_fEqHighR => x_35.Frame_sel24_fEqHighR
                     , Frame_sel25_fEqHighLpL => ampToneHighPrevL + (resize(\c$app_arg_118\,24))
                     , Frame_sel26_fEqHighLpR => ampToneHighPrevR + (resize(\c$app_arg_117\,24))
                     , Frame_sel27_fAccL => x_35.Frame_sel27_fAccL
                     , Frame_sel28_fAccR => x_35.Frame_sel28_fAccR
                     , Frame_sel29_fAcc2L => x_35.Frame_sel29_fAcc2L
                     , Frame_sel30_fAcc2R => x_35.Frame_sel30_fAcc2R
                     , Frame_sel31_fAcc3L => x_35.Frame_sel31_fAcc3L
                     , Frame_sel32_fAcc3R => x_35.Frame_sel32_fAcc3R );

  \c$shI_50\ <= (to_signed(2,64));

  capp_arg_117_shiftR : block
    signal sh_50 : natural;
  begin
    sh_50 <=
        -- pragma translate_off
        natural'high when (\c$shI_50\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_50\);
    \c$app_arg_117\ <= shift_right((\c$app_arg_120\ - (resize(ampToneHighPrevR,25))),sh_50)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$shI_51\ <= (to_signed(2,64));

  capp_arg_118_shiftR : block
    signal sh_51 : natural;
  begin
    sh_51 <=
        -- pragma translate_off
        natural'high when (\c$shI_51\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_51\);
    \c$app_arg_118\ <= shift_right((\c$app_arg_122\ - (resize(ampToneHighPrevL,25))),sh_51)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$shI_52\ <= (to_signed(5,64));

  capp_arg_119_shiftR : block
    signal sh_52 : natural;
  begin
    sh_52 <=
        -- pragma translate_off
        natural'high when (\c$shI_52\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_52\);
    \c$app_arg_119\ <= shift_right((\c$app_arg_120\ - (resize(ampToneLowPrevR,25))),sh_52)
        -- pragma translate_off
        when ((to_signed(5,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_120\ <= resize(x_35.Frame_sel16_fWetR,25);

  \c$shI_53\ <= (to_signed(5,64));

  capp_arg_121_shiftR : block
    signal sh_53 : natural;
  begin
    sh_53 <=
        -- pragma translate_off
        natural'high when (\c$shI_53\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_53\);
    \c$app_arg_121\ <= shift_right((\c$app_arg_122\ - (resize(ampToneLowPrevL,25))),sh_53)
        -- pragma translate_off
        when ((to_signed(5,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_122\ <= resize(x_35.Frame_sel15_fWetL,25);

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
                                    x_34.Frame_sel26_fEqHighLpR when others;

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
                                    x_34.Frame_sel25_fEqHighLpL when others;

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
                                   x_34.Frame_sel20_fEqLowR when others;

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
                                   x_34.Frame_sel19_fEqLowL when others;

  x_34 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ampToneFilterPipe(970 downto 0)));

  -- register begin
  ampPreLowpassPipe_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ampPreLowpassPipe <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ampPreLowpassPipe <= result_78;
    end if;
  end process;
  -- register end

  with (ds1_12(971 downto 971)) select
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

  alpha <= to_unsigned(160,8) + \c$alpha_app_arg\;

  \c$bv_16\ <= (x_36.Frame_sel3_fGate);

  \on_12\ <= (\c$bv_16\(6 downto 6)) = std_logic_vector'("1");

  result_79 <= ( Frame_sel0_fL => x_36.Frame_sel0_fL
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
               , Frame_sel15_fWetL => \c$app_arg_125\
               , Frame_sel16_fWetR => \c$app_arg_123\
               , Frame_sel17_fFbL => x_36.Frame_sel17_fFbL
               , Frame_sel18_fFbR => x_36.Frame_sel18_fFbR
               , Frame_sel19_fEqLowL => x_36.Frame_sel19_fEqLowL
               , Frame_sel20_fEqLowR => x_36.Frame_sel20_fEqLowR
               , Frame_sel21_fEqMidL => x_36.Frame_sel21_fEqMidL
               , Frame_sel22_fEqMidR => x_36.Frame_sel22_fEqMidR
               , Frame_sel23_fEqHighL => x_36.Frame_sel23_fEqHighL
               , Frame_sel24_fEqHighR => x_36.Frame_sel24_fEqHighR
               , Frame_sel25_fEqHighLpL => x_36.Frame_sel25_fEqHighLpL
               , Frame_sel26_fEqHighLpR => x_36.Frame_sel26_fEqHighLpR
               , Frame_sel27_fAccL => x_36.Frame_sel27_fAccL
               , Frame_sel28_fAccR => x_36.Frame_sel28_fAccR
               , Frame_sel29_fAcc2L => x_36.Frame_sel29_fAcc2L
               , Frame_sel30_fAcc2R => x_36.Frame_sel30_fAcc2R
               , Frame_sel31_fAcc3L => x_36.Frame_sel31_fAcc3L
               , Frame_sel32_fAcc3R => x_36.Frame_sel32_fAcc3R );

  \c$app_arg_123\ <= result_80 when \on_12\ else
                     x_36.Frame_sel1_fR;

  \c$shI_54\ <= (to_signed(8,64));

  capp_arg_124_shiftR : block
    signal sh_54 : natural;
  begin
    sh_54 <=
        -- pragma translate_off
        natural'high when (\c$shI_54\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_54\);
    \c$app_arg_124\ <= shift_right(((resize((resize(x_36.Frame_sel16_fWetR,48)) * (resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(alpha)))))))),48)), 48)) + (resize((resize(ampPreLpPrevR,48)) * (resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(gain_5)))))))),48)), 48))),sh_54)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  gain_5 <= to_unsigned(255,8) - alpha;

  \c$case_alt_selection_res_41\ <= \c$app_arg_124\ < to_signed(-8388608,48);

  \c$case_alt_48\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_41\ else
                     resize(\c$app_arg_124\,24);

  result_selection_res_44 <= \c$app_arg_124\ > to_signed(8388607,48);

  result_80 <= to_signed(8388607,24) when result_selection_res_44 else
               \c$case_alt_48\;

  \c$app_arg_125\ <= result_81 when \on_12\ else
                     x_36.Frame_sel0_fL;

  \c$shI_55\ <= (to_signed(8,64));

  capp_arg_126_shiftR : block
    signal sh_55 : natural;
  begin
    sh_55 <=
        -- pragma translate_off
        natural'high when (\c$shI_55\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_55\);
    \c$app_arg_126\ <= shift_right(((resize((resize(x_36.Frame_sel15_fWetL,48)) * (resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(alpha)))))))),48)), 48)) + (resize((resize(ampPreLpPrevL,48)) * (resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(gain_6)))))))),48)), 48))),sh_55)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  gain_6 <= to_unsigned(255,8) - alpha;

  \c$case_alt_selection_res_42\ <= \c$app_arg_126\ < to_signed(-8388608,48);

  \c$case_alt_49\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_42\ else
                     resize(\c$app_arg_126\,24);

  result_selection_res_45 <= \c$app_arg_126\ > to_signed(8388607,48);

  result_81 <= to_signed(8388607,24) when result_selection_res_45 else
               \c$case_alt_49\;

  \c$bv_17\ <= (x_36.Frame_sel9_fAmpTone);

  \c$shI_56\ <= (to_signed(2,64));

  calpha_app_arg_shiftL : block
    signal sh_56 : natural;
  begin
    sh_56 <=
        -- pragma translate_off
        natural'high when (\c$shI_56\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_56\);
    \c$alpha_app_arg\ <= shift_right((unsigned((\c$bv_17\(31 downto 24)))),sh_56)
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
                                 x_35.Frame_sel16_fWetR when others;

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
                                 x_35.Frame_sel15_fWetL when others;

  x_35 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ampPreLowpassPipe(970 downto 0)));

  x_36 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_12(970 downto 0)));

  -- register begin
  ds1_12_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_12 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_12 <= result_82;
    end if;
  end process;
  -- register end

  with (ds1_13(971 downto 971)) select
    result_82 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(result_83.Frame_sel0_fL)
                  & std_logic_vector(result_83.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(result_83.Frame_sel2_fLast)
                  & result_83.Frame_sel3_fGate
                  & result_83.Frame_sel4_fOd
                  & result_83.Frame_sel5_fDist
                  & result_83.Frame_sel6_fEq
                  & result_83.Frame_sel7_fRat
                  & result_83.Frame_sel8_fAmp
                  & result_83.Frame_sel9_fAmpTone
                  & result_83.Frame_sel10_fCab
                  & result_83.Frame_sel11_fReverb
                  & std_logic_vector(result_83.Frame_sel12_fAddr)
                  & std_logic_vector(result_83.Frame_sel13_fDryL)
                  & std_logic_vector(result_83.Frame_sel14_fDryR)
                  & std_logic_vector(result_83.Frame_sel15_fWetL)
                  & std_logic_vector(result_83.Frame_sel16_fWetR)
                  & std_logic_vector(result_83.Frame_sel17_fFbL)
                  & std_logic_vector(result_83.Frame_sel18_fFbR)
                  & std_logic_vector(result_83.Frame_sel19_fEqLowL)
                  & std_logic_vector(result_83.Frame_sel20_fEqLowR)
                  & std_logic_vector(result_83.Frame_sel21_fEqMidL)
                  & std_logic_vector(result_83.Frame_sel22_fEqMidR)
                  & std_logic_vector(result_83.Frame_sel23_fEqHighL)
                  & std_logic_vector(result_83.Frame_sel24_fEqHighR)
                  & std_logic_vector(result_83.Frame_sel25_fEqHighLpL)
                  & std_logic_vector(result_83.Frame_sel26_fEqHighLpR)
                  & std_logic_vector(result_83.Frame_sel27_fAccL)
                  & std_logic_vector(result_83.Frame_sel28_fAccR)
                  & std_logic_vector(result_83.Frame_sel29_fAcc2L)
                  & std_logic_vector(result_83.Frame_sel30_fAcc2R)
                  & std_logic_vector(result_83.Frame_sel31_fAcc3L)
                  & std_logic_vector(result_83.Frame_sel32_fAcc3R)))) when others;

  \c$bv_18\ <= (x_37.Frame_sel9_fAmpTone);

  character <= unsigned((\c$bv_18\(31 downto 24)));

  \c$bv_19\ <= (x_37.Frame_sel3_fGate);

  \on_13\ <= (\c$bv_19\(6 downto 6)) = std_logic_vector'("1");

  result_83 <= ( Frame_sel0_fL => x_37.Frame_sel0_fL
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
               , Frame_sel15_fWetL => \c$app_arg_128\
               , Frame_sel16_fWetR => \c$app_arg_127\
               , Frame_sel17_fFbL => x_37.Frame_sel17_fFbL
               , Frame_sel18_fFbR => x_37.Frame_sel18_fFbR
               , Frame_sel19_fEqLowL => x_37.Frame_sel19_fEqLowL
               , Frame_sel20_fEqLowR => x_37.Frame_sel20_fEqLowR
               , Frame_sel21_fEqMidL => x_37.Frame_sel21_fEqMidL
               , Frame_sel22_fEqMidR => x_37.Frame_sel22_fEqMidR
               , Frame_sel23_fEqHighL => x_37.Frame_sel23_fEqHighL
               , Frame_sel24_fEqHighR => x_37.Frame_sel24_fEqHighR
               , Frame_sel25_fEqHighLpL => x_37.Frame_sel25_fEqHighLpL
               , Frame_sel26_fEqHighLpR => x_37.Frame_sel26_fEqHighLpR
               , Frame_sel27_fAccL => x_37.Frame_sel27_fAccL
               , Frame_sel28_fAccR => x_37.Frame_sel28_fAccR
               , Frame_sel29_fAcc2L => x_37.Frame_sel29_fAcc2L
               , Frame_sel30_fAcc2R => x_37.Frame_sel30_fAcc2R
               , Frame_sel31_fAcc3L => x_37.Frame_sel31_fAcc3L
               , Frame_sel32_fAcc3R => x_37.Frame_sel32_fAcc3R );

  \c$app_arg_127\ <= result_84 when \on_13\ else
                     x_37.Frame_sel1_fR;

  result_84 <= result_86 when \c$satWideOut_case_scrut\ else
               result_85;

  result_selection_res_46 <= x_37.Frame_sel16_fWetR < \c$satWideOut_app_arg_4\;

  result_85 <= result_86 when result_selection_res_46 else
               x_37.Frame_sel16_fWetR;

  \c$case_alt_selection_res_43\ <= \c$satWideOut_app_arg\ < to_signed(-8388608,48);

  \c$case_alt_50\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_43\ else
                     resize(\c$satWideOut_app_arg\,24);

  result_selection_res_47 <= \c$satWideOut_app_arg\ > to_signed(8388607,48);

  result_86 <= to_signed(8388607,24) when result_selection_res_47 else
               \c$case_alt_50\;

  \c$satWideOut_app_arg\ <= resize((\c$satWideOut_app_arg_1\ + \c$satWideOut_app_arg_0\),48) when \c$satWideOut_case_scrut\ else
                            resize(((resize(\c$satWideOut_app_arg_4\,25)) + \c$satWideOut_app_arg_2\),48);

  \c$shI_57\ <= (to_signed(2,64));

  csatWideOut_app_arg_0_shiftR : block
    signal sh_57 : natural;
  begin
    sh_57 <=
        -- pragma translate_off
        natural'high when (\c$shI_57\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_57\);
    \c$satWideOut_app_arg_0\ <= shift_right((\c$satWideOut_app_arg_3\ - \c$satWideOut_app_arg_1\),sh_57)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$satWideOut_app_arg_1\ <= resize(positiveKnee,25);

  \c$satWideOut_case_scrut\ <= x_37.Frame_sel16_fWetR > positiveKnee;

  positiveKnee <= resize((to_signed(5200000,25) - (resize(ch * to_signed(8500,25), 25))),24);

  \c$shI_58\ <= (to_signed(3,64));

  csatWideOut_app_arg_2_shiftR : block
    signal sh_58 : natural;
  begin
    sh_58 <=
        -- pragma translate_off
        natural'high when (\c$shI_58\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_58\);
    \c$satWideOut_app_arg_2\ <= shift_right((\c$satWideOut_app_arg_3\ + (resize(negativeKnee,25))),sh_58)
        -- pragma translate_off
        when ((to_signed(3,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$satWideOut_app_arg_3\ <= resize(x_37.Frame_sel16_fWetR,25);

  \c$satWideOut_app_arg_4\ <= -negativeKnee;

  negativeKnee <= resize((to_signed(4700000,25) - (resize(ch * to_signed(7000,25), 25))),24);

  ch <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(character)))))))),25);

  \c$app_arg_128\ <= result_87 when \on_13\ else
                     x_37.Frame_sel0_fL;

  result_87 <= result_89 when \c$satWideOut_case_scrut_0\ else
               result_88;

  result_selection_res_48 <= x_37.Frame_sel15_fWetL < \c$satWideOut_app_arg_10\;

  result_88 <= result_89 when result_selection_res_48 else
               x_37.Frame_sel15_fWetL;

  \c$case_alt_selection_res_44\ <= \c$satWideOut_app_arg_5\ < to_signed(-8388608,48);

  \c$case_alt_51\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_44\ else
                     resize(\c$satWideOut_app_arg_5\,24);

  result_selection_res_49 <= \c$satWideOut_app_arg_5\ > to_signed(8388607,48);

  result_89 <= to_signed(8388607,24) when result_selection_res_49 else
               \c$case_alt_51\;

  \c$satWideOut_app_arg_5\ <= resize((\c$satWideOut_app_arg_7\ + \c$satWideOut_app_arg_6\),48) when \c$satWideOut_case_scrut_0\ else
                              resize(((resize(\c$satWideOut_app_arg_10\,25)) + \c$satWideOut_app_arg_8\),48);

  \c$shI_59\ <= (to_signed(2,64));

  csatWideOut_app_arg_6_shiftR : block
    signal sh_59 : natural;
  begin
    sh_59 <=
        -- pragma translate_off
        natural'high when (\c$shI_59\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_59\);
    \c$satWideOut_app_arg_6\ <= shift_right((\c$satWideOut_app_arg_9\ - \c$satWideOut_app_arg_7\),sh_59)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$satWideOut_app_arg_7\ <= resize(positiveKnee_0,25);

  \c$satWideOut_case_scrut_0\ <= x_37.Frame_sel15_fWetL > positiveKnee_0;

  positiveKnee_0 <= resize((to_signed(5200000,25) - (resize(ch_0 * to_signed(8500,25), 25))),24);

  \c$shI_60\ <= (to_signed(3,64));

  csatWideOut_app_arg_8_shiftR : block
    signal sh_60 : natural;
  begin
    sh_60 <=
        -- pragma translate_off
        natural'high when (\c$shI_60\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_60\);
    \c$satWideOut_app_arg_8\ <= shift_right((\c$satWideOut_app_arg_9\ + (resize(negativeKnee_0,25))),sh_60)
        -- pragma translate_off
        when ((to_signed(3,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$satWideOut_app_arg_9\ <= resize(x_37.Frame_sel15_fWetL,25);

  \c$satWideOut_app_arg_10\ <= -negativeKnee_0;

  negativeKnee_0 <= resize((to_signed(4700000,25) - (resize(ch_0 * to_signed(7000,25), 25))),24);

  ch_0 <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(character)))))))),25);

  x_37 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_13(970 downto 0)));

  -- register begin
  ds1_13_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_13 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_13 <= result_90;
    end if;
  end process;
  -- register end

  with (ds1_14(971 downto 971)) select
    result_90 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                 std_logic_vector'("1" & ((std_logic_vector(result_93.Frame_sel0_fL)
                  & std_logic_vector(result_93.Frame_sel1_fR)
                  & clash_lowpass_fir_types.toSLV(result_93.Frame_sel2_fLast)
                  & result_93.Frame_sel3_fGate
                  & result_93.Frame_sel4_fOd
                  & result_93.Frame_sel5_fDist
                  & result_93.Frame_sel6_fEq
                  & result_93.Frame_sel7_fRat
                  & result_93.Frame_sel8_fAmp
                  & result_93.Frame_sel9_fAmpTone
                  & result_93.Frame_sel10_fCab
                  & result_93.Frame_sel11_fReverb
                  & std_logic_vector(result_93.Frame_sel12_fAddr)
                  & std_logic_vector(result_93.Frame_sel13_fDryL)
                  & std_logic_vector(result_93.Frame_sel14_fDryR)
                  & std_logic_vector(result_93.Frame_sel15_fWetL)
                  & std_logic_vector(result_93.Frame_sel16_fWetR)
                  & std_logic_vector(result_93.Frame_sel17_fFbL)
                  & std_logic_vector(result_93.Frame_sel18_fFbR)
                  & std_logic_vector(result_93.Frame_sel19_fEqLowL)
                  & std_logic_vector(result_93.Frame_sel20_fEqLowR)
                  & std_logic_vector(result_93.Frame_sel21_fEqMidL)
                  & std_logic_vector(result_93.Frame_sel22_fEqMidR)
                  & std_logic_vector(result_93.Frame_sel23_fEqHighL)
                  & std_logic_vector(result_93.Frame_sel24_fEqHighR)
                  & std_logic_vector(result_93.Frame_sel25_fEqHighLpL)
                  & std_logic_vector(result_93.Frame_sel26_fEqHighLpR)
                  & std_logic_vector(result_93.Frame_sel27_fAccL)
                  & std_logic_vector(result_93.Frame_sel28_fAccR)
                  & std_logic_vector(result_93.Frame_sel29_fAcc2L)
                  & std_logic_vector(result_93.Frame_sel30_fAcc2R)
                  & std_logic_vector(result_93.Frame_sel31_fAcc3L)
                  & std_logic_vector(result_93.Frame_sel32_fAcc3R)))) when others;

  \c$shI_61\ <= (to_signed(7,64));

  capp_arg_129_shiftR : block
    signal sh_61 : natural;
  begin
    sh_61 <=
        -- pragma translate_off
        natural'high when (\c$shI_61\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_61\);
    \c$app_arg_129\ <= shift_right(x_38.Frame_sel27_fAccL,sh_61)
        -- pragma translate_off
        when ((to_signed(7,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_45\ <= \c$app_arg_129\ < to_signed(-8388608,48);

  \c$case_alt_52\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_45\ else
                     resize(\c$app_arg_129\,24);

  result_selection_res_50 <= \c$app_arg_129\ > to_signed(8388607,48);

  result_91 <= to_signed(8388607,24) when result_selection_res_50 else
               \c$case_alt_52\;

  \c$app_arg_130\ <= result_91 when \on_14\ else
                     x_38.Frame_sel0_fL;

  \c$shI_62\ <= (to_signed(7,64));

  capp_arg_131_shiftR : block
    signal sh_62 : natural;
  begin
    sh_62 <=
        -- pragma translate_off
        natural'high when (\c$shI_62\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_62\);
    \c$app_arg_131\ <= shift_right(x_38.Frame_sel28_fAccR,sh_62)
        -- pragma translate_off
        when ((to_signed(7,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_46\ <= \c$app_arg_131\ < to_signed(-8388608,48);

  \c$case_alt_53\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_46\ else
                     resize(\c$app_arg_131\,24);

  result_selection_res_51 <= \c$app_arg_131\ > to_signed(8388607,48);

  result_92 <= to_signed(8388607,24) when result_selection_res_51 else
               \c$case_alt_53\;

  \c$app_arg_132\ <= result_92 when \on_14\ else
                     x_38.Frame_sel1_fR;

  result_93 <= ( Frame_sel0_fL => x_38.Frame_sel0_fL
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
               , Frame_sel15_fWetL => \c$app_arg_130\
               , Frame_sel16_fWetR => \c$app_arg_132\
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

  \c$bv_20\ <= (x_38.Frame_sel3_fGate);

  \on_14\ <= (\c$bv_20\(6 downto 6)) = std_logic_vector'("1");

  x_38 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_14(970 downto 0)));

  -- register begin
  ds1_14_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_14 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_14 <= result_94;
    end if;
  end process;
  -- register end

  with (ampHighpassPipe(971 downto 971)) select
    result_94 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
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

  result_95 <= ( Frame_sel0_fL => x_41.Frame_sel0_fL
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
               , Frame_sel15_fWetL => x_41.Frame_sel15_fWetL
               , Frame_sel16_fWetR => x_41.Frame_sel16_fWetR
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
               , Frame_sel27_fAccL => \c$app_arg_134\
               , Frame_sel28_fAccR => \c$app_arg_133\
               , Frame_sel29_fAcc2L => x_41.Frame_sel29_fAcc2L
               , Frame_sel30_fAcc2R => x_41.Frame_sel30_fAcc2R
               , Frame_sel31_fAcc3L => x_41.Frame_sel31_fAcc3L
               , Frame_sel32_fAcc3R => x_41.Frame_sel32_fAcc3R );

  \c$app_arg_133\ <= resize((resize(x_41.Frame_sel16_fWetR,48)) * \c$app_arg_135\, 48) when \on_15\ else
                     to_signed(0,48);

  \c$app_arg_134\ <= resize((resize(x_41.Frame_sel15_fWetL,48)) * \c$app_arg_135\, 48) when \on_15\ else
                     to_signed(0,48);

  \c$bv_21\ <= (x_41.Frame_sel3_fGate);

  \on_15\ <= (\c$bv_21\(6 downto 6)) = std_logic_vector'("1");

  \c$app_arg_135\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(gain_7)))))))),48);

  \c$bv_22\ <= (x_41.Frame_sel8_fAmp);

  gain_7 <= resize((to_unsigned(128,12) + (resize((resize((unsigned((\c$bv_22\(7 downto 0)))),12)) * to_unsigned(15,12), 12))),12);

  -- register begin
  ampHighpassPipe_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ampHighpassPipe <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ampHighpassPipe <= result_96;
    end if;
  end process;
  -- register end

  with (ds1_15(971 downto 971)) select
    result_96 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
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

  x_39 <= ((resize(x_42.Frame_sel0_fL,48)) - (resize(ampHpInPrevL,48))) + (resize((resize(ampHpOutPrevL,48)) * to_signed(0,48), 48));

  \c$case_alt_selection_res_47\ <= x_39 < to_signed(-8388608,48);

  \c$case_alt_54\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_47\ else
                     resize(x_39,24);

  result_selection_res_52 <= x_39 > to_signed(8388607,48);

  result_97 <= to_signed(8388607,24) when result_selection_res_52 else
               \c$case_alt_54\;

  \c$app_arg_136\ <= result_97 when \on_16\ else
                     x_42.Frame_sel0_fL;

  x_40 <= ((resize(x_42.Frame_sel1_fR,48)) - (resize(ampHpInPrevR,48))) + (resize((resize(ampHpOutPrevR,48)) * to_signed(0,48), 48));

  \c$case_alt_selection_res_48\ <= x_40 < to_signed(-8388608,48);

  \c$case_alt_55\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_48\ else
                     resize(x_40,24);

  result_selection_res_53 <= x_40 > to_signed(8388607,48);

  result_98 <= to_signed(8388607,24) when result_selection_res_53 else
               \c$case_alt_55\;

  \c$app_arg_137\ <= result_98 when \on_16\ else
                     x_42.Frame_sel1_fR;

  result_99 <= ( Frame_sel0_fL => x_42.Frame_sel0_fL
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
               , Frame_sel13_fDryL => x_42.Frame_sel0_fL
               , Frame_sel14_fDryR => x_42.Frame_sel1_fR
               , Frame_sel15_fWetL => \c$app_arg_136\
               , Frame_sel16_fWetR => \c$app_arg_137\
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

  \c$bv_23\ <= (x_42.Frame_sel3_fGate);

  \on_16\ <= (\c$bv_23\(6 downto 6)) = std_logic_vector'("1");

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
                                 x_41.Frame_sel16_fWetR when others;

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
                                 x_41.Frame_sel15_fWetL when others;

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
                                x_41.Frame_sel14_fDryR when others;

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
                                x_41.Frame_sel13_fDryL when others;

  x_41 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ampHighpassPipe(970 downto 0)));

  x_42 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_15(970 downto 0)));

  -- register begin
  ds1_15_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_15 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_15 <= result_100;
    end if;
  end process;
  -- register end

  with (ds1_16(971 downto 971)) select
    result_100 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                  std_logic_vector'("1" & ((std_logic_vector(result_101.Frame_sel0_fL)
                   & std_logic_vector(result_101.Frame_sel1_fR)
                   & clash_lowpass_fir_types.toSLV(result_101.Frame_sel2_fLast)
                   & result_101.Frame_sel3_fGate
                   & result_101.Frame_sel4_fOd
                   & result_101.Frame_sel5_fDist
                   & result_101.Frame_sel6_fEq
                   & result_101.Frame_sel7_fRat
                   & result_101.Frame_sel8_fAmp
                   & result_101.Frame_sel9_fAmpTone
                   & result_101.Frame_sel10_fCab
                   & result_101.Frame_sel11_fReverb
                   & std_logic_vector(result_101.Frame_sel12_fAddr)
                   & std_logic_vector(result_101.Frame_sel13_fDryL)
                   & std_logic_vector(result_101.Frame_sel14_fDryR)
                   & std_logic_vector(result_101.Frame_sel15_fWetL)
                   & std_logic_vector(result_101.Frame_sel16_fWetR)
                   & std_logic_vector(result_101.Frame_sel17_fFbL)
                   & std_logic_vector(result_101.Frame_sel18_fFbR)
                   & std_logic_vector(result_101.Frame_sel19_fEqLowL)
                   & std_logic_vector(result_101.Frame_sel20_fEqLowR)
                   & std_logic_vector(result_101.Frame_sel21_fEqMidL)
                   & std_logic_vector(result_101.Frame_sel22_fEqMidR)
                   & std_logic_vector(result_101.Frame_sel23_fEqHighL)
                   & std_logic_vector(result_101.Frame_sel24_fEqHighR)
                   & std_logic_vector(result_101.Frame_sel25_fEqHighLpL)
                   & std_logic_vector(result_101.Frame_sel26_fEqHighLpR)
                   & std_logic_vector(result_101.Frame_sel27_fAccL)
                   & std_logic_vector(result_101.Frame_sel28_fAccR)
                   & std_logic_vector(result_101.Frame_sel29_fAcc2L)
                   & std_logic_vector(result_101.Frame_sel30_fAcc2R)
                   & std_logic_vector(result_101.Frame_sel31_fAcc3L)
                   & std_logic_vector(result_101.Frame_sel32_fAcc3R)))) when others;

  result_101 <= ( Frame_sel0_fL => \c$app_arg_143\
                , Frame_sel1_fR => \c$app_arg_138\
                , Frame_sel2_fLast => x_43.Frame_sel2_fLast
                , Frame_sel3_fGate => x_43.Frame_sel3_fGate
                , Frame_sel4_fOd => x_43.Frame_sel4_fOd
                , Frame_sel5_fDist => x_43.Frame_sel5_fDist
                , Frame_sel6_fEq => x_43.Frame_sel6_fEq
                , Frame_sel7_fRat => x_43.Frame_sel7_fRat
                , Frame_sel8_fAmp => x_43.Frame_sel8_fAmp
                , Frame_sel9_fAmpTone => x_43.Frame_sel9_fAmpTone
                , Frame_sel10_fCab => x_43.Frame_sel10_fCab
                , Frame_sel11_fReverb => x_43.Frame_sel11_fReverb
                , Frame_sel12_fAddr => x_43.Frame_sel12_fAddr
                , Frame_sel13_fDryL => x_43.Frame_sel13_fDryL
                , Frame_sel14_fDryR => x_43.Frame_sel14_fDryR
                , Frame_sel15_fWetL => x_43.Frame_sel15_fWetL
                , Frame_sel16_fWetR => x_43.Frame_sel16_fWetR
                , Frame_sel17_fFbL => x_43.Frame_sel17_fFbL
                , Frame_sel18_fFbR => x_43.Frame_sel18_fFbR
                , Frame_sel19_fEqLowL => x_43.Frame_sel19_fEqLowL
                , Frame_sel20_fEqLowR => x_43.Frame_sel20_fEqLowR
                , Frame_sel21_fEqMidL => x_43.Frame_sel21_fEqMidL
                , Frame_sel22_fEqMidR => x_43.Frame_sel22_fEqMidR
                , Frame_sel23_fEqHighL => x_43.Frame_sel23_fEqHighL
                , Frame_sel24_fEqHighR => x_43.Frame_sel24_fEqHighR
                , Frame_sel25_fEqHighLpL => x_43.Frame_sel25_fEqHighLpL
                , Frame_sel26_fEqHighLpR => x_43.Frame_sel26_fEqHighLpR
                , Frame_sel27_fAccL => x_43.Frame_sel27_fAccL
                , Frame_sel28_fAccR => x_43.Frame_sel28_fAccR
                , Frame_sel29_fAcc2L => x_43.Frame_sel29_fAcc2L
                , Frame_sel30_fAcc2R => x_43.Frame_sel30_fAcc2R
                , Frame_sel31_fAcc3L => x_43.Frame_sel31_fAcc3L
                , Frame_sel32_fAcc3R => x_43.Frame_sel32_fAcc3R );

  \c$app_arg_138\ <= result_102 when \on_17\ else
                     x_43.Frame_sel1_fR;

  result_selection_res_54 <= result_103 > to_signed(4194304,24);

  result_102 <= resize((to_signed(4194304,25) + \c$app_arg_139\),24) when result_selection_res_54 else
                \c$case_alt_56\;

  \c$case_alt_selection_res_49\ <= result_103 < to_signed(-4194304,24);

  \c$case_alt_56\ <= resize((to_signed(-4194304,25) + \c$app_arg_140\),24) when \c$case_alt_selection_res_49\ else
                     result_103;

  \c$shI_63\ <= (to_signed(2,64));

  capp_arg_139_shiftR : block
    signal sh_63 : natural;
  begin
    sh_63 <=
        -- pragma translate_off
        natural'high when (\c$shI_63\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_63\);
    \c$app_arg_139\ <= shift_right((\c$app_arg_141\ - to_signed(4194304,25)),sh_63)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$shI_64\ <= (to_signed(2,64));

  capp_arg_140_shiftR : block
    signal sh_64 : natural;
  begin
    sh_64 <=
        -- pragma translate_off
        natural'high when (\c$shI_64\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_64\);
    \c$app_arg_140\ <= shift_right((\c$app_arg_141\ + to_signed(4194304,25)),sh_64)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_141\ <= resize(result_103,25);

  \c$case_alt_selection_res_50\ <= \c$app_arg_142\ < to_signed(-8388608,48);

  \c$case_alt_57\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_50\ else
                     resize(\c$app_arg_142\,24);

  result_selection_res_55 <= \c$app_arg_142\ > to_signed(8388607,48);

  result_103 <= to_signed(8388607,24) when result_selection_res_55 else
                \c$case_alt_57\;

  \c$shI_65\ <= (to_signed(8,64));

  capp_arg_142_shiftR : block
    signal sh_65 : natural;
  begin
    sh_65 <=
        -- pragma translate_off
        natural'high when (\c$shI_65\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_65\);
    \c$app_arg_142\ <= shift_right(((resize((resize(x_43.Frame_sel14_fDryR,48)) * \c$app_arg_149\, 48)) + (resize((resize(x_43.Frame_sel16_fWetR,48)) * \c$app_arg_148\, 48))),sh_65)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_143\ <= result_104 when \on_17\ else
                     x_43.Frame_sel0_fL;

  \c$bv_24\ <= (x_43.Frame_sel3_fGate);

  \on_17\ <= (\c$bv_24\(4 downto 4)) = std_logic_vector'("1");

  result_selection_res_56 <= result_105 > to_signed(4194304,24);

  result_104 <= resize((to_signed(4194304,25) + \c$app_arg_144\),24) when result_selection_res_56 else
                \c$case_alt_58\;

  \c$case_alt_selection_res_51\ <= result_105 < to_signed(-4194304,24);

  \c$case_alt_58\ <= resize((to_signed(-4194304,25) + \c$app_arg_145\),24) when \c$case_alt_selection_res_51\ else
                     result_105;

  \c$shI_66\ <= (to_signed(2,64));

  capp_arg_144_shiftR : block
    signal sh_66 : natural;
  begin
    sh_66 <=
        -- pragma translate_off
        natural'high when (\c$shI_66\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_66\);
    \c$app_arg_144\ <= shift_right((\c$app_arg_146\ - to_signed(4194304,25)),sh_66)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$shI_67\ <= (to_signed(2,64));

  capp_arg_145_shiftR : block
    signal sh_67 : natural;
  begin
    sh_67 <=
        -- pragma translate_off
        natural'high when (\c$shI_67\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_67\);
    \c$app_arg_145\ <= shift_right((\c$app_arg_146\ + to_signed(4194304,25)),sh_67)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_146\ <= resize(result_105,25);

  \c$case_alt_selection_res_52\ <= \c$app_arg_147\ < to_signed(-8388608,48);

  \c$case_alt_59\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_52\ else
                     resize(\c$app_arg_147\,24);

  result_selection_res_57 <= \c$app_arg_147\ > to_signed(8388607,48);

  result_105 <= to_signed(8388607,24) when result_selection_res_57 else
                \c$case_alt_59\;

  \c$shI_68\ <= (to_signed(8,64));

  capp_arg_147_shiftR : block
    signal sh_68 : natural;
  begin
    sh_68 <=
        -- pragma translate_off
        natural'high when (\c$shI_68\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_68\);
    \c$app_arg_147\ <= shift_right(((resize((resize(x_43.Frame_sel13_fDryL,48)) * \c$app_arg_149\, 48)) + (resize((resize(x_43.Frame_sel15_fWetL,48)) * \c$app_arg_148\, 48))),sh_68)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_148\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(mix_0)))))))),48);

  \c$app_arg_149\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(invMix_0)))))))),48);

  invMix_0 <= to_unsigned(255,8) - mix_0;

  \c$bv_25\ <= (x_43.Frame_sel7_fRat);

  mix_0 <= unsigned((\c$bv_25\(31 downto 24)));

  x_43 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_16(970 downto 0)));

  -- register begin
  ds1_16_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_16 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_16 <= result_106;
    end if;
  end process;
  -- register end

  with (ratTonePipe(971 downto 971)) select
    result_106 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                  std_logic_vector'("1" & ((std_logic_vector(result_107.Frame_sel0_fL)
                   & std_logic_vector(result_107.Frame_sel1_fR)
                   & clash_lowpass_fir_types.toSLV(result_107.Frame_sel2_fLast)
                   & result_107.Frame_sel3_fGate
                   & result_107.Frame_sel4_fOd
                   & result_107.Frame_sel5_fDist
                   & result_107.Frame_sel6_fEq
                   & result_107.Frame_sel7_fRat
                   & result_107.Frame_sel8_fAmp
                   & result_107.Frame_sel9_fAmpTone
                   & result_107.Frame_sel10_fCab
                   & result_107.Frame_sel11_fReverb
                   & std_logic_vector(result_107.Frame_sel12_fAddr)
                   & std_logic_vector(result_107.Frame_sel13_fDryL)
                   & std_logic_vector(result_107.Frame_sel14_fDryR)
                   & std_logic_vector(result_107.Frame_sel15_fWetL)
                   & std_logic_vector(result_107.Frame_sel16_fWetR)
                   & std_logic_vector(result_107.Frame_sel17_fFbL)
                   & std_logic_vector(result_107.Frame_sel18_fFbR)
                   & std_logic_vector(result_107.Frame_sel19_fEqLowL)
                   & std_logic_vector(result_107.Frame_sel20_fEqLowR)
                   & std_logic_vector(result_107.Frame_sel21_fEqMidL)
                   & std_logic_vector(result_107.Frame_sel22_fEqMidR)
                   & std_logic_vector(result_107.Frame_sel23_fEqHighL)
                   & std_logic_vector(result_107.Frame_sel24_fEqHighR)
                   & std_logic_vector(result_107.Frame_sel25_fEqHighLpL)
                   & std_logic_vector(result_107.Frame_sel26_fEqHighLpR)
                   & std_logic_vector(result_107.Frame_sel27_fAccL)
                   & std_logic_vector(result_107.Frame_sel28_fAccR)
                   & std_logic_vector(result_107.Frame_sel29_fAcc2L)
                   & std_logic_vector(result_107.Frame_sel30_fAcc2R)
                   & std_logic_vector(result_107.Frame_sel31_fAcc3L)
                   & std_logic_vector(result_107.Frame_sel32_fAcc3R)))) when others;

  result_107 <= ( Frame_sel0_fL => x_44.Frame_sel0_fL
                , Frame_sel1_fR => x_44.Frame_sel1_fR
                , Frame_sel2_fLast => x_44.Frame_sel2_fLast
                , Frame_sel3_fGate => x_44.Frame_sel3_fGate
                , Frame_sel4_fOd => x_44.Frame_sel4_fOd
                , Frame_sel5_fDist => x_44.Frame_sel5_fDist
                , Frame_sel6_fEq => x_44.Frame_sel6_fEq
                , Frame_sel7_fRat => x_44.Frame_sel7_fRat
                , Frame_sel8_fAmp => x_44.Frame_sel8_fAmp
                , Frame_sel9_fAmpTone => x_44.Frame_sel9_fAmpTone
                , Frame_sel10_fCab => x_44.Frame_sel10_fCab
                , Frame_sel11_fReverb => x_44.Frame_sel11_fReverb
                , Frame_sel12_fAddr => x_44.Frame_sel12_fAddr
                , Frame_sel13_fDryL => x_44.Frame_sel13_fDryL
                , Frame_sel14_fDryR => x_44.Frame_sel14_fDryR
                , Frame_sel15_fWetL => \c$app_arg_152\
                , Frame_sel16_fWetR => \c$app_arg_150\
                , Frame_sel17_fFbL => x_44.Frame_sel17_fFbL
                , Frame_sel18_fFbR => x_44.Frame_sel18_fFbR
                , Frame_sel19_fEqLowL => x_44.Frame_sel19_fEqLowL
                , Frame_sel20_fEqLowR => x_44.Frame_sel20_fEqLowR
                , Frame_sel21_fEqMidL => x_44.Frame_sel21_fEqMidL
                , Frame_sel22_fEqMidR => x_44.Frame_sel22_fEqMidR
                , Frame_sel23_fEqHighL => x_44.Frame_sel23_fEqHighL
                , Frame_sel24_fEqHighR => x_44.Frame_sel24_fEqHighR
                , Frame_sel25_fEqHighLpL => x_44.Frame_sel25_fEqHighLpL
                , Frame_sel26_fEqHighLpR => x_44.Frame_sel26_fEqHighLpR
                , Frame_sel27_fAccL => x_44.Frame_sel27_fAccL
                , Frame_sel28_fAccR => x_44.Frame_sel28_fAccR
                , Frame_sel29_fAcc2L => x_44.Frame_sel29_fAcc2L
                , Frame_sel30_fAcc2R => x_44.Frame_sel30_fAcc2R
                , Frame_sel31_fAcc3L => x_44.Frame_sel31_fAcc3L
                , Frame_sel32_fAcc3R => x_44.Frame_sel32_fAcc3R );

  \c$app_arg_150\ <= result_108 when \on_18\ else
                     x_44.Frame_sel1_fR;

  \c$case_alt_selection_res_53\ <= \c$app_arg_151\ < to_signed(-8388608,48);

  \c$case_alt_60\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_53\ else
                     resize(\c$app_arg_151\,24);

  result_selection_res_58 <= \c$app_arg_151\ > to_signed(8388607,48);

  result_108 <= to_signed(8388607,24) when result_selection_res_58 else
                \c$case_alt_60\;

  \c$shI_69\ <= (to_signed(7,64));

  capp_arg_151_shiftR : block
    signal sh_69 : natural;
  begin
    sh_69 <=
        -- pragma translate_off
        natural'high when (\c$shI_69\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_69\);
    \c$app_arg_151\ <= shift_right((resize((resize(x_44.Frame_sel16_fWetR,48)) * \c$app_arg_154\, 48)),sh_69)
        -- pragma translate_off
        when ((to_signed(7,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_152\ <= result_109 when \on_18\ else
                     x_44.Frame_sel0_fL;

  \c$bv_26\ <= (x_44.Frame_sel3_fGate);

  \on_18\ <= (\c$bv_26\(4 downto 4)) = std_logic_vector'("1");

  \c$case_alt_selection_res_54\ <= \c$app_arg_153\ < to_signed(-8388608,48);

  \c$case_alt_61\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_54\ else
                     resize(\c$app_arg_153\,24);

  result_selection_res_59 <= \c$app_arg_153\ > to_signed(8388607,48);

  result_109 <= to_signed(8388607,24) when result_selection_res_59 else
                \c$case_alt_61\;

  \c$shI_70\ <= (to_signed(7,64));

  capp_arg_153_shiftR : block
    signal sh_70 : natural;
  begin
    sh_70 <=
        -- pragma translate_off
        natural'high when (\c$shI_70\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_70\);
    \c$app_arg_153\ <= shift_right((resize((resize(x_44.Frame_sel15_fWetL,48)) * \c$app_arg_154\, 48)),sh_70)
        -- pragma translate_off
        when ((to_signed(7,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_154\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(level_1)))))))),48);

  \c$bv_27\ <= (x_44.Frame_sel7_fRat);

  level_1 <= unsigned((\c$bv_27\(15 downto 8)));

  -- register begin
  ratTonePipe_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ratTonePipe <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ratTonePipe <= result_110;
    end if;
  end process;
  -- register end

  with (ratPostPipe(971 downto 971)) select
    result_110 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                  std_logic_vector'("1" & ((std_logic_vector(result_111.Frame_sel0_fL)
                   & std_logic_vector(result_111.Frame_sel1_fR)
                   & clash_lowpass_fir_types.toSLV(result_111.Frame_sel2_fLast)
                   & result_111.Frame_sel3_fGate
                   & result_111.Frame_sel4_fOd
                   & result_111.Frame_sel5_fDist
                   & result_111.Frame_sel6_fEq
                   & result_111.Frame_sel7_fRat
                   & result_111.Frame_sel8_fAmp
                   & result_111.Frame_sel9_fAmpTone
                   & result_111.Frame_sel10_fCab
                   & result_111.Frame_sel11_fReverb
                   & std_logic_vector(result_111.Frame_sel12_fAddr)
                   & std_logic_vector(result_111.Frame_sel13_fDryL)
                   & std_logic_vector(result_111.Frame_sel14_fDryR)
                   & std_logic_vector(result_111.Frame_sel15_fWetL)
                   & std_logic_vector(result_111.Frame_sel16_fWetR)
                   & std_logic_vector(result_111.Frame_sel17_fFbL)
                   & std_logic_vector(result_111.Frame_sel18_fFbR)
                   & std_logic_vector(result_111.Frame_sel19_fEqLowL)
                   & std_logic_vector(result_111.Frame_sel20_fEqLowR)
                   & std_logic_vector(result_111.Frame_sel21_fEqMidL)
                   & std_logic_vector(result_111.Frame_sel22_fEqMidR)
                   & std_logic_vector(result_111.Frame_sel23_fEqHighL)
                   & std_logic_vector(result_111.Frame_sel24_fEqHighR)
                   & std_logic_vector(result_111.Frame_sel25_fEqHighLpL)
                   & std_logic_vector(result_111.Frame_sel26_fEqHighLpR)
                   & std_logic_vector(result_111.Frame_sel27_fAccL)
                   & std_logic_vector(result_111.Frame_sel28_fAccR)
                   & std_logic_vector(result_111.Frame_sel29_fAcc2L)
                   & std_logic_vector(result_111.Frame_sel30_fAcc2R)
                   & std_logic_vector(result_111.Frame_sel31_fAcc3L)
                   & std_logic_vector(result_111.Frame_sel32_fAcc3R)))) when others;

  alpha_0 <= to_unsigned(224,8) - (resize(\c$alpha_app_arg_0\,8));

  \c$bv_28\ <= (x_45.Frame_sel3_fGate);

  \on_19\ <= (\c$bv_28\(4 downto 4)) = std_logic_vector'("1");

  result_111 <= ( Frame_sel0_fL => x_45.Frame_sel0_fL
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
                , Frame_sel15_fWetL => \c$app_arg_157\
                , Frame_sel16_fWetR => \c$app_arg_155\
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
                , Frame_sel27_fAccL => x_45.Frame_sel27_fAccL
                , Frame_sel28_fAccR => x_45.Frame_sel28_fAccR
                , Frame_sel29_fAcc2L => x_45.Frame_sel29_fAcc2L
                , Frame_sel30_fAcc2R => x_45.Frame_sel30_fAcc2R
                , Frame_sel31_fAcc3L => x_45.Frame_sel31_fAcc3L
                , Frame_sel32_fAcc3R => x_45.Frame_sel32_fAcc3R );

  \c$app_arg_155\ <= result_112 when \on_19\ else
                     x_45.Frame_sel1_fR;

  \c$shI_71\ <= (to_signed(8,64));

  capp_arg_156_shiftR : block
    signal sh_71 : natural;
  begin
    sh_71 <=
        -- pragma translate_off
        natural'high when (\c$shI_71\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_71\);
    \c$app_arg_156\ <= shift_right(((resize((resize(x_45.Frame_sel16_fWetR,48)) * (resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(alpha_0)))))))),48)), 48)) + (resize((resize(ratTonePrevR,48)) * (resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(gain_8)))))))),48)), 48))),sh_71)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  gain_8 <= to_unsigned(255,8) - alpha_0;

  \c$case_alt_selection_res_55\ <= \c$app_arg_156\ < to_signed(-8388608,48);

  \c$case_alt_62\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_55\ else
                     resize(\c$app_arg_156\,24);

  result_selection_res_60 <= \c$app_arg_156\ > to_signed(8388607,48);

  result_112 <= to_signed(8388607,24) when result_selection_res_60 else
                \c$case_alt_62\;

  \c$app_arg_157\ <= result_113 when \on_19\ else
                     x_45.Frame_sel0_fL;

  \c$shI_72\ <= (to_signed(8,64));

  capp_arg_158_shiftR : block
    signal sh_72 : natural;
  begin
    sh_72 <=
        -- pragma translate_off
        natural'high when (\c$shI_72\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_72\);
    \c$app_arg_158\ <= shift_right(((resize((resize(x_45.Frame_sel15_fWetL,48)) * (resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(alpha_0)))))))),48)), 48)) + (resize((resize(ratTonePrevL,48)) * (resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(gain_9)))))))),48)), 48))),sh_72)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  gain_9 <= to_unsigned(255,8) - alpha_0;

  \c$case_alt_selection_res_56\ <= \c$app_arg_158\ < to_signed(-8388608,48);

  \c$case_alt_63\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_56\ else
                     resize(\c$app_arg_158\,24);

  result_selection_res_61 <= \c$app_arg_158\ > to_signed(8388607,48);

  result_113 <= to_signed(8388607,24) when result_selection_res_61 else
                \c$case_alt_63\;

  \c$bv_29\ <= (x_45.Frame_sel7_fRat);

  \c$shI_73\ <= (to_signed(2,64));

  calpha_app_arg_0_shiftL : block
    signal sh_73 : natural;
  begin
    sh_73 <=
        -- pragma translate_off
        natural'high when (\c$shI_73\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_73\);
    \c$alpha_app_arg_0\ <= shift_right((resize((resize((unsigned((\c$bv_29\(7 downto 0)))),10)) * to_unsigned(3,10), 10)),sh_73)
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
                                x_44.Frame_sel16_fWetR when others;

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
                                x_44.Frame_sel15_fWetL when others;

  x_44 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ratTonePipe(970 downto 0)));

  -- register begin
  ratPostPipe_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ratPostPipe <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ratPostPipe <= result_114;
    end if;
  end process;
  -- register end

  with (ds1_17(971 downto 971)) select
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

  \c$bv_30\ <= (x_46.Frame_sel3_fGate);

  \on_20\ <= (\c$bv_30\(4 downto 4)) = std_logic_vector'("1");

  result_115 <= ( Frame_sel0_fL => x_46.Frame_sel0_fL
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
                , Frame_sel13_fDryL => x_46.Frame_sel13_fDryL
                , Frame_sel14_fDryR => x_46.Frame_sel14_fDryR
                , Frame_sel15_fWetL => \c$app_arg_161\
                , Frame_sel16_fWetR => \c$app_arg_159\
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

  \c$app_arg_159\ <= result_116 when \on_20\ else
                     x_46.Frame_sel1_fR;

  \c$shI_74\ <= (to_signed(8,64));

  capp_arg_160_shiftR : block
    signal sh_74 : natural;
  begin
    sh_74 <=
        -- pragma translate_off
        natural'high when (\c$shI_74\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_74\);
    \c$app_arg_160\ <= shift_right(((resize((resize(x_46.Frame_sel16_fWetR,48)) * to_signed(192,48), 48)) + (resize((resize(ratPostPrevR,48)) * to_signed(63,48), 48))),sh_74)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_57\ <= \c$app_arg_160\ < to_signed(-8388608,48);

  \c$case_alt_64\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_57\ else
                     resize(\c$app_arg_160\,24);

  result_selection_res_62 <= \c$app_arg_160\ > to_signed(8388607,48);

  result_116 <= to_signed(8388607,24) when result_selection_res_62 else
                \c$case_alt_64\;

  \c$app_arg_161\ <= result_117 when \on_20\ else
                     x_46.Frame_sel0_fL;

  \c$shI_75\ <= (to_signed(8,64));

  capp_arg_162_shiftR : block
    signal sh_75 : natural;
  begin
    sh_75 <=
        -- pragma translate_off
        natural'high when (\c$shI_75\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_75\);
    \c$app_arg_162\ <= shift_right(((resize((resize(x_46.Frame_sel15_fWetL,48)) * to_signed(192,48), 48)) + (resize((resize(ratPostPrevL,48)) * to_signed(63,48), 48))),sh_75)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_58\ <= \c$app_arg_162\ < to_signed(-8388608,48);

  \c$case_alt_65\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_58\ else
                     resize(\c$app_arg_162\,24);

  result_selection_res_63 <= \c$app_arg_162\ > to_signed(8388607,48);

  result_117 <= to_signed(8388607,24) when result_selection_res_63 else
                \c$case_alt_65\;

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
                                x_45.Frame_sel16_fWetR when others;

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
                                x_45.Frame_sel15_fWetL when others;

  x_45 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ratPostPipe(970 downto 0)));

  x_46 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_17(970 downto 0)));

  -- register begin
  ds1_17_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_17 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_17 <= result_118;
    end if;
  end process;
  -- register end

  with (ratOpAmpPipe(971 downto 971)) select
    result_118 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
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

  threshold <= resize(result_122,24);

  \c$bv_31\ <= (x_48.Frame_sel3_fGate);

  \on_21\ <= (\c$bv_31\(4 downto 4)) = std_logic_vector'("1");

  result_119 <= ( Frame_sel0_fL => x_48.Frame_sel0_fL
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
                , Frame_sel15_fWetL => \c$app_arg_165\
                , Frame_sel16_fWetR => \c$app_arg_163\
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

  \c$app_arg_163\ <= result_120 when \on_21\ else
                     x_48.Frame_sel1_fR;

  result_selection_res_64 <= x_48.Frame_sel16_fWetR > threshold;

  result_120 <= threshold when result_selection_res_64 else
                \c$case_alt_66\;

  \c$case_alt_selection_res_59\ <= x_48.Frame_sel16_fWetR < \c$app_arg_164\;

  \c$case_alt_66\ <= \c$app_arg_164\ when \c$case_alt_selection_res_59\ else
                     x_48.Frame_sel16_fWetR;

  \c$app_arg_164\ <= -threshold;

  \c$app_arg_165\ <= result_121 when \on_21\ else
                     x_48.Frame_sel0_fL;

  result_selection_res_65 <= x_48.Frame_sel15_fWetL > threshold;

  result_121 <= threshold when result_selection_res_65 else
                \c$case_alt_67\;

  \c$case_alt_selection_res_60\ <= x_48.Frame_sel15_fWetL < \c$app_arg_166\;

  \c$case_alt_67\ <= \c$app_arg_166\ when \c$case_alt_selection_res_60\ else
                     x_48.Frame_sel15_fWetL;

  \c$app_arg_166\ <= -threshold;

  rawThreshold <= to_signed(6291456,25) - (resize((resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(x_47)))))))),25)) * to_signed(9000,25), 25));

  result_selection_res_66 <= rawThreshold < to_signed(3750000,25);

  result_122 <= to_signed(3750000,25) when result_selection_res_66 else
                rawThreshold;

  \c$bv_32\ <= (x_48.Frame_sel7_fRat);

  x_47 <= unsigned((\c$bv_32\(23 downto 16)));

  -- register begin
  ratOpAmpPipe_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ratOpAmpPipe <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ratOpAmpPipe <= result_123;
    end if;
  end process;
  -- register end

  with (ds1_18(971 downto 971)) select
    result_123 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                  std_logic_vector'("1" & ((std_logic_vector(result_124.Frame_sel0_fL)
                   & std_logic_vector(result_124.Frame_sel1_fR)
                   & clash_lowpass_fir_types.toSLV(result_124.Frame_sel2_fLast)
                   & result_124.Frame_sel3_fGate
                   & result_124.Frame_sel4_fOd
                   & result_124.Frame_sel5_fDist
                   & result_124.Frame_sel6_fEq
                   & result_124.Frame_sel7_fRat
                   & result_124.Frame_sel8_fAmp
                   & result_124.Frame_sel9_fAmpTone
                   & result_124.Frame_sel10_fCab
                   & result_124.Frame_sel11_fReverb
                   & std_logic_vector(result_124.Frame_sel12_fAddr)
                   & std_logic_vector(result_124.Frame_sel13_fDryL)
                   & std_logic_vector(result_124.Frame_sel14_fDryR)
                   & std_logic_vector(result_124.Frame_sel15_fWetL)
                   & std_logic_vector(result_124.Frame_sel16_fWetR)
                   & std_logic_vector(result_124.Frame_sel17_fFbL)
                   & std_logic_vector(result_124.Frame_sel18_fFbR)
                   & std_logic_vector(result_124.Frame_sel19_fEqLowL)
                   & std_logic_vector(result_124.Frame_sel20_fEqLowR)
                   & std_logic_vector(result_124.Frame_sel21_fEqMidL)
                   & std_logic_vector(result_124.Frame_sel22_fEqMidR)
                   & std_logic_vector(result_124.Frame_sel23_fEqHighL)
                   & std_logic_vector(result_124.Frame_sel24_fEqHighR)
                   & std_logic_vector(result_124.Frame_sel25_fEqHighLpL)
                   & std_logic_vector(result_124.Frame_sel26_fEqHighLpR)
                   & std_logic_vector(result_124.Frame_sel27_fAccL)
                   & std_logic_vector(result_124.Frame_sel28_fAccR)
                   & std_logic_vector(result_124.Frame_sel29_fAcc2L)
                   & std_logic_vector(result_124.Frame_sel30_fAcc2R)
                   & std_logic_vector(result_124.Frame_sel31_fAcc3L)
                   & std_logic_vector(result_124.Frame_sel32_fAcc3R)))) when others;

  alpha_1 <= to_unsigned(192,8) - (resize(\c$alpha_app_arg_1\,8));

  \c$bv_33\ <= (x_49.Frame_sel3_fGate);

  \on_22\ <= (\c$bv_33\(4 downto 4)) = std_logic_vector'("1");

  result_124 <= ( Frame_sel0_fL => x_49.Frame_sel0_fL
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
                , Frame_sel15_fWetL => \c$app_arg_169\
                , Frame_sel16_fWetR => \c$app_arg_167\
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

  \c$app_arg_167\ <= result_125 when \on_22\ else
                     x_49.Frame_sel1_fR;

  \c$shI_76\ <= (to_signed(8,64));

  capp_arg_168_shiftR : block
    signal sh_76 : natural;
  begin
    sh_76 <=
        -- pragma translate_off
        natural'high when (\c$shI_76\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_76\);
    \c$app_arg_168\ <= shift_right(((resize((resize(x_49.Frame_sel16_fWetR,48)) * (resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(alpha_1)))))))),48)), 48)) + (resize((resize(ratOpAmpPrevR,48)) * (resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(gain_10)))))))),48)), 48))),sh_76)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  gain_10 <= to_unsigned(255,8) - alpha_1;

  \c$case_alt_selection_res_61\ <= \c$app_arg_168\ < to_signed(-8388608,48);

  \c$case_alt_68\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_61\ else
                     resize(\c$app_arg_168\,24);

  result_selection_res_67 <= \c$app_arg_168\ > to_signed(8388607,48);

  result_125 <= to_signed(8388607,24) when result_selection_res_67 else
                \c$case_alt_68\;

  \c$app_arg_169\ <= result_126 when \on_22\ else
                     x_49.Frame_sel0_fL;

  \c$shI_77\ <= (to_signed(8,64));

  capp_arg_170_shiftR : block
    signal sh_77 : natural;
  begin
    sh_77 <=
        -- pragma translate_off
        natural'high when (\c$shI_77\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_77\);
    \c$app_arg_170\ <= shift_right(((resize((resize(x_49.Frame_sel15_fWetL,48)) * (resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(alpha_1)))))))),48)), 48)) + (resize((resize(ratOpAmpPrevL,48)) * (resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(gain_11)))))))),48)), 48))),sh_77)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  gain_11 <= to_unsigned(255,8) - alpha_1;

  \c$case_alt_selection_res_62\ <= \c$app_arg_170\ < to_signed(-8388608,48);

  \c$case_alt_69\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_62\ else
                     resize(\c$app_arg_170\,24);

  result_selection_res_68 <= \c$app_arg_170\ > to_signed(8388607,48);

  result_126 <= to_signed(8388607,24) when result_selection_res_68 else
                \c$case_alt_69\;

  \c$bv_34\ <= (x_49.Frame_sel7_fRat);

  \c$shI_78\ <= (to_signed(1,64));

  calpha_app_arg_1_shiftL : block
    signal sh_78 : natural;
  begin
    sh_78 <=
        -- pragma translate_off
        natural'high when (\c$shI_78\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_78\);
    \c$alpha_app_arg_1\ <= shift_right((unsigned((\c$bv_34\(23 downto 16)))),sh_78)
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
                                 x_48.Frame_sel16_fWetR when others;

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
                                 x_48.Frame_sel15_fWetL when others;

  x_48 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ratOpAmpPipe(970 downto 0)));

  x_49 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_18(970 downto 0)));

  -- register begin
  ds1_18_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_18 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_18 <= result_127;
    end if;
  end process;
  -- register end

  with (ds1_19(971 downto 971)) select
    result_127 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                  std_logic_vector'("1" & ((std_logic_vector(result_130.Frame_sel0_fL)
                   & std_logic_vector(result_130.Frame_sel1_fR)
                   & clash_lowpass_fir_types.toSLV(result_130.Frame_sel2_fLast)
                   & result_130.Frame_sel3_fGate
                   & result_130.Frame_sel4_fOd
                   & result_130.Frame_sel5_fDist
                   & result_130.Frame_sel6_fEq
                   & result_130.Frame_sel7_fRat
                   & result_130.Frame_sel8_fAmp
                   & result_130.Frame_sel9_fAmpTone
                   & result_130.Frame_sel10_fCab
                   & result_130.Frame_sel11_fReverb
                   & std_logic_vector(result_130.Frame_sel12_fAddr)
                   & std_logic_vector(result_130.Frame_sel13_fDryL)
                   & std_logic_vector(result_130.Frame_sel14_fDryR)
                   & std_logic_vector(result_130.Frame_sel15_fWetL)
                   & std_logic_vector(result_130.Frame_sel16_fWetR)
                   & std_logic_vector(result_130.Frame_sel17_fFbL)
                   & std_logic_vector(result_130.Frame_sel18_fFbR)
                   & std_logic_vector(result_130.Frame_sel19_fEqLowL)
                   & std_logic_vector(result_130.Frame_sel20_fEqLowR)
                   & std_logic_vector(result_130.Frame_sel21_fEqMidL)
                   & std_logic_vector(result_130.Frame_sel22_fEqMidR)
                   & std_logic_vector(result_130.Frame_sel23_fEqHighL)
                   & std_logic_vector(result_130.Frame_sel24_fEqHighR)
                   & std_logic_vector(result_130.Frame_sel25_fEqHighLpL)
                   & std_logic_vector(result_130.Frame_sel26_fEqHighLpR)
                   & std_logic_vector(result_130.Frame_sel27_fAccL)
                   & std_logic_vector(result_130.Frame_sel28_fAccR)
                   & std_logic_vector(result_130.Frame_sel29_fAcc2L)
                   & std_logic_vector(result_130.Frame_sel30_fAcc2R)
                   & std_logic_vector(result_130.Frame_sel31_fAcc3L)
                   & std_logic_vector(result_130.Frame_sel32_fAcc3R)))) when others;

  \c$shI_79\ <= (to_signed(8,64));

  capp_arg_171_shiftR : block
    signal sh_79 : natural;
  begin
    sh_79 <=
        -- pragma translate_off
        natural'high when (\c$shI_79\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_79\);
    \c$app_arg_171\ <= shift_right(x_50.Frame_sel27_fAccL,sh_79)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_63\ <= \c$app_arg_171\ < to_signed(-8388608,48);

  \c$case_alt_70\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_63\ else
                     resize(\c$app_arg_171\,24);

  result_selection_res_69 <= \c$app_arg_171\ > to_signed(8388607,48);

  result_128 <= to_signed(8388607,24) when result_selection_res_69 else
                \c$case_alt_70\;

  \c$app_arg_172\ <= result_128 when \on_23\ else
                     x_50.Frame_sel0_fL;

  \c$shI_80\ <= (to_signed(8,64));

  capp_arg_173_shiftR : block
    signal sh_80 : natural;
  begin
    sh_80 <=
        -- pragma translate_off
        natural'high when (\c$shI_80\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_80\);
    \c$app_arg_173\ <= shift_right(x_50.Frame_sel28_fAccR,sh_80)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_64\ <= \c$app_arg_173\ < to_signed(-8388608,48);

  \c$case_alt_71\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_64\ else
                     resize(\c$app_arg_173\,24);

  result_selection_res_70 <= \c$app_arg_173\ > to_signed(8388607,48);

  result_129 <= to_signed(8388607,24) when result_selection_res_70 else
                \c$case_alt_71\;

  \c$app_arg_174\ <= result_129 when \on_23\ else
                     x_50.Frame_sel1_fR;

  result_130 <= ( Frame_sel0_fL => x_50.Frame_sel0_fL
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
                , Frame_sel15_fWetL => \c$app_arg_172\
                , Frame_sel16_fWetR => \c$app_arg_174\
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

  \c$bv_35\ <= (x_50.Frame_sel3_fGate);

  \on_23\ <= (\c$bv_35\(4 downto 4)) = std_logic_vector'("1");

  x_50 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_19(970 downto 0)));

  -- register begin
  ds1_19_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_19 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_19 <= result_131;
    end if;
  end process;
  -- register end

  with (ratHighpassPipe(971 downto 971)) select
    result_131 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                  std_logic_vector'("1" & ((std_logic_vector(result_132.Frame_sel0_fL)
                   & std_logic_vector(result_132.Frame_sel1_fR)
                   & clash_lowpass_fir_types.toSLV(result_132.Frame_sel2_fLast)
                   & result_132.Frame_sel3_fGate
                   & result_132.Frame_sel4_fOd
                   & result_132.Frame_sel5_fDist
                   & result_132.Frame_sel6_fEq
                   & result_132.Frame_sel7_fRat
                   & result_132.Frame_sel8_fAmp
                   & result_132.Frame_sel9_fAmpTone
                   & result_132.Frame_sel10_fCab
                   & result_132.Frame_sel11_fReverb
                   & std_logic_vector(result_132.Frame_sel12_fAddr)
                   & std_logic_vector(result_132.Frame_sel13_fDryL)
                   & std_logic_vector(result_132.Frame_sel14_fDryR)
                   & std_logic_vector(result_132.Frame_sel15_fWetL)
                   & std_logic_vector(result_132.Frame_sel16_fWetR)
                   & std_logic_vector(result_132.Frame_sel17_fFbL)
                   & std_logic_vector(result_132.Frame_sel18_fFbR)
                   & std_logic_vector(result_132.Frame_sel19_fEqLowL)
                   & std_logic_vector(result_132.Frame_sel20_fEqLowR)
                   & std_logic_vector(result_132.Frame_sel21_fEqMidL)
                   & std_logic_vector(result_132.Frame_sel22_fEqMidR)
                   & std_logic_vector(result_132.Frame_sel23_fEqHighL)
                   & std_logic_vector(result_132.Frame_sel24_fEqHighR)
                   & std_logic_vector(result_132.Frame_sel25_fEqHighLpL)
                   & std_logic_vector(result_132.Frame_sel26_fEqHighLpR)
                   & std_logic_vector(result_132.Frame_sel27_fAccL)
                   & std_logic_vector(result_132.Frame_sel28_fAccR)
                   & std_logic_vector(result_132.Frame_sel29_fAcc2L)
                   & std_logic_vector(result_132.Frame_sel30_fAcc2R)
                   & std_logic_vector(result_132.Frame_sel31_fAcc3L)
                   & std_logic_vector(result_132.Frame_sel32_fAcc3R)))) when others;

  result_132 <= ( Frame_sel0_fL => x_53.Frame_sel0_fL
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
                , Frame_sel15_fWetL => x_53.Frame_sel15_fWetL
                , Frame_sel16_fWetR => x_53.Frame_sel16_fWetR
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
                , Frame_sel27_fAccL => \c$app_arg_176\
                , Frame_sel28_fAccR => \c$app_arg_175\
                , Frame_sel29_fAcc2L => x_53.Frame_sel29_fAcc2L
                , Frame_sel30_fAcc2R => x_53.Frame_sel30_fAcc2R
                , Frame_sel31_fAcc3L => x_53.Frame_sel31_fAcc3L
                , Frame_sel32_fAcc3R => x_53.Frame_sel32_fAcc3R );

  \c$app_arg_175\ <= resize((resize(x_53.Frame_sel16_fWetR,48)) * \c$app_arg_177\, 48) when \on_24\ else
                     to_signed(0,48);

  \c$app_arg_176\ <= resize((resize(x_53.Frame_sel15_fWetL,48)) * \c$app_arg_177\, 48) when \on_24\ else
                     to_signed(0,48);

  \c$bv_36\ <= (x_53.Frame_sel3_fGate);

  \on_24\ <= (\c$bv_36\(4 downto 4)) = std_logic_vector'("1");

  \c$app_arg_177\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(driveGain)))))))),48);

  \c$bv_37\ <= (x_53.Frame_sel7_fRat);

  driveGain <= resize((to_unsigned(512,12) + (resize((resize((unsigned((\c$bv_37\(23 downto 16)))),12)) * to_unsigned(14,12), 12))),12);

  -- register begin
  ratHighpassPipe_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ratHighpassPipe <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ratHighpassPipe <= result_133;
    end if;
  end process;
  -- register end

  with (ds1_20(971 downto 971)) select
    result_133 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                  std_logic_vector'("1" & ((std_logic_vector(result_136.Frame_sel0_fL)
                   & std_logic_vector(result_136.Frame_sel1_fR)
                   & clash_lowpass_fir_types.toSLV(result_136.Frame_sel2_fLast)
                   & result_136.Frame_sel3_fGate
                   & result_136.Frame_sel4_fOd
                   & result_136.Frame_sel5_fDist
                   & result_136.Frame_sel6_fEq
                   & result_136.Frame_sel7_fRat
                   & result_136.Frame_sel8_fAmp
                   & result_136.Frame_sel9_fAmpTone
                   & result_136.Frame_sel10_fCab
                   & result_136.Frame_sel11_fReverb
                   & std_logic_vector(result_136.Frame_sel12_fAddr)
                   & std_logic_vector(result_136.Frame_sel13_fDryL)
                   & std_logic_vector(result_136.Frame_sel14_fDryR)
                   & std_logic_vector(result_136.Frame_sel15_fWetL)
                   & std_logic_vector(result_136.Frame_sel16_fWetR)
                   & std_logic_vector(result_136.Frame_sel17_fFbL)
                   & std_logic_vector(result_136.Frame_sel18_fFbR)
                   & std_logic_vector(result_136.Frame_sel19_fEqLowL)
                   & std_logic_vector(result_136.Frame_sel20_fEqLowR)
                   & std_logic_vector(result_136.Frame_sel21_fEqMidL)
                   & std_logic_vector(result_136.Frame_sel22_fEqMidR)
                   & std_logic_vector(result_136.Frame_sel23_fEqHighL)
                   & std_logic_vector(result_136.Frame_sel24_fEqHighR)
                   & std_logic_vector(result_136.Frame_sel25_fEqHighLpL)
                   & std_logic_vector(result_136.Frame_sel26_fEqHighLpR)
                   & std_logic_vector(result_136.Frame_sel27_fAccL)
                   & std_logic_vector(result_136.Frame_sel28_fAccR)
                   & std_logic_vector(result_136.Frame_sel29_fAcc2L)
                   & std_logic_vector(result_136.Frame_sel30_fAcc2R)
                   & std_logic_vector(result_136.Frame_sel31_fAcc3L)
                   & std_logic_vector(result_136.Frame_sel32_fAcc3R)))) when others;

  x_51 <= ((resize(x_54.Frame_sel0_fL,48)) - (resize(ratHpInPrevL,48))) + (resize((resize(ratHpOutPrevL,48)) * to_signed(0,48), 48));

  \c$case_alt_selection_res_65\ <= x_51 < to_signed(-8388608,48);

  \c$case_alt_72\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_65\ else
                     resize(x_51,24);

  result_selection_res_71 <= x_51 > to_signed(8388607,48);

  result_134 <= to_signed(8388607,24) when result_selection_res_71 else
                \c$case_alt_72\;

  \c$app_arg_178\ <= result_134 when \on_25\ else
                     x_54.Frame_sel0_fL;

  x_52 <= ((resize(x_54.Frame_sel1_fR,48)) - (resize(ratHpInPrevR,48))) + (resize((resize(ratHpOutPrevR,48)) * to_signed(0,48), 48));

  \c$case_alt_selection_res_66\ <= x_52 < to_signed(-8388608,48);

  \c$case_alt_73\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_66\ else
                     resize(x_52,24);

  result_selection_res_72 <= x_52 > to_signed(8388607,48);

  result_135 <= to_signed(8388607,24) when result_selection_res_72 else
                \c$case_alt_73\;

  \c$app_arg_179\ <= result_135 when \on_25\ else
                     x_54.Frame_sel1_fR;

  result_136 <= ( Frame_sel0_fL => x_54.Frame_sel0_fL
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
                , Frame_sel13_fDryL => x_54.Frame_sel0_fL
                , Frame_sel14_fDryR => x_54.Frame_sel1_fR
                , Frame_sel15_fWetL => \c$app_arg_178\
                , Frame_sel16_fWetR => \c$app_arg_179\
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

  \c$bv_38\ <= (x_54.Frame_sel3_fGate);

  \on_25\ <= (\c$bv_38\(4 downto 4)) = std_logic_vector'("1");

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
                                 x_53.Frame_sel16_fWetR when others;

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
                                 x_53.Frame_sel15_fWetL when others;

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
                                x_53.Frame_sel14_fDryR when others;

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
                                x_53.Frame_sel13_fDryL when others;

  x_53 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ratHighpassPipe(970 downto 0)));

  x_54 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_20(970 downto 0)));

  -- register begin
  ds1_20_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_20 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_20 <= result_137;
    end if;
  end process;
  -- register end

  with (distToneBlendPipe(971 downto 971)) select
    result_137 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                  std_logic_vector'("1" & ((std_logic_vector(result_138.Frame_sel0_fL)
                   & std_logic_vector(result_138.Frame_sel1_fR)
                   & clash_lowpass_fir_types.toSLV(result_138.Frame_sel2_fLast)
                   & result_138.Frame_sel3_fGate
                   & result_138.Frame_sel4_fOd
                   & result_138.Frame_sel5_fDist
                   & result_138.Frame_sel6_fEq
                   & result_138.Frame_sel7_fRat
                   & result_138.Frame_sel8_fAmp
                   & result_138.Frame_sel9_fAmpTone
                   & result_138.Frame_sel10_fCab
                   & result_138.Frame_sel11_fReverb
                   & std_logic_vector(result_138.Frame_sel12_fAddr)
                   & std_logic_vector(result_138.Frame_sel13_fDryL)
                   & std_logic_vector(result_138.Frame_sel14_fDryR)
                   & std_logic_vector(result_138.Frame_sel15_fWetL)
                   & std_logic_vector(result_138.Frame_sel16_fWetR)
                   & std_logic_vector(result_138.Frame_sel17_fFbL)
                   & std_logic_vector(result_138.Frame_sel18_fFbR)
                   & std_logic_vector(result_138.Frame_sel19_fEqLowL)
                   & std_logic_vector(result_138.Frame_sel20_fEqLowR)
                   & std_logic_vector(result_138.Frame_sel21_fEqMidL)
                   & std_logic_vector(result_138.Frame_sel22_fEqMidR)
                   & std_logic_vector(result_138.Frame_sel23_fEqHighL)
                   & std_logic_vector(result_138.Frame_sel24_fEqHighR)
                   & std_logic_vector(result_138.Frame_sel25_fEqHighLpL)
                   & std_logic_vector(result_138.Frame_sel26_fEqHighLpR)
                   & std_logic_vector(result_138.Frame_sel27_fAccL)
                   & std_logic_vector(result_138.Frame_sel28_fAccR)
                   & std_logic_vector(result_138.Frame_sel29_fAcc2L)
                   & std_logic_vector(result_138.Frame_sel30_fAcc2R)
                   & std_logic_vector(result_138.Frame_sel31_fAcc3L)
                   & std_logic_vector(result_138.Frame_sel32_fAcc3R)))) when others;

  result_138 <= ( Frame_sel0_fL => \c$app_arg_182\
                , Frame_sel1_fR => \c$app_arg_180\
                , Frame_sel2_fLast => x_56.Frame_sel2_fLast
                , Frame_sel3_fGate => x_56.Frame_sel3_fGate
                , Frame_sel4_fOd => x_56.Frame_sel4_fOd
                , Frame_sel5_fDist => x_56.Frame_sel5_fDist
                , Frame_sel6_fEq => x_56.Frame_sel6_fEq
                , Frame_sel7_fRat => x_56.Frame_sel7_fRat
                , Frame_sel8_fAmp => x_56.Frame_sel8_fAmp
                , Frame_sel9_fAmpTone => x_56.Frame_sel9_fAmpTone
                , Frame_sel10_fCab => x_56.Frame_sel10_fCab
                , Frame_sel11_fReverb => x_56.Frame_sel11_fReverb
                , Frame_sel12_fAddr => x_56.Frame_sel12_fAddr
                , Frame_sel13_fDryL => x_56.Frame_sel13_fDryL
                , Frame_sel14_fDryR => x_56.Frame_sel14_fDryR
                , Frame_sel15_fWetL => x_56.Frame_sel15_fWetL
                , Frame_sel16_fWetR => x_56.Frame_sel16_fWetR
                , Frame_sel17_fFbL => x_56.Frame_sel17_fFbL
                , Frame_sel18_fFbR => x_56.Frame_sel18_fFbR
                , Frame_sel19_fEqLowL => x_56.Frame_sel19_fEqLowL
                , Frame_sel20_fEqLowR => x_56.Frame_sel20_fEqLowR
                , Frame_sel21_fEqMidL => x_56.Frame_sel21_fEqMidL
                , Frame_sel22_fEqMidR => x_56.Frame_sel22_fEqMidR
                , Frame_sel23_fEqHighL => x_56.Frame_sel23_fEqHighL
                , Frame_sel24_fEqHighR => x_56.Frame_sel24_fEqHighR
                , Frame_sel25_fEqHighLpL => x_56.Frame_sel25_fEqHighLpL
                , Frame_sel26_fEqHighLpR => x_56.Frame_sel26_fEqHighLpR
                , Frame_sel27_fAccL => x_56.Frame_sel27_fAccL
                , Frame_sel28_fAccR => x_56.Frame_sel28_fAccR
                , Frame_sel29_fAcc2L => x_56.Frame_sel29_fAcc2L
                , Frame_sel30_fAcc2R => x_56.Frame_sel30_fAcc2R
                , Frame_sel31_fAcc3L => x_56.Frame_sel31_fAcc3L
                , Frame_sel32_fAcc3R => x_56.Frame_sel32_fAcc3R );

  \c$app_arg_180\ <= result_139 when \on_26\ else
                     x_56.Frame_sel1_fR;

  \c$case_alt_selection_res_67\ <= \c$app_arg_181\ < to_signed(-8388608,48);

  \c$case_alt_74\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_67\ else
                     resize(\c$app_arg_181\,24);

  result_selection_res_73 <= \c$app_arg_181\ > to_signed(8388607,48);

  result_139 <= to_signed(8388607,24) when result_selection_res_73 else
                \c$case_alt_74\;

  \c$shI_81\ <= (to_signed(7,64));

  capp_arg_181_shiftR : block
    signal sh_81 : natural;
  begin
    sh_81 <=
        -- pragma translate_off
        natural'high when (\c$shI_81\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_81\);
    \c$app_arg_181\ <= shift_right((resize((resize(x_56.Frame_sel16_fWetR,48)) * \c$app_arg_184\, 48)),sh_81)
        -- pragma translate_off
        when ((to_signed(7,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_182\ <= result_140 when \on_26\ else
                     x_56.Frame_sel0_fL;

  \c$bv_39\ <= (x_56.Frame_sel3_fGate);

  \on_26\ <= (\c$bv_39\(2 downto 2)) = std_logic_vector'("1");

  \c$case_alt_selection_res_68\ <= \c$app_arg_183\ < to_signed(-8388608,48);

  \c$case_alt_75\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_68\ else
                     resize(\c$app_arg_183\,24);

  result_selection_res_74 <= \c$app_arg_183\ > to_signed(8388607,48);

  result_140 <= to_signed(8388607,24) when result_selection_res_74 else
                \c$case_alt_75\;

  \c$shI_82\ <= (to_signed(7,64));

  capp_arg_183_shiftR : block
    signal sh_82 : natural;
  begin
    sh_82 <=
        -- pragma translate_off
        natural'high when (\c$shI_82\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_82\);
    \c$app_arg_183\ <= shift_right((resize((resize(x_56.Frame_sel15_fWetL,48)) * \c$app_arg_184\, 48)),sh_82)
        -- pragma translate_off
        when ((to_signed(7,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_184\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(level_2)))))))),48);

  \c$bv_40\ <= (x_56.Frame_sel5_fDist);

  level_2 <= unsigned((\c$bv_40\(15 downto 8)));

  -- register begin
  distToneBlendPipe_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      distToneBlendPipe <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      distToneBlendPipe <= result_141;
    end if;
  end process;
  -- register end

  with (ds1_21(971 downto 971)) select
    result_141 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
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

  \c$shI_83\ <= (to_signed(8,64));

  capp_arg_185_shiftR : block
    signal sh_83 : natural;
  begin
    sh_83 <=
        -- pragma translate_off
        natural'high when (\c$shI_83\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_83\);
    \c$app_arg_185\ <= shift_right((x_55.Frame_sel27_fAccL + x_55.Frame_sel29_fAcc2L),sh_83)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_69\ <= \c$app_arg_185\ < to_signed(-8388608,48);

  \c$case_alt_76\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_69\ else
                     resize(\c$app_arg_185\,24);

  result_selection_res_75 <= \c$app_arg_185\ > to_signed(8388607,48);

  result_142 <= to_signed(8388607,24) when result_selection_res_75 else
                \c$case_alt_76\;

  \c$app_arg_186\ <= result_142 when \on_27\ else
                     x_55.Frame_sel0_fL;

  \c$shI_84\ <= (to_signed(8,64));

  capp_arg_187_shiftR : block
    signal sh_84 : natural;
  begin
    sh_84 <=
        -- pragma translate_off
        natural'high when (\c$shI_84\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_84\);
    \c$app_arg_187\ <= shift_right((x_55.Frame_sel28_fAccR + x_55.Frame_sel30_fAcc2R),sh_84)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_70\ <= \c$app_arg_187\ < to_signed(-8388608,48);

  \c$case_alt_77\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_70\ else
                     resize(\c$app_arg_187\,24);

  result_selection_res_76 <= \c$app_arg_187\ > to_signed(8388607,48);

  result_143 <= to_signed(8388607,24) when result_selection_res_76 else
                \c$case_alt_77\;

  \c$app_arg_188\ <= result_143 when \on_27\ else
                     x_55.Frame_sel1_fR;

  result_144 <= ( Frame_sel0_fL => x_55.Frame_sel0_fL
                , Frame_sel1_fR => x_55.Frame_sel1_fR
                , Frame_sel2_fLast => x_55.Frame_sel2_fLast
                , Frame_sel3_fGate => x_55.Frame_sel3_fGate
                , Frame_sel4_fOd => x_55.Frame_sel4_fOd
                , Frame_sel5_fDist => x_55.Frame_sel5_fDist
                , Frame_sel6_fEq => x_55.Frame_sel6_fEq
                , Frame_sel7_fRat => x_55.Frame_sel7_fRat
                , Frame_sel8_fAmp => x_55.Frame_sel8_fAmp
                , Frame_sel9_fAmpTone => x_55.Frame_sel9_fAmpTone
                , Frame_sel10_fCab => x_55.Frame_sel10_fCab
                , Frame_sel11_fReverb => x_55.Frame_sel11_fReverb
                , Frame_sel12_fAddr => x_55.Frame_sel12_fAddr
                , Frame_sel13_fDryL => x_55.Frame_sel13_fDryL
                , Frame_sel14_fDryR => x_55.Frame_sel14_fDryR
                , Frame_sel15_fWetL => \c$app_arg_186\
                , Frame_sel16_fWetR => \c$app_arg_188\
                , Frame_sel17_fFbL => x_55.Frame_sel17_fFbL
                , Frame_sel18_fFbR => x_55.Frame_sel18_fFbR
                , Frame_sel19_fEqLowL => x_55.Frame_sel19_fEqLowL
                , Frame_sel20_fEqLowR => x_55.Frame_sel20_fEqLowR
                , Frame_sel21_fEqMidL => x_55.Frame_sel21_fEqMidL
                , Frame_sel22_fEqMidR => x_55.Frame_sel22_fEqMidR
                , Frame_sel23_fEqHighL => x_55.Frame_sel23_fEqHighL
                , Frame_sel24_fEqHighR => x_55.Frame_sel24_fEqHighR
                , Frame_sel25_fEqHighLpL => x_55.Frame_sel25_fEqHighLpL
                , Frame_sel26_fEqHighLpR => x_55.Frame_sel26_fEqHighLpR
                , Frame_sel27_fAccL => x_55.Frame_sel27_fAccL
                , Frame_sel28_fAccR => x_55.Frame_sel28_fAccR
                , Frame_sel29_fAcc2L => x_55.Frame_sel29_fAcc2L
                , Frame_sel30_fAcc2R => x_55.Frame_sel30_fAcc2R
                , Frame_sel31_fAcc3L => x_55.Frame_sel31_fAcc3L
                , Frame_sel32_fAcc3R => x_55.Frame_sel32_fAcc3R );

  \c$bv_41\ <= (x_55.Frame_sel3_fGate);

  \on_27\ <= (\c$bv_41\(2 downto 2)) = std_logic_vector'("1");

  x_55 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_21(970 downto 0)));

  -- register begin
  ds1_21_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_21 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_21 <= result_145;
    end if;
  end process;
  -- register end

  with (ds1_22(971 downto 971)) select
    result_145 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                  std_logic_vector'("1" & ((std_logic_vector(result_146.Frame_sel0_fL)
                   & std_logic_vector(result_146.Frame_sel1_fR)
                   & clash_lowpass_fir_types.toSLV(result_146.Frame_sel2_fLast)
                   & result_146.Frame_sel3_fGate
                   & result_146.Frame_sel4_fOd
                   & result_146.Frame_sel5_fDist
                   & result_146.Frame_sel6_fEq
                   & result_146.Frame_sel7_fRat
                   & result_146.Frame_sel8_fAmp
                   & result_146.Frame_sel9_fAmpTone
                   & result_146.Frame_sel10_fCab
                   & result_146.Frame_sel11_fReverb
                   & std_logic_vector(result_146.Frame_sel12_fAddr)
                   & std_logic_vector(result_146.Frame_sel13_fDryL)
                   & std_logic_vector(result_146.Frame_sel14_fDryR)
                   & std_logic_vector(result_146.Frame_sel15_fWetL)
                   & std_logic_vector(result_146.Frame_sel16_fWetR)
                   & std_logic_vector(result_146.Frame_sel17_fFbL)
                   & std_logic_vector(result_146.Frame_sel18_fFbR)
                   & std_logic_vector(result_146.Frame_sel19_fEqLowL)
                   & std_logic_vector(result_146.Frame_sel20_fEqLowR)
                   & std_logic_vector(result_146.Frame_sel21_fEqMidL)
                   & std_logic_vector(result_146.Frame_sel22_fEqMidR)
                   & std_logic_vector(result_146.Frame_sel23_fEqHighL)
                   & std_logic_vector(result_146.Frame_sel24_fEqHighR)
                   & std_logic_vector(result_146.Frame_sel25_fEqHighLpL)
                   & std_logic_vector(result_146.Frame_sel26_fEqHighLpR)
                   & std_logic_vector(result_146.Frame_sel27_fAccL)
                   & std_logic_vector(result_146.Frame_sel28_fAccR)
                   & std_logic_vector(result_146.Frame_sel29_fAcc2L)
                   & std_logic_vector(result_146.Frame_sel30_fAcc2R)
                   & std_logic_vector(result_146.Frame_sel31_fAcc3L)
                   & std_logic_vector(result_146.Frame_sel32_fAcc3R)))) when others;

  result_146 <= ( Frame_sel0_fL => x_57.Frame_sel0_fL
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
                , Frame_sel27_fAccL => \c$app_arg_193\
                , Frame_sel28_fAccR => \c$app_arg_192\
                , Frame_sel29_fAcc2L => \c$app_arg_190\
                , Frame_sel30_fAcc2R => \c$app_arg_189\
                , Frame_sel31_fAcc3L => x_57.Frame_sel31_fAcc3L
                , Frame_sel32_fAcc3R => x_57.Frame_sel32_fAcc3R );

  \c$app_arg_189\ <= resize((resize(distTonePrevR,48)) * \c$app_arg_191\, 48) when \on_28\ else
                     to_signed(0,48);

  \c$app_arg_190\ <= resize((resize(distTonePrevL,48)) * \c$app_arg_191\, 48) when \on_28\ else
                     to_signed(0,48);

  \c$app_arg_191\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(toneInv)))))))),48);

  toneInv <= to_unsigned(255,8) - tone;

  \c$app_arg_192\ <= resize((resize(x_57.Frame_sel1_fR,48)) * \c$app_arg_194\, 48) when \on_28\ else
                     to_signed(0,48);

  \c$app_arg_193\ <= resize((resize(x_57.Frame_sel0_fL,48)) * \c$app_arg_194\, 48) when \on_28\ else
                     to_signed(0,48);

  \c$bv_42\ <= (x_57.Frame_sel3_fGate);

  \on_28\ <= (\c$bv_42\(2 downto 2)) = std_logic_vector'("1");

  \c$app_arg_194\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(tone)))))))),48);

  \c$bv_43\ <= (x_57.Frame_sel5_fDist);

  tone <= unsigned((\c$bv_43\(7 downto 0)));

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
                                 x_56.Frame_sel16_fWetR when others;

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
                                 x_56.Frame_sel15_fWetL when others;

  x_56 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(distToneBlendPipe(970 downto 0)));

  x_57 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_22(970 downto 0)));

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
                  std_logic_vector'("1" & ((std_logic_vector(result_148.Frame_sel0_fL)
                   & std_logic_vector(result_148.Frame_sel1_fR)
                   & clash_lowpass_fir_types.toSLV(result_148.Frame_sel2_fLast)
                   & result_148.Frame_sel3_fGate
                   & result_148.Frame_sel4_fOd
                   & result_148.Frame_sel5_fDist
                   & result_148.Frame_sel6_fEq
                   & result_148.Frame_sel7_fRat
                   & result_148.Frame_sel8_fAmp
                   & result_148.Frame_sel9_fAmpTone
                   & result_148.Frame_sel10_fCab
                   & result_148.Frame_sel11_fReverb
                   & std_logic_vector(result_148.Frame_sel12_fAddr)
                   & std_logic_vector(result_148.Frame_sel13_fDryL)
                   & std_logic_vector(result_148.Frame_sel14_fDryR)
                   & std_logic_vector(result_148.Frame_sel15_fWetL)
                   & std_logic_vector(result_148.Frame_sel16_fWetR)
                   & std_logic_vector(result_148.Frame_sel17_fFbL)
                   & std_logic_vector(result_148.Frame_sel18_fFbR)
                   & std_logic_vector(result_148.Frame_sel19_fEqLowL)
                   & std_logic_vector(result_148.Frame_sel20_fEqLowR)
                   & std_logic_vector(result_148.Frame_sel21_fEqMidL)
                   & std_logic_vector(result_148.Frame_sel22_fEqMidR)
                   & std_logic_vector(result_148.Frame_sel23_fEqHighL)
                   & std_logic_vector(result_148.Frame_sel24_fEqHighR)
                   & std_logic_vector(result_148.Frame_sel25_fEqHighLpL)
                   & std_logic_vector(result_148.Frame_sel26_fEqHighLpR)
                   & std_logic_vector(result_148.Frame_sel27_fAccL)
                   & std_logic_vector(result_148.Frame_sel28_fAccR)
                   & std_logic_vector(result_148.Frame_sel29_fAcc2L)
                   & std_logic_vector(result_148.Frame_sel30_fAcc2R)
                   & std_logic_vector(result_148.Frame_sel31_fAcc3L)
                   & std_logic_vector(result_148.Frame_sel32_fAcc3R)))) when others;

  threshold_0 <= resize(x_58.Frame_sel29_fAcc2L,24);

  \c$bv_44\ <= (x_58.Frame_sel3_fGate);

  \on_29\ <= (\c$bv_44\(2 downto 2)) = std_logic_vector'("1");

  result_148 <= ( Frame_sel0_fL => \c$app_arg_197\
                , Frame_sel1_fR => \c$app_arg_195\
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
                , Frame_sel13_fDryL => x_58.Frame_sel13_fDryL
                , Frame_sel14_fDryR => x_58.Frame_sel14_fDryR
                , Frame_sel15_fWetL => x_58.Frame_sel15_fWetL
                , Frame_sel16_fWetR => x_58.Frame_sel16_fWetR
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

  \c$app_arg_195\ <= result_149 when \on_29\ else
                     x_58.Frame_sel1_fR;

  result_selection_res_77 <= x_58.Frame_sel16_fWetR > threshold_0;

  result_149 <= threshold_0 when result_selection_res_77 else
                \c$case_alt_78\;

  \c$case_alt_selection_res_71\ <= x_58.Frame_sel16_fWetR < \c$app_arg_196\;

  \c$case_alt_78\ <= \c$app_arg_196\ when \c$case_alt_selection_res_71\ else
                     x_58.Frame_sel16_fWetR;

  \c$app_arg_196\ <= -threshold_0;

  \c$app_arg_197\ <= result_150 when \on_29\ else
                     x_58.Frame_sel0_fL;

  result_selection_res_78 <= x_58.Frame_sel15_fWetL > threshold_0;

  result_150 <= threshold_0 when result_selection_res_78 else
                \c$case_alt_79\;

  \c$case_alt_selection_res_72\ <= x_58.Frame_sel15_fWetL < \c$app_arg_198\;

  \c$case_alt_79\ <= \c$app_arg_198\ when \c$case_alt_selection_res_72\ else
                     x_58.Frame_sel15_fWetL;

  \c$app_arg_198\ <= -threshold_0;

  x_58 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_23(970 downto 0)));

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

  with (ds1_24(971 downto 971)) select
    result_151 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                  std_logic_vector'("1" & ((std_logic_vector(result_154.Frame_sel0_fL)
                   & std_logic_vector(result_154.Frame_sel1_fR)
                   & clash_lowpass_fir_types.toSLV(result_154.Frame_sel2_fLast)
                   & result_154.Frame_sel3_fGate
                   & result_154.Frame_sel4_fOd
                   & result_154.Frame_sel5_fDist
                   & result_154.Frame_sel6_fEq
                   & result_154.Frame_sel7_fRat
                   & result_154.Frame_sel8_fAmp
                   & result_154.Frame_sel9_fAmpTone
                   & result_154.Frame_sel10_fCab
                   & result_154.Frame_sel11_fReverb
                   & std_logic_vector(result_154.Frame_sel12_fAddr)
                   & std_logic_vector(result_154.Frame_sel13_fDryL)
                   & std_logic_vector(result_154.Frame_sel14_fDryR)
                   & std_logic_vector(result_154.Frame_sel15_fWetL)
                   & std_logic_vector(result_154.Frame_sel16_fWetR)
                   & std_logic_vector(result_154.Frame_sel17_fFbL)
                   & std_logic_vector(result_154.Frame_sel18_fFbR)
                   & std_logic_vector(result_154.Frame_sel19_fEqLowL)
                   & std_logic_vector(result_154.Frame_sel20_fEqLowR)
                   & std_logic_vector(result_154.Frame_sel21_fEqMidL)
                   & std_logic_vector(result_154.Frame_sel22_fEqMidR)
                   & std_logic_vector(result_154.Frame_sel23_fEqHighL)
                   & std_logic_vector(result_154.Frame_sel24_fEqHighR)
                   & std_logic_vector(result_154.Frame_sel25_fEqHighLpL)
                   & std_logic_vector(result_154.Frame_sel26_fEqHighLpR)
                   & std_logic_vector(result_154.Frame_sel27_fAccL)
                   & std_logic_vector(result_154.Frame_sel28_fAccR)
                   & std_logic_vector(result_154.Frame_sel29_fAcc2L)
                   & std_logic_vector(result_154.Frame_sel30_fAcc2R)
                   & std_logic_vector(result_154.Frame_sel31_fAcc3L)
                   & std_logic_vector(result_154.Frame_sel32_fAcc3R)))) when others;

  \c$shI_85\ <= (to_signed(8,64));

  capp_arg_199_shiftR : block
    signal sh_85 : natural;
  begin
    sh_85 <=
        -- pragma translate_off
        natural'high when (\c$shI_85\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_85\);
    \c$app_arg_199\ <= shift_right(x_59.Frame_sel27_fAccL,sh_85)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_73\ <= \c$app_arg_199\ < to_signed(-8388608,48);

  \c$case_alt_80\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_73\ else
                     resize(\c$app_arg_199\,24);

  result_selection_res_79 <= \c$app_arg_199\ > to_signed(8388607,48);

  result_152 <= to_signed(8388607,24) when result_selection_res_79 else
                \c$case_alt_80\;

  \c$app_arg_200\ <= result_152 when \on_30\ else
                     x_59.Frame_sel0_fL;

  \c$shI_86\ <= (to_signed(8,64));

  capp_arg_201_shiftR : block
    signal sh_86 : natural;
  begin
    sh_86 <=
        -- pragma translate_off
        natural'high when (\c$shI_86\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_86\);
    \c$app_arg_201\ <= shift_right(x_59.Frame_sel28_fAccR,sh_86)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_74\ <= \c$app_arg_201\ < to_signed(-8388608,48);

  \c$case_alt_81\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_74\ else
                     resize(\c$app_arg_201\,24);

  result_selection_res_80 <= \c$app_arg_201\ > to_signed(8388607,48);

  result_153 <= to_signed(8388607,24) when result_selection_res_80 else
                \c$case_alt_81\;

  \c$app_arg_202\ <= result_153 when \on_30\ else
                     x_59.Frame_sel1_fR;

  result_154 <= ( Frame_sel0_fL => x_59.Frame_sel0_fL
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
                , Frame_sel15_fWetL => \c$app_arg_200\
                , Frame_sel16_fWetR => \c$app_arg_202\
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

  \c$bv_45\ <= (x_59.Frame_sel3_fGate);

  \on_30\ <= (\c$bv_45\(2 downto 2)) = std_logic_vector'("1");

  x_59 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_24(970 downto 0)));

  -- register begin
  ds1_24_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_24 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_24 <= result_155;
    end if;
  end process;
  -- register end

  with (ds1_25(971 downto 971)) select
    result_155 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
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

  result_156 <= ( Frame_sel0_fL => x_60.Frame_sel0_fL
                , Frame_sel1_fR => x_60.Frame_sel1_fR
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
                , Frame_sel27_fAccL => \c$app_arg_204\
                , Frame_sel28_fAccR => \c$app_arg_203\
                , Frame_sel29_fAcc2L => resize((resize(result_157,24)),48)
                , Frame_sel30_fAcc2R => x_60.Frame_sel30_fAcc2R
                , Frame_sel31_fAcc3L => x_60.Frame_sel31_fAcc3L
                , Frame_sel32_fAcc3R => x_60.Frame_sel32_fAcc3R );

  result_selection_res_81 <= rawThreshold_0 < to_signed(1800000,25);

  result_157 <= to_signed(1800000,25) when result_selection_res_81 else
                rawThreshold_0;

  rawThreshold_0 <= to_signed(8388607,25) - (resize((resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(amount)))))))),25)) * to_signed(24000,25), 25));

  \c$app_arg_203\ <= resize((resize(x_60.Frame_sel1_fR,48)) * \c$app_arg_205\, 48) when \on_31\ else
                     to_signed(0,48);

  \c$app_arg_204\ <= resize((resize(x_60.Frame_sel0_fL,48)) * \c$app_arg_205\, 48) when \on_31\ else
                     to_signed(0,48);

  \c$bv_46\ <= (x_60.Frame_sel3_fGate);

  \on_31\ <= (\c$bv_46\(2 downto 2)) = std_logic_vector'("1");

  \c$app_arg_205\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(driveGain_0)))))))),48);

  driveGain_0 <= resize((to_unsigned(256,11) + (resize((resize(amount,11)) * to_unsigned(8,11), 11))),12);

  \c$bv_47\ <= (x_60.Frame_sel5_fDist);

  amount <= unsigned((\c$bv_47\(23 downto 16)));

  x_60 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_25(970 downto 0)));

  -- register begin
  ds1_25_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_25 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_25 <= result_158;
    end if;
  end process;
  -- register end

  with (odToneBlendPipe(971 downto 971)) select
    result_158 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                  std_logic_vector'("1" & ((std_logic_vector(result_159.Frame_sel0_fL)
                   & std_logic_vector(result_159.Frame_sel1_fR)
                   & clash_lowpass_fir_types.toSLV(result_159.Frame_sel2_fLast)
                   & result_159.Frame_sel3_fGate
                   & result_159.Frame_sel4_fOd
                   & result_159.Frame_sel5_fDist
                   & result_159.Frame_sel6_fEq
                   & result_159.Frame_sel7_fRat
                   & result_159.Frame_sel8_fAmp
                   & result_159.Frame_sel9_fAmpTone
                   & result_159.Frame_sel10_fCab
                   & result_159.Frame_sel11_fReverb
                   & std_logic_vector(result_159.Frame_sel12_fAddr)
                   & std_logic_vector(result_159.Frame_sel13_fDryL)
                   & std_logic_vector(result_159.Frame_sel14_fDryR)
                   & std_logic_vector(result_159.Frame_sel15_fWetL)
                   & std_logic_vector(result_159.Frame_sel16_fWetR)
                   & std_logic_vector(result_159.Frame_sel17_fFbL)
                   & std_logic_vector(result_159.Frame_sel18_fFbR)
                   & std_logic_vector(result_159.Frame_sel19_fEqLowL)
                   & std_logic_vector(result_159.Frame_sel20_fEqLowR)
                   & std_logic_vector(result_159.Frame_sel21_fEqMidL)
                   & std_logic_vector(result_159.Frame_sel22_fEqMidR)
                   & std_logic_vector(result_159.Frame_sel23_fEqHighL)
                   & std_logic_vector(result_159.Frame_sel24_fEqHighR)
                   & std_logic_vector(result_159.Frame_sel25_fEqHighLpL)
                   & std_logic_vector(result_159.Frame_sel26_fEqHighLpR)
                   & std_logic_vector(result_159.Frame_sel27_fAccL)
                   & std_logic_vector(result_159.Frame_sel28_fAccR)
                   & std_logic_vector(result_159.Frame_sel29_fAcc2L)
                   & std_logic_vector(result_159.Frame_sel30_fAcc2R)
                   & std_logic_vector(result_159.Frame_sel31_fAcc3L)
                   & std_logic_vector(result_159.Frame_sel32_fAcc3R)))) when others;

  result_159 <= ( Frame_sel0_fL => \c$app_arg_208\
                , Frame_sel1_fR => \c$app_arg_206\
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

  \c$app_arg_206\ <= result_160 when \on_32\ else
                     x_62.Frame_sel1_fR;

  \c$case_alt_selection_res_75\ <= \c$app_arg_207\ < to_signed(-8388608,48);

  \c$case_alt_82\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_75\ else
                     resize(\c$app_arg_207\,24);

  result_selection_res_82 <= \c$app_arg_207\ > to_signed(8388607,48);

  result_160 <= to_signed(8388607,24) when result_selection_res_82 else
                \c$case_alt_82\;

  \c$shI_87\ <= (to_signed(7,64));

  capp_arg_207_shiftR : block
    signal sh_87 : natural;
  begin
    sh_87 <=
        -- pragma translate_off
        natural'high when (\c$shI_87\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_87\);
    \c$app_arg_207\ <= shift_right((resize((resize(x_62.Frame_sel16_fWetR,48)) * \c$app_arg_210\, 48)),sh_87)
        -- pragma translate_off
        when ((to_signed(7,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_208\ <= result_161 when \on_32\ else
                     x_62.Frame_sel0_fL;

  \c$bv_48\ <= (x_62.Frame_sel3_fGate);

  \on_32\ <= (\c$bv_48\(1 downto 1)) = std_logic_vector'("1");

  \c$case_alt_selection_res_76\ <= \c$app_arg_209\ < to_signed(-8388608,48);

  \c$case_alt_83\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_76\ else
                     resize(\c$app_arg_209\,24);

  result_selection_res_83 <= \c$app_arg_209\ > to_signed(8388607,48);

  result_161 <= to_signed(8388607,24) when result_selection_res_83 else
                \c$case_alt_83\;

  \c$shI_88\ <= (to_signed(7,64));

  capp_arg_209_shiftR : block
    signal sh_88 : natural;
  begin
    sh_88 <=
        -- pragma translate_off
        natural'high when (\c$shI_88\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_88\);
    \c$app_arg_209\ <= shift_right((resize((resize(x_62.Frame_sel15_fWetL,48)) * \c$app_arg_210\, 48)),sh_88)
        -- pragma translate_off
        when ((to_signed(7,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_210\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(level_3)))))))),48);

  \c$bv_49\ <= (x_62.Frame_sel4_fOd);

  level_3 <= unsigned((\c$bv_49\(15 downto 8)));

  -- register begin
  odToneBlendPipe_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      odToneBlendPipe <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      odToneBlendPipe <= result_162;
    end if;
  end process;
  -- register end

  with (ds1_26(971 downto 971)) select
    result_162 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                  std_logic_vector'("1" & ((std_logic_vector(result_165.Frame_sel0_fL)
                   & std_logic_vector(result_165.Frame_sel1_fR)
                   & clash_lowpass_fir_types.toSLV(result_165.Frame_sel2_fLast)
                   & result_165.Frame_sel3_fGate
                   & result_165.Frame_sel4_fOd
                   & result_165.Frame_sel5_fDist
                   & result_165.Frame_sel6_fEq
                   & result_165.Frame_sel7_fRat
                   & result_165.Frame_sel8_fAmp
                   & result_165.Frame_sel9_fAmpTone
                   & result_165.Frame_sel10_fCab
                   & result_165.Frame_sel11_fReverb
                   & std_logic_vector(result_165.Frame_sel12_fAddr)
                   & std_logic_vector(result_165.Frame_sel13_fDryL)
                   & std_logic_vector(result_165.Frame_sel14_fDryR)
                   & std_logic_vector(result_165.Frame_sel15_fWetL)
                   & std_logic_vector(result_165.Frame_sel16_fWetR)
                   & std_logic_vector(result_165.Frame_sel17_fFbL)
                   & std_logic_vector(result_165.Frame_sel18_fFbR)
                   & std_logic_vector(result_165.Frame_sel19_fEqLowL)
                   & std_logic_vector(result_165.Frame_sel20_fEqLowR)
                   & std_logic_vector(result_165.Frame_sel21_fEqMidL)
                   & std_logic_vector(result_165.Frame_sel22_fEqMidR)
                   & std_logic_vector(result_165.Frame_sel23_fEqHighL)
                   & std_logic_vector(result_165.Frame_sel24_fEqHighR)
                   & std_logic_vector(result_165.Frame_sel25_fEqHighLpL)
                   & std_logic_vector(result_165.Frame_sel26_fEqHighLpR)
                   & std_logic_vector(result_165.Frame_sel27_fAccL)
                   & std_logic_vector(result_165.Frame_sel28_fAccR)
                   & std_logic_vector(result_165.Frame_sel29_fAcc2L)
                   & std_logic_vector(result_165.Frame_sel30_fAcc2R)
                   & std_logic_vector(result_165.Frame_sel31_fAcc3L)
                   & std_logic_vector(result_165.Frame_sel32_fAcc3R)))) when others;

  \c$shI_89\ <= (to_signed(8,64));

  capp_arg_211_shiftR : block
    signal sh_89 : natural;
  begin
    sh_89 <=
        -- pragma translate_off
        natural'high when (\c$shI_89\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_89\);
    \c$app_arg_211\ <= shift_right((x_61.Frame_sel27_fAccL + x_61.Frame_sel29_fAcc2L),sh_89)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_77\ <= \c$app_arg_211\ < to_signed(-8388608,48);

  \c$case_alt_84\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_77\ else
                     resize(\c$app_arg_211\,24);

  result_selection_res_84 <= \c$app_arg_211\ > to_signed(8388607,48);

  result_163 <= to_signed(8388607,24) when result_selection_res_84 else
                \c$case_alt_84\;

  \c$app_arg_212\ <= result_163 when \on_33\ else
                     x_61.Frame_sel0_fL;

  \c$shI_90\ <= (to_signed(8,64));

  capp_arg_213_shiftR : block
    signal sh_90 : natural;
  begin
    sh_90 <=
        -- pragma translate_off
        natural'high when (\c$shI_90\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_90\);
    \c$app_arg_213\ <= shift_right((x_61.Frame_sel28_fAccR + x_61.Frame_sel30_fAcc2R),sh_90)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_78\ <= \c$app_arg_213\ < to_signed(-8388608,48);

  \c$case_alt_85\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_78\ else
                     resize(\c$app_arg_213\,24);

  result_selection_res_85 <= \c$app_arg_213\ > to_signed(8388607,48);

  result_164 <= to_signed(8388607,24) when result_selection_res_85 else
                \c$case_alt_85\;

  \c$app_arg_214\ <= result_164 when \on_33\ else
                     x_61.Frame_sel1_fR;

  result_165 <= ( Frame_sel0_fL => x_61.Frame_sel0_fL
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
                , Frame_sel15_fWetL => \c$app_arg_212\
                , Frame_sel16_fWetR => \c$app_arg_214\
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
                , Frame_sel27_fAccL => x_61.Frame_sel27_fAccL
                , Frame_sel28_fAccR => x_61.Frame_sel28_fAccR
                , Frame_sel29_fAcc2L => x_61.Frame_sel29_fAcc2L
                , Frame_sel30_fAcc2R => x_61.Frame_sel30_fAcc2R
                , Frame_sel31_fAcc3L => x_61.Frame_sel31_fAcc3L
                , Frame_sel32_fAcc3R => x_61.Frame_sel32_fAcc3R );

  \c$bv_50\ <= (x_61.Frame_sel3_fGate);

  \on_33\ <= (\c$bv_50\(1 downto 1)) = std_logic_vector'("1");

  x_61 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_26(970 downto 0)));

  -- register begin
  ds1_26_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_26 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_26 <= result_166;
    end if;
  end process;
  -- register end

  with (ds1_27(971 downto 971)) select
    result_166 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                  std_logic_vector'("1" & ((std_logic_vector(result_167.Frame_sel0_fL)
                   & std_logic_vector(result_167.Frame_sel1_fR)
                   & clash_lowpass_fir_types.toSLV(result_167.Frame_sel2_fLast)
                   & result_167.Frame_sel3_fGate
                   & result_167.Frame_sel4_fOd
                   & result_167.Frame_sel5_fDist
                   & result_167.Frame_sel6_fEq
                   & result_167.Frame_sel7_fRat
                   & result_167.Frame_sel8_fAmp
                   & result_167.Frame_sel9_fAmpTone
                   & result_167.Frame_sel10_fCab
                   & result_167.Frame_sel11_fReverb
                   & std_logic_vector(result_167.Frame_sel12_fAddr)
                   & std_logic_vector(result_167.Frame_sel13_fDryL)
                   & std_logic_vector(result_167.Frame_sel14_fDryR)
                   & std_logic_vector(result_167.Frame_sel15_fWetL)
                   & std_logic_vector(result_167.Frame_sel16_fWetR)
                   & std_logic_vector(result_167.Frame_sel17_fFbL)
                   & std_logic_vector(result_167.Frame_sel18_fFbR)
                   & std_logic_vector(result_167.Frame_sel19_fEqLowL)
                   & std_logic_vector(result_167.Frame_sel20_fEqLowR)
                   & std_logic_vector(result_167.Frame_sel21_fEqMidL)
                   & std_logic_vector(result_167.Frame_sel22_fEqMidR)
                   & std_logic_vector(result_167.Frame_sel23_fEqHighL)
                   & std_logic_vector(result_167.Frame_sel24_fEqHighR)
                   & std_logic_vector(result_167.Frame_sel25_fEqHighLpL)
                   & std_logic_vector(result_167.Frame_sel26_fEqHighLpR)
                   & std_logic_vector(result_167.Frame_sel27_fAccL)
                   & std_logic_vector(result_167.Frame_sel28_fAccR)
                   & std_logic_vector(result_167.Frame_sel29_fAcc2L)
                   & std_logic_vector(result_167.Frame_sel30_fAcc2R)
                   & std_logic_vector(result_167.Frame_sel31_fAcc3L)
                   & std_logic_vector(result_167.Frame_sel32_fAcc3R)))) when others;

  result_167 <= ( Frame_sel0_fL => x_63.Frame_sel0_fL
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
                , Frame_sel15_fWetL => x_63.Frame_sel15_fWetL
                , Frame_sel16_fWetR => x_63.Frame_sel16_fWetR
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
                , Frame_sel27_fAccL => \c$app_arg_219\
                , Frame_sel28_fAccR => \c$app_arg_218\
                , Frame_sel29_fAcc2L => \c$app_arg_216\
                , Frame_sel30_fAcc2R => \c$app_arg_215\
                , Frame_sel31_fAcc3L => x_63.Frame_sel31_fAcc3L
                , Frame_sel32_fAcc3R => x_63.Frame_sel32_fAcc3R );

  \c$app_arg_215\ <= resize((resize(odTonePrevR,48)) * \c$app_arg_217\, 48) when \on_34\ else
                     to_signed(0,48);

  \c$app_arg_216\ <= resize((resize(odTonePrevL,48)) * \c$app_arg_217\, 48) when \on_34\ else
                     to_signed(0,48);

  \c$app_arg_217\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(toneInv_0)))))))),48);

  toneInv_0 <= to_unsigned(255,8) - tone_0;

  \c$app_arg_218\ <= resize((resize(x_63.Frame_sel1_fR,48)) * \c$app_arg_220\, 48) when \on_34\ else
                     to_signed(0,48);

  \c$app_arg_219\ <= resize((resize(x_63.Frame_sel0_fL,48)) * \c$app_arg_220\, 48) when \on_34\ else
                     to_signed(0,48);

  \c$bv_51\ <= (x_63.Frame_sel3_fGate);

  \on_34\ <= (\c$bv_51\(1 downto 1)) = std_logic_vector'("1");

  \c$app_arg_220\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(tone_0)))))))),48);

  \c$bv_52\ <= (x_63.Frame_sel4_fOd);

  tone_0 <= unsigned((\c$bv_52\(7 downto 0)));

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
                               x_62.Frame_sel16_fWetR when others;

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
                               x_62.Frame_sel15_fWetL when others;

  x_62 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(odToneBlendPipe(970 downto 0)));

  x_63 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_27(970 downto 0)));

  -- register begin
  ds1_27_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_27 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_27 <= result_168;
    end if;
  end process;
  -- register end

  with (ds1_28(971 downto 971)) select
    result_168 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                  std_logic_vector'("1" & ((std_logic_vector(result_169.Frame_sel0_fL)
                   & std_logic_vector(result_169.Frame_sel1_fR)
                   & clash_lowpass_fir_types.toSLV(result_169.Frame_sel2_fLast)
                   & result_169.Frame_sel3_fGate
                   & result_169.Frame_sel4_fOd
                   & result_169.Frame_sel5_fDist
                   & result_169.Frame_sel6_fEq
                   & result_169.Frame_sel7_fRat
                   & result_169.Frame_sel8_fAmp
                   & result_169.Frame_sel9_fAmpTone
                   & result_169.Frame_sel10_fCab
                   & result_169.Frame_sel11_fReverb
                   & std_logic_vector(result_169.Frame_sel12_fAddr)
                   & std_logic_vector(result_169.Frame_sel13_fDryL)
                   & std_logic_vector(result_169.Frame_sel14_fDryR)
                   & std_logic_vector(result_169.Frame_sel15_fWetL)
                   & std_logic_vector(result_169.Frame_sel16_fWetR)
                   & std_logic_vector(result_169.Frame_sel17_fFbL)
                   & std_logic_vector(result_169.Frame_sel18_fFbR)
                   & std_logic_vector(result_169.Frame_sel19_fEqLowL)
                   & std_logic_vector(result_169.Frame_sel20_fEqLowR)
                   & std_logic_vector(result_169.Frame_sel21_fEqMidL)
                   & std_logic_vector(result_169.Frame_sel22_fEqMidR)
                   & std_logic_vector(result_169.Frame_sel23_fEqHighL)
                   & std_logic_vector(result_169.Frame_sel24_fEqHighR)
                   & std_logic_vector(result_169.Frame_sel25_fEqHighLpL)
                   & std_logic_vector(result_169.Frame_sel26_fEqHighLpR)
                   & std_logic_vector(result_169.Frame_sel27_fAccL)
                   & std_logic_vector(result_169.Frame_sel28_fAccR)
                   & std_logic_vector(result_169.Frame_sel29_fAcc2L)
                   & std_logic_vector(result_169.Frame_sel30_fAcc2R)
                   & std_logic_vector(result_169.Frame_sel31_fAcc3L)
                   & std_logic_vector(result_169.Frame_sel32_fAcc3R)))) when others;

  \c$bv_53\ <= (x_64.Frame_sel3_fGate);

  \on_35\ <= (\c$bv_53\(1 downto 1)) = std_logic_vector'("1");

  result_169 <= ( Frame_sel0_fL => \c$app_arg_225\
                , Frame_sel1_fR => \c$app_arg_221\
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
                , Frame_sel27_fAccL => x_64.Frame_sel27_fAccL
                , Frame_sel28_fAccR => x_64.Frame_sel28_fAccR
                , Frame_sel29_fAcc2L => x_64.Frame_sel29_fAcc2L
                , Frame_sel30_fAcc2R => x_64.Frame_sel30_fAcc2R
                , Frame_sel31_fAcc3L => x_64.Frame_sel31_fAcc3L
                , Frame_sel32_fAcc3R => x_64.Frame_sel32_fAcc3R );

  \c$app_arg_221\ <= result_170 when \on_35\ else
                     x_64.Frame_sel1_fR;

  result_selection_res_86 <= x_64.Frame_sel16_fWetR > to_signed(4194304,24);

  result_170 <= resize((to_signed(4194304,25) + \c$app_arg_222\),24) when result_selection_res_86 else
                \c$case_alt_86\;

  \c$case_alt_selection_res_79\ <= x_64.Frame_sel16_fWetR < to_signed(-4194304,24);

  \c$case_alt_86\ <= resize((to_signed(-4194304,25) + \c$app_arg_223\),24) when \c$case_alt_selection_res_79\ else
                     x_64.Frame_sel16_fWetR;

  \c$shI_91\ <= (to_signed(2,64));

  capp_arg_222_shiftR : block
    signal sh_91 : natural;
  begin
    sh_91 <=
        -- pragma translate_off
        natural'high when (\c$shI_91\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_91\);
    \c$app_arg_222\ <= shift_right((\c$app_arg_224\ - to_signed(4194304,25)),sh_91)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$shI_92\ <= (to_signed(2,64));

  capp_arg_223_shiftR : block
    signal sh_92 : natural;
  begin
    sh_92 <=
        -- pragma translate_off
        natural'high when (\c$shI_92\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_92\);
    \c$app_arg_223\ <= shift_right((\c$app_arg_224\ + to_signed(4194304,25)),sh_92)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_224\ <= resize(x_64.Frame_sel16_fWetR,25);

  \c$app_arg_225\ <= result_171 when \on_35\ else
                     x_64.Frame_sel0_fL;

  result_selection_res_87 <= x_64.Frame_sel15_fWetL > to_signed(4194304,24);

  result_171 <= resize((to_signed(4194304,25) + \c$app_arg_226\),24) when result_selection_res_87 else
                \c$case_alt_87\;

  \c$case_alt_selection_res_80\ <= x_64.Frame_sel15_fWetL < to_signed(-4194304,24);

  \c$case_alt_87\ <= resize((to_signed(-4194304,25) + \c$app_arg_227\),24) when \c$case_alt_selection_res_80\ else
                     x_64.Frame_sel15_fWetL;

  \c$shI_93\ <= (to_signed(2,64));

  capp_arg_226_shiftR : block
    signal sh_93 : natural;
  begin
    sh_93 <=
        -- pragma translate_off
        natural'high when (\c$shI_93\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_93\);
    \c$app_arg_226\ <= shift_right((\c$app_arg_228\ - to_signed(4194304,25)),sh_93)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$shI_94\ <= (to_signed(2,64));

  capp_arg_227_shiftR : block
    signal sh_94 : natural;
  begin
    sh_94 <=
        -- pragma translate_off
        natural'high when (\c$shI_94\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_94\);
    \c$app_arg_227\ <= shift_right((\c$app_arg_228\ + to_signed(4194304,25)),sh_94)
        -- pragma translate_off
        when ((to_signed(2,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_228\ <= resize(x_64.Frame_sel15_fWetL,25);

  x_64 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_28(970 downto 0)));

  -- register begin
  ds1_28_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_28 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_28 <= result_172;
    end if;
  end process;
  -- register end

  with (ds1_29(971 downto 971)) select
    result_172 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                  std_logic_vector'("1" & ((std_logic_vector(result_175.Frame_sel0_fL)
                   & std_logic_vector(result_175.Frame_sel1_fR)
                   & clash_lowpass_fir_types.toSLV(result_175.Frame_sel2_fLast)
                   & result_175.Frame_sel3_fGate
                   & result_175.Frame_sel4_fOd
                   & result_175.Frame_sel5_fDist
                   & result_175.Frame_sel6_fEq
                   & result_175.Frame_sel7_fRat
                   & result_175.Frame_sel8_fAmp
                   & result_175.Frame_sel9_fAmpTone
                   & result_175.Frame_sel10_fCab
                   & result_175.Frame_sel11_fReverb
                   & std_logic_vector(result_175.Frame_sel12_fAddr)
                   & std_logic_vector(result_175.Frame_sel13_fDryL)
                   & std_logic_vector(result_175.Frame_sel14_fDryR)
                   & std_logic_vector(result_175.Frame_sel15_fWetL)
                   & std_logic_vector(result_175.Frame_sel16_fWetR)
                   & std_logic_vector(result_175.Frame_sel17_fFbL)
                   & std_logic_vector(result_175.Frame_sel18_fFbR)
                   & std_logic_vector(result_175.Frame_sel19_fEqLowL)
                   & std_logic_vector(result_175.Frame_sel20_fEqLowR)
                   & std_logic_vector(result_175.Frame_sel21_fEqMidL)
                   & std_logic_vector(result_175.Frame_sel22_fEqMidR)
                   & std_logic_vector(result_175.Frame_sel23_fEqHighL)
                   & std_logic_vector(result_175.Frame_sel24_fEqHighR)
                   & std_logic_vector(result_175.Frame_sel25_fEqHighLpL)
                   & std_logic_vector(result_175.Frame_sel26_fEqHighLpR)
                   & std_logic_vector(result_175.Frame_sel27_fAccL)
                   & std_logic_vector(result_175.Frame_sel28_fAccR)
                   & std_logic_vector(result_175.Frame_sel29_fAcc2L)
                   & std_logic_vector(result_175.Frame_sel30_fAcc2R)
                   & std_logic_vector(result_175.Frame_sel31_fAcc3L)
                   & std_logic_vector(result_175.Frame_sel32_fAcc3R)))) when others;

  \c$shI_95\ <= (to_signed(8,64));

  capp_arg_229_shiftR : block
    signal sh_95 : natural;
  begin
    sh_95 <=
        -- pragma translate_off
        natural'high when (\c$shI_95\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_95\);
    \c$app_arg_229\ <= shift_right(x_65.Frame_sel27_fAccL,sh_95)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_81\ <= \c$app_arg_229\ < to_signed(-8388608,48);

  \c$case_alt_88\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_81\ else
                     resize(\c$app_arg_229\,24);

  result_selection_res_88 <= \c$app_arg_229\ > to_signed(8388607,48);

  result_173 <= to_signed(8388607,24) when result_selection_res_88 else
                \c$case_alt_88\;

  \c$app_arg_230\ <= result_173 when \on_36\ else
                     x_65.Frame_sel0_fL;

  \c$shI_96\ <= (to_signed(8,64));

  capp_arg_231_shiftR : block
    signal sh_96 : natural;
  begin
    sh_96 <=
        -- pragma translate_off
        natural'high when (\c$shI_96\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_96\);
    \c$app_arg_231\ <= shift_right(x_65.Frame_sel28_fAccR,sh_96)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_82\ <= \c$app_arg_231\ < to_signed(-8388608,48);

  \c$case_alt_89\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_82\ else
                     resize(\c$app_arg_231\,24);

  result_selection_res_89 <= \c$app_arg_231\ > to_signed(8388607,48);

  result_174 <= to_signed(8388607,24) when result_selection_res_89 else
                \c$case_alt_89\;

  \c$app_arg_232\ <= result_174 when \on_36\ else
                     x_65.Frame_sel1_fR;

  result_175 <= ( Frame_sel0_fL => x_65.Frame_sel0_fL
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
                , Frame_sel15_fWetL => \c$app_arg_230\
                , Frame_sel16_fWetR => \c$app_arg_232\
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

  \c$bv_54\ <= (x_65.Frame_sel3_fGate);

  \on_36\ <= (\c$bv_54\(1 downto 1)) = std_logic_vector'("1");

  x_65 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_29(970 downto 0)));

  -- register begin
  ds1_29_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_29 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_29 <= result_176;
    end if;
  end process;
  -- register end

  with (ds1_30(971 downto 971)) select
    result_176 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                  std_logic_vector'("1" & ((std_logic_vector(result_177.Frame_sel0_fL)
                   & std_logic_vector(result_177.Frame_sel1_fR)
                   & clash_lowpass_fir_types.toSLV(result_177.Frame_sel2_fLast)
                   & result_177.Frame_sel3_fGate
                   & result_177.Frame_sel4_fOd
                   & result_177.Frame_sel5_fDist
                   & result_177.Frame_sel6_fEq
                   & result_177.Frame_sel7_fRat
                   & result_177.Frame_sel8_fAmp
                   & result_177.Frame_sel9_fAmpTone
                   & result_177.Frame_sel10_fCab
                   & result_177.Frame_sel11_fReverb
                   & std_logic_vector(result_177.Frame_sel12_fAddr)
                   & std_logic_vector(result_177.Frame_sel13_fDryL)
                   & std_logic_vector(result_177.Frame_sel14_fDryR)
                   & std_logic_vector(result_177.Frame_sel15_fWetL)
                   & std_logic_vector(result_177.Frame_sel16_fWetR)
                   & std_logic_vector(result_177.Frame_sel17_fFbL)
                   & std_logic_vector(result_177.Frame_sel18_fFbR)
                   & std_logic_vector(result_177.Frame_sel19_fEqLowL)
                   & std_logic_vector(result_177.Frame_sel20_fEqLowR)
                   & std_logic_vector(result_177.Frame_sel21_fEqMidL)
                   & std_logic_vector(result_177.Frame_sel22_fEqMidR)
                   & std_logic_vector(result_177.Frame_sel23_fEqHighL)
                   & std_logic_vector(result_177.Frame_sel24_fEqHighR)
                   & std_logic_vector(result_177.Frame_sel25_fEqHighLpL)
                   & std_logic_vector(result_177.Frame_sel26_fEqHighLpR)
                   & std_logic_vector(result_177.Frame_sel27_fAccL)
                   & std_logic_vector(result_177.Frame_sel28_fAccR)
                   & std_logic_vector(result_177.Frame_sel29_fAcc2L)
                   & std_logic_vector(result_177.Frame_sel30_fAcc2R)
                   & std_logic_vector(result_177.Frame_sel31_fAcc3L)
                   & std_logic_vector(result_177.Frame_sel32_fAcc3R)))) when others;

  result_177 <= ( Frame_sel0_fL => x_66.Frame_sel0_fL
                , Frame_sel1_fR => x_66.Frame_sel1_fR
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
                , Frame_sel27_fAccL => \c$app_arg_234\
                , Frame_sel28_fAccR => \c$app_arg_233\
                , Frame_sel29_fAcc2L => x_66.Frame_sel29_fAcc2L
                , Frame_sel30_fAcc2R => x_66.Frame_sel30_fAcc2R
                , Frame_sel31_fAcc3L => x_66.Frame_sel31_fAcc3L
                , Frame_sel32_fAcc3R => x_66.Frame_sel32_fAcc3R );

  \c$app_arg_233\ <= resize((resize(x_66.Frame_sel1_fR,48)) * \c$app_arg_235\, 48) when \on_37\ else
                     to_signed(0,48);

  \c$app_arg_234\ <= resize((resize(x_66.Frame_sel0_fL,48)) * \c$app_arg_235\, 48) when \on_37\ else
                     to_signed(0,48);

  \c$bv_55\ <= (x_66.Frame_sel3_fGate);

  \on_37\ <= (\c$bv_55\(1 downto 1)) = std_logic_vector'("1");

  \c$app_arg_235\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(driveGain_1)))))))),48);

  \c$bv_56\ <= (x_66.Frame_sel4_fOd);

  driveGain_1 <= resize((to_unsigned(256,10) + (resize((resize((unsigned((\c$bv_56\(23 downto 16)))),10)) * to_unsigned(4,10), 10))),12);

  x_66 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_30(970 downto 0)));

  -- register begin
  ds1_30_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_30 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_30 <= result_178;
    end if;
  end process;
  -- register end

  with (gateLevelPipe(971 downto 971)) select
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

  \c$bv_57\ <= (x_69.Frame_sel3_fGate);

  result_selection_res_90 <= not ((\c$bv_57\(0 downto 0)) = std_logic_vector'("1"));

  result_179 <= x_69 when result_selection_res_90 else
                ( Frame_sel0_fL => result_181
                , Frame_sel1_fR => result_180
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
                , Frame_sel15_fWetL => x_69.Frame_sel15_fWetL
                , Frame_sel16_fWetR => x_69.Frame_sel16_fWetR
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

  \c$case_alt_selection_res_83\ <= \c$app_arg_236\ < to_signed(-8388608,48);

  \c$case_alt_90\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_83\ else
                     resize(\c$app_arg_236\,24);

  result_selection_res_91 <= \c$app_arg_236\ > to_signed(8388607,48);

  result_180 <= to_signed(8388607,24) when result_selection_res_91 else
                \c$case_alt_90\;

  \c$shI_97\ <= (to_signed(12,64));

  capp_arg_236_shiftR : block
    signal sh_97 : natural;
  begin
    sh_97 <=
        -- pragma translate_off
        natural'high when (\c$shI_97\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_97\);
    \c$app_arg_236\ <= shift_right((resize((resize(x_69.Frame_sel1_fR,48)) * \c$app_arg_238\, 48)),sh_97)
        -- pragma translate_off
        when ((to_signed(12,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$case_alt_selection_res_84\ <= \c$app_arg_237\ < to_signed(-8388608,48);

  \c$case_alt_91\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_84\ else
                     resize(\c$app_arg_237\,24);

  result_selection_res_92 <= \c$app_arg_237\ > to_signed(8388607,48);

  result_181 <= to_signed(8388607,24) when result_selection_res_92 else
                \c$case_alt_91\;

  \c$shI_98\ <= (to_signed(12,64));

  capp_arg_237_shiftR : block
    signal sh_98 : natural;
  begin
    sh_98 <=
        -- pragma translate_off
        natural'high when (\c$shI_98\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_98\);
    \c$app_arg_237\ <= shift_right((resize((resize(x_69.Frame_sel0_fL,48)) * \c$app_arg_238\, 48)),sh_98)
        -- pragma translate_off
        when ((to_signed(12,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_238\ <= resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(gateGain)))))))),48);

  -- register begin
  gateGain_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      gateGain <= to_unsigned(4095,12);
    elsif rising_edge(clk) then
      gateGain <= result_182;
    end if;
  end process;
  -- register end

  \c$case_alt_selection_res_85\ <= gateGain < to_unsigned(4,12);

  \c$case_alt_92\ <= to_unsigned(0,12) when \c$case_alt_selection_res_85\ else
                     gateGain - to_unsigned(4,12);

  \c$case_alt_selection_res_86\ <= gateGain > to_unsigned(3583,12);

  \c$case_alt_93\ <= to_unsigned(4095,12) when \c$case_alt_selection_res_86\ else
                     gateGain + to_unsigned(512,12);

  \c$case_alt_94\ <= \c$case_alt_93\ when gateOpen else
                     \c$case_alt_92\;

  \c$bv_58\ <= (f_2.Frame_sel3_fGate);

  \c$case_alt_selection_res_87\ <= not ((\c$bv_58\(0 downto 0)) = std_logic_vector'("1"));

  \c$case_alt_95\ <= to_unsigned(4095,12) when \c$case_alt_selection_res_87\ else
                     \c$case_alt_94\;

  f_2 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(gateLevelPipe(970 downto 0)));

  with (gateLevelPipe(971 downto 971)) select
    result_182 <= gateGain when "0",
                  \c$case_alt_95\ when others;

  -- register begin
  gateOpen_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      gateOpen <= true;
    elsif rising_edge(clk) then
      gateOpen <= result_183;
    end if;
  end process;
  -- register end

  with (gateLevelPipe(971 downto 971)) select
    result_183 <= gateOpen when "0",
                  \c$case_alt_96\ when others;

  \c$case_alt_selection_res_88\ <= not ((\c$app_arg_241\(0 downto 0)) = std_logic_vector'("1"));

  \c$case_alt_96\ <= true when \c$case_alt_selection_res_88\ else
                     result_184;

  with (closeThreshold) select
    result_184 <= true when x"000000",
                  \c$case_alt_97\ when others;

  \c$case_alt_selection_res_89\ <= gateEnv > result_185;

  \c$case_alt_97\ <= true when \c$case_alt_selection_res_89\ else
                     \c$case_alt_98\;

  \c$case_alt_selection_res_90\ <= gateEnv < closeThreshold;

  \c$case_alt_98\ <= false when \c$case_alt_selection_res_90\ else
                     gateOpen;

  x_67 <= (\c$app_arg_240\ + \c$app_arg_239\) + to_signed(65536,48);

  \c$case_alt_selection_res_91\ <= x_67 < to_signed(-8388608,48);

  \c$case_alt_99\ <= to_signed(-8388608,24) when \c$case_alt_selection_res_91\ else
                     resize(x_67,24);

  result_selection_res_93 <= x_67 > to_signed(8388607,48);

  result_185 <= to_signed(8388607,24) when result_selection_res_93 else
                \c$case_alt_99\;

  \c$shI_99\ <= (to_signed(1,64));

  capp_arg_239_shiftR : block
    signal sh_99 : natural;
  begin
    sh_99 <=
        -- pragma translate_off
        natural'high when (\c$shI_99\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_99\);
    \c$app_arg_239\ <= shift_right(\c$app_arg_240\,sh_99)
        -- pragma translate_off
        when ((to_signed(1,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  \c$app_arg_240\ <= resize(closeThreshold,48);

  \c$shI_100\ <= (to_signed(13,64));

  closeThreshold_shiftL : block
    signal sh_100 : natural;
  begin
    sh_100 <=
        -- pragma translate_off
        natural'high when (\c$shI_100\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_100\);
    closeThreshold <= shift_left((resize((signed((std_logic_vector'(std_logic_vector'(std_logic_vector'("0")) & std_logic_vector'(((std_logic_vector(x_68)))))))),24)),sh_100)
        -- pragma translate_off
        when ((to_signed(13,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  x_68 <= unsigned((\c$app_arg_241\(15 downto 8)));

  \c$app_arg_241\ <= f_3.Frame_sel3_fGate;

  f_3 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(gateLevelPipe(970 downto 0)));

  -- register begin
  gateEnv_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      gateEnv <= to_signed(0,24);
    elsif rising_edge(clk) then
      gateEnv <= result_187;
    end if;
  end process;
  -- register end

  \c$shI_101\ <= (to_signed(8,64));

  cdecay_app_arg_shiftR : block
    signal sh_101 : natural;
  begin
    sh_101 <=
        -- pragma translate_off
        natural'high when (\c$shI_101\(64-1 downto 31) /= 0) else
        -- pragma translate_on
        to_integer(\c$shI_101\);
    \c$decay_app_arg\ <= shift_right((resize(gateEnv,25)),sh_101)
        -- pragma translate_off
        when ((to_signed(8,64)) >= 0) else (others => 'X')
        -- pragma translate_on
        ;
  end block;

  result_selection_res_94 <= gateEnv > decay;

  result_186 <= gateEnv - decay when result_selection_res_94 else
                to_signed(0,24);

  \c$case_alt_selection_res_92\ <= f_4.Frame_sel15_fWetL > gateEnv;

  \c$case_alt_100\ <= f_4.Frame_sel15_fWetL when \c$case_alt_selection_res_92\ else
                      result_186;

  \c$bv_59\ <= (f_4.Frame_sel3_fGate);

  \c$case_alt_selection_res_93\ <= not ((\c$bv_59\(0 downto 0)) = std_logic_vector'("1"));

  \c$case_alt_101\ <= to_signed(0,24) when \c$case_alt_selection_res_93\ else
                      \c$case_alt_100\;

  f_4 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(gateLevelPipe(970 downto 0)));

  decay <= resize((\c$decay_app_arg\ + to_signed(1,25)),24);

  with (gateLevelPipe(971 downto 971)) select
    result_187 <= gateEnv when "0",
                  \c$case_alt_101\ when others;

  x_69 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(gateLevelPipe(970 downto 0)));

  -- register begin
  gateLevelPipe_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      gateLevelPipe <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      gateLevelPipe <= result_188;
    end if;
  end process;
  -- register end

  with (ds1_31(971 downto 971)) select
    result_188 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------") when "0",
                  std_logic_vector'("1" & ((std_logic_vector(\c$case_alt_102\.Frame_sel0_fL)
                   & std_logic_vector(\c$case_alt_102\.Frame_sel1_fR)
                   & clash_lowpass_fir_types.toSLV(\c$case_alt_102\.Frame_sel2_fLast)
                   & \c$case_alt_102\.Frame_sel3_fGate
                   & \c$case_alt_102\.Frame_sel4_fOd
                   & \c$case_alt_102\.Frame_sel5_fDist
                   & \c$case_alt_102\.Frame_sel6_fEq
                   & \c$case_alt_102\.Frame_sel7_fRat
                   & \c$case_alt_102\.Frame_sel8_fAmp
                   & \c$case_alt_102\.Frame_sel9_fAmpTone
                   & \c$case_alt_102\.Frame_sel10_fCab
                   & \c$case_alt_102\.Frame_sel11_fReverb
                   & std_logic_vector(\c$case_alt_102\.Frame_sel12_fAddr)
                   & std_logic_vector(\c$case_alt_102\.Frame_sel13_fDryL)
                   & std_logic_vector(\c$case_alt_102\.Frame_sel14_fDryR)
                   & std_logic_vector(\c$case_alt_102\.Frame_sel15_fWetL)
                   & std_logic_vector(\c$case_alt_102\.Frame_sel16_fWetR)
                   & std_logic_vector(\c$case_alt_102\.Frame_sel17_fFbL)
                   & std_logic_vector(\c$case_alt_102\.Frame_sel18_fFbR)
                   & std_logic_vector(\c$case_alt_102\.Frame_sel19_fEqLowL)
                   & std_logic_vector(\c$case_alt_102\.Frame_sel20_fEqLowR)
                   & std_logic_vector(\c$case_alt_102\.Frame_sel21_fEqMidL)
                   & std_logic_vector(\c$case_alt_102\.Frame_sel22_fEqMidR)
                   & std_logic_vector(\c$case_alt_102\.Frame_sel23_fEqHighL)
                   & std_logic_vector(\c$case_alt_102\.Frame_sel24_fEqHighR)
                   & std_logic_vector(\c$case_alt_102\.Frame_sel25_fEqHighLpL)
                   & std_logic_vector(\c$case_alt_102\.Frame_sel26_fEqHighLpR)
                   & std_logic_vector(\c$case_alt_102\.Frame_sel27_fAccL)
                   & std_logic_vector(\c$case_alt_102\.Frame_sel28_fAccR)
                   & std_logic_vector(\c$case_alt_102\.Frame_sel29_fAcc2L)
                   & std_logic_vector(\c$case_alt_102\.Frame_sel30_fAcc2R)
                   & std_logic_vector(\c$case_alt_102\.Frame_sel31_fAcc3L)
                   & std_logic_vector(\c$case_alt_102\.Frame_sel32_fAcc3R)))) when others;

  result_selection_res_95 <= result_191 > result_190;

  result_189 <= result_191 when result_selection_res_95 else
                result_190;

  \c$case_alt_102\ <= ( Frame_sel0_fL => x_70.Frame_sel0_fL
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
                      , Frame_sel15_fWetL => result_189
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
                      , Frame_sel27_fAccL => x_70.Frame_sel27_fAccL
                      , Frame_sel28_fAccR => x_70.Frame_sel28_fAccR
                      , Frame_sel29_fAcc2L => x_70.Frame_sel29_fAcc2L
                      , Frame_sel30_fAcc2R => x_70.Frame_sel30_fAcc2R
                      , Frame_sel31_fAcc3L => x_70.Frame_sel31_fAcc3L
                      , Frame_sel32_fAcc3R => x_70.Frame_sel32_fAcc3R );

  \c$case_alt_selection_res_94\ <= x_70.Frame_sel1_fR < to_signed(0,24);

  \c$case_alt_103\ <= -x_70.Frame_sel1_fR when \c$case_alt_selection_res_94\ else
                      x_70.Frame_sel1_fR;

  result_selection_res_96 <= x_70.Frame_sel1_fR = to_signed(-8388608,24);

  result_190 <= to_signed(8388607,24) when result_selection_res_96 else
                \c$case_alt_103\;

  \c$case_alt_selection_res_95\ <= x_70.Frame_sel0_fL < to_signed(0,24);

  \c$case_alt_104\ <= -x_70.Frame_sel0_fL when \c$case_alt_selection_res_95\ else
                      x_70.Frame_sel0_fL;

  result_selection_res_97 <= x_70.Frame_sel0_fL = to_signed(-8388608,24);

  result_191 <= to_signed(8388607,24) when result_selection_res_97 else
                \c$case_alt_104\;

  x_70 <= clash_lowpass_fir_types.Frame'(clash_lowpass_fir_types.fromSLV(ds1_31(970 downto 0)));

  -- register begin
  ds1_31_register : process(clk,aresetn)
  begin
    if aresetn =  '0'  then
      ds1_31 <= std_logic_vector'("0" & "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
    elsif rising_edge(clk) then
      ds1_31 <= result_193;
    end if;
  end process;
  -- register end

  validIn <= axis_in_tvalid and axis_out_tready;

  right <= result_192.Tuple2_0_sel1_signed_1;

  left <= result_192.Tuple2_0_sel0_signed_0;

  result_192 <= ( Tuple2_0_sel0_signed_0 => signed((\c$app_arg_242\(23 downto 0)))
                , Tuple2_0_sel1_signed_1 => signed((\c$app_arg_242\(47 downto 24))) );

  \c$app_arg_242\ <= axis_in_tdata;

  result_193 <= std_logic_vector'("1" & ((std_logic_vector(left)
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
