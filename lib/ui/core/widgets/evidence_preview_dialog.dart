import 'package:file_cast/domain/models/requisition_detail.dart';
import 'package:file_cast/domain/services/audio_playback_service.dart';
import 'package:file_cast/domain/services/evidence_preview_service.dart';
import 'package:file_cast/ui/core/widgets/app_modal_bottom_sheet.dart';
import 'package:file_cast/ui/core/widgets/evidence_preview_sheet.dart';
import 'package:flutter/material.dart';

Future<void> showEvidencePreviewDialog({
  required BuildContext context,
  required RequisitionEvidence evidence,
  required Future<PreparedEvidencePreview> Function() prepare,
  required Future<void> Function(PreparedEvidencePreview) disposePreview,
  required AudioPlaybackService audioPlaybackService,
}) async {
  await showAppModalBottomSheet<void>(
    context: context,
    expand: true,
    useSafeArea: false,
    enableDrag: false,
    isDismissible: false,
    backgroundColor: Colors.transparent,
    builder: (_) => PopScope(
      canPop: false,
      child: EvidencePreviewSheet(
        evidence: evidence,
        prepare: prepare,
        disposePreview: disposePreview,
        audioPlaybackService: audioPlaybackService,
        showHandle: true,
      ),
    ),
  );
}
