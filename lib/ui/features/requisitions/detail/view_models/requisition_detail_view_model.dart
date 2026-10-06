import 'dart:async';

import 'package:file_cast/domain/models/requisition.dart';
import 'package:file_cast/domain/models/requisition_detail.dart';
import 'package:file_cast/domain/models/requisition_creation.dart';
import 'package:file_cast/domain/models/evidence_upload_progress.dart';
import 'package:file_cast/domain/repositories/requisition_detail_repository.dart';
import 'package:file_cast/domain/repositories/requisition_creation_repository.dart';
import 'package:file_cast/domain/repositories/requisition_repository.dart';
import 'package:file_cast/domain/services/evidence_preview_service.dart';
import 'package:flutter/foundation.dart';

enum RequisitionDetailPhase { loading, content, error }

enum CaseLinkSearchPhase { initial, loading, content, empty, error }

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
  bool _isCreatingSession = false;
  bool _isFinalizing = false;
  bool _isLinkingCase = false;
  Timer? _caseLinkDebounce;
  int _caseLinkSearchToken = 0;
  String _caseLinkQuery = '';
  List<EcosystemCaseSummary> _caseLinkResults = const [];
  CaseLinkSearchPhase _caseLinkSearchPhase = CaseLinkSearchPhase.initial;
  String? _caseLinkError;
  StreamSubscription<String>? _changesSubscription;
  StreamSubscription<EvidenceUploadProgress>? _uploadProgressSubscription;
  List<ImportedEvidenceDraft> _selectedEvidence = const [];
  EvidenceUploadProgress? _uploadProgress;
  bool _disposed = false;
  bool get isImporting => _isImporting;
  bool get isSelectingEvidence => _isSelectingEvidence;
  bool get isSyncing => _isSyncing;
  List<ImportedEvidenceDraft> get selectedEvidence => _selectedEvidence;
  EvidenceUploadProgress? get uploadProgress => _uploadProgress;
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

  int get pendingEvidenceCount =>
      _detail?.evidence
          .where(
            (item) => const {'PENDING_UPLOAD', 'UPLOADING', 'ERROR'}.contains(
              item.uploadStatus?.toUpperCase(),
            ),
          )
          .length ??
      0;

  bool get hasPendingEvidence => pendingEvidenceCount > 0;

  String get caseLinkQuery => _caseLinkQuery;
  List<EcosystemCaseSummary> get caseLinkResults => _caseLinkResults;
  CaseLinkSearchPhase get caseLinkSearchPhase => _caseLinkSearchPhase;
  String? get caseLinkError => _caseLinkError;
  bool get isLinkingCase => _isLinkingCase;
  bool get canLinkCase =>
      _detail?.requisition.cud == null &&
      (_detail?.requisition.status == RequisitionStatus.draft ||
          _detail?.requisition.status == RequisitionStatus.inProgress);

  String participantName(RequisitionParticipantSummary participant) {
    if (currentActorId == participant.actorId &&
        currentActorName?.trim().isNotEmpty == true) {
      return currentActorName!.trim();
    }
    return 'Participante asignado';
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
      } else if (_isSyncing) {
        _isSyncing = false;
      }
      notifyListeners();
    });
    _phase = RequisitionDetailPhase.loading;
    _errorMessage = null;
    if (!_disposed) notifyListeners();
    try {
      _detail = await _repository.getDetail(requisitionId);
      _phase = RequisitionDetailPhase.content;
    } catch (_) {
      _phase = RequisitionDetailPhase.error;
      _errorMessage = 'No se pudo recuperar la requisa.';
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> _reloadSilently() async {
    try {
      _detail = await _repository.getDetail(requisitionId);
      _phase = RequisitionDetailPhase.content;
      if (!_disposed) notifyListeners();
    } catch (_) {
      // The existing detail remains visible until a deliberate retry.
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
    try {
      await _repository.syncPendingEvidence();
    } catch (error) {
      _errorMessage = _messageFromError(
        error,
        fallback: 'La evidencia quedó guardada y se reintentará más tarde.',
      );
    } finally {
      _isSyncing = false;
      if (!_disposed) notifyListeners();
    }
  }

  void retryPendingEvidence() {
    if (_isSyncing || _disposed || !hasPendingEvidence) return;
    _isSyncing = true;
    if (!_disposed) notifyListeners();
    unawaited(_syncImportedEvidence());
  }

  Future<PreparedEvidencePreview> prepareEvidencePreview(
    RequisitionEvidence evidence,
  ) => _previewService.prepare(evidence);

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

  String _messageFromError(Object error, {required String fallback}) {
    final message = error.toString().replaceFirst('Bad state: ', '').trim();
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
    super.dispose();
  }
}
