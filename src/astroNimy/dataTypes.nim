import tables
import arraymancer
import hashes
import times

type

    Loc* = tuple[x, y: int]

    Star* = object
        loc*: Loc
        pixelSize*: int
        id*: Hash

    Image* = object
        headers*: Table[string, string]
        shape*: array[2, int]
        data*: Tensor[uint16]
        stars*: seq[Star]
        noiseFloor*: uint64
        binary*: Tensor[bool]
        time*: DateTime
    
    ImgSeq* = object
        images*: seq[Image]
        transforms*: seq[Transform]
    
    Track* = seq[tuple[time: float, mag: float]]
    
    Transform* = object
        scale*: float
        rotation*: float
        origin*: Loc
        translation*: tuple[x, y: int]
    
proc `+`*(a, b: Loc): Loc = 
    result.x = a.x + b.x
    result.y = a.y + b.y

proc `-`*(a, b: Loc): Loc = 
    result.x = a.x - b.x
    result.y = a.y - b.y

proc hash*(x: Star): Hash =
    result = x.loc.hash !& x.pixelSize.hash
    result = !$result

proc getStar*(image: Image, id: Hash): Star =
    for i in image.stars:
        if i.id == id:
            return i

proc exists*(star: Star): bool =
    if star.loc.x + star.loc.y + star.pixelSize == 0:
        return false
    else:
        return true
