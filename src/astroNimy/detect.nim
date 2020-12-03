import arraymancer
import math
import dataTypes
import operations

proc detectStars*(image: var Image, minSpan: int = 10, maxSpan: int = 100, maxStars: int = 10) =
    var imageCopy = image
    imageCopy.boxBlur()

    let av1 = sum(imageCopy.data.astype(uint64)) div (imageCopy.shape[0] * imageCopy.shape[1]).uint64

    var dev: seq[int]
    for x in 0..<imageCopy.shape[0]:
        for y in 0..<imageCopy.shape[1]:
            dev.add(abs(imageCopy.data[x, y].int - av1.int))

    image.noiseFloor = av1 + ((sum(dev) div len(dev)).uint64 * 1)

    var binary = newTensor[bool](imageCopy.shape[0], imageCopy.shape[1])

    for x in 0..<imageCopy.shape[0]:
        for y in 0..<imageCopy.shape[1]:
            if imageCopy.data[x, y] < image.noiseFloor:
                binary[x, y] = false
            else:
                binary[x, y] = true
    
    image.binary = binary

    var numFound = @[0]
    while true:
        
        let max = max(imageCopy.data)
        var source: array[2, int]
        block findMax:
            for x in 0..<image.shape[0]:
                for y in 0..<image.shape[1]:
                    if imageCopy.data[x, y] == max:
                        source = [x, y]
                        break findMax

        var last = 0
        var register: seq[Loc]
        for span in minSpan..maxSpan:
            for a in -span..span:
                for b in -span..span:
                    try:
                        let tmp = (x: source[0]+a, y: source[1]+b)
                        if binary[tmp[0], tmp[1]]:
                            if tmp notin register:
                                register.add(tmp)
                    except IndexError:
                        continue
            
            if len(register) > last:
                last = len(register)
            else:
                if last >= minSpan.float.pow(2.float).int:
                    
                    var lastMax = 0.uint16
                    var lastLoc: Loc
                    for i in register:
                        let value = image.data[i.x, i.y]
                        if value > lastMax:
                            lastLoc = i
                            lastMax = value
                    
                    image.stars.add(Star(loc: lastLoc, pixelSize: span*2))
                
                for i in register:
                    binary[i[0], i[1]] = false
                    imageCopy.data[i[0], i[1]] = 0.uint16
                
                break
        
        if len(image.stars) == maxStars or len(image.stars) == numFound[^min([len(numFound), 10])]:
            break
        else:
            numFound.add(len(image.stars))

when compileOption("threads"):
    import threadpool
    var chan: Channel[tuple[index: int, image: Image]]

    proc detectOne(image: Image, index: int) =
        var img = image
        img.detectStars()
        chan.send((index: index, image: img))

proc detectInEach*(imgSeq: var ImgSeq) =
    when compileOption("threads"):
        var tmpChan: Channel[tuple[index: int, image: Image]]
        chan = tmpChan
        chan.open()

        for index in 0..<len(imgSeq.images):
            spawn detectOne(imgSeq.images[index], index)
        
        var count = 0
        while count < len(imgSeq.images):
            let data = chan.recv()
            imgSeq.images[data.index] = data.image
            count += 1
        
        chan.close()
    
    else:
        for index in 0..<len(imgSeq.images):
            imgSeq.images[index].detectStars()
    