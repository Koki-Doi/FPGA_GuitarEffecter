# Audio Lab on PYNQ

A platform for playing with audio DSP on via PYNQ. I'm using this for writing
guitar effects in [CLaSH](http://https://clash-lang.org/). Do what you'd like
with it!

We expose the ADAU1761 audio codec's configuration registers via Python, so you
can fiddle with gains or the DSP engine at run-time. We also expose the audio
samples (in an easy, parallel format) in a clock domain seperate from and much
faster than the the ADAU1761's clocks. Feel free to make the most of the extra
cycles! Credit to hamster (Mike Field) and
[ems-kl](https://github.com/ems-kl/zedboard_audio) for the I2S implementation.

This repo supports the PYNQ-Z2 board. It can probably be extended to any
Zynq/MPSoC board with the ADAU1761 audio codec without too much swearing.
   
## Overlay installation

I'll try to supply a pre-built wheel containing the bitstream for any tagged releases.

We depend on some new packaging features (depending on other packages via GitHub), so first, please update your pip:

```sh
pip3 install --upgrade pip
```

You can install it straight from the board with:

```sh
# pip3 install https://github.com/cramsay/Audio-Lab-PYNQ/releases/download/v1.0_$BOARD/audio_lab_pynq-1.0-py3-none-any.whl
# python3 -c 'import audio_lab_pynq; audio_lab_pynq.install_notebooks()'
```

The notebooks should then be available from the Jupyter file browser inside the
`audio_lab` directory.

## Building the wheel
> NOTE: This must be built on an x86 Linux PC, with Vivado and Python 3
> installed and available on $PATH. This cannot be built on the board because of
> the Vendor EDA tools...

You can rebuild the entire wheel by running:

```sh
$ git clone https://github.com/cramsay/Audio-Lab-PYNQ
$ cd Audio-Lab-PYNQ
$ BOARD=Pynq-Z2 make
```

If you just want to build the Vivado project and bitstream, run:
```sh
$ make Pynq-Z2
```

## License

WTFPL.

## FX gain HLS IP
- The block design inserts `fx_gain_0` (VLNV `user.org:hls:fx_gain:1.0`) inline on the audio AXI-Stream path: `axis_switch_source/M00_AXIS → fx_gain_0/s_axis → fx_gain_0/m_axis → axis_switch_sink/S00_AXIS`.
- `s_axi_CTRL` is tied to PS `M_AXI_GP0` and mapped at `0x43C20000` (64KB). Clock is `FCLK_CLK0` (100MHz); reset uses `peripheral_aresetn`.
- Make sure the HLS IP is registered in the Vivado IP catalog (default `ip_repo_paths` is `hw/ip`; adjust if you store it elsewhere).
