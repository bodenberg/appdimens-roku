sub init()
    ' Design values are px on a 1920x1080 mock-up (reference mode, the default).
    ad = AppDimens()
    safe = ad.safeRect("title")

    card = m.top.findNode("card")
    card.translation = [safe.x, safe.y]
    card.width = ad.sdp(720)
    card.height = ad.sdp(360)

    titleFont = CreateObject("roSGNode", "Font")
    titleFont.uri = "font:MediumBoldSystemFontFile"
    titleFont.size = ad.fontSize(48)
    title = m.top.findNode("title")
    title.font = titleFont
    title.translation = [safe.x + ad.sdp(40), safe.y + ad.sdp(40)]

    bodyFont = CreateObject("roSGNode", "Font")
    bodyFont.uri = "font:MediumSystemFontFile"
    bodyFont.size = ad.fontSize(28, "logarithmic")    ' TV-friendly growth for long text
    body = m.top.findNode("body")
    body.font = bodyFont
    body.width = ad.sdp(640)
    body.translation = [safe.x + ad.sdp(40), safe.y + ad.asdp(120)]

    m.top.summary = "space=" + ad.surfaceWidth.ToStr() + "x" + ad.surfaceHeight.ToStr() + " card=" + card.width.ToStr() + " font=" + titleFont.size.ToStr()
    m.top.ready = true
end sub
