import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, UIDocumentPickerDelegate {
  private var qrChannel: FlutterMethodChannel?
  private var exportResult: FlutterResult?
  private var exportFile: URL?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "QrStudioExport")!
    let channel = FlutterMethodChannel(
      name: "com.dinecircle.partnerapp/qr_studio", binaryMessenger: registrar.messenger())
    qrChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      guard call.method == "export" else { result(FlutterMethodNotImplemented); return }
      self.export(call, result: result)
    }
  }

  private func export(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard exportResult == nil else {
      result(FlutterError(code: "busy", message: "An export is already open.", details: nil)); return
    }
    guard let args = call.arguments as? [String: Any],
          let png = args["png"] as? FlutterStandardTypedData,
          png.data.count <= 32 * 1024 * 1024,
          let image = UIImage(data: png.data) else {
      result(FlutterError(code: "invalid", message: "Invalid card image.", details: nil)); return
    }
    guard let presenter = topViewController(), presenter.presentedViewController == nil else {
      result(FlutterError(code: "unavailable", message: "Close the current sheet and try again.", details: nil)); return
    }
    let pdf = args["pdf"] as? Bool == true
    let share = args["share"] as? Bool == true
    let stem = String((args["filename"] as? String ?? "dinecircle-qr")
      .filter { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }.prefix(100))
    exportResult = result
    do {
      let directory = FileManager.default.temporaryDirectory.appendingPathComponent("qr_studio", isDirectory: true)
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      // Keep shared URLs available for recipients; remove only yesterday's files.
      if let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey]) {
        for file in files {
          if let modified = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
             Date().timeIntervalSince(modified) > 86400 { try? FileManager.default.removeItem(at: file) }
        }
      }
      let folder = directory.appendingPathComponent(UUID().uuidString, isDirectory: true)
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      let file = folder.appendingPathComponent("\(stem).\(pdf ? "pdf" : "png")")
      let bytes = pdf ? makePDF(image) : png.data
      try bytes.write(to: file, options: .atomic)
      exportFile = file
      if share {
        let sheet = UIActivityViewController(activityItems: [file], applicationActivities: nil)
        // Required on iPad: anchor inside the presenting view's coordinate space.
        sheet.popoverPresentationController?.sourceView = presenter.view
        sheet.popoverPresentationController?.sourceRect = CGRect(
          x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 1, height: 1)
        sheet.popoverPresentationController?.permittedArrowDirections = []
        sheet.completionWithItemsHandler = { [weak self] _, completed, _, error in
          if let error = error { self?.finish(error: error) }
          else { self?.finish(outcome: completed ? "shared" : nil) }
        }
        presenter.present(sheet, animated: true)
      } else {
        let picker = UIDocumentPickerViewController(forExporting: [file], asCopy: true)
        picker.delegate = self
        picker.shouldShowFileExtensions = true
        presenter.present(picker, animated: true)
      }
    } catch { finish(error: error) }
  }

  private func makePDF(_ image: UIImage) -> Data {
    let mm: CGFloat = 72 / 25.4
    let width = 105 * mm
    let margin = 5 * mm
    let contentWidth = width - 2 * margin
    let contentHeight = contentWidth * image.size.height / image.size.width
    let bounds = CGRect(x: 0, y: 0, width: width, height: max(148 * mm, contentHeight + 2 * margin))
    return UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
      context.beginPage()
      UIColor.white.setFill()
      context.cgContext.fill(bounds)
      context.cgContext.interpolationQuality = .none
      image.draw(in: CGRect(x: margin, y: margin, width: contentWidth, height: contentHeight))
    }
  }

  private func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    var controller = scenes.flatMap { $0.windows }.first(where: { $0.isKeyWindow })?.rootViewController
    while let presented = controller?.presentedViewController { controller = presented }
    return controller
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    finish(outcome: urls.isEmpty ? nil : "saved")
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { finish() }

  private func finish(outcome: String? = nil, error: Error? = nil) {
    let result = exportResult
    exportResult = nil
    exportFile = nil
    if let error = error {
      result?(FlutterError(code: "export_failed", message: error.localizedDescription, details: nil))
    } else { result?(outcome) }
  }
}
