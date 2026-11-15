# Changelog

## Latest — in production (`main`)
- Global token functions, the AppDimens way (like `sdp(16)` on the Web / React Native): `sdp(720)`, `asdpa(24)`, `logssp(28)` … for all 432 tokens, over `AppDimens()`.
- Custom strategies: global `cdp(16, "brand")` / `csp(14, "brand")` and the `"16cdp-brand"` / `"14csp-brand"` literals in `ad.dimen` (like webdimens).

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
