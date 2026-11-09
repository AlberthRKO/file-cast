import 'dart:async';

import 'package:file_cast/domain/models/evidence_offline_sync.dart';
import 'package:file_cast/domain/models/evidence_upload_progress.dart';
import 'package:file_cast/domain/models/requisition.dart';
import 'package:file_cast/domain/models/requisition_creation.dart';
import 'package:file_cast/domain/models/requisition_detail.dart';
import 'package:file_cast/domain/repositories/requisition_creation_repository.dart';
import 'package:file_cast/domain/repositories/requisition_detail_repository.dart';
import 'package:file_cast/domain/repositories/requisition_repository.dart';
import 'package:file_cast/domain/services/evidence_preview_service.dart';
import 'package:flutter/foundation.dart';

enum RequisitionDetailPhase { loading, content, error }

enum CaseLinkSearchPhase { initial, loading, content, empty, error }

enum ParticipantSearchPhase { initial, loading, content, empty, error }

enum EvidenceCategory { images, videos, files }

final class EvidenceCategorySummary {
  const EvidenceCategorySummary({
    required this.category,
    required this.items,
    required this.totalSizeLabel,
  });

  final EvidenceCategory category;
  final List<RequisitionEvidence> items;
  final String totalSizeLabel;
}

class RequisitionDetailViewModel extends ChangeNotifier {
  RequisitionDetailViewModel({
    required RequisitionDetailRepository repository,
    required RequisitionRepository requisitionRepository,
    required RequisitionCreationRepository creationRepository,
    required EvidencePreviewService previewService,
    required this.requisitionId,
    this.currentActorId,
    this.currentActorName,
  }) : _repository = repository,
       _requisitionRepository = requisitionRepository,
       _creationRepository = creationRepository,
       _previewService = previewService;

  final RequisitionDetailRepository _repository;
  final RequisitionRepository _requisitionRepository;
  final RequisitionCreationRepository _creationRepository;
  final EvidencePreviewService _previewService;
  final String requisitionId;
  final String? currentActorId;
  final String? currentActorName;
  RequisitionDetailPhase _phase = RequisitionDetailPhase.loading;
  RequisitionDetailPhase get phase => _phase;
  RequisitionDetail? _detail;
  RequisitionDetail? get detail => _detail;
  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  bool _isImporting = false;
  bool _isSelectingEvidence = false;
  bool _isSyncing = false;
  bool _isCancellingUpload = false;
  String? _uploadingEvidenceId;
  bool _isRefreshing = false;
  bool _isOfflineSyncing = false;
  bool _waitingForOfflineReload = false;
  bool _isCreatingSession = false;
  bool _isFinalizing = false;
  bool _isLinkingCase = false;
  bool _isAddingParticipant = false;
  Timer? _caseLinkDebounce;
  int _caseLinkSearchToken = 0;
  String _caseLinkQuery = '';
  List<EcosystemCaseSummary> _caseLinkResults = const [];
  CaseLinkSearchPhase _caseLinkSearchPhase = CaseLinkSearchPhase.initial;
  String? _caseLinkError;
  int _participantSearchToken = 0;
  String _participantQuery = '';
  RequisitionParticipantUser? _participantCandidate;
  ParticipantSearchPhase _participantSearchPhase =
      ParticipantSearchPhase.initial;
  String? _participantError;
  final Map<String, RequisitionParticipantUser> _knownParticipants = {};
  StreamSubscription<String>? _changesSubscription;
  StreamSubscription<EvidenceUploadProgress>? _uploadProgressSubscription;
  StreamSubscription<EvidenceOfflineSyncProgress>?
  _offlineSyncProgressSubscription;
  List<ImportedEvidenceDraft> _selectedEvidence = const [];
  EvidenceUploadProgress? _uploadProgress;
  EvidenceOfflineSyncProgress? _offlineSyncProgress;
  String? _offlineSyncError;
  List<String> _offlineSyncErrors = const [];
  Future<void>? _silentReloadInFlight;
  Future<void>? _remoteUploadRefreshInFlight;
  bool _silentReloadQueued = false;
  bool _uploadRequestInFlight = false;
  Timer? _uploadStatusTimer;
  bool _disposed = false;
  bool get isImporting => _isImporting;
  bool get isSelectingEvidence => _isSelectingEvidence;
  bool get isSyncing => _isSyncing;
  bool get isCancellingUpload => _isCancellingUpload;
  bool get isRefreshing => _isRefreshing;
  List<ImportedEvidenceDraft> get selectedEvidence => _selectedEvidence;
  EvidenceUploadProgress? get uploadProgress => _uploadProgress;
  EvidenceOfflineSyncProgress? get offlineSyncProgress => _offlineSyncProgress;
  String? get offlineSyncError => _offlineSyncError;
  List<String> get offlineSyncErrors => _offlineSyncErrors;
  bool get isOfflineSyncing => _isOfflineSyncing;
  bool get isFinalizing => _isFinalizing;
  bool get canFinalize {
    final status = _detail?.requisition.status;
    return status == RequisitionStatus.draft ||
        status == RequisitionStatus.inProgress;
  }

  bool get canSeal =>
      canFinalize && (_detail?.requisition.isSynchronized ?? false);

  bool get canAcquire {
    final status = _detail?.requisition.status;
    return status == RequisitionStatus.draft ||
        status == RequisitionStatus.inProgress;
  }

  bool get supportsAndroidUsbAcquisition =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  int get pendingEvidenceCount =>
      _detail?.evidence
          .where(
            (item) => const {'PENDING_UPLOAD', 'UPLOADING', 'ERROR'}.contains(
              item.uploadStatus?.toUpperCase(),
            ),
          )
          .length ??
      0;

  int get failedEvidenceCount =>
      _detail?.evidence
          .where((item) => item.uploadStatus?.toUpperCase() == 'ERROR')
          .length ??
      0;

  bool get hasPendingEvidence => pendingEvidenceCount > 0;

  bool canDeleteEvidence(RequisitionEvidence evidence) {
    if (_uploadingEvidenceId == evidence.id) return false;
    final status = evidence.uploadStatus?.toUpperCase();
    if (status != 'PENDING_UPLOAD' && status != 'ERROR') return false;
    return evidence.isBackendRecord ||
        evidence.localPath?.trim().isNotEmpty == true;
  }

  String? _deletingEvidenceId;

  bool isDeletingEvidence(RequisitionEvidence evidence) =>
      _deletingEvidenceId == evidence.id;

  bool canUploadEvidence(RequisitionEvidence evidence) {
    if (_uploadingEvidenceId != null || _isCancellingUpload) return false;
    final status = evidence.uploadStatus?.toUpperCase();
    return (status == 'PENDING_UPLOAD' || status == 'ERROR') &&
        evidence.localPath?.trim().isNotEmpty == true;
  }

  bool isUploadingEvidence(RequisitionEvidence evidence) =>
      _uploadingEvidenceId == evidence.id;

  int get offlineEvidenceTotalCount =>
      _detail?.evidence
          .where(
            (item) =>
                item.encrypted &&
                item.uploadStatus?.toUpperCase() == 'AVAILABLE' &&
                (item.contentUrl?.isNotEmpty ?? false),
          )
          .length ??
      0;

  int get offlineEvidenceAvailableCount =>
      _detail?.evidence
          .where(
            (item) =>
                item.encrypted &&
                item.uploadStatus?.toUpperCase() == 'AVAILABLE' &&
                (item.contentUrl?.isNotEmpty ?? false) &&
                (item.localPath?.isNotEmpty ?? false),
          )
          .length ??
      0;

  String get caseLinkQuery => _caseLinkQuery;
  List<EcosystemCaseSummary> get caseLinkResults => _caseLinkResults;
  CaseLinkSearchPhase get caseLinkSearchPhase => _caseLinkSearchPhase;
  String? get caseLinkError => _caseLinkError;
  bool get isLinkingCase => _isLinkingCase;
  bool get isAddingParticipant => _isAddingParticipant;
  String get participantQuery => _participantQuery;
  RequisitionParticipantUser? get participantCandidate => _participantCandidate;
  ParticipantSearchPhase get participantSearchPhase => _participantSearchPhase;
  String? get participantError => _participantError;
  bool get canManageParticipants {
    final status = _detail?.requisition.status;
    if (currentActorId == null ||
        (status != RequisitionStatus.draft &&
            status != RequisitionStatus.inProgress)) {
      return false;
    }
    return _detail?.participants.any(
          (participant) =>
              participant.actorId == currentActorId &&
              participant.role.toUpperCase() == 'OWNER',
        ) ??
        false;
  }

  bool get canLinkCase =>
      _detail?.requisition.cud == null &&
      (_detail?.requisition.status == RequisitionStatus.draft ||
          _detail?.requisition.status == RequisitionStatus.inProgress);

  String participantName(RequisitionParticipantSummary participant) {
    if (participant.fullName?.trim().isNotEmpty ?? false) {
      return participant.fullName!.trim();
    }
    if (currentActorId == participant.actorId &&
        (currentActorName?.trim().isNotEmpty ?? false)) {
      return currentActorName!.trim();
    }
    return _knownParticipants[participant.actorId]?.fullName ??
        'Participante asignado';
  }

  bool isParticipantAlreadyAdded(RequisitionParticipantUser user) {
    return _detail?.participants.any(
          (participant) => participant.actorId == user.id.toString(),
        ) ??
        false;
  }

  List<EvidenceCategorySummary> get evidenceCategories {
    final evidence = _detail?.evidence ?? const <RequisitionEvidence>[];
    return EvidenceCategory.values
        .map((category) {
          final items = evidence
              .where(
                (item) => switch (category) {
                  EvidenceCategory.images =>
                    item.type == RequisitionEvidenceType.image,
                  EvidenceCategory.videos =>
                    item.type == RequisitionEvidenceType.video,
                  EvidenceCategory.files =>
                    item.type != RequisitionEvidenceType.image &&
                        item.type != RequisitionEvidenceType.video,
                },
              )
              .toList(growable: false);
          final bytes = items.fold<int>(
            0,
            (total, item) => total + item.byteLength,
          );
          return EvidenceCategorySummary(
            category: category,
            items: items,
            totalSizeLabel: _formatSize(bytes),
          );
        })
        .toList(growable: false);
  }

  Future<void> load() async {
    if (_disposed) return;
    _changesSubscription ??= _repository.changes.listen((changedId) {
      if (changedId == requisitionId) unawaited(_reloadSilently());
    });
    _uploadProgressSubscription ??= _repository.uploadProgress.listen((
      progress,
    ) {
      if (progress.requisitionId != requisitionId || _disposed) return;
      _uploadProgress = progress;
      if (progress.isActive) {
        _isSyncing = true;
      } else if (_isSyncing && !_uploadRequestInFlight) {
        _isSyncing = false;
      }
      notifyListeners();
    });
    _offlineSyncProgressSubscription ??= _repository.offlineSyncProgress.listen(
      (progress) {
        if (progress.requisitionId != requisitionId || _disposed) return;
        if (progress.scope == EvidenceOfflineSyncScope.selectedEvidence) {
          if (!progress.isActive) unawaited(_reloadSilently());
          return;
        }
        _offlineSyncProgress = progress;
        _offlineSyncError = progress.errorMessage;
        _offlineSyncErrors = progress.errors;
        if (progress.isActive) {
          _isOfflineSyncing = true;
        } else if (!_waitingForOfflineReload) {
          _isOfflineSyncing = false;
        }
        notifyListeners();
      },
    );
    _phase = RequisitionDetailPhase.loading;
    _errorMessage = null;
    if (!_disposed) notifyListeners();
    try {
      _detail = await _repository.getDetail(requisitionId);
      _updateUploadStatusPolling();
      _phase = RequisitionDetailPhase.content;
      _clearUploadStateWhenNoPendingEvidence();
    } catch (_) {
      _phase = RequisitionDetailPhase.error;
      _errorMessage = 'No se pudo recuperar la requisa.';
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> _reloadSilently() {
    final inFlight = _silentReloadInFlight;
    if (inFlight != null) {
      _silentReloadQueued = true;
      return inFlight;
    }

    final future = () async {
      do {
        _silentReloadQueued = false;
        await _performSilentReload();
      } while (_silentReloadQueued && !_disposed);
    }();
    _silentReloadInFlight = future;
    unawaited(
      future.whenComplete(() {
        if (identical(_silentReloadInFlight, future)) {
          _silentReloadInFlight = null;
        }
      }),
    );
    return future;
  }

  Future<void> _performSilentReload() async {
    try {
      final hadPendingEvidence = pendingEvidenceCount > 0;
      _detail = await _repository.getCachedDetail(requisitionId);
      _updateUploadStatusPolling();
      _phase = RequisitionDetailPhase.content;
      _clearUploadStateWhenNoPendingEvidence();
      if (!_disposed) notifyListeners();
      if (hadPendingEvidence && pendingEvidenceCount == 0) {
        unawaited(_refreshRemoteAfterUpload());
      }
    } catch (_) {
      // The existing detail remains visible until a deliberate retry.
    }
  }

  Future<void> _refreshRemoteAfterUpload() {
    final inFlight = _remoteUploadRefreshInFlight;
    if (inFlight != null) return inFlight;
    final refresh = _performRemoteRefreshAfterUpload();
    _remoteUploadRefreshInFlight = refresh;
    unawaited(
      refresh.whenComplete(() {
        if (identical(_remoteUploadRefreshInFlight, refresh)) {
          _remoteUploadRefreshInFlight = null;
        }
      }),
    );
    return refresh;
  }

  Future<void> _performRemoteRefreshAfterUpload() async {
    try {
      final refreshed = await _repository.refreshDetail(requisitionId);
      if (_disposed) return;
      _detail = refreshed;
      _updateUploadStatusPolling();
      _phase = RequisitionDetailPhase.content;
      _clearUploadStateWhenNoPendingEvidence();
      notifyListeners();
    } catch (_) {
      // La confirmación local de la outbox ya está visible. Una caída de la
      // lectura remota posterior no debe convertir una carga exitosa en error.
    }
  }

  Future<void> refresh() async {
    if (_disposed || _isRefreshing) return;
    if (_detail == null) {
      await load();
      return;
    }

    _isRefreshing = true;
    _errorMessage = null;
    if (!_disposed) notifyListeners();
    try {
      _detail = await _repository.refreshDetail(requisitionId);
      _updateUploadStatusPolling();
      _phase = RequisitionDetailPhase.content;
      _clearUploadStateWhenNoPendingEvidence();
    } catch (error) {
      _errorMessage = _messageFromError(
        error,
        fallback: 'No se pudo actualizar el detalle de la requisa.',
      );
    } finally {
      _isRefreshing = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<bool> importEvidence({required bool imagesOnly}) async {
    final selected = await selectEvidence(imagesOnly: imagesOnly);
    if (selected.isEmpty) return false;
    return confirmSelectedEvidence();
  }

  Future<List<ImportedEvidenceDraft>> selectEvidence({
    required bool imagesOnly,
  }) async {
    if (_isSelectingEvidence || _isImporting || _disposed) {
      return const [];
    }
    _isSelectingEvidence = true;
    _selectedEvidence = const [];
    _errorMessage = null;
    if (!_disposed) notifyListeners();
    try {
      _selectedEvidence =
          await _repository.pickEvidence(imagesOnly: imagesOnly) ?? const [];
      return _selectedEvidence;
    } catch (error) {
      _errorMessage = _messageFromError(
        error,
        fallback: 'No se pudieron seleccionar los archivos.',
      );
      return const [];
    } finally {
      _isSelectingEvidence = false;
      if (!_disposed) notifyListeners();
    }
  }

  void clearSelectedEvidence() {
    if (_selectedEvidence.isEmpty) return;
    _selectedEvidence = const [];
    if (!_disposed) notifyListeners();
  }

  Future<bool> confirmSelectedEvidence() async {
    if (_isImporting || _disposed || _selectedEvidence.isEmpty) return false;
    _isImporting = true;
    _errorMessage = null;
    var imported = false;
    if (!_disposed) notifyListeners();
    try {
      final sessionId = await ensureAcquisitionSession(
        sourcePlatform: 'FILE_CAST',
        transport: 'SYSTEM_PICKER',
      );
      if (sessionId != null) {
        final drafts = _selectedEvidence
            .map(
              (draft) => draft.copyWith(
                sessionId: sessionId,
              ),
            )
            .toList(growable: false);
        final result = await _repository.addImportedEvidenceBatch(
          requisitionId: requisitionId,
          evidence: drafts,
        );
        if (result != null) {
          _detail = result;
          _updateUploadStatusPolling();
          imported = true;
          _selectedEvidence = const [];
          _isSyncing = true;
          if (!_disposed) notifyListeners();
          unawaited(_syncImportedEvidence());
        }
      }
    } catch (error) {
      _errorMessage = _messageFromError(
        error,
        fallback: 'No se pudo registrar la evidencia localmente.',
      );
    }
    _isImporting = false;
    if (!_disposed) notifyListeners();
    return imported;
  }

  Future<void> _syncImportedEvidence() async {
    _uploadRequestInFlight = true;
    try {
      final synchronized = await _repository.syncPendingEvidence(
        requisitionId: requisitionId,
      );
      // Primero se refleja la confirmación local para que el badge y el total
      // cambien sin esperar otra petición. Luego se reconcilia en segundo
      // plano todo el detalle con la fuente remota.
      await _reloadSilently();
      if (synchronized > 0) {
        unawaited(_refreshRemoteAfterUpload());
      }
    } catch (error) {
      _errorMessage = _messageFromError(
        error,
        fallback: 'La evidencia quedó guardada y se reintentará más tarde.',
      );
    } finally {
      _uploadRequestInFlight = false;
      _isSyncing = false;
      if (!_disposed) notifyListeners();
    }
  }

  void retryPendingEvidence() {
    if (_isSyncing || _isCancellingUpload || _disposed || !hasPendingEvidence) {
      return;
    }
    _isSyncing = true;
    _uploadProgress = null;
    _errorMessage = null;
    if (!_disposed) notifyListeners();
    unawaited(_syncImportedEvidence());
  }

  Future<void> cancelPendingEvidenceSync() async {
    if (_disposed || _isCancellingUpload || !hasPendingEvidence) return;
    _isCancellingUpload = true;
    _isSyncing = false;
    if (!_disposed) notifyListeners();
    try {
      await _repository.cancelPendingEvidenceSync(requisitionId: requisitionId);
      _uploadProgress = null;
      await _reloadSilently();
    } catch (error) {
      _errorMessage = _messageFromError(
        error,
        fallback: 'No se pudo detener la sincronización. Intenta nuevamente.',
      );
    } finally {
      _isCancellingUpload = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<String?> uploadPendingEvidence(RequisitionEvidence evidence) async {
    if (_disposed) return 'El detalle de la requisa ya no está disponible.';
    if (!canUploadEvidence(evidence)) {
      return 'La evidencia ya se está subiendo o no tiene una copia local disponible.';
    }

    _uploadingEvidenceId = evidence.id;
    _uploadRequestInFlight = true;
    _isSyncing = true;
    _uploadProgress = null;
    _errorMessage = null;
    if (!_disposed) notifyListeners();
    try {
      final synchronized = await _repository.syncEvidence(
        requisitionId: requisitionId,
        evidenceId: evidence.id,
      );
      await _reloadSilently();
      _clearUploadStateWhenNoPendingEvidence();
      if (!synchronized) {
        return 'No se pudo cargar la evidencia. Quedó guardada para volver a intentarlo.';
      }
      unawaited(_refreshRemoteAfterUpload());
      return null;
    } catch (error) {
      final message = _messageFromError(
        error,
        fallback:
            'No se pudo cargar la evidencia. Quedó guardada para volver a intentarlo.',
      );
      _errorMessage = message;
      await _reloadSilently();
      return message;
    } finally {
      _uploadingEvidenceId = null;
      _uploadRequestInFlight = false;
      _isSyncing = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<String?> deletePendingEvidence(RequisitionEvidence evidence) async {
    if (_disposed) return 'El detalle de la requisa ya no está disponible.';
    if (!canDeleteEvidence(evidence)) {
      return 'La evidencia ya está sincronizada o no se puede eliminar.';
    }
    if (_deletingEvidenceId != null) return 'Ya hay una eliminación en curso.';

    _deletingEvidenceId = evidence.id;
    _errorMessage = null;
    if (!_disposed) notifyListeners();
    try {
      _detail = await _repository.deletePendingEvidence(
        requisitionId: requisitionId,
        evidence: evidence,
      );
      _updateUploadStatusPolling();
      await _reloadSilently();
      _clearUploadStateWhenNoPendingEvidence();
      _phase = RequisitionDetailPhase.content;
      return null;
    } catch (error) {
      final message = _messageFromError(
        error,
        fallback: 'No se pudo eliminar la evidencia pendiente.',
      );
      _errorMessage = message;
      return message;
    } finally {
      _deletingEvidenceId = null;
      if (!_disposed) notifyListeners();
    }
  }

  void syncEvidenceForOffline() {
    if (_isOfflineSyncing || _disposed) return;
    final evidence = _detail?.evidence;
    if (evidence == null || evidence.isEmpty) return;
    _isOfflineSyncing = true;
    _waitingForOfflineReload = true;
    _offlineSyncProgress = null;
    _offlineSyncError = null;
    _offlineSyncErrors = const [];
    _errorMessage = null;
    notifyListeners();
    unawaited(_syncEvidenceForOffline(evidence));
  }

  Future<void> _syncEvidenceForOffline(
    List<RequisitionEvidence> evidence,
  ) async {
    try {
      final result = await _repository.syncEvidenceForOffline(
        requisitionId: requisitionId,
        evidence: evidence,
      );
      if (result.hasFailures) {
        _offlineSyncErrors = result.errors;
        _offlineSyncError = result.errors.isEmpty
            ? 'Algunas evidencias no pudieron quedar disponibles offline.'
            : result.errors.first;
        _errorMessage = _offlineSyncError;
      } else if (result.total == 0) {
        _offlineSyncError =
            'No se encontraron evidencias disponibles para sincronizar offline.';
        _errorMessage = _offlineSyncError;
      }
      await _reloadSilently();
    } catch (error) {
      _offlineSyncError = _messageFromError(
        error,
        fallback: 'No se pudieron sincronizar las evidencias para uso offline.',
      );
      _offlineSyncErrors = [_offlineSyncError!];
      _errorMessage = _offlineSyncError;
    } finally {
      _waitingForOfflineReload = false;
      _isOfflineSyncing = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<PreparedEvidencePreview> prepareEvidencePreview(
    RequisitionEvidence evidence,
  ) async {
    var evidenceForPreview = evidence;
    if (_needsOfflineRecovery(evidence)) {
      // EvidencePreviewSheet starts this future from initState. That happens
      // while Flutter is building the dialog, so notifying synchronously here
      // causes markNeedsBuild/setState during build. Yield to the event loop
      // before changing ViewModel state; this also keeps the preview usable
      // when the detail is rebuilt at the same time.
      await Future<void>.delayed(Duration.zero);
      if (_disposed) return _previewService.prepare(evidenceForPreview);

      EvidenceOfflineSyncResult result;
      try {
        result = await _repository.syncEvidenceForOffline(
          requisitionId: requisitionId,
          evidence: [evidence],
          scope: EvidenceOfflineSyncScope.selectedEvidence,
        );
        await _reloadSilently();
      } catch (error) {
        throw StateError(
          _messageFromError(
            error,
            fallback:
                'No se pudo descargar la evidencia. Puedes intentarlo nuevamente.',
          ),
        );
      }
      if (result.hasFailures) {
        final reason = result.errors.isEmpty
            ? 'No se pudo descargar la evidencia.'
            : result.errors.first;
        final backgroundMessage = result.backgroundRetryScheduled
            ? ' La descarga continuará en segundo plano y recibirás un aviso cuando termine.'
            : ' Puedes intentarlo nuevamente.';
        throw StateError('$reason$backgroundMessage');
      }

      if (_disposed) {
        throw StateError(
          'La vista previa se cerró antes de completar la descarga.',
        );
      }

      for (final item in _detail?.evidence ?? const <RequisitionEvidence>[]) {
        if (item.id == evidence.id) {
          evidenceForPreview = item;
          break;
        }
      }
      if (_needsOfflineRecovery(evidenceForPreview)) {
        throw StateError(
          'La copia local todavía no está disponible. '
          'Puedes intentarlo nuevamente.',
        );
      }
    }
    return _previewService.prepare(evidenceForPreview);
  }

  bool _needsOfflineRecovery(RequisitionEvidence evidence) {
    return evidence.encrypted &&
        evidence.uploadStatus?.toUpperCase() == 'AVAILABLE' &&
        (evidence.contentUrl?.isNotEmpty ?? false) &&
        (evidence.localPath == null || evidence.localPath!.isEmpty);
  }

  void _clearUploadStateWhenNoPendingEvidence() {
    if (pendingEvidenceCount != 0) return;
    _isSyncing = false;
    _uploadProgress = null;
  }

  void _updateUploadStatusPolling() {
    if (pendingEvidenceCount == 0) {
      _uploadStatusTimer?.cancel();
      _uploadStatusTimer = null;
      return;
    }
    // WorkManager actualiza SQLite desde otro isolate y no puede publicar en
    // el StreamController de esta pantalla. Esta reconciliación consulta solo
    // el snapshot local cacheado y permite observar el estado terminal sin
    // recargar el detalle remoto ni las miniaturas.
    _uploadStatusTimer ??= Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(_reloadSilently()),
    );
  }

  Future<void> disposeEvidencePreview(PreparedEvidencePreview preview) =>
      _previewService.disposePreview(preview);

  Future<String?> ensureAcquisitionSession({
    required String sourcePlatform,
    required String transport,
  }) async {
    final existing = _detail?.sessionId.trim();
    if (existing != null && existing.isNotEmpty) return existing;
    if (_isCreatingSession || _disposed) return null;

    _isCreatingSession = true;
    _errorMessage = null;
    if (!_disposed) notifyListeners();
    try {
      final sessionId = await _requisitionRepository.createAcquisitionSession(
        requisitionId: requisitionId,
        sourcePlatform: sourcePlatform,
        transport: transport,
      );
      await _reloadSilently();
      return sessionId;
    } catch (error) {
      _errorMessage = _messageFromError(
        error,
        fallback: 'No se pudo abrir la sesión de adquisición.',
      );
      return null;
    } finally {
      _isCreatingSession = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<String?> finalizeRequisition() async {
    if (_isFinalizing || _disposed || !canFinalize) return null;
    if (!canSeal) {
      const message =
          'No se puede sellar mientras existan evidencias pendientes de sincronización.';
      _errorMessage = message;
      if (!_disposed) notifyListeners();
      return message;
    }
    _isFinalizing = true;
    _errorMessage = null;
    if (!_disposed) notifyListeners();
    try {
      await _requisitionRepository.finalizeRequisition(requisitionId);
      await _reloadSilently();
      return null;
    } catch (error) {
      final message = _messageFromError(
        error,
        fallback: 'No se pudo finalizar la requisa.',
      );
      _errorMessage = message;
      return message;
    } finally {
      _isFinalizing = false;
      if (!_disposed) notifyListeners();
    }
  }

  void updateCaseLinkQuery(String value) {
    _caseLinkDebounce?.cancel();
    _caseLinkQuery = value;
    _caseLinkResults = const [];
    _caseLinkError = null;
    _caseLinkSearchPhase = value.trim().length >= 4
        ? CaseLinkSearchPhase.loading
        : CaseLinkSearchPhase.initial;
    if (!_disposed) notifyListeners();
    if (value.trim().length < 4) return;
    _caseLinkDebounce = Timer(
      const Duration(milliseconds: 350),
      searchCaseLinkCandidates,
    );
  }

  Future<void> searchCaseLinkCandidates() async {
    final query = _caseLinkQuery.trim();
    if (query.length < 4 || _disposed) return;
    final token = ++_caseLinkSearchToken;
    _caseLinkSearchPhase = CaseLinkSearchPhase.loading;
    _caseLinkError = null;
    if (!_disposed) notifyListeners();
    try {
      final results = await _creationRepository.searchCasesByCud(query);
      if (token != _caseLinkSearchToken || _disposed) return;
      _caseLinkResults = results;
      _caseLinkSearchPhase = results.isEmpty
          ? CaseLinkSearchPhase.empty
          : CaseLinkSearchPhase.content;
    } catch (error) {
      if (token != _caseLinkSearchToken || _disposed) return;
      _caseLinkResults = const [];
      _caseLinkSearchPhase = CaseLinkSearchPhase.error;
      _caseLinkError = _messageFromError(
        error,
        fallback: 'No se pudo buscar el CUD.',
      );
    }
    if (!_disposed) notifyListeners();
  }

  Future<String?> linkCase(EcosystemCaseSummary caseSummary) async {
    if (_disposed) return 'El detalle de la requisa ya no está disponible.';
    if (_isLinkingCase) return 'Ya hay una vinculación en curso.';
    if (!canLinkCase) {
      return 'La requisa no admite vincular un caso en su estado actual.';
    }
    _isLinkingCase = true;
    _caseLinkError = null;
    if (!_disposed) notifyListeners();
    try {
      await _requisitionRepository.linkCase(
        requisitionId: requisitionId,
        externalCaseId: caseSummary.id > 0 ? caseSummary.id : null,
        cud: caseSummary.cud,
        type: caseSummary.type,
        division: caseSummary.division,
        subjects: caseSummary.subjects,
        participants: caseSummary.officials,
      );
      await _reloadSilently();
      _caseLinkQuery = '';
      _caseLinkResults = const [];
      _caseLinkSearchPhase = CaseLinkSearchPhase.initial;
      return null;
    } catch (error) {
      final message = _messageFromError(
        error,
        fallback: 'No se pudo vincular el CUD.',
      );
      _caseLinkError = message;
      return message;
    } finally {
      _isLinkingCase = false;
      if (!_disposed) notifyListeners();
    }
  }

  void updateParticipantQuery(String value) {
    _participantQuery = value;
    _participantCandidate = null;
    _participantSearchPhase = ParticipantSearchPhase.initial;
    _participantError = null;
    if (!_disposed) notifyListeners();
  }

  Future<void> searchParticipantUser() async {
    final query = _participantQuery.trim();
    if (query.length < 3 || _disposed) return;
    final token = ++_participantSearchToken;
    _participantCandidate = null;
    _participantSearchPhase = ParticipantSearchPhase.loading;
    _participantError = null;
    if (!_disposed) notifyListeners();
    try {
      final user = await _requisitionRepository.searchParticipantUserByCi(
        query,
      );
      if (token != _participantSearchToken || _disposed) return;
      _participantCandidate = user;
      _knownParticipants[user.id.toString()] = user;
      _participantSearchPhase = ParticipantSearchPhase.content;
    } catch (error) {
      if (token != _participantSearchToken || _disposed) return;
      _participantSearchPhase = ParticipantSearchPhase.error;
      _participantError = _messageFromError(
        error,
        fallback: 'No se encontró un usuario con ese CI.',
      );
    }
    if (!_disposed) notifyListeners();
  }

  Future<String?> addParticipant({
    required RequisitionParticipantRole role,
  }) async {
    final candidate = _participantCandidate;
    if (_disposed) return 'El detalle de la requisa ya no está disponible.';
    if (_isAddingParticipant) return 'Ya hay un participante en proceso.';
    if (!canManageParticipants) {
      return 'Solo el propietario puede agregar participantes.';
    }
    if (candidate == null) {
      return 'Busca un usuario por CI antes de agregarlo.';
    }
    if (isParticipantAlreadyAdded(candidate)) {
      return 'Este usuario ya tiene acceso a la requisa.';
    }

    _isAddingParticipant = true;
    _participantError = null;
    if (!_disposed) notifyListeners();
    try {
      await _requisitionRepository.addParticipant(
        requisitionId: requisitionId,
        ci: candidate.ci,
        role: role,
      );
      await _reloadSilently();
      _participantQuery = '';
      _participantCandidate = null;
      _participantSearchPhase = ParticipantSearchPhase.initial;
      return null;
    } catch (error) {
      final message = _messageFromError(
        error,
        fallback: 'No se pudo agregar el participante.',
      );
      _participantError = message;
      return message;
    } finally {
      _isAddingParticipant = false;
      if (!_disposed) notifyListeners();
    }
  }

  String _messageFromError(Object error, {required String fallback}) {
    final message = error.toString().replaceFirst('Bad state: ', '').trim();
    final normalized = message.toLowerCase();
    if (normalized.contains('timeout') ||
        normalized.contains('bloqueo de sincronización local')) {
      return 'La sincronización local está ocupada. Se reintentará automáticamente.';
    }
    if (message.contains('SqfliteSqlCipherOpenDatabaseOptions') ||
        message.contains('SqfliteOpenDatabaseOptions')) {
      return 'La base local cifrada no pudo abrirse. Actualiza la aplicación '
          'y vuelve a intentar; la evidencia remota no se eliminó.';
    }
    return message.isEmpty ? fallback : message;
  }

  String _formatSize(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).ceil()} KB';
  }

  @override
  void dispose() {
    _disposed = true;
    _caseLinkDebounce?.cancel();
    _changesSubscription?.cancel();
    _uploadProgressSubscription?.cancel();
    _offlineSyncProgressSubscription?.cancel();
    _uploadStatusTimer?.cancel();
    _knownParticipants.clear();
    super.dispose();
  }
}
