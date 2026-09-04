import 'package:file_cast/domain/models/acquisition.dart';
import 'package:file_cast/domain/models/requisition_detail.dart';

abstract interface class AcquisitionRepository {
  Stream<void> get deviceChanges;

  Future<AcquisitionAvailability> getAvailability();
  Future<List<AcquisitionDevice>> getDevices();
  Future<bool?> requestPermission(String deviceId);
  Future<AcquisitionMirrorSession> connectAndStart({
    required AcquisitionDevice device,
    required String requisitionId,
    required String sessionId,
  });
  Future<AcquisitionMirrorSession?> activeSession({
    required String requisitionId,
    required String sessionId,
  });
  Future<RequisitionDetail> getRequisitionDetail(String requisitionId);
  Future<RequisitionDetail> captureScreenshot({
    required String requisitionId,
    required String sessionId,
  });
  Future<RequisitionDetail> startRecording({
    required String requisitionId,
    required String sessionId,
  });
  Future<RequisitionDetail> stopRecording({
    required String requisitionId,
    required String sessionId,
  });
  Future<void> disconnect();
  Future<void> sendTouch(int action, int pointerId, int x, int y);
  Future<void> sendScroll(int x, int y, int deltaY);
  Future<String> getControlDiagnostics();
  Future<void> sendBack();
  Future<void> sendHome();
  Future<void> sendAppSwitch();
}
