import ".."
import "../../../services"
import "."
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/**
 * Right-click context menu for text editors (undo/redo/cut/copy/paste/
 * delete/select all), drawn with the project's own widgets and NerdSymbol
 * font icons.
 *
 * Why a custom menu instead of Qt's built-in TextEditingContextMenu (which
 * the Basic style attaches to every TextArea):
 * - Positioning: QQuickTextEdit::contextMenuEvent re-maps the context menu
 *   event to cursorRectangle().center(), so the built-in menu opens at the
 *   text cursor instead of at the mouse. Callers therefore open this menu
 *   themselves via openAt() with the real mouse position, from a
 *   right-button TapHandler (which also makes Qt skip synthesizing the
 *   automatic QContextMenuEvent, so the built-in menu never double-opens).
 * - Icons: the built-in menu resolves icons through the system icon theme,
 *   which renders as emoji on Omarchy. Here every item uses a NerdSymbol.
 *
 * Item enablement mirrors Qt's UndoAction/CopyAction/... (selected text,
 * canUndo/canRedo/canPaste, readOnly), so read-only editors just show
 * disabled editing entries.
 */
Menu {
    id: root

    // The TextArea/TextEdit this menu operates on. Set by the owner, or
    // re-pointed per-open via openAt() when sharing one menu between
    // several editors (e.g. chat message paragraphs).
    property Item editor
    readonly property bool editorEditable: editor !== null && !editor.readOnly

    // Opens the menu at a position in the target item's coordinates.
    //
    // The popup is re-parented to the window overlay instead of the target:
    // parenting it to the editor buries it under panel content declared
    // after the editor (later siblings paint above the editor's whole
    // subtree), which made the menu render semi-transparent behind the
    // input bar. The overlay always paints on top of window content, and
    // Qt's popup positioner still clamps/flips it within the window.
    function openAt(target: Item, pos: point) {
        root.editor = target;
        const overlay = target.Overlay.overlay;
        if (overlay === null) {
            popup(target, pos.x, pos.y);
            return;
        }
        if (root.parent !== overlay)
            root.parent = overlay;
        const overlayPos = target.mapToItem(overlay, pos.x, pos.y);
        popup(Qt.point(overlayPos.x, overlayPos.y));
    }

    // Popup.Item: Quickshell does not support native popup windows on layer
    // surfaces; in-window item popups position correctly and clamp/flip to
    // stay inside the window (QQuickPopupPositioner).
    popupType: Popup.Item
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    topPadding: 4
    bottomPadding: 4

    enter: Transition {
        NumberAnimation {
            property: "opacity"
            from: 0
            to: 1
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Appearance.animation.elementMoveFast.type
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }
    }

    background: Rectangle {
        implicitWidth: 180
        implicitHeight: 40
        // The shell's dedicated popup surface token: unlike the layer colors
        // (colLayer1 etc., which follow contentTransparency and are
        // semi-transparent by design — fine for backgrounds, wrong for a
        // floating menu over content), this is opaque, so panel content
        // never shows through the menu.
        color: Theme.popups.background
        border.width: 1
        border.color: Theme.popups.border
        radius: Appearance.rounding.small
    }

    component StyledTextMenuItem: MenuItem {
        id: menuItem

        property string iconText: ""
        property string labelText: ""

        leftPadding: 10
        rightPadding: 14
        topPadding: 6
        bottomPadding: 6
        implicitWidth: menuItemRowLayout.implicitWidth + leftPadding + rightPadding
        implicitHeight: menuItemRowLayout.implicitHeight + topPadding + bottomPadding

        contentItem: RowLayout {
            id: menuItemRowLayout
            spacing: 10

            NerdSymbol {
                iconName: menuItem.iconText
                iconSize: Appearance.font.pixelSize.normal
                color: menuItem.enabled ? menuItem.hovered ? Theme.popups.text : Appearance.colors.colOnLayer1Inactive : Appearance.colors.colOnLayer1Inactive
                Layout.alignment: Qt.AlignVCenter
            }
            StyledText {
                text: menuItem.labelText
                color: menuItem.enabled ? Theme.popups.text : Appearance.colors.colOnLayer1Inactive
                Layout.alignment: Qt.AlignVCenter
                Layout.fillWidth: true
            }
        }

        background: Rectangle {
            implicitWidth: 160
            implicitHeight: 30
            radius: Appearance.rounding.small
            color: menuItem.hovered ? Appearance.colors.colLayer1Hover : "transparent"
        }
    }

    component MenuItemSeparator: MenuSeparator {
        topPadding: 4
        bottomPadding: 4
        contentItem: Rectangle {
            implicitWidth: 160
            implicitHeight: 1
            color: Theme.popups.border
        }
    }

    StyledTextMenuItem {
        iconText: "undo"
        labelText: Translation.tr("Undo")
        enabled: root.editorEditable && editor.canUndo
        onTriggered: editor.undo()
    }
    StyledTextMenuItem {
        iconText: "redo"
        labelText: Translation.tr("Redo")
        enabled: root.editorEditable && editor.canRedo
        onTriggered: editor.redo()
    }

    MenuItemSeparator {}

    StyledTextMenuItem {
        iconText: "content_cut"
        labelText: Translation.tr("Cut")
        enabled: root.editorEditable && editor.selectedText.length > 0
        onTriggered: editor.cut()
    }
    StyledTextMenuItem {
        iconText: "copy"
        labelText: Translation.tr("Copy")
        enabled: editor !== null && editor.selectedText.length > 0
        onTriggered: editor.copy()
    }
    StyledTextMenuItem {
        iconText: "content_paste"
        labelText: Translation.tr("Paste")
        enabled: root.editorEditable && editor.canPaste
        onTriggered: editor.paste()
    }
    StyledTextMenuItem {
        iconText: "delete"
        labelText: Translation.tr("Delete")
        enabled: root.editorEditable && editor.selectedText.length > 0
        onTriggered: editor.removeSelectedText()
    }

    MenuItemSeparator {}

    StyledTextMenuItem {
        iconText: "select_all"
        labelText: Translation.tr("Select All")
        enabled: editor !== null && editor.length > 0
        onTriggered: editor.selectAll()
    }
}
