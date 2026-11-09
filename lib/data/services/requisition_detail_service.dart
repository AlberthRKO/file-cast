import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'package:file_cast/core/errors/either.dart';
import 'package:file_cast/core/network/http.dart';
import 'package:file_cast/domain/models/requisition.dart';
import 'package:file_cast/domain/models/requisition_detail.dart';

/// Cliente HTTP del detalle de una requisa.
///
/// El backend devuelve el detalle dentro de `response.data`; este servicio
/// convierte ese DTO en modelos de dominio antes de entregarlo al repositorio.
class RequisitionDetailService {
  const RequisitionDetailService({required Http http}) : _http = http;

  final Http _http;

  Future<RequisitionDetail> getDetail(String requisitionId) async {
    final result = await _http.request<RequisitionDetail>(
      '/api/v1/requisitions/$requisitionId',
      onSucces: _parseDetail,
    );

    return switch (result) {
      Left(leftValue: final error) => throw StateError(
        error.message ?? 'No se pudo cargar el detalle de la requisa.',
      ),
      Right(rightValue: final detail) => detail,
      Either() => throw StateError(
        'Respuesta inesperada al cargar el detalle de la requisa.',
      ),
    };
  }

  Future<void> deleteEvidence({
    required String requisitionId,
    required String evidenceId,
  }) async {
    final result = await _http.request<void>(
      '/api/v1/requisitions/$requisitionId/evidences/$evidenceId',
      method: HttpMethod.delete,
      headers: {
        'Idempotency-Key': 'delete-evidence-$requisitionId-$evidenceId',
      },
      onSucces: (_) {},
    );

    switch (result) {
      case Left(leftValue: final error):
        throw StateError(
          error.message ?? 'No se pudo eliminar la evidencia del servidor.',
        );
      case Right():
        return;
      case Either():
        throw StateError(
          'Respuesta inesperada al eliminar la evidencia del servidor.',
        );
    }
  }

  Future<RequisitionEvidence> renameEvidence({
    required String requisitionId,
    required String evidenceId,
    required String displayName,
  }) async {
    final result = await _http.request<RequisitionEvidence>(
      '/api/v1/requisitions/$requisitionId/evidences/$evidenceId/name',
      method: HttpMethod.patch,
      headers: {
        'Idempotency-Key':
            'rename-evidence-$requisitionId-$evidenceId-'
            '${crypto.sha256.convert(utf8.encode(displayName.trim())).toString().substring(0, 24)}',
      },
      body: {'displayName': displayName.trim()},
      onSucces: (body) {
        final envelope = _asMap(body);
        final response = _asMap(envelope['response']);
        final data = _asMap(response['data']);
        return _parseEvidence(data, requisitionId, const []);
      },
    );
    return switch (result) {
      Left(leftValue: final error) => throw StateError(
        error.message ?? 'No se pudo cambiar el nombre de la evidencia.',
      ),
      Right(rightValue: final evidence) => evidence,
      Either() => throw StateError(
        'Respuesta inesperada al cambiar el nombre.',
      ),
    };
  }

  Future<RequisitionEvidence> setEvidenceSubjects({
    required String requisitionId,
    required String evidenceId,
    required List<int> personIds,
  }) async {
    final result = await _http.request<RequisitionEvidence>(
      '/api/v1/requisitions/$requisitionId/evidences/$evidenceId/subjects',
      method: HttpMethod.put,
      headers: {
        'Idempotency-Key': 'evidence-subjects-$requisitionId-$evidenceId',
      },
      body: {'personIds': personIds},
      onSucces: (body) {
        final envelope = _asMap(body);
        final response = _asMap(envelope['response']);
        final data = _asMap(response['data']);
        return _parseEvidence(data, requisitionId, const []);
      },
    );
    return switch (result) {
      Left(leftValue: final error) => throw StateError(
        error.message ??
            'No se pudieron actualizar los sujetos de la evidencia.',
      ),
      Right(rightValue: final evidence) => evidence,
      Either() => throw StateError(
        'Respuesta inesperada al actualizar sujetos.',
      ),
    };
  }

  RequisitionDetail _parseDetail(dynamic body) {
    final envelope = _asMap(body);
    final response = _asMap(envelope['response']);
    final data = _asMap(response['data']);
    if (data.isEmpty) {
      throw const FormatException(
        'El backend no devolvió datos para la requisa.',
      );
    }

    final currentCase = _asMap(data['currentCase']);
    final primarySubject = _asMap(data['primarySubject']);
    final caseSnapshot = _asMap(currentCase['snapshot']);
    final requisitionId = _text(data['id']) ?? '';
    final caseSubjects = _parseCaseSubjects(data['caseSubjects']);
    final evidence = _asList(data['evidences'])
        .map((item) => _parseEvidence(item, requisitionId, caseSubjects))
        .toList(growable: false);
    final sessions = _asList(
      data['sessions'],
    ).map(_parseSession).toList(growable: false);
    RequisitionAcquisitionSession? currentSession;
    for (final session in sessions) {
      if (session.isOpen) {
        currentSession = session;
        break;
      }
    }
    final subjectDetails = caseSubjects.isNotEmpty
        ? caseSubjects
        : _parseSubjectDetails(data['subjects'], caseSnapshot, primarySubject);
    final subjects = subjectDetails
        .map((subject) => subject.name)
        .toList(growable: false);
    final participants = _parseParticipants(data['accesses']);
    final cud = _text(currentCase['cud']);
    final description = _text(data['description']);
    final caseName =
        _text(caseSnapshot['type']) ??
        description ??
        (cud == null ? 'Requisa por persona' : 'Caso vinculado');
    final division =
        _text(caseSnapshot['division']) ??
        _text(primarySubject['subjectRole']) ??
        'Sin división registrada';
    final evidenceCounts = _asMap(data['evidenceCounts']);
    final imageCount = _int(
      evidenceCounts['images'],
      fallback: evidence
          .where((item) => item.type == RequisitionEvidenceType.image)
          .length,
    );
    final videoCount = _int(
      evidenceCounts['videos'],
      fallback: evidence
          .where((item) => item.type == RequisitionEvidenceType.video)
          .length,
    );

    return RequisitionDetail(
      requisition: Requisition(
        id: _text(data['id']) ?? '',
        caseName: caseName,
        registeredAt:
            _date(data['procedureAt']) ??
            _date(data['createdAt']) ??
            DateTime.fromMillisecondsSinceEpoch(0),
        status: _status(data['status']),
        imageEvidenceCount: imageCount,
        videoEvidenceCount: videoCount,
        isSynchronized: evidence.every(
          (item) => item.uploadStatus == 'AVAILABLE',
        ),
        cud: cud,
        subjectName: _text(primarySubject['fullName']),
      ),
      division: division,
      subjects: subjects,
      subjectDetails: subjectDetails,
      caseSubjects: caseSubjects.isNotEmpty ? caseSubjects : subjectDetails,
      participants: participants,
      sessionId: currentSession?.id ?? '',
      evidence: evidence,
      sessions: sessions,
      description: description,
      procedureAt: _date(data['procedureAt']),
      locationLabel: _text(data['locationLabel']),
      latitude: _double(data['latitude']),
      longitude: _double(data['longitude']),
      version: _int(data['version'], fallback: 1),
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
    );
  }

  RequisitionEvidence _parseEvidence(
    Object? raw,
    String requisitionId,
    List<RequisitionSubjectSummary> caseSubjects,
  ) {
    final data = _asMap(raw);
    final byteLength = _int(data['byteLength']);
    final evidenceId = _text(data['id']) ?? '';
    final uploadStatus = _text(data['uploadStatus']);
    final isAvailable = uploadStatus?.toUpperCase() == 'AVAILABLE';
    final contentUrl = isAvailable && evidenceId.isNotEmpty
        ? '/api/v1/requisitions/${Uri.encodeComponent(requisitionId)}'
              '/evidences/${Uri.encodeComponent(evidenceId)}/content'
        : null;
    return RequisitionEvidence(
      id: evidenceId,
      isBackendRecord: true,
      requisitionId: requisitionId,
      name: _text(data['originalName']) ?? 'Evidencia',
      displayName: _text(data['displayName']),
      linkedSubjects: _parseLinkedSubjects(
        data['linkedSubjects'],
        caseSubjects,
      ),
      type: _evidenceType(data['kind']),
      createdAt:
          _date(data['capturedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      sizeLabel: _formatSize(byteLength),
      byteLength: byteLength,
      sha256: _text(data['sha256']),
      sourcePath: _text(data['sourcePath']),
      mimeType: _text(data['mimeType']),
      encrypted: _text(data['encryptionStatus']) == 'CLIENT_SIDE',
      encryptionAlgorithm: _text(data['encryptionAlgorithm']),
      encryptionVersion: _intOrNull(data['encryptionVersion']),
      plaintextByteLength: _intOrNull(data['plaintextByteLength']),
      plaintextSha256: _text(data['plaintextSha256']),
      uploadStatus: uploadStatus,
      contentUrl: contentUrl,
      downloadUrl: contentUrl,
    );
  }

  List<RequisitionEvidenceSubject> _parseLinkedSubjects(
    Object? raw,
    List<RequisitionSubjectSummary> caseSubjects,
  ) {
    final byPersonId = <int, RequisitionSubjectSummary>{
      for (final subject in caseSubjects)
        if (subject.personId != null) subject.personId!: subject,
    };
    return _asList(raw)
        .map((value) {
          final item = _asMap(value);
          final personId = _intOrNull(item['personId']);
          if (personId == null) return null;
          final subject = byPersonId[personId];
          return RequisitionEvidenceSubject(
            personId: personId,
            name: subject?.name ?? 'Persona $personId',
            documentNumber: subject?.documentNumber,
            source: _text(item['source']),
          );
        })
        .whereType<RequisitionEvidenceSubject>()
        .toList(growable: false);
  }

  List<RequisitionSubjectSummary> _parseCaseSubjects(Object? raw) {
    return _asList(raw)
        .map((value) {
          final item = _asMap(value);
          final person = _asMap(item['person']);
          final entity = _asMap(
            item['legalEntity'] ?? item['legalEntitySnapshot'],
          );
          final personId = _intOrNull(item['personId']);
          final name =
              _text(item['personFullName']) ??
              _text(person['nombreCompleto']) ??
              _text(entity['razonSocial']) ??
              _text(entity['nombre']) ??
              'Sujeto procesal';
          return RequisitionSubjectSummary(
            name: name,
            documentNumber:
                _text(item['personDocumentNumber']) ?? _text(person['ci']),
            role: _text(item['subjectTypeName']),
            personId: personId,
            caseSubjectId: _intOrNull(item['caseSubjectId']),
            alias: _text(item['alias']),
            identityReserved: item['identityReserved'] == true,
            subjectTypeColorHex: _text(item['subjectTypeColorHex']),
            subjectTypeLevel: _intOrNull(item['subjectTypeLevel']),
            subjectTypeId: _intOrNull(item['subjectTypeId']),
            legalSituationId: _intOrNull(item['legalSituationId']),
            legalEntityName:
                _text(entity['razonSocial']) ?? _text(entity['nombre']),
            currentSubjectState: _text(item['currentSubjectState']),
            snapshot: item['snapshot'] is Map<String, dynamic>
                ? item['snapshot'] as Map<String, dynamic>
                : null,
          );
        })
        .toList(growable: false);
  }

  RequisitionAcquisitionSession _parseSession(Object? raw) {
    final data = _asMap(raw);
    return RequisitionAcquisitionSession(
      id: _text(data['id']) ?? '',
      status: _sessionStatus(data['status']),
      sourcePlatform: _text(data['sourcePlatform']) ?? 'UNKNOWN',
      transport: _text(data['transport']) ?? 'UNKNOWN',
      startedAt:
          _date(data['startedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      endedAt: _date(data['endedAt']),
    );
  }

  List<RequisitionSubjectSummary> _parseSubjectDetails(
    Object? rawSubjects,
    Map<String, dynamic> caseSnapshot,
    Map<String, dynamic> primarySubject,
  ) {
    final subjects = <RequisitionSubjectSummary>[];
    for (final raw in _asList(caseSnapshot['subjects'])) {
      final item = _asMap(raw);
      final name = raw is String ? _text(raw) : _text(item['fullName']);
      if (name != null) {
        subjects.add(
          RequisitionSubjectSummary(
            name: name,
            documentNumber: _text(item['documentNumber']),
            role: _text(item['subjectRole']),
          ),
        );
      }
    }
    if (subjects.isNotEmpty) return List.unmodifiable(subjects);

    for (final raw in _asList(rawSubjects)) {
      final item = _asMap(raw);
      final name = _text(item['fullName']);
      if (name != null) {
        subjects.add(
          RequisitionSubjectSummary(
            name: name,
            documentNumber: _text(item['documentNumber']),
            role: _text(item['subjectRole']),
          ),
        );
      }
    }
    if (subjects.isNotEmpty) return List.unmodifiable(subjects);
    final fallback = _text(primarySubject['fullName']);
    if (subjects.isEmpty && fallback != null) {
      subjects.add(
        RequisitionSubjectSummary(
          name: fallback,
          documentNumber: _text(primarySubject['documentNumber']),
          role: _text(primarySubject['subjectRole']),
        ),
      );
    }
    return List.unmodifiable(subjects);
  }

  List<RequisitionParticipantSummary> _parseParticipants(Object? raw) {
    final participants = <RequisitionParticipantSummary>[];
    for (final value in _asList(raw)) {
      final item = _asMap(value);
      final actorId = _text(item['actorId']);
      if (actorId != null) {
        participants.add(
          RequisitionParticipantSummary(
            actorId: actorId,
            role: _text(item['role']) ?? 'PARTICIPANTE',
            fullName: _text(item['fullName']),
            documentNumber: _text(item['documentNumber']),
          ),
        );
      }
    }
    return List.unmodifiable(participants);
  }

  RequisitionStatus _status(Object? value) =>
      switch (value?.toString().toUpperCase()) {
        'DRAFT' => RequisitionStatus.draft,
        'IN_PROGRESS' => RequisitionStatus.inProgress,
        'FINALIZING' => RequisitionStatus.finalizing,
        'SEALED' => RequisitionStatus.finalized,
        'CANCELLED' => RequisitionStatus.cancelled,
        _ => RequisitionStatus.draft,
      };

  RequisitionSessionStatus _sessionStatus(Object? value) =>
      switch (value?.toString().toUpperCase()) {
        'OPEN' => RequisitionSessionStatus.open,
        'COMPLETED' => RequisitionSessionStatus.completed,
        'FAILED' => RequisitionSessionStatus.failed,
        'CANCELLED' => RequisitionSessionStatus.cancelled,
        _ => RequisitionSessionStatus.failed,
      };

  RequisitionEvidenceType _evidenceType(Object? value) =>
      switch (value?.toString().toUpperCase()) {
        'IMAGE' => RequisitionEvidenceType.image,
        'VIDEO' => RequisitionEvidenceType.video,
        'AUDIO' => RequisitionEvidenceType.audio,
        'DOCUMENT' => RequisitionEvidenceType.document,
        _ => RequisitionEvidenceType.other,
      };

  String _formatSize(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '$bytes B';
  }

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  static List<Object?> _asList(Object? value) {
    return value is List ? List<Object?>.from(value) : const [];
  }

  static String? _text(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static int _int(Object? value, {int fallback = 0}) {
    if (value is num) return value.toInt();
    return int.tryParse(_text(value) ?? '') ?? fallback;
  }

  static int? _intOrNull(Object? value) {
    if (value == null) return null;
    return _int(value);
  }

  static double? _double(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(_text(value) ?? '');
  }

  static DateTime? _date(Object? value) {
    return DateTime.tryParse(_text(value) ?? '')?.toLocal();
  }
}
