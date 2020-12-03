import dataTypes
import hashes
import times
import arraymancer
import ggplotnim

proc trackMagnitude*(imgSeq: ImgSeq, target: Hash, control: Hash, controlMag: float = 0.0): Track =

    for image in imgSeq.images:

        let targetStar = image.getStar(target)
        let targetLoc = targetStar.loc

        let controlStar = image.getStar(control)
        let controlLoc = targetStar.loc

        if targetStar.exists() and controlStar.exists():
            
            var targetFlux: int64
            var span = targetStar.pixelSize div 2
            for a in -span..span:
                for b in -span..span:
                    targetFlux += max([0.int64, (image.data[targetLoc.x+a, targetLoc.y+b]-image.noiseFloor).int64])

            var controlFlux: int64
            span = controlStar.pixelSize div 2
            for a in -span..span:
                for b in -span..span:
                    controlFlux += max([0.int64, (image.data[controlLoc.x+a, controlLoc.y+b]-image.noiseFloor).int64])
            
            let time = image.time.toTime.toUnixFloat()
            result.add((time: time, mag: controlMag + (-2.5 * log10(targetFlux.float64/controlFlux.float64)) ))

proc graph*(track: Track, outputFile: string) =
    var 
        Time: seq[float]
        Magnitude: seq[float]
    
    for i in track:
        Time.add(i.time)
        Magnitude.add(i.mag)

    let df = seqsToDf(Time, Magnitude)
    
    ggplot(df, aes("Time", "Magnitude")) +
        geom_point() +
        ggsave(outputFile)