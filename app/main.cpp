#ifdef _WIN32
#include <windows.h>
#endif

#include <QFontDatabase>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QStringList>
#include <QtGlobal>

#include "ChronosBridge.h"

namespace {

// EDRD.md §3.1 — two bundled families, split hard by role. JetBrains Mono is
// the default for everything; Instrument Serif is display-only (splash wordmark,
// dashboard title, picker headings, why-panel verdict) and never touches a
// number, since it ships no tabular figures.
//
// These must be registered before QQmlApplicationEngine is constructed, or the
// first QML frame lays out against a fallback metric and re-flows once the real
// font arrives. Loaded from the Qt resource system rather than a relative path
// so an installed build behaves identically to a source-tree run.
void registerBundledFonts() {
    const QStringList fonts = {
        QStringLiteral(":/qt/qml/ChronOS/app/fonts/JetBrainsMono-Regular.ttf"),
        QStringLiteral(":/qt/qml/ChronOS/app/fonts/JetBrainsMono-Medium.ttf"),
        QStringLiteral(":/qt/qml/ChronOS/app/fonts/JetBrainsMono-SemiBold.ttf"),
        QStringLiteral(":/qt/qml/ChronOS/app/fonts/JetBrainsMono-Bold.ttf"),
        QStringLiteral(":/qt/qml/ChronOS/app/fonts/JetBrainsMono-ExtraBold.ttf"),
        QStringLiteral(":/qt/qml/ChronOS/app/fonts/InstrumentSerif-Regular.ttf"),
        QStringLiteral(":/qt/qml/ChronOS/app/fonts/InstrumentSerif-Italic.ttf"),
    };

    for (const QString& path : fonts) {
        // A failed load is worth shouting about: Qt falls back to a system
        // font that looks *almost* right, so a silent -1 here shows up much
        // later as "why is the type slightly wrong" rather than as an error.
        if (QFontDatabase::addApplicationFont(path) < 0) {
            qWarning("ChronOS: failed to load bundled font %s", qPrintable(path));
        }
    }
}

}  // namespace

int main(int argc, char** argv) {
#ifdef _WIN32
    // The build's generated manifest declares no DPI awareness, so Windows
    // silently stretches ("DPI-virtualizes") the whole window bitmap for an
    // "unaware" process — independent of anything Qt does internally, and
    // the actual cause of every off-by-a-weird-factor layout/centering bug
    // seen while developing this screen. Declaring Per-Monitor-V2 awareness
    // here (before QGuiApplication exists) stops Windows from virtualizing
    // it at all, so Qt's own real-DPI handling is what applies.
    SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
#endif

    QGuiApplication app(argc, argv);

    registerBundledFonts();

    // Mono is what anything unstyled inherits, so a missed font binding in QML
    // degrades to the right family rather than to a system sans-serif.
    QFont defaultFont(QStringLiteral("JetBrains Mono"));
    defaultFont.setPixelSize(14);
    QGuiApplication::setFont(defaultFont);

    ChronosBridge bridge;

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("bridge", &bridge);
    engine.loadFromModule("ChronOS", "Main");

    if (engine.rootObjects().isEmpty()) {
        return -1;
    }

    return app.exec();
}
