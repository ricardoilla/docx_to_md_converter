import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // Default window ~1100x700, minimum 800x500 (centered on first launch).
    self.contentMinSize = NSSize(width: 800, height: 500)
    self.setContentSize(NSSize(width: 1100, height: 700))
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
