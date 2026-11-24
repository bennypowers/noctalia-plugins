# Dell U4025QW DDC/CI — Reverse-Engineering Notes

Research for the `ddc-dell` bar widget: a human-readable DDC/CI controller for the
Dell U4025QW, executed through `ddcutil`. Focus: mapping Dell's undocumented
"Manufacturer specific" VCP codes (0xE0–0xF0) to human-readable options,
including PIP/PBP and KVM.

## 1. Target monitor (live unit)

| | |
|---|---|
| Model | DELL U4025QW (UltraSharp 40 Curved Thunderbolt Hub) |
| Panel | 39.7" 21:9, 5120×2160, 120 Hz, IPS Black, DisplayHDR 600 |
| Serial | 95G5934 (product code 0x430F) |
| Bus | `/dev/i2c-12`, DRM connector `card0-DP-1`, VCP/MCCS 2.1 |
| Video inputs (exactly 3) | **DisplayPort 1.4**, **HDMI 2.1**, **Thunderbolt 4 upstream** (140 W) |
| Other | USB-C upstream + USB-A hub, 2.5 GbE RJ45, KVM, 5 W×2 speakers, TB4 downstream (daisy chain), iMST, DPBS |

The user's computer is plugged into **DP (0x0F)**; a second source is on **TB4 (0x19)**
(PBP with TB4 as sub-window works, so a live signal is present there).

### ddcutil capability string (manufacturer-specific part)

```
E2(00 02 04 0C 0D 0F 10 11 13 0B 1A 1B 3D 14 27 23 24 3A)
E4(00 01)  E5  E7(02 03)  E8  E9(00 01 02 21 22 24 27 28 29 2A)
EA(FE FC)  F0(09 0A A1 31 32 34 36)  EE  EF(00 01 0F)  F1  F2  FD
```

Standard features present: 10, 12, 14, 16/18/1A (RGB gain), 60, 62, 66, 87 (sharpness),
CA (OSD), CC (language), D6 (power), DC.

## 2. Standard (MCCS) codes — verified on this unit

| Code | Feature | Values (verified via capabilities / live reads) |
|---|---|---|
| `0x10` | Brightness | continuous 0–100 (read: `VCP 10 C 48 100`) |
| `0x12` | Contrast | continuous 0–100 |
| `0x14` | Color preset | `01` sRGB, `04` 5000 K, `05` 6500 K, `06` 7500 K, `08` 9300 K, `09` 10000 K, `0B` User 1, `0C` User 2 |
| `0x60` | Input source | `0x0F` DisplayPort, `0x11` HDMI, **`0x19` Thunderbolt** (non-standard code; ddcutil prints "Unrecognized value" for 0x19 in `capabilities`, but it is the TB4 input — matches the monitor's physical port list) |
| `0x62` | Volume | continuous 0–100 |
| `0x8D` | Mute | `00` on, `01` muted (standard MCCS speaker state) |
| `0xDC` | Display mode | `00` Standard, `03` Movie, `05` Game |
| `0xD6` | Power | `04` on / `05` off (write-only) — optional |

Reference input-code table (montools, generic Dell): `01` VGA1, `02` VGA2, `03` DVI1,
`04` DVI2, `0F` DP1, `10` DP2, `11` HDMI1, `12` HDMI2, `1B` USB-C. On the U4025QW the
TB4 upstream is `0x19` instead of `0x1B`.

## 3. Dell "Manufacturer specific" codes — findings

### 0xE9 — PIP/PBP mode (layout/split selector) — **main feature**
- Advertised values: `00 01 02 21 22 24 27 28 29 2A`
- **Verified live (second session, 2026-11-05):** `0x00` = Off, `0x24` = PBP 50/50,
  `0x27` = PBP 20/80 (both confirmed by a before/after `getvcp scan` diff on another
  U4025QW: rabfulton/Dell_U4025QW_Controller captures 20260418T224653Z / 225946Z).
- **All of `21 24 27 28 29 2A` accept writes** on this unit — from Off *and* while a
  layout is active. `0x22`, `0x01`, `0x02` are refused (read-back stays put) from
  every state tried. The earlier "only 0x24 works" finding was a transient refusal
  (retried later the same day, all ratios accepted).
- **Ratio labels confirmed by the user** (watching the screen during the
  2026-11-05 probe): `0x24` 50/50, `0x27` 20/80, `0x28` 80/20, `0x29` 25/75,
  `0x2A` 75/25. **`0x21` = PIP top-right, small** (user-confirmed the same day).
- **PIP position codes (user's assumed mapping, to verify by clicking):** the
  user expects the positions to continue in code order — `0x22` = PIP bottom-
  right small, then bottom-left and top-left small — followed by the same
  orientations large. Only `01 02 21 22` are advertised, so the plugin offers
  `0x22` (BR small), `0x01` (BL small), `0x02` (TL small) as *assumed* (tooltip
  marked); the large variants have no advertised code on this model and are not
  offered. Note the ddc-kvm cross-reference calls `0x01` "PIP big" on the
  U2723QE, so the 0x01/0x02 labels are the weakest of the set.
- All offered values were accepted or refused per state during probing; `0x22`/
  `0x01`/`0x02` were refused when first tried, but the ratio refusals of the
  same session later turned out to be transient, so the PIP buttons may still
  work — they are no-ops if the firmware refuses them.
- Entering/exiting/changing a layout re-hotplugs the monitor and drops DDC for
  ~1–4 s ("EDID has changed"); the backend's stale-bus retry handles it.
- Cross-references:
  - U2723QE gist (lainosantos): `E9 0x00` off, `0x01` PIP big, `0x02` toggle PIP
    position, `0x21` PIP small, `0x24` PBP.
  - jason-c-dev/ddc-kvm `dell-vcp-codes.md`: same family, plus `0x41` 2x2
    "Screen Partition" (not advertised on the U4025QW).
  - omarchy U4924DW plugin (St1aan): `0x00` off, `0x24` PBP; `0x21 0x22 0x01 0x02
    0x2D 0x2E` unidentified.

### 0xE8 — PBP sub-window input — **verified**
- Complex feature (`CNC`), value in `sl`, no advertised list.
- **Verified live:** with PBP active, writes of `0x0F` (DP), `0x11` (HDMI), `0x19`
  (TB4) were all accepted and read back; corresponds to the OSD "PIP/PBP (Sub)" menu
  (Thunderbolt / DP / HDMI).
- Default on this unit: `0x19` (TB4).

### 0xE5 — PBP enable flag + actions — **verified**
- **PBP enable flag (state):** `sl` reads `0x00` with PIP/PBP off and `0xFF` when on
  (confirmed on this unit live *and* in the rabfulton U4025QW captures). The
  firmware sets it when `E9` changes; no explicit write is needed.
- **Action:** `E5 0xF001` = **Video Swap** (verified live: swaps main ↔ sub window —
  VCP `60` and `E8` exchange values; OSD item "Video Swap"). Accepted even with PBP
  off, where it is a no-op; effective only while PIP/PBP mode is on.
- U2723QE gist: `E5 0xF001` "switch video sources in pip/pbp mode" — consistent.
- U2723QE also used `E5 0xFF00`-style codes for USB switching; untested here.

### 0xE7 — KVM / USB upstream — **untested (risky), strong cross-references**
- Advertised values: `02 03` (enum). Live read returns odd data
  (`mh=0xbc ml=0x00 sh=0xac sl=0x00` on 2026-11-05) — an action-style or
  bitfield register, not a plain value register.
- **Re-read 2026-11-23:** `mh=0xbc ml=0x00 sh=0xb8 sl=0x00`, stable across
  repeated reads. The value byte `sl` stays `0x00` — never the advertised
  `02/03` — so there is **no usable state readback** the way E5/E8 have. But
  the `sh` byte moved `0xAC → 0xB8` between sessions: its bits 5:4 decode to
  exactly `02 → 03` (the advertised values), while bits 3:2 also moved
  (`11 → 00`), so a single KVM flip can't fully explain the diff — probably a
  multi-field register (KVM position + e.g. an Ethernet/USB-assignment flag).
  The state is plausibly readable as bits 5:4 of `sh`, but that needs one
  supervised flip (read, flip, read) to confirm, plus the user identifying
  which output (USB-C vs Thunderbolt) each position routes to. The plugin now
  polls `E7` (harmless) but tracks the switch position optimistically in the
  `ddc` state's `kvm` key (0/1, nil until first flipped; carried through
  service polls), with an assumed USB-C/Thunderbolt label mapping.
- NOT written during probing: it can steal the user's keyboard/mouse.
- Cross-references:
  - U2723QE gist: `E7 0xFF00` = momentary "switch USB hub target in pip/pbp mode"
    (KVM switch, only in PIP/PBP).
  - montools (rballonline): on U4919DW, `E7` is a 16-bit **USB upstream mapping
    register** — low byte holds a 2-bit slot per video input (MSB first
    DP·USB-C·HDMI2·HDMI1), slot value = upstream port (0=USB-B1, 1=USB-B2, 2=USB-C),
    high byte 0xFF preserved. E.g. `0xFF21`.
  - OSD: "USB Switch" (switch between USB upstream sources, **only in PIP/PBP mode**)
    and the USB menu ("DP assign to USB-C", "HDMI assign to USB-C", Ethernet
    Switch Mode: Tie to KVM / Prompt when KVM switches / Switch Manually, Ethernet
    Switch, Reset USB).
- Working assumption for the widget: a momentary `E7 0xFF00` "Switch KVM (USB)"
  action button, PBP-only, marked experimental — **to be tested with the user
  present** before shipping.

### Unknown / unassigned
| Code | Advertised | Notes |
|---|---|---|
| `0xE2` | `00 02 04 0C 0D 0F 10 11 13 0B 1A 1B 3D 14 27 23 24 3A` | 18 values incl. input-like codes; writes refused (stayed `0x00` even with PBP on). Not the sub-input. Unknown. |
| `0xE4` | `00 01` | Toggle, currently `0x01`. Not probed (could be iMST "Screen Partition", DPBS, or similar — toggling may reshape the display topology). Unknown. |
| `0xE0`, `0xE1` | — | No values advertised. |
| `0xEA` | `FE FC` | Reads `0xff..`; unknown. |
| `0xEF` | `00 01 0F` | `0x00`; unknown. |
| `0xF0` | `09 0A A1 31 32 34 36` | `0x00`; unknown. |
| `0xEE`, `0xF1`, `0xF2`, `0xFD` | — | Unknown. |

## 4. ddcutil mechanics (from live probing)

- Detect: `ddcutil detect --terse` → blocks with `I2C bus: /dev/i2c-N` and
  `Monitor: DEL:<MODEL>:<SERIAL>`; select bus where manufacturer is `DEL:` and model
  matches (optional substring filter, case-insensitive).
- Read: `ddcutil --bus N getvcp --terse <codes...>`; terse line formats:
  - `VCP 10 C 48 100` — continuous: current, max
  - `VCP 14 SNC x05` — simple non-continuous: value
  - `VCP E9 CNC x00 xff x00 x00` — complex: `mh ml sh sl`; **the value lives in `sl`**
- Write: `ddcutil --bus N --noverify setvcp <code> <value>`.
  - **`--noverify` is required**: the monitor applies writes asynchronously (~1 s for
    E9), so strict verify fails even when the write works.
  - The firmware *refuses* invalid values: read-back simply stays at the old value.
- **Transactions must be serialized** (overlapping DDC transactions garble each
  other). The omarchy reference implementation serializes with `flock` and caches the
  bus in `$XDG_RUNTIME_DIR`.
- **Bus can go stale**: after a PBP transition (or hotplug) the monitor re-enumerates
  ("EDID has changed"); retry once on a freshly detected bus.
- Baseline state on this unit (restore after experiments): brightness 48, contrast
  75, preset `05` (6500 K), input `0F` (DP), volume 74, mute `00`, mode `00`,
  `E8 0x19`, `E9 0x00`.

## 5. OSD structure (U4025QW user guide — relevant parts)

- **PIP/PBP menu**: PIP/PBP Mode (Off, 50/50, 80/20, 20/80, 75/25, 25/75) · PIP/PBP
  (Sub) [TB4/DP/HDMI] · USB Switch · Video Swap · Audio (main/sub) · Contrast (Sub).
  All sub-items available **only when PIP/PBP mode is enabled**.
  NOTE: PBP/PIP and Screen Partition do **not** support HDR or VRR/DRR.
- **USB (KVM) menu**: DP assign to [USB-C] · HDMI assign to [USB-C] · Ethernet
  Switch Mode (Tie to KVM / Prompt when KVM switches / Switch Manually) · Ethernet
  Switch · Show KVM Setup Guide · Reset USB.
  "No additional USB cable needed for Thunderbolt video" (TB carries USB upstream).
- **Screen Partition (DP/TBT)**: iMST partitioning, Off + refresh rate 60/120 Hz
  (DP/TB only).
- **Shortcut key 3** cycles: Aspect Ratio, Volume, Speaker, PIP/PBP Mode, USB.
- **DPBS** (Dell Power Button Sync) under Display menu.

## 6. Widget feature plan (human-readable layer over ddcutil)

Sliders: Brightness (`10`), Contrast (`12`), Volume (`62`) · Toggle: Mute (`8D`)
· Choice rows: Color preset (`14`), Display mode (`DC`), Input (`60`: DP / HDMI /
Thunderbolt)
· PIP/PBP section with an **on/off switch in the header** (off = `0x00`, on
  = PBP 50/50), split into a **Picture-By-Picture** chip row (the six
  user-confirmed ratios) and a **Picture-In-Picture** chip row (TR small
  confirmed; BR/BL/TL small assumed), Sub-window input (`E8`, visible in PBP),
  **Video Swap** button (`E5 0xF001`, PBP), **KVM USB Switch** button
  (`E7 0xFF00` presumed, PBP, experimental — test first).

## 7. Open questions

1. (RESOLVED 2026-11-05) Ratios confirmed by the user: `0x28` = 80/20,
   `0x29` = 25/75, `0x2A` = 75/25; `0x21` = PIP top-right small.
   REMAINING: verify the assumed PIP labels for `0x22`/`0x01`/`0x02` by clicking
   the buttons (and whether the writes work at all — earlier refusals may have
   been transient).
2. `E7` semantics on this model: enum `02/03` (which PC?) vs momentary `0xFF00`?
   Needs a supervised test with the user (keyboard/mouse follow the switch).
   (RESOLVED: the earlier `E9` mass-refusal was transient — all accepted values
   work from Off and from an active layout; `22/01/02` remain genuinely refused.)
   (2026-11-23: user-confirmed the KVM control is binary — it toggles between
   two outputs (USB-C / Thunderbolt). The panel now offers it as a switch with
   plugin-tracked position; remaining: supervised read/flip/read to confirm the
   `sh` bits 5:4 = `02/03` hypothesis and the value→output mapping.)
   (2026-11-24: switch semantics fixed with the user — the monitor's OSD
   shows "Upstream:" <output>, so the state is checkable by eye any time.
   The switch reads ON when USB is routed to Thunderbolt and OFF when it is
   on USB-C; the tracked `kvm` key holds the index of the active output in
   `kvmOutputs` = { USB-C, Thunderbolt }.)
3. `E2` / `E4` / `EA` / `EF` / `F0` meanings.
4. Whether "Audio (main/sub)" (PBP audio source) has a DDC code (maybe `EA` or `F0`).
5. Whether the OSD USB-menu KVM *assignments* ("DP assign to USB-C", Ethernet
   Switch Mode) map onto `E7`'s bitfield (cf. montools' U4919DW mapping register) —
   writing is risky (steals the keyboard), untested; the omarchy plugin only
   ships the `0xFF00` momentary, which we match.

## 8. Implementation status (plugin built)

The `ddc-dell` plugin now exists in this repo (v1.0.0, `plugin_api` 24):

- `ddc-dell` (bash backend) — detect + bus cache in `$XDG_RUNTIME_DIR`, `flock`
  serialization, `--noverify` writes, one stale-bus retry; `state` prints raw
  terse `getvcp` lines, `set` is whitelist-only (`10 12 14 60 62 8D DC E8 E9`),
  `action swap|kvm` writes `E5 0xF001` / `E7 0xFF00` (both verified accepted by
  ddcutil; `swap` is a no-op with PBP off, as expected).
- `service.luau` — polls `state` every `updateInterval` (default 5 s), parses
  with `lib/model.luau` (pure-Lua, covered by `tests/test_ddc_model.lua`),
  publishes `noctalia.state` key `ddc`.
- `widget.luau` — `device-tv` glyph + brightness %; tooltip lists input, PBP
  state and sub-input; click opens the panel.
- `panel.luau` — brightness/contrast/volume sliders (commit on release, the
  host suppresses value re-apply mid-drag), mute toggle, preset/mode selects,
  input select with a **confirm step** before switching away from the current
  input (the omarchy plugin's second-click guard, adapted to a panel row),
  PIP/PBP section: layout chip grid with every offered `E9` value (six PBP
  ratios user-confirmed; PIP TR small confirmed, PIP BR/BL/TL small assumed with
  Tabler corner icons), sub-window input, **Video Swap** and
  **KVM USB Switch** buttons (PBP-only; KVM gated by the `kvmSwitch` setting and
  labelled experimental). Second session (2026-11-05): re-probed `E9` with fresh
  cross-references (rabfulton U4025QW captures, ddc-kvm reference) — all of
  `21/24/27/28/29/2A` accept writes, `22/01/02` are refused; `E5`'s PBP-enable flag
  confirmed (`sl` 0x00/0xFF).
- Optimistic writes + silent post-write re-read; a failed poll (the PBP
  transition DDC drop) does not flash the panel/widget into an error state —
  the last good state is kept until a poll succeeds.
- Catalog row added; validator, `noctalia plugins lint`, and all `tests/*.lua`
  pass.

Still open from §7: (1) confirm which split `0x24` yields; (3) supervised
`E7 0xFF00` KVM test with a second machine present — the button is live in
the panel behind the `kvmSwitch` setting, ready for that test; (4)–(5) the
`E2/E4/EA/EF/F0` codes are still unmapped and intentionally unoffered.

## 9. Sources

- **Live probing** of the user's U4025QW on `/dev/i2c-12` (this session; all
  experiments restored to baseline).
- St1aan/omarchy-dell-display — Omarchy bar plugin for the U4924DW; reference for
  option tables (Model.js) and a serialized bash ddcutil backend (`dell-display`,
  flock + bus cache). Cloned at `/tmp/omarchy-dell-display`.
- rabfulton/Dell_U4025QW_Controller — dedicated U4025QW controller project with
  before/after `getvcp scan` captures: confirmed `E9 0x24` = PBP 50/50, `E9 0x27`
  = PBP 20/80, and `E5`'s PBP-enable flag (`sl` 0x00/0xFF).
- jason-c-dev/ddc-kvm `dell-vcp-codes.md` — cross-model Dell VCP reference: input
  codes (`0x19` TB4, `0x1B` USB-C), `E7` KVM/USB mapping, `E5 0xF001` swap, `E9`
  family (`0x01` PIP big, `0x21` PIP small, `0x41` 2x2 partition).
- rballonline/montools — Tauri KVM/switcher; `kvm.rs` (U4919DW `E7` USB mapping
  register) and `inputs.rs` (Dell input-code table).
- gist lainosantos/06d233f6c586305cde67489c2e4a764d — U2723QE KVM/PIP/PBP script
  (`E9`/`E5`/`E7` action codes).
- Dell U4025QW User's Guide (PDF via B&H, archived copy) → text at `/tmp/u4025qw.txt`
  (OSD menus: PIP/PBP, USB/KVM, Screen Partition, shortcut keys).
- ddcutil docs (`ddcutil.com`) — terse output formats, verify behavior.
