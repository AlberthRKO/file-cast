import 'package:file_cast/data/services/android_acquisition_platform_service.dart';
import 'package:file_cast/domain/models/acquisition.dart';
import 'package:file_cast/domain/models/requisition_detail.dart';
import 'package:file_cast/domain/repositories/acquisition_repository.dart';
import 'package:file_cast/domain/repositories/requisition_detail_repository.dart';

class AcquisitionRepositoryImpl implements AcquisitionRepository {
  AcquisitionRepositoryImpl({
    required AndroidAcquisitionPlatformService platformService,
    required RequisitionDetailRepository detailRepository,
  }) : _platformService = platformService,
       _detailRepository = detailRepository;

  final AndroidAcquisitionPlatformService _platformService;
  final RequisitionDetailRepository _detailRepository;

  @override
  Stream<void> get deviceChanges => _platformService.deviceChanges;

  @override
  Future<AcquisitionAvailability> getAvailability() =>
      _platformService.getAvailability();

  @override
  Future<List<AcquisitionDevice>> getDevices() => _platformService.getDevices();

  @override
  Future<bool?> requestPermission(String deviceId) =>
      _platformService.requestPermission(deviceId);

  @override
  Future<AcquisitionMirrorSession> connectAndStart({
    required AcquisitionDevice device,
    required String requisitionId,
    required String sessionId,
  }) => _platformService.connectAndStart(
    device: device,
    requisitionId: requisitionId,
    sessionId: sessionId,
  );

  @override
  Future<AcquisitionMirrorSession?> activeSession({
    required String requisitionId,
    required String sessionId,
  }) => _platformService.activeSession(
    requisitionId: requisitionId,
    sessionId: sessionId,
  );

  @override
  Future<RequisitionDetail> getRequisitionDetail(String requisitionId) =>
      _detailRepository.getDetail(requisitionId);

  @override
  Future<RequisitionDetail> captureScreenshot({
    required String requisitionId,
    required String sessionId,
  }) async {
    final captured = await _platformService.captureScreenshot(
      requisitionId: requisitionId,
      sessionId: sessionId,
    );
    return _register(
      requisitionId: requisitionId,
      captured: captured,
      type: RequisitionEvidenceType.image,
    );
  }

  @override
  Future<RequisitionDetail> startRecording({
    required String requisitionId,
    required String sessionId,
  }) async {
    await _platformService.startRecording(
      requisitionId: requisitionId,
      sessionId: sessionId,
    );
    return _detailRepository.getDetail(requisitionId);
  }

  @override
  Future<RequisitionDetail> stopRecording({
    required String requisitionId,
    required String sessionId,
  }) async {
    final captured = await _platformService.stopRecording();
    return _register(
      requisitionId: requisitionId,
      captured: captured,
      type: RequisitionEvidenceType.video,
    );
  }

  Future<RequisitionDetail> _register({
    required String requisitionId,
    required CapturedEvidence captured,
    required RequisitionEvidenceType type,
  }) {
    return _detailRepository.addImportedEvidence(
      requisitionId: requisitionId,
      name: captured.name,
      type: type,
      sizeLabel: _formatSize(captured.byteLength),
      byteLength: captured.byteLength,
      localPath: captured.localPath,
      sha256: captured.sha256,
    );
  }

  String _formatSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).ceil()} KB';
  }

  @override
  Future<void> disconnect() => _platformService.disconnect();

  @override
  Future<void> sendTouch(int action, int pointerId, int x, int y) =>
      _platformService.sendTouch(action, pointerId, x, y);

  @override
  Future<void> sendScroll(int x, int y, int deltaY) =>
      _platformService.sendScroll(x, y, deltaY);

  @override
  Future<String> getControlDiagnostics() =>
      _platformService.getControlDiagnostics();

  @override
  Future<void> sendBack() => _platformService.sendBack();

  @override
  Future<void> sendHome() => _platformService.sendHome();

  @override
  Future<void> sendAppSwitch() => _platformService.sendAppSwitch();
}
