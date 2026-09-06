pragma ComponentBehavior: Bound

import QtQuick

// Layout listing/switching went entirely through `hyprctl` (config option
// query, device listing, `switchxkblayout`) - no generic protocol reports
// or controls XKB layouts, consistent with the caps-lock/num-lock/layout
// stubs elsewhere (see services/Hypr.qml). Stubbed to always-empty rather
// than removing the popout outright: KbLayout.qml already hides its list
// and active-layout row when there's nothing to show.
Item {
    id: model

    property alias visibleModel: visibleModel
    property string activeLabel: ""
    property int activeIndex: -1

    function start() {}

    function refresh() {}

    function switchTo(idx) {}

    visible: false

    ListModel {
        id: visibleModel
    }
}
