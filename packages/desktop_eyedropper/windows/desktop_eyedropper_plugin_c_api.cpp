#include "include/desktop_eyedropper/desktop_eyedropper_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "desktop_eyedropper_plugin.h"

void DesktopEyedropperPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  desktop_eyedropper::DesktopEyedropperPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
