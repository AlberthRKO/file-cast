import 'package:file_cast/domain/repositories/connectivity_repository.dart';
import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:file_cast/ui/core/widgets/app_modal_bottom_sheet.dart';
import 'package:file_cast/ui/features/connectivity/view_models/connectivity_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AppConnectivityBanner extends StatelessWidget {
  const AppConnectivityBanner({
    required this.viewModel,
    required this.navigatorKey,
    super.key,
  });

  final ConnectivityViewModel viewModel;
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  Widget build(BuildContext context) {
    if (!viewModel.showsOfflineIndicator) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final presentation = _presentation(viewModel.status, theme.colorScheme);

    return Semantics(
      liveRegion: true,
      button: true,
      label: presentation.semantics,
      child: Material(
        elevation: 6,
        shadowColor: theme.colorScheme.shadow.withValues(alpha: .28),
        color: presentation.background,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.pill)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _showStatus(context),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSize.minTouchTarget,
              maxWidth: 156,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s,
                vertical: AppSpace.xs,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    'assets/images/icons/${presentation.iconAsset}',
                    width: AppSize.iconS - 2,
                    height: AppSize.iconS - 2,
                    colorFilter: ColorFilter.mode(
                      presentation.foreground,
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(width: AppSpace.xs),
                  Flexible(
                    child: Text(
                      presentation.compactLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: presentation.foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showStatus(BuildContext context) {
    // MaterialApp.router.builder is above the route Navigator. Use the
    // Navigator's Overlay context so showModalBottomSheet can find it.
    final navigatorContext = navigatorKey.currentState?.overlay?.context;
    if (navigatorContext == null) return Future<void>.value();

    final status = viewModel.status;
    final theme = Theme.of(context);
    final presentation = _presentation(status, theme.colorScheme);
    return showAppModalBottomSheet<void>(
      context: navigatorContext,
      useSafeArea: true,
      maxWidth: AppSize.messageMaxWidth,
      backgroundColor: theme.cardColor,
      builder: (sheetContext) {
        final scheme = Theme.of(sheetContext).colorScheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.l,
            AppSpace.m,
            AppSpace.l,
            AppSpace.l,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.m),
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  padding: const EdgeInsets.all(AppSpace.s),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(AppRadius.m),
                  ),
                  child: SvgPicture.asset(
                    'assets/images/icons/${presentation.iconAsset}',
                    colorFilter: ColorFilter.mode(
                      scheme.primary,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.s),
              Text(
                presentation.title,
                style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpace.s),
              Text(
                presentation.description,
                style: Theme.of(sheetContext).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpace.l),
              FilledButton.icon(
                onPressed: status == ConnectivityStatus.checking
                    ? null
                    : () {
                        Navigator.of(sheetContext).pop();
                        viewModel.retry();
                      },
                icon: SvgPicture.asset(
                  'assets/images/icons/refresh.svg',
                  width: AppSize.iconM,
                  height: AppSize.iconM,
                  colorFilter: ColorFilter.mode(
                    scheme.onPrimary,
                    BlendMode.srcIn,
                  ),
                ),
                label: const Text('Comprobar conexión'),
              ),
            ],
          ),
        );
      },
    );
  }

  _ConnectivityPresentation _presentation(
    ConnectivityStatus status,
    ColorScheme colors,
  ) {
    return switch (status) {
      ConnectivityStatus.checking => _ConnectivityPresentation(
        title: 'Comprobando conexión',
        compactLabel: 'Verificando',
        semantics: 'Comprobando conexión con File Cast',
        description:
            'La aplicación está verificando si el servicio institucional está disponible.',
        iconAsset: 'sync.svg',
        background: colors.surfaceContainerHighest,
        foreground: colors.onSurfaceVariant,
      ),
      ConnectivityStatus.online => _ConnectivityPresentation(
        title: 'Modo en línea',
        compactLabel: 'En línea',
        semantics: 'File Cast está en línea',
        description:
            'El servicio institucional está disponible. Las evidencias pendientes pueden sincronizarse.',
        iconAsset: 'check.svg',
        background: colors.primaryContainer,
        foreground: colors.onPrimaryContainer,
      ),
      ConnectivityStatus.offline => _ConnectivityPresentation(
        title: 'Modo sin conexión',
        compactLabel: 'Sin conexión',
        semantics: 'File Cast está sin conexión y trabaja localmente',
        description:
            'Puedes consultar la información guardada y registrar evidencias locales. Se sincronizarán al recuperar conexión.',
        iconAsset: 'alert.svg',
        background: colors.errorContainer,
        foreground: colors.onErrorContainer,
      ),
      ConnectivityStatus.limited => _ConnectivityPresentation(
        title: 'Sin conexión al servidor',
        compactLabel: 'Sin conexión',
        semantics:
            'File Cast no tiene conexión con el servidor y trabaja localmente',
        description:
            'Hay red, pero el servicio institucional no responde correctamente. El trabajo local permanece disponible.',
        iconAsset: 'alert.svg',
        background: colors.tertiaryContainer,
        foreground: colors.onTertiaryContainer,
      ),
    };
  }
}

final class _ConnectivityPresentation {
  const _ConnectivityPresentation({
    required this.title,
    required this.compactLabel,
    required this.semantics,
    required this.description,
    required this.iconAsset,
    required this.background,
    required this.foreground,
  });

  final String title;
  final String compactLabel;
  final String semantics;
  final String description;
  final String iconAsset;
  final Color background;
  final Color foreground;
}
