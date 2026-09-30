import 'dart:math';

import 'package:file_cast/core/errors/either.dart';
import 'package:file_cast/core/network/http.dart';
import 'package:file_cast/data/models/requisition_creation_dto.dart';
import 'package:file_cast/domain/models/requisition_creation.dart';

class RequisitionCreationService {
  const RequisitionCreationService({required Http http}) : _http = http;

  final Http _http;

  Future<List<EcosystemCaseDto>> searchCasesByCud(String cud) async {
    final result = await _http.request<List<EcosystemCaseDto>>(
      '/api/v1/file-cast/casos/list',
      method: HttpMethod.post,
      body: {
        'size': 5,
        'page': 1,
        'where': {'cud': cud.trim()},
      },
      onSucces: (body) {
        final map = _asMap(body);
        final response = _asMap(map['response']);
        final payload = response['data'];
        final payloadMap = _asMap(payload);
        final list = payload is List
            ? payload
            : payloadMap['data'] is List
            ? payloadMap['data'] as List
            : const [];
        return list
            .whereType<Map<String, dynamic>>()
            .map(EcosystemCaseDto.fromJson)
            .toList(growable: false);
      },
    );

    return switch (result) {
      Left(leftValue: final error) => throw StateError(
        error.message ?? 'No se pudo buscar el CUD.',
      ),
      Right(rightValue: final cases) => cases,
      Either() => throw StateError('Respuesta inesperada al buscar el CUD.'),
    };
  }

  Future<PersonSummaryDto?> searchPersonByCi(String ci) async {
    final result = await _http.request<PersonSummaryDto?>(
      '/api/v1/file-cast/persona/buscar',
      method: HttpMethod.post,
      body: {
        'numeroDocumento': ci.trim(),
        'actualizar': false,
      },
      onSucces: (body) {
        final map = _asMap(body);
        final response = _asMap(map['response']);
        final data = response.containsKey('data') ? response['data'] : response;
        final dataMap = _asMap(data);
        final person = _asMap(dataMap['persona']).isNotEmpty
            ? _asMap(dataMap['persona'])
            : _asMap(dataMap['data']).isNotEmpty
            ? _asMap(dataMap['data'])
            : dataMap;
        if (person.isEmpty && data is List && data.isNotEmpty) {
          return PersonSummaryDto.fromJson(_asMap(data.first));
        }
        if (person.isEmpty) return null;
        return PersonSummaryDto.fromJson(person);
      },
    );

    return switch (result) {
      Left(leftValue: final error) => throw StateError(
        error.message ?? 'No se pudo buscar la persona.',
      ),
      Right(rightValue: final person) => person,
      Either() => throw StateError(
        'Respuesta inesperada al buscar la persona.',
      ),
    };
  }

  Future<CreateRequisitionResult> createDraft(
    CreateRequisitionDraft draft,
  ) async {
    final result = await _http.request<CreateRequisitionResult>(
      '/api/v1/requisitions',
      method: HttpMethod.post,
      headers: {'Idempotency-Key': _idempotencyKey()},
      body: _createBody(draft),
      onSucces: (body) {
        final envelope = _asMap(body);
        final response = _asMap(envelope['response']);
        final data = _asMap(response['data']);
        final requisitionId = _asString(data['id']);
        if (requisitionId == null) {
          throw const FormatException(
            'El backend no devolvió el identificador de la requisa.',
          );
        }
        return CreateRequisitionResult(requisitionId: requisitionId);
      },
    );

    return switch (result) {
      Left(leftValue: final error) => throw StateError(
        error.message ?? 'No se pudo registrar la requisa.',
      ),
      Right(rightValue: final created) => created,
      Either() => throw StateError(
        'Respuesta inesperada al registrar la requisa.',
      ),
    };
  }

  Map<String, dynamic> _createBody(CreateRequisitionDraft draft) {
    final caseSummary = draft.caseSummary;
    final personSummary = draft.personSummary;
    return {
      'originType': draft.mode == RequisitionRegistrationMode.existingCud
          ? 'CASE'
          : 'PERSON',
      'procedureAt': draft.procedureAt.toUtc().toIso8601String(),
      'latitude': draft.location.latitude,
      'longitude': draft.location.longitude,
      if (draft.location.label?.isNotEmpty == true)
        'locationLabel': draft.location.label,
      if (caseSummary != null)
        'caseLink': {
          if (caseSummary.id > 0) 'externalCaseId': caseSummary.id,
          'cud': caseSummary.cud,
          'snapshot': {
            'type': caseSummary.type,
            'division': caseSummary.division,
            'subjects': caseSummary.subjects,
            'officials': caseSummary.officials,
          },
        },
      if (personSummary != null)
        'subject': {
          if (personSummary.id > 0) 'externalPersonId': personSummary.id,
          'documentNumber': personSummary.ci,
          'fullName': personSummary.name,
          if (personSummary.birthDate != null)
            'birthDate': personSummary.birthDate!.toUtc().toIso8601String(),
          if (personSummary.address?.isNotEmpty == true)
            'address': personSummary.address,
          if (personSummary.phone?.isNotEmpty == true)
            'phone': personSummary.phone,
        },
    };
  }

  String _idempotencyKey() {
    final suffix = Random.secure().nextInt(0x7fffffff).toRadixString(36);
    return 'create-requisition-${DateTime.now().microsecondsSinceEpoch}-$suffix';
  }

  static Map<String, dynamic> _asMap(Object? value) {
    return value is Map<String, dynamic> ? value : const {};
  }

  static String? _asString(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}
