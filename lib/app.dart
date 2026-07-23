import 'package:file_cast/core/core.dart';
import 'package:file_cast/presentation/routes/router.dart';
import 'package:flutter/material.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        final isPortrait = orientation == Orientation.portrait;

        return ScreenUtilInit(
          designSize: isPortrait
              ? const Size(375, 812)
              : const Size(812, 375),
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (context, child) {
            return MaterialApp.router(
              title: 'File Cast',
              theme: light,
              darkTheme: dark,
              routerConfig: appRouter,
              debugShowCheckedModeBanner: false,
            );
          },
        );
      },
    );
  }
}
