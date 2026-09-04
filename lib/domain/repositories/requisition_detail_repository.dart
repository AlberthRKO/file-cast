import 'package:file_cast/domain/models/requisition_detail.dart';

abstract interface class RequisitionDetailRepository {
  Future<RequisitionDetail> getDetail(String requisitionId);
  Future<RequisitionDetail> addImportedEvidence({
    required String requisitionId,
    required String name,
    required RequisitionEvidenceType type,
    required String sizeLabel,
    required int byteLength,
  });
  Future<RequisitionDetail?> importFromDevice({
    required String requisitionId,
    required bool imagesOnly,
  });
}
