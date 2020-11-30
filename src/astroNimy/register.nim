import arraymancer
import math
import dataTypes

proc register*(fits: var FITS, minSpan: int = 2, maxSpan: int = 100, maxStars: int = 1000) =
    let av1 = sum(fits.data.astype(uint64)) div (fits.shape[0] * fits.shape[1]).uint64

    var dev: seq[int]
    for x in 0..<fits.shape[0]:
        for y in 0..<fits.shape[1]:
            dev.add(abs(fits.data[x, y].int - av1.int))

    let av2 = av1 + ((sum(dev) div len(dev)).uint64 * 1)

    var binary = newTensor[bool](fits.shape[0], fits.shape[1])

    for x in 0..<fits.shape[0]:
        for y in 0..<fits.shape[1]:
            if fits.data[x, y] < av2:
                binary[x, y] = false
            else:
                binary[x, y] = true
    
    var fitsCopy = deepCopy(fits)

    var numFound = @[0]
    while true:
        
        let max = max(fitsCopy.data)
        var source: array[2, int]
        block findMax:
            for x in 0..<fits.shape[0]:
                for y in 0..<fits.shape[1]:
                    if fitsCopy.data[x, y] == max:
                        source = [x, y]
                        break findMax

        var last = 0
        var register: seq[array[2, int]]
        for span in minSpan..maxSpan:
            for a in -span..span:
                for b in -span..span:
                    try:
                        let tmp = [source[0]+a, source[1]+b]
                        if binary[tmp[0], tmp[1]]:
                            if tmp notin register:
                                register.add(tmp)
                    except IndexError:
                        continue
            
            if len(register) > last:
                last = len(register)
            else:
                if last >= minSpan.float.pow(2.float).int:
                    
                    var xsum = 0
                    var ysum = 0
                    for i in register:
                        xsum += i[0]
                        ysum += i[1]
                    
                    fits.stars.add(Star(loc: [xsum div last, ysum div last], pixelSize: span))
                
                for i in register:
                    binary[i[0], i[1]] = false
                    fitsCopy.data[i[0], i[1]] = 0.uint16
                
                break
        
        if len(fits.stars) == maxStars or len(fits.stars) == numFound[^min([len(numFound), 10])]:
            break
        else:
            numFound.add(len(fits.stars))