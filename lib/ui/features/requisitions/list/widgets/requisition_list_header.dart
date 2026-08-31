import 'package:file_cast/core/constants/complemento.dart';
import 'package:file_cast/core/theme/colors.dart';
import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// App bar propio del listado de requisas.
///
/// Conserva la identidad visual del Home original, pero calcula su composición
/// con el espacio disponible y consume exclusivamente colores del tema activo.
class RequisitionListHeader extends StatelessWidget {
  const RequisitionListHeader({
    required this.compact,
    required this.searchController,
    required this.onQueryChanged,
    required this.onOpenFilters,
    required this.onRefresh,
    required this.onSettings,
    required this.isRefreshing,
    required this.filtersActive,
    this.identityLabel = 'C.I. 14258827,',
    this.userName = 'Alberto Orlando Paredes Mamani',
    this.notificationCount = 2,
    super.key,
  });

  final bool compact;
  final TextEditingController searchController;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onOpenFilters;
  final VoidCallback onRefresh;
  final VoidCallback onSettings;
  final bool isRefreshing;
  final bool filtersActive;
  final String identityLabel;
  final String userName;
  final int notificationCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.cardColor,
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(25),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSize.contentMaxWidth,
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? AppSpace.m : AppSpace.l,
                AppSpace.s,
                compact ? AppSpace.m : AppSpace.l,
                AppSpace.m,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _IdentityRow(
                    compact: compact,
                    identityLabel: identityLabel,
                    userName: userName,
                    notificationCount: notificationCount,
                    onSettings: onSettings,
                  ),
                  const SizedBox(height: AppSpace.s),
                  Row(
                    children: [
                      Expanded(
                        child: _SearchField(
                          controller: searchController,
                          onChanged: onQueryChanged,
                        ),
                      ),
                      const SizedBox(width: AppSpace.s),
                      _HeaderAction(
                        tooltip: filtersActive
                            ? 'Modificar filtros activos'
                            : 'Filtrar requisas',
                        onTap: onOpenFilters,
                        borderColor: filtersActive
                            ? theme.colorScheme.error
                            : theme.primaryColor,
                        child: SvgPicture.asset(
                          '${assetImgIcon}filterMore.svg',
                          width: AppSize.iconM,
                          colorFilter: ColorFilter.mode(
                            filtersActive
                                ? theme.colorScheme.error
                                : theme.primaryColor,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                      if (!compact) ...[
                        const SizedBox(width: AppSpace.s),
                        _HeaderAction(
                          tooltip: 'Actualizar listado',
                          onTap: onRefresh,
                          borderColor: theme.primaryColor,
                          child: isRefreshing
                              ? SizedBox.square(
                                  dimension: AppSize.iconM,
                                  child: CircularProgressIndicator(
                                    color: theme.primaryColor,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  Icons.refresh_rounded,
                                  color: theme.primaryColor,
                                  size: AppSize.iconM,
                                ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IdentityRow extends StatelessWidget {
  const _IdentityRow({
    required this.compact,
    required this.identityLabel,
    required this.userName,
    required this.notificationCount,
    required this.onSettings,
  });

  final bool compact;
  final String identityLabel;
  final String userName;
  final int notificationCount;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avatarSize = compact ? 40.0 : 48.0;

    return Row(
      children: [
        SizedBox.square(
          dimension: avatarSize,
          child: ClipOval(
            child: ColoredBox(
              color: theme.scaffoldBackgroundColor,
              child: SvgPicture.asset(
                '${assetImg}profile.svg',
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpace.s),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                identityLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall,
              ),
              Text(
                userName,
                maxLines: compact ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (!compact) ...[
          Icon(
            Icons.cloud_off_outlined,
            size: AppSize.iconS,
            color: theme.hintColor,
          ),
          const SizedBox(width: AppSpace.xs),
          Text('Datos locales', style: theme.textTheme.bodySmall),
          const SizedBox(width: AppSpace.m),
        ],
        _NotificationButton(
          count: notificationCount,
          onTap: onSettings,
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      constraints: const BoxConstraints(minHeight: AppSize.minTouchTarget),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.m),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: theme.textTheme.bodyMedium,
        cursorColor: theme.primaryColor,
        decoration: InputDecoration(
          labelText: 'Buscar por CUD',
          labelStyle: theme.textTheme.bodyMedium?.copyWith(
            color: theme.primaryColor.withValues(alpha: 0.55),
          ),
          prefixIcon: Center(
            widthFactor: 1,
            child: SvgPicture.asset(
              '${assetImgIcon}search.svg',
              width: AppSize.iconM,
              colorFilter: ColorFilter.mode(
                theme.primaryColor,
                BlendMode.srcIn,
              ),
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: AppSize.minTouchTarget,
            minHeight: AppSize.minTouchTarget,
          ),
        ),
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.tooltip,
    required this.onTap,
    required this.borderColor,
    required this.child,
  });

  final String tooltip;
  final VoidCallback onTap;
  final Color borderColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.m),
        child: Container(
          width: AppSize.minTouchTarget,
          height: AppSize.minTouchTarget,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(AppRadius.m),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _NotificationButton extends StatelessWidget {
  const _NotificationButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Tooltip(
      message: 'Notificaciones y configuración',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox.square(
          dimension: AppSize.minTouchTarget,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              SvgPicture.asset(
                '${assetImgIcon}notification.svg',
                width: AppSize.iconM,
                colorFilter: ColorFilter.mode(
                  theme.textTheme.bodyLarge?.color ?? theme.primaryColor,
                  BlendMode.srcIn,
                ),
              ),
              if (count > 0)
                Positioned(
                  right: 2,
                  top: 2,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: theme.primaryColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.cardColor),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      count > 9 ? '9+' : '$count',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: textWhite,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
