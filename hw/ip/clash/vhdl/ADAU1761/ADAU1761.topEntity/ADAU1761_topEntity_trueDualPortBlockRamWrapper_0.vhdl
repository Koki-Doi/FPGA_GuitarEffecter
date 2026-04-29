-- Automatically generated VHDL-93
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;
use std.textio.all;

library work;
use work.i2s_to_stream_types.all;

library xpm;
use xpm.vcomponents.all;

entity ADAU1761_topEntity_trueDualPortBlockRamWrapper_0 is
  port(
       -- clock
       clkA   : in std_logic;
       enA    : in boolean;
       weA    : in boolean;
       addrA  : in index_4;
       datA   : in Tup2;
       -- clock
       clkB   : in std_logic;
       enB    : in boolean;
       weB    : in boolean;
       addrB  : in index_4;
       datB   : in Tup2;
       result : out Tup2_0
  );
end;

architecture structural of ADAU1761_topEntity_trueDualPortBlockRamWrapper_0 is
  signal enA_sl, weA_sl, enB_sl, weB_sl : std_logic;
  signal wea_vec, web_vec : std_logic_vector(0 downto 0);
  signal addra_slv, addrb_slv : std_logic_vector(1 downto 0);
  signal dina_slv,  dinb_slv  : std_logic_vector(47 downto 0);
  signal douta_slv, doutb_slv : std_logic_vector(47 downto 0);
  signal a_dout, b_dout : Tup2;
  constant C0 : std_logic := '0';
  constant C1 : std_logic := '1';
begin
  enA_sl <= '1' when enA else '0';
  weA_sl <= '1' when weA else '0';
  enB_sl <= '1' when enB else '0';
  weB_sl <= '1' when weB else '0';

  wea_vec(0) <= weA_sl;
  web_vec(0) <= weB_sl;

  addra_slv <= std_logic_vector(addrA);
  addrb_slv <= std_logic_vector(addrB);

  dina_slv  <= toSLV(datA);
  dinb_slv  <= toSLV(datB);

  a_dout    <= fromSLV(douta_slv);
  b_dout    <= fromSLV(doutb_slv);

  result    <= (a_dout, b_dout);

  mem_i : xpm_memory_tdpram
    generic map (
      MEMORY_SIZE        => 48*4,
      MEMORY_PRIMITIVE   => "block",
      CLOCKING_MODE      => "independent_clock",
      ECC_MODE           => "no_ecc",
      WRITE_DATA_WIDTH_A => 48,
      READ_DATA_WIDTH_A  => 48,
      BYTE_WRITE_WIDTH_A => 48,
      ADDR_WIDTH_A       => 2,
      READ_LATENCY_A     => 1,
      WRITE_MODE_A       => "read_first",
      WRITE_DATA_WIDTH_B => 48,
      READ_DATA_WIDTH_B  => 48,
      BYTE_WRITE_WIDTH_B => 48,
      ADDR_WIDTH_B       => 2,
      READ_LATENCY_B     => 1,
      WRITE_MODE_B       => "read_first"
    )
    port map (
      clka   => clkA,
      ena    => enA_sl,
      rsta   => C0,
      regcea => C1,
      wea    => wea_vec,
      addra  => addra_slv,
      dina   => dina_slv,
      douta  => douta_slv,

      clkb   => clkB,
      enb    => enB_sl,
      rstb   => C0,
      regceb => C1,
      web    => web_vec,
      addrb  => addrb_slv,
      dinb   => dinb_slv,
      doutb  => doutb_slv,

      sleep           => C0,
      injectsbiterra  => C0,
      injectdbiterra  => C0,
      injectsbiterrb  => C0,
      injectdbiterrb  => C0,
      sbiterra         => open,
      dbiterra         => open
    );

end structural;
