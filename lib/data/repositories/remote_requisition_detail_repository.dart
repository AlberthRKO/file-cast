import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:file_cast/data/services/evidence_crypto_service.dart';
import 'package:file_cast/data/services/evidence_picker_service.dart';
import 'package:file_cast/data/services/evidence_key_exchange_service.dart';
import 'package:file_cast/data/services/evidence_offline_sync_service.dart';
import 'package:file_cast/data/services/evidence_sync_service.dart';
import 'package:file_cast/data/services/local_evidence_database_service.dart';
import 'package:file_cast/data/services/remote_request_exception.dart';
import 'package:file_cast/data/services/requisition_detail_service.dart';
import 'package:file_cast/domain/models/evidence_offline_sync.dart';
import 'package:file_cast/domain/models/evidence_upload_progress.dart';
import 'package:file_cast/domain/models/requisition.dart';
import 'package:file_cast/domain/models/requisition_detail.dart';
import 'package:file_cast/domain/repositories/requisition_detail_repository.dart';
import 'package:file_cast/domain/repositories/connectivity_repository.dart';

class RemoteRequisitionDetailRepository implements RequisitionDetailRepository {
  RemoteRequisitionDetailRepository({
    required RequisitionDetailService detailService,
    EvidencePickerService? pickerService,
    EvidenceCryptoService? cryptoService,
    LocalEvidenceDatabaseService? database,
    EvidenceSyncService? syncService,
    EvidenceKeyExchangeService? keyExchange,
    EvidenceOfflineSyncService? offlineSyncService,
    required ConnectivityRepository connectivity,
  }) : _detailService = detailService,
       _pickerService = pickerService ?? EvidencePickerService(),
       _cryptoService = cryptoService,
       _database = database,
       _syncService = syncService,
       _keyExchange = keyExchange,
       _connectivity = connectivity,
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
  String? _memoryAccountId;
  final EvidencePickerService _pickerService;
  final EvidenceCryptoService? _cryptoService;
  final LocalEvidenceDatabaseService? _database;
  final EvidenceSyncService? _syncService;
  final EvidenceKeyExchangeService? _keyExchange;
  final EvidenceOfflineSyncService? _offlineSyncService;
  final ConnectivityRepository _connectivity;
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
  Future<RequisitionDetail> renameEvidence({
    required String requisitionId,
    required RequisitionEvidence evidence,
    required String displayName,
  }) async {
    if (!evidence.isBackendRecord) {
      await _database?.updateDisplayName(
        requisitionId: requisitionId,
        evidenceId: evidence.id,
        displayName: displayName.trim(),
      );
      _updateLocalEvidence(
        requisitionId,
        evidence.id,
        evidence.copyWith(displayName: displayName.trim()),
      );
      final cached = _cachedRemoteDetails[requisitionId];
      return cached == null
          ? getDetail(requisitionId)
          : _mergeRemoteDetail(cached, requisitionId);
    }
    await _detailService.renameEvidence(
      requisitionId: requisitionId,
      evidenceId: evidence.id,
      displayName: displayName,
    );
    final refreshed = await refreshDetail(requisitionId);
    return refreshed;
  }

  @override
  Future<RequisitionDetail> setEvidenceSubjects({
    required String requisitionId,
    required RequisitionEvidence evidence,
    required List<int> personIds,
  }) async {
    if (!evidence.isBackendRecord) {
      throw StateError(
        'Los sujetos se pueden anclar cuando la evidencia existe en el servidor.',
      );
    }
    await _detailService.setEvidenceSubjects(
      requisitionId: requisitionId,
      evidenceId: evidence.id,
      personIds: personIds,
    );
    return refreshDetail(requisitionId);
  }

  void _updateLocalEvidence(
    String requisitionId,
    String evidenceId,
    RequisitionEvidence updated,
  ) {
    _imported.update(
      requisitionId,
      (items) => items
          .map((item) => item.id == evidenceId ? updated : item)
          .toList(growable: false),
      ifAbsent: () => const [],
    );
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
    EvidencePickerSource source = EvidencePickerSource.files,
  }) async {
    final picked = await _pickerService.pickFiles(
      imagesOnly: imagesOnly,
      fromPhotoLibrary: source == EvidencePickerSource.photoLibrary,
    );
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
            preserveSource: !file.ownedPickerCopy,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> releasePickedEvidence(
    List<ImportedEvidenceDraft> evidence,
  ) => _pickerService.releaseOwnedPickerPaths(
    evidence.map((draft) => draft.localPath),
  );

  @override
  Future<RequisitionDetail> getDetail(String requisitionId) async {
    await _ensureMemoryAccountScope();
    RequisitionDetail remote;
    await _refreshConnectivityIfUnknown();
    if (_worksOffline) {
      final cached = await _persistedOrMemoryDetail(requisitionId);
      if (cached == null) {
        throw StateError(
          'Esta requisa todavía no fue preparada para trabajar sin conexión.',
        );
      }
      remote = cached;
    } else {
      try {
        remote = await _fetchRemoteAndCache(requisitionId);
        remote = _withoutDeletedEvidence(requisitionId, remote);
        _cachedRemoteDetails[requisitionId] = remote;
      } on RemoteRequestException catch (error) {
        if (!error.allowsOfflineFallback) rethrow;
        final cached = await _persistedOrMemoryDetail(requisitionId);
        if (cached == null) rethrow;
        remote = cached;
      }
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
    if (!_worksOffline) _schedulePersistedKeySharing(requisitionId, remote);
    return detail;
  }

  @override
  Future<RequisitionDetail> refreshDetail(String requisitionId) async {
    await _ensureMemoryAccountScope();
    await _refreshConnectivityIfUnknown();
    if (_worksOffline) return getCachedDetail(requisitionId);
    var remote = await _fetchRemoteAndCache(requisitionId);
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

  bool get _worksOffline => switch (_connectivity.currentStatus) {
    ConnectivityStatus.offline || ConnectivityStatus.limited => true,
    ConnectivityStatus.checking || ConnectivityStatus.online => false,
  };

  Future<void> _refreshConnectivityIfUnknown() async {
    if (_connectivity.currentStatus != ConnectivityStatus.checking) return;
    await _connectivity.refresh();
  }

  @override
  Future<RequisitionDetail> getCachedDetail(String requisitionId) async {
    await _ensureMemoryAccountScope();
    final cached = await _persistedOrMemoryDetail(requisitionId);
    if (cached == null) return getDetail(requisitionId);
    try {
      return await _mergeRemoteDetail(cached, requisitionId);
    } on Object {
      return cached;
    }
  }

  Future<RequisitionDetail> _fetchRemoteAndCache(String requisitionId) async {
    final snapshot = await _detailService.getDetailSnapshot(requisitionId);
    try {
      await _database?.saveRequisitionDetailSnapshot(
        requisitionId: requisitionId,
        payloadJson: snapshot.payloadJson,
      );
    } on Object {
      // El detalle remoto se puede mostrar aunque SQLite esté ocupado.
    }
    return snapshot.detail;
  }

  Future<RequisitionDetail?> _persistedOrMemoryDetail(
    String requisitionId,
  ) async {
    final memory = _cachedRemoteDetails[requisitionId];
    try {
      final payload = await _database?.requisitionDetailSnapshot(requisitionId);
      if (payload == null || payload.isEmpty) {
        _cachedRemoteDetails.remove(requisitionId);
        return null;
      }
      final detail = _detailService.parseCachedSnapshot(payload);
      _cachedRemoteDetails[requisitionId] = detail;
      return detail;
    } on Object {
      // Si SQLite está temporalmente ocupado, el snapshot ya validado de esta
      // ejecución sigue siendo un fallback seguro para la misma cuenta.
      return memory;
    }
  }

  Future<void> _ensureMemoryAccountScope() async {
    final database = _database;
    if (database == null) return;
    final accountId = await database.currentAccountId();
    if (_memoryAccountId == accountId) return;
    _memoryAccountId = accountId;
    _imported.clear();
    _cachedLocalEvidence.clear();
    _cachedRemoteDetails.clear();
    _deletedEvidenceIds.clear();
    _keySharingInFlight.clear();
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
    LocalAcquisitionSessionRecord? localSession;
    try {
      localSession = await _database?.activeLocalAcquisitionSession(
        requisitionId,
      );
    } on Object {
      localSession = null;
    }
    final remoteSessionId = localSession?.remoteId;
    if (remoteSessionId != null && remoteSessionId.isNotEmpty) {
      RequisitionAcquisitionSession? matchingRemoteSession;
      for (final session in remote.sessions) {
        if (session.id == remoteSessionId) {
          matchingRemoteSession = session;
          break;
        }
      }
      if (matchingRemoteSession != null && !matchingRemoteSession.isOpen) {
        try {
          await _database?.markLocalSessionClosed(localSession!.localId);
        } on Object {
          // El detalle remoto sigue siendo utilizable aunque falle este ajuste.
        }
        localSession = null;
      }
    }
    final resolvedLocalSession = localSession;
    final sessions = <RequisitionAcquisitionSession>[
      ...remote.sessions,
      if (resolvedLocalSession != null &&
          remote.sessions.every(
            (item) => item.id != resolvedLocalSession.localId,
          ))
        RequisitionAcquisitionSession(
          id: resolvedLocalSession.localId,
          status: RequisitionSessionStatus.open,
          sourcePlatform: resolvedLocalSession.sourcePlatform,
          transport: resolvedLocalSession.transport,
          startedAt: resolvedLocalSession.createdAt,
        ),
    ];
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
      caseSubjects: remote.caseSubjects,
      participants: remote.participants,
      caseInfo: remote.caseInfo,
      personInfo: remote.personInfo,
      sessionId: resolvedLocalSession?.localId ?? remote.sessionId,
      evidence: evidence,
      sessions: sessions,
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
      caseSubjects: detail.caseSubjects,
      participants: detail.participants,
      caseInfo: detail.caseInfo,
      personInfo: detail.personInfo,
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
      // En la primera apertura, SQLCipher y el Keychain de iPadOS pueden
      // tardar más de dos segundos. Esperar esa lectura evita mostrar una
      // falsa pérdida de copias offline tras reiniciar la app.
      final cached = _cachedLocalEvidence[requisitionId];
      final read = database.forRequisition(requisitionId);
      final local = cached == null
          ? await read
          : await read.timeout(const Duration(seconds: 2));
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
    List<int> subjectPersonIds = const [],
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
          subjectPersonIds: subjectPersonIds,
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
            subjectPersonIds: normalized.subjectPersonIds,
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
          linkedSubjects: _localLinkedSubjects(
            requisitionId,
            normalized.subjectPersonIds,
          ),
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
    final encryptedPath = await _persistEncryptedFile(
      evidenceId: evidenceId,
      encrypted: encrypted,
    );
    return ImportedEvidenceDraft(
      name: encrypted.name,
      type: draft.type,
      sizeLabel: _formatSize(encrypted.byteLength),
      byteLength: encrypted.byteLength,
      localPath: encryptedPath,
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
      subjectPersonIds: draft.subjectPersonIds,
      preserveSource: false,
    );
  }

  Future<String> _persistEncryptedFile({
    required String evidenceId,
    required EncryptedEvidenceLocal encrypted,
  }) async {
    final database = _database;
    if (database == null) return encrypted.localPath;
    final destinationPath = await database.persistentEncryptedPath(evidenceId);
    if (encrypted.localPath == destinationPath) return destinationPath;
    final source = File(encrypted.localPath);
    final destination = File(destinationPath);
    if (await destination.exists()) {
      throw StateError('Ya existe una copia cifrada con esta identidad.');
    }
    try {
      await source.rename(destinationPath);
    } on FileSystemException {
      final staging = File('$destinationPath.part');
      try {
        if (await staging.exists()) await staging.delete();
        await source.copy(staging.path);
        if (await staging.length() != encrypted.byteLength) {
          throw StateError('La copia cifrada no se guardó completa.');
        }
        await staging.rename(destinationPath);
        try {
          await source.delete();
        } on FileSystemException {
          // La copia persistente ya está instalada y verificada por tamaño.
        }
      } catch (_) {
        if (await staging.exists()) await staging.delete();
        rethrow;
      }
    }
    return destinationPath;
  }

  List<RequisitionEvidenceSubject> _localLinkedSubjects(
    String requisitionId,
    List<int> personIds,
  ) {
    if (personIds.isEmpty) return const [];
    final detail = _cachedRemoteDetails[requisitionId];
    if (detail == null) return const [];
    final subjects = {
      for (final subject in detail.anchorableSubjects)
        if (subject.personId != null) subject.personId!: subject,
    };
    return personIds
        .map((personId) => subjects[personId])
        .whereType<RequisitionSubjectSummary>()
        .map(
          (subject) => RequisitionEvidenceSubject(
            personId: subject.personId!,
            name: subject.name,
            documentNumber: subject.documentNumber,
            caseSubjectId: subject.caseSubjectId,
            subjectTypeName: subject.role,
            subjectTypeColorHex: subject.subjectTypeColorHex,
            source: 'MANUAL',
          ),
        )
        .toList(growable: false);
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
    final localPath = File(record.encryptedPath).existsSync()
        ? record.encryptedPath
        : null;
    return RequisitionEvidence(
      id: record.id,
      requisitionId: record.requisitionId,
      name: record.originalName,
      displayName: record.displayName,
      type: type,
      createdAt: record.createdAt,
      sizeLabel: _formatSize(record.ciphertextByteLength),
      byteLength: record.ciphertextByteLength,
      localPath: localPath,
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
      linkedSubjects: _localLinkedSubjects(
        record.requisitionId,
        record.subjectPersonIds,
      ),
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
        displayName: remote.displayName ?? persisted.displayName,
        linkedSubjects: remote.linkedSubjects,
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
      displayName: remote.displayName ?? imported.displayName,
      linkedSubjects: remote.linkedSubjects,
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
