import 'dart:io';

import 'package:file_cast/domain/services/evidence_decryption_service.dart';
import 'package:file_cast/domain/services/evidence_video_thumbnail_service.dart';
import 'package:file_cast/ui/core/widgets/evidence_thumbnail_work_queue.dart';
import 'package:flutter/material.dart';

class EvidenceVideoThumbnail extends StatefulWidget {
  const EvidenceVideoThumbnail({
    required this.localPath,
    required this.evidenceId,
    required this.fileName,
    required this.fallback,
    required this.thumbnailService,
    this.wrappedKey,
    this.plaintextSha256,
    this.plaintextByteLength,
    this.decryptionService,
    super.key,
  });

  final String? localPath;
  final String evidenceId;
  final String fileName;
  final Widget fallback;
  final String? wrappedKey;
  final String? plaintextSha256;
  final int? plaintextByteLength;
  final EvidenceDecryptionService? decryptionService;
  final EvidenceVideoThumbnailService thumbnailService;

  @override
  State<EvidenceVideoThumbnail> createState() => _EvidenceVideoThumbnailState();
}

class _EvidenceVideoThumbnailState extends State<EvidenceVideoThumbnail>
    with AutomaticKeepAliveClientMixin<EvidenceVideoThumbnail> {
  String? _thumbnailPath;
  Future<void>? _loading;
  var _generation = 0;

  @override
  void initState() {
    super.initState();
    _loading = _prepare(_generation);
  }

  @override
  void didUpdateWidget(covariant EvidenceVideoThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.localPath != widget.localPath ||
        oldWidget.wrappedKey != widget.wrappedKey ||
        oldWidget.evidenceId != widget.evidenceId ||
        oldWidget.plaintextSha256 != widget.plaintextSha256 ||
        oldWidget.plaintextByteLength != widget.plaintextByteLength) {
      _thumbnailPath = null;
      _generation++;
      _loading = _prepare(_generation);
    }
  }

  Future<void> _prepare(int generation) async {
    String? cachedThumbnail;
    try {
      cachedThumbnail = await widget.thumbnailService.findCachedThumbnail(
        cacheKey: widget.evidenceId,
      );
    } on Object {
      // La consulta de caché es una optimización: si falla, todavía se puede
      // generar la miniatura desde la copia local.
    }
    if (cachedThumbnail != null && await File(cachedThumbnail).exists()) {
      if (mounted && generation == _generation) {
        setState(() => _thumbnailPath = cachedThumbnail);
      }
      return;
    }

    await EvidenceThumbnailWorkQueue.videos.run(
      () => _prepareWhenScheduled(generation),
    );
  }

  Future<void> _prepareWhenScheduled(int generation) async {
    if (!mounted || generation != _generation) return;
    final encryptedPath = widget.localPath;
    if (encryptedPath == null || !await File(encryptedPath).exists()) return;

    var videoPath = encryptedPath;
    var deleteVideoAfterwards = false;
    try {
      final wrappedKey = widget.wrappedKey;
      if (wrappedKey != null && wrappedKey.isNotEmpty) {
        final decryptionService = widget.decryptionService;
        if (decryptionService == null) {
          throw StateError('No hay un descifrador disponible para el video.');
        }
        videoPath = await decryptionService.decryptToTemporaryFile(
          evidenceId: widget.evidenceId,
          encryptedPath: encryptedPath,
          wrappedKey: wrappedKey,
          outputExtension: _fileExtension(widget.fileName),
          expectedPlaintextSha256: widget.plaintextSha256,
          expectedPlaintextByteLength: widget.plaintextByteLength,
        );
        deleteVideoAfterwards = true;
      }
      final thumbnailPath = await widget.thumbnailService.createThumbnail(
        videoPath: videoPath,
        cacheKey: widget.evidenceId,
      );
      if (mounted && generation == _generation) {
        setState(() => _thumbnailPath = thumbnailPath);
      }
    } finally {
      if (deleteVideoAfterwards) await _delete(videoPath);
    }
  }

  Future<void> _delete(String path) async {
    try {
      await File(path).delete();
    } on FileSystemException {
      // El almacenamiento temporal del sistema retirará el archivo después.
    }
  }

  String? _fileExtension(String fileName) {
    final name = fileName.split('/').last;
    final separator = name.lastIndexOf('.');
    if (separator <= 0 || separator == name.length - 1) return null;
    final extension = name.substring(separator + 1);
    return RegExp(r'^[A-Za-z0-9]{1,10}$').hasMatch(extension)
        ? extension
        : null;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final path = _thumbnailPath;
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
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(
          File(path),
          fit: BoxFit.cover,
          cacheWidth: 480,
          errorBuilder: (context, error, stackTrace) => widget.fallback,
        ),
        const Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0x99000000),
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.play_arrow_rounded, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}
