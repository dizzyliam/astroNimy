import dataTypes
import math
import hashes


proc getCommonStars(reference, target: Image, n: int): seq[Hash] =
    for star in reference.stars:
        let tmp = target.getStar(star.id)
        if tmp.exists(): # if star exists in both images
            result.add(star.id)
            if result.len() >= n:
                break

proc calcTransform*(reference, target: Image): Transform =
    let 
        stars = getCommonStars(reference, target, 2)
        reference1 = reference.getStar(stars[0]).loc
        reference2 = reference.getStar(stars[1]).loc
        target1 = target.getStar(stars[0]).loc
        target2 = target.getStar(stars[1]).loc
     
    # calculation of translation offset between star1 (the reference) in both images
    result.translation = (x: target1.x - reference1.x,
                          y: target1.y - reference1.y)
    
    # calculation of the angle betwen star1 and star2 in both images
    let refRotation = arctan2((reference1.y - reference2.y).float, (reference1.x - reference2.x).float)
    let tgtRotation = arctan2((target1.y - target2.y).float, (target1.x - target2.x).float)
    
    # change in rotation necessary for the images to be aligned
    result.rotation = tgtRotation - refRotation
    result.origin = reference1
    
    # change in scale
    echo [reference1, reference2, target1, target2]
    result.scale = ((reference1.x-reference2.x).float.pow(2) + (reference1.y-reference2.y).float.pow(2)) /
                ((target1.x-target2.x).float.pow(2) + (target1.y-target2.y).float.pow(2))
                
                
proc transformPoint*(transform: Transform, point: Loc): Loc = 
    # translate
    result = point + transform.translation  
    echo "After translation"
    echo result
    # rotate
    let
        px = result.x
        py = result.y
        oy = transform.origin.y
        ox = transform.origin.x
        angle = transform.rotation
        qx = ox.float + cos(angle) * (px - ox).float - sin(angle) * (py - oy).float
        qy = oy.float + sin(angle) * (px - ox).float + cos(angle) * (py - oy).float
    result = (x: qx.int, y: qy.int)
    echo "After rotation"
    echo result
    # scale
    let 
        dx = result.x - ox
        dy = result.y - oy
        toAdd = (x: (dx.float * transform.scale).int + ox, y: (dy.float * transform.scale).int + oy)
    echo "adding"
    echo toAdd
    result = result + toAdd
    echo "After scaling"
    echo result
        
    
