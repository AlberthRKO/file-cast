import 'package:file_cast/core/errors/either.dart';
import 'package:file_cast/core/network/http.dart';
import 'package:file_cast/data/models/requisition_creation_dto.dart';

class RequisitionCreationService {
  const RequisitionCreationService({required Http http}) : _http = http;

  final Http _http;

  Future<List<EcosystemCaseDto>> searchCasesByCud(String cud) async {
    final result = await _http.request<List<EcosystemCaseDto>>(
      '/caso/casos/list',
      method: HttpMethod.post,
      body: {
        'size': 5,
        'page': 1,
        'where': {
          'misCasos': false,
          'cud': cud,
          'soloCoincidenciaSujetos': true,
        },
        'orderBy': 'id',
        'orderDirection': 'desc',
      },
      onSucces: (body) {
        final map = body as Map<String, dynamic>;
        final response = map['response'];
        final data = response is Map<String, dynamic>
            ? response['data']
            : const [];
        final list = data is List ? data : const [];
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
      '/supr/persona/detalle/segip',
      method: HttpMethod.post,
      body: {
        'ci': ci,
        'actualizar': false,
      },
      onSucces: (body) {
        final map = body as Map<String, dynamic>;
        final response = map['response'];
        final data = response is Map<String, dynamic> ? response['data'] : null;
        if (data is! Map<String, dynamic>) return null;
        return PersonSummaryDto.fromJson(data);
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
}
