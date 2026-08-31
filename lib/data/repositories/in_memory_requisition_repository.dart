import 'package:file_cast/domain/models/requisition.dart';
import 'package:file_cast/domain/repositories/requisition_repository.dart';

class InMemoryRequisitionRepository implements RequisitionRepository {
  const InMemoryRequisitionRepository();

  @override
  Future<List<Requisition>> getRequisitions() async {
    return List<Requisition>.unmodifiable(_fixtures());
  }

  List<Requisition> _fixtures() {
    const cases = [
      'Robo calificado',
      'Portación de arma',
      'Hurto de dispositivo móvil',
      'Estafa informática',
      'Amenazas y coacción',
      'Tenencia de drogas',
    ];
    const people = [
      'Roberto Sánchez Mora',
      'Analía Torres Vega',
      'Marcelo Ruiz Salazar',
      'Valeria Cortez Lima',
    ];

    return List<Requisition>.generate(24, (index) {
      final hasCud = index % 5 != 2;
      final status = index % 3 == 0
          ? RequisitionStatus.inProgress
          : RequisitionStatus.finalized;
      final dayOffset = index * 2;

      return Requisition(
        id: 'REQ-2026-${(89 + index).toString().padLeft(3, '0')}',
        cud: hasCud
            ? '71010209260${(140 + index).toString().padLeft(3, '0')}'
            : null,
        subjectName: hasCud ? null : people[index % people.length],
        caseName: cases[index % cases.length],
        registeredAt: DateTime(2026, 8, 28).subtract(
          Duration(days: dayOffset, hours: index % 7),
        ),
        status: status,
        imageEvidenceCount: 2 + (index % 10),
        videoEvidenceCount: index % 5,
        isSynchronized: index % 7 != 0,
      );
    });
  }
}
