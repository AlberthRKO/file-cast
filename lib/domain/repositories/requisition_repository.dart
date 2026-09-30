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

  Future<void> finalizeRequisition(String requisitionId);
}
