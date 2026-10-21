import QtQuick
import ChronOS

// Numeric input in the terminal's grammar: `[-] 12.5 [+]`. Added 2026-10-16
// for the algorithm tuner and the custom workload builder (explicit user
// request) — the app had no editable control before, and both screens need one
// that reads as a shell prompt field rather than a desktop spin box.
//
// The value is typeable (click it, type, Enter), steppable ([-]/[+], hold to
// repeat) and wheel-able. It never writes `value` itself: it emits edited()
// with the clamped, rounded result and the caller decides — which is what lets
// the bridge apply its own clamping and stay the single source of truth.
Item {
    id: root

    property real value: 0
    property real step: 1
    property real minimum: 0
    property real maximum: 100
    property int decimals: 0
    property int cells: 4            // width of the value field, in characters
    property bool enabledStepper: true
    property color valueColor: Theme.textPrimary
    signal edited(real value)

    implicitWidth: minus.width + field.width + plus.width
    implicitHeight: Theme.sizeData + Theme.spaceXs * 2 + 2

    function commit(v) {
        if (isNaN(v)) return;
        v = Math.max(minimum, Math.min(maximum, v));
        v = Number(v.toFixed(decimals));
        if (v !== value) edited(v);
    }

    component StepButton: Rectangle {
        id: btn
        property string glyph: "-"
        property real direction: -1
        readonly property bool lit: area.containsMouse && root.enabledStepper

        width: Theme.charWidth(Theme.sizeData) * 3
        height: root.height
        radius: Theme.radiusNone
        color: lit ? Theme.textPrimary : Theme.bgVoid
        border.width: Theme.borderThin
        border.color: lit ? Theme.textPrimary : Theme.borderMuted

        Text {
            anchors.centerIn: parent
            text: btn.glyph
            color: !root.enabledStepper ? Theme.textDim
                                        : (btn.lit ? Theme.textOnAccent : Theme.textPrimary)
            font.family: Theme.fontMono
            font.pixelSize: Theme.sizeData
            font.weight: Theme.weightBold
        }

        Timer {
            id: repeat
            interval: 70
            repeat: true
            onTriggered: root.commit(root.value + btn.direction * root.step)
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            enabled: root.enabledStepper
            cursorShape: Qt.PointingHandCursor
            onClicked: root.commit(root.value + btn.direction * root.step)
            onPressAndHold: repeat.start()
            onReleased: repeat.stop()
            onCanceled: repeat.stop()
        }
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        StepButton { id: minus; glyph: "-"; direction: -1 }

        Rectangle {
            id: field
            width: Theme.charWidth(Theme.sizeData) * root.cells + Theme.spaceSm * 2
            height: root.height
            radius: Theme.radiusNone
            color: Theme.bgInset
            border.width: Theme.borderThin
            border.color: input.activeFocus ? Theme.borderActive : Theme.borderMuted

            TextInput {
                id: input
                anchors.fill: parent
                anchors.leftMargin: Theme.spaceSm
                anchors.rightMargin: Theme.spaceSm
                verticalAlignment: TextInput.AlignVCenter
                horizontalAlignment: TextInput.AlignRight
                text: root.value.toFixed(root.decimals)
                readOnly: !root.enabledStepper
                color: root.enabledStepper ? root.valueColor : Theme.textDim
                selectionColor: Theme.textPrimary
                selectedTextColor: Theme.textOnAccent
                selectByMouse: true
                clip: true
                font.family: Theme.fontMono
                font.pixelSize: Theme.sizeData
                validator: RegularExpressionValidator { regularExpression: /-?[0-9]*\.?[0-9]*/ }

                function restore() {
                    text = Qt.binding(() => root.value.toFixed(root.decimals));
                }
                onEditingFinished: {
                    root.commit(Number(text));
                    restore();
                }
                onActiveFocusChanged: if (!activeFocus) restore()
                Keys.onUpPressed: root.commit(root.value + root.step)
                Keys.onDownPressed: root.commit(root.value - root.step)
                Keys.onEscapePressed: { restore(); focus = false; }
            }

            WheelHandler {
                enabled: root.enabledStepper
                onWheel: (event) => root.commit(root.value + (event.angleDelta.y > 0 ? 1 : -1) * root.step)
            }
        }

        StepButton { id: plus; glyph: "+"; direction: 1 }
    }
}
