import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:file_cast/data/services/evidence_picker_service.dart';
import 'package:file_cast/data/services/evidence_crypto_service.dart';
import 'package:file_cast/data/services/local_evidence_database_service.dart';
import 'package:file_cast/domain/models/requisition.dart';
import 'package:file_cast/domain/models/requisition_detail.dart';
import 'package:file_cast/domain/repositories/requisition_detail_repository.dart';

class InMemoryRequisitionDetailRepository
    implements RequisitionDetailRepository {
  InMemoryRequisitionDetailRepository({
    EvidencePickerService? pickerService,
    EvidenceCryptoService? cryptoService,
    LocalEvidenceDatabaseService? database,
  }) : _pickerService = pickerService ?? EvidencePickerService(),
       _cryptoService = cryptoService,
       _database = database;

  final Map<String, List<RequisitionEvidence>> _imported = {};
  final EvidencePickerService _pickerService;
  final EvidenceCryptoService? _cryptoService;
  final LocalEvidenceDatabaseService? _database;
  final StreamController<String> _changesController =
      StreamController<String>.broadcast();
  final Random _random = Random.secure();

  @override
  Stream<String> get changes => _changesController.stream;

  @override
  Future<RequisitionDetail> getDetail(String requisitionId) async {
    final persisted =
        await _database?.forRequisition(requisitionId) ??
        const <LocalEvidenceRecord>[];
    final imported = _imported[requisitionId] ?? const <RequisitionEvidence>[];
    final evidence = [
      ..._fixtures(requisitionId),
      ...imported,
      ...persisted
          .where((item) => !imported.any((evidence) => evidence.id == item.id))
          .map(_toEvidence),
    ];
    return RequisitionDetail(
      requisition: Requisition(
        id: requisitionId,
        cud: '710102092600140',
        caseName: 'Robo calificado',
        registeredAt: DateTime(2026, 8, 28, 10),
        status: RequisitionStatus.inProgress,
        imageEvidenceCount: evidence
            .where((e) => e.type == RequisitionEvidenceType.image)
            .length,
        videoEvidenceCount: evidence
            .where((e) => e.type == RequisitionEvidenceType.video)
            .length,
        isSynchronized: false,
      ),
      division: 'FELCC – Delitos contra la propiedad',
      subjects: const ['Roberto Sánchez Mora', 'María Quispe Flores'],
      sessionId: 'SES-$requisitionId',
      evidence: evidence,
    );
  }

  @override
  Future<RequisitionDetail> addImportedEvidence({
    required String requisitionId,
    required String name,
    required RequisitionEvidenceType type,
    required String sizeLabel,
    required int byteLength,
    String? localPath,
    String? sha256,
    String? sourcePath,
    String? sessionId,
    String? mimeType,
    String? acquisitionMethod,
    bool encrypted = false,
    String? encryptionAlgorithm,
    int? encryptionVersion,
    int? plaintextByteLength,
    String? plaintextSha256,
    String? aadHash,
    String? wrappedKey,
    int? keyVersion,
    bool preserveSource = false,
  }) async {
    return addImportedEvidenceBatch(
      requisitionId: requisitionId,
      evidence: [
        ImportedEvidenceDraft(
          name: name,
          type: type,
          sizeLabel: sizeLabel,
          byteLength: byteLength,
          localPath: localPath,
          sha256: sha256,
          sourcePath: sourcePath,
          sessionId: sessionId,
          mimeType: mimeType,
          acquisitionMethod: acquisitionMethod,
          encrypted: encrypted,
          encryptionAlgorithm: encryptionAlgorithm,
          encryptionVersion: encryptionVersion,
          plaintextByteLength: plaintextByteLength,
          plaintextSha256: plaintextSha256,
          aadHash: aadHash,
          wrappedKey: wrappedKey,
          keyVersion: keyVersion,
          preserveSource: preserveSource,
        ),
      ],
    );
  }

  @override
  Future<RequisitionDetail> addImportedEvidenceBatch({
    required String requisitionId,
    required List<ImportedEvidenceDraft> evidence,
  }) async {
    final timestamp = DateTime.now();
    final imported = <RequisitionEvidence>[];
    for (final draft in evidence) {
      final evidenceId = _uuid();
      final normalized = await _encryptDraftIfNeeded(
        evidenceId: evidenceId,
        draft: draft,
      );
      if (normalized.encrypted &&
          normalized.localPath != null &&
          normalized.sha256 != null &&
          normalized.plaintextSha256 != null &&
          normalized.encryptionAlgorithm != null &&
          normalized.encryptionVersion != null &&
          normalized.aadHash != null &&
          normalized.wrappedKey != null &&
          normalized.keyVersion != null &&
          normalized.mimeType != null) {
        await _database?.saveEvidence(
          LocalEvidenceRecord(
            id: evidenceId,
            requisitionId: requisitionId,
            sessionId: normalized.sessionId ?? '',
            originalName: normalized.name,
            mimeType: normalized.mimeType!,
            type: _backendKind(normalized.type),
            acquisitionMethod: normalized.acquisitionMethod ?? 'IMPORTED_FILE',
            encryptedPath: normalized.localPath!,
            plaintextByteLength:
                normalized.plaintextByteLength ?? normalized.byteLength,
            ciphertextByteLength: normalized.byteLength,
            plaintextSha256: normalized.plaintextSha256!,
            ciphertextSha256: normalized.sha256!,
            encryptionAlgorithm: normalized.encryptionAlgorithm!,
            encryptionVersion: normalized.encryptionVersion!,
            aadHash: normalized.aadHash!,
            wrappedKey: normalized.wrappedKey!,
            keyVersion: normalized.keyVersion!,
            state: 'PENDIENTE',
            clientOperationId: _uuid(),
            createdAt: timestamp,
            sourcePath: normalized.sourcePath,
          ),
        );
      }
      imported.add(
        RequisitionEvidence(
          id: evidenceId,
          name: normalized.name,
          type: normalized.type,
          createdAt: timestamp,
          sizeLabel: normalized.sizeLabel,
          byteLength: normalized.byteLength,
          localPath: normalized.localPath,
          sha256: normalized.sha256,
          sourcePath: normalized.sourcePath,
          sessionId: normalized.sessionId,
          mimeType: normalized.mimeType,
          encrypted: normalized.encrypted,
          encryptionAlgorithm: normalized.encryptionAlgorithm,
          encryptionVersion: normalized.encryptionVersion,
          plaintextByteLength: normalized.plaintextByteLength,
          plaintextSha256: normalized.plaintextSha256,
          aadHash: normalized.aadHash,
          wrappedKey: normalized.wrappedKey,
          keyVersion: normalized.keyVersion,
        ),
      );
    }
    _imported.update(
      requisitionId,
      (items) => [...items, ...imported],
      ifAbsent: () => imported,
    );
    _changesController.add(requisitionId);
    return getDetail(requisitionId);
  }

  @override
  Future<RequisitionDetail?> importFromDevice({
    required String requisitionId,
    required bool imagesOnly,
    String? sessionId,
  }) async {
    final picked = imagesOnly
        ? await _pickerService.pickImage()
        : await _pickerService.pickFile();
    if (picked == null) return null;
    return addImportedEvidence(
      requisitionId: requisitionId,
      name: picked.name,
      type: picked.type,
      sizeLabel: picked.sizeLabel,
      byteLength: picked.byteLength,
      localPath: picked.localPath,
      mimeType: picked.mimeType,
      acquisitionMethod: 'IMPORTED_FILE',
      sessionId: sessionId,
      preserveSource: true,
    );
  }

  Future<ImportedEvidenceDraft> _encryptDraftIfNeeded({
    required String evidenceId,
    required ImportedEvidenceDraft draft,
  }) async {
    final path = draft.localPath;
    final crypto = _cryptoService;
    if (draft.encrypted || path == null || crypto == null) return draft;
    final sourcePath = draft.preserveSource
        ? '${path}.filecast-staging-${DateTime.now().microsecondsSinceEpoch}'
        : path;
    if (draft.preserveSource) await File(path).copy(sourcePath);
    late final EncryptedEvidenceLocal encrypted;
    try {
      encrypted = await crypto.encryptEvidence(
        evidenceId: evidenceId,
        inputPath: sourcePath,
        originalName: draft.name,
        mimeType: draft.mimeType ?? 'application/octet-stream',
      );
    } catch (_) {
      if (draft.preserveSource) {
        try {
          await File(sourcePath).delete();
        } on FileSystemException {
          // El staging se limpiará con el almacenamiento temporal del sistema.
        }
      }
      rethrow;
    }
    return ImportedEvidenceDraft(
      name: encrypted.name,
      type: draft.type,
      sizeLabel: _formatSize(encrypted.byteLength),
      byteLength: encrypted.byteLength,
      localPath: encrypted.localPath,
      sha256: encrypted.sha256,
      sourcePath: draft.sourcePath,
      sessionId: draft.sessionId,
      mimeType: encrypted.mimeType,
      acquisitionMethod: draft.acquisitionMethod,
      encrypted: true,
      encryptionAlgorithm: encrypted.encryptionAlgorithm,
      encryptionVersion: encrypted.encryptionVersion,
      plaintextByteLength: encrypted.plaintextByteLength,
      plaintextSha256: encrypted.plaintextSha256,
      aadHash: encrypted.aadHash,
      wrappedKey: encrypted.wrappedKey,
      keyVersion: encrypted.keyVersion,
      preserveSource: false,
    );
  }

  String _backendKind(RequisitionEvidenceType type) => switch (type) {
    RequisitionEvidenceType.image => 'IMAGE',
    RequisitionEvidenceType.video => 'VIDEO',
    RequisitionEvidenceType.audio => 'AUDIO',
    RequisitionEvidenceType.document => 'DOCUMENT',
    RequisitionEvidenceType.other => 'OTHER',
  };

  String _formatSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).ceil()} KB';
  }

  String _uuid() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  RequisitionEvidence _toEvidence(LocalEvidenceRecord record) {
    final type = switch (record.type) {
      'IMAGE' => RequisitionEvidenceType.image,
      'VIDEO' => RequisitionEvidenceType.video,
      'AUDIO' => RequisitionEvidenceType.audio,
      'DOCUMENT' => RequisitionEvidenceType.document,
      _ => RequisitionEvidenceType.other,
    };
    return RequisitionEvidence(
      id: record.id,
      name: record.originalName,
      type: type,
      createdAt: record.createdAt,
      sizeLabel: _formatSize(record.ciphertextByteLength),
      byteLength: record.ciphertextByteLength,
      localPath: record.encryptedPath,
      sha256: record.ciphertextSha256,
      sourcePath: record.sourcePath,
      sessionId: record.sessionId,
      mimeType: record.mimeType,
      encrypted: true,
      encryptionAlgorithm: record.encryptionAlgorithm,
      encryptionVersion: record.encryptionVersion,
      plaintextByteLength: record.plaintextByteLength,
      plaintextSha256: record.plaintextSha256,
      aadHash: record.aadHash,
      wrappedKey: record.wrappedKey,
      keyVersion: record.keyVersion,
    );
  }

  List<RequisitionEvidence> _fixtures(String requisitionId) => [
    ...List.generate(
      7,
      (index) => RequisitionEvidence(
        id: '$requisitionId-image-$index',
        name: index == 0
            ? 'Captura inicial.png'
            : 'Evidencia fotográfica ${index + 1}.png',
        type: RequisitionEvidenceType.image,
        createdAt: DateTime(2026, 8, 28, 10, 4 + index),
        sizeLabel: '${(1.2 + index / 10).toStringAsFixed(1)} MB',
        byteLength: 1200000 + index * 100000,
      ),
    ),
    ...List.generate(
      6,
      (index) => RequisitionEvidence(
        id: '$requisitionId-video-$index',
        name: index == 0
            ? 'Video de procedimiento.mp4'
            : 'Grabación de pantalla ${index + 1}.mp4',
        type: RequisitionEvidenceType.video,
        createdAt: DateTime(2026, 8, 28, 10, 18 + index),
        sizeLabel: '${24 + index * 3}.6 MB',
        byteLength: 24600000 + index * 3000000,
      ),
    ),
    ...List.generate(
      8,
      (index) => RequisitionEvidence(
        id: '$requisitionId-document-$index',
        name: index == 0
            ? 'Acta de intervención.pdf'
            : 'Documento adjunto ${index + 1}.pdf',
        type: RequisitionEvidenceType.document,
        createdAt: DateTime(2026, 8, 28, 10, 30 + index),
        sizeLabel: '${480 + index * 35} KB',
        byteLength: (480 + index * 35) * 1024,
      ),
    ),
    ...List.generate(
      3,
      (index) => RequisitionEvidence(
        id: '$requisitionId-audio-$index',
        name: index == 0 ? 'Entrevista.mp3' : 'Audio ${index + 1}.m4a',
        type: RequisitionEvidenceType.audio,
        createdAt: DateTime(2026, 8, 28, 10, 42 + index),
        sizeLabel: '${(1.4 + index / 2).toStringAsFixed(1)} MB',
        byteLength: 1400000 + index * 500000,
      ),
    ),
  ];
}
