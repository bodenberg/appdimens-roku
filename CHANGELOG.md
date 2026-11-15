# Changelog

## 3.2.0 — first release

- BrightScript / SceneGraph port of AppDimens 3.2: 12 strategies, 11 axis variants, flags `a`/`i`/`ia`, kinds
  `dp`/`sp`/`em`, `Px`, the token grammar (`ad.resolve`, `ad.dimen`) and 432 generated token methods.
- Roku coordinate space from the manifest's `ui_resolutions` (single entry → firmware autoscale; several → the
  device's UI resolution); modes `reference` (px at 1920×1080 → coordinates), `tv` (Android TV 960×540 dp space)
  and `pixel`; safe zones, integer font sizes, translation/rect helpers.
- Custom strategies (`AppDimensCustom.brs`): shared JSON document, text formulas, code factors/formulas, rules,
  built-ins and presets.
- Tests in brs-engine: 10 560 parity factors from appdimens-dynamic, tokens, modes, the 540-case custom fixture and
  the SceneGraph example under two manifests; BrighterScript validation in CI.
