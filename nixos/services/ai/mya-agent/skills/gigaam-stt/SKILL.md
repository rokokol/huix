---
name: gigaam-stt
description: Transcribe Russian audio locally on the station with GigaAM-v3 Q4_K_M. Use when a voice note, audio file or recording needs a Russian transcript, including Telegram voice messages.
license: MIT
---

# Local GigaAM speech recognition

Run `mya-gigaam-stt AUDIO_FILE` to transcribe Russian audio on the station. It accepts formats supported by FFmpeg, converts them to 16 kHz mono WAV in a private temporary directory, and prints the transcript. The audio and transcript are not sent to an external service.

Use the transcript as source material, not as confirmed intent. Preserve uncertainty where the audio is unclear, and ask before acting on ambiguous speech. Do not overwrite or delete the source recording.

The command uses the station's pinned GigaAM-v3 e2e-RNNT Q4_K_M model. Set `GIGAAM_THREADS` to a positive integer to adjust CPU use; the default is 2. The model is Russian-only and does not stream partial results.
