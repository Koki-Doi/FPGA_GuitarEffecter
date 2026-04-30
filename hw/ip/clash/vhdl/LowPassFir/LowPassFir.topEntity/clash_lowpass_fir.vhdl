library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity clash_lowpass_fir is
  port(
       clk                : in std_logic;
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

architecture rtl of clash_lowpass_fir is
  constant DELAY_LEN : integer := 1024;
  constant ADDR_LAST : integer := DELAY_LEN - 1;

  subtype sample_t is signed(23 downto 0);
  subtype wide_t is signed(47 downto 0);
  subtype gain8_t is unsigned(7 downto 0);
  subtype gain9_t is unsigned(8 downto 0);
  subtype gain12_t is unsigned(11 downto 0);
  type delay_ram_t is array (0 to DELAY_LEN - 1) of sample_t;
  type state_t is (
    idle,
    gate_stage,
    overdrive_drive_stage,
    overdrive_tone_stage,
    distortion_drive_stage,
    distortion_tone_stage,
    eq_filter_stage,
    eq_mix_stage,
    delay_read_stage,
    delay_mix_stage,
    reverb_read_stage,
    reverb_tone_stage,
    reverb_mix_stage
  );

  signal delay_l : delay_ram_t := (others => (others => '0'));
  signal delay_r : delay_ram_t := (others => (others => '0'));
  signal reverb_l : delay_ram_t := (others => (others => '0'));
  signal reverb_r : delay_ram_t := (others => (others => '0'));
  attribute ram_style : string;
  attribute ram_style of delay_l : signal is "block";
  attribute ram_style of delay_r : signal is "block";
  attribute ram_style of reverb_l : signal is "block";
  attribute ram_style of reverb_r : signal is "block";

  signal state : state_t := idle;
  signal wr_addr : integer range 0 to ADDR_LAST := 0;

  signal stage_l : sample_t := (others => '0');
  signal stage_r : sample_t := (others => '0');
  signal stage_last : boolean := false;

  signal gate_ctrl_reg : std_logic_vector(31 downto 0) := (others => '0');
  signal od_ctrl_reg : std_logic_vector(31 downto 0) := (others => '0');
  signal dist_ctrl_reg : std_logic_vector(31 downto 0) := (others => '0');
  signal eq_ctrl_reg : std_logic_vector(31 downto 0) := (others => '0');
  signal delay_ctrl_reg : std_logic_vector(31 downto 0) := (others => '0');
  signal reverb_ctrl_reg : std_logic_vector(31 downto 0) := (others => '0');

  signal od_tone_l : sample_t := (others => '0');
  signal od_tone_r : sample_t := (others => '0');
  signal dist_tone_l : sample_t := (others => '0');
  signal dist_tone_r : sample_t := (others => '0');
  signal eq_low_l : sample_t := (others => '0');
  signal eq_low_r : sample_t := (others => '0');
  signal eq_high_lp_l : sample_t := (others => '0');
  signal eq_high_lp_r : sample_t := (others => '0');
  signal eq_band_low_l : sample_t := (others => '0');
  signal eq_band_low_r : sample_t := (others => '0');
  signal eq_band_mid_l : sample_t := (others => '0');
  signal eq_band_mid_r : sample_t := (others => '0');
  signal eq_band_high_l : sample_t := (others => '0');
  signal eq_band_high_r : sample_t := (others => '0');
  signal delay_tap_l : sample_t := (others => '0');
  signal delay_tap_r : sample_t := (others => '0');
  signal reverb_tap_l : sample_t := (others => '0');
  signal reverb_tap_r : sample_t := (others => '0');
  signal reverb_tone_l : sample_t := (others => '0');
  signal reverb_tone_r : sample_t := (others => '0');
  signal reverb_wet_l : sample_t := (others => '0');
  signal reverb_wet_r : sample_t := (others => '0');

  signal out_data : std_logic_vector(47 downto 0) := (others => '0');
  signal out_valid : boolean := false;
  signal out_last : boolean := false;

  function abs24(x : sample_t) return sample_t is
  begin
    if x = to_signed(-8388608, 24) then
      return to_signed(8388607, 24);
    elsif x(23) = '1' then
      return -x;
    else
      return x;
    end if;
  end function;

  function mul_u8(x : sample_t; g : gain8_t) return wide_t is
  begin
    return resize(x * signed('0' & std_logic_vector(g)), 48);
  end function;

  function mul_u9(x : sample_t; g : gain9_t) return wide_t is
  begin
    return resize(x * signed('0' & std_logic_vector(g)), 48);
  end function;

  function mul_u12(x : sample_t; g : gain12_t) return wide_t is
  begin
    return resize(x * signed('0' & std_logic_vector(g)), 48);
  end function;

  function sat_wide(x : wide_t) return sample_t is
  begin
    if x > to_signed(8388607, 48) then
      return to_signed(8388607, 24);
    elsif x < to_signed(-8388608, 48) then
      return to_signed(-8388608, 24);
    else
      return x(23 downto 0);
    end if;
  end function;

  function sat_shift7(x : wide_t) return sample_t is
  begin
    return sat_wide(shift_right(x, 7));
  end function;

  function sat_shift8(x : wide_t) return sample_t is
  begin
    return sat_wide(shift_right(x, 8));
  end function;

  function soft_clip(x : sample_t) return sample_t is
    variable w : wide_t;
    constant knee : sample_t := to_signed(4194304, 24);
  begin
    if x > knee then
      w := resize(knee, 48) + shift_right(resize(x - knee, 48), 2);
      return sat_wide(w);
    elsif x < -knee then
      w := resize(-knee, 48) + shift_right(resize(x + knee, 48), 2);
      return sat_wide(w);
    else
      return x;
    end if;
  end function;

  function hard_clip(x : sample_t; threshold : sample_t) return sample_t is
  begin
    if x > threshold then
      return threshold;
    elsif x < -threshold then
      return -threshold;
    else
      return x;
    end if;
  end function;
begin
  axis_in_tready  <= (state = idle) and ((not out_valid) or axis_out_tready);
  axis_out_tdata  <= out_data;
  axis_out_tvalid <= out_valid;
  axis_out_tlast  <= out_last;

  process(clk)
    variable x_l : sample_t;
    variable x_r : sample_t;
    variable y_l : sample_t;
    variable y_r : sample_t;
    variable low_l : sample_t;
    variable low_r : sample_t;
    variable high_lp_l : sample_t;
    variable high_lp_r : sample_t;
    variable high_l : sample_t;
    variable high_r : sample_t;
    variable mid_l : sample_t;
    variable mid_r : sample_t;
    variable threshold : sample_t;
    variable clip_threshold : sample_t;
    variable mix_gain : gain8_t;
    variable inv_mix_gain : gain9_t;
    variable drive_gain : gain12_t;
    variable tone_gain : gain8_t;
    variable inv_tone_gain : gain8_t;
    variable level_gain : gain8_t;
    variable delay_samples : integer range 0 to ADDR_LAST;
    variable read_addr : integer range 0 to ADDR_LAST;
    variable p : integer;
    variable tmp : integer;
    variable acc_l : wide_t;
    variable acc_r : wide_t;
  begin
    if rising_edge(clk) then
      if aresetn = '0' then
        state <= idle;
        wr_addr <= 0;
        stage_l <= (others => '0');
        stage_r <= (others => '0');
        stage_last <= false;
        gate_ctrl_reg <= (others => '0');
        od_ctrl_reg <= (others => '0');
        dist_ctrl_reg <= (others => '0');
        eq_ctrl_reg <= (others => '0');
        delay_ctrl_reg <= (others => '0');
        reverb_ctrl_reg <= (others => '0');
        od_tone_l <= (others => '0');
        od_tone_r <= (others => '0');
        dist_tone_l <= (others => '0');
        dist_tone_r <= (others => '0');
        eq_low_l <= (others => '0');
        eq_low_r <= (others => '0');
        eq_high_lp_l <= (others => '0');
        eq_high_lp_r <= (others => '0');
        eq_band_low_l <= (others => '0');
        eq_band_low_r <= (others => '0');
        eq_band_mid_l <= (others => '0');
        eq_band_mid_r <= (others => '0');
        eq_band_high_l <= (others => '0');
        eq_band_high_r <= (others => '0');
        delay_tap_l <= (others => '0');
        delay_tap_r <= (others => '0');
        reverb_tap_l <= (others => '0');
        reverb_tap_r <= (others => '0');
        reverb_tone_l <= (others => '0');
        reverb_tone_r <= (others => '0');
        reverb_wet_l <= (others => '0');
        reverb_wet_r <= (others => '0');
        out_data <= (others => '0');
        out_valid <= false;
        out_last <= false;
      else
        if axis_out_tready then
          out_valid <= false;
        end if;

        case state is
          when idle =>
            if axis_in_tvalid and ((not out_valid) or axis_out_tready) then
              stage_l <= signed(axis_in_tdata(23 downto 0));
              stage_r <= signed(axis_in_tdata(47 downto 24));
              stage_last <= axis_in_tlast;
              gate_ctrl_reg <= gate_control;
              od_ctrl_reg <= overdrive_control;
              dist_ctrl_reg <= distortion_control;
              eq_ctrl_reg <= eq_control;
              delay_ctrl_reg <= delay_control;
              reverb_ctrl_reg <= reverb_control;
              state <= gate_stage;
            end if;

          when gate_stage =>
            x_l := stage_l;
            x_r := stage_r;
            if gate_ctrl_reg(0) = '1' then
              threshold := shift_left(resize(signed('0' & gate_ctrl_reg(15 downto 8)), 24), 15);
              if abs24(x_l) < threshold and abs24(x_r) < threshold then
                x_l := (others => '0');
                x_r := (others => '0');
              end if;
            end if;
            stage_l <= x_l;
            stage_r <= x_r;
            state <= overdrive_drive_stage;

          when overdrive_drive_stage =>
            x_l := stage_l;
            x_r := stage_r;
            if gate_ctrl_reg(1) = '1' then
              tmp := 256 + (to_integer(unsigned(od_ctrl_reg(23 downto 16))) * 4);
              drive_gain := to_unsigned(tmp, 12);
              x_l := soft_clip(sat_shift8(mul_u12(x_l, drive_gain)));
              x_r := soft_clip(sat_shift8(mul_u12(x_r, drive_gain)));
            end if;
            stage_l <= x_l;
            stage_r <= x_r;
            state <= overdrive_tone_stage;

          when overdrive_tone_stage =>
            x_l := stage_l;
            x_r := stage_r;
            if gate_ctrl_reg(1) = '1' then
              tone_gain := unsigned(od_ctrl_reg(7 downto 0));
              inv_tone_gain := to_unsigned(255, 8) - tone_gain;
              level_gain := unsigned(od_ctrl_reg(15 downto 8));
              acc_l := mul_u8(x_l, tone_gain) + mul_u8(od_tone_l, inv_tone_gain);
              acc_r := mul_u8(x_r, tone_gain) + mul_u8(od_tone_r, inv_tone_gain);
              y_l := sat_shift8(acc_l);
              y_r := sat_shift8(acc_r);
              od_tone_l <= y_l;
              od_tone_r <= y_r;
              x_l := sat_shift7(mul_u8(y_l, level_gain));
              x_r := sat_shift7(mul_u8(y_r, level_gain));
            else
              od_tone_l <= x_l;
              od_tone_r <= x_r;
            end if;
            stage_l <= x_l;
            stage_r <= x_r;
            state <= distortion_drive_stage;

          when distortion_drive_stage =>
            x_l := stage_l;
            x_r := stage_r;
            if gate_ctrl_reg(2) = '1' then
              tmp := 256 + (to_integer(unsigned(dist_ctrl_reg(23 downto 16))) * 8);
              drive_gain := to_unsigned(tmp, 12);
              tmp := 8388607 - (to_integer(unsigned(dist_ctrl_reg(23 downto 16))) * 24000);
              if tmp < 1800000 then
                tmp := 1800000;
              end if;
              clip_threshold := to_signed(tmp, 24);
              x_l := hard_clip(sat_shift8(mul_u12(x_l, drive_gain)), clip_threshold);
              x_r := hard_clip(sat_shift8(mul_u12(x_r, drive_gain)), clip_threshold);
            end if;
            stage_l <= x_l;
            stage_r <= x_r;
            state <= distortion_tone_stage;

          when distortion_tone_stage =>
            x_l := stage_l;
            x_r := stage_r;
            if gate_ctrl_reg(2) = '1' then
              tone_gain := unsigned(dist_ctrl_reg(7 downto 0));
              inv_tone_gain := to_unsigned(255, 8) - tone_gain;
              level_gain := unsigned(dist_ctrl_reg(15 downto 8));
              acc_l := mul_u8(x_l, tone_gain) + mul_u8(dist_tone_l, inv_tone_gain);
              acc_r := mul_u8(x_r, tone_gain) + mul_u8(dist_tone_r, inv_tone_gain);
              y_l := sat_shift8(acc_l);
              y_r := sat_shift8(acc_r);
              dist_tone_l <= y_l;
              dist_tone_r <= y_r;
              x_l := sat_shift7(mul_u8(y_l, level_gain));
              x_r := sat_shift7(mul_u8(y_r, level_gain));
            else
              dist_tone_l <= x_l;
              dist_tone_r <= x_r;
            end if;
            stage_l <= x_l;
            stage_r <= x_r;
            state <= eq_filter_stage;

          when eq_filter_stage =>
            x_l := stage_l;
            x_r := stage_r;
            low_l := eq_low_l + resize(shift_right(resize(x_l, 25) - resize(eq_low_l, 25), 5), 24);
            low_r := eq_low_r + resize(shift_right(resize(x_r, 25) - resize(eq_low_r, 25), 5), 24);
            high_lp_l := eq_high_lp_l + resize(shift_right(resize(x_l, 25) - resize(eq_high_lp_l, 25), 2), 24);
            high_lp_r := eq_high_lp_r + resize(shift_right(resize(x_r, 25) - resize(eq_high_lp_r, 25), 2), 24);
            high_l := sat_wide(resize(x_l, 48) - resize(high_lp_l, 48));
            high_r := sat_wide(resize(x_r, 48) - resize(high_lp_r, 48));
            mid_l := sat_wide(resize(x_l, 48) - resize(low_l, 48) - resize(high_l, 48));
            mid_r := sat_wide(resize(x_r, 48) - resize(low_r, 48) - resize(high_r, 48));

            eq_low_l <= low_l;
            eq_low_r <= low_r;
            eq_high_lp_l <= high_lp_l;
            eq_high_lp_r <= high_lp_r;
            eq_band_low_l <= low_l;
            eq_band_low_r <= low_r;
            eq_band_mid_l <= mid_l;
            eq_band_mid_r <= mid_r;
            eq_band_high_l <= high_l;
            eq_band_high_r <= high_r;
            state <= eq_mix_stage;

          when eq_mix_stage =>
            x_l := stage_l;
            x_r := stage_r;
            if gate_ctrl_reg(3) = '1' then
              acc_l := mul_u8(eq_band_low_l, unsigned(eq_ctrl_reg(7 downto 0))) +
                       mul_u8(eq_band_mid_l, unsigned(eq_ctrl_reg(15 downto 8))) +
                       mul_u8(eq_band_high_l, unsigned(eq_ctrl_reg(23 downto 16)));
              acc_r := mul_u8(eq_band_low_r, unsigned(eq_ctrl_reg(7 downto 0))) +
                       mul_u8(eq_band_mid_r, unsigned(eq_ctrl_reg(15 downto 8))) +
                       mul_u8(eq_band_high_r, unsigned(eq_ctrl_reg(23 downto 16)));
              x_l := sat_shift7(acc_l);
              x_r := sat_shift7(acc_r);
            end if;
            stage_l <= x_l;
            stage_r <= x_r;
            state <= delay_read_stage;

          when delay_read_stage =>
            p := to_integer(unsigned(delay_ctrl_reg(15 downto 8)));
            delay_samples := 64 + (p * 3);
            if wr_addr >= delay_samples then
              read_addr := wr_addr - delay_samples;
            else
              read_addr := DELAY_LEN + wr_addr - delay_samples;
            end if;
            delay_tap_l <= delay_l(read_addr);
            delay_tap_r <= delay_r(read_addr);
            state <= delay_mix_stage;

          when delay_mix_stage =>
            x_l := stage_l;
            x_r := stage_r;
            if gate_ctrl_reg(4) = '1' then
              acc_l := resize(x_l, 48) + shift_right(mul_u8(delay_tap_l, unsigned(delay_ctrl_reg(7 downto 0))), 8);
              acc_r := resize(x_r, 48) + shift_right(mul_u8(delay_tap_r, unsigned(delay_ctrl_reg(7 downto 0))), 8);
              y_l := sat_wide(acc_l);
              y_r := sat_wide(acc_r);

              acc_l := resize(x_l, 48) + shift_right(mul_u8(delay_tap_l, unsigned(delay_ctrl_reg(23 downto 16))), 8);
              acc_r := resize(x_r, 48) + shift_right(mul_u8(delay_tap_r, unsigned(delay_ctrl_reg(23 downto 16))), 8);
              delay_l(wr_addr) <= sat_wide(acc_l);
              delay_r(wr_addr) <= sat_wide(acc_r);
              x_l := y_l;
              x_r := y_r;
            else
              delay_l(wr_addr) <= x_l;
              delay_r(wr_addr) <= x_r;
            end if;
            stage_l <= x_l;
            stage_r <= x_r;
            state <= reverb_read_stage;

          when reverb_read_stage =>
            reverb_tap_l <= reverb_l(wr_addr);
            reverb_tap_r <= reverb_r(wr_addr);
            state <= reverb_tone_stage;

          when reverb_tone_stage =>
            tone_gain := unsigned(reverb_ctrl_reg(15 downto 8));
            inv_tone_gain := to_unsigned(255, 8) - tone_gain;
            acc_l := mul_u8(reverb_tap_l, tone_gain) + mul_u8(reverb_tone_l, inv_tone_gain);
            acc_r := mul_u8(reverb_tap_r, tone_gain) + mul_u8(reverb_tone_r, inv_tone_gain);
            y_l := sat_shift8(acc_l);
            y_r := sat_shift8(acc_r);
            reverb_tone_l <= y_l;
            reverb_tone_r <= y_r;
            reverb_wet_l <= y_l;
            reverb_wet_r <= y_r;
            state <= reverb_mix_stage;

          when reverb_mix_stage =>
            x_l := stage_l;
            x_r := stage_r;
            if gate_ctrl_reg(5) = '1' then
              mix_gain := unsigned(reverb_ctrl_reg(23 downto 16));
              inv_mix_gain := to_unsigned(256, 9) - resize(mix_gain, 9);
              acc_l := mul_u9(x_l, inv_mix_gain) + mul_u8(reverb_wet_l, mix_gain);
              acc_r := mul_u9(x_r, inv_mix_gain) + mul_u8(reverb_wet_r, mix_gain);
              y_l := sat_shift8(acc_l);
              y_r := sat_shift8(acc_r);

              acc_l := shift_right(resize(x_l, 48), 1) + shift_right(mul_u8(reverb_wet_l, unsigned(reverb_ctrl_reg(7 downto 0))), 8);
              acc_r := shift_right(resize(x_r, 48), 1) + shift_right(mul_u8(reverb_wet_r, unsigned(reverb_ctrl_reg(7 downto 0))), 8);
              reverb_l(wr_addr) <= sat_wide(acc_l);
              reverb_r(wr_addr) <= sat_wide(acc_r);
            else
              y_l := x_l;
              y_r := x_r;
              reverb_l(wr_addr) <= (others => '0');
              reverb_r(wr_addr) <= (others => '0');
            end if;

            out_data <= std_logic_vector(y_r) & std_logic_vector(y_l);
            out_last <= stage_last;
            out_valid <= true;

            if wr_addr = ADDR_LAST then
              wr_addr <= 0;
            else
              wr_addr <= wr_addr + 1;
            end if;
            state <= idle;
        end case;
      end if;
    end if;
  end process;
end;
