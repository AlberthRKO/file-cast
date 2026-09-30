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
    this.sessionId,
    this.mimeType,
    this.acquisitionMethod,
    this.encrypted = false,
    this.encryptionAlgorithm,
    this.encryptionVersion,
    this.plaintextByteLength,
    this.plaintextSha256,
    this.aadHash,
    this.wrappedKey,
    this.keyVersion,
    this.preserveSource = false,
  });

  final String name;
  final RequisitionEvidenceType type;
  final String sizeLabel;
  final int byteLength;
  final String? localPath;
  final String? sha256;
  final String? sourcePath;
  final String? sessionId;
  final String? mimeType;
  final String? acquisitionMethod;
  final bool encrypted;
  final String? encryptionAlgorithm;
  final int? encryptionVersion;
  final int? plaintextByteLength;
  final String? plaintextSha256;
  final String? aadHash;
  final String? wrappedKey;
  final int? keyVersion;
  final bool preserveSource;
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
    this.sessionId,
    this.mimeType,
    this.encrypted = false,
    this.encryptionAlgorithm,
    this.encryptionVersion,
    this.plaintextByteLength,
    this.plaintextSha256,
    this.aadHash,
    this.wrappedKey,
    this.keyVersion,
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
  final String? sessionId;
  final String? mimeType;
  final bool encrypted;
  final String? encryptionAlgorithm;
  final int? encryptionVersion;
  final int? plaintextByteLength;
  final String? plaintextSha256;
  final String? aadHash;
  final String? wrappedKey;
  final int? keyVersion;
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
