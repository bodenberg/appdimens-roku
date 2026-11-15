' Custom strategies: the cross-platform 540-case fixture (Kotlin reference engine) + API behaviour.
sub RunExtraTests(t as object)
    AppDimens_ResetStrategies()
    fx = ParseJson(ReadAsciiFile("pkg:/tests/custom-strategy-fixture.json"))
    tol = fx.tolerance
    d = AppDimens_DecodeStrategies(fx.document)
    Check(t, d.ok, "decode fixture: " + d.error)
    if not d.ok then return
    Check(t, d.defaultId = "brand", "fixture default")
    screens = {}
    screens.SetModeCaseSensitive()
    for each name in fx.screens
        s = fx.screens[name]
        screens[name] = AppDimens_CustomScreen(s.width, s.height, s.density, s.fontScale, s.device, s.multiWindow, s.smallestWidth, s.landscape)
    end for
    Check(t, fx.cases.Count() = 540, "540 cases")
    bad = 0
    for each c in fx.cases
        r = AppDimens_ResolveStrategy(d.strategies[c.strategy], screens[c.screen])
        dp = AppDimens_ScaleResolved(r, c.base)
        sp = AppDimens_ScaleSpResolved(r, c.base)
        rules = ""
        for each n in r.rules
            if rules <> "" then rules = rules + ","
            rules = rules + n
        end for
        want = ""
        for each n in c.rules
            if want <> "" then want = want + ","
            want = want + n
        end for
        ok = Near(c.factor, r.factor, tol) and Near(c.dp, dp, tol) and Near(c.spDp, sp, tol) and rules = want
        if not ok then
            bad = bad + 1
            if bad <= 10 then print "custom "; c.strategy; "/"; c.screen; " base "; c.base; ": factor "; c.factor; "/"; r.factor; " dp "; c.dp; "/"; dp; " sp "; c.spDp; "/"; sp; " rules '"; want; "'/'"; rules; "'"
        end if
    end for
    print "custom fixture: "; 540 - bad; "/540 cases match"
    Check(t, bad = 0, "custom fixture")

    ' API
    err = AppDimens_LoadStrategies(fx.document)
    Check(t, err = "", "load fixture document")
    Check(t, AppDimens_DefaultStrategy().id = "brand", "default applied")
    scr = AppDimens_CustomScreen(720, 1280, 2, 1)
    product = AppDimens_CustomFactor("product", function(s)
        f = s.width / 360.0
        if f < 0.85 then f = 0.85
        if f > 1.8 then f = 1.8
        return f
    end function)
    Check(t, Near(18.0, AppDimens_ScaleResolved(AppDimens_ResolveStrategy(product, scr), 10)), "code factor")
    hud = AppDimens_CustomFormula("hud", function(base, s) : return base * ((s.sw / 360.0) ^ 0.8) : end function)
    Check(t, Near(16 * (2.0 ^ 0.8), AppDimens_ScaleResolved(AppDimens_ResolveStrategy(hud, scr), 16), 1e-5), "code formula")
    f1 = AppDimens_Formula("base * pow(sw / 360, 0.8)")
    f1.marker = 7
    Check(t, AppDimens_Formula("base * pow(sw / 360, 0.8)").marker = 7, "formula shared per text")
    Check(t, Near(16 * (2.0 ^ 0.8), AppDimens_ScaleResolved(AppDimens_ResolveStrategy(f1, scr), 16), 1e-5), "text formula")
    Check(t, AppDimens_ParseExpression("base * (", 2).ok = false, "syntax error")
    Check(t, AppDimens_ParseExpression("foo + 1", 2).ok = false, "unknown variable")
    Check(t, AppDimens_ParseExpression("pow(1)", 2).ok = false, "arity")
    Check(t, AppDimens_ParseExpression("tablet ? 1.2 : 1e0 + 2.5e-1 * 0", 0).ok, "ternary + exponent numbers")
    e = AppDimens_ParseExpression("clamp(ratio, 0.9, 1.5) + (landscape && !tv ? 1 : 0) + 2 ^ 3 % 5 - smoothstep(0, 10, 5)", 1)
    Check(t, e.ok, "complex expression")
    env = AppDimens__Env(scr, 2.0, 720, 360, 360, 640)
    Check(t, Near(1.5 + 0 + 3 - 0.5, AppDimens__Eval(e.expr.root, env)), "evaluate complex expression")
    err = AppDimens_LoadStrategies("{""version"":1,""strategies"":[{""id"":""x"",""clamp"":5}]}")
    Check(t, err <> "" and AppDimens_GetStrategy("x") = invalid, "strict + atomic: " + err)
    err = AppDimens_LoadStrategies("{""version"":1,""strategies"":[{""id"":""a"",""extends"":""b""},{""id"":""b"",""extends"":""a""}]}")
    Check(t, Instr(1, err, "Cyclic") > 0, "cyclic extends")
    err = AppDimens_LoadStrategies("{""version"":1,""strategies"":[{""id"":""y"",""extends"":""nope""}]}")
    Check(t, Instr(1, err, "unknown strategy") > 0, "unknown parent")
    Check(t, AppDimens_GetStrategy("gameHud") <> invalid and AppDimens_GetStrategy("TVSAFE") <> invalid, "presets")

    ' Instance methods on a Roku TV (reference mode)
    ad = AppDimens_Custom()
    ad2 = AppDimens_Create({ width: 1920, height: 1080 })
    AppDimens_InstallCustom(ad2)
    Check(t, Near(24, ad2.cdp(24, "scaled")), "cdp scaled = identity at the reference")
    Check(t, Near(ad2.sdp(24), ad2.cdp(24, "scaled")), "cdp scaled = sdp")
    tvs = ad2.cresolve("tvSafe")
    Check(t, tvs.rules.Count() = 1 and tvs.rules[0] = "tv", "tvSafe rule applies on Roku")
    Check(t, Near(16 * 2.0 ^ 0.8 * 0 + ad2.cdp(16, "base * (sw / 360)"), ad2.cdp(16, "base * (sw / 360)")), "cdp with a formula")
    Check(t, Near(ad2.cdp(14, "readableText") * 1.0, ad2.csp(14, "readableText")), "csp with font scale 1")
    Check(t, ad.cdp <> invalid, "AppDimens_Custom installs methods")
    AppDimens_SetDefaultStrategy("logarithmic")
    Check(t, Near(ad2.cdp(10, "logarithmic"), ad2.cdp(10)), "default strategy used")
    AppDimens_ResetStrategies()
end sub
