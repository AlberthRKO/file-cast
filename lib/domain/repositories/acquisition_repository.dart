import 'package:file_cast/domain/models/acquisition.dart';
import 'package:file_cast/domain/models/requisition_detail.dart';

typedef RemoteFilePreview = ({String localPath, String? documentText});

abstract interface class AcquisitionRepository {
  Stream<void> get deviceChanges;
  Stream<String> get evidenceChanges;

  Future<AcquisitionAvailability> getAvailability();
  Future<List<AcquisitionDevice>> getDevices();
  Future<bool?> requestPermission(String deviceId);
  Future<AcquisitionMirrorSession> connectAndStart({
    required AcquisitionDevice device,
    required String requisitionId,
    required String sessionId,
  });
  Future<AcquisitionMultiMirrorSession> connectAndStartMulti({
    required List<AcquisitionDevice> devices,
    required String requisitionId,
    required String sessionId,
  });
  Future<List<AcquisitionMirrorSession>> activeMultiSessions({
    required String requisitionId,
    required String sessionId,
  });
  Future<AcquisitionMirrorSession> restartMirror();
  Future<AcquisitionMirrorSession> restartMultiMirrorSource(
    String sourceSessionId,
  );
  Future<void> disconnectMulti({String? sourceSessionId});
  Future<void> sendTouchToSource(
    String sourceSessionId,
    int action,
    int pointerId,
    int x,
    int y,
  );
  Future<void> sendScrollToSource(
    String sourceSessionId,
    int x,
    int y,
    int deltaY,
  );
  Future<void> sendKeyToSource(String sourceSessionId, int keycode);
  Future<RequisitionDetail> captureScreenshotForSource({
    required String sourceSessionId,
    required String requisitionId,
    required String sessionId,
    List<int> subjectPersonIds = const [],
  });
  Future<void> startRecordingForSource({
    required String sourceSessionId,
    required String requisitionId,
    required String sessionId,
  });
  Future<RequisitionDetail> stopRecordingForSource({
    required String sourceSessionId,
    required String requisitionId,
    required String sessionId,
    List<int> subjectPersonIds = const [],
  });
  Future<String> getMultiControlDiagnostics(String sourceSessionId);
  Future<AcquisitionConnectionSession> connectForTransfer({
    required AcquisitionDevice device,
    required String requisitionId,
    required String sessionId,
  });
  Future<AcquisitionConnectionSession?> activeConnection({
    required String requisitionId,
    required String sessionId,
  });
  Future<AcquisitionMirrorSession?> activeSession({
    required String requisitionId,
    required String sessionId,
  });
  int? subjectPersonIdForDevice({
    required String requisitionId,
    required String sessionId,
    required String deviceKey,
  });
  void setSubjectForDevice({
    required String requisitionId,
    required String sessionId,
    required String deviceKey,
    required int? personId,
  });
  Future<RequisitionDetail> getRequisitionDetail(String requisitionId);
  Future<RequisitionDetail> getCachedRequisitionDetail(String requisitionId);
  Future<RequisitionDetail> renameEvidence({
    required String requisitionId,
    required RequisitionEvidence evidence,
    required String displayName,
  });
  Future<RequisitionDetail> captureScreenshot({
    required String requisitionId,
    required String sessionId,
    List<int> subjectPersonIds = const [],
  });
  Future<void> startRecording({
    required String requisitionId,
    required String sessionId,
  });
  Future<RequisitionDetail> stopRecording({
    required String requisitionId,
    required String sessionId,
    List<int> subjectPersonIds = const [],
  });
  Stream<FileTransferProgress> get fileTransferProgress;
  Future<List<RemoteFileEntry>> listRemoteFiles(String remotePath);
  Future<RemoteFilePreview> prepareRemoteFilePreview({
    required String requisitionId,
    required String sessionId,
    required RemoteFileEntry file,
  });
  Future<void> discardRemoteFilePreview({
    required String requisitionId,
    required String sessionId,
  });
  Future<FileTransferResult> transferRemoteFiles({
    required String requisitionId,
    required String sessionId,
    required List<RemoteFileEntry> files,
    List<int> subjectPersonIds = const [],
  });
  Future<void> cancelFileTransfer();
  Future<void> disconnect();
  Future<void> sendTouch(int action, int pointerId, int x, int y);
  Future<void> sendScroll(int x, int y, int deltaY);
  Future<String> getConnectionDiagnostics();
  Future<String> getControlDiagnostics();
  Future<void> sendBack();
  Future<void> sendHome();
  Future<void> sendAppSwitch();
}
