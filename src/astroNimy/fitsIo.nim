import cfitsio
import arraymancer
import tables

type
    image = object
        data: Tensor[int]
        rawHeader: Table[string, string]