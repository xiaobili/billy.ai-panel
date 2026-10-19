pragma Singleton
pragma ComponentBehavior: Bound
import "../modules/common"
import QtQuick
import Quickshell

/**
 * A nice wrapper for date and time strings.
 * Only the consumers' fields are kept: Ai's {DATETIME} prompt substitution
 * uses `time` and `collapsedCalendarFormat`.
 */
Singleton {
    property var clock: SystemClock {
        id: clock
        precision: Config.options.time.secondPrecision ? SystemClock.Seconds : SystemClock.Minutes
    }
    property string time: Qt.locale().toString(clock.date, Config.options?.time.format ?? "hh:mm")
    property string collapsedCalendarFormat: Qt.locale().toString(clock.date, "dddd, MMMM dd")
}
