cmake_minimum_required(VERSION 3.16)
project(ChronOS CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Debug)
endif()

# --- chronos_core: engine logic shared by the CLI and the GUI ------------
file(GLOB CORE_SOURCES
    "${CMAKE_SOURCE_DIR}/engine/*.cpp"
    "${CMAKE_SOURCE_DIR}/engine/schedulers/*.cpp"
)
list(REMOVE_ITEM CORE_SOURCES "${CMAKE_SOURCE_DIR}/engine/main.cpp")

add_library(chronos_core STATIC ${CORE_SOURCES})

target_include_directories(chronos_core PUBLIC
    "${CMAKE_SOURCE_DIR}/engine"
    "${CMAKE_SOURCE_DIR}/engine/vendor"
)

# --- chronos: CLI (writes results/<name>.json) ----------------------------
add_executable(chronos "${CMAKE_SOURCE_DIR}/engine/main.cpp")
target_link_libraries(chronos PRIVATE chronos_core)

set_target_properties(chronos PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/engine"
)

# --- chronos_app: native Qt/QML GUI ---------------------------------------
find_package(Qt6 COMPONENTS Core Gui Qml Quick QUIET)

if(Qt6_FOUND)
    qt_standard_project_setup(REQUIRES 6.5)

    # All .qml files live in one directory (app/qml) and are declared with
    # paths relative to the source root, so the module needs no extra qmldir
    # files. Declaring the policy explicitly keeps the configure step warning-
    # free rather than leaving an unset-policy notice on every run.
    if(QT_KNOWN_POLICY_QTP0004)
        qt_policy(SET QTP0004 NEW)
    endif()

    file(GLOB APP_QML_FILES RELATIVE "${CMAKE_SOURCE_DIR}" "${CMAKE_SOURCE_DIR}/app/qml/*.qml")

    # Theme.qml is a `pragma Singleton` file — some Qt6 versions need this
    # property set explicitly or the singleton silently fails to register
    # (every Theme.* binding elsewhere then resolves to `undefined`).
    set_source_files_properties("${CMAKE_SOURCE_DIR}/app/qml/Theme.qml" PROPERTIES
        QT_QML_SINGLETON_TYPE TRUE
    )

    qt_add_executable(chronos_app
        "${CMAKE_SOURCE_DIR}/app/main.cpp"
        "${CMAKE_SOURCE_DIR}/app/ChronosBridge.cpp"
        "${CMAKE_SOURCE_DIR}/app/ChronosBridge.h"
        "${CMAKE_SOURCE_DIR}/app/WorkloadListModel.cpp"
        "${CMAKE_SOURCE_DIR}/app/WorkloadListModel.h"
    )

    # Bundled type (EDRD.md §3.1): JetBrains Mono for all UI, Instrument Serif for
    # display type only. Compiled into the binary as resources so an installed
    # build loads the same files a source-tree run does — app/main.cpp reads
    # them from :/qt/qml/ChronOS/fonts/.
    file(GLOB APP_FONT_FILES RELATIVE "${CMAKE_SOURCE_DIR}" "${CMAKE_SOURCE_DIR}/app/fonts/*.ttf")

    qt_add_qml_module(chronos_app
        URI ChronOS
        VERSION 1.0
        QML_FILES ${APP_QML_FILES}
        RESOURCES ${APP_FONT_FILES}
    )

    target_link_libraries(chronos_app PRIVATE chronos_core Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick)

    target_compile_definitions(chronos_app PRIVATE
        CHRONOS_WORKLOADS_DIR="${CMAKE_SOURCE_DIR}/workloads"
    )

    set_target_properties(chronos_app PROPERTIES
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/app"
    )
else()
    message(STATUS "Qt6 (Core/Gui/Qml/Quick) not found - skipping chronos_app GUI target, chronos CLI still builds.")
endif()
