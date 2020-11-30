import arraymancer
import fitsIO
import math
import dataTypes
import utils

proc bufferedGet(data: Tensor[uint16], x, y: int): uint16 = 
    if x >= 0 and x < data.shape[0] and y >= 0 and y < data.shape[1]:
        return data[x, y]
    else:
        return 0

proc blurAxis(data: Tensor[uint16], size: int): Tensor[uint16] =
    var tmpData = deepCopy(data)
    for x in 0..<data.shape[0]:
        
        var sum = 0.uint64
        for y in 0..<data.shape[1]:

            if y == 0:
                for i in -size..size:
                    sum += data.bufferedGet(x, i)

            else:
                sum += data.bufferedGet(x, y+size)
                sum -= data.bufferedGet(x, y-size)
            
            tmpData[x, y] = (sum div ((2*size)+1).uint64).uint16
    
    return tmpData

proc boxBlur*(fits: var FITS, size: int = 4) =
    fits.data = fits.data.blurAxis(size=size).transpose().blurAxis(size=size).transpose()