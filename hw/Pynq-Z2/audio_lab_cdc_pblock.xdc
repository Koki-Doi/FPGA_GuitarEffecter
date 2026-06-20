## D146: stabilise the placement-sensitive fabric -> I2S output crossing.
##
## The 112 CDC-13 paths run from transfer mux 0 in axis_switch_sink into the
## write-side distributed dual-port RAM inside i2s_to_stream.  D109 times the
## crossing with a 10 ns datapath-only bound, but D136-D144 proved that the
## audio result remains placement-sensitive.  Keep both sides in the same
## compact region derived from a fresh, timing-clean D135 routed checkpoint.
##
## This file is implementation-only.  create_project.tcl marks it unused for
## synthesis so these post-synthesis hierarchical cells are always available.

set d146_pblock_name pblock_audio_output_cdc
create_pblock $d146_pblock_name

resize_pblock [get_pblocks $d146_pblock_name] \
    -add {SLICE_X100Y116:SLICE_X113Y137}
set_property IS_SOFT false [get_pblocks $d146_pblock_name]

set d146_source_pattern {block_design_i/axis_switch_sink/inst/gen_transfer_mux?0?.axisc_transfer_mux_0/axisc_register_slice_0/gen_AB_reg_slice.*}
set d146_target_pattern {block_design_i/i2s_to_stream_0/U0/ADAU1761_topEntity_trueDualPortBlockRamWrapper_ccase_scrut/*}

add_cells_to_pblock [get_pblocks $d146_pblock_name] \
    [get_cells -hierarchical -quiet -filter \
        "IS_PRIMITIVE == 1 && NAME =~ $d146_source_pattern"]
add_cells_to_pblock [get_pblocks $d146_pblock_name] \
    [get_cells -hierarchical -quiet -filter \
        "IS_PRIMITIVE == 1 && NAME =~ $d146_target_pattern"]
