<div align="center">

# AppDimens for Roku

**Design the 10-foot UI once. The same SceneGraph screens keep their proportions in FHD, HD and SD coordinate spaces, stay inside the Roku safe zones, and share their sizing tokens with your Android TV, mobile and web apps.**

[![Release](https://img.shields.io/badge/release-3.2.0-1d4ed8.svg)](CHANGELOG.md)
[![Roku](https://img.shields.io/badge/Roku-BrightScript%20%7C%20SceneGraph-6c3c97.svg)](#install)
[![Tests](https://img.shields.io/badge/tests-brs--engine%20%2B%20bsc-15803d.svg)](#precision-and-tests)
[![License](https://img.shields.io/badge/license-Apache%202.0-15803d.svg)](LICENSE)

Part of the [AppDimens family](https://github.com/bodenberg/appdimens) — same tokens and math as Android, iOS, Flutter, React Native, Web, .NET, Qt, GTK, LVGL, Python and Games.

🇧🇷 [Resumo em português](#-resumo-em-português)

</div>

## Install

Plain BrightScript, no build step and no dependencies. Copy the files into your channel's `source/`:

| File | What |
|---|---|
| `source/AppDimens.brs` | core: strategies, token parser, Roku coordinate space, safe zones, fonts (required) |
| `source/AppDimensTokens.brs` | 432 token methods: `ad.sdp`, `ad.asdpa`, `ad.logssp`, `ad.ftwem` … (required) |
| `source/AppDimensCustom.brs` | custom strategies: shared JSON document and text formulas (optional) |

In a SceneGraph component, include them next to your script:

```xml
<script type="text/brightscript" uri="pkg:/source/AppDimens.brs" />
<script type="text/brightscript" uri="pkg:/source/AppDimensTokens.brs" />
```

## First lines of code

```brightscript
sub init()
    ad = AppDimens()                         ' this device, cached per thread
    safe = ad.safeRect("title")              ' Roku title-safe zone (80 %), in coordinates

    card = m.top.findNode("card")
    card.translation = [safe.x, safe.y]
    card.width = ad.sdp(720)                 ' px on your 1920×1080 mock-up → coordinates now
    card.height = ad.sdp(360)

    font = CreateObject("roSGNode", "Font")
    font.uri = "font:MediumBoldSystemFontFile"
    font.size = ad.fontSize(48)              ' integer, never below 1
    m.top.findNode("title").font = font

    gap = ad.resolve("asdpa", 24)            ' any token: strategy + axis + flags
    pad = ad.dimen("16hdpLw")                ' "<number><token>"
end sub
```

## Coordinate space and modes

Roku draws SceneGraph in the resolution your manifest declares:

- `ui_resolutions=fhd` (one entry) — coordinates are always 1920×1080 and the firmware scales the
  picture on HD devices. AppDimens reads this and keeps your values as they are.
- `ui_resolutions=hd,fhd` (several) — the channel runs in the device's own UI resolution (1280×720 or
  1920×1080) and must scale itself. AppDimens does it: `ad.sdp(96)` is 96 on FHD and 64 on HD.

| Mode | Use it when | Plain tokens return |
|---|---|---|
| `"reference"` (default) | your mock-ups are in px at 1920×1080 (or `reference: { width, height }`) | coordinates (`ad.sdp(96)` → 96 at the reference) |
| `"tv"` | you share dp tokens with Android TV / mobile: 960×540 dp on every 16:9 resolution | dp; `ad.px(v)` / `…Px` tokens → coordinates |
| `"pixel"` | you author directly in coordinates | coordinates, density 1 |

```brightscript
ad = AppDimens({ mode: "tv" })
label.translation = [ad.px(ad.sdp(48)), ad.resolve("sdpPx", 27)]
```

## Tokens

`<prefix><s|h|w><dp|sp|em>[a|i|ia]` as methods, the full grammar (`Ph`/`Lh`/`Pw`/`Lw` inverters, `Px`) through
`ad.resolve(token, v)` and `ad.dimen("16sdpPxa")`. Prefixes: `""` scaled, `a` auto, `p` percent, `pw` power,
`f` fluid, `i` interpolated, `log` logarithmic (best for long TV text), `dg` diagonal, `pr` perimeter,
`ft` fit, `fl` fill, `d` density. More: [docs/GUIDE.md](docs/GUIDE.md).

## Custom strategies

Your own rule, with the same JSON document and text formulas as every AppDimens platform:

```brightscript
err = AppDimens_LoadStrategies(ReadAsciiFile("pkg:/config/custom-strategies.json"))   ' "" = ok
ad = AppDimens_Custom()
pad = ad.cdp(16, "brand")
txt = ad.csp(14, "readableText")
hud = ad.cdp(64, "base * pow(sw / 360, 0.8)")
```

`tvSafe`, `readableText` and the other presets apply their TV rules on Roku (device class `tv`).
Details: [docs/CUSTOM.md](docs/CUSTOM.md).

## Precision and tests

- **Parity:** the suite checks all 10 560 factors (12 strategies × 44 slots × 20 screens) against vectors generated
  from `appdimens-dynamic`'s own kernels — BrightScript `Float` is IEEE-754 binary32, like the reference — and the
  540-case cross-platform custom-strategy fixture.
- **Cost:** a token method is one table read and one multiply; each strategy's 44 factors are computed on first use.
- **Tested** in the BrightScript simulator [brs-engine](https://github.com/lvcabral/brs-engine) (`npm test`: 232 checks
  plus the SceneGraph example under `ui_resolutions=fhd` and `hd,fhd`) and validated by the BrighterScript compiler
  (`npx bsc`). `tests/` is also a sideloadable channel for a real device.

## 🇧🇷 Resumo em português

AppDimens para Roku (BrightScript/SceneGraph): copie `source/AppDimens.brs` e `source/AppDimensTokens.brs` para o seu
canal, chame `ad = AppDimens()` e use `ad.sdp(96)`, `ad.fontSize(32)`, `ad.safeRect("title")`, `ad.resolve("asdpa", 24)`.
O modo `"reference"` (padrão) recebe px do mock-up em 1920×1080 e devolve coordenadas, respeitando o
`ui_resolutions` do manifest; o modo `"tv"` usa o espaço dp do Android TV (960×540) para compartilhar tokens.
Estratégias custom (`AppDimensCustom.brs`) usam o mesmo JSON e fórmulas das outras plataformas. Testado com
brs-engine e validado com o compilador BrighterScript.

## Author

Jean Bodenberg — [AppDimens hub](https://github.com/bodenberg/appdimens) · Apache-2.0
