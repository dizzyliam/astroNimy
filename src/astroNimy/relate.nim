import dataTypes
import arraymancer
import math
import sets
import tables
import sequtils
import algorithm
import hashes

proc getLength(a, b: Star): float =
    return sqrt((a.loc.x - b.loc.x).float.pow(2) + (a.loc.y - b.loc.y).float.pow(2))

proc getAngle(a, b, c: Star): float =

    let 
        x = getLength(a, b)
        y = getLength(b, c)
        z = getLength(c, a)
    
    return radToDeg(arccos( (x.pow(2)+y.pow(2)-x.pow(2)) / (2*x*y) ))

proc relate*(imgSeq: var ImgSeq) =
    var triPool: seq[array[3, tuple[id: Hash, angle: float]]]
    var hashPool: seq[Hash]
    for imageIndex, image in imgSeq.images:
        var tmpPool: seq[array[3, tuple[id: Hash, angle: float]]]
        var voteTable: Table[int, seq[Hash]]

        for index, star in image.stars:
            imgSeq.images[imageIndex].stars[index].id = !$(hash(star) !& imageIndex.hash)

        for index, star in image.stars:

            var tris: seq[array[3, tuple[index: int, angle: float]]]

            for index1, star1 in image.stars:
                for index2, star2 in image.stars:
                    if deduplicate([index, index1, index2]).len() == 3:

                        var tmp: seq[Star]
                        for i in [index, index1, index2]:
                            tmp.add(image.stars[i])
                        
                        let tri = [
                            (index: index, angle: getAngle(tmp[1], tmp[0], tmp[2])),
                            (index: index1, angle: getAngle(tmp[0], tmp[1], tmp[2])),
                            (index: index2, angle: getAngle(tmp[1], tmp[2], tmp[0]))
                        ]

                        tris.add(tri)

                        for past in triPool:
                            var offset = -1
                            for i in 0..2:
                                var tmp = past
                                tmp.rotateLeft(-i)
                                if (abs(past[0].angle - tri[0].angle) + abs(past[1].angle - tri[1].angle) + abs(past[2].angle - tri[2].angle)) / 3 < 1:
                                    offset = i
                                    break
                            
                            if offset != -1:
                                var tri2 = past
                                tri2.rotateLeft(-offset)

                                for i in 0..2:
                                    if voteTable.hasKey(tri[i].index):
                                        voteTable[tri[i].index].add(tri2[i].id)
                                    else:
                                        voteTable[tri[i].index] = @[tri2[i].id]
            
            for index in voteTable.keys():
                imgSeq.images[imageIndex].stars[index].id = toCountTable(voteTable[index]).largest()[0]

            for tri in tris:
                let tmp = [
                    (id: imgSeq.images[imageIndex].stars[tri[0].index].id, angle: tri[0].angle),
                    (id: imgSeq.images[imageIndex].stars[tri[1].index].id, angle: tri[1].angle),
                    (id: imgSeq.images[imageIndex].stars[tri[2].index].id, angle: tri[2].angle)
                ]

                let hash = !$((tmp[0].id - tmp[0].angle.int) !& (tmp[1].id - tmp[1].angle.int) !& (tmp[0].id - tmp[0].angle.int) !& (tmp[0].id - tmp[0].angle.int))
                if hash notin hashPool:
                    tmpPool.add(tmp)
                    hashPool.add(hash)
        
        triPool &= tmpPool