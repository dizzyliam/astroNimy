import arraymancer
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

proc boxBlur*(image: var Image, size: int = 4) =
    image.data = image.data.blurAxis(size=size).transpose().blurAxis(size=size).transpose()

proc bin*(image: var Image, size: int) =
    var newImage = image
    newImage.shape = [image.shape[0] div size, image.shape[1] div size]
    newImage.data = newTensor[uint16](newImage.shape[0], newImage.shape[1])

    for x in 0..<newImage.shape[0]:
        for y in 0..<newImage.shape[1]:
            var tmp: seq[uint64]
            for a in 0..<size:
                for b in 0..<size:
                    try:
                        tmp.add(image.data[(x*size)+a, (y*size)+b])
                    except IndexError:
                        continue
            newImage.data[x, y] = (sum(tmp) div len(tmp).uint64).uint16
    
    image = newImage

proc binEach*(imgSeq: var ImgSeq, size: int) =
    for index in 0..<len(imgSeq.images):
        imgSeq.images[index].bin(size)

    
