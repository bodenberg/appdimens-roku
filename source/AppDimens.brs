' ─────────────────────────────────────────────────────────────────────────────────────────────
' AppDimens for Roku (BrightScript / SceneGraph) 3.2.0 — responsive sizes for the 10-foot UI.
' Port of the appdimens-dynamic kernels: 12 strategies × 11 axis variants × flags (a, i, ia),
' kinds dp / sp / em, Px, token grammar, parity-tested against vectors from the reference.
'
'   ad = AppDimens()                  ' per-thread cached instance for this device
'   label.translation = [ad.sdp(96), ad.sdp(54)]
'   font.size = ad.fontSize(32)       ' integer, never below 1
'   ad.resolve("asdpa", 24) : ad.dimen("16hdpLw")
'   card.width = sdp(720)            ' global token functions (like sdp(16) on the Web): sdp, asdp, ssp …
'
' Include in components: <script type="text/brightscript" uri="pkg:/source/AppDimens.brs" />
'                         <script type="text/brightscript" uri="pkg:/source/AppDimensTokens.brs" />
' Copyright 2026 Jean Bodenberg — Apache-2.0
' ─────────────────────────────────────────────────────────────────────────────────────────────

function AppDimens_Version() as string
    return "3.2.0"
end function

function AppDimens_Strategies() as object
    return ["scaled", "auto", "percent", "power", "fluid", "interpolated", "logarithmic", "diagonal", "perimeter", "fit", "fill", "density"]
end function

function AppDimens_Prefixes() as object
    return ["", "a", "p", "pw", "f", "i", "log", "dg", "pr", "ft", "fl", "d"]
end function

' Axis variants: qualifier (0 sw, 1 height, 2 width) and inverter of each of the 11 variants.
function AppDimens__VariantQ() as object
    return [0, 1, 2, 0, 0, 0, 0, 1, 1, 2, 2]
end function

function AppDimens__VariantInv() as object
    return [0, 0, 0, 7, 5, 8, 6, 1, 3, 2, 4]
end function

' Per-thread instance built from the device (cached in the thread's global AA).
'   options (optional): see AppDimens_Create.
function AppDimens(options = invalid as dynamic) as object
    g = GetGlobalAA()
    if options = invalid and g.appdimens_instance <> invalid then return g.appdimens_instance
    ad = AppDimens_Create(AppDimens_DeviceOptions(options))
    g.appdimens_instance = ad
    return ad
end function

' Re-reads the device (e.g. after a display-mode change). Returns the new instance.
function AppDimens_Refresh(options = invalid as dynamic) as object
    GetGlobalAA().appdimens_instance = invalid
    return AppDimens(options)
end function

' Coordinate space of this channel: with a single entry in the manifest's ui_resolutions the
' firmware auto-scales from that resolution (coordinates stay in it); with several, the one that
' matches the device is used.
function AppDimens_CoordinateSpace() as object
    sizes = { sd: [720, 480], hd: [1280, 720], fhd: [1920, 1080] }
    di = CreateObject("roDeviceInfo")
    ui = di.GetUIResolution()
    list = ""
    info = CreateObject("roAppInfo")
    if info <> invalid then list = LCase(info.GetValue("ui_resolutions"))
    names = []
    for each part in list.Split(",")
        p = part.Trim()
        if sizes.DoesExist(p) then names.Push(p)
    end for
    if names.Count() = 1 then
        s = sizes[names[0]]
        return { name: names[0], width: s[0], height: s[1], autoscaled: true }
    end if
    w = 1280
    h = 720
    n = "hd"
    if ui <> invalid then
        w = ui.width
        h = ui.height
        n = LCase(ui.name)
    end if
    return { name: n, width: w, height: h, autoscaled: false }
end function

function AppDimens_DeviceOptions(options = invalid as dynamic) as object
    o = {}
    if options <> invalid then o.Append(options)
    if o.width = invalid or o.height = invalid then
        cs = AppDimens_CoordinateSpace()
        o.width = cs.width
        o.height = cs.height
        o.coordinateSpace = cs.name
    end if
    if o.uiMode = invalid then o.uiMode = "television"
    return o
end function

' Builds an instance.
'   width/height: coordinate space in UI px (default: the channel's coordinate space)
'   mode: "reference" (default) — design values are px at `reference` (default 1920×1080);
'                                 plain tokens return coordinates directly.
'         "tv"        — Android TV dp space (960×540 on every 16:9 resolution); plain tokens return
'                       dp, *Px tokens / ad.px() return coordinates (share tokens with mobile/TV apps).
'         "pixel"     — density 1: dp = coordinates.
'   reference: { width, height } (reference mode), fontScale (default 1), multiWindow (default false),
'   density (explicit override), uiMode (default "television").
function AppDimens_Create(options = invalid as dynamic) as object
    o = {}
    if options <> invalid then o.Append(options)
    w = 1920.0
    h = 1080.0
    if o.width <> invalid then w = o.width * 1.0
    if o.height <> invalid then h = o.height * 1.0
    mode = "reference"
    if o.mode <> invalid then mode = LCase(o.mode)
    shortSide = w
    if h < w then shortSide = h
    d = 1.0
    if o.density <> invalid then
        d = o.density * 1.0
    else if mode = "tv" then
        d = shortSide / 540.0
    else if mode = "pixel" then
        d = 1.0
    else
        mode = "reference"
        rw = 1920.0
        rh = 1080.0
        if o.reference <> invalid then
            if o.reference.width <> invalid then rw = o.reference.width * 1.0
            if o.reference.height <> invalid then rh = o.reference.height * 1.0
        end if
        rs = rw
        if rh < rs then rs = rh
        d = rs / 300.0
    end if
    if not (d > 0.0) then d = 1.0
    fs = 1.0
    if o.fontScale <> invalid then fs = o.fontScale * 1.0
    mw = false
    if o.multiWindow = true then mw = true
    ad = AppDimens_Metrics(w / d, h / d, d, fs, mw)
    ad.mode = mode
    ad.surfaceWidth = w
    ad.surfaceHeight = h
    ad.uiMode = "television"
    if o.uiMode <> invalid then ad.uiMode = LCase(o.uiMode)
    if o.coordinateSpace <> invalid then ad.coordinateSpace = o.coordinateSpace
    AppDimens__InstallMethods(ad)
    return ad
end function

' Snapshot from logical size (dp), density and font scale — the same inputs as every AppDimens port.
function AppDimens_Metrics(width as float, height as float, density = 1.0 as float, fontScale = 1.0 as float, multiWindow = false as boolean) as object
    m0 = {}
    if not (width > 0.0 and width < 1e30) then width = 0.0
    if not (height > 0.0 and height < 1e30) then height = 0.0
    if not (density > 0.0 and density < 1e30) then density = 1.0
    if not (fontScale > 0.0 and fontScale < 1e30) then fontScale = 1.0
    mn = width
    mx = height
    if height < width then
        mn = height
        mx = width
    end if
    m0.width = width
    m0.height = height
    m0.density = density
    m0.fontScale = fontScale
    m0.multiWindow = multiWindow
    m0.minDim = mn
    m0.maxDim = mx
    m0.isLandscape = width > height
    m0.isPortrait = not m0.isLandscape and (width > 0.0 or height > 0.0)
    sw = mn
    if not (sw > 0.0) then sw = 300.0
    m0.sw = sw
    m0.inv = 1.0 / 300.0
    m0.adj = 0.1 / 30.0
    m0.sens = 0.08 / 30.0
    m0.scale = sw * m0.inv
    nar = 1.0
    if mn > 0.0 then nar = mx / mn
    nar = nar / 1.78
    if not (nar > 0.0 and nar < 1e30) then nar = 1.0
    m0.logNar = Log(nar)
    m0.powerScale = (sw / 300.0) ^ 0.75
    m0.interpolatedScale = 1.0 + (sw * m0.inv - 1.0) * 0.5
    m0.diagonalScale = Sqr(mn * mn + mx * mx) / 611.6305
    m0.perimeterScale = (mn + mx) / 833.0
    m0.logarithmicScale = AppDimens__LogScale(sw, m0.inv)
    m0.t = [invalid, invalid, invalid, invalid, invalid, invalid, invalid, invalid, invalid, invalid, invalid, invalid]
    m0.row = AppDimens__Row
    m0.factor = AppDimens__Factor
    m0.computeFactor = AppDimens__ComputeFactorMethod
    return m0
end function

function AppDimens__LogScale(d as float, inv as float) as float
    if d > 300.0 then return 1.0 + 0.4 * Log(d * inv)
    if d > 0.0 then return 1.0 - 0.4 * Log(300.0 / d)
    return 1.0
end function

function AppDimens__EffectiveQ(q as integer, inv as integer, land as boolean, port as boolean) as integer
    if inv = 1 then
        if land and q = 1 then return 2
    else if inv = 2 then
        if land and q = 2 then return 1
    else if inv = 3 then
        if port and q = 1 then return 2
    else if inv = 4 then
        if port and q = 2 then return 1
    else if inv = 5 then
        if land and q = 0 then return 1
    else if inv = 6 then
        if land and q = 0 then return 2
    else if inv = 7 then
        if port and q = 0 then return 1
    else if inv = 8 then
        if port and q = 0 then return 2
    end if
    return q
end function

function AppDimens__Axis(m0 as object, q as integer) as float
    if q = 1 then return m0.height
    if q = 2 then return m0.width
    return m0.sw
end function

function AppDimens__BaseScale(m0 as object, s as integer, q as integer, defSw as boolean) as float
    if s = 0 or s = 2 then
        if defSw then return m0.scale
        return AppDimens__Axis(m0, q) * m0.inv
    else if s = 1 then
        d = AppDimens__Axis(m0, q)
        if d <= 480.0 then return d * m0.inv
        return 480.0 * m0.inv + 0.4 * Log(1.0 + (d - 480.0) * m0.inv)
    else if s = 3 then
        if defSw then return m0.powerScale
        return (AppDimens__Axis(m0, q) / 300.0) ^ 0.75
    else if s = 4 then
        d = AppDimens__Axis(m0, q)
        if d <= 320.0 then return 0.8
        if d >= 768.0 then return 1.2
        return 0.8 + ((1.2 - 0.8) * (d - 320.0)) / (768.0 - 320.0)
    else if s = 5 then
        if defSw then return m0.interpolatedScale
        return 1.0 + (AppDimens__Axis(m0, q) * m0.inv - 1.0) * 0.5
    else if s = 6 then
        if defSw then return m0.logarithmicScale
        return AppDimens__LogScale(AppDimens__Axis(m0, q), m0.inv)
    else if s = 7 then
        return m0.diagonalScale
    else if s = 8 then
        return m0.perimeterScale
    else if s = 9 then
        a = m0.minDim / 300.0
        b = m0.maxDim / 533.0
        if a < b then return a
        return b
    else if s = 10 then
        a = m0.minDim / 300.0
        b = m0.maxDim / 533.0
        if a > b then return a
        return b
    else if s = 11 then
        return m0.density
    end if
    return 1.0
end function

' General factor: strategy index, qualifier, inverter, ignore-multi-window, aspect correction and
' aspect-ratio sensitivity k (default 0.08/30).
function AppDimens_ComputeFactor(m0 as object, s as integer, qual as integer, inv as integer, ignoreMw as boolean, aspect as boolean, k = -1.0 as float) as float
    if k < 0.0 then k = m0.sens
    if ignoreMw and m0.multiWindow then return 1.0
    defSw = (qual = 0 and inv = 0)
    q = qual
    if s < 7 then q = AppDimens__EffectiveQ(qual, inv, m0.isLandscape, m0.isPortrait)
    if s = 0 or s = 2 then
        d = m0.sw
        if not defSw then d = AppDimens__Axis(m0, q)
        if not aspect then
            if defSw then return m0.scale
            return d * m0.inv
        end if
        return 1.0 + (d - 300.0) * (m0.adj + k * m0.logNar)
    end if
    base = AppDimens__BaseScale(m0, s, q, defSw)
    if aspect then return base * (1.0 + k * m0.logNar)
    return base
end function

function AppDimens__ComputeFactorMethod(s as integer, qual as integer, inv as integer, ignoreMw as boolean, aspect as boolean, k = -1.0 as float) as float
    return AppDimens_ComputeFactor(m, s, qual, inv, ignoreMw, aspect, k)
end function

' Row of 44 factors for a strategy (variant * 4 + flags), computed on first use.
function AppDimens__Row(s as integer) as object
    t = m.t[s]
    if t <> invalid then return t
    vq = AppDimens__VariantQ()
    vi = AppDimens__VariantInv()
    t = CreateObject("roArray", 44, false)
    for v = 0 to 10
        plain = AppDimens_ComputeFactor(m, s, vq[v], vi[v], false, false)
        ar = AppDimens_ComputeFactor(m, s, vq[v], vi[v], false, true)
        t.Push(plain)
        t.Push(ar)
        if m.multiWindow then
            t.Push(1.0)
            t.Push(1.0)
        else
            t.Push(plain)
            t.Push(ar)
        end if
    end for
    m.t[s] = t
    return t
end function

function AppDimens__Factor(s as integer, slot = 0 as integer) as float
    t = m.t[s]
    if t = invalid then t = m.row(s)
    return t[slot]
end function

' ── Token parser ─────────────────────────────────────────────────────────────────────────────
' "sdp", "asdpa", "hdpLw", "sdpPxiaPh", "logssp" … → { strategy, slot, kind (0 dp, 1 sp, 2 em), px }
function AppDimens_ParseToken(name as string) as dynamic
    cache = GetGlobalAA().appdimens_tokens
    if cache = invalid then
        cache = {}
        cache.SetModeCaseSensitive()
        GetGlobalAA().appdimens_tokens = cache
    end if
    hit = cache.Lookup(name)
    if hit <> invalid then
        if hit.strategy < 0 then return invalid
        return hit
    end if
    prefixes = AppDimens_Prefixes()
    order = [6, 3, 7, 8, 9, 10, 1, 2, 4, 5, 11, 0]
    n = Len(name)
    result = invalid
    for each s in order
        p = prefixes[s]
        pl = Len(p)
        if pl <= n and Left(name, pl) = p then
            result = AppDimens__ParseRest(Mid(name, pl + 1), s)
            if result <> invalid then exit for
        end if
    end for
    if cache.Count() < 512 then
        if result = invalid then
            cache.AddReplace(name, { strategy: -1 })
        else
            cache.AddReplace(name, result)
        end if
    end if
    return result
end function

function AppDimens__ParseRest(r as string, s as integer) as dynamic
    n = Len(r)
    if n < 3 then return invalid
    axis = Left(r, 1)
    q = -1
    if axis = "s" then q = 0
    if axis = "h" then q = 1
    if axis = "w" then q = 2
    if q < 0 then return invalid
    k = Mid(r, 2, 2)
    kind = -1
    if k = "dp" then kind = 0
    if k = "sp" then kind = 1
    if k = "em" then kind = 2
    if kind < 0 then return invalid
    i = 4
    px = false
    flags = -1
    inv = ""
    while i <= n
        two = Mid(r, i, 2)
        c = Mid(r, i, 1)
        if two = "Px" then
            if px then return invalid
            px = true
            i = i + 2
        else if two = "Ph" or two = "Pw" or two = "Lh" or two = "Lw" then
            if inv <> "" then return invalid
            inv = two
            i = i + 2
        else if c = "i" or c = "a" then
            if flags >= 0 then return invalid
            if two = "ia" then
                flags = 3
                i = i + 2
            else if c = "a" then
                flags = 1
                i = i + 1
            else
                flags = 2
                i = i + 1
            end if
        else
            return invalid
        end if
    end while
    if flags < 0 then flags = 0
    v = q
    if inv <> "" then
        P = Left(inv, 1) = "P"
        H = Right(inv, 1) = "h"
        if axis = "s" then
            if P then
                if H then v = 3 else v = 5
            else
                if H then v = 4 else v = 6
            end if
        else if axis = "h" and not H then
            if P then v = 8 else v = 7
        else if axis = "w" and H then
            if P then v = 10 else v = 9
        else
            return invalid
        end if
    end if
    return { strategy: s, slot: v * 4 + flags, kind: kind, px: px }
end function

' ── Instance methods ─────────────────────────────────────────────────────────────────────────
sub AppDimens__InstallMethods(ad as object)
    ad.dp = AppDimens__MDp
    ad.sp = AppDimens__MSp
    ad.px = AppDimens__MPx
    ad.resolve = AppDimens__MResolve
    ad.dimen = AppDimens__MDimen
    ad.fontSize = AppDimens__MFontSize
    ad.safeRect = AppDimens__MSafeRect
    ad.xy = AppDimens__MXY
    ad.rect = AppDimens__MRect
    ad.spaceW = AppDimens__MSpaceW
    ad.spaceH = AppDimens__MSpaceH
    ad.pickOrientation = AppDimens__MPickOrientation
    ad.pickMinSw = AppDimens__MPickMinSw
    AppDimens_InstallTokens(ad)
end sub

' dp of `v` for a strategy (index or name) and slot (default 0 = s axis, no flags).
function AppDimens__MDp(strategy as dynamic, v as float, slot = 0 as integer) as float
    return v * m.factor(AppDimens__StrategyIndex(strategy), slot)
end function

function AppDimens__MSp(strategy as dynamic, v as float, slot = 0 as integer) as float
    return v * m.factor(AppDimens__StrategyIndex(strategy), slot) * m.fontScale
end function

' dp → coordinates (× density). In reference mode tokens already return coordinates.
function AppDimens__MPx(v as float) as float
    if m.mode = "reference" then return v
    return v * m.density
end function

function AppDimens__StrategyIndex(strategy as dynamic) as integer
    if Type(strategy) = "String" or Type(strategy) = "roString" then
        names = AppDimens_Strategies()
        for i = 0 to names.Count() - 1
            if names[i] = LCase(strategy) then return i
        end for
        return 0
    end if
    return strategy
end function

' Value of a token: ad.resolve("asdpa", 24). Unknown tokens return invalid.
function AppDimens__MResolve(token as string, v as float) as dynamic
    t = AppDimens_ParseToken(token)
    if t = invalid then return invalid
    r = v * m.factor(t.strategy, t.slot)
    if t.kind = 1 then r = r * m.fontScale
    if t.px then r = r * m.density
    return r
end function

' "<number><token>": "16sdp", "-4hdpLw", "14.5assp", "50spaceW", "12dp", "3px". invalid when malformed.
function AppDimens__MDimen(expr as string) as dynamic
    n = Len(expr)
    i = 1
    c = Mid(expr, 1, 1)
    if c = "-" or c = "+" then i = 2
    digits = 0
    while i <= n
        c = Mid(expr, i, 1)
        if (c >= "0" and c <= "9") or c = "." then
            if c <> "." then digits = digits + 1
            i = i + 1
        else
            exit while
        end if
    end while
    if digits = 0 then return invalid
    v = Val(Left(expr, i - 1))
    tok = Mid(expr, i)
    if tok = "dp" then return v
    if tok = "px" then return v / m.density
    if tok = "spaceW" then return v * 0.01 * m.width
    if tok = "spaceH" then return v * 0.01 * m.height
    if tok = "spaceSw" then return v * 0.01 * m.sw
    ' custom strategies (AppDimensCustom.brs): "16cdp-brand", "14csp-readableText" — like webdimens
    if Left(tok, 4) = "cdp-" or Left(tok, 4) = "csp-" then
        if m.cdp = invalid then return invalid
        if Left(tok, 1) = "c" and Mid(tok, 2, 1) = "s" then return m.csp(v, Mid(tok, 5))
        return m.cdp(v, Mid(tok, 5))
    end if
    return m.resolve(tok, v)
end function

' Integer font size (SceneGraph Font.size) through a strategy (default "scaled"), never below 1.
function AppDimens__MFontSize(v as float, strategy = 0 as dynamic) as integer
    r = v * m.factor(AppDimens__StrategyIndex(strategy), 0) * m.fontScale
    if m.mode <> "reference" then r = r * m.density
    size = Int(r + 0.5)
    if size < 1 then size = 1
    return size
end function

' Roku safe zones in coordinates: "action" (90 %, default) or "title" (80 %). { x, y, width, height }
function AppDimens__MSafeRect(zone = "action" as string) as object
    f = 0.9
    if LCase(zone) = "title" then f = 0.8
    w = m.surfaceWidth * f
    h = m.surfaceHeight * f
    return { x: (m.surfaceWidth - w) * 0.5, y: (m.surfaceHeight - h) * 0.5, width: w, height: h }
end function

' [x, y] translation through a token (default "sdp").
function AppDimens__MXY(x as float, y as float, token = "sdp" as string) as object
    return [m.resolve(token, x), m.resolve(token, y)]
end function

function AppDimens__MRect(x as float, y as float, w as float, h as float, token = "sdp" as string) as object
    return { x: m.resolve(token, x), y: m.resolve(token, y), width: m.resolve(token, w), height: m.resolve(token, h) }
end function

function AppDimens__MSpaceW(p as float) as float
    return p * 0.01 * m.width
end function

function AppDimens__MSpaceH(p as float) as float
    return p * 0.01 * m.height
end function

function AppDimens__MPickOrientation(portrait as dynamic, landscape as dynamic) as dynamic
    if m.isLandscape then return landscape
    return portrait
end function

function AppDimens__MPickMinSw(value as dynamic, minSw as float, largeValue as dynamic) as dynamic
    if m.sw >= minSw then return largeValue
    return value
end function
