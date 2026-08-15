// MapView.mc — Vue principale : rendu des tuiles, position GPS, overlay HUD

using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Position;
using Toybox.Application;
using Toybox.System;
using Toybox.Lang;

class MapView extends WatchUi.View {

    // Gestionnaire de tuiles
    var _tileMgr as TileManager;

    // Position GPS courante
    var _lat as Double = 0.0;
    var _lon as Double = 0.0;
    var _hasGps as Boolean = false;
    var _gpsAccuracy as Number = 0;
    var _altitude as Float = 0.0f;
    var _heading as Float = 0.0f;
    var _speed as Float = 0.0f; // m/s

    // Zoom courant
    var _zoom as Number = 10;

    // Dimensions écran
    var _screenW as Number = 416;
    var _screenH as Number = 416;

    // Rayon de tuiles à charger autour du centre (1 = 3x3, 2 = 5x5)
    var _tileRadius as Number = 2;

    function initialize(tileMgr as TileManager) {
        View.initialize();
        _tileMgr = tileMgr;
        _zoom = Application.Properties.getValue("defaultZoom") as Number;
        if (_zoom == null || _zoom < 5 || _zoom > 15) {
            _zoom = 10;
        }
    }

    function onLayout(dc as Graphics.Dc) as Void {
        _screenW = dc.getWidth();
        _screenH = dc.getHeight();
    }

    // Appelé par le callback GPS (depuis l'App)
    function updatePosition(info as Position.Info) as Void {
        if (info.position != null) {
            var coords = info.position.toDegrees();
            _lat = coords[0] as Double;
            _lon = coords[1] as Double;
            _hasGps = true;
        }
        if (info.accuracy != null) {
            _gpsAccuracy = info.accuracy as Number;
        }
        if (info.altitude != null) {
            _altitude = info.altitude as Float;
        }
        if (info.heading != null) {
            _heading = info.heading as Float; // radians
        }
        if (info.speed != null) {
            _speed = info.speed as Float; // m/s
        }
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        // Fond noir
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        if (!_hasGps) {
            drawNoGps(dc);
            return;
        }

        // Centre de l'écran
        var cx = _screenW / 2;
        var cy = _screenH / 2;

        // Tuile contenant la position GPS
        var centerTileX = TileUtils.lonToTileX(_lon, _zoom);
        var centerTileY = TileUtils.latToTileY(_lat, _zoom);

        // Position en pixels globaux
        var globalPx = TileUtils.lonToGlobalPixelX(_lon, _zoom);
        var globalPy = TileUtils.latToGlobalPixelY(_lat, _zoom);

        // Demander les tuiles visibles
        _tileMgr.requestVisibleTiles(_zoom, centerTileX, centerTileY, _tileRadius);

        // Dessiner les tuiles
        for (var dx = -_tileRadius; dx <= _tileRadius; dx++) {
            for (var dy = -_tileRadius; dy <= _tileRadius; dy++) {
                var tx = centerTileX + dx;
                var ty = centerTileY + dy;

                var bitmap = _tileMgr.getTile(_zoom, tx, ty);

                // Position écran de cette tuile
                var tileOriginPx = tx * 256.0;
                var tileOriginPy = ty * 256.0;
                var screenX = (tileOriginPx - globalPx + cx).toNumber();
                var screenY = (tileOriginPy - globalPy + cy).toNumber();

                if (bitmap != null) {
                    dc.drawBitmap(screenX, screenY, bitmap);
                } else {
                    // Placeholder : rectangle gris avec grille
                    drawTilePlaceholder(dc, screenX, screenY, tx, ty);
                }
            }
        }

        // Marqueur position GPS (toujours au centre)
        drawPositionMarker(dc, cx, cy);

        // HUD : altitude, vitesse, zoom, buffer
        drawHud(dc);
    }

    // Placeholder pour les tuiles en cours de chargement
    function drawTilePlaceholder(dc as Graphics.Dc, sx as Number, sy as Number,
                                  tx as Number, ty as Number) as Void {
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(sx, sy, 256, 256);

        // Afficher les coordonnées de la tuile
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        var label = Lang.format("$1$/$2$", [tx, ty]);
        dc.drawText(sx + 128, sy + 128, Graphics.FONT_TINY, label,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Marqueur de position : triangle orienté selon le cap
    function drawPositionMarker(dc as Graphics.Dc, cx as Number, cy as Number) as Void {
        var markerSize = 12;

        // Cercle de précision (bleu translucide)
        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        if (_gpsAccuracy >= Position.QUALITY_GOOD) {
            dc.drawCircle(cx, cy, 8);
        } else {
            dc.drawCircle(cx, cy, 16);
        }

        // Triangle orienté (direction du cap)
        var hdg = _heading; // radians, 0 = nord
        var sinH = Math.sin(hdg);
        var cosH = Math.cos(hdg);

        // Pointe avant
        var ax = cx + (sinH * markerSize).toNumber();
        var ay = cy - (cosH * markerSize).toNumber();
        // Arrière gauche
        var bx = cx + (Math.sin(hdg - 2.5) * markerSize * 0.6).toNumber();
        var by = cy - (Math.cos(hdg - 2.5) * markerSize * 0.6).toNumber();
        // Arrière droit
        var ex = cx + (Math.sin(hdg + 2.5) * markerSize * 0.6).toNumber();
        var ey = cy - (Math.cos(hdg + 2.5) * markerSize * 0.6).toNumber();

        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[ax, ay], [bx, by], [ex, ey]]);

        // Contour blanc
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(ax, ay, bx, by);
        dc.drawLine(bx, by, ex, ey);
        dc.drawLine(ex, ey, ax, ay);
    }

    // HUD overlay : données de vol
    function drawHud(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);

        // Altitude (en ft)
        var altFt = (_altitude * 3.28084).toNumber();
        var altStr = Lang.format("$1$ ft", [altFt]);
        dc.drawText(10, _screenH - 60, Graphics.FONT_TINY, altStr,
                    Graphics.TEXT_JUSTIFY_LEFT);

        // Vitesse (en kt)
        var speedKt = (_speed * 1.94384).toNumber();
        var spdStr = Lang.format("$1$ kt", [speedKt]);
        dc.drawText(10, _screenH - 40, Graphics.FONT_TINY, spdStr,
                    Graphics.TEXT_JUSTIFY_LEFT);

        // Cap magnétique (approximation, sans déclinaison)
        var hdgDeg = (_heading * 180.0 / Math.PI).toNumber();
        if (hdgDeg < 0) { hdgDeg += 360; }
        var hdgStr = Lang.format("HDG $1$°", [hdgDeg]);
        dc.drawText(_screenW - 10, _screenH - 60, Graphics.FONT_TINY, hdgStr,
                    Graphics.TEXT_JUSTIFY_RIGHT);

        // Zoom et buffer
        var bufStr = Lang.format("Z$1$ [$2$]", [_zoom, _tileMgr.cacheSize()]);
        dc.drawText(_screenW - 10, _screenH - 40, Graphics.FONT_TINY, bufStr,
                    Graphics.TEXT_JUSTIFY_RIGHT);
    }

    // Écran d'attente GPS
    function drawNoGps(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.drawText(_screenW / 2, _screenH / 2, Graphics.FONT_MEDIUM,
                    Application.loadResource(Rez.Strings.NoGps) as String,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Accesseurs zoom
    function zoomIn() as Void {
        if (_zoom < 15) {
            _zoom++;
            _tileMgr.clearCache();
            WatchUi.requestUpdate();
        }
    }

    function zoomOut() as Void {
        if (_zoom > 5) {
            _zoom--;
            _tileMgr.clearCache();
            WatchUi.requestUpdate();
        }
    }

    function getZoom() as Number {
        return _zoom;
    }
}
