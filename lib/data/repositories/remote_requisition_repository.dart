import 'package:file_cast/data/services/requisition_service.dart';
import 'package:file_cast/domain/models/requisition.dart';
import 'package:file_cast/domain/repositories/requisition_repository.dart';

class RemoteRequisitionRepository implements RequisitionRepository {
  const RemoteRequisitionRepository({required RequisitionService service})
    : _service = service;

  final RequisitionService _service;

  @override
  Future<RequisitionPage> getRequisitions({
    required int page,
    required int limit,
    String? search,
    RequisitionStatus? status,
  }) {
    return _service.list(
      page: page,
      limit: limit,
      search: search,
      status: status,
    );
  }

  @override
  Future<void> finalizeRequisition(String requisitionId) {
    return _service.finalizeRequisition(requisitionId);
  }
}
