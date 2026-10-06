import 'dart:io';

import 'package:file_cast/core/theme/colors.dart';
import 'package:file_cast/domain/models/requisition_detail.dart';
import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:file_cast/ui/core/widgets/app_action_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ImportEvidencePreviewDialog extends StatelessWidget {
  const ImportEvidencePreviewDialog({
    required this.evidence,
    required this.onCancel,
    required this.onConfirm,
    super.key,
  });

  final List<ImportedEvidenceDraft> evidence;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalBytes = evidence.fold<int>(
      0,
      (total, item) => total + item.byteLength,
    );

    return Dialog(
      insetPadding: const EdgeInsets.all(AppSpace.m),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Revisar archivos',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onCancel,
                    tooltip: 'Cancelar',
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              Text(
                '${evidence.length} archivos · ${_sizeLabel(totalBytes)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpace.s),
              Text(
                'Estos archivos se cifrarán y se subirán de forma segura. '
                'Puedes seguir usando la aplicación después de confirmar.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpace.m),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 520 ? 2 : 1;
                    return GridView.builder(
                      itemCount: evidence.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: AppSpace.s,
                        mainAxisSpacing: AppSpace.s,
                        mainAxisExtent: 76,
                      ),
                      itemBuilder: (context, index) => _SelectedEvidenceTile(
                        evidence: evidence[index],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpace.m),
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 420) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        OutlinedButton(
                          onPressed: onCancel,
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(height: AppSpace.s),
                        _confirmButton(),
                      ],
                    );
                  }
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: onCancel,
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: AppSpace.s),
                      SizedBox(width: 230, child: _confirmButton()),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _confirmButton() => AppActionButton(
    label: 'Confirmar y subir',
    onPressed: onConfirm,
    foregroundColor: textWhite,
    gradient: const LinearGradient(
      colors: [actionGradientStart, violet],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    leadingAsset: 'assets/images/icons/upload.svg',
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpace.m,
      vertical: AppSpace.s,
    ),
  );
}

class _SelectedEvidenceTile extends StatelessWidget {
  const _SelectedEvidenceTile({required this.evidence});

  final ImportedEvidenceDraft evidence;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final asset = switch (evidence.type) {
      RequisitionEvidenceType.image => 'gallery.svg',
      RequisitionEvidenceType.video => 'video.svg',
      RequisitionEvidenceType.audio => 'microphone.svg',
      RequisitionEvidenceType.document => 'file.svg',
      RequisitionEvidenceType.other => 'paper.svg',
    };
    final fallback = SvgPicture.asset(
      'assets/images/icons/$asset',
      colorFilter: ColorFilter.mode(scheme.primary, BlendMode.srcIn),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: .45),
        borderRadius: BorderRadius.circular(AppRadius.m),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.s),
              child: SizedBox(
                width: 56,
                height: 56,
                child:
                    evidence.type == RequisitionEvidenceType.image &&
                        evidence.localPath != null
                    ? Image.file(
                        File(evidence.localPath!),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => fallback,
                      )
                    : Container(
                        color: scheme.primary.withValues(alpha: .12),
                        padding: const EdgeInsets.all(AppSpace.m - AppSpace.s),
                        child: fallback,
                      ),
              ),
            ),
            const SizedBox(width: AppSpace.s),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    evidence.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpace.xxs),
                  Text(
                    evidence.sizeLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _sizeLabel(int bytes) {
  if (bytes >= 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / 1024).ceil()} KB';
}
