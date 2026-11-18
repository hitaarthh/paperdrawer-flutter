import Flutter
import ImageIO
import PDFKit
import Security
import UIKit
import Vision
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // flutter_local_notifications: show reminders and receive taps.
    UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()
    registerStorageChannel(messenger)
    registerTextChannel(messenger)
    registerAccountChannel(messenger)
  }

  private func registerAccountChannel(_ messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "app.paperdrawer.mobile/account", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard let args = call.arguments as? [String: Any], let account = args["account"] as? String else {
        result(FlutterError(code: "invalid_account", message: nil, details: nil))
        return
      }
      let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "app.paperdrawer.mobile.supabase",
        kSecAttrAccount as String: account,
      ]
      var status: OSStatus
      switch call.method {
      case "read":
        var search = query
        search[kSecReturnData as String] = true
        search[kSecMatchLimit as String] = kSecMatchLimitOne
        var value: CFTypeRef?
        status = SecItemCopyMatching(search as CFDictionary, &value)
        if status == errSecSuccess || status == errSecItemNotFound {
          result((value as? Data).flatMap { String(data: $0, encoding: .utf8) })
          return
        }
      case "write":
        guard let value = args["value"] as? String else {
          result(FlutterError(code: "invalid_session", message: nil, details: nil))
          return
        }
        let attributes: [String: Any] = [kSecValueData as String: Data(value.utf8)]
        status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
          var item = query.merging(attributes) { _, value in value }
          item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
          status = SecItemAdd(item as CFDictionary, nil)
        }
      case "remove":
        status = SecItemDelete(query as CFDictionary)
        if status == errSecItemNotFound { status = errSecSuccess }
      default:
        result(FlutterMethodNotImplemented)
        return
      }
      result(status == errSecSuccess ? nil : FlutterError(
        code: "account_storage_failed", message: "Couldn’t access the device Keychain.", details: nil
      ))
    }
  }

  // MARK: - Private storage

  private func registerStorageChannel(_ messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "app.paperdrawer.mobile/storage",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "excludeFromBackup" else {
        result(FlutterMethodNotImplemented)
        return
      }

      do {
        let support = try FileManager.default.url(
          for: .applicationSupportDirectory,
          in: .userDomainMask,
          appropriateFor: nil,
          create: true
        )
        var vault = support.appendingPathComponent("paperdrawer", isDirectory: true)
        try FileManager.default.createDirectory(at: vault, withIntermediateDirectories: true)
        var settings = URLResourceValues()
        settings.isExcludedFromBackup = true
        try vault.setResourceValues(settings)
        result(nil)
      } catch {
        result(FlutterError(
          code: "local_storage_setup_failed",
          message: "The vault could not be kept out of device backups.",
          details: nil
        ))
      }
    }
  }

  // MARK: - On-device text recognition (Apple Vision)

  private let textQueue = DispatchQueue(label: "app.paperdrawer.text", qos: .userInitiated)

  private func registerTextChannel(_ messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "app.paperdrawer.mobile/text",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "recognize" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard
        let args = call.arguments as? [String: Any],
        let path = args["path"] as? String,
        !path.isEmpty
      else {
        result(FlutterError(code: "bad_args", message: "Expected {path: String}.", details: nil))
        return
      }
      self?.textQueue.async {
        let lines = TextReader.lines(atPath: path)
        DispatchQueue.main.async { result(lines) }
      }
    }
  }
}

/// Reads printed text from a photo or the first pages of a PDF. Everything
/// runs on the device; nothing leaves the phone.
enum TextReader {
  static func lines(atPath path: String) -> [String] {
    let url = URL(fileURLWithPath: path)
    var images: [(CGImage, CGImagePropertyOrientation)] = []
    if url.pathExtension.lowercased() == "pdf" {
      images = pdfPages(url).map { ($0, .up) }
    } else if let image = photo(url) {
      images = [image]
    }
    var lines: [String] = []
    for (image, orientation) in images {
      lines.append(contentsOf: recognize(image, orientation: orientation))
    }
    return lines
  }

  private static func photo(_ url: URL) -> (CGImage, CGImagePropertyOrientation)? {
    guard
      let source = CGImageSourceCreateWithURL(url as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { return nil }
    var orientation = CGImagePropertyOrientation.up
    if
      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
      let raw = properties[kCGImagePropertyOrientation] as? UInt32,
      let parsed = CGImagePropertyOrientation(rawValue: raw)
    {
      orientation = parsed
    }
    return (image, orientation)
  }

  private static func pdfPages(_ url: URL) -> [CGImage] {
    guard let document = PDFDocument(url: url) else { return [] }
    var pages: [CGImage] = []
    for index in 0..<min(document.pageCount, 3) {
      guard let page = document.page(at: index) else { continue }
      let bounds = page.bounds(for: .mediaBox)
      let scale: CGFloat = 2
      let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
      guard size.width > 0, size.height > 0 else { continue }
      let format = UIGraphicsImageRendererFormat()
      format.scale = 1
      let rendered = UIGraphicsImageRenderer(size: size, format: format).image { context in
        UIColor.white.setFill()
        context.fill(CGRect(origin: .zero, size: size))
        let cg = context.cgContext
        cg.translateBy(x: 0, y: size.height)
        cg.scaleBy(x: scale, y: -scale)
        page.draw(with: .mediaBox, to: cg)
      }
      if let image = rendered.cgImage { pages.append(image) }
    }
    return pages
  }

  private static func recognize(
    _ image: CGImage,
    orientation: CGImagePropertyOrientation
  ) -> [String] {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    let wanted = ["en-IN", "en-US"]
    if let supported = try? request.supportedRecognitionLanguages() {
      let languages = wanted.filter { supported.contains($0) }
      request.recognitionLanguages = languages.isEmpty ? ["en-US"] : languages
    }
    let handler = VNImageRequestHandler(cgImage: image, orientation: orientation, options: [:])
    do {
      try handler.perform([request])
    } catch {
      return []
    }
    let pieces: [(box: CGRect, text: String)] = (request.results ?? []).compactMap { observation in
      guard
        let text = observation.topCandidates(1).first?.string
          .trimmingCharacters(in: .whitespacesAndNewlines),
        !text.isEmpty
      else { return nil }
      return (observation.boundingBox, text)
    }
    // Top to bottom (Vision's origin is bottom left), then join pieces that
    // sit on the same printed row, so "Grand Total" and "₹2,999" stay together.
    let sorted = pieces.sorted { $0.box.midY > $1.box.midY }
    var rows: [[(box: CGRect, text: String)]] = []
    for piece in sorted {
      if
        let last = rows.last?.first,
        abs(last.box.midY - piece.box.midY) < max(last.box.height, piece.box.height) * 0.5
      {
        rows[rows.count - 1].append(piece)
      } else {
        rows.append([piece])
      }
    }
    return rows.map { row in
      row.sorted { $0.box.minX < $1.box.minX }.map(\.text).joined(separator: "  ")
    }
  }
}
