import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property var pluginApi: null

    // Current authentication state
    property string currentActionId: ""
    property string currentMessage: ""
    property string currentIconName: ""
    property string currentCookie: ""
    property string currentRequest: ""
    property bool currentEcho: false
    property bool isAuthenticating: false
    property string errorMessage: ""

    // Connection status
    property bool isConnected: socket.connected

    onIsConnectedChanged: {
        console.log("[polkit-agent] Main.isConnected changed:", isConnected)
    }

    // Socket path
    readonly property string socketPath: {
        var runtimeDir = Quickshell.env("XDG_RUNTIME_DIR")
        if (runtimeDir) {
            return runtimeDir + "/quickshell-polkit/quickshell-polkit"
        } else {
            return "/tmp/quickshell-polkit-" + Quickshell.env("UID") + "/quickshell-polkit"
        }
    }

    // Submit authentication response (password)
    function submitResponse(response) {
        if (!socket.connected) {
            console.log("[polkit-agent] Not connected to polkit agent")
            return false
        }

        var message = {
            "type": "submit_authentication",
            "cookie": currentCookie,
            "response": response
        }

        socket.write(JSON.stringify(message) + "\n")
        socket.flush()
        return true
    }

    // Cancel current authorization
    function cancelAuthorization() {
        if (!socket.connected) return

        var message = {
            "type": "cancel_authorization"
        }

        socket.write(JSON.stringify(message) + "\n")
        socket.flush()
        closeDialog()
    }

    function openDialog() {
        console.log("[polkit-agent] Opening dialog via pluginApi.openPanel()")
        if (!pluginApi) {
            console.log("[polkit-agent] pluginApi not available")
            return
        }
        pluginApi.withCurrentScreen(function(screen) {
            pluginApi.openPanel(screen)
        })
    }

    function closeDialog() {
        console.log("[polkit-agent] Closing dialog")
        if (pluginApi) {
            pluginApi.withCurrentScreen(function(screen) {
                pluginApi.closePanel(screen)
            })
        }
        // Reset state
        isAuthenticating = false
        currentActionId = ""
        currentMessage = ""
        currentIconName = ""
        currentCookie = ""
        currentRequest = ""
        currentEcho = false
        errorMessage = ""
    }

    function handleMessage(message) {
        switch (message.type) {
        case "show_auth_dialog":
            console.log("[polkit-agent] Auth dialog requested for:", message.action_id)
            currentActionId = message.action_id || ""
            currentMessage = message.message || ""
            currentIconName = message.icon_name || ""
            currentCookie = message.cookie || ""
            errorMessage = ""
            // Only open dialog if not already authenticating (avoid toggle on second message)
            if (!isAuthenticating) {
                isAuthenticating = true
                openDialog()
            }
            break

        case "password_request":
            console.log("[polkit-agent] Password requested for:", message.action_id)
            currentActionId = message.action_id || ""
            currentRequest = message.request || "Password:"
            currentEcho = message.echo || false
            currentCookie = message.cookie || ""
            errorMessage = ""
            // Only open dialog if not already authenticating (avoid toggle on second message)
            if (!isAuthenticating) {
                isAuthenticating = true
                openDialog()
            }
            break

        case "authorization_result":
            console.log("[polkit-agent] Authorization result:", message.authorized ? "GRANTED" : "DENIED")
            if (!message.authorized) {
                errorMessage = "Authentication failed"
            }
            closeDialog()
            break

        case "authorization_error":
            console.log("[polkit-agent] Authorization error:", message.error)
            errorMessage = message.error || "Unknown error"
            break

        case "authentication_state_changed":
            console.log("[polkit-agent] State changed:", message.state)
            break

        case "authentication_method_changed":
            console.log("[polkit-agent] Method changed:", message.method)
            break

        default:
            console.log("[polkit-agent] Unknown message type:", message.type)
        }
    }

    // Unix socket connection to quickshell-polkit-agent daemon
    Socket {
        id: socket
        path: root.socketPath

        parser: SplitParser {
            onRead: function(data) {
                var line = data.trim()
                if (line.length > 0) {
                    try {
                        var message = JSON.parse(line)
                        root.handleMessage(message)
                    } catch (e) {
                        console.log("[polkit-agent] Invalid JSON:", e, "Data:", line)
                    }
                }
            }
        }

        onConnectedChanged: {
            if (connected) {
                console.log("[polkit-agent] Connected to quickshell-polkit-agent")
            } else {
                console.log("[polkit-agent] Disconnected from quickshell-polkit-agent")
                reconnectTimer.start()
            }
        }

        onError: function(error) {
            console.log("[polkit-agent] Socket error:", error)
        }
    }

    // Auto-connect on component creation
    Component.onCompleted: {
        console.log("[polkit-agent] Connecting to:", socketPath)
        socket.connected = true
    }

    // Auto-reconnect on disconnection
    Timer {
        id: reconnectTimer
        interval: 2000
        repeat: false
        onTriggered: {
            if (!socket.connected) {
                console.log("[polkit-agent] Reconnecting...")
                socket.connected = true
            }
        }
    }
}
