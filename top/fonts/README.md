# Embedded UI typography

`ui.tres` uses the **complete static Noto Sans CJK TC Regular (400)**, not a
text-dependent subset or a variable font whose default weight is Thin (100).
The TC face follows Traditional Chinese glyph forms and also covers Japanese
kana and the current English/Japanese mechanic names. DejaVu Sans is a
complete companion for rotation arrows and other non-CJK signs.

Noto is SIL OFL 1.1 (CJK-OFL.txt); DejaVu uses its Bitstream Vera / DejaVu
license (SYMBOLS-LICENSE.txt). Exact upstream URLs,
SHA256 digests and coverage counts are recorded in manifest.json. Do not rebuild
these into hand-maintained subsets: new UI wording must not create missing glyphs.

Use the same resource for Control themes, Label3D and drawn waymark text, rather
than a host-specific SystemFont. `python3 tools/audit_ui_font.py` (fonttools)
checks the shipped font bytes and all non-ASCII printable characters used in
runtime GDScript and data JSON, including full-width punctuation and kana.
