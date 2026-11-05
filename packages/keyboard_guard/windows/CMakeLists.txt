cmake_minimum_required(VERSION 3.14)
project(keyboard_guard LANGUAGES CXX)
cmake_policy(VERSION 3.14...3.25)
set(PLUGIN_NAME "keyboard_guard_plugin")
add_library(${PLUGIN_NAME} SHARED
  "include/keyboard_guard/keyboard_guard_plugin_c_api.h"
  "keyboard_guard_plugin_c_api.cpp"
  "keyboard_guard_plugin.cpp"
  "keyboard_guard_plugin.h"
  "keyboard_guard_engine.cpp"
  "keyboard_guard_engine.h"
)
apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_include_directories(${PLUGIN_NAME} INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin user32 wtsapi32)
set(keyboard_guard_bundled_libraries "" PARENT_SCOPE)
