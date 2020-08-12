import streams
import tables
import strutils
import arraymancer
import endians2

type
    FITS* = object
        headers*: Table[string, string]
        shape*: array[2, int]
        data*: Tensor[uint16]

proc getStr*(fits: FITS, key: string): string =
    return fits.headers[key]

proc getInt*(fits: FITS, key: string): int =
    return parseInt(fits.headers[key])

proc getFloat*(fits: FITS, key: string): float =
    return parseFloat(fits.headers[key])

proc loadFITS*(fn: string): FITS = 
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
    var fits = FITS(headers: headers)

    # Get info about image shape from headers
    let nAxes = fits.getInt("NAXIS")
    var shape = newSeq[int](0)
    for i in 1..nAxes:
        shape.add(fits.getInt("NAXIS" & intToStr(i)))
    
    let bits = fits.getInt("BITPIX")
    let bzero = fits.getFloat("BZERO").uint16

    while fs.getPosition().mod(2880) != 0:
        fs.setPosition(fs.getPosition()+1)
    
    fits.data = newTensor[uint16](shape[0], shape[1])
    for y in 0..<shape[1]:
        for x in 0..<shape[0]:

            case bits:
                of 8:
                    fits.data[x, y] = fs.readUInt8().uint16
                of 16:
                    fits.data[x, y] = (cast[int16](fromBE(fs.readUInt16())).uint16 + bzero).uint16
                else:
                    raise newException(IOError, "Unsupported bit/pixel value")
    
    fits.shape = [shape[0], shape[1]]

    fs.close()
    return fits
