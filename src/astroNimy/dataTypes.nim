import tables
import arraymancer

type

    Star* = object
        loc*: array[2, int]
        pixelSize*: int

    FITS* = object
        headers*: Table[string, string]
        shape*: array[2, int]
        data*: Tensor[uint16]
        stars*: seq[Star]