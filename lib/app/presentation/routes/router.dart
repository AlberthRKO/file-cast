import 'package:file_cast/app/presentation/pages/home/home.dart';
import 'package:file_cast/app/presentation/pages/offline/offline.dart';
import 'package:file_cast/app/presentation/pages/settings/settings.dart';
import 'package:file_cast/app/presentation/routes/routes.dart';
import 'package:file_cast/app/view/app.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

Future<String> getInitialRouteName(BuildContext context) async {
  return Routes.home;
}

mixin RouterMixin on State<App> {
  GoRouter? _router;
  late String _initialRouteName;

  bool _loading = true;
  bool get loading => _loading;

  GoRouter get router {
    if (_router != null) {
      return _router!;
    }

    final routes = [
      GoRoute(
        name: Routes.home,
        path: '/',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        name: Routes.offline,
        path: '/offline',
        builder: (context, state) => const Offline(),
      ),
      GoRoute(
        name: Routes.settings,
        path: '/settings',
        builder: (context, state) => const Settings(),
      ),
    ];

    final initialLocation = routes
        .firstWhere(
          (element) => element.name == _initialRouteName,
          orElse: () => routes.first,
        )
        .path;

    _router = GoRouter(
      initialLocation: initialLocation,
      routes: routes,
      debugLogDiagnostics: true,
    );

    return _router!;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    _initialRouteName = await getInitialRouteName(context);
    setState(() {
      _loading = false;
    });
  }
}
