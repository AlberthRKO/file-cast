import 'package:file_cast/domain/models/requisition_creation.dart';

abstract interface class RequisitionCreationRepository {
  Future<List<EcosystemCaseSummary>> searchCasesByCud(String cud);

  Future<PersonSummary?> searchPersonByCi(String ci);

  Future<CreateRequisitionResult> createDraft(CreateRequisitionDraft draft);
}
