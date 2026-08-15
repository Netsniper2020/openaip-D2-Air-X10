// TileManager.mc — Gestion du téléchargement, cache et éviction des tuiles

using Toybox.Communications;
using Toybox.Application;
using Toybox.Lang;
using Toybox.WatchUi;

class TileManager {

    // Cache : clé "z/x/y" → BitmapReference
    var _cache as Dictionary = {};
    // File d'attente de téléchargement : Array de {:z, :x, :y}
    var _queue as Array = [];
    // Téléchargement en cours ?
    var _downloading as Boolean = false;
    // Clé de la tuile en cours de téléchargement
    var _currentKey as String = "";

    // Taille max du buffer (paramétrable)
    var _maxBufferSize as Number = 16;
    // URL template
    var _urlTemplate as String = "";
    // Clé API
    var _apiKey as String = "";

    // Centre courant (pour l'éviction par distance)
    var _centerTileX as Number = 0;
    var _centerTileY as Number = 0;

    function initialize() {
        loadSettings();
    }

    // Recharger les paramètres depuis les Properties
    function loadSettings() as Void {
        _maxBufferSize = Application.Properties.getValue("tileBufferSize") as Number;
        if (_maxBufferSize == null || _maxBufferSize < 4) {
            _maxBufferSize = 16;
        }
        _urlTemplate = Application.Properties.getValue("tileUrlTemplate") as String;
        if (_urlTemplate == null || _urlTemplate.length() == 0) {
            _urlTemplate = "https://api.tiles.openaip.net/api/data/openaip/{z}/{x}/{y}.png?apiKey={k}";
        }
        _apiKey = Application.Properties.getValue("apiKey") as String;
        if (_apiKey == null) {
            _apiKey = "";
        }
    }

    // Mettre à jour le centre de référence (position GPS courante)
    function setCenterTile(tx as Number, ty as Number) as Void {
        _centerTileX = tx;
        _centerTileY = ty;
    }

    // Récupérer une tuile du cache (ou null si absente)
    function getTile(z as Number, x as Number, y as Number) {
        var key = TileUtils.tileKey(z, x, y);
        if (_cache.hasKey(key)) {
            return _cache[key];
        }
        return null;
    }

    // Vérifier si une tuile est dans le cache
    function hasTile(z as Number, x as Number, y as Number) as Boolean {
        return _cache.hasKey(TileUtils.tileKey(z, x, y));
    }

    // Demander le téléchargement d'une tuile (ajoute à la queue si pas en cache)
    function requestTile(z as Number, x as Number, y as Number) as Void {
        var key = TileUtils.tileKey(z, x, y);

        // Déjà en cache
        if (_cache.hasKey(key)) {
            return;
        }

        // Déjà dans la queue
        for (var i = 0; i < _queue.size(); i++) {
            var item = _queue[i] as Dictionary;
            if (item[:z] == z && item[:x] == x && item[:y] == y) {
                return;
            }
        }

        // En cours de téléchargement
        if (_downloading && _currentKey.equals(key)) {
            return;
        }

        _queue.add({:z => z, :x => x, :y => y});
        processQueue();
    }

    // Demander toutes les tuiles visibles autour d'un centre
    function requestVisibleTiles(z as Number, centerX as Number, centerY as Number, radius as Number) as Void {
        setCenterTile(centerX, centerY);
        for (var dx = -radius; dx <= radius; dx++) {
            for (var dy = -radius; dy <= radius; dy++) {
                requestTile(z, centerX + dx, centerY + dy);
            }
        }
    }

    // Traiter la file de téléchargement
    function processQueue() as Void {
        if (_downloading || _queue.size() == 0) {
            return;
        }

        // Prioriser les tuiles les plus proches du centre
        var bestIdx = 0;
        var bestDist = 999;
        for (var i = 0; i < _queue.size(); i++) {
            var item = _queue[i] as Dictionary;
            var dist = TileUtils.tileManhattan(
                item[:x] as Number, item[:y] as Number,
                _centerTileX, _centerTileY
            );
            if (dist < bestDist) {
                bestDist = dist;
                bestIdx = i;
            }
        }

        var tile = _queue[bestIdx] as Dictionary;
        _queue.remove(_queue[bestIdx]);

        var z = tile[:z] as Number;
        var x = tile[:x] as Number;
        var y = tile[:y] as Number;
        _currentKey = TileUtils.tileKey(z, x, y);
        _downloading = true;

        var url = buildTileUrl(z, x, y);

        var options = {
            :maxWidth => 256,
            :maxHeight => 256
        };

        Communications.makeImageRequest(url, null, options, method(:onTileReceived));
    }

    // Construire l'URL d'une tuile à partir du template
    function buildTileUrl(z as Number, x as Number, y as Number) as String {
        var url = _urlTemplate;
        // Substitution manuelle des placeholders
        url = stringReplace(url, "{z}", z.toString());
        url = stringReplace(url, "{x}", x.toString());
        url = stringReplace(url, "{y}", y.toString());
        url = stringReplace(url, "{k}", _apiKey);
        return url;
    }

    // Remplacement de chaîne simple (Monkey C n'a pas de replace natif)
    function stringReplace(src as String, search as String, replace as String) as String {
        var idx = src.find(search);
        if (idx == null) {
            return src;
        }
        var before = "";
        if (idx > 0) {
            before = src.substring(0, idx);
        }
        var after = src.substring(idx + search.length(), src.length());
        return before + replace + after;
    }

    // Callback de réception d'une tuile
    function onTileReceived(responseCode as Number, data) as Void {
        _downloading = false;

        if (responseCode == 200 && data != null) {
            // Éviction si le cache est plein
            evictIfNeeded();
            _cache[_currentKey] = data;
        }
        // else : tuile non disponible, on ignore silencieusement

        _currentKey = "";

        // Rafraîchir l'affichage
        WatchUi.requestUpdate();

        // Continuer la queue
        processQueue();
    }

    // Éviction LRU par distance : supprimer la tuile la plus éloignée du centre
    function evictIfNeeded() as Void {
        while (_cache.size() >= _maxBufferSize) {
            var keys = _cache.keys();
            var worstKey = null;
            var worstDist = -1;

            for (var i = 0; i < keys.size(); i++) {
                var key = keys[i] as String;
                var parts = parseTileKey(key);
                if (parts != null) {
                    var dist = TileUtils.tileManhattan(
                        parts[1], parts[2],
                        _centerTileX, _centerTileY
                    );
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

    // Parser une clé "z/x/y" → [z, x, y] ou null
    function parseTileKey(key as String) as Array? {
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

    // Vider tout le cache (changement de zoom par ex.)
    function clearCache() as Void {
        _cache = {};
        _queue = [];
    }

    // Nombre de tuiles en cache
    function cacheSize() as Number {
        return _cache.size();
    }
}
