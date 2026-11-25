import 'dart:io';

import 'package:file_cast/domain/models/requisition_detail.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

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
  static const _iosPhotoLibraryChannel = MethodChannel(
    'com.fiscalia.file_cast/evidence_photo_library',
  );
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
    if (fromPhotoLibrary && Platform.isIOS) {
      return _pickIosPhotoLibraryMedia();
    }
    if (fromPhotoLibrary && Platform.isAndroid) {
      return _pickAndroidPhotoLibraryMedia();
    }
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

    return result.files
        .where((file) => file.path != null)
        .map(
          (file) => _toPickedEvidence(
            name: file.name,
            byteLength: file.size,
            localPath: file.path!,
            ownedPickerCopy: false,
          ),
        )
        .toList(growable: false);
  }

  Future<List<PickedEvidence>?> _pickIosPhotoLibraryMedia() async {
    final List<dynamic>? media;
    try {
      media = await _iosPhotoLibraryChannel.invokeListMethod<dynamic>(
        'pickMedia',
      );
    } on PlatformException catch (error) {
      throw StateError(
        error.message ?? 'No se pudieron preparar las fotos y videos.',
      );
    }
    if (media == null || media.isEmpty) return null;

    final picked = <PickedEvidence>[];
    final receivedPaths = <String>[];
    try {
      for (final raw in media) {
        if (raw is! Map) {
          throw const FormatException('Selección de fototeca inválida.');
        }
        final name = raw['name'];
        final localPath = raw['path'];
        final byteLength = raw['size'];
        if (name is! String ||
            name.isEmpty ||
            localPath is! String ||
            localPath.isEmpty ||
            byteLength is! int ||
            byteLength <= 0) {
          throw const FormatException('Archivo de fototeca inválido.');
        }
        _ownedPickerMediaPaths.add(localPath);
        receivedPaths.add(localPath);
        picked.add(
          _toPickedEvidence(
            name: name,
            byteLength: byteLength,
            localPath: localPath,
            ownedPickerCopy: true,
          ),
        );
      }
      return picked;
    } catch (_) {
      await releaseOwnedPickerPaths(receivedPaths);
      rethrow;
    }
  }

  Future<List<PickedEvidence>?> _pickAndroidPhotoLibraryMedia() async {
    final media = await _imagePicker.pickMultipleMedia(
      requestFullMetadata: false,
    );
    if (media.isEmpty) return null;

    final picked = <PickedEvidence>[];
    final movedPaths = <String>[];
    try {
      final directory = Directory(
        '${await getDatabasesPath()}/.file_cast_evidence_imports',
      );
      await directory.create(recursive: true);
      for (final item in media) {
        final source = File(item.path);
        final destination = File(
          '${directory.path}/${DateTime.now().microsecondsSinceEpoch}-'
          '${movedPaths.length}-${source.uri.pathSegments.last}',
        );
        try {
          await source.rename(destination.path);
        } on FileSystemException {
          try {
            await source.copy(destination.path);
            if (await destination.length() != await source.length()) {
              throw StateError('La copia de la galería quedó incompleta.');
            }
            try {
              await source.delete();
            } on FileSystemException {
              // La copia temporal será retirada por Android.
            }
          } catch (_) {
            if (await destination.exists()) await destination.delete();
            rethrow;
          }
        }
        _ownedPickerMediaPaths.add(destination.path);
        movedPaths.add(destination.path);
        final byteLength = await destination.length();
        if (byteLength == 0) {
          throw StateError('Una foto o video seleccionado está vacío.');
        }
        picked.add(
          _toPickedEvidence(
            name: item.name,
            byteLength: byteLength,
            localPath: destination.path,
            ownedPickerCopy: true,
          ),
        );
      }
      return picked;
    } catch (_) {
      await releaseOwnedPickerPaths(movedPaths);
      rethrow;
    }
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

  PickedEvidence _toPickedEvidence({
    required String name,
    required int byteLength,
    required String localPath,
    required bool ownedPickerCopy,
  }) {
    final extension = name.contains('.')
        ? name.split('.').last.toLowerCase()
        : null;
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
      'docm' ||
      'xls' ||
      'xlsx' ||
      'xlsm' ||
      'ppt' ||
      'pptx' ||
      'pptm' ||
      'rtf' ||
      'txt' ||
      'csv' ||
      'tsv' ||
      'json' ||
      'xml' ||
      'log' => RequisitionEvidenceType.document,
      _ => RequisitionEvidenceType.other,
    };
    return PickedEvidence(
      name: name,
      type: type,
      sizeLabel: _sizeLabel(byteLength),
      byteLength: byteLength,
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
    'docm' => 'application/vnd.ms-word.document.macroEnabled.12',
    'xls' => 'application/vnd.ms-excel',
    'xlsx' =>
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'xlsm' => 'application/vnd.ms-excel.sheet.macroEnabled.12',
    'ppt' => 'application/vnd.ms-powerpoint',
    'pptx' =>
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'pptm' => 'application/vnd.ms-powerpoint.presentation.macroEnabled.12',
    'rtf' => 'application/rtf',
    'csv' => 'text/csv',
    'tsv' => 'text/tab-separated-values',
    _ => 'application/octet-stream',
  };
}
