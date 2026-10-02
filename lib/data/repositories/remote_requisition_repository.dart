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
  Future<String> createAcquisitionSession({
    required String requisitionId,
    required String sourcePlatform,
    required String transport,
  }) {
    return _service.createAcquisitionSession(
      requisitionId: requisitionId,
      sourcePlatform: sourcePlatform,
      transport: transport,
    );
  }

  @override
  Future<void> linkCase({
    required String requisitionId,
    required int? externalCaseId,
    required String cud,
    required String type,
    required String division,
    required List<String> subjects,
    required List<String> participants,
  }) {
    return _service.linkCase(
      requisitionId: requisitionId,
      externalCaseId: externalCaseId,
      cud: cud,
      type: type,
      division: division,
      subjects: subjects,
      participants: participants,
    );
  }

  @override
  Future<void> finalizeRequisition(String requisitionId) {
    return _service.finalizeRequisition(requisitionId);
  }
}
