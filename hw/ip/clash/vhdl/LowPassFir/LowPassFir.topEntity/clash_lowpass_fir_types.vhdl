library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package clash_lowpass_fir_types is
  subtype en_AudioDomain is boolean;

  subtype rst_AudioDomain is std_logic;
  subtype clk_AudioDomain is std_logic;

  type Tup4 is record
    Tup4_sel0_std_logic_vector : std_logic_vector(47 downto 0);
    Tup4_sel1_boolean_0 : boolean;
    Tup4_sel2_boolean_1 : boolean;
    Tup4_sel3_boolean_2 : boolean;
  end record;

  type Tup2 is record
    Tup2_sel0_signed_0 : signed(23 downto 0);
    Tup2_sel1_signed_1 : signed(23 downto 0);
  end record;
  type Tup2_0 is record
    Tup2_0_sel0_std_logic_vector_0 : std_logic_vector(0 downto 0);
    Tup2_0_sel1_std_logic_vector_1 : std_logic_vector(23 downto 0);
  end record;
  type array_of_signed_24 is array (integer range <>) of signed(23 downto 0);
  type array_of_std_logic_vector_1 is array (integer range <>) of std_logic_vector(0 downto 0);
  type Tup2_1 is record
    Tup2_1_sel0_std_logic_vector_0 : std_logic_vector(0 downto 0);
    Tup2_1_sel1_std_logic_vector_1 : std_logic_vector(46 downto 0);
  end record;

  type array_of_std_logic is array (integer range <>) of std_logic;
  type array_of_array_of_24_std_logic is array (integer range <>) of array_of_std_logic(0 to 23);
  function toSLV (b : in boolean) return std_logic_vector;
  function fromSLV (sl : in std_logic_vector) return boolean;
  function tagToEnum (s : in signed) return boolean;
  function dataToTag (b : in boolean) return signed;
  function toSLV (slv : in std_logic_vector) return std_logic_vector;
  function fromSLV (slv : in std_logic_vector) return std_logic_vector;
  function toSLV (sl : in std_logic) return std_logic_vector;
  function fromSLV (slv : in std_logic_vector) return std_logic;
  function toSLV (p : Tup4) return std_logic_vector;
  function fromSLV (slv : in std_logic_vector) return Tup4;
  function toSLV (s : in signed) return std_logic_vector;
  function fromSLV (slv : in std_logic_vector) return signed;
  function toSLV (p : Tup2) return std_logic_vector;
  function fromSLV (slv : in std_logic_vector) return Tup2;
  function toSLV (p : Tup2_0) return std_logic_vector;
  function fromSLV (slv : in std_logic_vector) return Tup2_0;
  function toSLV (value :  array_of_signed_24) return std_logic_vector;
  function fromSLV (slv : in std_logic_vector) return array_of_signed_24;
  function toSLV (value :  array_of_std_logic_vector_1) return std_logic_vector;
  function fromSLV (slv : in std_logic_vector) return array_of_std_logic_vector_1;
  function toSLV (p : Tup2_1) return std_logic_vector;
  function fromSLV (slv : in std_logic_vector) return Tup2_1;
  function toSLV (value :  array_of_std_logic) return std_logic_vector;
  function fromSLV (slv : in std_logic_vector) return array_of_std_logic;
  function toSLV (value :  array_of_array_of_24_std_logic) return std_logic_vector;
  function fromSLV (slv : in std_logic_vector) return array_of_array_of_24_std_logic;
end;

package body clash_lowpass_fir_types is
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
  function toSLV (p : Tup4) return std_logic_vector is
  begin
    return (toSLV(p.Tup4_sel0_std_logic_vector) & toSLV(p.Tup4_sel1_boolean_0) & toSLV(p.Tup4_sel2_boolean_1) & toSLV(p.Tup4_sel3_boolean_2));
  end;
  function fromSLV (slv : in std_logic_vector) return Tup4 is
  alias islv : std_logic_vector(0 to slv'length - 1) is slv;
  begin
    return (fromSLV(islv(0 to 47)),fromSLV(islv(48 to 48)),fromSLV(islv(49 to 49)),fromSLV(islv(50 to 50)));
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
  function toSLV (p : Tup2_0) return std_logic_vector is
  begin
    return (toSLV(p.Tup2_0_sel0_std_logic_vector_0) & toSLV(p.Tup2_0_sel1_std_logic_vector_1));
  end;
  function fromSLV (slv : in std_logic_vector) return Tup2_0 is
  alias islv : std_logic_vector(0 to slv'length - 1) is slv;
  begin
    return (fromSLV(islv(0 to 0)),fromSLV(islv(1 to 24)));
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
    return (toSLV(p.Tup2_1_sel0_std_logic_vector_0) & toSLV(p.Tup2_1_sel1_std_logic_vector_1));
  end;
  function fromSLV (slv : in std_logic_vector) return Tup2_1 is
  alias islv : std_logic_vector(0 to slv'length - 1) is slv;
  begin
    return (fromSLV(islv(0 to 0)),fromSLV(islv(1 to 47)));
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
  function toSLV (value :  array_of_array_of_24_std_logic) return std_logic_vector is
    alias ivalue    : array_of_array_of_24_std_logic(1 to value'length) is value;
    variable result : std_logic_vector(1 to value'length * 24);
  begin
    for i in ivalue'range loop
      result(((i - 1) * 24) + 1 to i*24) := toSLV(ivalue(i));
    end loop;
    return result;
  end;
  function fromSLV (slv : in std_logic_vector) return array_of_array_of_24_std_logic is
    alias islv      : std_logic_vector(0 to slv'length - 1) is slv;
    variable result : array_of_array_of_24_std_logic(0 to slv'length / 24 - 1);
  begin
    for i in result'range loop
      result(i) := fromSLV(islv(i * 24 to (i+1) * 24 - 1));
    end loop;
    return result;
  end;
end;

