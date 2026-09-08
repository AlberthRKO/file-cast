import 'dart:async';

import 'package:file_cast/data/services/evidence_picker_service.dart';
import 'package:file_cast/domain/models/requisition.dart';
import 'package:file_cast/domain/models/requisition_detail.dart';
import 'package:file_cast/domain/repositories/requisition_detail_repository.dart';

class InMemoryRequisitionDetailRepository
    implements RequisitionDetailRepository {
  InMemoryRequisitionDetailRepository({EvidencePickerService? pickerService})
    : _pickerService = pickerService ?? EvidencePickerService();

  final Map<String, List<RequisitionEvidence>> _imported = {};
  final EvidencePickerService _pickerService;
  final StreamController<String> _changesController =
      StreamController<String>.broadcast();

  @override
  Stream<String> get changes => _changesController.stream;

  @override
  Future<RequisitionDetail> getDetail(String requisitionId) async {
    final evidence = [
      ..._fixtures(requisitionId),
      ...?_imported[requisitionId],
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
    final imported = evidence.indexed
        .map((entry) {
          final (index, draft) = entry;
          return RequisitionEvidence(
            id: 'EVI-${timestamp.microsecondsSinceEpoch}-$index',
            name: draft.name,
            type: draft.type,
            createdAt: timestamp,
            sizeLabel: draft.sizeLabel,
            byteLength: draft.byteLength,
            localPath: draft.localPath,
            sha256: draft.sha256,
            sourcePath: draft.sourcePath,
          );
        })
        .toList(growable: false);
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
