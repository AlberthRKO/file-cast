import 'package:file_cast/data/services/requisition_creation_service.dart';
import 'package:file_cast/domain/models/requisition_creation.dart';
import 'package:file_cast/domain/repositories/requisition_creation_repository.dart';

class RequisitionCreationRepositoryImpl
    implements RequisitionCreationRepository {
  const RequisitionCreationRepositoryImpl({
    required RequisitionCreationService service,
    this.enableFallbackFixtures = false,
  }) : _service = service;

  final RequisitionCreationService _service;
  final bool enableFallbackFixtures;

  @override
  Future<List<EcosystemCaseSummary>> searchCasesByCud(String cud) async {
    try {
      final cases = await _service.searchCasesByCud(cud);
      return cases.map((item) => item.toDomain()).toList(growable: false);
    } catch (_) {
      if (!enableFallbackFixtures) rethrow;
      return _fallbackCases(cud);
    }
  }

  @override
  Future<PersonSummary?> searchPersonByCi(String ci) async {
    try {
      return (await _service.searchPersonByCi(ci))?.toDomain();
    } catch (_) {
      if (!enableFallbackFixtures) rethrow;
      return _fallbackPerson(ci);
    }
  }

  @override
  Future<CreateRequisitionResult> createDraft(CreateRequisitionDraft draft) {
    return _service.createDraft(draft);
  }

  List<EcosystemCaseSummary> _fallbackCases(String cud) {
    if (cud.trim().length < 4) return const [];
    return [
      EcosystemCaseSummary(
        id: 1,
        cud: cud,
        type: 'Denuncia verbal',
        division: 'FELCC - Delitos contra la propiedad',
        subjects: const ['Persona vinculada al expediente'],
        officials: const ['Fiscal asignado principal'],
      ),
    ];
  }

  PersonSummary? _fallbackPerson(String ci) {
    if (ci.trim().length < 4) return null;
    return PersonSummary(
      id: 1515,
      name: 'Alberto Orlando Paredes Mamani',
      ci: ci,
      birthDate: DateTime(1997, 3, 11),
      address: 'C/ Sanandita Nro. 1 - Sucre',
      phone: '79319449',
    );
  }
}
