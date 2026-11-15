# AppDimens for Roku — guide

## Instance

| Call | Result |
|---|---|
| `AppDimens(options)` | instance for this device, cached in the thread's global AA (each SceneGraph component and Task has its own) |
| `AppDimens_Refresh()` | re-reads the device (after a display-mode change) |
| `AppDimens_Create(options)` | uncached instance; `width`/`height` (coordinates), `mode`, `reference`, `density`, `fontScale`, `multiWindow`, `uiMode` |
| `AppDimens_CoordinateSpace()` | `{ name, width, height, autoscaled }` from the manifest's `ui_resolutions` and `roDeviceInfo.GetUIResolution()` |
| `AppDimens_Metrics(wDp, hDp, density, fontScale, multiWindow)` | raw snapshot (same inputs as every port) |

Fields: `width`, `height`, `sw` (dp), `density`, `fontScale`, `isLandscape`, `surfaceWidth`, `surfaceHeight`
(coordinates), `mode`, `uiMode`.

## Values

| Method | Result |
|---|---|
| `ad.sdp(v)` … 432 methods | `<prefix><s|h|w><dp|sp|em>[a|i|ia]`; `sp` × font scale |
| `ad.resolve(token, v)` | any token (inverters `Ph Lh Pw Lw`, `Px`); `invalid` when unknown |
| `ad.dimen("16asdp")` | `"<number><token>"`, also `dp`, `px`, `spaceW`, `spaceH`, `spaceSw`; `invalid` when malformed |
| `ad.dp(strategy, v, slot)` / `ad.sp(…)` | by strategy index or name and slot (`variant * 4 + flags`) |
| `ad.factor(strategy, slot)` | the factor itself |
| `ad.px(v)` | dp → coordinates (identity in reference mode) |
| `ad.fontSize(v, strategy)` | integer `Font.size` in coordinates (default strategy `scaled`) |
| `ad.xy(x, y, token)` / `ad.rect(x, y, w, h, token)` | `[x, y]` translation / `{ x, y, width, height }` through a token (default `sdp`) |
| `ad.safeRect("action" | "title")` | Roku safe zones (90 % / 80 %) in coordinates |
| `ad.spaceW(p)` / `ad.spaceH(p)` | `p` % of the width / height in dp |

## Which strategy on a TV

| Element | Token |
|---|---|
| layout, cards, rows, focus rings | `sdp` (reference mode keeps the mock-up's px) |
| long text, descriptions | `logssp` / `ad.fontSize(v, "logarithmic")` |
| hero art that must cover | `flsdp` · art that must stay whole: `ftsdp` |
| posters keeping a 2:3 grid on any space | `asdp` |
| a mobile design reused on TV | mode `"tv"` + the same tokens as Android |

## Threads

SceneGraph components and Tasks run in separate BrightScript contexts: call `AppDimens()` in each `init()`
(it reads the device once per context). Pass numbers, not the instance, across nodes.
