---
name: appdimens-roku
description: Responsive sizes for Roku channels (BrightScript / SceneGraph) with AppDimens — coordinate space from ui_resolutions, reference/tv modes, tokens, safe zones, font sizes and custom strategies.
---

# AppDimens for Roku

## Core idea

Mock-ups for Roku are usually 1920×1080 px. `AppDimens()` reads the channel's coordinate space (manifest
`ui_resolutions`: one entry → firmware autoscale, several → the device's resolution) and returns sizes in
coordinates. Never hard-code a scale such as `* 0.6667` for HD.

## Steps

1. Copy `source/AppDimens.brs` and `source/AppDimensTokens.brs` (and `AppDimensCustom.brs` for custom
   strategies) into the channel's `source/`; add both `<script>` tags to every component that sizes nodes.
2. In each component `init()`: `ad = AppDimens()` (one per BrightScript context; Tasks too).
3. Layout: `node.width = ad.sdp(720)`, `node.translation = ad.xy(96, 54)`; text: `font.size = ad.fontSize(32)`;
   long text: `ad.fontSize(28, "logarithmic")`; cover art: `flsdp`, whole art: `ftsdp`.
4. Keep focusable content inside `ad.safeRect("action")`, titles inside `ad.safeRect("title")`.
5. A design shared with Android TV/mobile in dp: `AppDimens({ mode: "tv" })` and `ad.px(ad.sdp(v))` /
   `ad.resolve("sdpPx", v)` for coordinates.

## Custom strategies

Only when the project declares `customStrategies` (or the user asks for their own rule):
`AppDimens_LoadStrategies(text)` once per component, `ad = AppDimens_Custom()`, then `ad.cdp(16, "id")`,
`ad.csp(14, "id")`; one-off math: `ad.cdp(64, "base * pow(sw / 360, 0.8)")`. Never invent ids.

## Don'ts

- Don't mix `Px` tokens with reference mode (values are already coordinates).
- Don't store the instance in node fields; call `AppDimens()` in each context.
- Don't hand-edit `AppDimensTokens.brs`; run `python3 tools/gen_tokens.py`.

## Verify

`npm test` (brs-engine: parity, tokens, modes, custom fixture, SceneGraph example with `fhd` and `hd,fhd`) and
`npx bsc --project bsconfig.json`; on a device, sideload `build/hello.zip` from `sh tools/build_example.sh`.

<!-- appdimens-family:begin -->
## Other AppDimens platforms

The same token names and math exist on Android (Compose, Views, XML), Kotlin Multiplatform, iOS/macOS, Flutter, React
Native, Web, .NET, Qt, GTK, LVGL, Roku, Python/Blender and games (Unity, Unreal, Godot, C/C++). For code on another
platform, use that library's skill — every skill, plus the layout-intent decision table, installs with
`npx appdimens-skills` (https://github.com/bodenberg/appdimens-skills). Hub: https://github.com/bodenberg/appdimens.
<!-- appdimens-family:end -->
