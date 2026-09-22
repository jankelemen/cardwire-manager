import QtQuick
import Quickshell
import qs.Common
import qs.Services
pragma Singleton

Singleton {
    id: root

    property var modes: []
    property string activeModeName: ""
    property string lastError: ""
    property string lastRefreshText: ""
    property bool refreshing: false
    property bool applying: false
    property bool startupLoading: false

    readonly property bool busy: refreshing || applying
    property bool _refreshPending: false
    property var _widgets: []
    readonly property var _pollingWidgets: _widgets.filter(widget => widget.pollingEnabled)
    readonly property var _startupRetryDelays: [2000, 5000, 10000]
    property int _startupRetryIndex: 0

    function registerWidget(widget) {
        root._widgets = root._widgets.concat([widget]);
        if (root._widgets.length === 1) {
            root.startupLoading = root.activeModeName.length === 0;
            root._startupRetryIndex = 0;
            root.refreshModeState();
        }
    }

    function unregisterWidget(widget) {
        root._widgets = root._widgets.filter(candidate => candidate !== widget);
        if (root._widgets.length === 0) {
            startupRetry.stop();
            root.startupLoading = false;
        }
    }

    function refreshModeState() {
        if (root.busy) {
            root._refreshPending = true;
            return;
        }
        startupRetry.stop();
        root._refreshPending = false;
        root.refreshing = true;
        root._runCommand("get", [], (stdout, exitCode) => {
            if (exitCode !== 0) {
                root.lastError = stdout.trim() || "cardwire get exited " + exitCode;
            } else {
                const modeName = root._parseCurrentModeName(stdout);
                const availableModeNames = root._parseAvailableModeNames(stdout);
                if (!modeName || availableModeNames.length === 0) {
                    root.lastError = "Unrecognized cardwire get output";
                } else {
                    root.modes = availableModeNames.map(mode => root._createModeData(mode));
                    root.activeModeName = modeName;
                    root.lastError = "";
                    root.lastRefreshText = Qt.formatDateTime(new Date(), "HH:mm:ss");
                }
            }
            root.refreshing = false;
            if (root.startupLoading) {
                if (!root.lastError || root._startupRetryIndex === root._startupRetryDelays.length) {
                    root.startupLoading = false;
                } else {
                    startupRetry.interval = root._startupRetryDelays[root._startupRetryIndex];
                    startupRetry.start();
                }
            }
            if (root._refreshPending)
                Qt.callLater(root.refreshModeState);
        }, 5000);
    }

    function setMode(modeName) {
        if (root.busy || modeName === root.activeModeName)
            return;
        if (!modeName) {
            root.lastError = "Mode name is empty.";
            ToastService.showError("Cardwire mode switch failed", root.lastError);
            return;
        }
        postApplyRefresh.stop();
        root.applying = true;
        root._runCommand("set", [modeName], (stdout, exitCode) => {
            root.applying = false;
            if (exitCode !== 0) {
                root._refreshPending = false;
                root.lastError = stdout.trim() || "cardwire set " + modeName + " exited " + exitCode;
                ToastService.showError("Cardwire mode switch failed", root.lastError);
                return;
            }
            root.activeModeName = modeName;
            root.lastError = "";
            postApplyRefresh.restart();
        }, 15000);
    }

    function _runCommand(action, args, callback, timeoutMs) {
        // Keep arguments separate from shell code while collecting stderr as well as stdout.
        const command = ["sh", "-c", 'exec "$@" 2>&1', "cardwireManager", "cardwire", action].concat(args);
        Proc.runCommand("cardwireService." + action, command, callback, 50, timeoutMs);
    }

    function nextMode() {
        if (root.modes.length === 0)
            return null;

        const index = root.modes.findIndex((mode) => {
            return mode.name === root.activeModeName;
        });
        const nextIndex = index < 0 ? 0 : (index + 1) % root.modes.length;
        return root.modes[nextIndex];
    }

    function modeLabel(modeName) {
        const mode = root.modes.find((candidate) => {
            return candidate.name === modeName;
        });
        return mode ? mode.label : (modeName.length > 0 ? root._formatModeLabel(modeName) : "No mode");
    }

    function _createModeData(modeName) {
        const label = root._formatModeLabel(modeName);
        return {
            "name": modeName,
            "label": label,
            "description": "Switch to " + label + " mode"
        };
    }

    function _formatModeLabel(modeName) {
        return modeName.split(/[-_\s]+/).filter((word) => {
            return word.length > 0;
        }).map((word) => {
            return word.charAt(0).toUpperCase() + word.slice(1);
        }).join(" ");
    }

    function _parseCurrentModeName(stdout) {
        const match = stdout.match(/^Current Mode:[ \t]*([^\r\n]+)$/im);
        if (!match)
            return "";

        return match[1].trim().toLowerCase();
    }

    function _parseAvailableModeNames(stdout) {
        const match = stdout.match(/^Available Modes?:[ \t]*([^\r\n]+)$/im);
        if (!match)
            return [];

        return match[1].split(",").map((modeName) => {
            return modeName.trim().toLowerCase();
        }).filter((modeName) => {
            return modeName.length > 0;
        });
    }

    Timer {
        interval: root._pollingWidgets.length > 0 ? Math.min.apply(Math, root._pollingWidgets.map(widget => widget.pollIntervalSeconds)) * 1000 : 15000
        running: root._pollingWidgets.length > 0 && !root.startupLoading
        repeat: true
        onTriggered: root.refreshModeState()
    }

    Timer {
        id: startupRetry

        onTriggered: {
            root._startupRetryIndex += 1;
            root.refreshModeState();
        }
    }

    Timer {
        id: postApplyRefresh

        interval: 400
        onTriggered: root.refreshModeState()
    }

}
