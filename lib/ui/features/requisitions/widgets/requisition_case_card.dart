import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Adaptación responsive del CardCasoPenal usado por el ecosistema Justicia Libre.
class RequisitionCaseCard extends StatelessWidget {
  const RequisitionCaseCard({
    required this.cud,
    required this.caseType,
    required this.division,
    required this.statusLabel,
    this.identifierLabel = 'CUD',
    this.onViewSubjects,
    this.onRemove,
    super.key,
  });

  final String cud;
  final String caseType;
  final String division;
  final String statusLabel;
  final String identifierLabel;
  final VoidCallback? onViewSubjects;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpace.m),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(AppRadius.s),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .05),
                blurRadius: 15,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.only(right: onRemove == null ? 0 : AppSpace.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$identifierLabel: $cud',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpace.s),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(AppRadius.s),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.s,
                          vertical: AppSpace.xs,
                        ),
                        child: Text(
                          statusLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    if (onViewSubjects != null) ...[
                      const SizedBox(width: AppSpace.xs),
                      _CaseSubjectsButton(onPressed: onViewSubjects!),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpace.s),
                _DetailLine(
                  asset: 'assets/images/icons/contrato.svg',
                  label: 'Delito:',
                  value: caseType,
                ),
                const SizedBox(height: AppSpace.xs),
                _DetailLine(
                  asset: 'assets/images/icons/marca.svg',
                  label: 'Tipo:',
                  value: division,
                ),
              ],
            ),
          ),
        ),
        if (onRemove != null)
          Positioned(
            right: -AppSpace.xs,
            top: -AppSpace.xs,
            child: InkWell(
              onTap: onRemove,
              customBorder: const CircleBorder(),
              child: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withValues(alpha: .9),
                  shape: BoxShape.circle,
                ),
                child: SvgPicture.asset(
                  'assets/images/icons/x.svg',
                  width: 14,
                  colorFilter: ColorFilter.mode(
                    theme.colorScheme.onError,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CaseSubjectsButton extends StatelessWidget {
  const _CaseSubjectsButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return IconButton(
      tooltip: 'Ver sujetos del caso',
      onPressed: onPressed,
      style: IconButton.styleFrom(
        minimumSize: const Size.square(AppSize.minTouchTarget),
        maximumSize: const Size.square(AppSize.minTouchTarget),
        padding: EdgeInsets.zero,
        shape: const CircleBorder(),
        side: BorderSide.none,
      ),
      constraints: const BoxConstraints(
        minWidth: AppSize.minTouchTarget,
        minHeight: AppSize.minTouchTarget,
      ),
      icon: Container(
        width: AppSize.iconL + AppSpace.s,
        height: AppSize.iconL + AppSpace.s,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: primary.withValues(alpha: .1),
        ),
        alignment: Alignment.center,
        child: SvgPicture.asset(
          'assets/images/icons/users.svg',
          width: AppSize.iconS,
          height: AppSize.iconS,
          colorFilter: ColorFilter.mode(primary, BlendMode.srcIn),
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.asset,
    required this.label,
    required this.value,
  });
  final String asset;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SvgPicture.asset(
          asset,
          width: AppSize.iconS,
          height: AppSize.iconS,
          colorFilter: ColorFilter.mode(
            theme.colorScheme.primary,
            BlendMode.srcIn,
          ),
        ),
        const SizedBox(width: AppSpace.xs),
        Expanded(
          child: RichText(
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style: theme.textTheme.bodySmall,
              children: [
                TextSpan(
                  text: '$label ',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
