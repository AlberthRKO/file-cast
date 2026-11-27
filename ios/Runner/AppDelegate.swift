import AVFoundation
import Flutter
import Photos
import PhotosUI
import UIKit
import UniformTypeIdentifiers
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    WorkmanagerPlugin.registerLaunchHandlers()
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "EvidenceVideoThumbnailPlugin"
    ) {
      EvidenceVideoThumbnailPlugin.register(with: registrar)
    } else {
      NSLog("EvidenceVideoThumbnailPlugin: no se obtuvo el registrador Flutter")
    }
    if let photoRegistrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "EvidencePhotoLibraryPickerPlugin"
    ) {
      EvidencePhotoLibraryPickerPlugin.register(with: photoRegistrar)
    }
  }
}

final class EvidencePhotoLibraryPickerPlugin: NSObject, FlutterPlugin, PHPickerViewControllerDelegate {
  private static let channelName = "com.fiscalia.file_cast/evidence_photo_library"
  private weak var viewController: UIViewController?
  private var pendingResult: FlutterResult?

  init(viewController: UIViewController?) {
    self.viewController = viewController
    super.init()
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
    let instance = EvidencePhotoLibraryPickerPlugin(viewController: registrar.viewController)
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "getInspectorDeviceName" {
      var system = utsname()
      uname(&system)
      let identifier = withUnsafePointer(to: &system.machine) {
        $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
      }
      result("\(UIDevice.current.model) (\(identifier))")
      return
    }
    guard call.method == "pickMedia" else {
      result(FlutterMethodNotImplemented)
      return
    }
    let presenter = viewController ?? UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first(where: { $0.activationState == .foregroundActive })?
      .windows.first(where: { $0.isKeyWindow })?.rootViewController
    guard pendingResult == nil, let presenter, presenter.presentedViewController == nil else {
      result(FlutterError(code: "PICKER_BUSY", message: "La fototeca ya está abierta.", details: nil))
      return
    }

    var configuration = PHPickerConfiguration(photoLibrary: .shared())
    configuration.filter = .any(of: [.images, .videos])
    configuration.selectionLimit = 0
    configuration.preferredAssetRepresentationMode = .current
    let picker = PHPickerViewController(configuration: configuration)
    picker.delegate = self
    pendingResult = result
    presenter.present(picker, animated: true)
  }

  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    picker.dismiss(animated: true) { [self] in
      if results.isEmpty {
        finish([])
        return
      }
      copySelectedMedia(results)
    }
  }

  private func copySelectedMedia(_ selections: [PHPickerResult]) {
    let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
      .appendingPathComponent(".file_cast_evidence_imports", isDirectory: true)
    do {
      try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true,
        attributes: nil
      )
    } catch {
      finish(FlutterError(code: "PICKER_STORAGE", message: "No se pudo preparar el almacenamiento.", details: nil))
      return
    }

    let group = DispatchGroup()
    var copied = Array<[String: Any]?>(repeating: nil, count: selections.count)
    var failed = false
    for (index, selection) in selections.enumerated() {
      let provider = selection.itemProvider
      guard let typeIdentifier = provider.registeredTypeIdentifiers.first(where: {
        guard let type = UTType($0) else { return false }
        return type.conforms(to: .image) || type.conforms(to: .movie)
      }) else {
        failed = true
        continue
      }
      let assetName = originalName(for: selection) ?? provider.suggestedName
      let assetDates = photoLibraryDates(for: selection)
      group.enter()
      provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { temporary, error in
        var item: [String: Any]?
        if let temporary, error == nil {
          let temporaryExtension = temporary.pathExtension
          let proposedExtension = assetName.map {
            URL(fileURLWithPath: $0).pathExtension
          } ?? ""
          let fileExtension: String
          if !temporaryExtension.isEmpty && temporaryExtension.lowercased() != "tmp" {
            fileExtension = temporaryExtension
          } else if let typeExtension = UTType(typeIdentifier)?.preferredFilenameExtension {
            fileExtension = typeExtension
          } else {
            fileExtension = proposedExtension.isEmpty ? "bin" : proposedExtension
          }
          let destination = directory.appendingPathComponent(
            "\(UUID().uuidString).\(fileExtension)",
            isDirectory: false
          )
          do {
            try FileManager.default.copyItem(at: temporary, to: destination)
            let attributes = try FileManager.default.attributesOfItem(atPath: destination.path)
            let byteLength = (attributes[.size] as? NSNumber)?.intValue ?? 0
            guard byteLength > 0 else { throw NSError(domain: "EvidencePicker", code: 1) }
            item = [
              "name": self.displayName(assetName, fileExtension: fileExtension),
              "path": destination.path,
              "size": byteLength,
            ]
            if let registeredAt = assetDates.registeredAt {
              item?["registeredOnDeviceAtMilliseconds"] = Int64(registeredAt.timeIntervalSince1970 * 1000)
            }
            if let capturedAt = assetDates.capturedAt {
              item?["contentCapturedAtMilliseconds"] = Int64(capturedAt.timeIntervalSince1970 * 1000)
            }
          } catch {
            try? FileManager.default.removeItem(at: destination)
          }
        }
        DispatchQueue.main.async {
          if let item {
            copied[index] = item
          } else {
            failed = true
          }
          group.leave()
        }
      }
    }

    group.notify(queue: .main) { [self] in
      guard !failed, copied.allSatisfy({ $0 != nil }) else {
        for item in copied {
          if let path = item?["path"] as? String {
            try? FileManager.default.removeItem(atPath: path)
          }
        }
        finish(FlutterError(
          code: "PICKER_IMPORT",
          message: "No se pudieron preparar todas las fotos y videos seleccionados.",
          details: nil
        ))
        return
      }
      finish(copied.compactMap { $0 })
    }
  }

  private func originalName(for selection: PHPickerResult) -> String? {
    let authorization = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    guard authorization == .authorized || authorization == .limited,
      let identifier = selection.assetIdentifier,
      let asset = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject
    else {
      return nil
    }
    let filename = PHAssetResource.assetResources(for: asset).first(where: {
      $0.type == .photo || $0.type == .video || $0.type == .fullSizePhoto || $0.type == .fullSizeVideo
    })?.originalFilename
    return filename?.isEmpty == false ? filename : nil
  }

  private func photoLibraryDates(for selection: PHPickerResult) -> (registeredAt: Date?, capturedAt: Date?) {
    let authorization = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    guard authorization == .authorized || authorization == .limited,
      let identifier = selection.assetIdentifier,
      let asset = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject
    else { return (nil, nil) }
    let registeredAt: Date?
    if #available(iOS 26.0, *) {
      registeredAt = asset.addedDate
    } else {
      registeredAt = nil
    }
    return (registeredAt, asset.creationDate)
  }

  private func displayName(_ proposedName: String?, fileExtension: String) -> String {
    guard let proposedName else {
      return "Archivo.\(fileExtension)"
    }
    let normalized = proposedName.replacingOccurrences(of: "\\", with: "/")
    let filename = normalized.components(separatedBy: "/").last?
      .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    guard !filename.isEmpty else { return "Archivo.\(fileExtension)" }
    let originalExtension = URL(fileURLWithPath: filename).pathExtension
    if originalExtension.isEmpty { return "\(filename).\(fileExtension)" }
    let originalType = originalExtension.lowercased()
    let copiedType = fileExtension.lowercased()
    if originalType == copiedType ||
      (["jpg", "jpeg"].contains(originalType) && ["jpg", "jpeg"].contains(copiedType)) ||
      (["tif", "tiff"].contains(originalType) && ["tif", "tiff"].contains(copiedType)) {
      return filename
    }
    let stem = URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
    return "\(stem).\(fileExtension)"
  }

  private func finish(_ value: Any) {
    let result = pendingResult
    pendingResult = nil
    result?(value)
  }
}

final class EvidenceVideoThumbnailPlugin: NSObject, FlutterPlugin {
  private static let channelName = "com.fiscalia.file_cast/evidence_video_thumbnail"
  private let workQueue = DispatchQueue(
    label: "com.fiscalia.file_cast.evidence_video_thumbnail",
    qos: .utility
  )

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )
    let instance = EvidenceVideoThumbnailPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let arguments = call.arguments as? [String: Any] else {
      result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
      return
    }

    guard let cacheKey = arguments["cacheKey"] as? String, !cacheKey.isEmpty else {
      result(FlutterError(code: "INVALID_ARGS", message: "cacheKey is required", details: nil))
      return
    }

    switch call.method {
    case "findCachedThumbnail":
      let cachedFile = cacheFile(for: cacheKey)
      if hasContent(cachedFile) {
        result(["path": cachedFile.path])
      } else {
        result(["path": NSNull()])
      }

    case "createThumbnail":
      guard let sourcePath = arguments["path"] as? String, !sourcePath.isEmpty else {
        result(FlutterError(code: "INVALID_ARGS", message: "path is required", details: nil))
        return
      }
      workQueue.async { [self] in
        do {
          let source = URL(fileURLWithPath: sourcePath)
          let destination = self.cacheFile(for: cacheKey)
          if !self.hasContent(destination) {
            try self.writeThumbnail(from: source, to: destination)
          }
          DispatchQueue.main.async {
            result(["path": destination.path])
          }
        } catch {
          DispatchQueue.main.async {
            result(
              FlutterError(
                code: "VIDEO_THUMBNAIL_ERROR",
                message: "No se pudo crear la miniatura del video",
                details: nil
              )
            )
          }
        }
      }

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func cacheFile(for key: String) -> URL {
    let cacheRoot = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    let directory = cacheRoot.appendingPathComponent("evidence_video_thumbnails", isDirectory: true)
    return directory.appendingPathComponent("\(key).jpg", isDirectory: false)
  }

  private func hasContent(_ file: URL) -> Bool {
    guard
      let attributes = try? FileManager.default.attributesOfItem(atPath: file.path),
      let size = attributes[.size] as? NSNumber
    else {
      return false
    }
    return size.intValue > 0
  }

  private func writeThumbnail(from source: URL, to destination: URL) throws {
    guard hasContent(source) else {
      throw NSError(domain: "EvidenceVideoThumbnail", code: 1)
    }

    let asset = AVURLAsset(url: source)
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = CGSize(width: 480, height: 480)

    let duration = CMTimeGetSeconds(asset.duration)
    let candidates: [Double]
    if duration.isFinite, duration > 0 {
      candidates = [min(1.0, duration / 4.0), duration / 2.0, duration * 0.75, 0]
    } else {
      candidates = [0, 0.15, 0.5, 1.0]
    }

    var thumbnail: CGImage?
    var attemptedTimes = Set<Int64>()
    for seconds in candidates {
      let time = CMTime(seconds: max(0, seconds), preferredTimescale: 600)
      guard attemptedTimes.insert(time.value).inserted else { continue }
      if let frame = try? generator.copyCGImage(at: time, actualTime: nil) {
        thumbnail = frame
        break
      }
    }

    guard
      let thumbnail,
      let jpeg = UIImage(cgImage: thumbnail).jpegData(compressionQuality: 0.82)
    else {
      throw NSError(domain: "EvidenceVideoThumbnail", code: 2)
    }

    let directory = destination.deletingLastPathComponent()
    try FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true,
      attributes: nil
    )
    try jpeg.write(to: destination, options: .atomic)
  }
}
