// TileUtils.mc — Conversion coordonnées GPS <-> tuiles slippy map (Web Mercator)

using Toybox.Math;
using Toybox.Lang;

module TileUtils {

    // Longitude → numéro de tuile X
    function lonToTileX(lon as Double, zoom as Number) as Number {
        var n = Math.pow(2, zoom);
        return ((lon + 180.0) / 360.0 * n).toNumber();
    }

    // Latitude → numéro de tuile Y
    function latToTileY(lat as Double, zoom as Number) as Number {
        var n = Math.pow(2, zoom);
        var latRad = lat * Math.PI / 180.0;
        var y = (1.0 - Math.ln(Math.tan(latRad) + 1.0 / Math.cos(latRad)) / Math.PI) / 2.0 * n;
        return y.toNumber();
    }

    // Position GPS → pixel X global (sur l'ensemble du plan de tuiles)
    function lonToGlobalPixelX(lon as Double, zoom as Number) as Double {
        var n = Math.pow(2, zoom);
        return (lon + 180.0) / 360.0 * n * 256.0;
    }

    // Position GPS → pixel Y global
    function latToGlobalPixelY(lat as Double, zoom as Number) as Double {
        var n = Math.pow(2, zoom);
        var latRad = lat * Math.PI / 180.0;
        return (1.0 - Math.ln(Math.tan(latRad) + 1.0 / Math.cos(latRad)) / Math.PI) / 2.0 * n * 256.0;
    }

    // Tuile X → longitude du bord gauche
    function tileXToLon(x as Number, zoom as Number) as Double {
        var n = Math.pow(2, zoom);
        return x.toDouble() / n * 360.0 - 180.0;
    }

    // Tuile Y → latitude du bord supérieur
    function tileYToLat(y as Number, zoom as Number) as Double {
        var n = Math.pow(2, zoom);
        var val = Math.PI - 2.0 * Math.PI * y.toDouble() / n;
        return 180.0 / Math.PI * Math.atan(0.5 * (Math.pow(Math.E, val) - Math.pow(Math.E, -val)));
    }

    // Clé unique pour identifier une tuile dans le cache
    function tileKey(z as Number, x as Number, y as Number) as String {
        return Lang.format("$1$/$2$/$3$", [z, x, y]);
    }

    // Distance Manhattan entre deux tuiles (pour l'éviction du cache)
    function tileManhattan(x1 as Number, y1 as Number, x2 as Number, y2 as Number) as Number {
        var dx = x1 - x2;
        var dy = y1 - y2;
        if (dx < 0) { dx = -dx; }
        if (dy < 0) { dy = -dy; }
        return dx + dy;
    }
}
