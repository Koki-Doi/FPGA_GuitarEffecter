-- Automatically generated VHDL-93
-- D54 hand-patch (no Clash regeneration): replaced the original
-- shared-variable BRAM template with a signal-based dual-port
-- register file. The original Clash-emitted body declared a
-- ``shared variable mem`` and rewrote it from two clocked processes;
-- Vivado 2019.1 refused to infer a dual-port BRAM from that
-- pattern in a from-scratch synth (``Unsupported Dual Port
-- Block-RAM template``). The functional contract is unchanged: the
-- two ports read/write a shared 4-entry Tup2 memory on rising edges
-- of clkA / clkB with their own enables, and ``result`` is the
-- 2-tuple ``(a_dout, b_dout)`` exactly as before. The previously
-- deployed audio_lab.bit was built when the same VHDL was already
-- cached as an OOC DCP, so this patch only takes effect on a
-- from-scratch rebuild. See DECISIONS.md D54.
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;
use std.textio.all;
use work.all;
use work.i2s_to_stream_types.all;

entity ADAU1761_topEntity_trueDualPortBlockRamWrapper_0 is
  port(-- clock
       clkA   : in std_logic;
       enA    : in boolean;
       weA    : in boolean;
       addrA  : in i2s_to_stream_types.index_4;
       datA   : in i2s_to_stream_types.Tup2;
       -- clock
       clkB   : in std_logic;
       enB    : in boolean;
       weB    : in boolean;
       addrB  : in i2s_to_stream_types.index_4;
       datB   : in i2s_to_stream_types.Tup2;
       result : out i2s_to_stream_types.Tup2_0);
end;

architecture structural of ADAU1761_topEntity_trueDualPortBlockRamWrapper_0 is

  type mem_type is array (3 downto 0) of i2s_to_stream_types.Tup2;
  signal mem    : mem_type;
  signal a_dout : i2s_to_stream_types.Tup2;
  signal b_dout : i2s_to_stream_types.Tup2;

  attribute ram_style : string;
  attribute ram_style of mem : signal is "distributed";

begin
  -- Port A
  process(clkA)
  begin
    if rising_edge(clkA) then
      if enA then
        if weA then
          mem(to_integer(addrA)) <= datA;
        end if;
        a_dout <= mem(to_integer(addrA));
      end if;
    end if;
  end process;

  -- Port B
  process(clkB)
  begin
    if rising_edge(clkB) then
      if enB then
        if weB then
          mem(to_integer(addrB)) <= datB;
        end if;
        b_dout <= mem(to_integer(addrB));
      end if;
    end if;
  end process;

  result <= (a_dout, b_dout);

end;
