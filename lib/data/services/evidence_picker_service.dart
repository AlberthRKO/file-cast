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
  });
  final String name;
  final RequisitionEvidenceType type;
  final String sizeLabel;
  final int byteLength;
  final String? localPath;
  final String? mimeType;
}

class EvidencePickerService {
  EvidencePickerService({ImagePicker? imagePicker})
    : _imagePicker = imagePicker ?? ImagePicker();

  final ImagePicker _imagePicker;

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

  Future<List<PickedEvidence>?> pickFiles({bool imagesOnly = false}) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: imagesOnly ? FileType.image : FileType.any,
    );
    if (result == null) return null;

    return result.files
        .where((file) => file.path != null)
        .map(_toPickedEvidence)
        .toList(growable: false);
  }

  PickedEvidence _toPickedEvidence(PlatformFile file) {
    final extension = file.extension?.toLowerCase();
    final type = switch (extension) {
      'jpg' || 'jpeg' || 'png' || 'webp' => RequisitionEvidenceType.image,
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
      localPath: file.path,
      mimeType: _mimeTypeFor(extension),
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
