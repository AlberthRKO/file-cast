enum RequisitionRegistrationMode { existingCud, withoutCud }

enum AsyncPhase { initial, loading, content, empty, error }

final class GeoPoint {
  const GeoPoint({
    required this.latitude,
    required this.longitude,
    this.label,
  });

  final double latitude;
  final double longitude;
  final String? label;

  GeoPoint copyWith({
    double? latitude,
    double? longitude,
    String? label,
  }) {
    return GeoPoint(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      label: label ?? this.label,
    );
  }
}

final class EcosystemCaseSummary {
  const EcosystemCaseSummary({
    required this.id,
    required this.cud,
    required this.type,
    required this.division,
    required this.status,
    required this.subjects,
    required this.officials,
    this.caseSubjects = const [],
  });

  final int id;
  final String cud;
  final String type;
  final String division;
  final String status;
  final List<String> subjects;
  final List<String> officials;
  final List<EcosystemSubjectSummary> caseSubjects;
}

final class EcosystemSubjectSummary {
  const EcosystemSubjectSummary({
    required this.name,
    this.personId,
    this.caseSubjectId,
    this.documentNumber,
    this.alias,
    this.role,
    this.subjectTypeColorHex,
    this.subjectTypeId,
    this.subjectTypeLevel,
    this.legalSituationId,
    this.identityReserved = false,
    this.legalEntityName,
    this.snapshot,
  });

  final String name;
  final int? personId;
  final int? caseSubjectId;
  final String? documentNumber;
  final String? alias;
  final String? role;
  final String? subjectTypeColorHex;
  final int? subjectTypeId;
  final int? subjectTypeLevel;
  final int? legalSituationId;
  final bool identityReserved;
  final String? legalEntityName;
  final Map<String, dynamic>? snapshot;

  bool get canAnchor => personId != null;
}

final class PersonSummary {
  const PersonSummary({
    required this.id,
    required this.name,
    required this.ci,
    this.birthDate,
    this.address,
    this.phone,
  });

  final int id;
  final String name;
  final String ci;
  final DateTime? birthDate;
  final String? address;
  final String? phone;

  int get segipPersonaId => id;
}

final class CreateRequisitionDraft {
  const CreateRequisitionDraft({
    required this.id,
    required this.mode,
    required this.procedureAt,
    required this.location,
    this.caseSummary,
    this.personSummary,
  });

  final String id;
  final RequisitionRegistrationMode mode;
  final DateTime procedureAt;
  final GeoPoint location;
  final EcosystemCaseSummary? caseSummary;
  final PersonSummary? personSummary;
}

final class CreateRequisitionResult {
  const CreateRequisitionResult({required this.requisitionId, this.sessionId});

  final String requisitionId;
  final String? sessionId;
}
