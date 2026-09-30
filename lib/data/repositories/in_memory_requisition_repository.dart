import 'dart:math' as math;

import 'package:file_cast/domain/models/requisition.dart';
import 'package:file_cast/domain/repositories/requisition_repository.dart';

class InMemoryRequisitionRepository implements RequisitionRepository {
  const InMemoryRequisitionRepository();

  @override
  Future<RequisitionPage> getRequisitions({
    required int page,
    required int limit,
    String? search,
    RequisitionStatus? status,
  }) async {
    final normalizedQuery = search?.trim().toLowerCase() ?? '';
    final filtered = _fixtures().where((item) {
      final matchesQuery =
          normalizedQuery.isEmpty ||
          item.id.toLowerCase().contains(normalizedQuery) ||
          (item.cud?.toLowerCase().contains(normalizedQuery) ?? false) ||
          (item.subjectName?.toLowerCase().contains(normalizedQuery) ??
              false) ||
          item.caseName.toLowerCase().contains(normalizedQuery);
      return matchesQuery && (status == null || item.status == status);
    }).toList();

    final safeLimit = math.max(1, limit);
    final safePage = math.max(1, page);
    final pageCount = (filtered.length / safeLimit).ceil();
    final start = math.min((safePage - 1) * safeLimit, filtered.length);
    final end = math.min(start + safeLimit, filtered.length);
    final pageItems = filtered.sublist(start, end);

    return (
      items: List<Requisition>.unmodifiable(pageItems),
      page: safePage,
      pageCount: pageCount,
      locations: {
        for (final item in pageItems)
          if (item.id.hashCode.isEven)
            item.id: RequisitionLocation(
              latitude: -19.0478 + (item.id.hashCode % 100) / 100000,
              longitude: -65.2592 + (item.id.hashCode % 100) / 100000,
              label: 'Lugar de prueba',
            ),
      },
    );
  }

  @override
  Future<void> finalizeRequisition(String requisitionId) async {
    // This repository remains available for isolated UI previews. Production
    // uses RemoteRequisitionRepository, where the backend performs the seal.
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
