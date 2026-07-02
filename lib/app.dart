import 'package:file_cast/core/core.dart';
import 'package:file_cast/presentation/routes/router.dart';
import 'package:flutter/material.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'File Cast',
      theme: light,
      darkTheme: dark,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
