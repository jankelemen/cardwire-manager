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

    function refreshModeState() {
        if (root.refreshing)
            return ;

        root.refreshing = true;
        Proc.runCommand("cardwireService.get", ["cardwire", "get"], (stdout, exitCode) => {
            if (exitCode !== 0) {
                root.refreshing = false;
                root.lastError = stdout && stdout.length > 0 ? stdout.trim() : "cardwire get exited " + exitCode;
                return ;
            }
            const modeName = root._parseCurrentModeName(stdout);
            const availableModeNames = root._parseAvailableModeNames(stdout);
            if (modeName.length === 0) {
                root.refreshing = false;
                root.lastError = "Could not read the current Cardwire mode";
                return ;
            }
            if (availableModeNames.length === 0) {
                root.refreshing = false;
                root.lastError = "Could not read the available Cardwire modes";
                return ;
            }
            root.modes = availableModeNames.map((availableModeName) => {
                return root._createModeData(availableModeName);
            });
            root.activeModeName = modeName;
            root.refreshing = false;
            root.lastError = "";
            root.lastRefreshText = Qt.formatDateTime(new Date(), "HH:mm:ss");
        }, 50, 5000);
    }

    function setMode(modeName, onDone) {
        root.applying = true;
        Proc.runCommand("cardwireService.set", ["cardwire", "set", modeName], (stdout, exitCode) => {
            root.applying = false;
            if (exitCode !== 0) {
                root.lastError = stdout && stdout.length > 0 ? stdout.trim() : "cardwire set " + modeName + " exited " + exitCode;
                ToastService.showError("Cardwire mode switch failed", root.lastError);
                onDone(false);
                return ;
            }
            root.activeModeName = modeName;
            root.lastError = "";
            onDone(true);
        }, 50, 15000);
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
        const match = stdout.match(/Current Mode:\s*([^\r\n]+)/i);
        if (!match)
            return "";

        return match[1].trim().toLowerCase();
    }

    function _parseAvailableModeNames(stdout) {
        const match = stdout.match(/Available Modes?:\s*([^\r\n]+)/i);
        if (!match)
            return [];

        return match[1].split(",").map((modeName) => {
            return modeName.trim().toLowerCase();
        }).filter((modeName) => {
            return modeName.length > 0;
        });
    }

}
