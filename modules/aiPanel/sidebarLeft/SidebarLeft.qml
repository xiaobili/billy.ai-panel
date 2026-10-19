import "../../.."
import "../../common"
import "../../common/widgets"
import QtQuick
import Quickshell.Io
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Scope { // Scope
    id: root
    property bool pin: false
    property Component contentComponent: SidebarLeftContent {}
    property Item sidebarContent

    Process { // Dodge cursor away, pin, move cursor back
        id: pinWithFunnyHyprlandWorkaroundProc
        property var hook: null
        property int cursorX;
        property int cursorY;
        function doIt() {
            command = ["hyprctl", "cursorpos"]
            hook = (output) => {
                cursorX = parseInt(output.split(",")[0]);
                cursorY = parseInt(output.split(",")[1]);
                doIt2();
            }
            running = true;
        }
        function doIt2(output) {
            command = ["bash", "-c", "hyprctl dispatch 'hl.dsp.cursor.move({x=9999,y=9999})'"];
            hook = () => {
                doIt3();
            }
            running = true;
        }
        function doIt3(output) {
            root.pin = !root.pin;
            command = ["bash", "-c", `sleep 0.01; hyprctl dispatch 'hl.dsp.cursor.move({x=${cursorX},y=${cursorY}})'`];
            hook = null
            running = true;
        }
        stdout: StdioCollector {
            onStreamFinished: {
                pinWithFunnyHyprlandWorkaroundProc.hook(text);
            }
        }
    }

    function togglePin() {
        if (!root.pin) pinWithFunnyHyprlandWorkaroundProc.doIt()
        else root.pin = !root.pin;
    }

    function injectSidebarContent() {
        const win = sidebarLoader.item
        if (!win || !win.contentParent || !root.sidebarContent) return
        win.contentParent.children = [root.sidebarContent]
    }

    Component.onCompleted: {
        root.sidebarContent = contentComponent.createObject(null, {
            "scopeRoot": root,
        });
        // The window Loader may not have instantiated yet when running as an
        // Omarchy plugin (deferred window creation), so retry on item change.
        injectSidebarContent();
    }
    onSidebarContentChanged: injectSidebarContent()

    Connections {
        target: sidebarLoader
        function onItemChanged() { injectSidebarContent() }
    }

    Loader {
        id: sidebarLoader
        active: true
        
        sourceComponent: PanelWindow { // Window
            id: panelWindow
            visible: GlobalStates.sidebarLeftOpen

            // Modal (unpinned) mode follows the official Omarchy panel pattern
            // (menu/clipboard/emojis/reminders): a full-screen layer surface
            // holding WlrKeyboardFocus.Exclusive, with a click-catcher behind
            // the content for outside-click dismissal.
            //
            // Why Exclusive: with OnDemand, Hyprland's focus-follows-mouse
            // hands the keyboard back to whatever toplevel the cursor hovers
            // (foot/kitty), so IME commits (typing Chinese while the mouse
            // rests on a terminal) land in the terminal instead of the panel.
            // Exclusive keeps keyboard + IME focus inside the panel until it
            // closes.
            //
            // Why the click-catcher replaces HyprlandFocusGrab dismissal:
            // Hyprland 0.49+ refuses to move keyboard focus away from an
            // exclusive layer surface, so a focus grab around the panel can
            // never clear on outside clicks. Official panels therefore catch
            // the click on their own full-screen surface instead.
            //
            // Docked (pinned) mode keeps OnDemand + pass-through input, since
            // a docked panel must let the user click into and type in the
            // terminal tiled beside it.
            readonly property bool modal: GlobalStates.sidebarLeftOpen && !root.pin

            property bool extend: false
            property real sidebarWidth: panelWindow.extend ? Appearance.sizes.sidebarWidthExtended : Appearance.sizes.sidebarWidth
            property var contentParent: sidebarContentHolder

            function hide() {
                GlobalStates.sidebarLeftOpen = false
            }

            exclusionMode: ExclusionMode.Normal
            exclusiveZone: root.pin ? sidebarWidth : 0
            implicitWidth: Appearance.sizes.sidebarWidthExtended + Appearance.sizes.elevationMargin
            WlrLayershell.namespace: "quickshell:sidebarLeft"
            WlrLayershell.keyboardFocus: panelWindow.modal
                ? WlrKeyboardFocus.Exclusive
                : WlrKeyboardFocus.OnDemand
            color: "transparent"

            anchors {
                top: true
                left: true
                bottom: true
                right: panelWindow.modal
            }

            // Input region: modal mode must receive clicks on the whole window
            // (the click-catcher below); docked mode limits input to the panel
            // rectangle so clicks pass through to surrounding surfaces.
            mask: panelWindow.modal ? fullWindowMask : sidebarMask
            Region {
                id: fullWindowMask
                // Region is not an Item: no anchors — bind geometry directly.
                width: panelWindow.width
                height: panelWindow.height
            }
            Region {
                id: sidebarMask
                item: sidebarLeftBackground
            }

            // Click-catcher: closes the panel on outside click (modal mode).
            // Declared first so every sidebar item sits above it.
            MouseArea {
                anchors.fill: parent
                enabled: panelWindow.modal
                onClicked: panelWindow.hide()
            }

            // Content
            StyledRectangularShadow {
                target: sidebarLeftBackground
                radius: sidebarLeftBackground.radius
            }
            Rectangle {
                id: sidebarLeftBackground
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.topMargin: Appearance.sizes.hyprlandGapsOut
                anchors.leftMargin: Appearance.sizes.hyprlandGapsOut
                width: panelWindow.sidebarWidth - Appearance.sizes.hyprlandGapsOut - Appearance.sizes.elevationMargin
                height: parent.height - Appearance.sizes.hyprlandGapsOut * 2
                color: Appearance.colors.colLayer0
                border.width: 1
                border.color: Appearance.colors.colLayer0Border
                radius: Math.max(0, Appearance.rounding.screenRounding - Appearance.sizes.hyprlandGapsOut + 1)

                // Swallows clicks on the panel's own padding so they don't
                // fall through to the click-catcher. Declared before the
                // content holder, so injected content stays on top of it.
                MouseArea {
                    anchors.fill: parent
                    onClicked: (event) => event.accepted = true
                }

                // Injected sidebar content lands here (see injectSidebarContent).
                Item {
                    id: sidebarContentHolder
                    anchors.fill: parent
                }

                Behavior on width {
                    animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                }

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Escape) {
                        panelWindow.hide();
                    }
                    if (event.modifiers === Qt.ControlModifier) {
                        if (event.key === Qt.Key_O) {
                            panelWindow.extend = !panelWindow.extend;
                        } else if (event.key === Qt.Key_P) {
                            root.togglePin();
                        }
                        event.accepted = true;
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "sidebarLeft"

        function toggle(): void {
            GlobalStates.sidebarLeftOpen = !GlobalStates.sidebarLeftOpen
        }

        function close(): void {
            GlobalStates.sidebarLeftOpen = false
        }

        function open(): void {
            GlobalStates.sidebarLeftOpen = true
        }
    }

    GlobalShortcut {
        name: "sidebarLeftToggle"
        description: "Toggles left sidebar on press"

        onPressed: {
            GlobalStates.sidebarLeftOpen = !GlobalStates.sidebarLeftOpen;
        }
    }

    GlobalShortcut {
        name: "sidebarLeftOpen"
        description: "Opens left sidebar on press"

        onPressed: {
            GlobalStates.sidebarLeftOpen = true;
        }
    }

    GlobalShortcut {
        name: "sidebarLeftClose"
        description: "Closes left sidebar on press"

        onPressed: {
            GlobalStates.sidebarLeftOpen = false;
        }
    }

}
