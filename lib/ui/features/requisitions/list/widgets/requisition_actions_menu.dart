import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:file_cast/core/constants/complemento.dart';
import 'package:file_cast/core/theme/colors.dart';
import 'package:file_cast/domain/models/requisition.dart';
import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum RequisitionCardAction { finalize }

/// Acciones mutables disponibles desde el listado.
///
/// La navegación al detalle permanece en [RequisitionDetailsButton]. El menú
/// solo publica operaciones soportadas por el backend para la fila.
class RequisitionActionsMenu extends StatelessWidget {
  const RequisitionActionsMenu({
    required this.requisition,
    required this.canFinalize,
    this.onFinalize,
    super.key,
  });

  final Requisition requisition;
  final bool canFinalize;
  final VoidCallback? onFinalize;

  bool get _canFinalize =>
      canFinalize &&
      onFinalize != null &&
      (requisition.status == RequisitionStatus.draft ||
          requisition.status == RequisitionStatus.inProgress);

  @override
  Widget build(BuildContext context) {
    if (!_canFinalize) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final iconColor =
        theme.textTheme.bodyLarge?.color ?? theme.colorScheme.onSurface;

    return LayoutBuilder(
      builder: (context, constraints) {
        final menuWidth =
            constraints.maxWidth.isFinite && constraints.maxWidth < 232
            ? 220.0
            : 240.0;

        return DropdownButtonHideUnderline(
          child: DropdownButton2<RequisitionCardAction>(
            customButton: Tooltip(
              message: 'Acciones de la requisa',
              child: SizedBox.square(
                dimension: AppSize.minTouchTarget,
                child: Center(
                  child: SvgPicture.asset(
                    '${assetImgIcon}ellipsisH.svg',
                    width: AppSize.iconM,
                    colorFilter: ColorFilter.mode(
                      iconColor,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
            ),
            items: [
              DropdownMenuItem<RequisitionCardAction>(
                value: RequisitionCardAction.finalize,
                child: _ActionMenuRow(
                  iconAsset: 'lock.svg',
                  label: 'Finalizar y sellar',
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            onChanged: (action) {
              if (action == RequisitionCardAction.finalize) {
                onFinalize?.call();
              }
            },
            dropdownStyleData: DropdownStyleData(
              maxHeight: 160,
              width: menuWidth,
              padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(AppRadius.m),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              useSafeArea: true,
            ),
            menuItemStyleData: const MenuItemStyleData(
              height: AppSize.minTouchTarget,
              padding: EdgeInsets.symmetric(horizontal: AppSpace.m),
            ),
            barrierColor: Colors.transparent,
          ),
        );
      },
    );
  }
}

class RequisitionDetailsButton extends StatelessWidget {
  const RequisitionDetailsButton({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Abrir requisa',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: AppSize.minTouchTarget,
          height: AppSize.minTouchTarget,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [actionGradientStart, violet],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: violet.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: textWhite,
          ),
        ),
      ),
    );
  }
}

class _ActionMenuRow extends StatelessWidget {
  const _ActionMenuRow({
    required this.iconAsset,
    required this.label,
    required this.color,
  });

  final String iconAsset;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SvgPicture.asset(
          '$assetImgIcon$iconAsset',
          width: AppSize.iconM,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        ),
        const SizedBox(width: AppSpace.s),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
