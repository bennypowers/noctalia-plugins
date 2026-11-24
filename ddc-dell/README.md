# Dell Display (DDC)

Bar widget and control panel for a Dell display over DDC/CI, executed through
[`ddcutil`](https://ddcutil.com). Reverse-engineered for the **DELL U4025QW**:
the plugin's job is to make Dell's undocumented "Manufacturer specific" VCP
codes human-readable and pleasant to use.

## Features

- **Bar widget** — monitor glyph with the current brightness; scroll the wheel over it to adjust brightness (5% per detent); click opens the panel.
- **Panel**
  - Sliders: brightness, contrast, volume (committed on release)
  - Mute toggle
  - Selects: colour preset, display mode, input source (switching away from the
    current input asks for a confirm first — it blanks the screen)
  - **PIP/PBP section** with stacked full-width cards: a *Picture-By-Picture*
    chip row (Off plus the five ratios — Off is a chip, not a header switch)
    and *Picture-In-Picture* position chips (glyph + tooltip where the Tabler
    set has a real PIP icon), plus sub-window input, **Video Swap**, and an
    experimental **KVM USB switch** with a helper label showing which output
    (USB-C / Thunderbolt) the keyboard/mouse are routed to

## DDC/CI code map (U4025QW)

| VCP | Feature | Values |
|---|---|---|
| `0x10` | Brightness | 0–100 |
| `0x12` | Contrast | 0–100 |
| `0x14` | Colour preset | sRGB, 5000K, 6500K, 7500K, 9300K, 10000K, User 1, User 2 |
| `0x60` | Input (main window) | `0x0F` DisplayPort, `0x11` HDMI, `0x19` Thunderbolt |
| `0x62` | Volume | 0–100 |
| `0x8D` | Mute | 0 = on, 1 = muted |
| `0xDC` | Display mode | Standard, Movie, Game |
| `0xE9` | **PIP/PBP layout** (Dell) | `0x00` Off, `0x24` PBP 50/50, `0x27` PBP 20/80, `0x28` PBP 80/20, `0x29` PBP 25/75, `0x2A` PBP 75/25, `0x21` PIP TR small, `0x22`/`0x01`/`0x02` PIP BR/BL/TL small (assumed) |
| `0xE8` | **PBP sub-window input** (Dell) | same input codes as `0x60` |
| `0xE5` | **PIP/PBP flag + actions** (Dell) | `sl` 0x00/0xFF = PBP off/on (firmware-managed); `0xF001` video swap (main ↔ sub) |
| `0xE7` | **USB/KVM upstream** (Dell) | `0xFF00` momentary KVM switch (binary) — *experimental*; the register reports no usable state (value byte stays `0x00`), so the switch position is tracked by the plugin |

The firmware advertises ten `0xE9` values. `0x24` (PBP 50/50) and `0x27`
(PBP 20/80) are confirmed by a before/after VCP scan on another U4025QW
(rabfulton/Dell_U4025QW_Controller); the remaining ratios (`0x28` 80/20,
`0x29` 25/75, `0x2A` 75/25) and `0x21` (PIP top-right, small) were confirmed by
the user watching the screen. All six ratios plus the PIP positions are offered
as a chip grid. The remaining advertised PIP codes (`0x22`/`0x01`/`0x02`) were
refused on first probe but the same session's ratio refusals later turned out
to be transient, so they are offered as *assumed* PIP bottom-right /
bottom-left / top-left small (tooltip-marked); the large PIP variants have no
advertised code on this model. See `RESEARCH.md` for the full probing notes.

## How it works

The plugin ships a small `ddc-dell` bash backend next to its scripts; the
service and panel call it through `noctalia.runAsync`. The backend:

- detects the monitor with `ddcutil detect` and caches the I2C bus in
  `$XDG_RUNTIME_DIR`
- serializes every DDC transaction with `flock` (overlapping transactions
  garble each other) and writes with `--noverify` (the firmware applies
  writes asynchronously)
- re-detects the bus once after a failed transaction — a PBP transition
  re-enumerates the monitor and leaves the cached bus stale
- refuses VCP codes outside the whitelist

The service polls `getvcp` on the configured interval and publishes the parsed
state; the panel writes optimistically and re-reads afterwards so the UI
tracks what the firmware actually applied.

## Requirements

- `ddcutil` on `PATH` (and the usual I2C access: `i2c-dev` group or equivalent)
- a Dell monitor reachable over I2C (`ddcutil detect` must list it as `DEL:`)

## Settings

| Setting | Default | Meaning |
|---|---|---|
| `monitor` | `U4025QW` | Case-insensitive substring of the DDC model name; empty selects the first Dell monitor |
| `updateInterval` | `5000` | State polling interval in ms (2000–60000) |
| `kvmSwitch` | `true` | Show the experimental KVM USB switch in PBP mode |

## Caveats

- **KVM USB Switch is experimental**: `0xE7 0xFF00` is a strong cross-model
  inference (U2723QE gist), not verified on the U4025QW. It is only shown
  while PIP/PBP is on, where the OSD's "USB Switch" also lives — but test it
  with a second machine present before relying on it. The monitor does not
  report the switch position, so the plugin tracks it per session: the label
  reads *Unknown* until the switch is flipped once (and again after a
  Noctalia restart or a manual switch on the monitor's OSD). Switch ON means
  the USB upstream is routed to Thunderbolt; OFF means USB-C.
- PBP disables HDR and VRR/DRR on this monitor, and entering/leaving PBP drops
  DDC for a few seconds; the next poll recovers.
- All split ratios and the top-right PIP are user-confirmed. The other three
  PIP chips (`0x22`/`0x01`/`0x02`) carry *assumed* BR/BL/TL-small labels —
  click them and watch the screen to confirm or correct (see `RESEARCH.md`
  open question 1).
