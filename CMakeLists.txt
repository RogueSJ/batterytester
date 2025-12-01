cmake_minimum_required(VERSION 3.16)

project(batterytester VERSION 1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick SerialPort Charts Widgets)

qt_standard_project_setup(REQUIRES 6.5)

# Windows application icon
set(APP_ICON_RESOURCE_WINDOWS "${CMAKE_CURRENT_SOURCE_DIR}/resources/app.rc")

qt_add_executable(appbatterytester
    main.cpp
    deviceprotocol.h
    deviceprotocol.cpp
    devicemanager.h
    devicemanager.cpp
    csvdatamodel.h
    csvdatamodel.cpp
    $<$<PLATFORM_ID:Windows>:${APP_ICON_RESOURCE_WINDOWS}>
)

qt_add_qml_module(appbatterytester
    URI batterytester
    VERSION 1.0
    QML_FILES
        Main.qml
        TestMinimal.qml
)

# Qt for iOS sets MACOSX_BUNDLE_GUI_IDENTIFIER automatically since Qt 6.1.
# If you are developing for iOS or macOS you should consider setting an
# explicit, fixed bundle identifier manually though.
set_target_properties(appbatterytester PROPERTIES
#    MACOSX_BUNDLE_GUI_IDENTIFIER com.example.appbatterytester
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(appbatterytester
    PRIVATE Qt6::Quick Qt6::SerialPort Qt6::Charts Qt6::Widgets
)

include(GNUInstallDirs)
install(TARGETS appbatterytester
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
