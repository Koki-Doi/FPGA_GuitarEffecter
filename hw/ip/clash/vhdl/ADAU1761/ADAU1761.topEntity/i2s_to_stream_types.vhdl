library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package i2s_to_stream_types is
  subtype index_4 is unsigned(1 downto 0);


  subtype rst_I2S is std_logic;

  subtype clk_DSP is std_logic;

  type Tup2 is record
    Tup2_sel0_signed_0 : signed(23 downto 0);
    Tup2_sel1_signed_1 : signed(23 downto 0);
  end record;
  type array_of_std_logic_vector_1 is array (integer range <>) of std_logic_vector(0 downto 0);
  subtype rst_DSP is std_logic;
  type Tup2_1 is record
    Tup2_1_sel0_std_logic_vector : std_logic_vector(2 downto 0);
    Tup2_1_sel1_boolean : boolean;
  end record;
  type Tup3 is record
    Tup3_sel0_Tup2 : Tup2;
    Tup3_sel1_boolean_0 : boolean;
    Tup3_sel2_boolean_1 : boolean;
  end record;
  type Tup2_0 is record
    Tup2_0_sel0_Tup2_0 : Tup2;
    Tup2_0_sel1_Tup2_1 : Tup2;
  end record;
  type Tup3_0 is record
    Tup3_0_sel0_std_logic_vector_0 : std_logic_vector(2 downto 0);
    Tup3_0_sel1_std_logic_vector_1 : std_logic_vector(2 downto 0);
    Tup3_0_sel2_boolean : boolean;
  end record;
  subtype clk_I2S is std_logic;
  subtype RamOp is std_logic_vector(51 downto 0);
  subtype Maybe is std_logic_vector(48 downto 0);

  type array_of_std_logic is array (integer range <>) of std_logic;
  type Tup2_6 is record
    Tup2_6_sel0_array_of_std_logic_0 : array_of_std_logic(0 to 0);
    Tup2_6_sel1_array_of_std_logic_1 : array_of_std_logic(0 to 63);
  end record;
  type Tup2_5 is record
    Tup2_5_sel0_array_of_std_logic_0 : array_of_std_logic(0 to 23);
    Tup2_5_sel1_array_of_std_logic_1 : array_of_std_logic(0 to 6);
  end record;
  type Tup2_3 is record
    Tup2_3_sel0_array_of_std_logic_0 : array_of_std_logic(0 to 23);
    Tup2_3_sel1_array_of_std_logic_1 : array_of_std_logic(0 to 38);
  end record;
  type Tup2_4 is record
    Tup2_4_sel0_array_of_std_logic_0 : array_of_std_logic(0 to 32);
    Tup2_4_sel1_array_of_std_logic_1 : array_of_std_logic(0 to 30);
  end record;
  type Tup2_2 is record
    Tup2_2_sel0_array_of_std_logic_0 : array_of_std_logic(0 to 0);
    Tup2_2_sel1_array_of_std_logic_1 : array_of_std_logic(0 to 62);
  end record;
  type Tup5 is record
    Tup5_sel0_std_logic : std_logic;
    Tup5_sel1_boolean_0 : boolean;
    Tup5_sel2_std_logic_vector : std_logic_vector(47 downto 0);
    Tup5_sel3_boolean_1 : boolean;
    Tup5_sel4_boolean_2 : boolean;
  end record;
  function toSLV (u : in unsigned) return std_logic_vector;
  function fromSLV (slv : in std_logic_vector) return unsigned;
  function toSLV (slv : in std_logic_vector) return std_logic_vector;
  function fromSLV (slv : in std_logic_vector) return std_logic_vector;
  function toSLV (sl : in std_logic) return std_logic_vector;
  function fromSLV (slv : in std_logic_vector) return std_logic;
  function toSLV (b : in boolean) return std_logic_vector;
  function fromSLV (sl : in std_logic_vector) return boolean;
  function tagToEnum (s : in signed) return boolean;
  function dataToTag (b : in boolean) return signed;
  function toSLV (s : in signed) return std_logic_vector;
  function fromSLV (slv : in std_logic_vector) return signed;
  function toSLV (p : Tup2) return std_logic_vector;
  function fromSLV (slv : in std_logic_vector) return Tup2;
  function toSLV (value :  array_of_std_logic_vector_1) return std_logic_vector;
  function fromSLV (slv : in std_logic_vector) return array_of_std_logic_vector_1;
  function toSLV (p : Tup2_1) return std_logic_vector;
  function fromSLV (slv : in std_logic_vector) return Tup2_1;
  function toSLV (p : Tup3) return std_logic_vector;
  function fromSLV (slv : in std_logic_vector) return Tup3;
  function toSLV (p : Tup2_0) return std_logic_vector;
  function fromSLV (slv : in std_logic_vector) return Tup2_0;
  function toSLV (p : Tup3_0) return std_logic_vector;
  function fromSLV (slv : in std_logic_vector) return Tup3_0;
  function toSLV (value :  array_of_std_logic) return std_logic_vector;
  function fromSLV (slv : in std_logic_vector) return array_of_std_logic;
  function toSLV (p : Tup2_6) return std_logic_vector;
  function fromSLV (slv : in std_logic_vector) return Tup2_6;
  function toSLV (p : Tup2_5) return std_logic_vector;
  function fromSLV (slv : in std_logic_vector) return Tup2_5;
  function toSLV (p : Tup2_3) return std_logic_vector;
  function fromSLV (slv : in std_logic_vector) return Tup2_3;
  function toSLV (p : Tup2_4) return std_logic_vector;
  function fromSLV (slv : in std_logic_vector) return Tup2_4;
  function toSLV (p : Tup2_2) return std_logic_vector;
  function fromSLV (slv : in std_logic_vector) return Tup2_2;
  function toSLV (p : Tup5) return std_logic_vector;
  function fromSLV (slv : in std_logic_vector) return Tup5;
end;

package body i2s_to_stream_types is
  function toSLV (u : in unsigned) return std_logic_vector is
  begin
    return std_logic_vector(u);
  end;
  function fromSLV (slv : in std_logic_vector) return unsigned is
    alias islv : std_logic_vector(0 to slv'length - 1) is slv;
  begin
    return unsigned(islv);
  end;
  function toSLV (slv : in std_logic_vector) return std_logic_vector is
  begin
    return slv;
  end;
  function fromSLV (slv : in std_logic_vector) return std_logic_vector is
  begin
    return slv;
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
  function toSLV (s : in signed) return std_logic_vector is
  begin
    return std_logic_vector(s);
  end;
  function fromSLV (slv : in std_logic_vector) return signed is
    alias islv : std_logic_vector(0 to slv'length - 1) is slv;
  begin
    return signed(islv);
  end;
  function toSLV (p : Tup2) return std_logic_vector is
  begin
    return (toSLV(p.Tup2_sel0_signed_0) & toSLV(p.Tup2_sel1_signed_1));
  end;
  function fromSLV (slv : in std_logic_vector) return Tup2 is
  alias islv : std_logic_vector(0 to slv'length - 1) is slv;
  begin
    return (fromSLV(islv(0 to 23)),fromSLV(islv(24 to 47)));
  end;
  function toSLV (value :  array_of_std_logic_vector_1) return std_logic_vector is
    alias ivalue    : array_of_std_logic_vector_1(1 to value'length) is value;
    variable result : std_logic_vector(1 to value'length * 1);
  begin
    for i in ivalue'range loop
      result(((i - 1) * 1) + 1 to i*1) := toSLV(ivalue(i));
    end loop;
    return result;
  end;
  function fromSLV (slv : in std_logic_vector) return array_of_std_logic_vector_1 is
    alias islv      : std_logic_vector(0 to slv'length - 1) is slv;
    variable result : array_of_std_logic_vector_1(0 to slv'length / 1 - 1);
  begin
    for i in result'range loop
      result(i) := islv(i * 1 to (i+1) * 1 - 1);
    end loop;
    return result;
  end;
  function toSLV (p : Tup2_1) return std_logic_vector is
  begin
    return (toSLV(p.Tup2_1_sel0_std_logic_vector) & toSLV(p.Tup2_1_sel1_boolean));
  end;
  function fromSLV (slv : in std_logic_vector) return Tup2_1 is
  alias islv : std_logic_vector(0 to slv'length - 1) is slv;
  begin
    return (fromSLV(islv(0 to 2)),fromSLV(islv(3 to 3)));
  end;
  function toSLV (p : Tup3) return std_logic_vector is
  begin
    return (toSLV(p.Tup3_sel0_Tup2) & toSLV(p.Tup3_sel1_boolean_0) & toSLV(p.Tup3_sel2_boolean_1));
  end;
  function fromSLV (slv : in std_logic_vector) return Tup3 is
  alias islv : std_logic_vector(0 to slv'length - 1) is slv;
  begin
    return (fromSLV(islv(0 to 47)),fromSLV(islv(48 to 48)),fromSLV(islv(49 to 49)));
  end;
  function toSLV (p : Tup2_0) return std_logic_vector is
  begin
    return (toSLV(p.Tup2_0_sel0_Tup2_0) & toSLV(p.Tup2_0_sel1_Tup2_1));
  end;
  function fromSLV (slv : in std_logic_vector) return Tup2_0 is
  alias islv : std_logic_vector(0 to slv'length - 1) is slv;
  begin
    return (fromSLV(islv(0 to 47)),fromSLV(islv(48 to 95)));
  end;
  function toSLV (p : Tup3_0) return std_logic_vector is
  begin
    return (toSLV(p.Tup3_0_sel0_std_logic_vector_0) & toSLV(p.Tup3_0_sel1_std_logic_vector_1) & toSLV(p.Tup3_0_sel2_boolean));
  end;
  function fromSLV (slv : in std_logic_vector) return Tup3_0 is
  alias islv : std_logic_vector(0 to slv'length - 1) is slv;
  begin
    return (fromSLV(islv(0 to 2)),fromSLV(islv(3 to 5)),fromSLV(islv(6 to 6)));
  end;
  function toSLV (value :  array_of_std_logic) return std_logic_vector is
    alias ivalue    : array_of_std_logic(1 to value'length) is value;
    variable result : std_logic_vector(1 to value'length * 1);
  begin
    for i in ivalue'range loop
      result(((i - 1) * 1) + 1 to i*1) := toSLV(ivalue(i));
    end loop;
    return result;
  end;
  function fromSLV (slv : in std_logic_vector) return array_of_std_logic is
    alias islv      : std_logic_vector(0 to slv'length - 1) is slv;
    variable result : array_of_std_logic(0 to slv'length / 1 - 1);
  begin
    for i in result'range loop
      result(i) := fromSLV(islv(i * 1 to (i+1) * 1 - 1));
    end loop;
    return result;
  end;
  function toSLV (p : Tup2_6) return std_logic_vector is
  begin
    return (toSLV(p.Tup2_6_sel0_array_of_std_logic_0) & toSLV(p.Tup2_6_sel1_array_of_std_logic_1));
  end;
  function fromSLV (slv : in std_logic_vector) return Tup2_6 is
  alias islv : std_logic_vector(0 to slv'length - 1) is slv;
  begin
    return (fromSLV(islv(0 to 0)),fromSLV(islv(1 to 64)));
  end;
  function toSLV (p : Tup2_5) return std_logic_vector is
  begin
    return (toSLV(p.Tup2_5_sel0_array_of_std_logic_0) & toSLV(p.Tup2_5_sel1_array_of_std_logic_1));
  end;
  function fromSLV (slv : in std_logic_vector) return Tup2_5 is
  alias islv : std_logic_vector(0 to slv'length - 1) is slv;
  begin
    return (fromSLV(islv(0 to 23)),fromSLV(islv(24 to 30)));
  end;
  function toSLV (p : Tup2_3) return std_logic_vector is
  begin
    return (toSLV(p.Tup2_3_sel0_array_of_std_logic_0) & toSLV(p.Tup2_3_sel1_array_of_std_logic_1));
  end;
  function fromSLV (slv : in std_logic_vector) return Tup2_3 is
  alias islv : std_logic_vector(0 to slv'length - 1) is slv;
  begin
    return (fromSLV(islv(0 to 23)),fromSLV(islv(24 to 62)));
  end;
  function toSLV (p : Tup2_4) return std_logic_vector is
  begin
    return (toSLV(p.Tup2_4_sel0_array_of_std_logic_0) & toSLV(p.Tup2_4_sel1_array_of_std_logic_1));
  end;
  function fromSLV (slv : in std_logic_vector) return Tup2_4 is
  alias islv : std_logic_vector(0 to slv'length - 1) is slv;
  begin
    return (fromSLV(islv(0 to 32)),fromSLV(islv(33 to 63)));
  end;
  function toSLV (p : Tup2_2) return std_logic_vector is
  begin
    return (toSLV(p.Tup2_2_sel0_array_of_std_logic_0) & toSLV(p.Tup2_2_sel1_array_of_std_logic_1));
  end;
  function fromSLV (slv : in std_logic_vector) return Tup2_2 is
  alias islv : std_logic_vector(0 to slv'length - 1) is slv;
  begin
    return (fromSLV(islv(0 to 0)),fromSLV(islv(1 to 63)));
  end;
  function toSLV (p : Tup5) return std_logic_vector is
  begin
    return (toSLV(p.Tup5_sel0_std_logic) & toSLV(p.Tup5_sel1_boolean_0) & toSLV(p.Tup5_sel2_std_logic_vector) & toSLV(p.Tup5_sel3_boolean_1) & toSLV(p.Tup5_sel4_boolean_2));
  end;
  function fromSLV (slv : in std_logic_vector) return Tup5 is
  alias islv : std_logic_vector(0 to slv'length - 1) is slv;
  begin
    return (fromSLV(islv(0 to 0)),fromSLV(islv(1 to 1)),fromSLV(islv(2 to 49)),fromSLV(islv(50 to 50)),fromSLV(islv(51 to 51)));
  end;
end;

