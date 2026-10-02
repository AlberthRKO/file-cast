import 'dart:math';

import 'package:file_cast/core/errors/either.dart';
import 'package:file_cast/core/network/http.dart';
import 'package:file_cast/domain/models/requisition.dart';
import 'package:file_cast/domain/repositories/requisition_repository.dart';

class RequisitionService {
  RequisitionService({required Http http}) : _http = http;

  final Http _http;
  final Random _random = Random.secure();

  Future<RequisitionPage> list({
    required int page,
    required int limit,
    String? search,
    RequisitionStatus? status,
  }) async {
    final result = await _http.request<RequisitionPage>(
      '/api/v1/requisitions',
      queryParameters: {
        'page': page.toString(),
        'limit': limit.toString(),
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (status != null) 'status': _statusValue(status),
      },
      onSucces: _parsePage,
    );

    return switch (result) {
      Left(leftValue: final error) => throw StateError(
        error.message ?? 'No se pudo cargar las requisas.',
      ),
      Right(rightValue: final requisitions) => requisitions,
      Either() => throw StateError('Respuesta inesperada al listar requisas.'),
    };
  }

  Future<void> finalizeRequisition(String requisitionId) async {
    final result = await _http.request<void>(
      '/api/v1/requisitions/$requisitionId/finalize',
      method: HttpMethod.post,
      headers: {
        'Idempotency-Key': _idempotencyKey('finalize', requisitionId),
      },
      onSucces: (_) {},
    );

    switch (result) {
      case Left(leftValue: final error):
        throw StateError(
          error.message ?? 'No se pudo finalizar la requisa.',
        );
      case Right():
        return;
      case Either():
        throw StateError('Respuesta inesperada al finalizar la requisa.');
    }
  }

  Future<void> linkCase({
    required String requisitionId,
    required int? externalCaseId,
    required String cud,
    required String type,
    required String division,
    required List<String> subjects,
    required List<String> participants,
  }) async {
    final result = await _http.request<void>(
      '/api/v1/requisitions/$requisitionId/case-links',
      method: HttpMethod.post,
      headers: {
        'Idempotency-Key': _idempotencyKey('link-case', requisitionId),
      },
      body: {
        if (externalCaseId != null && externalCaseId > 0)
          'externalCaseId': externalCaseId,
        'cud': cud,
        'snapshot': {
          'type': type,
          'division': division,
          'subjects': subjects,
          'officials': participants,
        },
      },
      onSucces: (_) {},
    );

    switch (result) {
      case Left(leftValue: final error):
        throw StateError(error.message ?? 'No se pudo vincular el CUD.');
      case Right():
        return;
      case Either():
        throw StateError('Respuesta inesperada al vincular el CUD.');
    }
  }

  Future<String> createAcquisitionSession({
    required String requisitionId,
    required String sourcePlatform,
    required String transport,
  }) async {
    final result = await _http.request<String>(
      '/api/v1/requisitions/$requisitionId/sessions',
      method: HttpMethod.post,
      headers: {'Idempotency-Key': _idempotencyKey('session', requisitionId)},
      body: {
        'sourcePlatform': sourcePlatform,
        'transport': transport,
        'capabilities': {
          'canMirror': sourcePlatform == 'ANDROID',
          'canControl': sourcePlatform == 'ANDROID',
          'canCaptureScreenshot': sourcePlatform == 'ANDROID',
          'canRecordScreen': sourcePlatform == 'ANDROID',
          'canBrowseSharedFiles': sourcePlatform == 'ANDROID',
        },
      },
      onSucces: (body) {
        final envelope = _asMap(body);
        final response = _asMap(envelope['response']);
        final data = _asMap(response['data']);
        final sessionId = _asString(data['id']);
        if (sessionId == null) {
          throw const FormatException(
            'El backend no devolvió el identificador de la sesión.',
          );
        }
        return sessionId;
      },
    );

    return switch (result) {
      Left(leftValue: final error) => throw StateError(
        error.message ?? 'No se pudo abrir la sesión de adquisición.',
      ),
      Right(rightValue: final sessionId) => sessionId,
      Either() => throw StateError(
        'Respuesta inesperada al abrir la sesión de adquisición.',
      ),
    };
  }

  RequisitionPage _parsePage(dynamic body) {
    final envelope = _asMap(body);
    final response = _asMap(envelope['response']);
    final data = response['data'];
    final pagination = _asMap(response['pagination']);
    final locations = <String, RequisitionLocation>{};
    final items = <Requisition>[];
    if (data is List) {
      for (final rawItem in data.whereType<Map<String, dynamic>>()) {
        final item = _toDomain(rawItem);
        items.add(item);
        final location = _locationFrom(rawItem);
        if (location != null && location.isValid) {
          locations[item.id] = location;
        }
      }
    }

    return (
      items: List<Requisition>.unmodifiable(items),
      page: _asInt(pagination['page'], fallback: 1),
      pageCount: _asInt(pagination['pageCount']),
      locations: Map<String, RequisitionLocation>.unmodifiable(locations),
    );
  }

  Requisition _toDomain(Map<String, dynamic> json) {
    final currentCase = _asMap(json['currentCase']);
    final primarySubject = _asMap(json['primarySubject']);
    final description = _asString(json['description']);
    final cud = _asString(currentCase['cud']);
    final subjectName = _asString(primarySubject['fullName']);
    final evidenceCounts = _asMap(json['evidenceCounts']);

    return Requisition(
      id: _asString(json['id']) ?? '',
      caseName:
          description ??
          (cud != null ? 'Requisa vinculada a caso' : 'Requisa por persona'),
      registeredAt:
          _asDate(json['procedureAt']) ??
          _asDate(json['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      status: _statusFromApi(json['status']),
      imageEvidenceCount: _asInt(evidenceCounts['images']),
      videoEvidenceCount: _asInt(evidenceCounts['videos']),
      isSynchronized: true,
      cud: cud,
      subjectName: subjectName,
    );
  }

  RequisitionLocation? _locationFrom(Map<String, dynamic> json) {
    final latitude = _asDouble(json['latitude']);
    final longitude = _asDouble(json['longitude']);
    if (latitude == null || longitude == null) return null;
    return RequisitionLocation(
      latitude: latitude,
      longitude: longitude,
      label: _asString(json['locationLabel']),
    );
  }

  String _idempotencyKey(String operation, String requisitionId) {
    final suffix = _random.nextInt(0x7fffffff).toRadixString(36);
    return '$operation-$requisitionId-${DateTime.now().microsecondsSinceEpoch}-$suffix';
  }

  String _statusValue(RequisitionStatus status) => switch (status) {
    RequisitionStatus.draft => 'DRAFT',
    RequisitionStatus.inProgress => 'IN_PROGRESS',
    RequisitionStatus.finalizing => 'FINALIZING',
    RequisitionStatus.finalized => 'SEALED',
    RequisitionStatus.cancelled => 'CANCELLED',
  };

  RequisitionStatus _statusFromApi(Object? value) {
    return switch (value?.toString().toUpperCase()) {
      'DRAFT' => RequisitionStatus.draft,
      'IN_PROGRESS' => RequisitionStatus.inProgress,
      'FINALIZING' => RequisitionStatus.finalizing,
      'SEALED' => RequisitionStatus.finalized,
      'CANCELLED' => RequisitionStatus.cancelled,
      _ => RequisitionStatus.draft,
    };
  }

  static Map<String, dynamic> _asMap(Object? value) {
    return value is Map<String, dynamic> ? value : const {};
  }

  static String? _asString(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static int _asInt(Object? value, {int fallback = 0}) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static DateTime? _asDate(Object? value) {
    return DateTime.tryParse(_asString(value) ?? '')?.toLocal();
  }
}
