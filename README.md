# astroNimy
A Nim library for astronomical image processing

## Recipes

### Photometry

``` nim
import astroNimy

var imgSeq = loadDir("svCen")

imgSeq.binEach(2)
imgSeq.detectInEach()
imgSeq.relate()

let target = imgSeq.images[0].chooseStar()
let control = imgSeq.images[0].chooseStar()

imgSeq.trackMagnitude(target, control, 8.74).graph("out.png")
```