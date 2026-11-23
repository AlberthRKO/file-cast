import 'dart:io';

import 'package:file_cast/domain/models/requisition_detail.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

final class PickedEvidence {
  const PickedEvidence({
    required this.name,
    required this.type,
    required this.sizeLabel,
    required this.byteLength,
    this.localPath,
    this.mimeType,
    this.ownedPickerCopy = false,
  });
  final String name;
  final RequisitionEvidenceType type;
  final String sizeLabel;
  final int byteLength;
  final String? localPath;
  final String? mimeType;
  final bool ownedPickerCopy;
}

class EvidencePickerService {
  EvidencePickerService({ImagePicker? imagePicker})
    : _imagePicker = imagePicker ?? ImagePicker();

  final ImagePicker _imagePicker;
  final Set<String> _ownedPickerMediaPaths = {};

  Future<PickedEvidence?> pickImage() async {
    final image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image == null) return null;
    final bytes = await File(image.path).length();
    return PickedEvidence(
      name: image.name,
      type: RequisitionEvidenceType.image,
      sizeLabel: _sizeLabel(bytes),
      byteLength: bytes,
      localPath: image.path,
      mimeType: 'image/${image.path.toLowerCase().split('.').last}',
    );
  }

  Future<PickedEvidence?> pickFile() async {
    final files = await pickFiles();
    return files?.firstOrNull;
  }

  Future<List<PickedEvidence>?> pickFiles({
    bool imagesOnly = false,
    bool fromPhotoLibrary = false,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: fromPhotoLibrary
          ? FileType.media
          : imagesOnly
          ? FileType.image
          : FileType.any,
      allowCompression: false,
    );
    if (result == null) return null;

    final picked = <PickedEvidence>[];
    try {
      for (final file in result.files) {
        if (file.path == null) continue;
        final localPath = fromPhotoLibrary && Platform.isIOS
            ? await _moveIosMediaCopyToPersistentDirectory(file.path!)
            : file.path!;
        picked.add(
          _toPickedEvidence(
            file,
            localPath: localPath,
            ownedPickerCopy: _ownedPickerMediaPaths.contains(localPath),
          ),
        );
      }
      return picked;
    } catch (_) {
      await releaseOwnedPickerPaths(picked.map((item) => item.localPath));
      if (fromPhotoLibrary && Platform.isIOS) {
        for (final file in result.files) {
          final path = file.path;
          if (path == null ||
              !File(path).parent.path.endsWith('/Documents/picked_images')) {
            continue;
          }
          try {
            await File(path).delete();
          } on FileSystemException {
            // La copia podría haber sido movida o retirada por el sistema.
          }
        }
      }
      rethrow;
    }
  }

  Future<String> _moveIosMediaCopyToPersistentDirectory(
    String sourcePath,
  ) async {
    final source = File(sourcePath);
    if (!source.parent.path.endsWith('/Documents/picked_images')) {
      return sourcePath;
    }
    // El FCE se escribe junto al archivo fuente. Debe quedar en almacenamiento
    // persistente mientras espera la sincronización offline.
    final directory = Directory(
      '${source.parent.parent.path}/.file_cast_evidence_imports',
    );
    await directory.create(recursive: true);
    await for (final entry in directory.list(followLinks: false)) {
      if (entry is! File ||
          entry.path.endsWith('.fce') ||
          _ownedPickerMediaPaths.contains(entry.path)) {
        continue;
      }
      try {
        await entry.delete();
      } on FileSystemException {
        // Una importación anterior aún podría estar finalizando.
      }
    }
    final destination = File(
      '${directory.path}/${DateTime.now().microsecondsSinceEpoch}-'
      '${_ownedPickerMediaPaths.length}-${source.uri.pathSegments.last}',
    );
    final moved = await source.rename(destination.path);
    _ownedPickerMediaPaths.add(moved.path);
    return moved.path;
  }

  Future<void> releaseOwnedPickerPaths(Iterable<String?> paths) async {
    for (final path in paths) {
      if (path == null || !_ownedPickerMediaPaths.contains(path)) continue;
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
        _ownedPickerMediaPaths.remove(path);
      } on FileSystemException {
        // Se intentará limpiar de nuevo cuando se libere la selección.
      }
    }
  }

  PickedEvidence _toPickedEvidence(
    PlatformFile file, {
    required String localPath,
    required bool ownedPickerCopy,
  }) {
    final extension = file.extension?.toLowerCase();
    final type = switch (extension) {
      'jpg' ||
      'jpeg' ||
      'png' ||
      'webp' ||
      'heic' ||
      'heif' ||
      'gif' ||
      'tif' ||
      'tiff' => RequisitionEvidenceType.image,
      'mp4' ||
      'mov' ||
      'mkv' ||
      'avi' ||
      'webm' ||
      '3gp' ||
      'm4v' ||
      'ts' ||
      'mts' ||
      'm2ts' ||
      'flv' ||
      'wmv' => RequisitionEvidenceType.video,
      'mp3' ||
      'wav' ||
      'aac' ||
      'm4a' ||
      'ogg' ||
      'oga' ||
      'opus' ||
      'flac' ||
      'amr' => RequisitionEvidenceType.audio,
      'pdf' ||
      'doc' ||
      'docx' ||
      'xls' ||
      'xlsx' ||
      'txt' ||
      'csv' ||
      'json' ||
      'xml' ||
      'log' => RequisitionEvidenceType.document,
      _ => RequisitionEvidenceType.other,
    };
    return PickedEvidence(
      name: file.name,
      type: type,
      sizeLabel: _sizeLabel(file.size),
      byteLength: file.size,
      localPath: localPath,
      mimeType: _mimeTypeFor(extension),
      ownedPickerCopy: ownedPickerCopy,
    );
  }

  String _sizeLabel(int bytes) {
    if (bytes >= 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / 1024).ceil()} KB';
  }

  String _mimeTypeFor(String? extension) => switch (extension) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'heic' => 'image/heic',
    'heif' => 'image/heif',
    'gif' => 'image/gif',
    'tif' || 'tiff' => 'image/tiff',
    'mp4' => 'video/mp4',
    'mov' => 'video/quicktime',
    'mkv' => 'video/x-matroska',
    'avi' => 'video/x-msvideo',
    'webm' => 'video/webm',
    '3gp' => 'video/3gpp',
    'm4v' => 'video/x-m4v',
    'ts' => 'video/mp2t',
    'mts' || 'm2ts' => 'video/mp2t',
    'flv' => 'video/x-flv',
    'wmv' => 'video/x-ms-wmv',
    'mp3' => 'audio/mpeg',
    'wav' => 'audio/wav',
    'm4a' => 'audio/mp4',
    'pdf' => 'application/pdf',
    'doc' => 'application/msword',
    'docx' =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    _ => 'application/octet-stream',
  };
}
