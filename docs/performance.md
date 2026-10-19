# Performance

What Hush costs on a Mac, measured, and how to measure it yourself. Targets from the v1 spec (ADR-021): near zero
off screen (under 1 %), under 5 % while animating, modest memory.

## How to measure

```sh
./scripts/measure.sh 40      # CPU time used by Hush and its WebKit helpers over 40 s, plus their memory
```

It adds up CPU time from `ps` (one core = 100 %), not the decaying %CPU column, and prints how long the Mac has had no
input, because moving the mouse near Hush wakes it. For a clean number, set up the state, then leave the Mac alone.
States: idle (nothing waiting, cursor elsewhere), alerting (Settings ▸ Developer ▸ Meeting in 2 min), battery mode
(Low Power Mode on), paused (menu bar ▸ Pause), locked (`sleep 5; ./scripts/measure.sh 40`, then lock the screen).

## Results (2026-10-19, MacBook, macOS 27.0.1, Apple silicon)

Measured while the Mac was in use by its owner and a Claude Code session was running (Hush shows "thinking" for it),
so treat these as upper bounds; a clean run is still to do. Hush + 3 WebKit helpers.

| State | CPU | Memory | Notes |
| --- | --- | --- | --- |
| Locked | 0.55 % | 33 MB | Nothing renders; pointer, clipboard and window checks stop (ADR-022) |
| Paused | 1.0 % | 38 MB | Was 1.97 % before sensors stopped while off screen |
| Idle, on screen | 0.8 to 2.9 % | 29 to 55 MB | Varies with mouse activity near Hush and the agent "thinking" pose |
| Battery mode (Low Power Mode), idle | 3.0 % | 55 MB | Measured before the off-screen changes, during use |
| Alerting (interrupt: hurry, then tapping) | 5.8 % | 56 MB | Was 12.7 % with a constant tap loop; now two knocks every 6 s |

Earlier, ADR-011 measured quiet stretches at 1.5 to 3 % and a median of 3.5 % in real use, down from about 20 %.
