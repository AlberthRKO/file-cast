enum EvidenceOfflineSyncStage { preparing, downloading, completed, error }

enum EvidenceOfflineSyncScope { requisition, selectedEvidence }

final class EvidenceOfflineSyncProgress {
  const EvidenceOfflineSyncProgress({
    required this.requisitionId,
    required this.total,
    required this.completed,
    required this.skipped,
    required this.failed,
    required this.stage,
    required this.isActive,
    this.scope = EvidenceOfflineSyncScope.requisition,
    this.currentFileName,
    this.errorMessage,
    this.errors = const [],
  });

  final String requisitionId;
  final int total;
  final int completed;
  final int skipped;
  final int failed;
  final EvidenceOfflineSyncStage stage;
  final bool isActive;
  final EvidenceOfflineSyncScope scope;
  final String? currentFileName;
  final String? errorMessage;
  final List<String> errors;

  int get processed => completed + skipped + failed;

  double? get fraction {
    if (total <= 0) return null;
    return (processed / total).clamp(0.0, 1.0).toDouble();
  }
}

final class EvidenceOfflineSyncResult {
  const EvidenceOfflineSyncResult({
    required this.total,
    required this.completed,
    required this.skipped,
    required this.failed,
    this.errors = const [],
    this.backgroundRetryScheduled = false,
  });

  final int total;
  final int completed;
  final int skipped;
  final int failed;
  final List<String> errors;
  final bool backgroundRetryScheduled;

  bool get hasFailures => failed > 0;
  int get available => completed + skipped;
}
