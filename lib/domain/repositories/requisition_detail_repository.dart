import 'package:file_cast/domain/models/requisition_detail.dart';

abstract interface class RequisitionDetailRepository {
  Stream<String> get changes;
  Future<RequisitionDetail> getDetail(String requisitionId);
  Future<RequisitionDetail> addImportedEvidence({
    required String requisitionId,
    required String name,
    required RequisitionEvidenceType type,
    required String sizeLabel,
    required int byteLength,
    String? localPath,
    String? sha256,
    String? sourcePath,
  });
  Future<RequisitionDetail> addImportedEvidenceBatch({
    required String requisitionId,
    required List<ImportedEvidenceDraft> evidence,
  });
  Future<RequisitionDetail?> importFromDevice({
    required String requisitionId,
    required bool imagesOnly,
  });
}
