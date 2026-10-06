import 'dart:io';

import 'package:file_cast/domain/services/evidence_decryption_service.dart';
import 'package:flutter/material.dart';

class EvidenceThumbnail extends StatefulWidget {
  const EvidenceThumbnail({
    required this.localPath,
    required this.fallback,
    this.evidenceId,
    this.wrappedKey,
    this.plaintextSha256,
    this.plaintextByteLength,
    this.decryptionService,
    super.key,
  });

  final String? localPath;
  final Widget fallback;
  final String? evidenceId;
  final String? wrappedKey;
  final String? plaintextSha256;
  final int? plaintextByteLength;
  final EvidenceDecryptionService? decryptionService;

  @override
  State<EvidenceThumbnail> createState() => _EvidenceThumbnailState();
}

class _EvidenceThumbnailState extends State<EvidenceThumbnail> {
  String? _previewPath;
  Future<void>? _loading;

  @override
  void initState() {
    super.initState();
    _loading = _prepare();
  }

  @override
  void didUpdateWidget(covariant EvidenceThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.localPath != widget.localPath ||
        oldWidget.wrappedKey != widget.wrappedKey) {
      final previous = _previewPath;
      _previewPath = null;
      if (previous != null) _delete(previous);
      _loading = _prepare();
    }
  }

  Future<void> _prepare() async {
    final path = widget.localPath;
    if (path == null) return;
    if (widget.wrappedKey == null) {
      _previewPath = path;
      if (mounted) setState(() {});
      return;
    }
    final decryptionService = widget.decryptionService;
    final evidenceId = widget.evidenceId;
    if (decryptionService == null || evidenceId == null) {
      throw StateError('No hay un descifrador disponible para la evidencia.');
    }
    final decrypted = await decryptionService.decryptToTemporaryFile(
      evidenceId: evidenceId,
      encryptedPath: path,
      wrappedKey: widget.wrappedKey!,
      expectedPlaintextSha256: widget.plaintextSha256,
      expectedPlaintextByteLength: widget.plaintextByteLength,
    );
    if (mounted) {
      setState(() => _previewPath = decrypted);
    } else {
      await _delete(decrypted);
    }
  }

  Future<void> _delete(String path) async {
    try {
      await File(path).delete();
    } on FileSystemException {
      // El temporal se limpia con el almacenamiento temporal del sistema.
    }
  }

  @override
  void dispose() {
    final preview = _previewPath;
    if (preview != null && preview != widget.localPath) _delete(preview);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final path = _previewPath;
    if (path == null) {
      if (widget.localPath == null) return widget.fallback;
      return FutureBuilder<void>(
        future: _loading,
        builder: (_, snapshot) => snapshot.hasError
            ? widget.fallback
            : const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
      );
    }
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => widget.fallback,
    );
  }
}
