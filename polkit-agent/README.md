# Polkit Authentication Agent

A Noctalia plugin that provides a polkit authentication UI using [quickshell-polkit-agent](https://github.com/bennypowers/quickshell-polkit-agent).

<img width="5119" height="2160" alt="Screenshot from 2026-01-08 11-46-13-min" src="https://github.com/user-attachments/assets/23af7066-3d7c-4610-9f8f-78f0167e74da" />


## Requirements

- [quickshell-polkit-agent](https://github.com/bennypowers/quickshell-polkit-agent) daemon must be running
- The daemon creates a Unix socket at `$XDG_RUNTIME_DIR/quickshell-polkit/quickshell-polkit`

## Installation

1. Install and start quickshell-polkit-agent:
   ```bash
   # Enable the systemd user service
   systemctl --user enable --now quickshell-polkit-agent.service
   ```

2. Install this plugin via Noctalia's plugin manager

## How It Works

This plugin consists of two components:

- **Main.qml** - Background service that connects to the quickshell-polkit-agent daemon via Unix socket. Listens for authentication requests and opens the panel when needed.

- **Panel.qml** - Authentication dialog UI that appears when polkit requests authorization. Provides password input and submit/cancel actions.

## Features

- Automatic connection/reconnection to polkit agent daemon
- Password input with masked characters
- Error message display for failed authentication
- Connection status indicator
- Keyboard shortcuts (Enter to submit, Escape to cancel)

## Architecture

```
┌─────────────────────────────────────────┐
│ System (pkexec, etc.)                   │
└────────────────┬────────────────────────┘
                 │ D-Bus
                 ▼
┌─────────────────────────────────────────┐
│ quickshell-polkit-agent (C++ daemon)    │
└────────────────┬────────────────────────┘
                 │ Unix Socket (JSON)
                 ▼
┌─────────────────────────────────────────┐
│ Main.qml (IPC handler)                  │
│  ├── Connects to daemon socket          │
│  ├── Receives auth requests             │
│  └── Opens Panel on request             │
└────────────────┬────────────────────────┘
                 │ pluginApi
                 ▼
┌─────────────────────────────────────────┐
│ Panel.qml (Authentication UI)           │
│  ├── Shows action details               │
│  ├── Password input                     │
│  └── Submit/Cancel buttons              │
└─────────────────────────────────────────┘
```

## License

GPLv3
