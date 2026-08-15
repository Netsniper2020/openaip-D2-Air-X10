using Toybox.Application;
using Toybox.WatchUi;
using Toybox.Position;
using Toybox.System;

class OpenAipApp extends Application.AppBase {

    var _tileMgr;
    var _mapView;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
        _tileMgr = new TileManager();
        Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
    }

    function getInitialView() {
        _mapView = new MapView(_tileMgr);
        var delegate = new MapDelegate(_mapView);
        return [_mapView, delegate];
    }

    function onPosition(info) {
        if (_mapView != null) {
            _mapView.updatePosition(info);
            WatchUi.requestUpdate();
        }
    }

    function onStop(state) {
        Position.enableLocationEvents(Position.LOCATION_DISABLE, method(:onPosition));
    }

    function onSettingsChanged() {
        if (_tileMgr != null) {
            _tileMgr.loadSettings();
            _tileMgr.clearCache();
            WatchUi.requestUpdate();
        }
    }
}
