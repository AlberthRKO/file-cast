import 'dart:async';

import 'package:file_cast/data/services/android_acquisition_platform_service.dart';
import 'package:file_cast/data/services/evidence_sync_service.dart';
import 'package:file_cast/data/services/remote_document_preview_service.dart';
import 'package:file_cast/domain/models/acquisition.dart';
import 'package:file_cast/domain/models/requisition_detail.dart';
import 'package:file_cast/domain/repositories/acquisition_repository.dart';
import 'package:file_cast/domain/repositories/requisition_detail_repository.dart';

class AcquisitionRepositoryImpl implements AcquisitionRepository {
  AcquisitionRepositoryImpl({
    required AndroidAcquisitionPlatformService platformService,
    required RequisitionDetailRepository detailRepository,
    required RemoteDocumentPreviewService documentPreviewService,
    EvidenceSyncService? syncService,
  }) : _platformService = platformService,
       _detailRepository = detailRepository,
       _documentPreviewService = documentPreviewService,
       _syncService = syncService;

  final AndroidAcquisitionPlatformService _platformService;
  final RequisitionDetailRepository _detailRepository;
  final RemoteDocumentPreviewService _documentPreviewService;
  final EvidenceSyncService? _syncService;

  @override
  Stream<void> get deviceChanges => _platformService.deviceChanges;

  @override
  Stream<String> get evidenceChanges => _detailRepository.changes;

  @override
  Stream<FileTransferProgress> get fileTransferProgress =>
      _platformService.fileTransferProgress;

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
  Future<AcquisitionConnectionSession> connectForTransfer({
    required AcquisitionDevice device,
    required String requisitionId,
    required String sessionId,
  }) => _platformService.connectForTransfer(
    device: device,
    requisitionId: requisitionId,
    sessionId: sessionId,
  );

  @override
  Future<AcquisitionConnectionSession?> activeConnection({
    required String requisitionId,
    required String sessionId,
  }) => _platformService.activeConnection(
    requisitionId: requisitionId,
    sessionId: sessionId,
  );

  @override
  Future<RequisitionDetail> getRequisitionDetail(String requisitionId) =>
      _detailRepository.getDetail(requisitionId);

  @override
  Future<RequisitionDetail> getCachedRequisitionDetail(String requisitionId) =>
      _detailRepository.getCachedDetail(requisitionId);

  @override
  Future<RequisitionDetail> renameEvidence({
    required String requisitionId,
    required RequisitionEvidence evidence,
    required String displayName,
  }) => _detailRepository.renameEvidence(
    requisitionId: requisitionId,
    evidence: evidence,
    displayName: displayName,
  );

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
      sessionId: sessionId,
      captured: captured,
      type: RequisitionEvidenceType.image,
    );
  }

  @override
  Future<void> startRecording({
    required String requisitionId,
    required String sessionId,
  }) async {
    await _platformService.startRecording(
      requisitionId: requisitionId,
      sessionId: sessionId,
    );
  }

  @override
  Future<RequisitionDetail> stopRecording({
    required String requisitionId,
    required String sessionId,
  }) async {
    final captured = await _platformService.stopRecording();
    return _register(
      requisitionId: requisitionId,
      sessionId: sessionId,
      captured: captured,
      type: RequisitionEvidenceType.video,
    );
  }

  Future<RequisitionDetail> _register({
    required String requisitionId,
    required String sessionId,
    required CapturedEvidence captured,
    required RequisitionEvidenceType type,
  }) async {
    final detail = await _detailRepository.addImportedEvidence(
      requisitionId: requisitionId,
      name: captured.name,
      type: type,
      sizeLabel: _formatSize(captured.byteLength),
      byteLength: captured.byteLength,
      localPath: captured.localPath,
      sha256: captured.sha256,
      sourcePath: captured.sourcePath,
      sessionId: sessionId,
      mimeType: captured.mimeType ?? _mimeTypeFor(type, captured.name),
      acquisitionMethod: type == RequisitionEvidenceType.image
          ? 'SCREEN_CAPTURE'
          : 'SCREEN_RECORDING',
    );
    _triggerBackgroundSync();
    return detail;
  }

  void _triggerBackgroundSync() {
    final syncService = _syncService;
    if (syncService == null) return;
    unawaited(
      syncService.syncPendingInForeground().then<void>(
        (_) {},
        onError: (Object _, StackTrace __) {
          // La evidencia ya quedó cifrada y en la outbox. La sincronización se
          // reintentará por conectividad o WorkManager; no debe convertir un
          // guardado local exitoso en un error del flujo de captura.
        },
      ),
    );
  }

  @override
  Future<List<RemoteFileEntry>> listRemoteFiles(String remotePath) =>
      _platformService.listRemoteFiles(remotePath);

  @override
  Future<RemoteFilePreview> prepareRemoteFilePreview({
    required String requisitionId,
    required String sessionId,
    required RemoteFileEntry file,
  }) async {
    final localPath = await _platformService.prepareRemoteFilePreview(
      requisitionId: requisitionId,
      sessionId: sessionId,
      file: file,
    );
    try {
      final documentText = await _documentPreviewService.extractReadableText(
        localPath,
      );
      return (localPath: localPath, documentText: documentText);
    } catch (_) {
      await _platformService.discardRemoteFilePreview(
        requisitionId: requisitionId,
        sessionId: sessionId,
      );
      rethrow;
    }
  }

  @override
  Future<void> discardRemoteFilePreview({
    required String requisitionId,
    required String sessionId,
  }) => _platformService.discardRemoteFilePreview(
    requisitionId: requisitionId,
    sessionId: sessionId,
  );

  @override
  Future<FileTransferResult> transferRemoteFiles({
    required String requisitionId,
    required String sessionId,
    required List<RemoteFileEntry> files,
  }) async {
    final result = await _platformService.transferRemoteFiles(
      requisitionId: requisitionId,
      sessionId: sessionId,
      files: files,
    );
    if (result.files.isNotEmpty) {
      await _detailRepository.addImportedEvidenceBatch(
        requisitionId: requisitionId,
        evidence: result.files
            .map(
              (captured) => ImportedEvidenceDraft(
                name: captured.name,
                type: _evidenceType(captured.name),
                sizeLabel: _formatSize(captured.byteLength),
                byteLength: captured.byteLength,
                localPath: captured.localPath,
                sha256: captured.sha256,
                sourcePath: captured.sourcePath,
                sessionId: sessionId,
                mimeType: _mimeTypeFor(
                  _evidenceType(captured.name),
                  captured.name,
                ),
                acquisitionMethod: 'DEVICE_TRANSFER',
              ),
            )
            .toList(growable: false),
      );
    }
    _triggerBackgroundSync();
    return result;
  }

  @override
  Future<void> cancelFileTransfer() => _platformService.cancelFileTransfer();

  RequisitionEvidenceType _evidenceType(String name) {
    final extension = name.toLowerCase().split('.').last;
    if (const {
      'jpg',
      'jpeg',
      'png',
      'gif',
      'webp',
      'heic',
      'bmp',
    }.contains(extension)) {
      return RequisitionEvidenceType.image;
    }
    if (const {
      'mp4',
      'mkv',
      'mov',
      'avi',
      'webm',
      '3gp',
      'm4v',
      'ts',
      'mts',
      'm2ts',
      'flv',
      'wmv',
    }.contains(extension)) {
      return RequisitionEvidenceType.video;
    }
    if (const {
      'mp3',
      'wav',
      'aac',
      'm4a',
      'ogg',
      'oga',
      'opus',
      'flac',
      'amr',
    }.contains(extension)) {
      return RequisitionEvidenceType.audio;
    }
    if (const {
      'pdf',
      'doc',
      'docx',
      'xls',
      'xlsx',
      'ppt',
      'pptx',
      'txt',
      'csv',
      'json',
      'xml',
      'log',
    }.contains(extension)) {
      return RequisitionEvidenceType.document;
    }
    return RequisitionEvidenceType.other;
  }

  String _mimeTypeFor(RequisitionEvidenceType type, String name) {
    final extension = name.toLowerCase().split('.').last;
    return switch (type) {
      RequisitionEvidenceType.image =>
        extension == 'png'
            ? 'image/png'
            : extension == 'webp'
            ? 'image/webp'
            : 'image/jpeg',
      RequisitionEvidenceType.video => switch (extension) {
        'mov' => 'video/quicktime',
        'mkv' => 'video/x-matroska',
        'avi' => 'video/x-msvideo',
        'webm' => 'video/webm',
        '3gp' => 'video/3gpp',
        'm4v' => 'video/x-m4v',
        'ts' || 'mts' || 'm2ts' => 'video/mp2t',
        'flv' => 'video/x-flv',
        'wmv' => 'video/x-ms-wmv',
        _ => 'video/mp4',
      },
      RequisitionEvidenceType.audio => 'audio/mpeg',
      RequisitionEvidenceType.document =>
        extension == 'pdf' ? 'application/pdf' : 'application/octet-stream',
      RequisitionEvidenceType.other => 'application/octet-stream',
    };
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
