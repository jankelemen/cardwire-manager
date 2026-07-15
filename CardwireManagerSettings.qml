import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    pluginId: "cardwireManager"
    Component.onCompleted: CardwireService.refreshModeState()

    StyledText {
        text: "Cardwire Manager"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    ToggleSetting {
        settingKey: "pollingEnabled"
        label: "Periodic polling"
        description: "Periodically refresh Cardwire state in the background. Turning this off stops refresh interval updates."
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "abbreviateModeNames"
        label: "Abbreviate mode names"
        description: "Show only the first letter of the current mode in the bar."
        defaultValue: false
    }

    StyledRect {
        width: parent.width
        height: generalCol.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: generalCol

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: Theme.spacingL
            anchors.rightMargin: Theme.spacingL
            anchors.topMargin: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                text: "General"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Bold
                color: Theme.surfaceText
            }

            SliderSetting {
                settingKey: "pollIntervalSeconds"
                label: "Refresh interval"
                description: "How often to call cardwire get."
                defaultValue: 15
                minimum: 5
                maximum: 120
                unit: "s"
            }

        }

    }

    StyledRect {
        width: parent.width
        height: statusCol.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: statusCol

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: Theme.spacingL
            anchors.rightMargin: Theme.spacingL
            anchors.topMargin: Theme.spacingL
            spacing: Theme.spacingM

            Row {
                width: parent.width
                spacing: Theme.spacingM

                StyledText {
                    text: "Modes"
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Bold
                    color: Theme.surfaceText
                    width: parent.width - refreshButton.width - parent.spacing
                    anchors.verticalCenter: parent.verticalCenter
                }

                DankButton {
                    id: refreshButton

                    text: CardwireService.refreshing ? "Refreshing" : "Refresh"
                    iconName: "refresh"
                    enabled: !CardwireService.refreshing
                    onClicked: CardwireService.refreshModeState()
                }

            }

            StyledText {
                text: CardwireService.lastError.length > 0 ? CardwireService.lastError : (CardwireService.activeModeName.length > 0 ? "Active: " + CardwireService.modeLabel(CardwireService.activeModeName) : "No active mode")
                font.pixelSize: Theme.fontSizeSmall
                color: CardwireService.lastError.length > 0 ? Theme.error : Theme.surfaceTextMedium
                width: parent.width
                wrapMode: Text.WordWrap
            }

            Repeater {
                model: CardwireService.modes

                delegate: StyledRect {
                    id: modeRow

                    required property var modelData
                    readonly property bool active: modeRow.modelData.name === CardwireService.activeModeName

                    width: parent.width
                    height: 48
                    radius: Theme.cornerRadius
                    color: modeRow.active ? Theme.withAlpha(Theme.primary, 0.16) : Theme.nestedSurface
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
                            size: Theme.iconSize - 2
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            width: parent.width - Theme.iconSize - Theme.spacingM
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            StyledText {
                                text: modeRow.modelData.label
                                font.pixelSize: Theme.fontSizeSmall
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

                }

            }

        }

    }

}
