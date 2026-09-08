enum AcquisitionAvailability { checking, available, unsupported }

enum AcquisitionConnectionPhase {
  loading,
  ready,
  requestingPermission,
  connecting,
  preparingMirror,
  connected,
  error,
}

enum AcquisitionRecordingPhase { idle, recording, saving }

enum AcquisitionDestination { mirror, transfer }

enum RemoteFileKind { directory, image, video, audio, document, other }

enum FileTransferPhase {
  idle,
  preparing,
  transferring,
  completed,
  cancelled,
  error,
}

final class AcquisitionDevice {
  const AcquisitionDevice({
    required this.id,
    required this.name,
    required this.hasPermission,
    required this.vendorId,
    required this.productId,
  });

  final String id;
  final String name;
  final bool hasPermission;
  final int vendorId;
  final int productId;
}

final class AcquisitionMirrorSession {
  const AcquisitionMirrorSession({
    required this.requisitionId,
    required this.sessionId,
    required this.deviceName,
    required this.textureId,
    required this.controlStreamId,
    required this.videoWidth,
    required this.videoHeight,
  });

  final String requisitionId;
  final String sessionId;
  final String deviceName;
  final int textureId;
  final int controlStreamId;
  final int videoWidth;
  final int videoHeight;
}

final class AcquisitionConnectionSession {
  const AcquisitionConnectionSession({
    required this.requisitionId,
    required this.sessionId,
    required this.deviceName,
  });

  final String requisitionId;
  final String sessionId;
  final String deviceName;
}

final class RemoteFileEntry {
  const RemoteFileEntry({
    required this.path,
    required this.name,
    required this.byteLength,
    required this.modifiedAt,
    required this.kind,
    required this.isSelectable,
  });

  final String path;
  final String name;
  final int byteLength;
  final DateTime modifiedAt;
  final RemoteFileKind kind;
  final bool isSelectable;

  bool get isDirectory => kind == RemoteFileKind.directory;
}

final class FileTransferProgress {
  const FileTransferProgress({
    required this.transferId,
    required this.phase,
    required this.fileIndex,
    required this.fileCount,
    required this.fileBytes,
    required this.fileTotalBytes,
    required this.batchBytes,
    required this.batchTotalBytes,
    this.fileName,
    this.message,
  });

  final String transferId;
  final FileTransferPhase phase;
  final String? fileName;
  final int fileIndex;
  final int fileCount;
  final int fileBytes;
  final int fileTotalBytes;
  final int batchBytes;
  final int batchTotalBytes;
  final String? message;

  double get fileFraction => fileTotalBytes <= 0
      ? 0
      : (fileBytes / fileTotalBytes).clamp(0, 1).toDouble();
  double get batchFraction => batchTotalBytes <= 0
      ? 0
      : (batchBytes / batchTotalBytes).clamp(0, 1).toDouble();
}

final class FileTransferFailure {
  const FileTransferFailure({required this.remotePath, required this.message});

  final String remotePath;
  final String message;
}

final class FileTransferResult {
  const FileTransferResult({
    required this.files,
    required this.failures,
    required this.cancelled,
  });

  final List<CapturedEvidence> files;
  final List<FileTransferFailure> failures;
  final bool cancelled;
}

final class CapturedEvidence {
  const CapturedEvidence({
    required this.name,
    required this.localPath,
    required this.byteLength,
    required this.sha256,
    required this.createdAt,
    this.sourcePath,
  });

  final String name;
  final String localPath;
  final int byteLength;
  final String sha256;
  final DateTime createdAt;
  final String? sourcePath;
}
