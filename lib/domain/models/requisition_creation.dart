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
    required this.subjects,
    required this.officials,
  });

  final int id;
  final String cud;
  final String type;
  final String division;
  final List<String> subjects;
  final List<String> officials;
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
}

final class CreateRequisitionDraft {
  const CreateRequisitionDraft({
    required this.mode,
    required this.procedureAt,
    required this.location,
    this.caseSummary,
    this.personSummary,
  });

  final RequisitionRegistrationMode mode;
  final DateTime procedureAt;
  final GeoPoint location;
  final EcosystemCaseSummary? caseSummary;
  final PersonSummary? personSummary;
}

final class CreateRequisitionResult {
  const CreateRequisitionResult({
    required this.requisitionId,
    required this.sessionId,
  });

  final String requisitionId;
  final String sessionId;
}
