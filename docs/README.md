# Documentation index

- AI development context (Claude Code / Codex shared briefing) →
  [`ai_context/README.md`](ai_context/README.md)
- HDMI GUI renderer notes →
  [`../GUI/README.md`](../GUI/README.md)

The top-level repository [`README.md`](../README.md) remains the
end-user-facing description of the project.

The former untracked `HDMI/` experiment directory is no longer part of
the working tree. Current HDMI GUI work uses the integrated AudioLab
overlay plus the active `GUI/` renderer and `audio_lab_pynq/hdmi_backend.py`.

Current operational snapshot (2026-06-22): D155 is the accepted/deployed
bitstream (`09c8a95`, bit `8d875cc8...`) = cab speaker FIR extended 31->47 taps
(Option-Y folded extension, sharper real-4x12 >5 kHz rolloff; presence biquad
keeps the 2-4 kHz peak). It caps the 2026-06 D150-D155 voicing arc: D150 OD/DS
symmetric-clip chord IMD, D151 amp HF brighten (post-amp shelf + cab presence),
D152/D153 chord-HF cab headroom + JC/Twin level fix (音割れ), D154 gain-amp chord
IMD (no net fix, not shipped), D155 the cab 47-tap FIR. Rollback to D153
(`b86c88a`); prior baselines D148 (`96ef899`) and D135 (`765323b`).
`scripts/deploy_to_pynq.sh` now runs a no-download bit/hwh md5 integrity check.
Board Notebooks are served from
`http://192.168.1.9:9090/tree/audio_lab` and deploy validates all 15 files.
Historical Markdown under `docs/ai_context/history/` intentionally preserves
the status and terminology of its original phase.
