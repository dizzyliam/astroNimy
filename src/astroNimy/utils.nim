import nigui
import math
import arraymancer
import dataTypes
import hashes

quitOnLastWindowClose = false

proc preview*(image: dataTypes.Image) = 
    app.init()
    # Make window, image, etc.
    var window = newWindow("Image")
    var control = newControl()
    window.add(control)
    var tmp = newImage()

    let mi = min(image.data)
    let ma = max(image.data) - mi

    let iCanvas = tmp.canvas
    tmp.resize(image.shape[0], image.shape[1])

    for x in 0..<image.shape[0]:
        for y in 0..<image.shape[1]:
            let value = floor(((image.data[x, y]-mi).float/ma.float).float*255).int
            iCanvas.setPixel(x, y, rgb(value.byte, value.byte, value.byte))
    
    iCanvas.lineColor = rgb(255, 0, 0)
    for i in image.stars:
        let size = i.pixelSize
        let halfSize = size div 2
        iCanvas.drawRectOutline(i.loc.x-halfSize, i.loc.y-halfSize, size, size)

    # Draw image according to scale
    var scale = 0.75
    control.onDraw = proc (event: DrawEvent) =
        let canvas = event.control.canvas

        var scalar = 0.0
        if window.width <= window.height:
            scalar = (window.width / image.shape[0]) * scale
        else:
            scalar = (window.height / image.shape[1]) * scale

        let width = toInt(toFloat(image.shape[0]) * scalar)
        let height = toInt(toFloat(image.shape[1]) * scalar)

        let xOffset = toInt((window.width-width)/2)
        let yOffset = toInt((window.height-height)/2)

        canvas.drawImage(tmp, xOffset, yOffset, width, height)

    # Scale with mouseclick
    control.onMouseButtonDown = proc (event: MouseEvent) =
        case event.button:
            of MouseButton_Left:
                scale += 0.05
            of MouseButton_Right:
                scale -= 0.05
            else:
                discard
        
        if scale < 0.05:
            scale = 0.05
        
        control.forceRedraw()

    window.show()
    app.run()

proc chooseStar*(image: dataTypes.Image): Hash = 
    app.init()
    # Make window, image, etc.
    var window = newWindow("Star Selector")
    var control = newControl()
    window.add(control)
    var tmp = newImage()

    let mi = min(image.data)
    let ma = max(image.data) - mi

    let iCanvas = tmp.canvas
    tmp.resize(image.shape[0], image.shape[1])

    for x in 0..<image.shape[0]:
        for y in 0..<image.shape[1]:
            let value = floor(((image.data[x, y]-mi).float/ma.float).float*255).int
            iCanvas.setPixel(x, y, rgb(value.byte, value.byte, value.byte))
    
    iCanvas.lineColor = rgb(255, 0, 0)
    for i in image.stars:
        let size = i.pixelSize
        let halfSize = size div 2
        iCanvas.drawRectOutline(i.loc.x-halfSize, i.loc.y-halfSize, size, size)

    var 
        scalar: float
        width: int
        height: int
        xOffset: int
        yOffset: int

    # Draw image according to scale
    control.onDraw = proc (event: DrawEvent) =
        let canvas = event.control.canvas

        if window.width <= window.height:
            scalar = (window.width / image.shape[0])
        else:
            scalar = (window.height / image.shape[1])

        width = toInt(toFloat(image.shape[0]) * scalar)
        height = toInt(toFloat(image.shape[1]) * scalar)
        xOffset = toInt((window.width-width)/2)
        yOffset = toInt((window.height-height)/2)

        canvas.drawImage(tmp, xOffset, yOffset, width, height)
    
    var gResult: Hash

    # Scale with mouseclick
    control.onMouseButtonDown = proc (event: MouseEvent) =
        case event.button:
            of MouseButton_Left:

                let xPix = ((event.x-xOffset).float/width.float) * image.shape[0].float
                let yPix = ((event.y-yOffset).float/height.float) * image.shape[1].float
                
                for star in image.stars:
                    if sqrt( (xPix-star.loc.x.float).pow(2) + (yPix-star.loc.y.float).pow(2)) < star.pixelSize.float / 2:
                        gResult = star.id
                        window.dispose()
                        app.quit()

            else:
                discard

    window.show()
    app.run()
    return gResult