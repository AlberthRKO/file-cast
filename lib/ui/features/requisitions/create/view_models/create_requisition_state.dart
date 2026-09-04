import 'package:file_cast/domain/models/requisition_creation.dart';

final class CreateRequisitionState {
  const CreateRequisitionState({
    this.mode = RequisitionRegistrationMode.existingCud,
    this.cudQuery = '',
    this.caseSearchPhase = AsyncPhase.initial,
    this.caseResults = const [],
    this.selectedCase,
    this.personQuery = '',
    this.personSearchPhase = AsyncPhase.initial,
    this.personResults = const [],
    this.selectedPerson,
    this.procedureAt,
    this.location,
    this.submitPhase = AsyncPhase.initial,
    this.errorMessage,
    this.cudError,
    this.personError,
    this.dateError,
    this.locationError,
    this.createdResult,
  });

  final RequisitionRegistrationMode mode;
  final String cudQuery;
  final AsyncPhase caseSearchPhase;
  final List<EcosystemCaseSummary> caseResults;
  final EcosystemCaseSummary? selectedCase;
  final String personQuery;
  final AsyncPhase personSearchPhase;
  final List<PersonSummary> personResults;
  final PersonSummary? selectedPerson;
  final DateTime? procedureAt;
  final GeoPoint? location;
  final AsyncPhase submitPhase;
  final String? errorMessage;
  final String? cudError;
  final String? personError;
  final String? dateError;
  final String? locationError;
  final CreateRequisitionResult? createdResult;

  bool get isSubmitting => submitPhase == AsyncPhase.loading;

  bool get canSubmit =>
      !isSubmitting &&
      procedureAt != null &&
      location != null &&
      switch (mode) {
        RequisitionRegistrationMode.existingCud => selectedCase != null,
        RequisitionRegistrationMode.withoutCud => selectedPerson != null,
      };

  CreateRequisitionState copyWith({
    RequisitionRegistrationMode? mode,
    String? cudQuery,
    AsyncPhase? caseSearchPhase,
    List<EcosystemCaseSummary>? caseResults,
    Object? selectedCase = _sentinel,
    String? personQuery,
    AsyncPhase? personSearchPhase,
    List<PersonSummary>? personResults,
    Object? selectedPerson = _sentinel,
    Object? procedureAt = _sentinel,
    Object? location = _sentinel,
    AsyncPhase? submitPhase,
    Object? errorMessage = _sentinel,
    Object? cudError = _sentinel,
    Object? personError = _sentinel,
    Object? dateError = _sentinel,
    Object? locationError = _sentinel,
    Object? createdResult = _sentinel,
  }) {
    return CreateRequisitionState(
      mode: mode ?? this.mode,
      cudQuery: cudQuery ?? this.cudQuery,
      caseSearchPhase: caseSearchPhase ?? this.caseSearchPhase,
      caseResults: caseResults ?? this.caseResults,
      selectedCase: selectedCase == _sentinel
          ? this.selectedCase
          : selectedCase as EcosystemCaseSummary?,
      personQuery: personQuery ?? this.personQuery,
      personSearchPhase: personSearchPhase ?? this.personSearchPhase,
      personResults: personResults ?? this.personResults,
      selectedPerson: selectedPerson == _sentinel
          ? this.selectedPerson
          : selectedPerson as PersonSummary?,
      procedureAt: procedureAt == _sentinel
          ? this.procedureAt
          : procedureAt as DateTime?,
      location: location == _sentinel ? this.location : location as GeoPoint?,
      submitPhase: submitPhase ?? this.submitPhase,
      errorMessage: errorMessage == _sentinel
          ? this.errorMessage
          : errorMessage as String?,
      cudError: cudError == _sentinel ? this.cudError : cudError as String?,
      personError: personError == _sentinel
          ? this.personError
          : personError as String?,
      dateError: dateError == _sentinel ? this.dateError : dateError as String?,
      locationError: locationError == _sentinel
          ? this.locationError
          : locationError as String?,
      createdResult: createdResult == _sentinel
          ? this.createdResult
          : createdResult as CreateRequisitionResult?,
    );
  }
}

const Object _sentinel = Object();
