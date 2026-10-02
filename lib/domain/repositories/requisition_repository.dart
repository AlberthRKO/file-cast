import 'package:file_cast/domain/models/requisition.dart';

typedef RequisitionPage = ({
  List<Requisition> items,
  int page,
  int pageCount,
  Map<String, RequisitionLocation> locations,
});

abstract interface class RequisitionRepository {
  Future<RequisitionPage> getRequisitions({
    required int page,
    required int limit,
    String? search,
    RequisitionStatus? status,
  });

  Future<String> createAcquisitionSession({
    required String requisitionId,
    required String sourcePlatform,
    required String transport,
  });

  Future<void> linkCase({
    required String requisitionId,
    required int? externalCaseId,
    required String cud,
    required String type,
    required String division,
    required List<String> subjects,
    required List<String> participants,
  });

  Future<void> finalizeRequisition(String requisitionId);
}
