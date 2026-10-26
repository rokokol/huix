---
name: opus-sound-layer
description: Select recorded sound effects, place them at animation events, mix background audio with an existing voice track, and check the exported video. Use for animation sounds, background effects, sound design, whooshes, impacts, ambient audio, звуковые эффекты, фоновый звук, озвучивание анимации, сведение звука
license: MIT
---

# Sound layer

Use the installed `sound-layer-sfx`, `sound-layer-mix` and `sound-layer-qa` commands. They run the upstream scripts with their dependencies. Read [the upstream guide](references/upstream.md) for the workflow; use the installed commands in place of `uv run scripts/<name>.py`

1. Read each command's `--help`. Get the cue format from `sound-layer-mix --schema`
2. Derive cue times from the animation or project timeline. Match each effect to an actual action
3. Build a project-local library with `sound-layer-sfx kit`. Inspect its output for failed downloads and absent sound types
4. Browse and select individual recordings. Read the waveform and spectrogram images. Use `search` or `add` when the library has no suitable sound
5. Retain source and licence information. Keep long background recordings separate from the transient preparation steps, which cut recordings into short events
6. Mix the effects with any supplied voice and music tracks. Keep the cue sheet and separate stems so the editor can adjust the result
7. Run `sound-layer-qa` on the encoded video and inspect its report and images. Correct the cues or audio when a check fails

Measurements establish timing and levels, not perceptual quality. Report the measured result and give the user timecodes for a final listening check
