' AppDimens Roku test suite — runs in brs-cli (brs-engine) and on a device (sideload tests/).
' Prints "APPDIMENS TESTS: <passed>/<total> passed" and one "FAIL" line per failure.

sub Main(args as dynamic)
    t = { pass: 0, fail: 0 }
    TestParity(t)
    TestTokens(t)
    TestModes(t)
    TestDevice(t)
    RunExtraTests(t)
    print "APPDIMENS TESTS: "; t.pass; "/"; t.pass + t.fail; " passed"
    if t.fail = 0 then print "APPDIMENS RESULT: OK" else print "APPDIMENS RESULT: FAILED"
end sub

sub Check(t as object, ok as boolean, label as string)
    if ok then
        t.pass = t.pass + 1
    else
        t.fail = t.fail + 1
        if t.fail <= 25 then print "FAIL "; label
    end if
end sub

function Near(want as float, got as dynamic, rel = 3e-6 as float) as boolean
    if got = invalid then return false
    d = Abs(want - got)
    m = Abs(want)
    if m < 1.0 then m = 1.0
    return d <= rel * m
end function

sub TestParity(t as object)
    g = ParseJson(ReadAsciiFile("pkg:/tests/golden.json"))
    names = AppDimens_Strategies()
    Check(t, g.strategies.Count() = names.Count(), "strategy count")
    for i = 0 to names.Count() - 1
        Check(t, g.strategies[i] = names[i], "strategy order " + names[i])
    end for
    bad = 0
    total = 0
    for each c in g.cases
        m0 = AppDimens_Metrics(c.w, c.h, c.density, c.fontScale, c.multiWindow)
        for s = 0 to names.Count() - 1
            want = c.factors[names[s]]
            row = m0.row(s)
            for k = 0 to 43
                total = total + 1
                if not Near(want[k], row[k]) then
                    bad = bad + 1
                    if bad <= 10 then print "parity "; c.w; "x"; c.h; " "; names[s]; " slot "; k; ": want "; want[k]; " got "; row[k]
                end if
            end for
        end for
        Check(t, Near(c.customK001.scaled, AppDimens_ComputeFactor(m0, 0, 0, 0, false, true, 0.01)), "customK scaled")
        Check(t, Near(c.customK001.auto, AppDimens_ComputeFactor(m0, 1, 0, 0, false, true, 0.01)), "customK auto")
    end for
    print "parity: "; total - bad; "/"; total; " factors match"
    Check(t, bad = 0, "parity factors")
end sub

sub TestTokens(t as object)
    g = ParseJson(ReadAsciiFile("pkg:/tests/golden.json"))
    for ci = 0 to 5
        c = g.cases[ci]
        ad = AppDimens_Create({ width: c.w * c.density, height: c.h * c.density, density: c.density, fontScale: c.fontScale, multiWindow: c.multiWindow, mode: "tv" })
        f = c.factors
        Check(t, Near(10 * f.scaled[0], ad.sdp(10)), "sdp")
        Check(t, Near(10 * f.auto[1], ad.asdpa(10)), "asdpa")
        Check(t, Near(10 * f.scaled[4 + 2], ad.hdpi(10)), "hdpi")
        Check(t, Near(10 * f.scaled[8 + 3] * c.fontScale, ad.wspia(10)), "wspia")
        Check(t, Near(10 * f.scaled[0], ad.sem(10)), "sem")
        Check(t, Near(10 * f.scaled[0] * c.density, ad.resolve("sdpPx", 10)), "sdpPx")
        Check(t, Near(10 * f.scaled[12], ad.resolve("sdpPh", 10)), "sdpPh")
        Check(t, Near(10 * f.scaled[15] * c.density, ad.resolve("sdpPxiaPh", 10)), "sdpPxiaPh")
        Check(t, Near(10 * f.scaled[29], ad.resolve("hdpLwa", 10)), "hdpLwa")
        Check(t, Near(10 * f.logarithmic[0] * c.fontScale, ad.logssp(10)), "logssp")
        Check(t, Near(10 * f.fit[0], ad.ftsdp(10)), "ftsdp")
        Check(t, Near(10 * f.diagonal[8], ad.dgwdp(10)), "dgwdp")
        Check(t, Near(10 * f.power[0], ad.pwsdp(10)), "pwsdp")
        Check(t, Near(10 * f.percent[8], ad.pwdp(10)), "pwdp = percent w")
        Check(t, Near(16 * f.auto[0], ad.dimen("16asdp")), "dimen 16asdp")
        Check(t, Near(-4 * f.scaled[28], ad.dimen("-4hdpLw")), "dimen -4hdpLw")
        Check(t, Near(14.5 * f.auto[0] * c.fontScale, ad.dimen("14.5assp")), "dimen 14.5assp")
        Check(t, Near(50 * 0.01 * c.w, ad.dimen("50spaceW")), "dimen spaceW")
        Check(t, Near(3.0 / c.density, ad.dimen("3px")), "dimen px")
    end for
    ad = AppDimens_Create({ width: 1920, height: 1080 })
    Check(t, ad.resolve("xdp", 1) = invalid, "unknown token")
    Check(t, ad.resolve("sdpaa", 1) = invalid, "double flags")
    Check(t, ad.resolve("hdpPh", 1) = invalid, "invalid inverter")
    Check(t, ad.dimen("sdp") = invalid, "no number")
    Check(t, ad.dimen("16zz") = invalid, "bad suffix")
    tk = AppDimens_ParseToken("logwemPxiaLh")
    Check(t, tk <> invalid and tk.strategy = 6 and tk.kind = 2 and tk.px = true and tk.slot = 9 * 4 + 3, "parse logwemPxiaLh")
end sub

sub TestModes(t as object)
    ' reference mode: px at 1920x1080 → coordinates
    fhd = AppDimens_Create({ width: 1920, height: 1080 })
    Check(t, Near(96, fhd.sdp(96)), "reference identity at FHD")
    Check(t, Near(96 * (1920.0 / 3.6) / 300.0, fhd.wdp(96)), "reference wdp at FHD follows the width axis")
    Check(t, fhd.fontSize(32) = 32, "fontSize identity")
    hd = AppDimens_Create({ width: 1280, height: 720 })
    Check(t, Near(64, hd.sdp(96)), "reference FHD→HD")
    Check(t, Near(64, hd.px(64)), "px is identity in reference mode")
    Check(t, hd.fontSize(33) = 22, "fontSize HD rounds")
    Check(t, Near(fhd.wdp(1200) * 2.0 / 3.0, hd.wdp(1200)), "reference w axis FHD→HD")
    sd = AppDimens_Create({ width: 720, height: 480 })
    Check(t, Near(96 * 480.0 / 1080.0, sd.sdp(96)), "reference SD")
    cust = AppDimens_Create({ width: 1280, height: 720, reference: { width: 1280, height: 720 } })
    Check(t, Near(24, cust.sdp(24)), "custom reference")
    ' tv mode: Android TV dp space (960x540)
    tv = AppDimens_Create({ width: 1920, height: 1080, mode: "tv" })
    Check(t, Near(2.0, tv.density), "tv density FHD")
    Check(t, Near(960, tv.width) and Near(540, tv.height), "tv dp space FHD")
    tvhd = AppDimens_Create({ width: 1280, height: 720, mode: "tv" })
    Check(t, Near(960, tvhd.width) and Near(540, tvhd.height), "tv dp space HD")
    Check(t, Near(tv.sdp(16), tvhd.sdp(16)), "tv dp independent of resolution")
    Check(t, Near(tv.sdp(16) * 2.0, tv.px(tv.sdp(16))), "tv px")
    Check(t, Near(tv.resolve("sdpPx", 16), tv.px(tv.sdp(16))), "sdpPx = px(sdp)")
    Check(t, tv.fontSize(16) = Int(16 * tv.factor(0, 0) * 2.0 + 0.5), "tv fontSize in coordinates")
    px = AppDimens_Create({ width: 1280, height: 720, mode: "pixel" })
    Check(t, Near(1.0, px.density) and Near(720, px.sw), "pixel mode")
    ' safe zones
    a = fhd.safeRect()
    Check(t, Near(96, a.x) and Near(54, a.y) and Near(1728, a.width) and Near(972, a.height), "action safe FHD")
    ti = fhd.safeRect("title")
    Check(t, Near(192, ti.x) and Near(108, ti.y) and Near(1536, ti.width) and Near(864, ti.height), "title safe FHD")
    xy = hd.xy(96, 54)
    Check(t, Near(64, xy[0]) and Near(36, xy[1]), "xy")
    r = hd.rect(0, 0, 300, 150, "asdp")
    Check(t, Near(hd.asdp(300), r.width), "rect")
    ' multi-window flags
    mw = AppDimens_Metrics(600, 400, 1.0, 1.0, true)
    Check(t, mw.factor(0, 2) = 1.0 and Near(400.0 / 300.0, mw.factor(0, 0)), "i flag in multi-window")
    ' strategies by name
    Check(t, Near(hd.dp("auto", 10), hd.asdp(10)), "dp by name")
    Check(t, Near(hd.sp("logarithmic", 10), hd.logssp(10)), "sp by name")
    ' non-finite inputs
    bad = AppDimens_Metrics(-1, 0, 0, 0)
    Check(t, bad.density = 1.0 and bad.fontScale = 1.0 and bad.sw = 300.0, "sanitised inputs")
end sub

sub TestDevice(t as object)
    cs = AppDimens_CoordinateSpace()
    Check(t, cs.width > 0 and cs.height > 0, "coordinate space")
    ad = AppDimens()
    ad.testMarker = 42
    Check(t, AppDimens().testMarker = 42, "per-thread cache")
    Check(t, ad.uiMode = "television", "ui mode")
    Check(t, Near(cs.width, ad.surfaceWidth), "surface width")
    ad2 = AppDimens_Refresh()
    Check(t, ad2.surfaceWidth = cs.width, "refresh")
    ' manifest lists only fhd → coordinates stay 1920x1080 (firmware autoscale)
    Check(t, cs.name = "fhd" and cs.width = 1920 and cs.autoscaled = true, "single ui_resolution autoscale")
end sub
