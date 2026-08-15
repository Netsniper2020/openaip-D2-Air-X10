// OpenAipApp.mc — Point d'entrée de l'application OpenAIP Map
//
// Architecture :
//   OpenAipApp → crée MapView + TileManager
//                active le GPS continu
//                route les events Position vers MapView

using Toybox.Application;
using Toybox.WatchUi;
using Toybox.Position;
using Toybox.System;

class OpenAipApp extends Application.AppBase {

    var _tileMgr as TileManager?;
    var _mapView as MapView?;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
        // Initialiser le gestionnaire de tuiles
        _tileMgr = new TileManager();

        // Activer le GPS en continu
        Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
    }

    function getInitialView() as Array {
        _mapView = new MapView(_tileMgr);
        var delegate = new MapDelegate(_mapView);
        return [_mapView, delegate] as Array;
    }

    // Callback GPS — route vers la vue
    function onPosition(info as Position.Info) as Void {
        if (_mapView != null) {
            _mapView.updatePosition(info);
            WatchUi.requestUpdate();
        }
    }

    function onStop(state as Dictionary?) as Void {
        // Désactiver le GPS
        Position.enableLocationEvents(Position.LOCATION_DISABLE, method(:onPosition));
    }

    // Rechargement des settings depuis Garmin Connect Mobile
    function onSettingsChanged() as Void {
        if (_tileMgr != null) {
            _tileMgr.loadSettings();
            _tileMgr.clearCache();
            WatchUi.requestUpdate();
        }
    }
}
