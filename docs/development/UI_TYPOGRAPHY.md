# v0.3.6 embedded typography correction

## Root cause

The old variable Noto Sans TC ui.ttf covered only1,482 characters; its emergency
fallback covered31. Against current runtime scripts/data,70 CJK/kana/punctuation
characters were absent. The variable face had its default weight at100 (Thin),
not the normal400, despite the name-table style saying Regular. Host fonts could
hide coverage errors on native machines but were not a portable Web solution.

## Fix

- Ship unsubsetted Noto Sans CJK TC Regular400 (44,810 Unicode mappings).
- Ship unmodified DejaVu Sans as a small symbol fallback for rotation arrows.
- Keep upstream bytes/digests, exact sources and licenses under top/fonts.
- Share ui.tres between Control themes, all six Label3D factories and waymark drawing.
- Disable host-system font fallback on both imported faces.
- Place P6/tool controls above bottom instructions using their combined minimum
  height; do not alter preview size when selecting mechanisms or languages.
- Packaging includes the symbol font license; existing releases stay immutable.

## Validation

`python3 tools/audit_ui_font.py` requires fonttools and checks file digests,
static Regular weight, non-subset coverage and all current non-ASCII printable
characters in runtime GDScript/data JSON. Current result:753 unique characters,
zero missing. It includes Japanese kana/full-width punctuation and rotation signs.

Pinned Godot4.7.2 loaded both embedded faces with host fallback disabled, verified
all753 characters, weight400 and24 actual scene Label3D instances. Deterministic
setup498, rendered preferences97, presentation27 and input20 checks pass:642 total.
Native screenshots include zh_TW/en/ja, practice and advanced settings. Initial
normal-font P6 overlap was detected by presentation and fixed before acceptance.

These are native renderer/source-font checks, not browser gameplay certification.
The VPS browser is not rerun through the known900MiB/OOM path. Web export and
public resource/pack validation are recorded separately in deployment evidence.
