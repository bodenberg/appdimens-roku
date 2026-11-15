sub Main()
    screen = CreateObject("roSGScreen")
    port = CreateObject("roMessagePort")
    screen.SetMessagePort(port)
    scene = screen.CreateScene("HelloScene")
    screen.Show()
    if scene.ready = true then print "HELLO READY "; scene.summary
    while true
        msg = Wait(2000, port)
        if msg = invalid then exit while
        if Type(msg) = "roSGScreenEvent" and msg.IsScreenClosed() then exit while
    end while
end sub
