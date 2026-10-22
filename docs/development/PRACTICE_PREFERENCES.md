# Practice preferences and fixed test domain — 2026-10-22

Scope: Telegram48860. Mechanic-name locale, fresh-seed default, bottom instructions and dedicated Cloudflare named Tunnel.

## Behavior

- `catalog.json.names`: twenty IDs × `zh_TW`, `en`, `ja`. Keep canonical `name`/combat IDs unchanged; localized names are display-only. Chinese labels are readable community terminology, not asserted official Traditional Chinese localization. Missing locale labels fall back to canonical English.
- `mechanism_language` and `fresh_seed` persist through Godot ConfigFile alongside unrelated settings. Missing old-config preference defaults to fresh seeds; unknown locale falls back to zh_TW.
- Locale changes only update list and preview/HUD titles. Do not call prepare/filter/rebuild or discard selections/paused runtime.
- `start_run(checkpoint, new_seed=true)` samples a valid 1…2147483647 seed excluding the previous seed when enabled. Preview preparation never rerolls. New primary and segment starts follow the fresh-seed preference.
- R, Shift+R, the R hotbar action, explicit CLI demo seed and waymark-triggered restart pass `new_seed=false`. Resume and retry_beat preserve original state/seed.
- Fixed footer panels in setup/player view show movement, camera, actions and utility keys independently of Tab tools. P6/Tab rows are raised above them; the live 3D viewport stays full-window during practice. Preview sizing is independent of locale text.

## Verification

- Godot4.7.2 source setup/layout gate:498 checks/175 method selections,0 failures.
- Actual X11/Mesa render and behavior gate:97 checks,0 failures; three locale screenshots, native R input, repeated primary starts, fixed-seed42, config migration/persistence, unrelated settings preservation, footer visibility and overlap.
- Existing presentation/input/marker regressions are recorded in docs/VALIDATION.md.
- Web snapshot is exported for user testing. Transport/HTTPS/hash checks are not browser gameplay certification. Previous VPS browser probe hit its900MiB resource limit; no unbounded repeat or universal browser-compatibility claim.

## Deployment

- Public test URL: https://top.servicing.cc . Dedicated named Tunnel; apex servicing.cc and other endpoints unchanged.
- Origin remains127.0.0.1:18850, user service top-web; named connector top-web-tunnel. Both enabled. Tunnel credentials stay outside Git; this document contains no credential values.
- Versioned Web executable filenames prevent mixing cached old PCK/JS with the new root HTML. Root HTML is revalidated; immutable snapshots retain rollback via public symlink and service restart.
- Fixed hostname survives connector/VPS restart. Availability still depends on VPS and Cloudflare; not a claim of guaranteed uptime.
