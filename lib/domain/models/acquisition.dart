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

final class CapturedEvidence {
  const CapturedEvidence({
    required this.name,
    required this.localPath,
    required this.byteLength,
    required this.sha256,
    required this.createdAt,
  });

  final String name;
  final String localPath;
  final int byteLength;
  final String sha256;
  final DateTime createdAt;
}
