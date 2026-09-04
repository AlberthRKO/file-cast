import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Icono de campo alineado con los inputs del formulario de inicio de sesión.
class AppFormInputIcon extends StatelessWidget {
  const AppFormInputIcon({required this.asset, this.muted = false, super.key});

  final String asset;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary.withValues(
      alpha: muted ? .7 : 1,
    );
    return SizedBox.square(
      dimension: AppSize.minTouchTarget,
      child: Center(
        child: SvgPicture.asset(
          asset,
          height: AppSize.iconM,
          width: AppSize.iconM,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        ),
      ),
    );
  }
}
