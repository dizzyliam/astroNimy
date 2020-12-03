import streams
import tables
import arraymancer
import strutils
import dataTypes
import endians2
import os
import times
import sequtils

proc getStr*(image: Image, key: string): string =
    return image.headers[key]

proc getInt*(image: Image, key: string): int =
    return parseInt(image.headers[key])

proc getFloat*(image: Image, key: string): float =
    return parseFloat(image.headers[key])

proc loadImage*(fn: string): Image = 
    let fs = openFileStream(fn)
    
    var headers = initTable[string, string]()

    while fs.peekStr(3) != "END":
        let name = fs.readStr(8).strip(chars={' '})
        let indicator = fs.readStr(2).strip(chars={' '})

        # Split the value/comment field
        let valueAndComment = fs.readStr(70).strip(chars={' '})
        let value = valueAndComment.split("/")[0].strip(chars={' ', '\''})

        var comment = "none"
        if "/" in valueAndComment:
            comment = valueAndComment.split("/")[1].strip(chars={' '})

        # Add string to headers table, but only if there is a value indicator
        if indicator == "=":
            headers[name] = value
    
    discard fs.readStr(3)
    
    # Load header data into object for ease of use
    var image = Image(headers: headers)

    # Get info about image shape from headers
    let nAxes = image.getInt("NAXIS")
    var shape = newSeq[int](0)
    for i in 1..nAxes:
        shape.add(image.getInt("NAXIS" & intToStr(i)))
    
    let bits = image.getInt("BITPIX")
    let bzero = image.getFloat("BZERO").uint16

    while fs.getPosition().mod(2880) != 0:
        fs.setPosition(fs.getPosition()+1)
    
    image.data = newTensor[uint16](shape[0], shape[1])
    for y in 0..<shape[1]:
        for x in 0..<shape[0]:

            case bits:
                of 8:
                    image.data[x, y] = fs.readUInt8().uint16
                of 16:
                    image.data[x, y] = (cast[int16](fromBE(fs.readUInt16())).uint16 + bzero).uint16
                else:
                    raise newException(IOError, "Unsupported bit/pixel value")
    
    image.shape = [shape[0], shape[1]]
    fs.close()

    image.time = parse(image.headers["DATE-OBS"], "yyyy-MM-dd'T'HH:mm:ss'.'fff", utc())
    
    return image

proc loadDir*(dir: string): ImgSeq =
    let files = toSeq(walkFiles(dir / "*"))
    for index, i in files:
        result.images.add(loadImage(i))