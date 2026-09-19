# SPDX-FileCopyrightText: 2026 crabiosa
# SPDX-License-Identifier: GPL-2.0-or-later

cmake_minimum_required(VERSION 3.20)
project(kwin-effect-swiperemap VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(ECM REQUIRED NO_MODULE)
list(APPEND CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

include(KDEInstallDirs)
include(KDECompilerSettings NO_POLICY_SCOPE)

find_package(KWin REQUIRED COMPONENTS kwineffects)
# Widgets is not used directly, but KWin::kwin has it in its link interface.
find_package(Qt6 REQUIRED COMPONENTS Core Gui Widgets)
find_package(KF6 REQUIRED COMPONENTS CoreAddons)

add_library(swiperemap MODULE swiperemap.cpp)

# KWin looks for effects at <qt-plugin-dir>/kwin/effects/plugins/<id>.so and
# takes the id from the metadata baked into the .so. That is why the file must
# be named exactly "swiperemap.so": no "lib" prefix (it would change the
# kwinrc key) and, unlike a normal library, the version never appears in the
# name. The pluginroot layout below is what the headless smoke run points
# QT_PLUGIN_PATH at.
set_target_properties(swiperemap PROPERTIES
    PREFIX ""
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/pluginroot/kwin/effects/plugins")

# KWIN_EFFECT_FACTORY expands to a class with Q_OBJECT and Q_PLUGIN_METADATA,
# but AUTOMOC only sees the text of the macro: without these hints it refuses to
# run and does not rebuild moc when metadata.json changes.
set_property(TARGET swiperemap APPEND PROPERTY AUTOMOC_MACRO_NAMES "KWIN_EFFECT_FACTORY")
set_property(TARGET swiperemap APPEND PROPERTY AUTOGEN_TARGET_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/metadata.json")

target_link_libraries(swiperemap PRIVATE
    KWin::kwin
    Qt6::Core
    Qt6::Gui
    KF6::CoreAddons)

# Not KDE_INSTALL_PLUGINDIR: KWin only scans the Qt plugin directory.
install(TARGETS swiperemap DESTINATION ${QT6_INSTALL_PLUGINS}/kwin/effects/plugins)
