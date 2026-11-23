import AVFoundation
import Flutter
import UIKit
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
    guard let registrar = engineBridge.pluginRegistry.registrar(
      forPlugin: "EvidenceVideoThumbnailPlugin"
    ) else {
      NSLog("EvidenceVideoThumbnailPlugin: no se obtuvo el registrador Flutter")
      return
    }
    EvidenceVideoThumbnailPlugin.register(with: registrar)
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
