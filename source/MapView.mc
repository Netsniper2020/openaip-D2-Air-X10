using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Position;
using Toybox.Application;
using Toybox.System;
using Toybox.Lang;
using Toybox.Math;

class MapView extends WatchUi.View {

    var _tileMgr;
    var _lat = 0.0d;
    var _lon = 0.0d;
    var _hasGps = false;
    var _gpsAccuracy = 0;
    var _altitude = 0.0f;
    var _heading = 0.0f;
    var _speed = 0.0f;
    var _zoom = 10;
    var _screenW = 416;
    var _screenH = 416;
    var _tileRadius = 2;

    function initialize(tileMgr) {
        View.initialize();
        _tileMgr = tileMgr;
        var z = Application.Properties.getValue("defaultZoom");
        if (z != null && z >= 5 && z <= 15) { _zoom = z; }
    }

    function onLayout(dc) {
        _screenW = dc.getWidth();
        _screenH = dc.getHeight();
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

        if (!_hasGps) {
            drawNoGps(dc);
            return;
        }

        var cx = _screenW / 2;
        var cy = _screenH / 2;

        var centerTileX = TileUtils.lonToTileX(_lon, _zoom);
        var centerTileY = TileUtils.latToTileY(_lat, _zoom);

        var globalPx = TileUtils.lonToGlobalPixelX(_lon, _zoom);
        var globalPy = TileUtils.latToGlobalPixelY(_lat, _zoom);

        _tileMgr.requestVisibleTiles(_zoom, centerTileX, centerTileY, _tileRadius);

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

        drawPositionMarker(dc, cx, cy);
        drawHud(dc);
    }

    function drawTilePlaceholder(dc, sx, sy, tx, ty) {
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(sx, sy, 256, 256);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        var label = Lang.format("$1$/$2$", [tx, ty]);
        dc.drawText(sx + 128, sy + 128, Graphics.FONT_TINY, label,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function drawPositionMarker(dc, cx, cy) {
        var markerSize = 12;
        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        if (_gpsAccuracy >= Position.QUALITY_GOOD) {
            dc.drawCircle(cx, cy, 8);
        } else {
            dc.drawCircle(cx, cy, 16);
        }

        var hdg = _heading.toDouble();
        var sinH = Math.sin(hdg);
        var cosH = Math.cos(hdg);

        var ax = cx + (sinH * markerSize).toNumber();
        var ay = cy - (cosH * markerSize).toNumber();
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

    function drawHud(dc) {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);

        var altFt = (_altitude * 3.28084).toNumber();
        dc.drawText(10, _screenH - 60, Graphics.FONT_TINY,
                    Lang.format("$1$ ft", [altFt]), Graphics.TEXT_JUSTIFY_LEFT);

        var speedKt = (_speed * 1.94384).toNumber();
        dc.drawText(10, _screenH - 40, Graphics.FONT_TINY,
                    Lang.format("$1$ kt", [speedKt]), Graphics.TEXT_JUSTIFY_LEFT);

        var hdgDeg = (_heading * 180.0 / Math.PI).toNumber();
        if (hdgDeg < 0) { hdgDeg += 360; }
        dc.drawText(_screenW - 10, _screenH - 60, Graphics.FONT_TINY,
                    Lang.format("HDG $1$", [hdgDeg]), Graphics.TEXT_JUSTIFY_RIGHT);

        dc.drawText(_screenW - 10, _screenH - 40, Graphics.FONT_TINY,
                    Lang.format("Z$1$ [$2$]", [_zoom, _tileMgr.cacheSize()]),
                    Graphics.TEXT_JUSTIFY_RIGHT);
    }

    function drawNoGps(dc) {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.drawText(_screenW / 2, _screenH / 2, Graphics.FONT_MEDIUM,
                    "Acquisition GPS...",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function zoomIn() {
        if (_zoom < 15) { _zoom++; _tileMgr.clearCache(); WatchUi.requestUpdate(); }
    }

    function zoomOut() {
        if (_zoom > 5) { _zoom--; _tileMgr.clearCache(); WatchUi.requestUpdate(); }
    }

    function getZoom() { return _zoom; }
}
