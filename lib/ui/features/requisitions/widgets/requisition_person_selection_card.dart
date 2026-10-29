import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Resultado de persona/usuario seleccionado dentro de un formulario de
/// requisa. Mantiene la misma jerarquía visual en creación y detalle.
class RequisitionPersonSelectionCard extends StatelessWidget {
  const RequisitionPersonSelectionCard({
    required this.name,
    required this.ci,
    this.username,
    this.address,
    this.phone,
    this.footer,
    this.onRemove,
    super.key,
  });

  final String name;
  final String ci;
  final String? username;
  final String? address;
  final String? phone;
  final Widget? footer;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final footer = this.footer;
    final card = Container(
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
        padding: EdgeInsets.only(
          right: onRemove == null ? 0 : AppSpace.m,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PersonCardContent(
              name: name,
              ci: ci,
              username: username,
              address: address,
              phone: phone,
            ),
            if (footer != null) ...[
              const SizedBox(height: AppSpace.m),
              Divider(
                height: 1,
                color: theme.colorScheme.outline.withValues(alpha: 0.18),
              ),
              const SizedBox(height: AppSpace.m),
              SizedBox(width: double.infinity, child: footer),
            ],
          ],
        ),
      ),
    );

    if (onRemove == null) return card;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        card,
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
                shape: BoxShape.circle,
                color: theme.colorScheme.error.withValues(alpha: .9),
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

class _PersonCardContent extends StatelessWidget {
  const _PersonCardContent({
    required this.name,
    required this.ci,
    this.username,
    this.address,
    this.phone,
  });

  final String name;
  final String ci;
  final String? username;
  final String? address;
  final String? phone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpace.xs),
        _PersonDetail(
          asset: 'assets/images/icons/cardEmployee.svg',
          label: 'CI:',
          value: ci,
        ),
        if (username?.trim().isNotEmpty == true) ...[
          const SizedBox(height: AppSpace.xs),
          _PersonDetail(
            asset: 'assets/images/icons/cardEmployee.svg',
            label: 'Usuario:',
            value: username!,
          ),
        ],
        if (address?.trim().isNotEmpty == true) ...[
          const SizedBox(height: AppSpace.xs),
          _PersonDetail(
            asset: 'assets/images/icons/address.svg',
            label: 'Dirección:',
            value: address!,
          ),
        ],
        if (phone?.trim().isNotEmpty == true) ...[
          const SizedBox(height: AppSpace.xs),
          _PersonDetail(
            asset: 'assets/images/icons/phone.svg',
            label: 'Celular:',
            value: phone!,
          ),
        ],
      ],
    );
  }
}

class _PersonDetail extends StatelessWidget {
  const _PersonDetail({
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
