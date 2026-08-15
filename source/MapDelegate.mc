// MapDelegate.mc — Gestion des entrées utilisateur (boutons + tactile)
//
// D2 Air X10 : écran tactile + 2 boutons physiques
// - Bouton haut / swipe haut : zoom in
// - Bouton bas / swipe bas  : zoom out
// - Appui long / back       : quitter

using Toybox.WatchUi;
using Toybox.System;

class MapDelegate extends WatchUi.BehaviorDelegate {

    var _view as MapView;

    function initialize(view as MapView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    // Bouton physique haut → zoom in
    function onNextPage() as Boolean {
        _view.zoomIn();
        return true;
    }

    // Bouton physique bas → zoom out
    function onPreviousPage() as Boolean {
        _view.zoomOut();
        return true;
    }

    // Bouton back → quitter l'application
    function onBack() as Boolean {
        System.exit();
        return true;
    }

    // Tap écran → zoom in (zone haute) / zoom out (zone basse)
    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        var coords = evt.getCoordinates();
        var y = coords[1];
        var screenH = System.getDeviceSettings().screenHeight;

        if (y < screenH / 3) {
            _view.zoomIn();
        } else if (y > screenH * 2 / 3) {
            _view.zoomOut();
        }
        // Tap au centre : pas d'action (réservé pour évolution future)
        return true;
    }
}
