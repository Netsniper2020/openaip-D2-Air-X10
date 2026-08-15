using Toybox.WatchUi;
using Toybox.System;

class MapDelegate extends WatchUi.BehaviorDelegate {

    var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onNextPage() {
        _view.zoomIn();
        return true;
    }

    function onPreviousPage() {
        _view.zoomOut();
        return true;
    }

    function onBack() {
        System.exit();
        return true;
    }

    function onTap(evt) {
        var coords = evt.getCoordinates();
        // D'abord tester les boutons zoom
        if (_view.handleTap(coords[0], coords[1])) {
            return true;
        }
        return true;
    }
}
