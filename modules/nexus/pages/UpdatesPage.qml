import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Updates")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: qsTr("System flake")
        }

        TextFieldRow {
            first: true
            label: qsTr("Config directory")
            subtext: qsTr("Flake directory, e.g. /etc/nixos (empty = NIX_BACKEND_CONFIG_DIR, then /etc/nixos)")
            placeholderText: "/etc/nixos"
            value: GlobalConfig.nixBackend.systemConfigDir
            showReset: value !== ""
            onEditingFinished: v => GlobalConfig.nixBackend.systemConfigDir = v
            onResetRequested: {
                GlobalConfig.nixBackend.systemConfigDir = "";
                clear();
            }
        }

        TextFieldRow {
            last: true
            label: qsTr("Host name")
            subtext: qsTr("nixosConfigurations.<name> (empty = NIX_BACKEND_HOST_NAME, then the machine's hostname)")
            placeholderText: qsTr("machine hostname")
            value: GlobalConfig.nixBackend.systemHostName
            showReset: value !== ""
            onEditingFinished: v => GlobalConfig.nixBackend.systemHostName = v
            onResetRequested: {
                GlobalConfig.nixBackend.systemHostName = "";
                clear();
            }
        }

        SectionHeader {
            text: qsTr("About")
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.largeIncreased
            Layout.rightMargin: Tokens.padding.largeIncreased
            Layout.bottomMargin: Tokens.padding.medium
            wrapMode: Text.WordWrap
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.small
            text: qsTr("Flake updates and rebuilds run from the dashboard's Nix tab. Registering a system generation and activating it each prompt for authorization separately; nix-backend-generic itself never runs as root.")
        }
    }
}
