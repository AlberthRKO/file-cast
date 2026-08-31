import 'package:file_cast/core/theme/theme_dark.dart';
import 'package:file_cast/core/theme/theme_light.dart';
import 'package:file_cast/ui/core/theme/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();
    final router = context.watch<GoRouter>();

    return MaterialApp.router(
      title: 'File Cast',
      theme: light,
      darkTheme: dark,
      themeMode: themeController.darkMode ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
