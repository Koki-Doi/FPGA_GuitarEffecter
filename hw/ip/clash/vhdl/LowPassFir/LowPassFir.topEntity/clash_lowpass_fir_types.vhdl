library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package clash_lowpass_fir_types is


  subtype index_2048 is unsigned(10 downto 0);

  type Tuple2_1 is record
    Tuple2_1_sel0_unsigned_0 : unsigned(15 downto 0);
    Tuple2_1_sel1_unsigned_1 : unsigned(15 downto 0);
  end record;
  type array_of_signed_10 is array (integer range <>) of signed(9 downto 0);

  type AxisOut is record
    AxisOut_sel0_oData : std_logic_vector(47 downto 0);
    AxisOut_sel1_oValid : boolean;
    AxisOut_sel2_oLast : boolean;
  end record;
  type CompTarget is record
    CompTarget_sel0_ctOn : boolean;
    CompTarget_sel1_ctTarget : unsigned(11 downto 0);
    CompTarget_sel2_ctStep : unsigned(11 downto 0);
  end record;
  subtype Maybe_1 is std_logic_vector(25 downto 0);

  type Tuple4_0 is record
    Tuple4_0_sel0_std_logic_vector : std_logic_vector(47 downto 0);
    Tuple4_0_sel1_boolean_0 : boolean;
    Tuple4_0_sel2_boolean_1 : boolean;
    Tuple4_0_sel3_boolean_2 : boolean;
  end record;
  type Tuple2 is record
    Tuple2_sel0_index_2048 : index_2048;
    Tuple2_sel1_signed : signed(23 downto 0);
  end record;
  subtype Maybe_0 is std_logic_vector(35 downto 0);
  type Tuple4 is record
    Tuple4_sel0_signed_0 : signed(23 downto 0);
    Tuple4_sel1_signed_1 : signed(23 downto 0);
    Tuple4_sel2_signed_2 : signed(23 downto 0);
    Tuple4_sel3_signed_3 : signed(23 downto 0);
  end record;
  subtype rst_AudioDomain is std_logic;
  subtype clk_AudioDomain is std_logic;
  type array_of_signed_24 is array (integer range <>) of signed(23 downto 0);
  type Tuple2_7 is record
    Tuple2_7_sel0_array_of_signed_24_0 : array_of_signed_24(0 to 11);
    Tuple2_7_sel1_array_of_signed_24_1 : array_of_signed_24(0 to 0);
  end record;
  type Tuple2_6 is record
    Tuple2_6_sel0_array_of_signed_24_0 : array_of_signed_24(0 to 15);
    Tuple2_6_sel1_array_of_signed_24_1 : array_of_signed_24(0 to 0);
  end record;
  type Tuple2_5 is record
    Tuple2_5_sel0_array_of_signed_24_0 : array_of_signed_24(0 to 13);
    Tuple2_5_sel1_array_of_signed_24_1 : array_of_signed_24(0 to 0);
  end record;
  type Tuple2_3 is record
    Tuple2_3_sel0_array_of_signed_24_0 : array_of_signed_24(0 to 255);
    Tuple2_3_sel1_array_of_signed_24_1 : array_of_signed_24(0 to 0);
  end record;
  type Tuple2_4 is record
    Tuple2_4_sel0_array_of_signed_24_0 : array_of_signed_24(0 to 127);
    Tuple2_4_sel1_array_of_signed_24_1 : array_of_signed_24(0 to 0);
  end record;
  type Tuple2_2 is record
    Tuple2_2_sel0_signed_0 : signed(23 downto 0);
    Tuple2_2_sel1_signed_1 : signed(23 downto 0);
  end record;
  type Tuple2_0 is record
    Tuple2_0_sel0_signed_0 : signed(15 downto 0);
    Tuple2_0_sel1_signed_1 : signed(15 downto 0);
  end record;
  type Tuple3 is record
    Tuple3_sel0_signed_0 : signed(15 downto 0);
    Tuple3_sel1_signed_1 : signed(15 downto 0);
    Tuple3_sel2_signed_2 : signed(15 downto 0);
  end record;
  type Frame is record
    Frame_sel0_fL : signed(23 downto 0);
    Frame_sel1_fR : signed(23 downto 0);
    Frame_sel2_fLast : boolean;
    Frame_sel3_fGate : std_logic_vector(31 downto 0);
    Frame_sel4_fOd : std_logic_vector(31 downto 0);
    Frame_sel5_fDist : std_logic_vector(31 downto 0);
    Frame_sel6_fEq : std_logic_vector(31 downto 0);
    Frame_sel7_fRat : std_logic_vector(31 downto 0);
    Frame_sel8_fAmp : std_logic_vector(31 downto 0);
    Frame_sel9_fAmpTone : std_logic_vector(31 downto 0);
    Frame_sel10_fCab : std_logic_vector(31 downto 0);
    Frame_sel11_fReverb : std_logic_vector(31 downto 0);
    Frame_sel12_fNs : std_logic_vector(31 downto 0);
    Frame_sel13_fComp : std_logic_vector(31 downto 0);
    Frame_sel14_fWah : std_logic_vector(31 downto 0);
    Frame_sel15_fAddr : index_2048;
    Frame_sel16_fDryL : signed(23 downto 0);
    Frame_sel17_fDryR : signed(23 downto 0);
    Frame_sel18_fWetL : signed(23 downto 0);
    Frame_sel19_fWetR : signed(23 downto 0);
    Frame_sel20_fFbL : signed(23 downto 0);
    Frame_sel21_fFbR : signed(23 downto 0);
    Frame_sel22_fEqLowL : signed(23 downto 0);
    Frame_sel23_fEqLowR : signed(23 downto 0);
    Frame_sel24_fEqMidL : signed(23 downto 0);
    Frame_sel25_fEqMidR : signed(23 downto 0);
    Frame_sel26_fEqHighL : signed(23 downto 0);
    Frame_sel27_fEqHighR : signed(23 downto 0);
    Frame_sel28_fEqHighLpL : signed(23 downto 0);
    Frame_sel29_fEqHighLpR : signed(23 downto 0);
    Frame_sel30_fAccL : signed(47 downto 0);
    Frame_sel31_fAccR : signed(47 downto 0);
    Frame_sel32_fAcc2L : signed(47 downto 0);
    Frame_sel33_fAcc2R : signed(47 downto 0);
    Frame_sel34_fAcc3L : signed(47 downto 0);
    Frame_sel35_fAcc3R : signed(47 downto 0);
  end record;
  subtype Maybe is std_logic_vector(1068 downto 0);
  type Tuple3_0 is record
    Tuple3_0_sel0_signed_0 : signed(47 downto 0);
    Tuple3_0_sel1_signed_1 : signed(47 downto 0);
    Tuple3_0_sel2_signed_2 : signed(47 downto 0);
  end record;
  function toSLV (s : in signed) return std_logic_vector;
  function fromSLV (slv : in std_logic_vector) return signed;
  function toSLV (slv : in std_logic_vector) return std_logic_vector;
  function fromSLV (slv : in std_logic_vector) return std_logic_vector;
  function toSLV (u : in unsigned) return std_logic_vector;
  function fromSLV (slv : in std_logic_vector) return unsigned;
  function toSLV (p : Tuple2_1) return std_logic_vector;
  function fromSLV (slv : in std_logic_vector) return Tuple2_1;
  function toSLV (value :  array_of_signed_10) return std_logic_vector;
  function fromSLV (slv : in std_logic_vector) return array_of_signed_10;
  function toSLV (b : in boolean) return std_logic_vector;
  function fromSLV (sl : in std_logic_vector) return boolean;
  function tagToEnum (s : in signed) return boolean;
  function dataToTag (b : in boolean) return signed;
  function toSLV (p : AxisOut) return std_logic_vector;
  function fromSLV (slv : in std_logic_vector) return AxisOut;
  function toSLV (p : CompTarget) return std_logic_vector;
  function fromSLV (slv : in std_logic_vector) return CompTarget;
  function toSLV (sl : in std_logic) return std_logic_vector;
  function fromSLV (slv : in std_logic_vector) return std_logic;
  function toSLV (p : Tuple4_0) return std_logic_vector;
  function fromSLV (slv : in std_logic_vector) return Tuple4_0;
  function toSLV (p : Tuple2) return std_logic_vector;
  function fromSLV (slv : in std_logic_vector) return Tuple2;
  function toSLV (p : Tuple4) return std_logic_vector;
  function fromSLV (slv : in std_logic_vector) return Tuple4;
  function toSLV (value :  array_of_signed_24) return std_logic_vector;
  function fromSLV (slv : in std_logic_vector) return array_of_signed_24;
  function toSLV (p : Tuple2_7) return std_logic_vector;
  function fromSLV (slv : in std_logic_vector) return Tuple2_7;
  function toSLV (p : Tuple2_6) return std_logic_vector;
  function fromSLV (slv : in std_logic_vector) return Tuple2_6;
  function toSLV (p : Tuple2_5) return std_logic_vector;
  function fromSLV (slv : in std_logic_vector) return Tuple2_5;
  function toSLV (p : Tuple2_3) return std_logic_vector;
  function fromSLV (slv : in std_logic_vector) return Tuple2_3;
  function toSLV (p : Tuple2_4) return std_logic_vector;
  function fromSLV (slv : in std_logic_vector) return Tuple2_4;
  function toSLV (p : Tuple2_2) return std_logic_vector;
  function fromSLV (slv : in std_logic_vector) return Tuple2_2;
  function toSLV (p : Tuple2_0) return std_logic_vector;
  function fromSLV (slv : in std_logic_vector) return Tuple2_0;
  function toSLV (p : Tuple3) return std_logic_vector;
  function fromSLV (slv : in std_logic_vector) return Tuple3;
  function toSLV (p : Frame) return std_logic_vector;
  function fromSLV (slv : in std_logic_vector) return Frame;
  function toSLV (p : Tuple3_0) return std_logic_vector;
  function fromSLV (slv : in std_logic_vector) return Tuple3_0;
end;

package body clash_lowpass_fir_types is
  function toSLV (s : in signed) return std_logic_vector is
  begin
    return std_logic_vector(s);
  end;
  function fromSLV (slv : in std_logic_vector) return signed is
    alias islv : std_logic_vector(0 to slv'length - 1) is slv;
  begin
    return signed(islv);
  end;
  function toSLV (slv : in std_logic_vector) return std_logic_vector is
  begin
    return slv;
  end;
  function fromSLV (slv : in std_logic_vector) return std_logic_vector is
  begin
    return slv;
  end;
  function toSLV (u : in unsigned) return std_logic_vector is
  begin
    return std_logic_vector(u);
  end;
  function fromSLV (slv : in std_logic_vector) return unsigned is
    alias islv : std_logic_vector(0 to slv'length - 1) is slv;
  begin
    return unsigned(islv);
  end;
  function toSLV (p : Tuple2_1) return std_logic_vector is
  begin
    return (toSLV(p.Tuple2_1_sel0_unsigned_0) & toSLV(p.Tuple2_1_sel1_unsigned_1));
  end;
  function fromSLV (slv : in std_logic_vector) return Tuple2_1 is
  alias islv : std_logic_vector(0 to slv'length - 1) is slv;
  begin
    return (fromSLV(islv(0 to 15)),fromSLV(islv(16 to 31)));
  end;
  function toSLV (value :  array_of_signed_10) return std_logic_vector is
    alias ivalue    : array_of_signed_10(1 to value'length) is value;
    variable result : std_logic_vector(1 to value'length * 10);
  begin
    for i in ivalue'range loop
      result(((i - 1) * 10) + 1 to i*10) := toSLV(ivalue(i));
    end loop;
    return result;
  end;
  function fromSLV (slv : in std_logic_vector) return array_of_signed_10 is
    alias islv      : std_logic_vector(0 to slv'length - 1) is slv;
    variable result : array_of_signed_10(0 to slv'length / 10 - 1);
  begin
    for i in result'range loop
      result(i) := fromSLV(islv(i * 10 to (i+1) * 10 - 1));
    end loop;
    return result;
  end;
  function toSLV (b : in boolean) return std_logic_vector is
  begin
    if b then
      return "1";
    else
      return "0";
    end if;
  end;
  function fromSLV (sl : in std_logic_vector) return boolean is
  begin
    if sl = "1" then
      return true;
    else
      return false;
    end if;
  end;
  function tagToEnum (s : in signed) return boolean is
  begin
    if s = to_signed(0,64) then
      return false;
    else
      return true;
    end if;
  end;
  function dataToTag (b : in boolean) return signed is
  begin
    if b then
      return to_signed(1,64);
    else
      return to_signed(0,64);
    end if;
  end;
  function toSLV (p : AxisOut) return std_logic_vector is
  begin
    return (toSLV(p.AxisOut_sel0_oData) & toSLV(p.AxisOut_sel1_oValid) & toSLV(p.AxisOut_sel2_oLast));
  end;
  function fromSLV (slv : in std_logic_vector) return AxisOut is
  alias islv : std_logic_vector(0 to slv'length - 1) is slv;
  begin
    return (fromSLV(islv(0 to 47)),fromSLV(islv(48 to 48)),fromSLV(islv(49 to 49)));
  end;
  function toSLV (p : CompTarget) return std_logic_vector is
  begin
    return (toSLV(p.CompTarget_sel0_ctOn) & toSLV(p.CompTarget_sel1_ctTarget) & toSLV(p.CompTarget_sel2_ctStep));
  end;
  function fromSLV (slv : in std_logic_vector) return CompTarget is
  alias islv : std_logic_vector(0 to slv'length - 1) is slv;
  begin
    return (fromSLV(islv(0 to 0)),fromSLV(islv(1 to 12)),fromSLV(islv(13 to 24)));
  end;
  function toSLV (sl : in std_logic) return std_logic_vector is
  begin
    return std_logic_vector'(0 => sl);
  end;
  function fromSLV (slv : in std_logic_vector) return std_logic is
    alias islv : std_logic_vector (0 to slv'length - 1) is slv;
  begin
    return islv(0);
  end;
  function toSLV (p : Tuple4_0) return std_logic_vector is
  begin
    return (toSLV(p.Tuple4_0_sel0_std_logic_vector) & toSLV(p.Tuple4_0_sel1_boolean_0) & toSLV(p.Tuple4_0_sel2_boolean_1) & toSLV(p.Tuple4_0_sel3_boolean_2));
  end;
  function fromSLV (slv : in std_logic_vector) return Tuple4_0 is
  alias islv : std_logic_vector(0 to slv'length - 1) is slv;
  begin
    return (fromSLV(islv(0 to 47)),fromSLV(islv(48 to 48)),fromSLV(islv(49 to 49)),fromSLV(islv(50 to 50)));
  end;
  function toSLV (p : Tuple2) return std_logic_vector is
  begin
    return (toSLV(p.Tuple2_sel0_index_2048) & toSLV(p.Tuple2_sel1_signed));
  end;
  function fromSLV (slv : in std_logic_vector) return Tuple2 is
  alias islv : std_logic_vector(0 to slv'length - 1) is slv;
  begin
    return (fromSLV(islv(0 to 10)),fromSLV(islv(11 to 34)));
  end;
  function toSLV (p : Tuple4) return std_logic_vector is
  begin
    return (toSLV(p.Tuple4_sel0_signed_0) & toSLV(p.Tuple4_sel1_signed_1) & toSLV(p.Tuple4_sel2_signed_2) & toSLV(p.Tuple4_sel3_signed_3));
  end;
  function fromSLV (slv : in std_logic_vector) return Tuple4 is
  alias islv : std_logic_vector(0 to slv'length - 1) is slv;
  begin
    return (fromSLV(islv(0 to 23)),fromSLV(islv(24 to 47)),fromSLV(islv(48 to 71)),fromSLV(islv(72 to 95)));
  end;
  function toSLV (value :  array_of_signed_24) return std_logic_vector is
    alias ivalue    : array_of_signed_24(1 to value'length) is value;
    variable result : std_logic_vector(1 to value'length * 24);
  begin
    for i in ivalue'range loop
      result(((i - 1) * 24) + 1 to i*24) := toSLV(ivalue(i));
    end loop;
    return result;
  end;
  function fromSLV (slv : in std_logic_vector) return array_of_signed_24 is
    alias islv      : std_logic_vector(0 to slv'length - 1) is slv;
    variable result : array_of_signed_24(0 to slv'length / 24 - 1);
  begin
    for i in result'range loop
      result(i) := fromSLV(islv(i * 24 to (i+1) * 24 - 1));
    end loop;
    return result;
  end;
  function toSLV (p : Tuple2_7) return std_logic_vector is
  begin
    return (toSLV(p.Tuple2_7_sel0_array_of_signed_24_0) & toSLV(p.Tuple2_7_sel1_array_of_signed_24_1));
  end;
  function fromSLV (slv : in std_logic_vector) return Tuple2_7 is
  alias islv : std_logic_vector(0 to slv'length - 1) is slv;
  begin
    return (fromSLV(islv(0 to 287)),fromSLV(islv(288 to 311)));
  end;
  function toSLV (p : Tuple2_6) return std_logic_vector is
  begin
    return (toSLV(p.Tuple2_6_sel0_array_of_signed_24_0) & toSLV(p.Tuple2_6_sel1_array_of_signed_24_1));
  end;
  function fromSLV (slv : in std_logic_vector) return Tuple2_6 is
  alias islv : std_logic_vector(0 to slv'length - 1) is slv;
  begin
    return (fromSLV(islv(0 to 383)),fromSLV(islv(384 to 407)));
  end;
  function toSLV (p : Tuple2_5) return std_logic_vector is
  begin
    return (toSLV(p.Tuple2_5_sel0_array_of_signed_24_0) & toSLV(p.Tuple2_5_sel1_array_of_signed_24_1));
  end;
  function fromSLV (slv : in std_logic_vector) return Tuple2_5 is
  alias islv : std_logic_vector(0 to slv'length - 1) is slv;
  begin
    return (fromSLV(islv(0 to 335)),fromSLV(islv(336 to 359)));
  end;
  function toSLV (p : Tuple2_3) return std_logic_vector is
  begin
    return (toSLV(p.Tuple2_3_sel0_array_of_signed_24_0) & toSLV(p.Tuple2_3_sel1_array_of_signed_24_1));
  end;
  function fromSLV (slv : in std_logic_vector) return Tuple2_3 is
  alias islv : std_logic_vector(0 to slv'length - 1) is slv;
  begin
    return (fromSLV(islv(0 to 6143)),fromSLV(islv(6144 to 6167)));
  end;
  function toSLV (p : Tuple2_4) return std_logic_vector is
  begin
    return (toSLV(p.Tuple2_4_sel0_array_of_signed_24_0) & toSLV(p.Tuple2_4_sel1_array_of_signed_24_1));
  end;
  function fromSLV (slv : in std_logic_vector) return Tuple2_4 is
  alias islv : std_logic_vector(0 to slv'length - 1) is slv;
  begin
    return (fromSLV(islv(0 to 3071)),fromSLV(islv(3072 to 3095)));
  end;
  function toSLV (p : Tuple2_2) return std_logic_vector is
  begin
    return (toSLV(p.Tuple2_2_sel0_signed_0) & toSLV(p.Tuple2_2_sel1_signed_1));
  end;
  function fromSLV (slv : in std_logic_vector) return Tuple2_2 is
  alias islv : std_logic_vector(0 to slv'length - 1) is slv;
  begin
    return (fromSLV(islv(0 to 23)),fromSLV(islv(24 to 47)));
  end;
  function toSLV (p : Tuple2_0) return std_logic_vector is
  begin
    return (toSLV(p.Tuple2_0_sel0_signed_0) & toSLV(p.Tuple2_0_sel1_signed_1));
  end;
  function fromSLV (slv : in std_logic_vector) return Tuple2_0 is
  alias islv : std_logic_vector(0 to slv'length - 1) is slv;
  begin
    return (fromSLV(islv(0 to 15)),fromSLV(islv(16 to 31)));
  end;
  function toSLV (p : Tuple3) return std_logic_vector is
  begin
    return (toSLV(p.Tuple3_sel0_signed_0) & toSLV(p.Tuple3_sel1_signed_1) & toSLV(p.Tuple3_sel2_signed_2));
  end;
  function fromSLV (slv : in std_logic_vector) return Tuple3 is
  alias islv : std_logic_vector(0 to slv'length - 1) is slv;
  begin
    return (fromSLV(islv(0 to 15)),fromSLV(islv(16 to 31)),fromSLV(islv(32 to 47)));
  end;
  function toSLV (p : Frame) return std_logic_vector is
  begin
    return (toSLV(p.Frame_sel0_fL) & toSLV(p.Frame_sel1_fR) & toSLV(p.Frame_sel2_fLast) & toSLV(p.Frame_sel3_fGate) & toSLV(p.Frame_sel4_fOd) & toSLV(p.Frame_sel5_fDist) & toSLV(p.Frame_sel6_fEq) & toSLV(p.Frame_sel7_fRat) & toSLV(p.Frame_sel8_fAmp) & toSLV(p.Frame_sel9_fAmpTone) & toSLV(p.Frame_sel10_fCab) & toSLV(p.Frame_sel11_fReverb) & toSLV(p.Frame_sel12_fNs) & toSLV(p.Frame_sel13_fComp) & toSLV(p.Frame_sel14_fWah) & toSLV(p.Frame_sel15_fAddr) & toSLV(p.Frame_sel16_fDryL) & toSLV(p.Frame_sel17_fDryR) & toSLV(p.Frame_sel18_fWetL) & toSLV(p.Frame_sel19_fWetR) & toSLV(p.Frame_sel20_fFbL) & toSLV(p.Frame_sel21_fFbR) & toSLV(p.Frame_sel22_fEqLowL) & toSLV(p.Frame_sel23_fEqLowR) & toSLV(p.Frame_sel24_fEqMidL) & toSLV(p.Frame_sel25_fEqMidR) & toSLV(p.Frame_sel26_fEqHighL) & toSLV(p.Frame_sel27_fEqHighR) & toSLV(p.Frame_sel28_fEqHighLpL) & toSLV(p.Frame_sel29_fEqHighLpR) & toSLV(p.Frame_sel30_fAccL) & toSLV(p.Frame_sel31_fAccR) & toSLV(p.Frame_sel32_fAcc2L) & toSLV(p.Frame_sel33_fAcc2R) & toSLV(p.Frame_sel34_fAcc3L) & toSLV(p.Frame_sel35_fAcc3R));
  end;
  function fromSLV (slv : in std_logic_vector) return Frame is
  alias islv : std_logic_vector(0 to slv'length - 1) is slv;
  begin
    return (fromSLV(islv(0 to 23)),fromSLV(islv(24 to 47)),fromSLV(islv(48 to 48)),fromSLV(islv(49 to 80)),fromSLV(islv(81 to 112)),fromSLV(islv(113 to 144)),fromSLV(islv(145 to 176)),fromSLV(islv(177 to 208)),fromSLV(islv(209 to 240)),fromSLV(islv(241 to 272)),fromSLV(islv(273 to 304)),fromSLV(islv(305 to 336)),fromSLV(islv(337 to 368)),fromSLV(islv(369 to 400)),fromSLV(islv(401 to 432)),fromSLV(islv(433 to 443)),fromSLV(islv(444 to 467)),fromSLV(islv(468 to 491)),fromSLV(islv(492 to 515)),fromSLV(islv(516 to 539)),fromSLV(islv(540 to 563)),fromSLV(islv(564 to 587)),fromSLV(islv(588 to 611)),fromSLV(islv(612 to 635)),fromSLV(islv(636 to 659)),fromSLV(islv(660 to 683)),fromSLV(islv(684 to 707)),fromSLV(islv(708 to 731)),fromSLV(islv(732 to 755)),fromSLV(islv(756 to 779)),fromSLV(islv(780 to 827)),fromSLV(islv(828 to 875)),fromSLV(islv(876 to 923)),fromSLV(islv(924 to 971)),fromSLV(islv(972 to 1019)),fromSLV(islv(1020 to 1067)));
  end;
  function toSLV (p : Tuple3_0) return std_logic_vector is
  begin
    return (toSLV(p.Tuple3_0_sel0_signed_0) & toSLV(p.Tuple3_0_sel1_signed_1) & toSLV(p.Tuple3_0_sel2_signed_2));
  end;
  function fromSLV (slv : in std_logic_vector) return Tuple3_0 is
  alias islv : std_logic_vector(0 to slv'length - 1) is slv;
  begin
    return (fromSLV(islv(0 to 47)),fromSLV(islv(48 to 95)),fromSLV(islv(96 to 143)));
  end;
end;

