import astroNimy

var image = loadImage("tests/test.fit")
image.boxBlur()
image.register(maxStars=10)
echo(image.stars)