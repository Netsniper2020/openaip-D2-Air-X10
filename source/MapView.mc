using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Position;
using Toybox.Application;
using Toybox.System;
using Toybox.Lang;
using Toybox.Math;

class MapView extends WatchUi.View {

    var _tileMgr;

    // Position courante — défaut = LFPH (Chelles-Le Pin)
    var _lat = 48.8783d;
    var _lon = 2.6067d;
    var _hasGps = false;
    var _gpsAccuracy = 0;
    var _altitude = 0.0f;
    var _heading = 0.0f;
    var _speed = 0.0f;

    var _zoom = 10;
    var _screenW = 416;
    var _screenH = 416;
    var _tileRadius = 2;

    // Zones des boutons zoom (pour hit-test tactile)
    // Positionnés pour écran rond, à droite
    var _btnPlusX = 0;
    var _btnPlusY = 0;
    var _btnMinusX = 0;
    var _btnMinusY = 0;
    var _btnSize = 36;

    function initialize(tileMgr) {
        View.initialize();
        _tileMgr = tileMgr;
        var z = Application.Properties.getValue("defaultZoom");
        if (z != null && z >= 5 && z <= 15) { _zoom = z; }
    }

    function onLayout(dc) {
        _screenW = dc.getWidth();
        _screenH = dc.getHeight();
        var cx = _screenW / 2;
        var cy = _screenH / 2;
        var r = cx - 20; // rayon utilisable (marge écran rond)
        // Boutons à droite, décalés de 45° depuis le centre
        _btnPlusX = cx + (r * 0.7).toNumber();
        _btnPlusY = cy - (r * 0.5).toNumber();
        _btnMinusX = cx + (r * 0.7).toNumber();
        _btnMinusY = cy + (r * 0.5).toNumber();
    }

    function updatePosition(info) {
        if (info.position != null) {
            var coords = info.position.toDegrees();
            _lat = coords[0].toDouble();
            _lon = coords[1].toDouble();
            _hasGps = true;
        }
        if (info.accuracy != null) { _gpsAccuracy = info.accuracy; }
        if (info.altitude != null) { _altitude = info.altitude.toFloat(); }
        if (info.heading != null) { _heading = info.heading.toFloat(); }
        if (info.speed != null) { _speed = info.speed.toFloat(); }
    }

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var cx = _screenW / 2;
        var cy = _screenH / 2;

        var centerTileX = TileUtils.lonToTileX(_lon, _zoom);
        var centerTileY = TileUtils.latToTileY(_lat, _zoom);

        var globalPx = TileUtils.lonToGlobalPixelX(_lon, _zoom);
        var globalPy = TileUtils.latToGlobalPixelY(_lat, _zoom);

        // Charger les tuiles du zoom courant
        _tileMgr.requestVisibleTiles(_zoom, centerTileX, centerTileY, _tileRadius);

        // Pré-charger zoom+1 et zoom-1 (centre uniquement, rayon 1)
        if (_zoom < 15) {
            var zUp = _zoom + 1;
            var txUp = TileUtils.lonToTileX(_lon, zUp);
            var tyUp = TileUtils.latToTileY(_lat, zUp);
            _tileMgr.requestVisibleTiles(zUp, txUp, tyUp, 1);
        }
        if (_zoom > 5) {
            var zDown = _zoom - 1;
            var txDown = TileUtils.lonToTileX(_lon, zDown);
            var tyDown = TileUtils.latToTileY(_lat, zDown);
            _tileMgr.requestVisibleTiles(zDown, txDown, tyDown, 1);
        }

        // Dessiner les tuiles
        for (var dx = -_tileRadius; dx <= _tileRadius; dx++) {
            for (var dy = -_tileRadius; dy <= _tileRadius; dy++) {
                var tx = centerTileX + dx;
                var ty = centerTileY + dy;

                var bitmap = _tileMgr.getTile(_zoom, tx, ty);

                var tileOriginPx = tx * 256.0;
                var tileOriginPy = ty * 256.0;
                var screenX = (tileOriginPx - globalPx + cx).toNumber();
                var screenY = (tileOriginPy - globalPy + cy).toNumber();

                if (bitmap != null) {
                    dc.drawBitmap(screenX, screenY, bitmap);
                } else {
                    drawTilePlaceholder(dc, screenX, screenY, tx, ty);
                }
            }
        }

        // Marqueur de position
        drawPositionMarker(dc, cx, cy);

        // HUD adapté écran rond
        drawHud(dc, cx, cy);

        // Boutons zoom
        drawZoomButtons(dc);
    }

    function drawTilePlaceholder(dc, sx, sy, tx, ty) {
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(sx, sy, 256, 256);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(sx + 128, sy + 128, Graphics.FONT_TINY,
                    Lang.format("$1$/$2$", [tx, ty]),
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function drawPositionMarker(dc, cx, cy) {
        var markerSize = 12;

        // Cercle de précision
        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        var circleR = (_gpsAccuracy >= Position.QUALITY_GOOD) ? 8 : 16;
        dc.drawCircle(cx, cy, circleR);

        if (!_hasGps) {
            // Pas de fix GPS : croix au centre
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(cx - 8, cy, cx + 8, cy);
            dc.drawLine(cx, cy - 8, cx, cy + 8);
            return;
        }

        // Triangle orienté (cap)
        var hdg = _heading.toDouble();
        var ax = cx + (Math.sin(hdg) * markerSize).toNumber();
        var ay = cy - (Math.cos(hdg) * markerSize).toNumber();
        var bx = cx + (Math.sin(hdg - 2.5) * markerSize * 0.6).toNumber();
        var by = cy - (Math.cos(hdg - 2.5) * markerSize * 0.6).toNumber();
        var ex = cx + (Math.sin(hdg + 2.5) * markerSize * 0.6).toNumber();
        var ey = cy - (Math.cos(hdg + 2.5) * markerSize * 0.6).toNumber();

        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[ax, ay], [bx, by], [ex, ey]]);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(ax, ay, bx, by);
        dc.drawLine(bx, by, ex, ey);
        dc.drawLine(ex, ey, ax, ay);
    }

    // HUD placé pour écran rond : texte le long du cercle intérieur
    function drawHud(dc, cx, cy) {
        var r = cx - 8;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);

        // Haut centre : cap
        var hdgDeg = (_heading * 180.0 / Math.PI).toNumber();
        if (hdgDeg < 0) { hdgDeg += 360; }
        dc.drawText(cx, 12, Graphics.FONT_TINY,
                    Lang.format("$1$°", [hdgDeg]),
                    Graphics.TEXT_JUSTIFY_CENTER);

        // Bas centre : altitude et vitesse
        var altFt = (_altitude * 3.28084).toNumber();
        var speedKt = (_speed * 1.94384).toNumber();
        dc.drawText(cx, _screenH - 38, Graphics.FONT_TINY,
                    Lang.format("$1$ft  $2$kt", [altFt, speedKt]),
                    Graphics.TEXT_JUSTIFY_CENTER);

        // Bas centre ligne 2 : zoom et cache
        dc.drawText(cx, _screenH - 22, Graphics.FONT_XTINY,
                    Lang.format("Z$1$ [$2$]", [_zoom, _tileMgr.cacheSize()]),
                    Graphics.TEXT_JUSTIFY_CENTER);

        // Indicateur GPS en haut
        if (!_hasGps) {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, 30, Graphics.FONT_XTINY, "NO GPS",
                        Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // Boutons zoom visuels
    function drawZoomButtons(dc) {
        var s = _btnSize;
        var half = s / 2;

        // Bouton +
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_btnPlusX, _btnPlusY, half);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(_btnPlusX, _btnPlusY, half);
        dc.drawText(_btnPlusX, _btnPlusY, Graphics.FONT_MEDIUM, "+",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Bouton -
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_btnMinusX, _btnMinusY, half);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(_btnMinusX, _btnMinusY, half);
        dc.drawText(_btnMinusX, _btnMinusY, Graphics.FONT_MEDIUM, "-",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Test si un tap touche un bouton zoom
    function handleTap(x, y) {
        var half = _btnSize / 2 + 8; // marge tactile
        var dxP = x - _btnPlusX;
        var dyP = y - _btnPlusY;
        if (dxP * dxP + dyP * dyP <= half * half) {
            zoomIn();
            return true;
        }
        var dxM = x - _btnMinusX;
        var dyM = y - _btnMinusY;
        if (dxM * dxM + dyM * dyM <= half * half) {
            zoomOut();
            return true;
        }
        return false;
    }

    function zoomIn() {
        if (_zoom < 15) { _zoom++; WatchUi.requestUpdate(); }
    }

    function zoomOut() {
        if (_zoom > 5) { _zoom--; WatchUi.requestUpdate(); }
    }

    function getZoom() { return _zoom; }
}
