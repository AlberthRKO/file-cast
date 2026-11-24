import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:file_cast/domain/models/requisition_detail.dart';
import 'package:file_cast/domain/services/evidence_decryption_service.dart';
import 'package:file_cast/domain/services/evidence_video_thumbnail_service.dart';
import 'package:file_cast/domain/services/evidence_image_thumbnail_service.dart';
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
    required this.visible,
    required this.onClose,
    required this.onRename,
    required this.onOpenEvidence,
    this.contextLabel,
    super.key,
  });

  final List<RequisitionEvidence> evidence;
  final int totalEvidence;
  final bool compact;
  final bool visible;
  final VoidCallback onClose;
  final RenameMirrorEvidence onRename;
  final ValueChanged<RequisitionEvidence> onOpenEvidence;
  final String? contextLabel;

  @override
  State<MirrorEvidencePane> createState() => _MirrorEvidencePaneState();
}

enum _EvidenceLayoutMode { grid, list }

class _MirrorEvidencePaneState extends State<MirrorEvidencePane> {
  _EvidenceLayoutMode _layoutMode = _EvidenceLayoutMode.grid;
  bool _blurPreviews = false;
  int _visibleCount = 12;

  @override
  Widget build(BuildContext context) => !widget.visible
      ? const SizedBox.shrink()
      : Card(
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
                          initialVisibleCount: _visibleCount,
                          onVisibleCountChanged: (count) =>
                              _visibleCount = count,
                          onRename: (item) => _renameEvidence(context, item),
                          onOpenEvidence: widget.onOpenEvidence,
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

class _EvidenceCollection extends StatefulWidget {
  const _EvidenceCollection({
    required this.evidence,
    required this.layoutMode,
    required this.compact,
    required this.blurred,
    required this.initialVisibleCount,
    required this.onVisibleCountChanged,
    required this.onRename,
    required this.onOpenEvidence,
  });

  final List<RequisitionEvidence> evidence;
  final _EvidenceLayoutMode layoutMode;
  final bool compact;
  final bool blurred;
  final int initialVisibleCount;
  final ValueChanged<int> onVisibleCountChanged;
  final ValueChanged<RequisitionEvidence> onRename;
  final ValueChanged<RequisitionEvidence> onOpenEvidence;

  @override
  State<_EvidenceCollection> createState() => _EvidenceCollectionState();
}

class _EvidenceCollectionState extends State<_EvidenceCollection> {
  static const _pageSize = 12;
  late int _visibleCount;
  bool _loadScheduled = false;

  @override
  void initState() {
    super.initState();
    _visibleCount = math.min(
      math.max(_pageSize, widget.initialVisibleCount),
      widget.evidence.length,
    );
  }

  @override
  void didUpdateWidget(covariant _EvidenceCollection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final added = widget.evidence.length - oldWidget.evidence.length;
    _visibleCount = math.min(
      widget.evidence.length,
      math.max(_pageSize, _visibleCount + math.max(0, added)),
    );
    widget.onVisibleCountChanged(_visibleCount);
  }

  bool _onScroll(ScrollNotification notification) {
    if (_loadScheduled ||
        _visibleCount >= widget.evidence.length ||
        notification.metrics.extentAfter > 300) {
      return false;
    }
    _loadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadScheduled = false;
      if (!mounted) return;
      setState(() {
        _visibleCount = math.min(
          widget.evidence.length,
          _visibleCount + _pageSize,
        );
      });
      widget.onVisibleCountChanged(_visibleCount);
    });
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final evidence = widget.evidence;
    final listMode = widget.layoutMode == _EvidenceLayoutMode.list;
    final horizontalGrid = widget.compact && !listMode;
    final indexById = <String, int>{
      for (var index = 0; index < evidence.length; index++)
        evidence[index].id: index,
    };
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: GridView.builder(
        key: PageStorageKey('mirror-evidence-${widget.layoutMode.name}'),
        scrollDirection: horizontalGrid ? Axis.horizontal : Axis.vertical,
        itemCount: _visibleCount + (_visibleCount < evidence.length ? 1 : 0),
        cacheExtent: evidence.length > 24 ? 0 : null,
        findChildIndexCallback: (key) {
          if (key is ValueKey<String>) {
            final index = indexById[key.value];
            return index != null && index < _visibleCount ? index : null;
          }
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
          if (index == _visibleCount) {
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }
          final item = evidence[index];
          return _EvidenceCard(
            key: ValueKey(item.id),
            evidence: item,
            layoutMode: widget.layoutMode,
            blurred: widget.blurred,
            onRename: () => widget.onRename(item),
            onOpen: () => widget.onOpenEvidence(item),
          );
        },
      ),
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
    required this.onOpen,
    super.key,
  });

  final RequisitionEvidence evidence;
  final _EvidenceLayoutMode layoutMode;
  final bool blurred;
  final VoidCallback onRename;
  final VoidCallback onOpen;

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
      child: InkWell(
        onTap: onOpen,
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
        thumbnailService: context.read<EvidenceImageThumbnailService>(),
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
