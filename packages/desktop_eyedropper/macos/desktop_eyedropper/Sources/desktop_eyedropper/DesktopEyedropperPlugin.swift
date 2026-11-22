import Cocoa
import FlutterMacOS

/// Picks screen colors with the system `NSColorSampler` loupe.
///
/// `NSColorSampler` is Apple's own eyedropper: it shows the native magnifier,
/// needs no Screen Recording permission and works inside the App Sandbox.
public class DesktopEyedropperPlugin: NSObject, FlutterPlugin {
  private let registrar: FlutterPluginRegistrar
  private var activeSampler: NSColorSampler?

  init(registrar: FlutterPluginRegistrar) {
    self.registrar = registrar
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "desktop_eyedropper",
      binaryMessenger: registrar.messenger)
    let instance = DesktopEyedropperPlugin(registrar: registrar)
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "pickColor":
      let args = call.arguments as? [String: Any]
      let hideWindow = args?["hideWindow"] as? Bool ?? true
      pickColor(hideWindow: hideWindow, result: result)
    case "setWindowVisible":
      // Window hiding is handled inside pickColor on macOS.
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func pickColor(hideWindow: Bool, result: @escaping FlutterResult) {
    guard #available(macOS 10.15, *) else {
      result(
        FlutterError(
          code: "unsupported",
          message: "Screen color picking requires macOS 10.15 or later.",
          details: nil))
      return
    }
    guard activeSampler == nil else {
      result(FlutterError(code: "busy", message: "A color pick is already running.", details: nil))
      return
    }

    // Fade the window out instead of ordering it out so the app stays active
    // and keyboard focus returns naturally afterwards.
    let window = registrar.view?.window
    let previousAlpha = window?.alphaValue ?? 1
    if hideWindow {
      window?.alphaValue = 0
    }

    let sampler = NSColorSampler()
    activeSampler = sampler
    sampler.show { [weak self] selected in
      DispatchQueue.main.async {
        self?.activeSampler = nil
        if hideWindow, let window = window {
          window.alphaValue = previousAlpha
          window.makeKeyAndOrderFront(nil)
          NSApp.activate(ignoringOtherApps: true)
        }
        guard let srgb = selected?.usingColorSpace(.sRGB) else {
          result(nil)  // Cancelled with Esc.
          return
        }
        func channel(_ value: CGFloat) -> Int {
          return max(0, min(255, Int((value * 255).rounded())))
        }
        let rgb =
          (channel(srgb.redComponent) << 16) | (channel(srgb.greenComponent) << 8)
          | channel(srgb.blueComponent)
        result(rgb)
      }
    }
  }
}
