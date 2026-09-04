import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Adaptación responsive del CardCasoPenal usado por el ecosistema Justicia Libre.
class RequisitionCaseCard extends StatelessWidget {
  const RequisitionCaseCard({
    required this.cud,
    required this.caseType,
    required this.division,
    required this.subjectCount,
    this.statusLabel = 'Vinculado',
    this.onRemove,
    super.key,
  });

  final String cud;
  final String caseType;
  final String division;
  final int subjectCount;
  final String statusLabel;
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
                        'CUD: $cud',
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
                  ],
                ),
                const SizedBox(height: AppSpace.s),
                _DetailLine(
                  asset: 'assets/images/icons/contrato.svg',
                  label: 'Delito:',
                  value: caseType,
                ),
                const SizedBox(height: AppSpace.xs),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 380;
                    final divisionLine = _DetailLine(
                      asset: 'assets/images/icons/marca.svg',
                      label: 'Tipo:',
                      value: division,
                    );
                    final subjectLine = _DetailLine(
                      asset: 'assets/images/icons/users.svg',
                      label: 'Sujetos:',
                      value: '$subjectCount',
                    );
                    if (compact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          divisionLine,
                          const SizedBox(height: AppSpace.xs),
                          subjectLine,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: divisionLine),
                        const SizedBox(width: AppSpace.s),
                        Flexible(child: subjectLine),
                      ],
                    );
                  },
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
