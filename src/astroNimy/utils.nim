import fitsIO
import nigui
import math
import arraymancer
import dataTypes

proc preview*(fits: FITS) = 
    app.init()
    # Make window, image, etc.
    var window = newWindow("FITS Image")
    var control = newControl()
    window.add(control)
    var tmp = newImage()

    let mi = min(fits.data)
    let ma = max(fits.data) - mi

    let iCanvas = tmp.canvas
    tmp.resize(fits.shape[0], fits.shape[1])

    for x in 0..<fits.shape[0]:
        for y in 0..<fits.shape[1]:
            let value = floor(((fits.data[x, y]-mi).float/ma.float).float*255).int
            iCanvas.setPixel(x, y, rgb(value.byte, value.byte, value.byte))
    
    iCanvas.lineColor = rgb(255, 0, 0)
    for i in fits.stars:
        let size = i.pixelSize
        let halfSize = size div 2
        iCanvas.drawRectOutline(i.loc[0]-halfSize, i.loc[1]-halfSize, size, size)

    # Draw image according to scale
    var scale = 0.75
    control.onDraw = proc (event: DrawEvent) =
        let canvas = event.control.canvas

        var scalar = 0.0
        if window.width <= window.height:
            scalar = (window.width / fits.shape[0]) * scale
        else:
            scalar = (window.height / fits.shape[1]) * scale

        let width = toInt(toFloat(fits.shape[0]) * scalar)
        let height = toInt(toFloat(fits.shape[1]) * scalar)

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