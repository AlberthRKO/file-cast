import 'dart:ui' as ui;

import 'package:file_cast/domain/models/requisition_detail.dart';
import 'package:file_cast/domain/services/evidence_decryption_service.dart';
import 'package:file_cast/domain/services/evidence_video_thumbnail_service.dart';
import 'package:file_cast/ui/core/feedback/app_feedback.dart';
import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:file_cast/ui/core/widgets/app_modal_bottom_sheet.dart';
import 'package:file_cast/ui/core/widgets/evidence_rename_sheet.dart';
import 'package:file_cast/ui/core/widgets/evidence_sync_badge.dart';
import 'package:file_cast/ui/core/widgets/evidence_thumbnail.dart';
import 'package:file_cast/ui/core/widgets/evidence_video_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

typedef RenameMirrorEvidence =
    Future<String?> Function(RequisitionEvidence evidence, String displayName);

/// Evidence browser shared by individual and multi-mirror acquisition.
class MirrorEvidencePane extends StatefulWidget {
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
  State<MirrorEvidencePane> createState() => _MirrorEvidencePaneState();
}

enum _EvidenceLayoutMode { grid, list }

class _MirrorEvidencePaneState extends State<MirrorEvidencePane> {
  _EvidenceLayoutMode _layoutMode = _EvidenceLayoutMode.grid;
  bool _blurPreviews = false;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.all(AppSpace.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _EvidencePaneHeader(
            totalEvidence: widget.totalEvidence,
            contextLabel: widget.contextLabel,
            layoutMode: _layoutMode,
            blurPreviews: _blurPreviews,
            onToggleLayout: () => setState(() {
              _layoutMode = _layoutMode == _EvidenceLayoutMode.grid
                  ? _EvidenceLayoutMode.list
                  : _EvidenceLayoutMode.grid;
            }),
            onToggleBlur: (selected) => setState(() {
              _blurPreviews = selected;
            }),
            onClose: widget.onClose,
          ),
          const SizedBox(height: AppSpace.s),
          Expanded(
            child: widget.evidence.isEmpty
                ? const _EmptyEvidenceState()
                : _EvidenceCollection(
                    evidence: widget.evidence,
                    layoutMode: _layoutMode,
                    compact: widget.compact,
                    blurred: _blurPreviews,
                    onRename: (item) => _renameEvidence(context, item),
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
        onSave: (name) => widget.onRename(item, name),
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

class _EvidenceCollection extends StatelessWidget {
  const _EvidenceCollection({
    required this.evidence,
    required this.layoutMode,
    required this.compact,
    required this.blurred,
    required this.onRename,
  });

  final List<RequisitionEvidence> evidence;
  final _EvidenceLayoutMode layoutMode;
  final bool compact;
  final bool blurred;
  final ValueChanged<RequisitionEvidence> onRename;

  @override
  Widget build(BuildContext context) {
    final listMode = layoutMode == _EvidenceLayoutMode.list;
    final horizontalGrid = compact && !listMode;
    final indexById = <String, int>{
      for (var index = 0; index < evidence.length; index++)
        evidence[index].id: index,
    };
    return GridView.builder(
      scrollDirection: horizontalGrid ? Axis.horizontal : Axis.vertical,
      itemCount: evidence.length,
      findChildIndexCallback: (key) {
        if (key is ValueKey<String>) return indexById[key.value];
        return null;
      },
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: listMode || horizontalGrid ? 1 : 2,
        crossAxisSpacing: AppSpace.s,
        mainAxisSpacing: AppSpace.s,
        mainAxisExtent: listMode ? 104 : (horizontalGrid ? 150 : null),
        childAspectRatio: 1.2,
      ),
      itemBuilder: (context, index) {
        final item = evidence[index];
        return _EvidenceCard(
          key: ValueKey(item.id),
          evidence: item,
          layoutMode: layoutMode,
          blurred: blurred,
          onRename: () => onRename(item),
        );
      },
    );
  }
}

class _EvidencePaneHeader extends StatelessWidget {
  const _EvidencePaneHeader({
    required this.totalEvidence,
    required this.layoutMode,
    required this.blurPreviews,
    required this.onToggleLayout,
    required this.onToggleBlur,
    required this.onClose,
    this.contextLabel,
  });

  final int totalEvidence;
  final String? contextLabel;
  final _EvidenceLayoutMode layoutMode;
  final bool blurPreviews;
  final VoidCallback onToggleLayout;
  final ValueChanged<bool> onToggleBlur;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final showLeadingIcon = constraints.maxWidth >= 300;
      final title = Row(
        children: [
          if (showLeadingIcon) ...[
            const Icon(Icons.verified_user_outlined, size: AppSize.iconM),
            const SizedBox(width: AppSpace.s),
          ],
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
        ],
      );
      final layoutButton = IconButton(
        onPressed: onToggleLayout,
        tooltip: layoutMode == _EvidenceLayoutMode.grid
            ? 'Ver como lista'
            : 'Ver como cuadrícula',
        icon: Icon(
          layoutMode == _EvidenceLayoutMode.grid
              ? Icons.view_list_outlined
              : Icons.grid_view_outlined,
        ),
      );
      final blurButton = IconButton(
        isSelected: blurPreviews,
        onPressed: () => onToggleBlur(!blurPreviews),
        tooltip: blurPreviews ? 'Quitar difuminado' : 'Difuminar evidencias',
        icon: const Icon(Icons.blur_on),
        selectedIcon: const Icon(Icons.blur_off),
      );
      final closeButton = IconButton(
        onPressed: onClose,
        tooltip: 'Ocultar evidencias',
        icon: const Icon(Icons.close),
      );
      return Row(
        children: [
          Expanded(child: title),
          layoutButton,
          blurButton,
          closeButton,
        ],
      );
    },
  );
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
    required this.layoutMode,
    required this.blurred,
    required this.onRename,
    super.key,
  });

  final RequisitionEvidence evidence;
  final _EvidenceLayoutMode layoutMode;
  final bool blurred;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context) {
    final path = evidence.localPath;
    final listMode = layoutMode == _EvidenceLayoutMode.list;
    final visual = _EvidenceVisual(evidence: evidence, blurred: blurred);
    return Material(
      color: listMode
          ? Theme.of(context).colorScheme.primary.withValues(alpha: .08)
          : Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.m),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: listMode ? AppSpace.s : 0,
            top: listMode ? AppSpace.s : 0,
            right: listMode ? null : 0,
            bottom: listMode ? AppSpace.s : 0,
            width: listMode ? 72 : null,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                listMode ? AppRadius.s : AppRadius.m,
              ),
              child: visual,
            ),
          ),
          Positioned(
            left: listMode ? 72 + (AppSpace.s * 2) : 0,
            top: listMode ? AppSpace.s : null,
            right: listMode ? AppSpace.s : 0,
            bottom: listMode ? AppSpace.s : 0,
            child: listMode
                ? Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              evidence.effectiveName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const SizedBox(height: AppSpace.xs),
                            EvidenceSyncBadge(
                              uploadStatus: evidence.uploadStatus,
                              hasLocalCopy: path?.trim().isNotEmpty == true,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: onRename,
                        tooltip: 'Cambiar nombre',
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    ],
                  )
                : Container(
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

class _EvidenceVisual extends StatelessWidget {
  const _EvidenceVisual({required this.evidence, required this.blurred});

  final RequisitionEvidence evidence;
  final bool blurred;

  @override
  Widget build(BuildContext context) {
    final path = evidence.localPath;
    final preview = switch (evidence.type) {
      RequisitionEvidenceType.image => EvidenceThumbnail(
        localPath: path,
        evidenceId: evidence.id,
        wrappedKey: evidence.wrappedKey,
        plaintextSha256: evidence.plaintextSha256,
        plaintextByteLength: evidence.plaintextByteLength,
        decryptionService: context.read<EvidenceDecryptionService>(),
        fallback: const Icon(Icons.image_outlined, size: 36),
      ),
      RequisitionEvidenceType.video => EvidenceVideoThumbnail(
        localPath: path,
        evidenceId: evidence.id,
        fileName: evidence.name,
        wrappedKey: evidence.wrappedKey,
        plaintextSha256: evidence.plaintextSha256,
        plaintextByteLength: evidence.plaintextByteLength,
        decryptionService: context.read<EvidenceDecryptionService>(),
        thumbnailService: context.read<EvidenceVideoThumbnailService>(),
        fallback: const Icon(Icons.play_circle_outline, size: 36),
      ),
      _ => const Icon(Icons.insert_drive_file_outlined, size: 36),
    };
    return ColoredBox(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: .1),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: preview),
          if (blurred)
            Positioned.fill(
              child: IgnorePointer(
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                    child: const ColoredBox(color: Colors.transparent),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
