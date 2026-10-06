import 'package:file_cast/domain/models/requisition_detail.dart';

final class PreparedEvidencePreview {
  const PreparedEvidencePreview({
    required this.path,
    required this.isTemporary,
    this.documentText,
  });

  final String path;
  final bool isTemporary;
  final String? documentText;
}

abstract interface class EvidencePreviewService {
  Future<PreparedEvidencePreview> prepare(RequisitionEvidence evidence);

  Future<void> disposePreview(PreparedEvidencePreview preview);
}
