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

Current operational snapshot (2026-06-19): D135 is the accepted/deployed
bitstream (`765323b`, bit `533d5869...`); D144 was bench-rejected and rolled
back. Board Notebooks are served from
`http://192.168.1.9:9090/tree/audio_lab` and deploy validates all 15 files.
Historical Markdown under `docs/ai_context/history/` intentionally preserves
the status and terminology of its original phase.
