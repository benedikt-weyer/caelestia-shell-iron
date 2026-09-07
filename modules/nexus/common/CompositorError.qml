import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

// A small error banner shown at the top of every Compositor/Displays page
// when `ironlandctl` last failed - most commonly because it isn't
// installed or isn't on PATH. Silently invisible otherwise.
ConnectedRect {
    id: root

    Layout.fillWidth: true
    Layout.bottomMargin: visible ? Tokens.spacing.medium : 0
    first: true
    last: true
    visible: !IronlandCtl.available
    implicitHeight: visible ? layout.implicitHeight + layout.anchors.margins * 2 : 0
    color: Colours.palette.m3errorContainer

    RowLayout {
        id: layout

        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.medium

        MaterialIcon {
            text: "error"
            color: Colours.palette.m3onErrorContainer
            fontStyle: Tokens.font.icon.medium
        }

        StyledText {
            Layout.fillWidth: true
            text: qsTr("Couldn't reach ironlandctl: %1").arg(IronlandCtl.lastError)
            color: Colours.palette.m3onErrorContainer
            font: Tokens.font.body.small
            wrapMode: Text.WordWrap
        }
    }
}
