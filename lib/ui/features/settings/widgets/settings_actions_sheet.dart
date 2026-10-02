import 'dart:async';

import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:file_cast/ui/core/theme/theme_controller.dart';
import 'package:flutter/material.dart';

class SettingsActionsSheet extends StatelessWidget {
  const SettingsActionsSheet({
    required this.themeController,
    required this.onClose,
    required this.onLogout,
    super.key,
  });

  final ThemeController themeController;
  final VoidCallback onClose;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeController,
      builder: (context, _) {
        final theme = Theme.of(context);

        return LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth >= 600
                ? AppSpace.xl
                : AppSpace.l;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                AppSpace.s,
                horizontalPadding,
                AppSpace.m,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Configuración',
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        onPressed: onClose,
                        tooltip: 'Cerrar',
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.s),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.dark_mode_outlined),
                    title: const Text('Tema oscuro'),
                    subtitle: const Text(
                      'Usar la apariencia oscura en toda la aplicación.',
                    ),
                    value: themeController.darkMode,
                    onChanged: themeController.onChange,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.logout,
                      color: theme.colorScheme.error,
                    ),
                    title: const Text('Cerrar sesión'),
                    subtitle: const Text(
                      'Finalizar la sesión actual en este dispositivo.',
                    ),
                    onTap: () {
                      onClose();
                      unawaited(onLogout());
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
