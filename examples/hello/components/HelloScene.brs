sub init()
    ' Design values are px on a 1920x1080 mock-up (reference mode, the default).
    ad = AppDimens()
    safe = ad.safeRect("title")

    card = m.top.findNode("card")
    card.translation = [safe.x, safe.y]
    card.width = sdp(720)                 ' global token functions, like sdp(16) on the Web
    card.height = sdp(360)

    titleFont = CreateObject("roSGNode", "Font")
    titleFont.uri = "font:MediumBoldSystemFontFile"
    titleFont.size = ad.fontSize(48)
    title = m.top.findNode("title")
    title.font = titleFont
    title.translation = [safe.x + sdp(40), safe.y + sdp(40)]

    bodyFont = CreateObject("roSGNode", "Font")
    bodyFont.uri = "font:MediumSystemFontFile"
    bodyFont.size = ad.fontSize(28, "logarithmic")    ' TV-friendly growth for long text
    body = m.top.findNode("body")
    body.font = bodyFont
    body.width = sdp(640)
    body.translation = [safe.x + sdp(40), safe.y + asdp(120)]

    m.top.summary = "space=" + ad.surfaceWidth.ToStr() + "x" + ad.surfaceHeight.ToStr() + " card=" + card.width.ToStr() + " font=" + titleFont.size.ToStr()
    m.top.ready = true
end sub
