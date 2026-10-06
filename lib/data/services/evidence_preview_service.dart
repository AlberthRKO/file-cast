import 'dart:io';

import 'package:file_cast/core/errors/either.dart';
import 'package:file_cast/core/network/http.dart';
import 'package:file_cast/data/services/evidence_crypto_service.dart';
import 'package:file_cast/data/services/remote_document_preview_service.dart';
import 'package:file_cast/domain/models/requisition_detail.dart';
import 'package:file_cast/domain/services/evidence_preview_service.dart';

class RemoteEvidencePreviewService implements EvidencePreviewService {
  RemoteEvidencePreviewService({
    required Http http,
    required EvidenceCryptoService crypto,
    required RemoteDocumentPreviewService documentPreview,
  }) : _http = http,
       _crypto = crypto,
       _documentPreview = documentPreview;

  final Http _http;
  final EvidenceCryptoService _crypto;
  final RemoteDocumentPreviewService _documentPreview;

  @override
  Future<PreparedEvidencePreview> prepare(
    RequisitionEvidence evidence,
  ) async {
    var path = evidence.localPath;
    var isTemporary = false;

    if (path != null && evidence.encrypted) {
      final wrappedKey = evidence.wrappedKey;
      if (wrappedKey == null || wrappedKey.isEmpty) {
        throw StateError(
          'Esta evidencia cifrada no tiene una clave local disponible para verla.',
        );
      }
      path = await _crypto.decryptToTemporaryFile(
        evidenceId: evidence.id,
        encryptedPath: path,
        wrappedKey: wrappedKey,
        outputPath: _temporaryPathFor(evidence),
        expectedPlaintextSha256: evidence.plaintextSha256,
        expectedPlaintextByteLength: evidence.plaintextByteLength,
      );
      isTemporary = true;
    }

    if (path == null || path.isEmpty) {
      final url = evidence.contentUrl;
      if (url == null || url.isEmpty) {
        throw StateError('La evidencia todavía no tiene contenido disponible.');
      }
      if (evidence.encrypted) {
        throw StateError(
          'La evidencia cifrada solo puede verse desde el dispositivo que conserva su clave local.',
        );
      }
      path = await _downloadToTemporaryFile(evidence, url);
      isTemporary = true;
    }

    try {
      String? documentText;
      if (evidence.type == RequisitionEvidenceType.document) {
        documentText = await _documentPreview.extractReadableText(path);
      }
      return PreparedEvidencePreview(
        path: path,
        isTemporary: isTemporary,
        documentText: documentText,
      );
    } catch (_) {
      if (isTemporary) await _deleteTemporary(path);
      rethrow;
    }
  }

  @override
  Future<void> disposePreview(PreparedEvidencePreview preview) async {
    if (!preview.isTemporary) return;
    await _deleteTemporary(preview.path);
  }

  Future<String> _downloadToTemporaryFile(
    RequisitionEvidence evidence,
    String url,
  ) async {
    final result = await _http.request<List<int>>(
      url,
      isFileV2: true,
      timeOut: const Duration(seconds: 60),
      onSucces: (body) => body is List<int>
          ? body
          : throw StateError('La respuesta de la evidencia no es un archivo.'),
    );
    final bytes = switch (result) {
      Left(leftValue: final error) => throw StateError(
        error.message ?? 'No se pudo descargar la evidencia.',
      ),
      Right(rightValue: final body) => body,
      Either() => throw StateError(
        'Respuesta inesperada al descargar la evidencia.',
      ),
    };
    final extension = _extensionFor(evidence);
    final file = File(_temporaryPathFor(evidence, extension: extension));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  String _temporaryPathFor(
    RequisitionEvidence evidence, {
    String? extension,
  }) =>
      '${Directory.systemTemp.path}/file-cast-preview-${evidence.id}.${extension ?? _extensionFor(evidence)}';

  Future<void> _deleteTemporary(String path) async {
    try {
      await File(path).delete();
    } on FileSystemException {
      // El temporal puede ser retirado por el sistema operativo más tarde.
    }
  }

  String _extensionFor(RequisitionEvidence evidence) {
    final name = evidence.name.trim();
    final dot = name.lastIndexOf('.');
    if (dot >= 0 && dot < name.length - 1) {
      return name.substring(dot + 1).toLowerCase();
    }
    final mime = evidence.mimeType ?? '';
    if (mime == 'application/pdf') return 'pdf';
    if (mime.startsWith('image/')) return mime.substring(6);
    if (mime.startsWith('video/')) return mime.substring(6);
    if (mime.startsWith('audio/')) return mime.substring(6);
    return 'bin';
  }
}
