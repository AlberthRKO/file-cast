import 'package:file_cast/domain/models/requisition_detail.dart';
import 'package:file_cast/domain/services/evidence_decryption_service.dart';
import 'package:file_cast/ui/core/feedback/app_feedback.dart';
import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:file_cast/ui/core/widgets/app_modal_bottom_sheet.dart';
import 'package:file_cast/ui/core/widgets/evidence_rename_sheet.dart';
import 'package:file_cast/ui/core/widgets/evidence_sync_badge.dart';
import 'package:file_cast/ui/core/widgets/evidence_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

typedef RenameMirrorEvidence =
    Future<String?> Function(RequisitionEvidence evidence, String displayName);

/// Evidence browser shared by individual and multi-mirror acquisition.
class MirrorEvidencePane extends StatelessWidget {
  const MirrorEvidencePane({
    required this.evidence,
    required this.totalEvidence,
    required this.compact,
    required this.onClose,
    required this.onRename,
    this.contextLabel,
    super.key,
  });

  final List<RequisitionEvidence> evidence;
  final int totalEvidence;
  final bool compact;
  final VoidCallback onClose;
  final RenameMirrorEvidence onRename;
  final String? contextLabel;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.all(AppSpace.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user_outlined, size: AppSize.iconM),
              const SizedBox(width: AppSpace.s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Evidencia registrada ($totalEvidence)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if (contextLabel != null)
                      Text(
                        contextLabel!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onClose,
                tooltip: 'Ocultar evidencias',
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s),
          Expanded(
            child: evidence.isEmpty
                ? const _EmptyEvidenceState()
                : compact
                ? ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: evidence.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: AppSpace.s),
                    itemBuilder: (context, index) => SizedBox(
                      width: 150,
                      child: _EvidenceCard(
                        key: ValueKey(evidence[index].id),
                        evidence: evidence[index],
                        onRename: () =>
                            _renameEvidence(context, evidence[index]),
                      ),
                    ),
                  )
                : GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: AppSpace.s,
                          mainAxisSpacing: AppSpace.s,
                          childAspectRatio: 1.2,
                        ),
                    itemCount: evidence.length,
                    itemBuilder: (context, index) => _EvidenceCard(
                      key: ValueKey(evidence[index].id),
                      evidence: evidence[index],
                      onRename: () => _renameEvidence(context, evidence[index]),
                    ),
                  ),
          ),
        ],
      ),
    ),
  );

  Future<void> _renameEvidence(
    BuildContext context,
    RequisitionEvidence item,
  ) async {
    final result = await showAppModalBottomSheet<Object?>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      maxWidth: AppSize.formMaxWidth,
      builder: (_) => EvidenceRenameSheet(
        currentName: item.effectiveName,
        originalName: item.name,
        onSave: (name) => onRename(item, name),
      ),
    );
    if (!context.mounted) return;
    if (result is String) {
      await showAppErrorBottomSheet(context, result);
      return;
    }
    if (result != true) return;
    await showAppSuccessBottomSheet(
      context,
      'Nombre de evidencia actualizado.',
    );
  }
}

class _EmptyEvidenceState extends StatelessWidget {
  const _EmptyEvidenceState();

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.perm_media_outlined,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: AppSpace.xs),
        const Text('Las capturas y videos aparecerán aquí.'),
      ],
    ),
  );
}

class _EvidenceCard extends StatelessWidget {
  const _EvidenceCard({
    required this.evidence,
    required this.onRename,
    super.key,
  });

  final RequisitionEvidence evidence;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context) {
    final path = evidence.localPath;
    final isImage = evidence.type == RequisitionEvidenceType.image;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.m),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: .1),
            child: isImage
                ? EvidenceThumbnail(
                    localPath: path,
                    evidenceId: evidence.id,
                    wrappedKey: evidence.wrappedKey,
                    plaintextSha256: evidence.plaintextSha256,
                    plaintextByteLength: evidence.plaintextByteLength,
                    decryptionService: context
                        .read<EvidenceDecryptionService>(),
                    fallback: const Icon(Icons.image_outlined, size: 36),
                  )
                : Icon(
                    evidence.type == RequisitionEvidenceType.video
                        ? Icons.play_circle_outline
                        : Icons.insert_drive_file_outlined,
                    size: 36,
                  ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpace.s),
              color: Colors.black.withValues(alpha: .68),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          evidence.effectiveName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: onRename,
                        tooltip: 'Cambiar nombre',
                        visualDensity: VisualDensity.compact,
                        color: Colors.white,
                        icon: const Icon(Icons.edit_outlined, size: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.xs),
                  EvidenceSyncBadge(
                    uploadStatus: evidence.uploadStatus,
                    hasLocalCopy: path?.trim().isNotEmpty == true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
