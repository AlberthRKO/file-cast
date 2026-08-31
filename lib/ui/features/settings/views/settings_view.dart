import 'package:file_cast/ui/core/adaptive/constrained_content.dart';
import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:file_cast/ui/core/theme/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver',
          onPressed: context.canPop() ? context.pop : null,
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Configuración'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedContent(
            maxWidth: AppSize.formMaxWidth,
            padding: const EdgeInsets.all(AppSpace.l),
            child: Card(
              child: SwitchListTile.adaptive(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.m,
                  vertical: AppSpace.s,
                ),
                secondary: const Icon(Icons.dark_mode_outlined),
                title: const Text('Tema oscuro'),
                subtitle: const Text(
                  'Usar la apariencia oscura en toda la aplicación.',
                ),
                value: themeController.darkMode,
                onChanged: themeController.onChange,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
