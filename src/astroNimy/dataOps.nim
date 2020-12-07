import arraymancer

# https://github.com/edubart/arraymancer-vision

proc scale_nearest*[T](src: Tensor[T], width, height: int): Tensor[T] =
    result = newTensor([src.channels, height, width], T)
    let
        step_x = src.height.float32 / height.float32
        step_y = src.width.float32 / width.float32
    for c in 0..<src.channels:
        for y in 0..<height:
            let sy = (y.float32 * step_y).int
            for x in 0..<width:
                let sx = (x.float32 * step_x).int
                result[c, y, x] = src[c, sy, sx]
                
