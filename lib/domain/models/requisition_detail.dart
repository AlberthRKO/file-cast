import 'package:file_cast/domain/models/requisition.dart';

enum RequisitionEvidenceType { image, video, audio, document, other }

enum RequisitionSessionStatus { open, completed, failed, cancelled }

final class RequisitionSubjectSummary {
  const RequisitionSubjectSummary({
    required this.name,
    this.documentNumber,
    this.role,
  });

  final String name;
  final String? documentNumber;
  final String? role;
}

final class RequisitionParticipantSummary {
  const RequisitionParticipantSummary({
    required this.actorId,
    required this.role,
  });

  final String actorId;
  final String role;
}

final class RequisitionAcquisitionSession {
  const RequisitionAcquisitionSession({
    required this.id,
    required this.status,
    required this.sourcePlatform,
    required this.transport,
    required this.startedAt,
    this.endedAt,
  });

  final String id;
  final RequisitionSessionStatus status;
  final String sourcePlatform;
  final String transport;
  final DateTime startedAt;
  final DateTime? endedAt;

  bool get isOpen => status == RequisitionSessionStatus.open;
}

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

  ImportedEvidenceDraft copyWith({
    String? sessionId,
    bool? preserveSource,
  }) {
    return ImportedEvidenceDraft(
      name: name,
      type: type,
      sizeLabel: sizeLabel,
      byteLength: byteLength,
      localPath: localPath,
      sha256: sha256,
      sourcePath: sourcePath,
      sessionId: sessionId ?? this.sessionId,
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
      preserveSource: preserveSource ?? this.preserveSource,
    );
  }
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
    this.uploadStatus,
    this.contentUrl,
    this.downloadUrl,
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
  final String? uploadStatus;
  final String? contentUrl;
  final String? downloadUrl;
}

final class RequisitionDetail {
  const RequisitionDetail({
    required this.requisition,
    required this.division,
    required this.subjects,
    required this.sessionId,
    required this.evidence,
    this.sessions = const [],
    this.subjectDetails = const [],
    this.participants = const [],
    this.description,
    this.procedureAt,
    this.locationLabel,
    this.latitude,
    this.longitude,
    this.version = 1,
    this.createdAt,
    this.updatedAt,
  });

  final Requisition requisition;
  final String division;
  final List<String> subjects;
  final List<RequisitionSubjectSummary> subjectDetails;
  final List<RequisitionParticipantSummary> participants;
  final String sessionId;
  final List<RequisitionEvidence> evidence;
  final List<RequisitionAcquisitionSession> sessions;
  final String? description;
  final DateTime? procedureAt;
  final String? locationLabel;
  final double? latitude;
  final double? longitude;
  final int version;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  RequisitionLocation? get location {
    final lat = latitude;
    final lng = longitude;
    if (lat == null || lng == null) return null;
    final value = RequisitionLocation(
      latitude: lat,
      longitude: lng,
      label: locationLabel,
    );
    return value.isValid ? value : null;
  }
}
