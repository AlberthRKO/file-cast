import 'dart:io';

import 'package:file_cast/domain/services/evidence_decryption_service.dart';
import 'package:file_cast/ui/core/widgets/evidence_thumbnail_work_queue.dart';
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

class _EvidenceThumbnailState extends State<EvidenceThumbnail>
    with AutomaticKeepAliveClientMixin<EvidenceThumbnail> {
  String? _previewPath;
  Future<void>? _loading;
  var _generation = 0;

  @override
  void initState() {
    super.initState();
    _loading = _prepare(_generation);
  }

  @override
  void didUpdateWidget(covariant EvidenceThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.localPath != widget.localPath ||
        oldWidget.wrappedKey != widget.wrappedKey ||
        oldWidget.evidenceId != widget.evidenceId ||
        oldWidget.plaintextSha256 != widget.plaintextSha256 ||
        oldWidget.plaintextByteLength != widget.plaintextByteLength) {
      final previous = _previewPath;
      _previewPath = null;
      if (previous != null && previous != oldWidget.localPath) {
        _delete(previous);
      }
      _generation++;
      _loading = _prepare(_generation);
    }
  }

  Future<void> _prepare(int generation) =>
      EvidenceThumbnailWorkQueue.images.run(
        () => _prepareWhenScheduled(generation),
      );

  Future<void> _prepareWhenScheduled(int generation) async {
    if (!mounted || generation != _generation) return;
    final path = widget.localPath;
    if (path == null) return;
    if (!await File(path).exists()) return;
    if (widget.wrappedKey == null) {
      if (mounted && generation == _generation) {
        setState(() => _previewPath = path);
      }
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
    if (mounted && generation == _generation) {
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
    super.build(context);
    final path = _previewPath;
    if (path == null) {
      if (widget.localPath == null) return widget.fallback;
      return FutureBuilder<void>(
        future: _loading,
        builder: (_, snapshot) =>
            snapshot.hasError ||
                snapshot.connectionState == ConnectionState.done
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
      cacheWidth: 480,
      errorBuilder: (context, error, stackTrace) => Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => widget.fallback,
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
