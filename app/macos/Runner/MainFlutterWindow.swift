import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    self.title = "Color Contrast Checker"
    self.minSize = NSSize(width: 760, height: 600)
    self.setContentSize(NSSize(width: 1280, height: 860))
    self.center()
    self.setFrameAutosaveName("MainWindow")

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
