import 'dart:async';

import 'package:file_cast/domain/models/requisition_creation.dart';
import 'package:file_cast/domain/repositories/requisition_creation_repository.dart';
import 'package:file_cast/ui/features/requisitions/create/view_models/create_requisition_state.dart';
import 'package:flutter/foundation.dart';

class CreateRequisitionViewModel extends ChangeNotifier {
  CreateRequisitionViewModel({
    required RequisitionCreationRepository repository,
    RequisitionRegistrationMode initialMode =
        RequisitionRegistrationMode.existingCud,
  }) : _repository = repository,
       _state = CreateRequisitionState(
         mode: initialMode,
         procedureAt: DateTime.now(),
       );

  final RequisitionCreationRepository _repository;
  Timer? _caseDebounce;
  Timer? _personDebounce;
  int _caseSearchToken = 0;
  int _personSearchToken = 0;

  CreateRequisitionState _state;
  CreateRequisitionState get state => _state;

  void setMode(RequisitionRegistrationMode mode) {
    if (_state.mode == mode) return;
    _emit(
      _state.copyWith(
        mode: mode,
        errorMessage: null,
        cudError: null,
        personError: null,
        createdResult: null,
      ),
    );
  }

  void updateCudQuery(String value) {
    _caseDebounce?.cancel();
    _emit(
      _state.copyWith(
        cudQuery: value,
        selectedCase: null,
        caseResults: const [],
        caseSearchPhase: value.trim().length >= 4
            ? AsyncPhase.loading
            : AsyncPhase.initial,
        cudError: null,
        errorMessage: null,
        createdResult: null,
      ),
    );
    if (value.trim().length < 4) return;
    _caseDebounce = Timer(
      const Duration(milliseconds: 350),
      () => searchCases(),
    );
  }

  Future<void> searchCases() async {
    final query = _state.cudQuery.trim();
    if (query.length < 4) return;
    final token = ++_caseSearchToken;
    _emit(_state.copyWith(caseSearchPhase: AsyncPhase.loading));

    try {
      final results = await _repository.searchCasesByCud(query);
      if (token != _caseSearchToken) return;
      _emit(
        _state.copyWith(
          caseResults: results,
          caseSearchPhase: results.isEmpty
              ? AsyncPhase.empty
              : AsyncPhase.content,
        ),
      );
    } catch (_) {
      if (token != _caseSearchToken) return;
      _emit(
        _state.copyWith(
          caseSearchPhase: AsyncPhase.error,
          cudError: 'No se pudo buscar el CUD.',
        ),
      );
    }
  }

  void selectCase(EcosystemCaseSummary value) {
    _emit(
      _state.copyWith(
        selectedCase: value,
        cudQuery: value.cud,
        caseResults: const [],
        caseSearchPhase: AsyncPhase.content,
        cudError: null,
        createdResult: null,
      ),
    );
  }

  void updatePersonQuery(String value) {
    _personDebounce?.cancel();
    _emit(
      _state.copyWith(
        personQuery: value,
        selectedPerson: null,
        personResults: const [],
        personSearchPhase: value.trim().length >= 4
            ? AsyncPhase.loading
            : AsyncPhase.initial,
        personError: null,
        errorMessage: null,
        createdResult: null,
      ),
    );
    if (value.trim().length < 4) return;
    _personDebounce = Timer(
      const Duration(milliseconds: 350),
      () => searchPerson(),
    );
  }

  Future<void> searchPerson() async {
    final query = _state.personQuery.trim();
    if (query.length < 4) return;
    final token = ++_personSearchToken;
    _emit(_state.copyWith(personSearchPhase: AsyncPhase.loading));

    try {
      final person = await _repository.searchPersonByCi(query);
      if (token != _personSearchToken) return;
      _emit(
        _state.copyWith(
          personResults: person == null ? const [] : [person],
          personSearchPhase: person == null
              ? AsyncPhase.empty
              : AsyncPhase.content,
        ),
      );
    } catch (_) {
      if (token != _personSearchToken) return;
      _emit(
        _state.copyWith(
          personSearchPhase: AsyncPhase.error,
          personError: 'No se pudo buscar la persona.',
        ),
      );
    }
  }

  void selectPerson(PersonSummary value) {
    _emit(
      _state.copyWith(
        selectedPerson: value,
        personQuery: value.ci,
        personResults: const [],
        personSearchPhase: AsyncPhase.content,
        personError: null,
        createdResult: null,
      ),
    );
  }

  void updateProcedureAt(DateTime value) {
    _emit(
      _state.copyWith(
        procedureAt: value,
        dateError: null,
        createdResult: null,
      ),
    );
  }

  void updateLocation(GeoPoint value) {
    _emit(
      _state.copyWith(
        location: value,
        locationError: null,
        createdResult: null,
      ),
    );
  }

  void updateLocationLabel(String value) {
    final current = _state.location;
    final label = value.trim();
    if (current == null) {
      if (label.isEmpty) return;
      _emit(
        _state.copyWith(
          location: GeoPoint(
            latitude: -19.0478,
            longitude: -65.2592,
            label: label,
          ),
          locationError: null,
          createdResult: null,
        ),
      );
      return;
    }
    _emit(
      _state.copyWith(
        location: GeoPoint(
          latitude: current.latitude,
          longitude: current.longitude,
          label: label.isEmpty ? null : label,
        ),
        locationError: null,
        createdResult: null,
      ),
    );
  }

  Future<void> submit() async {
    if (_state.isSubmitting) return;
    final cudError =
        _state.mode == RequisitionRegistrationMode.existingCud &&
            _state.selectedCase == null
        ? 'Selecciona un CUD existente.'
        : null;
    final personError =
        _state.mode == RequisitionRegistrationMode.withoutCud &&
            _state.selectedPerson == null
        ? 'Selecciona una persona.'
        : null;
    final dateError = _state.procedureAt == null
        ? 'Selecciona fecha y hora.'
        : null;
    final locationError = _state.location == null
        ? 'Captura o confirma la ubicacion GPS.'
        : null;

    if (cudError != null ||
        personError != null ||
        dateError != null ||
        locationError != null) {
      _emit(
        _state.copyWith(
          cudError: cudError,
          personError: personError,
          dateError: dateError,
          locationError: locationError,
          submitPhase: AsyncPhase.error,
          errorMessage: null,
        ),
      );
      return;
    }

    _emit(
      _state.copyWith(
        submitPhase: AsyncPhase.loading,
        errorMessage: null,
        createdResult: null,
      ),
    );

    try {
      final result = await _repository.createDraft(
        CreateRequisitionDraft(
          mode: _state.mode,
          caseSummary: _state.selectedCase,
          personSummary: _state.selectedPerson,
          procedureAt: _state.procedureAt!,
          location: _state.location!,
        ),
      );
      _emit(
        _state.copyWith(
          submitPhase: AsyncPhase.content,
          createdResult: result,
        ),
      );
    } catch (_) {
      _emit(
        _state.copyWith(
          submitPhase: AsyncPhase.error,
          errorMessage: 'No se pudo registrar la requisa.',
        ),
      );
    }
  }

  @override
  void dispose() {
    _caseDebounce?.cancel();
    _personDebounce?.cancel();
    super.dispose();
  }

  void _emit(CreateRequisitionState value) {
    _state = value;
    notifyListeners();
  }
}
