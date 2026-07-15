import QtQuick
import Quickshell
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginComponent {
    id: root

    readonly property int pollIntervalSeconds: Math.max(1, (pluginData && pluginData.pollIntervalSeconds) || 15)
    readonly property bool pollingEnabled: !pluginData || pluginData.pollingEnabled !== false
    readonly property bool abbreviateModeNames: pluginData ? pluginData.abbreviateModeNames === true : false
    readonly property var modes: CardwireService.modes
    readonly property string activeModeName: CardwireService.activeModeName

    function selectMode(mode) {
        if (mode.name === root.activeModeName || CardwireService.applying)
            return ;

        CardwireService.setMode(mode.name, (success) => {
            if (success)
                postClickRefresh.restart();

        });
    }

    function cycleMode() {
        const mode = CardwireService.nextMode();
        if (mode)
            root.selectMode(mode);

    }

    function currentModeLabel() {
        return CardwireService.modeLabel(root.activeModeName);
    }

    function barModeText() {
        if (root.abbreviateModeNames)
            return root.activeModeName.length > 0 ? root.activeModeName.charAt(0).toUpperCase() : "NM";

        return root.currentModeLabel();
    }

    layerNamespacePlugin: "cardwireManager"
    pillRightClickAction: function() {
        root.cycleMode();
    }
    popoutWidth: 420
    popoutHeight: Math.max(236, Math.min(476, 172 + root.modes.length * 64))
    Component.onCompleted: CardwireService.refreshModeState()

    Timer {
        interval: root.pollIntervalSeconds * 1000
        running: root.pollingEnabled
        repeat: true
        triggeredOnStart: false
        onTriggered: CardwireService.refreshModeState()
    }

    Timer {
        id: postClickRefresh

        interval: 400
        repeat: false
        onTriggered: CardwireService.refreshModeState()
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS
            anchors.verticalCenter: parent.verticalCenter

            DankIcon {
                name: CardwireService.lastError.length > 0 ? "warning" : "memory"
                color: CardwireService.lastError.length > 0 ? Theme.error : Theme.surfaceText
                size: Theme.iconSize - 6
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: root.barModeText()
                color: CardwireService.lastError.length > 0 ? Theme.error : Theme.surfaceText
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
                maximumLineCount: 1
                anchors.verticalCenter: parent.verticalCenter
            }

        }

    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXS

            DankIcon {
                name: CardwireService.lastError.length > 0 ? "warning" : "memory"
                color: CardwireService.lastError.length > 0 ? Theme.error : Theme.surfaceText
                size: Theme.iconSize - 6
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                text: root.barModeText()
                color: CardwireService.lastError.length > 0 ? Theme.error : Theme.surfaceText
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
                maximumLineCount: 1
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                anchors.horizontalCenter: parent.horizontalCenter
            }

        }

    }

    popoutContent: Component {
        PopoutComponent {
            id: popout

            showCloseButton: false
            spacing: Theme.spacingM
            Component.onCompleted: CardwireService.refreshModeState()

            Row {
                width: parent.width - Theme.spacingL * 2
                anchors.horizontalCenter: parent.horizontalCenter
                height: 44
                spacing: Theme.spacingM

                DankIcon {
                    name: CardwireService.lastError.length > 0 ? "warning" : "memory"
                    size: Theme.iconSizeLarge
                    color: CardwireService.lastError.length > 0 ? Theme.error : Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                    spacing: Theme.spacingXS
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - Theme.iconSizeLarge - closeButton.width - Theme.spacingM * 2

                    StyledText {
                        text: root.currentModeLabel()
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Font.Bold
                        color: CardwireService.lastError.length > 0 ? Theme.error : Theme.surfaceText
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        width: parent.width
                    }

                    StyledText {
                        text: CardwireService.lastError
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.error
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        width: parent.width
                        visible: CardwireService.lastError.length > 0
                    }

                }

                Rectangle {
                    id: closeButton

                    width: 32
                    height: 32
                    radius: 16
                    color: closeArea.containsMouse ? Theme.errorHover : "transparent"
                    anchors.top: parent.top

                    DankIcon {
                        anchors.centerIn: parent
                        name: "close"
                        size: Theme.iconSize - 4
                        color: closeArea.containsMouse ? Theme.error : Theme.surfaceText
                    }

                    MouseArea {
                        id: closeArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: {
                            popout.closePopout();
                        }
                    }

                }

            }

            Column {
                width: parent.width - Theme.spacingL * 2
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.spacingS

                Repeater {
                    model: root.modes

                    delegate: StyledRect {
                        id: modeRow

                        required property var modelData
                        readonly property bool active: modeRow.modelData.name === root.activeModeName

                        width: parent.width
                        height: 56
                        radius: Theme.cornerRadius
                        color: {
                            if (modeRow.active)
                                return Theme.withAlpha(Theme.primary, 0.16);

                            if (rowArea.containsMouse)
                                return Theme.nestedSurface;

                            return Theme.surfaceContainerHigh;
                        }
                        border.width: modeRow.active ? 1 : 0
                        border.color: modeRow.active ? Theme.primary : "transparent"

                        Row {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: Theme.spacingM
                            anchors.rightMargin: Theme.spacingM
                            spacing: Theme.spacingM

                            DankIcon {
                                name: modeRow.active ? "check_circle" : "tune"
                                color: modeRow.active ? Theme.primary : Theme.surfaceTextMedium
                                size: Theme.iconSize
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Column {
                                width: parent.width - Theme.iconSize - Theme.spacingM
                                spacing: Theme.spacingXS
                                anchors.verticalCenter: parent.verticalCenter

                                StyledText {
                                    text: modeRow.modelData.label
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: modeRow.active ? Font.Bold : Font.Medium
                                    color: Theme.surfaceText
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                    width: parent.width
                                }

                                StyledText {
                                    text: modeRow.modelData.description
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceTextMedium
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                    width: parent.width
                                }

                            }

                        }

                        MouseArea {
                            id: rowArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: !CardwireService.refreshing && !CardwireService.applying
                            onClicked: root.selectMode(modeRow.modelData)
                        }

                    }

                }

            }

            Row {
                width: parent.width - Theme.spacingL * 2
                anchors.horizontalCenter: parent.horizontalCenter
                height: 40
                spacing: Theme.spacingS

                DankButton {
                    text: CardwireService.refreshing ? "Refreshing" : "Refresh"
                    iconName: "refresh"
                    enabled: !CardwireService.refreshing
                    onClicked: CardwireService.refreshModeState()
                }

                StyledText {
                    text: CardwireService.lastRefreshText.length > 0 ? "Updated " + CardwireService.lastRefreshText : ""
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceTextMedium
                    height: parent.height
                    anchors.verticalCenter: parent.verticalCenter
                    visible: text.length > 0
                }

            }

            Item {
                width: 1
                height: Theme.spacingXS
            }

        }

    }

}
