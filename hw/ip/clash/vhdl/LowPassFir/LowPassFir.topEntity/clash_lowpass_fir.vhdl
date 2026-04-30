library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity clash_lowpass_fir is
  port(
       clk             : in std_logic;
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

architecture rtl of clash_lowpass_fir is
  constant DELAY_LEN : integer := 4096;
  constant ADDR_LAST : integer := DELAY_LEN - 1;

  subtype sample_t is signed(23 downto 0);
  subtype calc_t is signed(24 downto 0);
  type delay_ram_t is array (0 to DELAY_LEN - 1) of sample_t;

  signal delay_l : delay_ram_t := (others => (others => '0'));
  signal delay_r : delay_ram_t := (others => (others => '0'));
  attribute ram_style : string;
  attribute ram_style of delay_l : signal is "block";
  attribute ram_style of delay_r : signal is "block";

  signal wr_addr       : integer range 0 to ADDR_LAST := 0;
  signal wr_addr_read  : integer range 0 to ADDR_LAST := 0;
  signal wr_addr_calc  : integer range 0 to ADDR_LAST := 0;
  signal wr_addr_write : integer range 0 to ADDR_LAST := 0;

  signal tap_l_read  : sample_t := (others => '0');
  signal tap_r_read  : sample_t := (others => '0');
  signal dry_l_read  : sample_t := (others => '0');
  signal dry_r_read  : sample_t := (others => '0');
  signal last_read   : boolean := false;

  signal tap_l_calc  : sample_t := (others => '0');
  signal tap_r_calc  : sample_t := (others => '0');
  signal dry_l_calc  : sample_t := (others => '0');
  signal dry_r_calc  : sample_t := (others => '0');
  signal last_calc   : boolean := false;

  signal fb_l_write    : sample_t := (others => '0');
  signal fb_r_write    : sample_t := (others => '0');
  signal out_data_write : std_logic_vector(47 downto 0) := (others => '0');
  signal out_last_write : boolean := false;

  signal read_pending  : boolean := false;
  signal calc_pending  : boolean := false;
  signal write_pending : boolean := false;

  signal out_data  : std_logic_vector(47 downto 0) := (others => '0');
  signal out_valid : boolean := false;
  signal out_last  : boolean := false;

  function sat25(x : calc_t) return sample_t is
  begin
    if x(24 downto 23) = "01" then
      return to_signed(8388607, 24);
    elsif x(24 downto 23) = "10" then
      return to_signed(-8388608, 24);
    else
      return x(23 downto 0);
    end if;
  end function;
begin
  axis_in_tready  <= (not read_pending) and
                     (not calc_pending) and
                     (not write_pending) and
                     ((not out_valid) or axis_out_tready);
  axis_out_tdata  <= out_data;
  axis_out_tvalid <= out_valid;
  axis_out_tlast  <= out_last;

  process(clk)
    variable in_l  : sample_t;
    variable in_r  : sample_t;
    variable wet_l : calc_t;
    variable wet_r : calc_t;
    variable fb_l  : calc_t;
    variable fb_r  : calc_t;
    variable y_l   : sample_t;
    variable y_r   : sample_t;
  begin
    if rising_edge(clk) then
      if aresetn = '0' then
        wr_addr <= 0;
        wr_addr_read <= 0;
        wr_addr_calc <= 0;
        wr_addr_write <= 0;
        tap_l_read <= (others => '0');
        tap_r_read <= (others => '0');
        dry_l_read <= (others => '0');
        dry_r_read <= (others => '0');
        last_read <= false;
        tap_l_calc <= (others => '0');
        tap_r_calc <= (others => '0');
        dry_l_calc <= (others => '0');
        dry_r_calc <= (others => '0');
        last_calc <= false;
        fb_l_write <= (others => '0');
        fb_r_write <= (others => '0');
        out_data_write <= (others => '0');
        out_last_write <= false;
        read_pending <= false;
        calc_pending <= false;
        write_pending <= false;
        out_data <= (others => '0');
        out_valid <= false;
        out_last <= false;
      else
        if axis_out_tready then
          out_valid <= false;
        end if;

        if write_pending and ((not out_valid) or axis_out_tready) then
          delay_l(wr_addr_write) <= fb_l_write;
          delay_r(wr_addr_write) <= fb_r_write;
          out_data <= out_data_write;
          out_last <= out_last_write;
          out_valid <= true;
          write_pending <= false;

          if wr_addr = ADDR_LAST then
            wr_addr <= 0;
          else
            wr_addr <= wr_addr + 1;
          end if;
        elsif calc_pending then
          -- Light mix: dry + a small delayed component.
          wet_l := resize(dry_l_calc, 25) + resize(shift_right(tap_l_calc, 3), 25);
          wet_r := resize(dry_r_calc, 25) + resize(shift_right(tap_r_calc, 3), 25);
          y_l := sat25(wet_l);
          y_r := sat25(wet_r);

          -- Stable feedback: half of the new input plus one quarter of the delayed sample.
          fb_l := resize(shift_right(dry_l_calc, 1), 25) + resize(shift_right(tap_l_calc, 2), 25);
          fb_r := resize(shift_right(dry_r_calc, 1), 25) + resize(shift_right(tap_r_calc, 2), 25);

          fb_l_write <= sat25(fb_l);
          fb_r_write <= sat25(fb_r);
          out_data_write <= std_logic_vector(y_r) & std_logic_vector(y_l);
          out_last_write <= last_calc;
          wr_addr_write <= wr_addr_calc;
          write_pending <= true;
          calc_pending <= false;
        elsif read_pending then
          tap_l_calc <= tap_l_read;
          tap_r_calc <= tap_r_read;
          dry_l_calc <= dry_l_read;
          dry_r_calc <= dry_r_read;
          last_calc <= last_read;
          wr_addr_calc <= wr_addr_read;
          calc_pending <= true;
          read_pending <= false;
        elsif axis_in_tvalid and ((not out_valid) or axis_out_tready) then
          in_l := signed(axis_in_tdata(23 downto 0));
          in_r := signed(axis_in_tdata(47 downto 24));
          dry_l_read <= in_l;
          dry_r_read <= in_r;
          last_read <= axis_in_tlast;
          wr_addr_read <= wr_addr;
          tap_l_read <= delay_l(wr_addr);
          tap_r_read <= delay_r(wr_addr);
          read_pending <= true;
        end if;
      end if;
    end if;
  end process;
end;
