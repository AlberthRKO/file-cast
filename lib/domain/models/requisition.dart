import 'package:file_cast/domain/models/requisition_creation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'requisition.freezed.dart';

enum RequisitionStatus {
  draft,
  inProgress,
  finalizing,
  finalized,
  cancelled,
}

/// Alias semántico para las coordenadas que llegan en el resumen del listado.
/// El valor se comparte con el formulario de registro y no duplica el modelo.
typedef RequisitionLocation = GeoPoint;

extension RequisitionLocationValidation on GeoPoint {
  bool get isValid =>
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;
}

@freezed
abstract class Requisition with _$Requisition {
  const factory Requisition({
    required String id,
    required String caseName,
    required DateTime registeredAt,
    required RequisitionStatus status,
    required int imageEvidenceCount,
    required int videoEvidenceCount,
    required bool isSynchronized,
    String? cud,
    String? subjectName,
  }) = _Requisition;
}
