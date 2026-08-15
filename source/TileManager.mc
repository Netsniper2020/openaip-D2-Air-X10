using Toybox.Communications;
using Toybox.Application;
using Toybox.Lang;
using Toybox.WatchUi;
using Toybox.Graphics;

class TileManager {

    var _cache = {};
    var _queue = [];
    var _downloading = false;
    var _currentKey = "";
    var _maxBufferSize = 16;
    var _urlTemplate = "";
    var _apiKey = "";
    var _centerTileX = 0;
    var _centerTileY = 0;

    function initialize() {
        loadSettings();
    }

    function loadSettings() {
        var buf = Application.Properties.getValue("tileBufferSize");
        _maxBufferSize = (buf != null && buf >= 4) ? buf : 16;
        var url = Application.Properties.getValue("tileUrlTemplate");
        _urlTemplate = (url != null && url.length() > 0) ? url : "https://api.tiles.openaip.net/api/data/openaip/{z}/{x}/{y}.png?apiKey={k}";
        var key = Application.Properties.getValue("apiKey");
        _apiKey = (key != null) ? key : "";
    }

    function setCenterTile(tx, ty) {
        _centerTileX = tx;
        _centerTileY = ty;
    }

    function getTile(z, x, y) {
        var key = TileUtils.tileKey(z, x, y);
        if (_cache.hasKey(key)) {
            return _cache[key];
        }
        return null;
    }

    function hasTile(z, x, y) {
        return _cache.hasKey(TileUtils.tileKey(z, x, y));
    }

    function requestTile(z, x, y) {
        var key = TileUtils.tileKey(z, x, y);
        if (_cache.hasKey(key)) { return; }

        for (var i = 0; i < _queue.size(); i++) {
            var item = _queue[i];
            if (item[:z] == z && item[:x] == x && item[:y] == y) { return; }
        }

        if (_downloading && _currentKey.equals(key)) { return; }

        _queue.add({:z => z, :x => x, :y => y});
        processQueue();
    }

    function requestVisibleTiles(z, centerX, centerY, radius) {
        setCenterTile(centerX, centerY);
        for (var dx = -radius; dx <= radius; dx++) {
            for (var dy = -radius; dy <= radius; dy++) {
                requestTile(z, centerX + dx, centerY + dy);
            }
        }
    }

    function processQueue() {
        if (_downloading || _queue.size() == 0) { return; }

        var bestIdx = 0;
        var bestDist = 999;
        for (var i = 0; i < _queue.size(); i++) {
            var item = _queue[i];
            var dist = TileUtils.tileManhattan(item[:x], item[:y], _centerTileX, _centerTileY);
            if (dist < bestDist) {
                bestDist = dist;
                bestIdx = i;
            }
        }

        var tile = _queue[bestIdx];
        _queue.remove(tile);

        var z = tile[:z];
        var x = tile[:x];
        var y = tile[:y];
        _currentKey = TileUtils.tileKey(z, x, y);
        _downloading = true;

        var url = buildTileUrl(z, x, y);
        var options = { :maxWidth => 256, :maxHeight => 256 };

        Communications.makeImageRequest(url, null, options, method(:onTileReceived));
    }

    function buildTileUrl(z, x, y) {
        var url = _urlTemplate;
        url = stringReplace(url, "{z}", z.toString());
        url = stringReplace(url, "{x}", x.toString());
        url = stringReplace(url, "{y}", y.toString());
        url = stringReplace(url, "{k}", _apiKey);
        return url;
    }

    function stringReplace(src, search, replace) {
        var idx = src.find(search);
        if (idx == null) { return src; }
        var before = (idx > 0) ? src.substring(0, idx) : "";
        var after = src.substring(idx + search.length(), src.length());
        return before + replace + after;
    }

    function onTileReceived(responseCode as Lang.Number, data as Graphics.BitmapReference or WatchUi.BitmapResource or Null) as Void {
        _downloading = false;
        if (responseCode == 200 && data != null) {
            evictIfNeeded();
            _cache[_currentKey] = data;
        }
        _currentKey = "";
        WatchUi.requestUpdate();
        processQueue();
    }

    function evictIfNeeded() {
        while (_cache.size() >= _maxBufferSize) {
            var keys = _cache.keys();
            var worstKey = null;
            var worstDist = -1;
            for (var i = 0; i < keys.size(); i++) {
                var key = keys[i];
                var parts = parseTileKey(key);
                if (parts != null) {
                    var dist = TileUtils.tileManhattan(parts[1], parts[2], _centerTileX, _centerTileY);
                    if (dist > worstDist) {
                        worstDist = dist;
                        worstKey = key;
                    }
                }
            }
            if (worstKey != null) {
                _cache.remove(worstKey);
            } else {
                break;
            }
        }
    }

    function parseTileKey(key) {
        var slash1 = key.find("/");
        if (slash1 == null) { return null; }
        var rest = key.substring(slash1 + 1, key.length());
        var slash2 = rest.find("/");
        if (slash2 == null) { return null; }
        var zStr = key.substring(0, slash1);
        var xStr = rest.substring(0, slash2);
        var yStr = rest.substring(slash2 + 1, rest.length());
        return [zStr.toNumber(), xStr.toNumber(), yStr.toNumber()];
    }

    function clearCache() {
        _cache = {};
        _queue = [];
    }

    function cacheSize() {
        return _cache.size();
    }
}
