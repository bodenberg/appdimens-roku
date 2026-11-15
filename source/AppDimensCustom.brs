' ─────────────────────────────────────────────────────────────────────────────────────────────
' AppDimens for Roku — custom scaling strategies (port of appdimens-dynamic `library-custom`).
' Same JSON document, text-formula language, built-ins and presets as every AppDimens platform;
' tests/source/TestCustom.brs reproduces the shared 540-case fixture.
'
'   err = AppDimens_LoadStrategies(ReadAsciiFile("pkg:/config/custom-strategies.json"))  ' "" = ok
'   ad = AppDimens_Custom()
'   pad = ad.cdp(16, "brand")                        ' value through a registered strategy
'   txt = ad.csp(14, "readableText")                 ' text, font-scale policy applied
'   hud = ad.cdp(64, "base * pow(sw / 360, 0.8)")    ' a text formula (parsed once, shared)
'   pad = cdp(16, "brand") : txt = csp(14, "brand")   ' global functions, like cdp(16, s) on the Web
'   ad.dimen("16cdp-brand")                           ' literal form
'   AppDimens_CustomFactor("product", function(s) : return s.width / 360 : end function)
'
' The registry lives in the BrightScript context of the thread (each SceneGraph component has its
' own): load the document where you use it, e.g. from a string field on m.global.
' Copyright 2026 Jean Bodenberg — Apache-2.0
' ─────────────────────────────────────────────────────────────────────────────────────────────

function AppDimens__CustomState() as object
    g = GetGlobalAA()
    st = g.appdimens_custom
    if st = invalid then
        st = { registry: {}, formulas: {}, formulaCount: 0, defaultId: "scaled", builtins: invalid, generation: 0 }
        st.registry.SetModeCaseSensitive()
        st.formulas.SetModeCaseSensitive()
        g.appdimens_custom = st
        st.builtins = AppDimens__CustomBuiltins()
    end if
    return st
end function

' Clears the registry and shared formulas (tests).
sub AppDimens_ResetStrategies()
    GetGlobalAA().appdimens_custom = invalid
end sub

' ── Screen ───────────────────────────────────────────────────────────────────────────────────
' Screen snapshot used by custom strategies (dp, like every port). Device from the UI mode.
function AppDimens_CustomScreen(width as float, height as float, density = 1.0 as float, fontScale = 1.0 as float, device = "" as string, multiWindow = false as boolean, smallestWidth = -1.0 as float, landscape = invalid as dynamic) as object
    sw = smallestWidth
    if sw < 0.0 then
        sw = width
        if height < sw then sw = height
    end if
    land = width > height
    if landscape <> invalid then land = landscape
    dev = device
    if dev = "" then
        if sw >= 600.0 then dev = "tablet" else dev = "phone"
    end if
    return { width: width, height: height, sw: sw, density: density, fontScale: fontScale, landscape: land, multiWindow: multiWindow, device: dev }
end function

function AppDimens__ScreenOf(ad as object) as object
    dev = "tv"
    mode = ad.uiMode
    if mode = "desk" or mode = "desktop" then dev = "desktop"
    if mode = "car" then dev = "car"
    if mode = "watch" then dev = "watch"
    if mode = "vr" or mode = "vr_headset" then dev = "vr"
    if mode = "normal" then
        if ad.sw >= 600.0 then dev = "tablet" else dev = "phone"
    end if
    return AppDimens_CustomScreen(ad.width, ad.height, ad.density, ad.fontScale, dev, ad.multiWindow, ad.sw, ad.isLandscape)
end function

function AppDimens__ReadAxis(s as object, axis as integer) as float
    mn = s.width
    mx = s.height
    if s.height < s.width then
        mn = s.height
        mx = s.width
    end if
    if axis = 0 then return s.sw
    if axis = 1 then return s.width
    if axis = 2 then return s.height
    if axis = 3 then return mn
    if axis = 4 then return mx
    if axis = 5 then return Sqr(mn * mn + mx * mx)
    return mn + mx
end function

function AppDimens__RefAxis(w as float, h as float, axis as integer) as float
    mn = w
    mx = h
    if h < w then
        mn = h
        mx = w
    end if
    if axis = 0 or axis = 3 then return mn
    if axis = 1 then return w
    if axis = 2 then return h
    if axis = 4 then return mx
    if axis = 5 then return Sqr(w * w + h * h)
    return w + h
end function

function AppDimens__Aspect(s as object) as float
    mn = s.width
    mx = s.height
    if s.height < s.width then
        mn = s.height
        mx = s.width
    end if
    if mn > 0.0 then return mx / mn
    return 1.0
end function

function AppDimens__AxisNames() as object
    return ["smallestWidth", "width", "height", "min", "max", "diagonal", "perimeter"]
end function

function AppDimens__Devices() as object
    return ["phone", "tablet", "desktop", "tv", "watch", "car", "vr"]
end function

' ── Expressions ──────────────────────────────────────────────────────────────────────────────
' Nodes: { k: 0 num (v) | 1 var (n) | 2 neg | 3 not | 4 bin (op) | 5 ternary | 6 call (fn), a: [args] }
function AppDimens__ScreenVars() as object
    return ["sw", "width", "height", "shortSide", "longSide", "diagonal", "perimeter", "aspectRatio", "density", "fontScale", "landscape", "portrait", "multiWindow", "phone", "tablet", "desktop", "tv", "watch", "car", "vr", "pi", "e"]
end function

function AppDimens__AllowedVars(level as integer) as object
    ' level 0 screen, 1 curve, 2 formula
    names = AppDimens__ScreenVars()
    if level >= 1 then names.Append(["ratio", "axis", "ref", "refWidth", "refHeight"])
    if level >= 2 then names.Append(["base", "scaled", "factor"])
    set = {}
    set.SetModeCaseSensitive()
    for each n in names
        set[n] = true
    end for
    return set
end function

function AppDimens__Arity() as object
    a = {}
    a.SetModeCaseSensitive()
    many = 1000000
    a.min = [1, many]
    a.max = [1, many]
    a.clamp = [3, 3]
    a.pow = [2, 2]
    a.sqrt = [1, 1]
    a.ln = [1, 1]
    a.log = [1, 1]
    a.log10 = [1, 1]
    a.log2 = [1, 1]
    a.exp = [1, 1]
    a.abs = [1, 1]
    a.sign = [1, 1]
    a.floor = [1, 1]
    a.ceil = [1, 1]
    a.round = [1, 1]
    a.lerp = [3, 3]
    a.step = [2, 2]
    a.smoothstep = [3, 3]
    return a
end function

' Parses a formula. Returns { ok: true, expr } or { ok: false, error }.
function AppDimens_ParseExpression(source as string, level = 2 as integer) as object
    p = { s: source, i: 1, n: Len(source), allowed: AppDimens__AllowedVars(level), arity: AppDimens__Arity(), err: "" }
    if source.Trim() = "" then return { ok: false, error: "Invalid expression at 0: empty expression in """ + source + """" }
    root = AppDimens__PTernary(p)
    if p.err = "" then
        AppDimens__PWs(p)
        if p.i <= p.n then AppDimens__PFail(p, "unexpected '" + Mid(p.s, p.i, 1) + "'")
    end if
    if p.err <> "" then return { ok: false, error: p.err }
    return { ok: true, expr: { source: source, root: root, coef: AppDimens__BaseCoef(root) } }
end function

sub AppDimens__PFail(p as object, msg as string)
    if p.err = "" then p.err = "Invalid expression at " + (p.i - 1).ToStr() + ": " + msg + " in """ + p.s + """"
end sub

sub AppDimens__PWs(p as object)
    while p.i <= p.n
        c = Asc(Mid(p.s, p.i, 1))
        if c = 32 or c = 9 or c = 10 or c = 13 then p.i = p.i + 1 else exit while
    end while
end sub

function AppDimens__PPeek(p as object, tok as string) as boolean
    AppDimens__PWs(p)
    return Mid(p.s, p.i, Len(tok)) = tok
end function

function AppDimens__PEat(p as object, tok as string) as boolean
    if not AppDimens__PPeek(p, tok) then return false
    p.i = p.i + Len(tok)
    return true
end function

function AppDimens__PNode(k as integer, a = invalid as dynamic, op = "" as string) as object
    if a = invalid then a = []
    return { k: k, a: a, op: op }
end function

function AppDimens__PTernary(p as object) as dynamic
    c = AppDimens__POr(p)
    if p.err <> "" or not AppDimens__PEat(p, "?") then return c
    a = AppDimens__PTernary(p)
    if p.err <> "" then return invalid
    if not AppDimens__PEat(p, ":") then
        AppDimens__PFail(p, "expected ':'")
        return invalid
    end if
    b = AppDimens__PTernary(p)
    return AppDimens__PNode(5, [c, a, b])
end function

function AppDimens__POr(p as object) as dynamic
    n = AppDimens__PAnd(p)
    while p.err = "" and AppDimens__PEat(p, "||")
        n = AppDimens__PNode(4, [n, AppDimens__PAnd(p)], "||")
    end while
    return n
end function

function AppDimens__PAnd(p as object) as dynamic
    n = AppDimens__PCmp(p)
    while p.err = "" and AppDimens__PEat(p, "&&")
        n = AppDimens__PNode(4, [n, AppDimens__PCmp(p)], "&&")
    end while
    return n
end function

function AppDimens__PCmp(p as object) as dynamic
    n = AppDimens__PAdd(p)
    if p.err <> "" then return n
    for each op in ["==", "!=", "<=", ">=", "<", ">"]
        if AppDimens__PEat(p, op) then return AppDimens__PNode(4, [n, AppDimens__PAdd(p)], op)
    end for
    return n
end function

function AppDimens__PAdd(p as object) as dynamic
    n = AppDimens__PMul(p)
    while p.err = ""
        if AppDimens__PEat(p, "+") then
            n = AppDimens__PNode(4, [n, AppDimens__PMul(p)], "+")
        else if AppDimens__PEat(p, "-") then
            n = AppDimens__PNode(4, [n, AppDimens__PMul(p)], "-")
        else
            exit while
        end if
    end while
    return n
end function

function AppDimens__PMul(p as object) as dynamic
    n = AppDimens__PUnary(p)
    while p.err = ""
        if AppDimens__PEat(p, "*") then
            n = AppDimens__PNode(4, [n, AppDimens__PUnary(p)], "*")
        else if AppDimens__PEat(p, "/") then
            n = AppDimens__PNode(4, [n, AppDimens__PUnary(p)], "/")
        else if AppDimens__PEat(p, "%") then
            n = AppDimens__PNode(4, [n, AppDimens__PUnary(p)], "%")
        else
            exit while
        end if
    end while
    return n
end function

function AppDimens__PUnary(p as object) as dynamic
    if AppDimens__PEat(p, "-") then return AppDimens__PNode(2, [AppDimens__PUnary(p)])
    if AppDimens__PEat(p, "+") then return AppDimens__PUnary(p)
    if AppDimens__PPeek(p, "!") and not AppDimens__PPeek(p, "!=") then
        AppDimens__PEat(p, "!")
        return AppDimens__PNode(3, [AppDimens__PUnary(p)])
    end if
    n = AppDimens__PPrimary(p)
    if p.err = "" and AppDimens__PEat(p, "^") then return AppDimens__PNode(4, [n, AppDimens__PUnary(p)], "^")
    return n
end function

function AppDimens__IsDigit(c as string) as boolean
    return c >= "0" and c <= "9"
end function

function AppDimens__IsAlpha(c as string) as boolean
    return (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or c = "_"
end function

function AppDimens__PPrimary(p as object) as dynamic
    AppDimens__PWs(p)
    if p.i > p.n then
        AppDimens__PFail(p, "unexpected end")
        return invalid
    end if
    c = Mid(p.s, p.i, 1)
    if c = "(" then
        p.i = p.i + 1
        n = AppDimens__PTernary(p)
        if p.err = "" and not AppDimens__PEat(p, ")") then AppDimens__PFail(p, "expected ')'")
        return n
    end if
    if AppDimens__IsDigit(c) or c = "." then return AppDimens__PNumber(p)
    if AppDimens__IsAlpha(c) then
        start = p.i
        while p.i <= p.n
            ch = Mid(p.s, p.i, 1)
            if AppDimens__IsAlpha(ch) or AppDimens__IsDigit(ch) then p.i = p.i + 1 else exit while
        end while
        name = Mid(p.s, start, p.i - start)
        if AppDimens__PEat(p, "(") then return AppDimens__PCall(p, name, start)
        if name = "true" then return { k: 0, v: 1.0 }
        if name = "false" then return { k: 0, v: 0.0 }
        if not p.allowed.DoesExist(name) then
            p.i = start
            AppDimens__PFail(p, "unknown variable '" + name + "'")
            return invalid
        end if
        return { k: 1, n: name }
    end if
    AppDimens__PFail(p, "unexpected '" + c + "'")
    return invalid
end function

function AppDimens__PCall(p as object, name as string, start as integer) as dynamic
    args = []
    if not AppDimens__PEat(p, ")") then
        while p.err = ""
            args.Push(AppDimens__PTernary(p))
            if not AppDimens__PEat(p, ",") then exit while
        end while
        if p.err = "" and not AppDimens__PEat(p, ")") then AppDimens__PFail(p, "expected ')'")
    end if
    if p.err <> "" then return invalid
    ar = p.arity[name]
    if ar = invalid then
        p.i = start
        AppDimens__PFail(p, "unknown function '" + name + "'")
        return invalid
    end if
    if args.Count() < ar[0] or args.Count() > ar[1] then
        p.i = start
        want = ar[0].ToStr()
        if ar[0] <> ar[1] then want = want + "+"
        AppDimens__PFail(p, "'" + name + "' takes " + want + " argument(s), got " + args.Count().ToStr())
        return invalid
    end if
    return { k: 6, fn: name, a: args }
end function

function AppDimens__PNumber(p as object) as dynamic
    start = p.i
    while p.i <= p.n
        c = Mid(p.s, p.i, 1)
        if AppDimens__IsDigit(c) or c = "." then p.i = p.i + 1 else exit while
    end while
    mant = Mid(p.s, start, p.i - start)
    ex = 0
    c = Mid(p.s, p.i, 1)
    if c = "e" or c = "E" then
        save = p.i
        j = p.i + 1
        sign = 1
        cs = Mid(p.s, j, 1)
        if cs = "+" or cs = "-" then
            if cs = "-" then sign = -1
            j = j + 1
        end if
        if AppDimens__IsDigit(Mid(p.s, j, 1)) then
            while j <= p.n and AppDimens__IsDigit(Mid(p.s, j, 1))
                ex = ex * 10 + Asc(Mid(p.s, j, 1)) - 48
                j = j + 1
            end while
            ex = ex * sign
            p.i = j
        else
            p.i = save
        end if
    end if
    dots = 0
    for k = 1 to Len(mant)
        if Mid(mant, k, 1) = "." then dots = dots + 1
    end for
    if dots > 1 or mant = "." then
        p.i = start
        AppDimens__PFail(p, "bad number '" + mant + "'")
        return invalid
    end if
    if Left(mant, 1) = "." then mant = "0" + mant
    v = Val(mant)
    if ex <> 0 then v = v * (10.0 ^ ex)
    return { k: 0, v: v }
end function

function AppDimens__Reads(n as object, names as object) as boolean
    if n.k = 1 then return names.DoesExist(n.n)
    if n.a <> invalid then
        for each x in n.a
            if AppDimens__Reads(x, names) then return true
        end for
    end if
    return false
end function

' base / base * X / X * base (X not reading base, scaled, factor) → X; else invalid.
function AppDimens__BaseCoef(root as dynamic) as dynamic
    if root = invalid then return invalid
    vals = { base: true, scaled: true, factor: true }
    if root.k = 1 and root.n = "base" then return { k: 0, v: 1.0 }
    if root.k = 4 and root.op = "*" then
        a = root.a[0]
        b = root.a[1]
        if a.k = 1 and a.n = "base" and not AppDimens__Reads(b, vals) then return b
        if b.k = 1 and b.n = "base" and not AppDimens__Reads(a, vals) then return a
    end if
    return invalid
end function

function AppDimens__IsNaN(x as dynamic) as boolean
    return x <> x
end function

function AppDimens__Inf() as float
    return 1.0e38 * 1.0e38
end function

function AppDimens__Div(x as float, y as float) as float
    if y = 0.0 then
        if x = 0.0 or x <> x then return AppDimens__Inf() - AppDimens__Inf()
        if x > 0.0 then return AppDimens__Inf()
        return -AppDimens__Inf()
    end if
    return x / y
end function

function AppDimens__Pow(x as float, y as float) as float
    if y = 0.0 then return 1.0
    if x = 0.0 then
        if y > 0.0 then return 0.0
        return AppDimens__Inf()
    end if
    if x < 0.0 and y <> Int(y) then return AppDimens__Inf() - AppDimens__Inf()
    return x ^ y
end function

function AppDimens__Eval(n as object, env as object) as float
    k = n.k
    if k = 0 then return n.v
    if k = 1 then
        v = env[n.n]
        if v = invalid then return AppDimens__Inf() - AppDimens__Inf()
        return v
    end if
    if k = 2 then return -AppDimens__Eval(n.a[0], env)
    if k = 3 then
        if AppDimens__Eval(n.a[0], env) <> 0.0 then return 0.0
        return 1.0
    end if
    if k = 5 then
        if AppDimens__Eval(n.a[0], env) <> 0.0 then return AppDimens__Eval(n.a[1], env)
        return AppDimens__Eval(n.a[2], env)
    end if
    if k = 4 then
        op = n.op
        if op = "&&" then
            if AppDimens__Eval(n.a[0], env) <> 0.0 and AppDimens__Eval(n.a[1], env) <> 0.0 then return 1.0
            return 0.0
        end if
        if op = "||" then
            if AppDimens__Eval(n.a[0], env) <> 0.0 or AppDimens__Eval(n.a[1], env) <> 0.0 then return 1.0
            return 0.0
        end if
        x = AppDimens__Eval(n.a[0], env)
        y = AppDimens__Eval(n.a[1], env)
        if op = "+" then return x + y
        if op = "-" then return x - y
        if op = "*" then return x * y
        if op = "/" then return AppDimens__Div(x, y)
        if op = "%" then
            if y = 0.0 then return AppDimens__Inf() - AppDimens__Inf()
            return x - y * Fix(x / y)
        end if
        if op = "^" then return AppDimens__Pow(x, y)
        r = false
        if op = "==" then r = (x = y)
        if op = "!=" then r = (x <> y)
        if op = "<" then r = (x < y)
        if op = "<=" then r = (x <= y)
        if op = ">" then r = (x > y)
        if op = ">=" then r = (x >= y)
        if r then return 1.0
        return 0.0
    end if
    ' call
    a = []
    for each x in n.a
        a.Push(AppDimens__Eval(x, env))
    end for
    f = n.fn
    if f = "min" then
        r = a[0]
        for i = 1 to a.Count() - 1
            if a[i] < r then r = a[i]
        end for
        return r
    end if
    if f = "max" then
        r = a[0]
        for i = 1 to a.Count() - 1
            if a[i] > r then r = a[i]
        end for
        return r
    end if
    x = a[0]
    if f = "clamp" then
        r = x
        if a[2] < r then r = a[2]
        if a[1] > r then r = a[1]
        return r
    end if
    if f = "pow" then return AppDimens__Pow(x, a[1])
    if f = "sqrt" then
        if x < 0.0 then return AppDimens__Inf() - AppDimens__Inf()
        return Sqr(x)
    end if
    if f = "ln" or f = "log" or f = "log10" or f = "log2" then
        if x < 0.0 then return AppDimens__Inf() - AppDimens__Inf()
        if x = 0.0 then return -AppDimens__Inf()
        r = Log(x)
        if f = "log10" then r = r / Log(10.0)
        if f = "log2" then r = r / Log(2.0)
        return r
    end if
    if f = "exp" then return Exp(x)
    if f = "abs" then return Abs(x)
    if f = "sign" then
        if x > 0.0 then return 1.0
        if x < 0.0 then return -1.0
        return 0.0
    end if
    if f = "floor" then return Int(x)
    if f = "ceil" then return -Int(-x)
    if f = "round" then return Int(x + 0.5)
    if f = "lerp" then return x + (a[1] - x) * a[2]
    if f = "step" then
        if a[1] < x then return 0.0
        return 1.0
    end if
    if f = "smoothstep" then
        t = AppDimens__Div(a[2] - x, a[1] - x)
        if t < 0.0 then t = 0.0
        if t > 1.0 then t = 1.0
        return t * t * (3.0 - 2.0 * t)
    end if
    return AppDimens__Inf() - AppDimens__Inf()
end function

function AppDimens__Env(s as object, ratio as float, axisDp as float, refDp as float, refW as float, refH as float, base = 0.0 as float, scaled = 0.0 as float, factor = 0.0 as float) as object
    mn = s.width
    mx = s.height
    if s.height < s.width then
        mn = s.height
        mx = s.width
    end if
    e = {}
    e.SetModeCaseSensitive()
    e["sw"] = s.sw
    e["width"] = s.width
    e["height"] = s.height
    e["shortSide"] = mn
    e["longSide"] = mx
    e["diagonal"] = Sqr(mn * mn + mx * mx)
    e["perimeter"] = mn + mx
    e["aspectRatio"] = AppDimens__Aspect(s)
    e["density"] = s.density
    e["fontScale"] = s.fontScale
    if s.landscape then
        e["landscape"] = 1.0
        e["portrait"] = 0.0
    else
        e["landscape"] = 0.0
        e["portrait"] = 1.0
    end if
    if s.multiWindow then e["multiWindow"] = 1.0 else e["multiWindow"] = 0.0
    for each d in AppDimens__Devices()
        if s.device = d then e[d] = 1.0 else e[d] = 0.0
    end for
    e["pi"] = 3.14159265358979
    e["e"] = 2.71828182845905
    e["ratio"] = ratio
    e["axis"] = axisDp
    e["ref"] = refDp
    e["refWidth"] = refW
    e["refHeight"] = refH
    e["base"] = base
    e["scaled"] = scaled
    e["factor"] = factor
    return e
end function

' ── Model ────────────────────────────────────────────────────────────────────────────────────
function AppDimens__DefaultConfig() as object
    return { refW: 300.0, refH: 533.0, axis: 0, curve: { kind: "linear" }, mul: 1.0, minF: invalid, maxF: invalid, minV: invalid, maxV: invalid, ar: false, sens: invalid, font: "follow", fontMax: 0.0, mw: false, xf: invalid, fn: invalid, rules: [] }
end function

function AppDimens__CopyConfig(c as object) as object
    n = {}
    n.Append(c)
    return n
end function

function AppDimens__ApplyPatch(c as object, patch as object) as object
    n = AppDimens__CopyConfig(c)
    for each key in patch
        n[key] = patch[key]
    end for
    return n
end function

function AppDimens__CondMatches(cond as object, s as object) as boolean
    if cond.devices <> invalid then
        hit = false
        for each d in cond.devices
            if d = s.device then hit = true
        end for
        if not hit then return false
    end if
    if cond.orientation = "landscape" and not s.landscape then return false
    if cond.orientation = "portrait" and s.landscape then return false
    vals = [s.sw, s.width, s.height, AppDimens__Aspect(s)]
    for i = 0 to 3
        r = cond.ranges[i]
        if r <> invalid then
            if r.min <> invalid and vals[i] < r.min then return false
            if r.max <> invalid and vals[i] >= r.max then return false
        end if
    end for
    if cond.multiWindow <> invalid and s.multiWindow <> cond.multiWindow then return false
    return true
end function

function AppDimens__CurveFactor(curve as object, ratio as float, axisDp as float, env as dynamic, cfg as object, s as object, refDp as float) as float
    k = curve.kind
    if k = "linear" then return ratio
    if k = "power" then
        if ratio > 0.0 then return AppDimens__Pow(ratio, curve.v)
        return 0.0
    end if
    if k = "logarithmic" then
        if ratio > 0.0 then return 1.0 + curve.v * Log(ratio)
        return 1.0
    end if
    if k = "interpolated" then return 1.0 + (ratio - 1.0) * curve.v
    if k = "constant" then return curve.v
    if k = "breakpoints" then
        pts = curve.pts
        if axisDp <= pts[0].at then return pts[0].f
        for i = 1 to pts.Count() - 1
            if axisDp <= pts[i].at then
                span = pts[i].at - pts[i - 1].at
                if span <= 0.0 then return pts[i].f
                return pts[i - 1].f + (pts[i].f - pts[i - 1].f) * ((axisDp - pts[i - 1].at) / span)
            end if
        end for
        return pts[pts.Count() - 1].f
    end if
    if k = "code" then
        f = curve.fn
        return f(s)
    end if
    return AppDimens__Eval(curve.expr.root, AppDimens__Env(s, ratio, axisDp, refDp, cfg.refW, cfg.refH))
end function

' Resolves a strategy for a screen: { factor, rules (names applied), cfg, axisDp, refDp, ... }.
function AppDimens_ResolveStrategy(strategy as object, s as object) as object
    cfg = strategy.cfg
    applied = []
    rules = cfg.rules
    for i = 0 to rules.Count() - 1
        r = rules[i]
        if AppDimens__CondMatches(r.when, s) then
            cfg = AppDimens__ApplyPatch(cfg, r.set)
            if r.name <> invalid then applied.Push(r.name) else applied.Push("#" + i.ToStr())
        end if
    end for
    axisDp = AppDimens__ReadAxis(s, cfg.axis)
    refDp = AppDimens__RefAxis(cfg.refW, cfg.refH, cfg.axis)
    res = { cfg: cfg, screen: s, rules: applied, axisDp: axisDp, refDp: refDp, mwIgnored: false, coef: invalid, curveFactor: 1.0, arMul: 1.0 }
    if cfg.mw and s.multiWindow then
        res.factor = 1.0
        res.mwIgnored = true
        return res
    end if
    ratio = 1.0
    if refDp > 0.0 then ratio = axisDp / refDp
    res.ratio = ratio
    cf = AppDimens__CurveFactor(cfg.curve, ratio, axisDp, invalid, cfg, s, refDp)
    factor = cf * cfg.mul
    if cfg.ar then
        k = 0.08 / 30.0
        if cfg.sens <> invalid then k = cfg.sens
        res.arMul = 1.0 + k * Log(AppDimens__Aspect(s) / 1.78)
        factor = factor * res.arMul
    end if
    if cfg.minF <> invalid and factor < cfg.minF then factor = cfg.minF
    if cfg.maxF <> invalid and factor > cfg.maxF then factor = cfg.maxF
    if factor <> factor or factor > 1.0e37 or factor < -1.0e37 then factor = 1.0
    res.curveFactor = cf
    res.factor = factor
    if cfg.xf <> invalid and cfg.xf.coef <> invalid then
        res.coef = AppDimens__Eval(cfg.xf.coef, AppDimens__Env(s, ratio, axisDp, refDp, cfg.refW, cfg.refH))
    end if
    return res
end function

' Layout value (dp) of `base` for a resolved strategy.
function AppDimens_ScaleResolved(r as object, base as float) as float
    out = base * r.factor
    c = r.cfg
    if (c.minV <> invalid or c.maxV <> invalid) and out <> 0.0 then
        mag = Abs(out)
        if c.minV <> invalid and mag < c.minV then mag = c.minV
        if c.maxV <> invalid and mag > c.maxV then mag = c.maxV
        if out < 0.0 then out = -mag else out = mag
    end if
    if r.mwIgnored then return out
    if c.fn <> invalid then
        f = c.fn
        return f(base, r.screen)
    end if
    if c.xf = invalid then return out
    if r.coef <> invalid then return base * r.coef
    ratio = 1.0
    if r.refDp > 0.0 then ratio = r.axisDp / r.refDp
    return AppDimens__Eval(c.xf.root, AppDimens__Env(r.screen, ratio, r.axisDp, r.refDp, c.refW, c.refH, base, out, r.factor))
end function

function AppDimens_EffectiveFontScale(r as object) as float
    c = r.cfg
    if c.font = "ignore" then return 1.0
    if c.font = "clamp" then
        if r.screen.fontScale < c.fontMax then return r.screen.fontScale
        return c.fontMax
    end if
    return r.screen.fontScale
end function

' Text value in dp with the strategy's font-scale policy (Android scaleSpDp).
function AppDimens_ScaleSpResolved(r as object, base as float) as float
    return AppDimens_ScaleResolved(r, base) * AppDimens_EffectiveFontScale(r)
end function

' ── JSON ─────────────────────────────────────────────────────────────────────────────────────
function AppDimens__IsNum(v as dynamic) as boolean
    t = Type(v)
    return t = "Integer" or t = "roInteger" or t = "Float" or t = "roFloat" or t = "Double" or t = "roDouble" or t = "LongInteger" or t = "roLongInteger"
end function

function AppDimens__IsStr(v as dynamic) as boolean
    t = Type(v)
    return t = "String" or t = "roString"
end function

function AppDimens__IsBool(v as dynamic) as boolean
    t = Type(v)
    return t = "Boolean" or t = "roBoolean"
end function

function AppDimens__IsObj(v as dynamic) as boolean
    return Type(v) = "roAssociativeArray"
end function

function AppDimens__IsList(v as dynamic) as boolean
    return Type(v) = "roArray"
end function

' Reads a number field (invalid when absent). Records an error in rd.err.
function AppDimens__RNum(rd as object, o as object, key as string, path as string) as dynamic
    if o = invalid or not o.DoesExist(key) then return invalid
    v = o[key]
    if v = invalid then return invalid
    if not AppDimens__IsNum(v) then
        AppDimens__RFail(rd, path + "." + key + " must be a number")
        return invalid
    end if
    return v * 1.0
end function

function AppDimens__RBool(rd as object, o as object, key as string, path as string) as dynamic
    if o = invalid or not o.DoesExist(key) then return invalid
    v = o[key]
    if v = invalid then return invalid
    if not AppDimens__IsBool(v) then
        AppDimens__RFail(rd, path + "." + key + " must be a boolean")
        return invalid
    end if
    return v
end function

function AppDimens__RObj(rd as object, o as object, key as string, path as string) as dynamic
    if o = invalid or not o.DoesExist(key) then return invalid
    v = o[key]
    if v = invalid then return invalid
    if not AppDimens__IsObj(v) then
        AppDimens__RFail(rd, path + "." + key + " must be an object")
        return invalid
    end if
    return v
end function

sub AppDimens__RFail(rd as object, msg as string)
    if rd.err = "" then rd.err = msg
end sub

function AppDimens__RCurve(rd as object, v as dynamic, path as string) as dynamic
    if AppDimens__IsStr(v) then v = { type: v }
    if not AppDimens__IsObj(v) then
        AppDimens__RFail(rd, path + " must be an object or string")
        return invalid
    end if
    t = v.type
    if not AppDimens__IsStr(t) then
        AppDimens__RFail(rd, path + ".type is required")
        return invalid
    end if
    if t = "linear" then return { kind: "linear" }
    if t = "power" or t = "logarithmic" or t = "interpolated" or t = "constant" then
        keys = { power: "exponent", logarithmic: "k", interpolated: "t", constant: "factor" }
        defs = { power: 0.75, logarithmic: 0.4, interpolated: 0.5, constant: 1.0 }
        x = AppDimens__RNum(rd, v, keys[t], path)
        if x = invalid then x = defs[t]
        return { kind: t, v: x }
    end if
    if t = "expression" then
        src = v.expression
        if not AppDimens__IsStr(src) then
            AppDimens__RFail(rd, path + ".expression is required")
            return invalid
        end if
        pe = AppDimens_ParseExpression(src, 1)
        if not pe.ok then
            AppDimens__RFail(rd, path + ".expression: " + pe.error)
            return invalid
        end if
        return { kind: "expression", expr: pe.expr }
    end if
    if t = "breakpoints" then
        raw = v.points
        if not AppDimens__IsList(raw) then
            AppDimens__RFail(rd, path + ".points must be an array")
            return invalid
        end if
        pts = []
        for i = 0 to raw.Count() - 1
            pp = path + ".points[" + i.ToStr() + "]"
            if not AppDimens__IsObj(raw[i]) then
                AppDimens__RFail(rd, pp + " must be an object")
                return invalid
            end if
            at = AppDimens__RNum(rd, raw[i], "at", pp)
            f = AppDimens__RNum(rd, raw[i], "factor", pp)
            if at = invalid then AppDimens__RFail(rd, pp + ".at is required")
            if f = invalid then AppDimens__RFail(rd, pp + ".factor is required")
            if rd.err <> "" then return invalid
            if at < 0.0 then
                AppDimens__RFail(rd, "breakpoint 'at' must be finite and >= 0")
                return invalid
            end if
            pts.Push({ at: at, f: f })
        end for
        if pts.Count() = 0 then
            AppDimens__RFail(rd, "breakpoints need at least one point")
            return invalid
        end if
        pts.SortBy("at")
        return { kind: "breakpoints", pts: pts }
    end if
    AppDimens__RFail(rd, path + ".type '" + t + "' is not one of linear, power, logarithmic, interpolated, constant, breakpoints, expression")
    return invalid
end function

function AppDimens__RPatch(rd as object, o as object, path as string) as object
    p = {}
    clamp = AppDimens__RObj(rd, o, "clamp", path)
    vclamp = AppDimens__RObj(rd, o, "valueClamp", path)
    ref = o.reference
    if AppDimens__IsObj(ref) then
        w = AppDimens__RNum(rd, ref, "width", path + ".reference")
        h = AppDimens__RNum(rd, ref, "height", path + ".reference")
        if w = invalid then w = 300.0
        if h = invalid then h = 533.0
        if not (w > 0.0) then AppDimens__RFail(rd, "reference width must be > 0")
        if not (h > 0.0) then AppDimens__RFail(rd, "reference height must be > 0")
        p.refW = w
        p.refH = h
    end if
    if AppDimens__IsStr(o.axis) then
        names = AppDimens__AxisNames()
        found = -1
        for i = 0 to names.Count() - 1
            if LCase(names[i]) = LCase(o.axis) then found = i
        end for
        if found < 0 then AppDimens__RFail(rd, "Unknown axis '" + o.axis + "'") else p.axis = found
    end if
    if o.curve <> invalid then
        c = AppDimens__RCurve(rd, o.curve, path + ".curve")
        if c <> invalid then p.curve = c
    end if
    x = AppDimens__RNum(rd, o, "multiplier", path)
    if x <> invalid then p.mul = x
    if clamp <> invalid then
        x = AppDimens__RNum(rd, clamp, "min", path + ".clamp")
        if x <> invalid then p.minF = x
        x = AppDimens__RNum(rd, clamp, "max", path + ".clamp")
        if x <> invalid then p.maxF = x
    end if
    if vclamp <> invalid then
        x = AppDimens__RNum(rd, vclamp, "min", path + ".valueClamp")
        if x <> invalid then p.minV = x
        x = AppDimens__RNum(rd, vclamp, "max", path + ".valueClamp")
        if x <> invalid then p.maxV = x
    end if
    ar = o.aspectRatio
    if AppDimens__IsBool(ar) then
        p.ar = ar
    else if AppDimens__IsObj(ar) then
        en = AppDimens__RBool(rd, ar, "enabled", path + ".aspectRatio")
        if en = invalid then p.ar = true else p.ar = en
        x = AppDimens__RNum(rd, ar, "sensitivity", path + ".aspectRatio")
        if x <> invalid then p.sens = x
    else if ar <> invalid then
        AppDimens__RFail(rd, path + ".aspectRatio must be a boolean or object")
    end if
    if p.sens = invalid then
        x = AppDimens__RNum(rd, o, "sensitivity", path)
        if x <> invalid then p.sens = x
    end if
    fs = o.fontScale
    if fs <> invalid then
        if AppDimens__IsStr(fs) and (fs = "follow" or fs = "ignore") then
            p.font = fs
        else if AppDimens__IsObj(fs) then
            mx = AppDimens__RNum(rd, fs, "max", path + ".fontScale")
            if mx = invalid then
                AppDimens__RFail(rd, path + ".fontScale.max is required")
            else if mx <= 0.0 then
                AppDimens__RFail(rd, "fontScale max must be > 0")
            else
                p.font = "clamp"
                p.fontMax = mx
            end if
        else
            AppDimens__RFail(rd, path + ".fontScale must be ""follow"", ""ignore"" or {""max"": n}")
        end if
    end if
    b = AppDimens__RBool(rd, o, "ignoreMultiWindow", path)
    if b <> invalid then p.mw = b
    f = o.formula
    if f <> invalid then
        if not AppDimens__IsStr(f) then
            AppDimens__RFail(rd, path + ".formula must be a string")
        else
            pe = AppDimens_ParseExpression(f, 2)
            if pe.ok then
                p.xf = pe.expr
                p.fn = invalid
            else
                AppDimens__RFail(rd, path + ".formula: " + pe.error)
            end if
        end if
    end if
    return p
end function

function AppDimens__RCondition(rd as object, o as dynamic, path as string) as object
    c = { devices: invalid, orientation: invalid, ranges: [invalid, invalid, invalid, invalid], multiWindow: invalid }
    if o = invalid then return c
    d = o.device
    if AppDimens__IsStr(d) then d = [d]
    if AppDimens__IsList(d) then
        c.devices = []
        for each x in d
            if not AppDimens__IsStr(x) then
                AppDimens__RFail(rd, path + ".device entries must be strings")
            else
                ok = false
                for each known in AppDimens__Devices()
                    if LCase(x) = known then
                        ok = true
                        c.devices.Push(known)
                    end if
                end for
                if not ok then AppDimens__RFail(rd, "Unknown device class '" + x + "'")
            end if
        end for
    else if d <> invalid then
        AppDimens__RFail(rd, path + ".device must be a string or array")
    end if
    ori = o.orientation
    if ori <> invalid then
        if ori = "portrait" or ori = "landscape" then c.orientation = ori else AppDimens__RFail(rd, path + ".orientation must be portrait or landscape")
    end if
    keys = ["smallestWidth", "width", "height", "aspectRatio"]
    for i = 0 to 3
        r = o[keys[i]]
        if r <> invalid then
            if not AppDimens__IsObj(r) then
                AppDimens__RFail(rd, path + "." + keys[i] + " must be an object with min/max")
            else
                c.ranges[i] = { min: AppDimens__RNum(rd, r, "min", path + "." + keys[i]), max: AppDimens__RNum(rd, r, "max", path + "." + keys[i]) }
            end if
        end if
    end for
    c.multiWindow = AppDimens__RBool(rd, o, "multiWindow", path)
    return c
end function

sub AppDimens__ValidateConfig(rd as object, c as object, path as string)
    if c.minF <> invalid and c.maxF <> invalid and c.minF > c.maxF then AppDimens__RFail(rd, path + ": minFactor must be <= maxFactor")
    if c.minV <> invalid and c.maxV <> invalid and c.minV > c.maxV then AppDimens__RFail(rd, path + ": minValue must be <= maxValue")
    if c.minV <> invalid and c.minV < 0.0 then AppDimens__RFail(rd, path + ": minValue must be >= 0")
    if c.maxV <> invalid and c.maxV < 0.0 then AppDimens__RFail(rd, path + ": maxValue must be >= 0")
end sub

function AppDimens__RConfig(rd as object, o as object, parent as object, path as string) as object
    cfg = AppDimens__ApplyPatch(parent, AppDimens__RPatch(rd, o, path))
    if o.DoesExist("clamp") and o.clamp = invalid then
        cfg.minF = invalid
        cfg.maxF = invalid
    end if
    if o.DoesExist("valueClamp") and o.valueClamp = invalid then
        cfg.minV = invalid
        cfg.maxV = invalid
    end if
    if o.DoesExist("formula") and o.formula = invalid then
        cfg.xf = invalid
        cfg.fn = invalid
    end if
    rules = []
    rules.Append(parent.rules)
    raw = o.rules
    if raw <> invalid then
        if not AppDimens__IsList(raw) then
            AppDimens__RFail(rd, path + ".rules must be an array")
        else
            for i = 0 to raw.Count() - 1
                r = raw[i]
                rp = path + ".rules[" + i.ToStr() + "]"
                if not AppDimens__IsObj(r) then
                    AppDimens__RFail(rd, rp + " must be an object")
                else
                    when = AppDimens__RObj(rd, r, "when", rp)
                    cond = AppDimens__RCondition(rd, when, rp + ".when")
                    sset = AppDimens__RObj(rd, r, "set", rp)
                    if sset = invalid then
                        AppDimens__RFail(rd, rp + ".set is required")
                    else
                        name = invalid
                        if AppDimens__IsStr(r.name) then name = r.name
                        patch = AppDimens__RPatch(rd, sset, rp + ".set")
                        rules.Push({ when: cond, set: patch, name: name })
                        AppDimens__ValidateConfig(rd, AppDimens__ApplyPatch(cfg, patch), rp)
                    end if
                end if
            end for
        end if
    end if
    cfg.rules = rules
    AppDimens__ValidateConfig(rd, cfg, path)
    return cfg
end function

function AppDimens__NewStrategy(id as string, cfg as object) as object
    return { id: id, cfg: cfg, isAppDimensStrategy: true }
end function

function AppDimens__CustomBuiltins() as object
    specs = [
        { id: "scaled" },
        { id: "power", curve: { type: "power", exponent: 0.75 } },
        { id: "logarithmic", curve: { type: "logarithmic", k: 0.4 } },
        { id: "interpolated", curve: { type: "interpolated", t: 0.5 } },
        { id: "diagonal", axis: "diagonal" },
        { id: "perimeter", axis: "perimeter" },
        { id: "fixed", curve: { type: "constant", factor: 1 } },
        { id: "tabletFriendly", clamp: { max: 1.8 }, rules: [{ name: "large", when: { device: ["tablet", "desktop"] }, set: { curve: { type: "power", exponent: 0.5 } } }] },
        { id: "compactFirst", reference: { width: 360, height: 640 }, curve: { type: "interpolated", t: 0.5 }, clamp: { min: 0.9, max: 1.4 } },
        { id: "tvSafe", rules: [{ name: "tv", when: { device: "tv" }, set: { axis: "height", reference: { width: 960, height: 540 }, clamp: { min: 1, max: 2 } } }] },
        { id: "wearable", rules: [{ name: "watch", when: { device: "watch" }, set: { axis: "min", reference: { width: 192, height: 192 }, clamp: { min: 0.85, max: 1.15 } } }] },
        { id: "gameHud", axis: "min", curve: { type: "power", exponent: 0.85 }, aspectRatio: true, clamp: { min: 0.75, max: 2.5 }, fontScale: "ignore" },
        { id: "readableText", curve: { type: "logarithmic", k: 0.4 }, fontScale: { max: 1.3 } }
    ]
    out = {}
    out.SetModeCaseSensitive()
    rd = { err: "" }
    for each sp in specs
        out[LCase(sp.id)] = AppDimens__NewStrategy(sp.id, AppDimens__RConfig(rd, sp, AppDimens__DefaultConfig(), sp.id))
    end for
    return out
end function

' Parses a document (object, array or {"version", "default", "strategies"}) without registering it.
' Returns { ok, error, strategies (AA id → strategy), order (ids), defaultId }.
function AppDimens_DecodeStrategies(text as dynamic) as object
    root = text
    if AppDimens__IsStr(text) then root = ParseJson(text)
    fail = { ok: false, error: "", strategies: invalid, order: [], defaultId: invalid }
    items = invalid
    defaultId = invalid
    if AppDimens__IsObj(root) then
        if root.DoesExist("strategies") then
            ver = root.version
            if AppDimens__IsNum(ver) and ver > 1 then
                fail.error = "Unsupported strategies format version " + Int(ver).ToStr()
                return fail
            end if
            items = root.strategies
            if not AppDimens__IsList(items) then
                fail.error = "strategies must be an array"
                return fail
            end if
            if AppDimens__IsStr(root["default"]) then defaultId = root["default"]
        else
            items = [root]
        end if
    else if AppDimens__IsList(root) then
        items = root
    else
        fail.error = "Expected a JSON object or array"
        return fail
    end if
    raw = {}
    raw.SetModeCaseSensitive()
    order = []
    for i = 0 to items.Count() - 1
        it = items[i]
        if not AppDimens__IsObj(it) then
            fail.error = "strategies[" + i.ToStr() + "] must be an object"
            return fail
        end if
        if not AppDimens__IsStr(it.id) then
            fail.error = "strategies[" + i.ToStr() + "].id is required"
            return fail
        end if
        if raw.DoesExist(it.id) then
            fail.error = "Duplicate strategy id '" + it.id + "'"
            return fail
        end if
        raw[it.id] = it
        order.Push(it.id)
    end for
    ctx = { raw: raw, built: {}, rd: { err: "" } }
    ctx.built.SetModeCaseSensitive()
    for each id in order
        AppDimens__Build(ctx, id, [])
        if ctx.rd.err <> "" then
            fail.error = ctx.rd.err
            return fail
        end if
    end for
    return { ok: true, error: "", strategies: ctx.built, order: order, defaultId: defaultId }
end function

function AppDimens__Build(ctx as object, id as string, stack as object) as dynamic
    if ctx.built.DoesExist(id) then return ctx.built[id]
    for each sid in stack
        if sid = id then
            chain = ""
            for each x in stack
                chain = chain + x + " → "
            end for
            AppDimens__RFail(ctx.rd, "Cyclic 'extends': " + chain + id)
            return invalid
        end if
    end for
    o = ctx.raw[id]
    pid = invalid
    if AppDimens__IsStr(o.extends) then pid = o.extends
    parent = invalid
    if pid = invalid then
        parent = AppDimens__DefaultConfig()
    else if ctx.raw.DoesExist(pid) then
        st = []
        st.Append(stack)
        st.Push(id)
        ps = AppDimens__Build(ctx, pid, st)
        if ps = invalid then return invalid
        parent = ps.cfg
    else
        ps = AppDimens_GetStrategy(pid)
        if ps = invalid then
            AppDimens__RFail(ctx.rd, "'" + id + "' extends unknown strategy '" + pid + "'")
            return invalid
        end if
        parent = ps.cfg
    end if
    s = AppDimens__NewStrategy(id, AppDimens__RConfig(ctx.rd, o, parent, id))
    ctx.built[id] = s
    return s
end function

' Registers every strategy of a document and applies "default". Returns "" or the error (atomic:
' nothing is registered when the document is invalid).
function AppDimens_LoadStrategies(text as dynamic) as string
    d = AppDimens_DecodeStrategies(text)
    if not d.ok then return d.error
    st = AppDimens__CustomState()
    if d.defaultId <> invalid then
        if not d.strategies.DoesExist(d.defaultId) and AppDimens_GetStrategy(d.defaultId) = invalid then return "No scaling strategy '" + d.defaultId + "'"
    end if
    for each id in d.order
        st.registry[id] = d.strategies[id]
    end for
    if d.defaultId <> invalid then st.defaultId = d.defaultId
    st.generation = st.generation + 1
    return ""
end function

' Registered → built-in → preset (case-insensitive for built-ins and presets).
function AppDimens_GetStrategy(id as string) as dynamic
    st = AppDimens__CustomState()
    s = st.registry[id]
    if s <> invalid then return s
    return st.builtins[LCase(id)]
end function

function AppDimens_RegisterStrategy(s as object) as object
    st = AppDimens__CustomState()
    st.registry[s.id] = s
    st.generation = st.generation + 1
    return s
end function

sub AppDimens_UnregisterStrategy(id as string)
    st = AppDimens__CustomState()
    st.registry.Delete(id)
    st.generation = st.generation + 1
end sub

sub AppDimens_SetDefaultStrategy(id as string)
    st = AppDimens__CustomState()
    st.defaultId = id
    st.generation = st.generation + 1
end sub

function AppDimens_DefaultStrategy() as object
    st = AppDimens__CustomState()
    s = AppDimens_GetStrategy(st.defaultId)
    if s = invalid then s = st.builtins["scaled"]
    return s
end function

' A strategy whose factor comes from code: fn(screen) → factor (CustomScaleStrategy).
function AppDimens_CustomFactor(id as string, fn as function, register = true as boolean) as object
    cfg = AppDimens__DefaultConfig()
    cfg.curve = { kind: "code", fn: fn }
    s = AppDimens__NewStrategy(id, cfg)
    if register then AppDimens_RegisterStrategy(s)
    return s
end function

' A strategy whose final value comes from code: fn(base, screen) → value (scalingFormula { }).
function AppDimens_CustomFormula(id as string, fn as function, register = true as boolean) as object
    cfg = AppDimens__DefaultConfig()
    cfg.fn = fn
    s = AppDimens__NewStrategy(id, cfg)
    if register then AppDimens_RegisterStrategy(s)
    return s
end function

' A text formula, shared per text (bounded at 256). Returns invalid + prints the error when invalid.
function AppDimens_Formula(text as string) as dynamic
    st = AppDimens__CustomState()
    s = st.formulas[text]
    if s <> invalid then return s
    pe = AppDimens_ParseExpression(text, 2)
    if not pe.ok then
        print "AppDimens: "; pe.error
        return invalid
    end if
    cfg = AppDimens__DefaultConfig()
    cfg.xf = pe.expr
    s = AppDimens__NewStrategy("formula:" + text, cfg)
    if st.formulaCount < 256 then
        st.formulas[text] = s
        st.formulaCount = st.formulaCount + 1
    end if
    return s
end function

' Strategy object, registered id, or text formula ("base * …") → strategy (default when invalid).
function AppDimens_PickStrategy(s as dynamic) as object
    if s = invalid then return AppDimens_DefaultStrategy()
    if AppDimens__IsObj(s) then return s
    if AppDimens__IsStr(s) then
        hit = AppDimens_GetStrategy(s)
        if hit <> invalid then return hit
        f = AppDimens_Formula(s)
        if f <> invalid then return f
    end if
    return AppDimens_DefaultStrategy()
end function

' ── Instance methods (installed by AppDimens_Create) ─────────────────────────────────────────
' AppDimens() with the custom-strategy methods (ad.cdp, ad.csp, ad.cfactor, ad.cresolve).
function AppDimens_Custom(options = invalid as dynamic) as object
    ad = AppDimens(options)
    if ad.cdp = invalid then AppDimens_InstallCustom(ad)
    return ad
end function

sub AppDimens_InstallCustom(ad as object)
    ad.cdp = AppDimens__MCdp
    ad.csp = AppDimens__MCsp
    ad.cfactor = AppDimens__MCfactor
    ad.cresolve = AppDimens__MCresolve
    ad.customScreen = AppDimens__MCustomScreen
end sub

function AppDimens__MCustomScreen() as object
    if m.appdimens_cscreen = invalid then m.appdimens_cscreen = AppDimens__ScreenOf(m)
    return m.appdimens_cscreen
end function

function AppDimens__MCresolve(strategy = invalid as dynamic) as object
    s = AppDimens_PickStrategy(strategy)
    if m.appdimens_cres = invalid then
        m.appdimens_cres = {}
        m.appdimens_cres.SetModeCaseSensitive()
    end if
    st = AppDimens__CustomState()
    key = s.id
    hit = m.appdimens_cres[key]
    if hit <> invalid and hit.gen = st.generation then return hit.res
    res = AppDimens_ResolveStrategy(s, m.customScreen())
    m.appdimens_cres[key] = { gen: st.generation, strategy: s, res: res }
    return res
end function

' Value through a custom strategy (object, id or formula). Reference mode: coordinates, like sdp.
function AppDimens__MCdp(v as float, strategy = invalid as dynamic) as float
    return AppDimens_ScaleResolved(m.cresolve(strategy), v)
end function

function AppDimens__MCsp(v as float, strategy = invalid as dynamic) as float
    return AppDimens_ScaleSpResolved(m.cresolve(strategy), v)
end function

function AppDimens__MCfactor(strategy = invalid as dynamic) as float
    return m.cresolve(strategy).factor
end function

' ── Global functions, the AppDimens way (cdp(16, "brand") / csp(14, "brand") like the Web) ──────────
' strategy: registered id, built-in / preset id, strategy object or text formula ("base * pow(sw / 360, 0.8)").
function cdp(v as float, strategy = invalid as dynamic) as float
    return AppDimens_Custom().cdp(v, strategy)
end function

function csp(v as float, strategy = invalid as dynamic) as float
    return AppDimens_Custom().csp(v, strategy)
end function
