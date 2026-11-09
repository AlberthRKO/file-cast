import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:file_cast/data/services/evidence_crypto_service.dart';
import 'package:file_cast/data/services/evidence_picker_service.dart';
import 'package:file_cast/data/services/evidence_key_exchange_service.dart';
import 'package:file_cast/data/services/evidence_offline_sync_service.dart';
import 'package:file_cast/data/services/evidence_sync_service.dart';
import 'package:file_cast/data/services/local_evidence_database_service.dart';
import 'package:file_cast/data/services/requisition_detail_service.dart';
import 'package:file_cast/domain/models/evidence_offline_sync.dart';
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
    EvidenceKeyExchangeService? keyExchange,
    EvidenceOfflineSyncService? offlineSyncService,
  }) : _detailService = detailService,
       _pickerService = pickerService ?? EvidencePickerService(),
       _cryptoService = cryptoService,
       _database = database,
       _syncService = syncService,
       _keyExchange = keyExchange,
       _offlineSyncService = offlineSyncService {
    _syncChangesSubscription = syncService?.changes.listen(
      _onEvidenceSyncChanged,
    );
    _syncProgressSubscription = syncService?.progress.listen(
      _onEvidenceUploadProgress,
    );
  }

  final RequisitionDetailService _detailService;
  final Map<String, List<RequisitionEvidence>> _imported = {};
  final Map<String, List<LocalEvidenceRecord>> _cachedLocalEvidence = {};
  final Map<String, RequisitionDetail> _cachedRemoteDetails = {};
  final Map<String, Set<String>> _deletedEvidenceIds = {};
  final Map<String, Future<void>> _keySharingInFlight = {};
  final EvidencePickerService _pickerService;
  final EvidenceCryptoService? _cryptoService;
  final LocalEvidenceDatabaseService? _database;
  final EvidenceSyncService? _syncService;
  final EvidenceKeyExchangeService? _keyExchange;
  final EvidenceOfflineSyncService? _offlineSyncService;
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
  Stream<EvidenceOfflineSyncProgress> get offlineSyncProgress =>
      _offlineSyncService?.progress ?? const Stream.empty();

  @override
  Future<int> syncPendingEvidence({required String requisitionId}) =>
      _syncService?.retryPendingEvidence(requisitionId: requisitionId) ??
      Future<int>.value(0);

  @override
  Future<bool> syncEvidence({
    required String requisitionId,
    required String evidenceId,
  }) =>
      _syncService?.retryEvidence(
        requisitionId: requisitionId,
        evidenceId: evidenceId,
      ) ??
      Future<bool>.value(false);

  @override
  Future<void> cancelPendingEvidenceSync({
    required String requisitionId,
  }) async {
    await _syncService?.cancelPendingEvidence(requisitionId: requisitionId);
  }

  @override
  Future<RequisitionDetail> deletePendingEvidence({
    required String requisitionId,
    required RequisitionEvidence evidence,
  }) async {
    final imported = _imported[requisitionId] ?? const <RequisitionEvidence>[];
    RequisitionEvidence? importedEvidence;
    for (final item in imported) {
      if (item.id == evidence.id) {
        importedEvidence = item;
        break;
      }
    }

    final uploadStatus = evidence.uploadStatus?.toUpperCase();
    if (uploadStatus != 'PENDING_UPLOAD' && uploadStatus != 'ERROR') {
      throw StateError(
        'La evidencia ya está sincronizada o se está subiendo.',
      );
    }

    final database = _database;
    var deleted = false;
    if (evidence.isBackendRecord) {
      await _detailService.deleteEvidence(
        requisitionId: requisitionId,
        evidenceId: evidence.id,
      );
      if (database != null) {
        await database.deletePendingEvidence(
          requisitionId: requisitionId,
          evidenceId: evidence.id,
        );
      }
      deleted = true;
      _deletedEvidenceIds
          .putIfAbsent(requisitionId, () => <String>{})
          .add(evidence.id);
    } else if (database != null) {
      deleted = await database.deletePendingEvidence(
        requisitionId: requisitionId,
        evidenceId: evidence.id,
      );
    }
    if (!deleted && importedEvidence == null) {
      throw StateError(
        'La evidencia no está pendiente o ya fue sincronizada.',
      );
    }

    _imported.update(
      requisitionId,
      (items) => items.where((item) => item.id != evidence.id).toList(),
      ifAbsent: () => const [],
    );
    _cachedLocalEvidence.update(
      requisitionId,
      (items) => items.where((item) => item.id != evidence.id).toList(),
      ifAbsent: () => const [],
    );

    if (evidence.isBackendRecord) {
      final cachedRemote = _cachedRemoteDetails[requisitionId];
      if (cachedRemote != null) {
        _cachedRemoteDetails[requisitionId] = _withoutEvidence(
          cachedRemote,
          evidence.id,
        );
      }
    }

    final cachedRemote = _cachedRemoteDetails[requisitionId];
    if (cachedRemote == null) return getDetail(requisitionId);
    return _mergeRemoteDetail(cachedRemote, requisitionId);
  }

  @override
  Future<EvidenceOfflineSyncResult> syncEvidenceForOffline({
    required String requisitionId,
    required List<RequisitionEvidence> evidence,
    EvidenceOfflineSyncScope scope = EvidenceOfflineSyncScope.requisition,
  }) async {
    final service = _offlineSyncService;
    if (service == null) {
      throw StateError(
        'El servicio de sincronización offline no está disponible.',
      );
    }
    final result = await service.syncRequisition(
      requisitionId: requisitionId,
      evidence: evidence,
      scope: scope,
      showSystemProgress: scope == EvidenceOfflineSyncScope.requisition,
    );
    return result;
  }

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
      remote = _withoutDeletedEvidence(requisitionId, remote);
      _cachedRemoteDetails[requisitionId] = remote;
    } catch (_) {
      final cached = _cachedRemoteDetails[requisitionId];
      if (cached == null) rethrow;
      remote = cached;
    }

    RequisitionDetail detail;
    try {
      detail = await _mergeRemoteDetail(remote, requisitionId);
    } on Object {
      // El detalle remoto sigue siendo válido aunque una lectura local antigua
      // esté bloqueada o tenga una fila incompatible. La siguiente carga puede
      // volver a reconstruir la copia offline sin ocultar la requisa.
      detail = remote;
    }
    _schedulePersistedKeySharing(requisitionId, remote);
    return detail;
  }

  @override
  Future<RequisitionDetail> refreshDetail(String requisitionId) async {
    var remote = await _detailService.getDetail(requisitionId);
    remote = _withoutDeletedEvidence(requisitionId, remote);
    _cachedRemoteDetails[requisitionId] = remote;
    RequisitionDetail detail;
    try {
      detail = await _mergeRemoteDetail(remote, requisitionId);
    } on Object {
      detail = remote;
    }
    _schedulePersistedKeySharing(requisitionId, remote);
    return detail;
  }

  @override
  Future<RequisitionDetail> getCachedDetail(String requisitionId) async {
    final cached = _cachedRemoteDetails[requisitionId];
    if (cached == null) return getDetail(requisitionId);
    try {
      return await _mergeRemoteDetail(cached, requisitionId);
    } on Object {
      return cached;
    }
  }

  void _schedulePersistedKeySharing(
    String requisitionId,
    RequisitionDetail remote,
  ) {
    if (_keySharingInFlight.containsKey(requisitionId)) return;

    final task = _sharePersistedKeysSafely(requisitionId, remote);
    _keySharingInFlight[requisitionId] = task;
    unawaited(
      task.whenComplete(() {
        if (identical(_keySharingInFlight[requisitionId], task)) {
          _keySharingInFlight.remove(requisitionId);
        }
      }),
    );
  }

  Future<void> _sharePersistedKeysSafely(
    String requisitionId,
    RequisitionDetail remote,
  ) async {
    try {
      await _sharePersistedKeys(requisitionId, remote);
    } on Object {
      // La reparación de envolturas es mantenimiento secundario. Nunca debe
      // impedir que el detalle remoto llegue a la pantalla.
    }
  }

  Future<void> _sharePersistedKeys(
    String requisitionId,
    RequisitionDetail _,
  ) async {
    final keyExchange = _keyExchange;
    if (keyExchange == null) return;
    try {
      // Calienta fuera del render la única clave de requisa. Ya no se
      // recorren evidencias ni dispositivos para reparar envolturas una a una.
      await keyExchange.requisitionKey(requisitionId);
    } on Object {
      return;
    }
  }

  Future<RequisitionDetail> _mergeRemoteDetail(
    RequisitionDetail remote,
    String requisitionId,
  ) async {
    final persisted = await _localEvidenceSafely(requisitionId);
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
      ...imported.where(
        (item) =>
            !_isDeletedEvidence(requisitionId, item.id) &&
            !serverIds.contains(item.id) &&
            !persistedById.containsKey(item.id),
      ),
      ...persisted
          .where(
            (item) =>
                !_isDeletedEvidence(requisitionId, item.id) &&
                !serverIds.contains(item.id),
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

  RequisitionDetail _withoutEvidence(
    RequisitionDetail detail,
    String evidenceId,
  ) {
    final evidence = detail.evidence
        .where((item) => item.id != evidenceId)
        .toList(growable: false);
    return RequisitionDetail(
      requisition: detail.requisition.copyWith(
        imageEvidenceCount: evidence
            .where((item) => item.type == RequisitionEvidenceType.image)
            .length,
        videoEvidenceCount: evidence
            .where((item) => item.type == RequisitionEvidenceType.video)
            .length,
        isSynchronized: evidence.every(
          (item) => item.uploadStatus?.toUpperCase() == 'AVAILABLE',
        ),
      ),
      division: detail.division,
      subjects: detail.subjects,
      subjectDetails: detail.subjectDetails,
      participants: detail.participants,
      sessionId: detail.sessionId,
      evidence: evidence,
      sessions: detail.sessions,
      description: detail.description,
      procedureAt: detail.procedureAt,
      locationLabel: detail.locationLabel,
      latitude: detail.latitude,
      longitude: detail.longitude,
      version: detail.version,
      createdAt: detail.createdAt,
      updatedAt: detail.updatedAt,
    );
  }

  RequisitionDetail _withoutDeletedEvidence(
    String requisitionId,
    RequisitionDetail detail,
  ) {
    final deleted = _deletedEvidenceIds[requisitionId];
    if (deleted == null || deleted.isEmpty) return detail;
    var result = detail;
    for (final evidenceId in deleted) {
      result = _withoutEvidence(result, evidenceId);
    }
    return result;
  }

  bool _isDeletedEvidence(String requisitionId, String evidenceId) =>
      _deletedEvidenceIds[requisitionId]?.contains(evidenceId) ?? false;

  Future<List<LocalEvidenceRecord>> _localEvidenceSafely(
    String requisitionId,
  ) async {
    final database = _database;
    if (database == null) return const <LocalEvidenceRecord>[];
    try {
      // Esta lectura no modifica la base. No debe esperar el lock global,
      // porque WorkManager puede conservarlo mientras sincroniza evidencias.
      // Si SQLite está ocupado o la apertura cifrada se demora, el detalle
      // remoto sigue siendo suficiente para renderizar la pantalla.
      final local = await database
          .forRequisition(requisitionId)
          .timeout(const Duration(seconds: 2));
      _cachedLocalEvidence[requisitionId] = local;
      return local;
    } on Object {
      // Una lectura puede coincidir con el isolate de WorkManager. Conserva
      // el último snapshot válido para no reemplazar visualmente 4 copias
      // locales por solo la evidencia nueva que está en memoria.
      return _cachedLocalEvidence[requisitionId] ??
          const <LocalEvidenceRecord>[];
    }
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
          requisitionId: requisitionId,
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
      requisitionId: record.requisitionId,
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
      uploadStatus: _uploadStatusForLocalState(record.state),
    );
  }

  RequisitionEvidence _mergeLocalPreview(
    RequisitionEvidence remote,
    LocalEvidenceRecord? persisted,
    RequisitionEvidence? imported,
  ) {
    if (persisted != null) {
      final persistedPath = File(persisted.encryptedPath).existsSync()
          ? persisted.encryptedPath
          : null;
      return RequisitionEvidence(
        id: remote.id,
        isBackendRecord: true,
        requisitionId: remote.requisitionId,
        name: remote.name,
        type: remote.type,
        createdAt: remote.createdAt,
        sizeLabel: remote.sizeLabel,
        byteLength: remote.byteLength,
        localPath: persistedPath,
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
        remoteWrappedKey: remote.remoteWrappedKey,
        remoteWrapAlgorithm: remote.remoteWrapAlgorithm,
        keyVersion: remote.keyVersion ?? persisted.keyVersion,
        uploadStatus: _mergeUploadStatus(
          remoteStatus: remote.uploadStatus,
          localState: persisted.state,
        ),
        contentUrl: remote.contentUrl,
        downloadUrl: remote.downloadUrl,
        contentSessionToken: remote.contentSessionToken,
      );
    }
    if (imported == null || imported.localPath == null) return remote;
    return RequisitionEvidence(
      id: remote.id,
      isBackendRecord: true,
      requisitionId: remote.requisitionId,
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
      remoteWrappedKey: remote.remoteWrappedKey,
      remoteWrapAlgorithm: remote.remoteWrapAlgorithm,
      keyVersion: remote.keyVersion ?? imported.keyVersion,
      uploadStatus: remote.uploadStatus ?? imported.uploadStatus,
      contentUrl: remote.contentUrl,
      downloadUrl: remote.downloadUrl,
      contentSessionToken: remote.contentSessionToken,
    );
  }

  String _uploadStatusForLocalState(String state) =>
      switch (state.toUpperCase()) {
        'SINCRONIZADA' => 'AVAILABLE',
        'SUBIENDO' => 'UPLOADING',
        'ERROR' => 'ERROR',
        _ => 'PENDING_UPLOAD',
      };

  String _mergeUploadStatus({
    required String? remoteStatus,
    required String localState,
  }) {
    final normalizedRemote = remoteStatus?.trim().toUpperCase();
    final normalizedLocal = _uploadStatusForLocalState(localState);
    // AVAILABLE es la confirmación del servidor. Un estado local transitorio
    // o fallido no debe ocultar una subida que ya fue aceptada remotamente.
    if (normalizedRemote == 'AVAILABLE') return 'AVAILABLE';
    if (normalizedLocal == 'ERROR' || normalizedLocal == 'UPLOADING') {
      return normalizedLocal;
    }
    return normalizedRemote ?? normalizedLocal;
  }
}
