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
    final evidence = _asList(
      data['evidences'],
    ).map(_parseEvidence).toList(growable: false);
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
    final subjectDetails = _parseSubjectDetails(
      data['subjects'],
      caseSnapshot,
      primarySubject,
    );
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

  RequisitionEvidence _parseEvidence(Object? raw) {
    final data = _asMap(raw);
    final byteLength = _int(data['byteLength']);
    final urls = _asMap(data['urls']);
    return RequisitionEvidence(
      id: _text(data['id']) ?? '',
      name: _text(data['originalName']) ?? 'Evidencia',
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
      uploadStatus: _text(data['uploadStatus']),
      contentUrl: _text(urls['content']),
      downloadUrl: _text(urls['download']),
    );
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
