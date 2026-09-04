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
  });
  final String name;
  final RequisitionEvidenceType type;
  final String sizeLabel;
  final int byteLength;
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
    );
  }

  Future<PickedEvidence?> pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    final file = result?.files.singleOrNull;
    if (file == null) return null;
    final extension = file.extension?.toLowerCase();
    final type = switch (extension) {
      'jpg' || 'jpeg' || 'png' || 'webp' => RequisitionEvidenceType.image,
      'mp4' || 'mov' || 'mkv' => RequisitionEvidenceType.video,
      'mp3' ||
      'wav' ||
      'aac' ||
      'm4a' ||
      'ogg' => RequisitionEvidenceType.audio,
      'pdf' ||
      'doc' ||
      'docx' ||
      'xls' ||
      'xlsx' ||
      'txt' => RequisitionEvidenceType.document,
      _ => RequisitionEvidenceType.other,
    };
    return PickedEvidence(
      name: file.name,
      type: type,
      sizeLabel: _sizeLabel(file.size),
      byteLength: file.size,
    );
  }

  String _sizeLabel(int bytes) {
    if (bytes >= 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / 1024).ceil()} KB';
  }
}
