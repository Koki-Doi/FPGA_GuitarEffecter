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

Current operational snapshot (2026-06-20): D148 is the accepted/deployed
bitstream (`96ef899`, bit `972d9ba6...`) = JC/Twin clean-headroom fix + D146 hard
CDC pblock + D147 sag slew, superseding D135 (`765323b`); D136-D142 and D144 were
bench-rejected and rolled back to D135 before the D146 pblock made the crossing
robust. Board Notebooks are served from
`http://192.168.1.9:9090/tree/audio_lab` and deploy validates all 15 files.
Historical Markdown under `docs/ai_context/history/` intentionally preserves
the status and terminology of its original phase.
