import 'dart:io';

import 'package:file_cast/core/errors/either.dart';
import 'package:file_cast/core/network/http.dart';
import 'package:file_cast/data/services/evidence_crypto_service.dart';
import 'package:file_cast/data/services/evidence_key_exchange_service.dart';
import 'package:file_cast/data/services/remote_document_preview_service.dart';
import 'package:file_cast/domain/models/requisition_detail.dart';
import 'package:file_cast/domain/services/evidence_preview_service.dart';

class RemoteEvidencePreviewService implements EvidencePreviewService {
  RemoteEvidencePreviewService({
    required Http http,
    required EvidenceCryptoService crypto,
    required EvidenceKeyExchangeService keyExchange,
    required RemoteDocumentPreviewService documentPreview,
  }) : _http = http,
       _crypto = crypto,
       _keyExchange = keyExchange,
       _documentPreview = documentPreview;

  final Http _http;
  final EvidenceCryptoService _crypto;
  final EvidenceKeyExchangeService _keyExchange;
  final RemoteDocumentPreviewService _documentPreview;

  @override
  Future<PreparedEvidencePreview> prepare(
    RequisitionEvidence evidence,
  ) async {
    var path = evidence.localPath;
    if (path != null && !await File(path).exists()) path = null;
    var isTemporary = false;
    String? resolvedWrappedKey;
    var resolvedWrapAlgorithm = EvidenceCryptoService.localKeyWrapAlgorithm;

    if (evidence.encrypted) {
      resolvedWrappedKey = evidence.wrappedKey;
      if (resolvedWrappedKey == null || resolvedWrappedKey.isEmpty) {
        resolvedWrappedKey = evidence.remoteWrappedKey;
        resolvedWrapAlgorithm =
            evidence.remoteWrapAlgorithm ??
            EvidenceCryptoService.deviceKeyAlgorithm;
      }
      if (resolvedWrappedKey == null || resolvedWrappedKey.isEmpty) {
        final requisitionId = evidence.requisitionId;
        if (requisitionId != null && requisitionId.isNotEmpty) {
          resolvedWrappedKey = await _keyExchange.getEnvelope(
            requisitionId: requisitionId,
            evidenceId: evidence.id,
          );
          if (resolvedWrappedKey != null && resolvedWrappedKey.isNotEmpty) {
            // El endpoint devuelve la envoltura del dispositivo actual, no
            // la envoltura local de la bóveda que solo existía en el teléfono
            // anterior.
            resolvedWrapAlgorithm = EvidenceCryptoService.deviceKeyAlgorithm;
          }
        }
      }
      if (resolvedWrappedKey == null || resolvedWrappedKey.isEmpty) {
        throw StateError(
          'Esta evidencia cifrada no tiene una clave disponible para verla.',
        );
      }
      if (path != null && path.isNotEmpty) {
        path = await _crypto.decryptToTemporaryFile(
          evidenceId: evidence.id,
          encryptedPath: path,
          wrappedKey: resolvedWrappedKey!,
          wrapAlgorithm: resolvedWrapAlgorithm,
          outputPath: _temporaryPathFor(evidence),
          expectedPlaintextSha256: evidence.plaintextSha256,
          expectedPlaintextByteLength: evidence.plaintextByteLength,
        );
        isTemporary = true;
      }
    }

    if (path == null || path.isEmpty) {
      final url = evidence.contentUrl;
      if (url == null || url.isEmpty) {
        throw StateError('La evidencia todavía no tiene contenido disponible.');
      }
      final encryptedPath = await _downloadToTemporaryFile(evidence, url);
      if (evidence.encrypted) {
        if (resolvedWrappedKey == null || resolvedWrappedKey.isEmpty) {
          final requisitionId = evidence.requisitionId;
          if (requisitionId != null && requisitionId.isNotEmpty) {
            resolvedWrappedKey = await _keyExchange.getEnvelope(
              requisitionId: requisitionId,
              evidenceId: evidence.id,
            );
            if (resolvedWrappedKey != null && resolvedWrappedKey.isNotEmpty) {
              resolvedWrapAlgorithm = EvidenceCryptoService.deviceKeyAlgorithm;
            }
          }
        }
        if (resolvedWrappedKey == null || resolvedWrappedKey.isEmpty) {
          await _deleteTemporary(encryptedPath);
          throw StateError(
            'Esta evidencia cifrada no tiene una clave disponible para verla.',
          );
        }
        path = await _crypto.decryptToTemporaryFile(
          evidenceId: evidence.id,
          encryptedPath: encryptedPath,
          wrappedKey: resolvedWrappedKey!,
          wrapAlgorithm: resolvedWrapAlgorithm,
          outputPath: _temporaryPathFor(evidence),
          expectedPlaintextSha256: evidence.plaintextSha256,
          expectedPlaintextByteLength: evidence.plaintextByteLength,
        );
        await _deleteTemporary(encryptedPath);
      } else {
        path = encryptedPath;
      }
      isTemporary = true;
    }

    try {
      String? documentText;
      if (evidence.type == RequisitionEvidenceType.document) {
        documentText = await _documentPreview.extractReadableText(path!);
      }
      return PreparedEvidencePreview(
        path: path!,
        isTemporary: isTemporary,
        documentText: documentText,
      );
    } catch (_) {
      if (isTemporary) await _deleteTemporary(path!);
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
      headers: {
        if (evidence.contentSessionToken != null &&
            evidence.contentSessionToken!.isNotEmpty)
          'x-session-token': evidence.contentSessionToken!,
      },
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
    final downloadedLength = await file.length();
    if (evidence.byteLength > 0 && downloadedLength != evidence.byteLength) {
      await _deleteTemporary(file.path);
      throw StateError(
        'La evidencia descargada está incompleta '
        '(recibido: $downloadedLength, esperado: ${evidence.byteLength}).',
      );
    }
    return file.path;
  }

  String _temporaryPathFor(
    RequisitionEvidence evidence, {
    String? extension,
  }) =>
      '${Directory.systemTemp.path}/file-cast-preview-${evidence.id}-'
      '${DateTime.now().microsecondsSinceEpoch}.${extension ?? _extensionFor(evidence)}';

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
