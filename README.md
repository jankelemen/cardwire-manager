# cardwire-manager

A Dank Material Shell plugin for selecting Cardwire GPU modes from the DankBar.

The widget reads the current mode with:

```sh
cardwire get
```

and switches modes with:

```sh
cardwire set <mode>
```

## Features

- Shows the active Cardwire mode in the bar.
- Lists every mode reported by `cardwire get` in the popout.
- Marks the active mode with a check indicator.
- Switches modes from the popout.
- Cycles to the next mode from the pill right-click action.
- Polls Cardwire state every 15 seconds by default.
- Exposes the polling interval as a settings slider. Polling can also be disabled.

## Install

Symlink the plugin into DMS:

```sh
ln -s "$PWD/cardwire-manager" ~/.config/DankMaterialShell/plugins/cardwire-manager
```

Then open DMS settings, scan for plugins, enable **Cardwire Manager**, and add it to the DankBar widget list.

## Configuration

Settings live in **DMS Settings -> Plugins -> Cardwire Manager**.

- **Refresh interval**: how often the plugin calls `cardwire get`; default is 15 seconds.
- **Periodic polling**: enables or disables background refreshes. Startup, manual, and post-switch refreshes still run.
- **Abbreviate mode names**: shows only the first letter of the active mode in the bar.

## Development

There is no build toolchain. DMS loads the QML at runtime.

```sh
dms ipc call plugins reload cardwireManager
```
