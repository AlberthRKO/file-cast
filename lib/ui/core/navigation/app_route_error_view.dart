import 'package:file_cast/ui/core/navigation/app_route.dart';
import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppRouteErrorView extends StatelessWidget {
  const AppRouteErrorView({
    required this.message,
    super.key,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSize.messageMaxWidth,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.l),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: AppSize.minTouchTarget,
                  ),
                  const SizedBox(height: AppSpace.m),
                  Text(
                    'No se pudo abrir esta pantalla',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpace.s),
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpace.l),
                  FilledButton(
                    onPressed: () => context.goNamed(AppRouteName.requisitions),
                    child: const Text('Ir a requisas'),
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
