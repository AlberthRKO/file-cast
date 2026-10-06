enum EvidenceUploadStage { preparing, uploading, completed, error }

final class EvidenceUploadProgress {
  const EvidenceUploadProgress({
    required this.requisitionId,
    required this.total,
    required this.completed,
    required this.failed,
    required this.stage,
    required this.isActive,
    this.currentFileName,
  });

  final String requisitionId;
  final int total;
  final int completed;
  final int failed;
  final EvidenceUploadStage stage;
  final bool isActive;
  final String? currentFileName;

  int get processed => completed + failed;

  double? get fraction {
    if (total <= 0) return null;
    return (processed / total).clamp(0.0, 1.0).toDouble();
  }

  bool get hasFailures => failed > 0;
}
