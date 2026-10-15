import 'package:file_cast/domain/models/requisition_detail.dart';
import 'package:file_cast/domain/models/evidence_offline_sync.dart';
import 'package:file_cast/domain/models/evidence_upload_progress.dart';

abstract interface class RequisitionDetailRepository {
  Stream<String> get changes;
  Stream<EvidenceUploadProgress> get uploadProgress;
  Stream<EvidenceOfflineSyncProgress> get offlineSyncProgress;
  Future<RequisitionDetail> getDetail(String requisitionId);
  Future<int> syncPendingEvidence();
  Future<EvidenceOfflineSyncResult> syncEvidenceForOffline({
    required String requisitionId,
    required List<RequisitionEvidence> evidence,
  });
  Future<List<ImportedEvidenceDraft>?> pickEvidence({
    required bool imagesOnly,
  });
  Future<RequisitionDetail> addImportedEvidence({
    required String requisitionId,
    required String name,
    required RequisitionEvidenceType type,
    required String sizeLabel,
    required int byteLength,
    String? localPath,
    String? sha256,
    String? sourcePath,
    String? sessionId,
    String? mimeType,
    String? acquisitionMethod,
    bool encrypted = false,
    String? encryptionAlgorithm,
    int? encryptionVersion,
    int? plaintextByteLength,
    String? plaintextSha256,
    String? aadHash,
    String? wrappedKey,
    int? keyVersion,
    bool preserveSource = false,
  });
  Future<RequisitionDetail> addImportedEvidenceBatch({
    required String requisitionId,
    required List<ImportedEvidenceDraft> evidence,
  });
  Future<RequisitionDetail?> importFromDevice({
    required String requisitionId,
    required bool imagesOnly,
    String? sessionId,
  });
}
