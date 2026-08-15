using Toybox.Math;
using Toybox.Lang;

module TileUtils {

    function lonToTileX(lon, zoom) {
        var n = Math.pow(2, zoom);
        return ((lon + 180.0) / 360.0 * n).toNumber();
    }

    function latToTileY(lat, zoom) {
        var n = Math.pow(2, zoom);
        var latRad = lat * Math.PI / 180.0;
        var y = (1.0 - Math.ln(Math.tan(latRad) + 1.0 / Math.cos(latRad)) / Math.PI) / 2.0 * n;
        return y.toNumber();
    }

    function lonToGlobalPixelX(lon, zoom) {
        var n = Math.pow(2, zoom);
        return (lon + 180.0) / 360.0 * n * 256.0;
    }

    function latToGlobalPixelY(lat, zoom) {
        var n = Math.pow(2, zoom);
        var latRad = lat * Math.PI / 180.0;
        return (1.0 - Math.ln(Math.tan(latRad) + 1.0 / Math.cos(latRad)) / Math.PI) / 2.0 * n * 256.0;
    }

    function tileXToLon(x, zoom) {
        var n = Math.pow(2, zoom);
        return x.toDouble() / n * 360.0 - 180.0;
    }

    function tileYToLat(y, zoom) {
        var n = Math.pow(2, zoom);
        var val = Math.PI - 2.0 * Math.PI * y.toDouble() / n;
        return 180.0 / Math.PI * Math.atan(0.5 * (Math.pow(Math.E, val) - Math.pow(Math.E, -val)));
    }

    function tileKey(z, x, y) {
        return Lang.format("$1$/$2$/$3$", [z, x, y]);
    }

    function tileManhattan(x1, y1, x2, y2) {
        var dx = x1 - x2;
        var dy = y1 - y2;
        if (dx < 0) { dx = -dx; }
        if (dy < 0) { dy = -dy; }
        return dx + dy;
    }
}
