import 'package:file_cast/domain/models/requisition.dart';

enum RequisitionEvidenceType { image, video, audio, document, other }

final class ImportedEvidenceDraft {
  const ImportedEvidenceDraft({
    required this.name,
    required this.type,
    required this.sizeLabel,
    required this.byteLength,
    this.localPath,
    this.sha256,
    this.sourcePath,
  });

  final String name;
  final RequisitionEvidenceType type;
  final String sizeLabel;
  final int byteLength;
  final String? localPath;
  final String? sha256;
  final String? sourcePath;
}

final class RequisitionEvidence {
  const RequisitionEvidence({
    required this.id,
    required this.name,
    required this.type,
    required this.createdAt,
    required this.sizeLabel,
    required this.byteLength,
    this.localPath,
    this.sha256,
    this.sourcePath,
  });

  final String id;
  final String name;
  final RequisitionEvidenceType type;
  final DateTime createdAt;
  final String sizeLabel;
  final int byteLength;
  final String? localPath;
  final String? sha256;
  final String? sourcePath;
}

final class RequisitionDetail {
  const RequisitionDetail({
    required this.requisition,
    required this.division,
    required this.subjects,
    required this.sessionId,
    required this.evidence,
  });

  final Requisition requisition;
  final String division;
  final List<String> subjects;
  final String sessionId;
  final List<RequisitionEvidence> evidence;
}
