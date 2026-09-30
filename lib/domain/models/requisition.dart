import 'package:freezed_annotation/freezed_annotation.dart';

part 'requisition.freezed.dart';

enum RequisitionStatus {
  draft,
  inProgress,
  finalizing,
  finalized,
  cancelled,
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
