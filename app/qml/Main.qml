import QtQuick
import QtQuick.Controls
import QtQuick.Window
import ChronOS

ApplicationWindow {
    id: window
    // Screen.desktopAvailableWidth/Height is unreliable in some sandboxed/
    // virtual-display environments (observed reporting 1920x1200 against an
    // actual visible desktop of 1280x800) — so the size is fixed rather than
    // derived. 1180x730 leaves room for the title bar and taskbar on a
    // 1280x800 panel, which is the smallest display this has to run on; every
    // screen is laid out to work at that size rather than assuming more.
    width: 1180
    height: 730
    minimumWidth: 960
    minimumHeight: 620
    visible: true
    title: "ChronOS"
    color: Theme.bgVoid

    StackView {
        id: stack
        anchors.fill: parent
        initialItem: splashComponent

        replaceEnter: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.durationSlow }
        }
        replaceExit: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.durationBase }
        }
    }

    Component {
        id: splashComponent
        Splash { onFinished: stack.replace(algorithmPickerComponent) }
    }
    Component {
        id: algorithmPickerComponent
        AlgorithmPicker {
            onChosen: stack.replace(workloadPickerComponent)
            onTuneRequested: stack.replace(tunerComponent)
        }
    }
    // Added 2026-10-16: tuning AARS happens between the algorithm and
    // workload steps, only when asked for via [ TUNE ].
    Component {
        id: tunerComponent
        AlgorithmTuner {
            onContinueRequested: stack.replace(workloadPickerComponent)
            onBackRequested: stack.replace(algorithmPickerComponent)
        }
    }
    Component {
        id: workloadPickerComponent
        WorkloadPicker {
            onRunRequested: {
                // Compare mode (2026-10-22) runs both chosen algorithms on the
                // same processes and opens the side-by-side screen instead.
                if (bridge.compareMode) {
                    if (bridge.runComparison()) stack.replace(compareComponent);
                } else if (bridge.runSelectedSimulation()) {
                    stack.replace(dashboardComponent);
                }
            }
            onBackRequested: stack.replace(algorithmPickerComponent)
        }
    }
    Component {
        id: dashboardComponent
        Dashboard {
            onRestartRequested: stack.replace(algorithmPickerComponent)
        }
    }
    Component {
        id: compareComponent
        CompareView {
            onRestartRequested: stack.replace(algorithmPickerComponent)
        }
    }

    // EDRD.md §2.7 — front-most layer, mounted once for the whole app rather
    // than per-screen. `enabled: false` is what keeps it from eating clicks.
    ScanlineOverlay {
        anchors.fill: parent
    }
}
