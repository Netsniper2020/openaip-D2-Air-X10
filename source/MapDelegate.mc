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
        var y = coords[1];
        var screenH = System.getDeviceSettings().screenHeight;
        if (y < screenH / 3) {
            _view.zoomIn();
        } else if (y > screenH * 2 / 3) {
            _view.zoomOut();
        }
        return true;
    }
}
