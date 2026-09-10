import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let shareChannelName = "sinifcepte/incoming_share"
  private var pendingSharePath: String?
  private var shareChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let launched = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: shareChannelName,
        binaryMessenger: controller.binaryMessenger
      )
      shareChannel = channel
      channel.setMethodCallHandler { [weak self] call, result in
        if call.method == "takePending" {
          let path = self?.pendingSharePath
          self?.pendingSharePath = nil
          result(path)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }

    if let url = launchOptions?[.url] as? URL {
      captureIncomingFile(url)
    }
    return launched
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if url.isFileURL {
      captureIncomingFile(url)
      return true
    }
    return super.application(app, open: url, options: options)
  }

  private func captureIncomingFile(_ url: URL) {
    let accessed = url.startAccessingSecurityScopedResource()
    defer {
      if accessed {
        url.stopAccessingSecurityScopedResource()
      }
    }
    do {
      let name = url.lastPathComponent
      let dest = FileManager.default.temporaryDirectory
        .appendingPathComponent("incoming_share_\(name)")
      if FileManager.default.fileExists(atPath: dest.path) {
        try FileManager.default.removeItem(at: dest)
      }
      try FileManager.default.copyItem(at: url, to: dest)
      pendingSharePath = dest.path
      shareChannel?.invokeMethod("onSharedFile", arguments: dest.path)
    } catch {
      // Paylaşım kopyalanamazsa öğretmen yerel seçiciyi kullanır.
    }
  }
}
