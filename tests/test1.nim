import astroNimy

var fits = loadFITS("tests/test.fit")
fits.boxBlur()
fits.register(maxStars=10)
echo(fits.stars)