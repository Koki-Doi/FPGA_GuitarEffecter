# Comp+Cab v2 timing strategy analysis

Date: 2026-05-27

Branch: `timing/comp-cab-split-v2`

Source state:

- Timing candidate: `24fa72b Timing candidate: Compressor + Cab pipeline split (WNS -10.854 -> -9.972)`
- Documentation commit: `7d695e0 Document timing candidate and rejected DS-1 split`
- RTL source was not changed for this analysis.
- `block_design.tcl`, AXI GPIO layout, Python APIs, notebooks, GUI, encoder logic, and voicing constants were not changed.
- Reports are under `hw/Pynq-Z2/timing_reports/comp_cab_v2/<strategy>/` and are intentionally left out of the small analysis output.

## Method

The default implementation was rebuilt from the Comp+Cab v2 source in a clean temporary Vivado project. Other strategies were run from the same synthesized design with separate implementation runs.

Helper scripts:

- `docs/analysis/timing_strategy_comp_cab_v2/run_strategy_build.tcl`
- `docs/analysis/timing_strategy_comp_cab_v2/run_impl_variant.tcl`

Reports generated per strategy:

- `timing_summary.rpt`
- `timing_max_100.rpt`
- `timing_by_group.rpt`
- `timing_clk_fpga_0.rpt`
- `utilization.rpt`
- `utilization_hierarchical.rpt`
- `high_fanout_nets.rpt`
- `control_sets.rpt`
- `design_analysis_timing.rpt`

No DS-1 RTL experiment was included. In particular, the rejected `ds1BoostFrame` split was not reintroduced.

## Strategy results

Detailed CSV: `docs/analysis/timing_strategy_comp_cab_v2/strategy_results.csv`

| Strategy | WNS ns | TNS ns | WHS ns | THS ns | Failing endpoints | LUT | FF | BRAM | DSP |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| default | -10.687 | -10313.964 | 0.046 | 0.000 | 3236 | 20426 | 22382 | 6 | 83 |
| Performance_Explore | -9.972 | -10137.604 | 0.050 | 0.000 | 3304 | 20456 | 22447 | 6 | 83 |
| Performance_ExplorePostRoutePhysOpt | -9.832 | -9377.188 | 0.050 | 0.000 | 3132 | 20456 | 22447 | 6 | 83 |
| Performance_WLBlockPlacement | -9.875 | -10008.824 | 0.052 | 0.000 | 3197 | 20479 | 22410 | 6 | 83 |
| Performance_NetDelay_high | -9.729 | -10498.312 | 0.052 | 0.000 | 3534 | 20522 | 22399 | 6 | 83 |
| phys_opt_AggressiveExplore | -10.131 | -10207.098 | 0.051 | 0.000 | 3359 | 20489 | 22419 | 6 | 83 |

Observations:

- All strategies keep BRAM at 6 and DSP at 83.
- `Performance_NetDelay_high` gives the best single WNS at -9.729 ns, but has the worst TNS and the highest failing endpoint count.
- `Performance_ExplorePostRoutePhysOpt` gives the best balanced result: WNS -9.832 ns, best TNS, and lowest failing endpoint count.
- `phys_opt_AggressiveExplore` improved placement estimates but regressed after routing.

## Worst path analysis

For the preferred balanced strategy, `Performance_ExplorePostRoutePhysOpt`, path #1 is:

- Slack: -9.832 ns
- Source: `block_design_i/clash_lowpass_fir_0/U0/ARG__14__0_i_1_psdsp/C`
- Destination: `block_design_i/clash_lowpass_fir_0/U0/ds1_5_reg[1034]/D`
- Data path delay: 19.695 ns
- Logic delay: 13.363 ns, 68 percent
- Route delay: 6.332 ns, 32 percent
- Logic levels: 22
- Primitive mix: CARRY4=13, DSP48E1=2, LUT2=2, LUT3=3, LUT5=2
- Highest data fanout seen on the path: 143, `result_selection_res_11`

Top-100 classification from `timing_max_100.rpt`:

| Strategy | DS-1 paths | Compressor paths | Amp paths | Cab paths | Other paths | DS-1 paths with DSP48E1 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| default | 100 | 0 | 0 | 0 | 0 | 76 |
| Performance_Explore | 100 | 0 | 0 | 0 | 0 | 76 |
| Performance_ExplorePostRoutePhysOpt | 100 | 0 | 0 | 0 | 0 | 76 |
| Performance_WLBlockPlacement | 100 | 0 | 0 | 0 | 0 | 76 |
| Performance_NetDelay_high | 100 | 0 | 0 | 0 | 0 | 76 |
| phys_opt_AggressiveExplore | 100 | 0 | 0 | 0 | 0 | 76 |

The worst path family is not one uniform shape:

- 76 of the top 100 paths include DSP48E1 and CARRY4. These are logic-delay heavy paths around the DS-1 arithmetic and downstream `Maybe Frame` register packing.
- The remaining 24 paths are mostly CARRY4 chains and routing. Example from the same report: `ds1_7_reg[154]_replica/C` to `ARG__14__0_i_20_psdsp/D` has 42 logic levels, CARRY4=33, logic delay 10.550 ns, and route delay 8.994 ns.
- The path names include full `Maybe Frame` registers such as `ds1_5_reg` and `ds1_7_reg`. Some paths also expose `Frame_sel31_fAcc2L` and `Frame_sel33_fAcc3L`. The `Maybe Frame` mux/register shape is involved, but the first-order issue is still the DS-1 arithmetic plus saturation/carry-chain depth.
- High fanout is present inside the data path, but it is not the only driver. The largest critical data fanouts observed are around 143 on `result_selection_res_11` and 145 on `ds1_7_reg_n_0_[753]`.
- The global high-fanout list is dominated by clock/reset/video/control nets and does not by itself explain the DS-1 setup failure.

## Decision

Recommended RTL-free strategy candidate:

- `Performance_ExplorePostRoutePhysOpt`

Reason:

- It has the best TNS and lowest failing endpoint count of the tested runs.
- It still improves WNS over `Performance_Explore` by 0.140 ns.
- It keeps WHS/THS clean and does not add DSP or BRAM.

Not recommended as the next deploy candidate:

- `default`: baseline only.
- `Performance_Explore`: current candidate, but worse than post-route physopt in WNS/TNS/failing endpoints.
- `Performance_WLBlockPlacement`: good WNS, but less balanced than post-route physopt.
- `Performance_NetDelay_high`: best WNS, but worse TNS, more failing endpoints, and longer runtime.
- `phys_opt_AggressiveExplore`: route result regressed versus `Performance_Explore`.

## Next RTL analysis, if needed

Do not start with the rejected `satShift8` plus `asymSoftClip` split. The next DS-1 investigation should compare:

- Control decode localization only.
- A small intermediate record for only the fields needed by the DS-1 arithmetic, without adding a full `Frame` register.
- Keeping DS-1 RTL unchanged and relying on implementation strategy or physical optimization.
- Limited synthesis attributes or hierarchy controls while preserving pedal order and placement hierarchy.

Any DS-1 RTL change still requires a Vivado bit/hwh rebuild and a fresh timing summary before deployment.
