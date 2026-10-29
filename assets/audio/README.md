# Original procedural audio

All audio in this directory was synthesized specifically for this project by
`tools/generate_audio.py` using only Python's standard library. No samples,
commercial recordings, third-party music, or soundfonts were used.

## Format

- Mono, 22,050 Hz, signed 16-bit little-endian PCM WAV.
- `bgm.wav`: original 24-bar chiptune-inspired score, 120 BPM, exactly 48 seconds.
  Loop the entire file. Instrument tails are wrapped into the next loop; there is
  no silence or fade-out at the seam. Linear gain leaves at least 2 dB headroom.
- `shot.wav`: short player laser; `enemy_shot.wav`: softer, lower enemy laser.
- `explosion.wav`: filtered noise / low-frequency burst.
- `hit.wav`: damage impact; `powerup.wav`: ascending pickup chime.
- `victory.wav`: short resolution fanfare; `menu.wav`: confirmation chime.

Enable forward looping for the BGM stream only, either through Godot's WAV import
settings (`edit > Loop Mode: Forward`) or by assigning
`AudioStreamWAV.LOOP_FORWARD` to the loaded BGM stream's `loop_mode`. Sound effects
must not loop. Recommended in-game levels: BGM -9 dB, normal effects -8 dB,
player laser -16 dB; tune to taste.

## Reproducibility / checks

From the project root:

```sh
python3 tools/generate_audio.py
python3 tools/generate_audio.py --validate-only
```

The generator uses fixed RNG seeds. It prints duration, peak amplitude, RMS,
clipped sample count and loop-boundary jump for every WAV. It rejects clipping,
unexpected format, excessive peak amplitude and a large BGM seam discontinuity.
No Python packages are required.
