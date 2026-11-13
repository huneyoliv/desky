import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  /// No macOS o duplo clique num PDF nao chega como argumento de linha de comando:
  /// o Launch Services entrega um Apple Event. Este handler repassa o caminho pelo
  /// MethodChannel para o Dart abrir o leitor, e o Launch Services ja garante que
  /// nao exista uma segunda copia do app aberta.
  private var documentChannel: FlutterMethodChannel?
  private var pendingPaths: [String] = []

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    // A janela (e o FlutterViewController) pode ainda nao existir neste ponto.
    DispatchQueue.main.async { [weak self] in
      self?.flushPendingPaths()
    }
  }

  override func application(_ sender: NSApplication, openFile filename: String) -> Bool {
    deliver(path: filename)
    return true
  }

  override func application(_ sender: NSApplication, openFiles filenames: [String]) {
    for filename in filenames {
      deliver(path: filename)
    }
    sender.reply(toOpenOrPrint: .success)
  }

  private func activeFlutterViewController() -> FlutterViewController? {
    for window in NSApplication.shared.windows {
      if let controller = window.contentViewController as? FlutterViewController {
        return controller
      }
    }
    return nil
  }

  private func ensureChannel() -> FlutterMethodChannel? {
    if let channel = documentChannel {
      return channel
    }
    guard let controller = activeFlutterViewController() else {
      return nil
    }
    let channel = FlutterMethodChannel(
      name: "dev.desky/documents",
      binaryMessenger: controller.engine.binaryMessenger
    )
    documentChannel = channel
    return channel
  }

  private func deliver(path: String) {
    guard let channel = ensureChannel() else {
      pendingPaths.append(path)
      return
    }
    channel.invokeMethod("openPdf", arguments: path)
  }

  private func flushPendingPaths() {
    guard !pendingPaths.isEmpty, let channel = ensureChannel() else {
      return
    }
    let paths = pendingPaths
    pendingPaths.removeAll()
    for path in paths {
      channel.invokeMethod("openPdf", arguments: path)
    }
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}