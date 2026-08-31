import 'package:file_cast/core/core.dart';
import 'package:file_cast/presentation/providers/theme_controller.dart';
import 'package:file_cast/ui/core/navigation/app_router.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();

    return OrientationBuilder(
      builder: (context, orientation) {
        final isPortrait = orientation == Orientation.portrait;

        return ScreenUtilInit(
          designSize: isPortrait ? const Size(375, 812) : const Size(812, 375),
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (context, child) {
            return MaterialApp.router(
              title: 'File Cast',
              theme: light,
              darkTheme: dark,
              themeMode: themeController.darkMode
                  ? ThemeMode.dark
                  : ThemeMode.light,
              routerConfig: appRouter,
              debugShowCheckedModeBanner: false,
            );
          },
        );
      },
    );
  }
}
