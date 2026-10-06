import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:file_cast/data/services/evidence_crypto_service.dart';
import 'package:file_cast/data/services/evidence_picker_service.dart';
import 'package:file_cast/data/services/evidence_sync_service.dart';
import 'package:file_cast/data/services/local_evidence_database_service.dart';
import 'package:file_cast/data/services/requisition_detail_service.dart';
import 'package:file_cast/domain/models/evidence_upload_progress.dart';
import 'package:file_cast/domain/models/requisition.dart';
import 'package:file_cast/domain/models/requisition_detail.dart';
import 'package:file_cast/domain/repositories/requisition_detail_repository.dart';

class RemoteRequisitionDetailRepository implements RequisitionDetailRepository {
  RemoteRequisitionDetailRepository({
    required RequisitionDetailService detailService,
    EvidencePickerService? pickerService,
    EvidenceCryptoService? cryptoService,
    LocalEvidenceDatabaseService? database,
    EvidenceSyncService? syncService,
  }) : _detailService = detailService,
       _pickerService = pickerService ?? EvidencePickerService(),
       _cryptoService = cryptoService,
       _database = database,
       _syncService = syncService {
    _syncChangesSubscription = syncService?.changes.listen(
      _onEvidenceSyncChanged,
    );
    _syncProgressSubscription = syncService?.progress.listen(
      _onEvidenceUploadProgress,
    );
  }

  final RequisitionDetailService _detailService;
  final Map<String, List<RequisitionEvidence>> _imported = {};
  final Map<String, RequisitionDetail> _cachedRemoteDetails = {};
  final EvidencePickerService _pickerService;
  final EvidenceCryptoService? _cryptoService;
  final LocalEvidenceDatabaseService? _database;
  final EvidenceSyncService? _syncService;
  late final StreamSubscription<String>? _syncChangesSubscription;
  final StreamController<String> _changesController =
      StreamController<String>.broadcast();
  final StreamController<EvidenceUploadProgress> _progressController =
      StreamController<EvidenceUploadProgress>.broadcast();
  final Random _random = Random.secure();
  late final StreamSubscription<EvidenceUploadProgress>?
  _syncProgressSubscription;

  void _onEvidenceSyncChanged(String requisitionId) {
    if (!_changesController.isClosed) _changesController.add(requisitionId);
  }

  void _onEvidenceUploadProgress(EvidenceUploadProgress progress) {
    if (!_progressController.isClosed) _progressController.add(progress);
  }

  Future<void> dispose() async {
    await _syncChangesSubscription?.cancel();
    await _syncProgressSubscription?.cancel();
    await _changesController.close();
    await _progressController.close();
  }

  @override
  Stream<String> get changes => _changesController.stream;

  @override
  Stream<EvidenceUploadProgress> get uploadProgress =>
      _progressController.stream;

  @override
  Future<int> syncPendingEvidence() =>
      _syncService?.syncPending() ?? Future<int>.value(0);

  @override
  Future<List<ImportedEvidenceDraft>?> pickEvidence({
    required bool imagesOnly,
  }) async {
    final picked = await _pickerService.pickFiles(imagesOnly: imagesOnly);
    if (picked == null || picked.isEmpty) return null;
    return picked
        .map(
          (file) => ImportedEvidenceDraft(
            name: file.name,
            type: file.type,
            sizeLabel: file.sizeLabel,
            byteLength: file.byteLength,
            localPath: file.localPath,
            mimeType: file.mimeType,
            acquisitionMethod: 'IMPORTED_FILE',
            preserveSource: true,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<RequisitionDetail> getDetail(String requisitionId) async {
    RequisitionDetail remote;
    try {
      remote = await _detailService.getDetail(requisitionId);
      _cachedRemoteDetails[requisitionId] = remote;
    } catch (_) {
      final cached = _cachedRemoteDetails[requisitionId];
      if (cached == null) rethrow;
      remote = cached;
    }
    return _mergeRemoteDetail(remote, requisitionId);
  }

  Future<RequisitionDetail> _mergeRemoteDetail(
    RequisitionDetail remote,
    String requisitionId,
  ) async {
    final persisted =
        await _database?.forRequisition(requisitionId) ??
        const <LocalEvidenceRecord>[];
    final imported = _imported[requisitionId] ?? const <RequisitionEvidence>[];
    final serverIds = remote.evidence.map((item) => item.id).toSet();
    final persistedById = {
      for (final item in persisted) item.id: item,
    };
    final importedById = {
      for (final item in imported) item.id: item,
    };
    final remoteEvidence = remote.evidence
        .map(
          (item) => _mergeLocalPreview(
            item,
            persistedById[item.id],
            importedById[item.id],
          ),
        )
        .toList(growable: false);
    final localEvidence = <RequisitionEvidence>[
      ...imported.where((item) => !serverIds.contains(item.id)),
      ...persisted
          .where(
            (item) =>
                !serverIds.contains(item.id) &&
                !imported.any((evidence) => evidence.id == item.id),
          )
          .map(_toEvidence),
    ];
    final evidence = [...remoteEvidence, ...localEvidence];
    final imageCount = evidence
        .where((item) => item.type == RequisitionEvidenceType.image)
        .length;
    final videoCount = evidence
        .where((item) => item.type == RequisitionEvidenceType.video)
        .length;
    return RequisitionDetail(
      requisition: Requisition(
        id: remote.requisition.id,
        caseName: remote.requisition.caseName,
        registeredAt: remote.requisition.registeredAt,
        status: remote.requisition.status,
        imageEvidenceCount: imageCount,
        videoEvidenceCount: videoCount,
        isSynchronized:
            localEvidence.isEmpty && remote.requisition.isSynchronized,
        cud: remote.requisition.cud,
        subjectName: remote.requisition.subjectName,
      ),
      division: remote.division,
      subjects: remote.subjects,
      subjectDetails: remote.subjectDetails,
      participants: remote.participants,
      sessionId: remote.sessionId,
      evidence: evidence,
      sessions: remote.sessions,
      description: remote.description,
      procedureAt: remote.procedureAt,
      locationLabel: remote.locationLabel,
      latitude: remote.latitude,
      longitude: remote.longitude,
      version: remote.version,
      createdAt: remote.createdAt,
      updatedAt: remote.updatedAt,
    );
  }

  @override
  Future<RequisitionDetail> addImportedEvidence({
    required String requisitionId,
    required String name,
    required RequisitionEvidenceType type,
    required String sizeLabel,
    required int byteLength,
    String? localPath,
    String? sha256,
    String? sourcePath,
    String? sessionId,
    String? mimeType,
    String? acquisitionMethod,
    bool encrypted = false,
    String? encryptionAlgorithm,
    int? encryptionVersion,
    int? plaintextByteLength,
    String? plaintextSha256,
    String? aadHash,
    String? wrappedKey,
    int? keyVersion,
    bool preserveSource = false,
  }) async {
    return addImportedEvidenceBatch(
      requisitionId: requisitionId,
      evidence: [
        ImportedEvidenceDraft(
          name: name,
          type: type,
          sizeLabel: sizeLabel,
          byteLength: byteLength,
          localPath: localPath,
          sha256: sha256,
          sourcePath: sourcePath,
          sessionId: sessionId,
          mimeType: mimeType,
          acquisitionMethod: acquisitionMethod,
          encrypted: encrypted,
          encryptionAlgorithm: encryptionAlgorithm,
          encryptionVersion: encryptionVersion,
          plaintextByteLength: plaintextByteLength,
          plaintextSha256: plaintextSha256,
          aadHash: aadHash,
          wrappedKey: wrappedKey,
          keyVersion: keyVersion,
          preserveSource: preserveSource,
        ),
      ],
    );
  }

  @override
  Future<RequisitionDetail> addImportedEvidenceBatch({
    required String requisitionId,
    required List<ImportedEvidenceDraft> evidence,
  }) async {
    final timestamp = DateTime.now();
    final imported = <RequisitionEvidence>[];
    for (final draft in evidence) {
      final evidenceId = _uuid();
      final normalized = await _encryptDraftIfNeeded(
        evidenceId: evidenceId,
        draft: draft,
      );
      if (normalized.encrypted &&
          normalized.localPath != null &&
          normalized.sha256 != null &&
          normalized.plaintextSha256 != null &&
          normalized.encryptionAlgorithm != null &&
          normalized.encryptionVersion != null &&
          normalized.aadHash != null &&
          normalized.wrappedKey != null &&
          normalized.keyVersion != null &&
          normalized.mimeType != null) {
        await _database?.saveEvidence(
          LocalEvidenceRecord(
            id: evidenceId,
            requisitionId: requisitionId,
            sessionId: normalized.sessionId ?? '',
            originalName: normalized.name,
            mimeType: normalized.mimeType!,
            type: _backendKind(normalized.type),
            acquisitionMethod: normalized.acquisitionMethod ?? 'IMPORTED_FILE',
            encryptedPath: normalized.localPath!,
            plaintextByteLength:
                normalized.plaintextByteLength ?? normalized.byteLength,
            ciphertextByteLength: normalized.byteLength,
            plaintextSha256: normalized.plaintextSha256!,
            ciphertextSha256: normalized.sha256!,
            encryptionAlgorithm: normalized.encryptionAlgorithm!,
            encryptionVersion: normalized.encryptionVersion!,
            aadHash: normalized.aadHash!,
            wrappedKey: normalized.wrappedKey!,
            keyVersion: normalized.keyVersion!,
            state: 'PENDIENTE',
            clientOperationId: _uuid(),
            createdAt: timestamp,
            sourcePath: normalized.sourcePath,
          ),
        );
      }
      imported.add(
        RequisitionEvidence(
          id: evidenceId,
          name: normalized.name,
          type: normalized.type,
          createdAt: timestamp,
          sizeLabel: normalized.sizeLabel,
          byteLength: normalized.byteLength,
          localPath: normalized.localPath,
          sha256: normalized.sha256,
          sourcePath: normalized.sourcePath,
          sessionId: normalized.sessionId,
          mimeType: normalized.mimeType,
          encrypted: normalized.encrypted,
          encryptionAlgorithm: normalized.encryptionAlgorithm,
          encryptionVersion: normalized.encryptionVersion,
          plaintextByteLength: normalized.plaintextByteLength,
          plaintextSha256: normalized.plaintextSha256,
          aadHash: normalized.aadHash,
          wrappedKey: normalized.wrappedKey,
          keyVersion: normalized.keyVersion,
          uploadStatus: 'PENDING_UPLOAD',
        ),
      );
    }
    _imported.update(
      requisitionId,
      (items) => [...items, ...imported],
      ifAbsent: () => imported,
    );
    final cachedRemote = _cachedRemoteDetails[requisitionId];
    if (cachedRemote == null) return getDetail(requisitionId);
    return _mergeRemoteDetail(cachedRemote, requisitionId);
  }

  @override
  Future<RequisitionDetail?> importFromDevice({
    required String requisitionId,
    required bool imagesOnly,
    String? sessionId,
  }) async {
    final selected = await pickEvidence(imagesOnly: imagesOnly);
    if (selected == null || selected.isEmpty) return null;
    return addImportedEvidenceBatch(
      requisitionId: requisitionId,
      evidence: selected
          .map((draft) => draft.copyWith(sessionId: sessionId))
          .toList(growable: false),
    );
  }

  Future<ImportedEvidenceDraft> _encryptDraftIfNeeded({
    required String evidenceId,
    required ImportedEvidenceDraft draft,
  }) async {
    final path = draft.localPath;
    final crypto = _cryptoService;
    if (draft.encrypted || path == null || crypto == null) return draft;
    final sourcePath = draft.preserveSource
        ? '${path}.filecast-staging-${DateTime.now().microsecondsSinceEpoch}'
        : path;
    if (draft.preserveSource) await File(path).copy(sourcePath);
    late final EncryptedEvidenceLocal encrypted;
    try {
      encrypted = await crypto.encryptEvidence(
        evidenceId: evidenceId,
        inputPath: sourcePath,
        originalName: draft.name,
        mimeType: draft.mimeType ?? 'application/octet-stream',
      );
    } catch (_) {
      if (draft.preserveSource) {
        try {
          await File(sourcePath).delete();
        } on FileSystemException {
          // El staging se limpiará con el almacenamiento temporal del sistema.
        }
      }
      rethrow;
    }
    return ImportedEvidenceDraft(
      name: encrypted.name,
      type: draft.type,
      sizeLabel: _formatSize(encrypted.byteLength),
      byteLength: encrypted.byteLength,
      localPath: encrypted.localPath,
      sha256: encrypted.sha256,
      sourcePath: draft.sourcePath,
      sessionId: draft.sessionId,
      mimeType: encrypted.mimeType,
      acquisitionMethod: draft.acquisitionMethod,
      encrypted: true,
      encryptionAlgorithm: encrypted.encryptionAlgorithm,
      encryptionVersion: encrypted.encryptionVersion,
      plaintextByteLength: encrypted.plaintextByteLength,
      plaintextSha256: encrypted.plaintextSha256,
      aadHash: encrypted.aadHash,
      wrappedKey: encrypted.wrappedKey,
      keyVersion: encrypted.keyVersion,
      preserveSource: false,
    );
  }

  String _backendKind(RequisitionEvidenceType type) => switch (type) {
    RequisitionEvidenceType.image => 'IMAGE',
    RequisitionEvidenceType.video => 'VIDEO',
    RequisitionEvidenceType.audio => 'AUDIO',
    RequisitionEvidenceType.document => 'DOCUMENT',
    RequisitionEvidenceType.other => 'OTHER',
  };

  String _formatSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).ceil()} KB';
  }

  String _uuid() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  RequisitionEvidence _toEvidence(LocalEvidenceRecord record) {
    final type = switch (record.type) {
      'IMAGE' => RequisitionEvidenceType.image,
      'VIDEO' => RequisitionEvidenceType.video,
      'AUDIO' => RequisitionEvidenceType.audio,
      'DOCUMENT' => RequisitionEvidenceType.document,
      _ => RequisitionEvidenceType.other,
    };
    return RequisitionEvidence(
      id: record.id,
      name: record.originalName,
      type: type,
      createdAt: record.createdAt,
      sizeLabel: _formatSize(record.ciphertextByteLength),
      byteLength: record.ciphertextByteLength,
      localPath: record.encryptedPath,
      sha256: record.ciphertextSha256,
      sourcePath: record.sourcePath,
      sessionId: record.sessionId,
      mimeType: record.mimeType,
      encrypted: true,
      encryptionAlgorithm: record.encryptionAlgorithm,
      encryptionVersion: record.encryptionVersion,
      plaintextByteLength: record.plaintextByteLength,
      plaintextSha256: record.plaintextSha256,
      aadHash: record.aadHash,
      wrappedKey: record.wrappedKey,
      keyVersion: record.keyVersion,
      uploadStatus: record.state == 'SINCRONIZADA'
          ? 'AVAILABLE'
          : 'PENDING_UPLOAD',
    );
  }

  RequisitionEvidence _mergeLocalPreview(
    RequisitionEvidence remote,
    LocalEvidenceRecord? persisted,
    RequisitionEvidence? imported,
  ) {
    if (persisted != null) {
      return RequisitionEvidence(
        id: remote.id,
        name: remote.name,
        type: remote.type,
        createdAt: remote.createdAt,
        sizeLabel: remote.sizeLabel,
        byteLength: remote.byteLength,
        localPath: persisted.encryptedPath,
        sha256: remote.sha256 ?? persisted.ciphertextSha256,
        sourcePath: persisted.sourcePath ?? remote.sourcePath,
        sessionId: remote.sessionId ?? persisted.sessionId,
        mimeType: remote.mimeType ?? persisted.mimeType,
        encrypted: remote.encrypted || persisted.encryptionAlgorithm.isNotEmpty,
        encryptionAlgorithm:
            remote.encryptionAlgorithm ?? persisted.encryptionAlgorithm,
        encryptionVersion:
            remote.encryptionVersion ?? persisted.encryptionVersion,
        plaintextByteLength:
            remote.plaintextByteLength ?? persisted.plaintextByteLength,
        plaintextSha256: remote.plaintextSha256 ?? persisted.plaintextSha256,
        aadHash: remote.aadHash ?? persisted.aadHash,
        wrappedKey: remote.wrappedKey ?? persisted.wrappedKey,
        keyVersion: remote.keyVersion ?? persisted.keyVersion,
        uploadStatus: remote.uploadStatus,
        contentUrl: remote.contentUrl,
        downloadUrl: remote.downloadUrl,
      );
    }
    if (imported == null || imported.localPath == null) return remote;
    return RequisitionEvidence(
      id: remote.id,
      name: remote.name,
      type: remote.type,
      createdAt: remote.createdAt,
      sizeLabel: remote.sizeLabel,
      byteLength: remote.byteLength,
      localPath: imported.localPath,
      sha256: remote.sha256 ?? imported.sha256,
      sourcePath: imported.sourcePath ?? remote.sourcePath,
      sessionId: remote.sessionId ?? imported.sessionId,
      mimeType: remote.mimeType ?? imported.mimeType,
      encrypted: remote.encrypted || imported.encrypted,
      encryptionAlgorithm:
          remote.encryptionAlgorithm ?? imported.encryptionAlgorithm,
      encryptionVersion: remote.encryptionVersion ?? imported.encryptionVersion,
      plaintextByteLength:
          remote.plaintextByteLength ?? imported.plaintextByteLength,
      plaintextSha256: remote.plaintextSha256 ?? imported.plaintextSha256,
      aadHash: remote.aadHash ?? imported.aadHash,
      wrappedKey: remote.wrappedKey ?? imported.wrappedKey,
      keyVersion: remote.keyVersion ?? imported.keyVersion,
      uploadStatus: remote.uploadStatus,
      contentUrl: remote.contentUrl,
      downloadUrl: remote.downloadUrl,
    );
  }
}
