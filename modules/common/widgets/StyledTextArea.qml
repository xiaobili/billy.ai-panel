import ".."
import "."
import QtQuick
import QtQuick.Controls

/**
 * Does not include visual layout, but includes the easily neglected colors.
 */
TextArea {
    id: control
    renderType: Text.NativeRendering
    selectedTextColor: Appearance.m3colors.m3onSecondaryContainer
    selectionColor: Appearance.colors.colSecondaryContainer
    placeholderTextColor: Appearance.m3colors.m3outline
    color: Appearance.colors.colOnLayer0
    font {
        family: Appearance.font.family.main
        pixelSize: Appearance?.font.pixelSize.small ?? 15
        hintingPreference: Font.PreferFullHinting
        variableAxes: Appearance.font.variableAxes.main
    }

    // Right-click context menu at the mouse position. A right-button
    // TapHandler is the documented way to keep Qt from synthesizing the
    // automatic QContextMenuEvent: the style's built-in TextEditingContextMenu
    // would otherwise open at the text cursor instead of the mouse
    // (QQuickTextEdit::contextMenuEvent re-maps the event position to
    // cursorRectangle().center()). See StyledTextContextMenu.
    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: (eventPoint, button) => textContextMenu.openAt(control, eventPoint.position)
    }

    property alias contextMenu: textContextMenu

    StyledTextContextMenu {
        id: textContextMenu
        editor: control
    }
}
