#include "include/keyboard_guard/keyboard_guard_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "keyboard_guard_plugin.h"

void KeyboardGuardPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  keyboard_guard::KeyboardGuardPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
