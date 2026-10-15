enum EvidenceOfflineSyncStage { preparing, downloading, completed, error }

final class EvidenceOfflineSyncProgress {
  const EvidenceOfflineSyncProgress({
    required this.requisitionId,
    required this.total,
    required this.completed,
    required this.skipped,
    required this.failed,
    required this.stage,
    required this.isActive,
    this.currentFileName,
    this.errorMessage,
  });

  final String requisitionId;
  final int total;
  final int completed;
  final int skipped;
  final int failed;
  final EvidenceOfflineSyncStage stage;
  final bool isActive;
  final String? currentFileName;
  final String? errorMessage;

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
  });

  final int total;
  final int completed;
  final int skipped;
  final int failed;
  final List<String> errors;

  bool get hasFailures => failed > 0;
  int get available => completed + skipped;
}
