#ifndef FLUTTER_PLUGIN_DESKTOP_EYEDROPPER_PLUGIN_H_
#define FLUTTER_PLUGIN_DESKTOP_EYEDROPPER_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace desktop_eyedropper {

class PickSession;

class DesktopEyedropperPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  explicit DesktopEyedropperPlugin(flutter::PluginRegistrarWindows* registrar);
  ~DesktopEyedropperPlugin() override;

  DesktopEyedropperPlugin(const DesktopEyedropperPlugin&) = delete;
  DesktopEyedropperPlugin& operator=(const DesktopEyedropperPlugin&) = delete;

  // Called by a PickSession when it finishes (it deletes itself afterwards).
  void OnSessionFinished();

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  HWND GetTopLevelWindow() const;

  flutter::PluginRegistrarWindows* registrar_;
  PickSession* session_ = nullptr;
};

}  // namespace desktop_eyedropper

#endif  // FLUTTER_PLUGIN_DESKTOP_EYEDROPPER_PLUGIN_H_
