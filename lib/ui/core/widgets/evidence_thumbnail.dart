import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_cast/domain/services/evidence_image_thumbnail_service.dart';
import 'package:file_cast/ui/core/widgets/evidence_thumbnail_work_queue.dart';
import 'package:flutter/material.dart';

class EvidenceThumbnail extends StatefulWidget {
  const EvidenceThumbnail({
    required this.localPath,
    required this.evidenceId,
    required this.fallback,
    required this.thumbnailService,
    this.wrappedKey,
    this.plaintextSha256,
    this.plaintextByteLength,
    super.key,
  });

  final String? localPath;
  final Widget fallback;
  final String evidenceId;
  final String? wrappedKey;
  final String? plaintextSha256;
  final int? plaintextByteLength;
  final EvidenceImageThumbnailService thumbnailService;

  @override
  State<EvidenceThumbnail> createState() => _EvidenceThumbnailState();
}

class _EvidenceThumbnailState extends State<EvidenceThumbnail> {
  String? _previewPath;
  Uint8List? _thumbnailBytes;
  bool _ownsPreviewPath = false;
  Future<void>? _loading;
  var _generation = 0;

  @override
  void initState() {
    super.initState();
    _loading = _prepareWithVisibleDeadline(_generation);
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
      final owned = _ownsPreviewPath;
      _previewPath = null;
      _thumbnailBytes = null;
      _ownsPreviewPath = false;
      if (previous != null && owned) {
        unawaited(widget.thumbnailService.deleteFallback(previous));
      }
      _generation++;
      _loading = _prepareWithVisibleDeadline(_generation);
    }
  }

  Future<void> _prepareWithVisibleDeadline(int generation) =>
      _prepare(generation).timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          // Deja tiempo a la primera generación y a la cola compartida.
          // Un decoder atascado no debe dejar el indicador indefinidamente.
        },
      );

  Future<void> _prepare(int generation) {
    final path = widget.localPath;
    if (path == null) return Future<void>.value();
    final wrappedKey = widget.wrappedKey;
    if (wrappedKey == null) {
      _previewPath = path;
      return Future<void>.value();
    }
    final cached = widget.thumbnailService.findCachedThumbnail(
      evidenceId: widget.evidenceId,
      encryptedPath: path,
      plaintextSha256: widget.plaintextSha256,
      plaintextByteLength: widget.plaintextByteLength,
    );
    if (cached != null) {
      _thumbnailBytes = cached;
      return Future<void>.value();
    }
    return EvidenceThumbnailWorkQueue.images.run(
      () => _prepareWhenScheduled(generation),
    );
  }

  Future<void> _prepareWhenScheduled(int generation) async {
    if (!mounted || generation != _generation) return;
    final path = widget.localPath;
    if (path == null) return;
    final bytes = await widget.thumbnailService.loadThumbnail(
      evidenceId: widget.evidenceId,
      encryptedPath: path,
      wrappedKey: widget.wrappedKey!,
      plaintextSha256: widget.plaintextSha256,
      plaintextByteLength: widget.plaintextByteLength,
    );
    if (bytes != null) {
      if (mounted && generation == _generation) {
        setState(() => _thumbnailBytes = bytes);
      }
      return;
    }
    final decrypted = await widget.thumbnailService.decryptForFallback(
      evidenceId: widget.evidenceId,
      encryptedPath: path,
      wrappedKey: widget.wrappedKey!,
      plaintextSha256: widget.plaintextSha256,
      plaintextByteLength: widget.plaintextByteLength,
    );
    if (mounted && generation == _generation) {
      setState(() {
        _previewPath = decrypted;
        _ownsPreviewPath = true;
      });
    } else {
      await widget.thumbnailService.deleteFallback(decrypted);
    }
  }

  @override
  void dispose() {
    final preview = _previewPath;
    if (preview != null && _ownsPreviewPath) {
      unawaited(widget.thumbnailService.deleteFallback(preview));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _thumbnailBytes;
    final path = _previewPath;
    if (path == null && bytes == null) {
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final cacheWidth = constraints.hasBoundedWidth
            ? (constraints.maxWidth * MediaQuery.devicePixelRatioOf(context))
                  .ceil()
                  .clamp(1, 480)
                  .toInt()
            : 480;
        if (bytes != null) {
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            cacheWidth: cacheWidth,
            errorBuilder: (context, error, stackTrace) => widget.fallback,
          );
        }
        return Image.file(
          File(path!),
          fit: BoxFit.cover,
          cacheWidth: cacheWidth,
          errorBuilder: (context, error, stackTrace) => Image.file(
            File(path),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => widget.fallback,
          ),
        );
      },
    );
  }
}
