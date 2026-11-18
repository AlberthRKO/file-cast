import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Floating evidence entry point with total and synchronization state.
class MirrorEvidenceFab extends StatelessWidget {
  const MirrorEvidenceFab({
    required this.totalCount,
    required this.pendingCount,
    required this.onPressed,
    required this.heroTag,
    super.key,
  });

  final int totalCount;
  final int pendingCount;
  final VoidCallback onPressed;
  final Object heroTag;

  @override
  Widget build(BuildContext context) {
    final showLabel = MediaQuery.sizeOf(context).width >= 600;
    final colors = Theme.of(context).colorScheme;
    final icon = pendingCount > 0
        ? const SizedBox.square(
            dimension: AppSize.iconM,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const _EvidenceIcon();
    final button = showLabel
        ? FloatingActionButton.extended(
            heroTag: heroTag,
            onPressed: onPressed,
            tooltip: 'Mostrar evidencias',
            icon: icon,
            label: Text(
              pendingCount > 0 ? 'Sincronizando $pendingCount' : 'Evidencias',
            ),
          )
        : FloatingActionButton.small(
            heroTag: heroTag,
            onPressed: onPressed,
            tooltip: pendingCount > 0
                ? '$pendingCount evidencias sincronizándose'
                : 'Mostrar evidencias',
            child: icon,
          );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        button,
        Positioned(
          top: -6,
          right: -6,
          child: Semantics(
            label: '$totalCount evidencias registradas',
            child: Container(
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: pendingCount > 0 ? colors.tertiary : colors.primary,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: colors.surface, width: 2),
              ),
              child: Text(
                totalCount > 99 ? '99+' : '$totalCount',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: pendingCount > 0
                      ? colors.onTertiary
                      : colors.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EvidenceIcon extends StatelessWidget {
  const _EvidenceIcon();

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/images/icons/gallery.svg',
    width: AppSize.iconM,
    height: AppSize.iconM,
    colorFilter: ColorFilter.mode(
      IconTheme.of(context).color ?? Theme.of(context).colorScheme.onPrimary,
      BlendMode.srcIn,
    ),
  );
}
