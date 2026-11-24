import 'package:file_cast/domain/models/requisition_detail.dart';
import 'package:file_cast/domain/services/audio_playback_service.dart';
import 'package:file_cast/domain/services/evidence_preview_service.dart';
import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:file_cast/ui/core/widgets/evidence_preview_sheet.dart';
import 'package:flutter/material.dart';

Future<void> showEvidencePreviewDialog({
  required BuildContext context,
  required RequisitionEvidence evidence,
  required Future<PreparedEvidencePreview> Function() prepare,
  required Future<void> Function(PreparedEvidencePreview) disposePreview,
  required AudioPlaybackService audioPlaybackService,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (dialogContext) {
    final windowSize = MediaQuery.sizeOf(dialogContext);
    final availableWidth = windowSize.width - (AppSpace.m * 2);
    final availableHeight = windowSize.height - (AppSpace.m * 2);
    final dialogWidth = availableWidth > 920 ? 920.0 : availableWidth;
    final dialogHeight = availableHeight > 820 ? 820.0 : availableHeight;
    return PopScope(
      canPop: false,
      child: Dialog(
        insetPadding: const EdgeInsets.all(AppSpace.m),
        backgroundColor: Colors.transparent,
        elevation: 12,
        child: SizedBox(
          width: dialogWidth,
          height: dialogHeight,
          child: EvidencePreviewSheet(
            evidence: evidence,
            prepare: prepare,
            disposePreview: disposePreview,
            audioPlaybackService: audioPlaybackService,
          ),
        ),
      ),
    );
  },
);
