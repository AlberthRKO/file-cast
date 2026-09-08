import 'dart:async';

import 'package:file_cast/domain/models/requisition_detail.dart';
import 'package:file_cast/domain/repositories/requisition_detail_repository.dart';
import 'package:flutter/foundation.dart';

enum RequisitionDetailPhase { loading, content, error }

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
    required this.requisitionId,
  }) : _repository = repository;

  final RequisitionDetailRepository _repository;
  final String requisitionId;
  RequisitionDetailPhase _phase = RequisitionDetailPhase.loading;
  RequisitionDetailPhase get phase => _phase;
  RequisitionDetail? _detail;
  RequisitionDetail? get detail => _detail;
  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  bool _isImporting = false;
  StreamSubscription<String>? _changesSubscription;
  bool _disposed = false;
  bool get isImporting => _isImporting;

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
    _phase = RequisitionDetailPhase.loading;
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

  Future<void> importEvidence({required bool imagesOnly}) async {
    if (_isImporting || _disposed) return;
    _isImporting = true;
    _errorMessage = null;
    if (!_disposed) notifyListeners();
    try {
      final result = await _repository.importFromDevice(
        requisitionId: requisitionId,
        imagesOnly: imagesOnly,
      );
      if (result != null) _detail = result;
    } catch (_) {
      _errorMessage = 'No se pudo simular la carga del archivo.';
    }
    _isImporting = false;
    if (!_disposed) notifyListeners();
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
    _changesSubscription?.cancel();
    super.dispose();
  }
}
