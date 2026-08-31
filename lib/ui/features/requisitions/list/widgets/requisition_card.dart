import 'package:file_cast/core/constants/complemento.dart';
import 'package:file_cast/core/theme/colors.dart';
import 'package:file_cast/domain/models/requisition.dart';
import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:file_cast/ui/features/requisitions/list/widgets/requisition_status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

class RequisitionCard extends StatelessWidget {
  const RequisitionCard({
    required this.requisition,
    required this.onPressed,
    super.key,
  });

  final Requisition requisition;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? theme.primaryColor;
    final identifier =
        requisition.cud ?? requisition.subjectName ?? requisition.id;
    final identifierLabel = requisition.cud == null
        ? identifier
        : 'CUD: $identifier';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.l),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.l),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SvgPicture.asset(
                      '${assetImgIcon}calendar.svg',
                      width: AppSize.iconS,
                      colorFilter: ColorFilter.mode(
                        textColor.withValues(alpha: 0.5),
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(width: AppSpace.xs),
                    Expanded(
                      child: Text(
                        DateFormat(
                          'dd/MM/yyyy HH:mm',
                        ).format(requisition.registeredAt),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: textColor.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpace.s),
                    RequisitionStatusBadge(status: requisition.status),
                  ],
                ),
                const SizedBox(height: AppSpace.m),
                Text(
                  identifierLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.primaryColor,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  requisition.caseName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: AppSpace.m),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: textColor.withValues(alpha: 0.08),
                ),
                const SizedBox(height: AppSpace.m),
                Row(
                  children: [
                    Flexible(
                      child: _EvidencePill(
                        assetName: 'camera.svg',
                        count: requisition.imageEvidenceCount,
                        label: 'Capturas',
                      ),
                    ),
                    const SizedBox(width: AppSpace.s),
                    Flexible(
                      child: _EvidencePill(
                        assetName: 'video.svg',
                        count: requisition.videoEvidenceCount,
                        label: 'Videos',
                      ),
                    ),
                    const Spacer(),
                    _DetailsButton(onTap: onPressed),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EvidencePill extends StatelessWidget {
  const _EvidencePill({
    required this.assetName,
    required this.count,
    required this.label,
  });

  final String assetName;
  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.primaryColor;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s,
        vertical: AppSpace.xs,
      ),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            '$assetImgIcon$assetName',
            width: AppSize.iconS,
            colorFilter: ColorFilter.mode(primary, BlendMode.srcIn),
          ),
          const SizedBox(width: AppSpace.xs),
          Flexible(
            child: Text(
              '$count $label',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsButton extends StatelessWidget {
  const _DetailsButton({required this.onTap});

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
