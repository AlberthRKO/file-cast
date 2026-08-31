import 'package:file_cast/ui/core/adaptive/constrained_content.dart';
import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OfflineView extends StatelessWidget {
  const OfflineView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver',
          onPressed: context.canPop() ? context.pop : null,
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Sin conexión'),
      ),
      body: SafeArea(
        child: ConstrainedContent(
          maxWidth: AppSize.messageMaxWidth,
          alignment: Alignment.center,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_off_outlined,
                    size: AppSize.minTouchTarget,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: AppSpace.l),
                  Text(
                    'Sin conexión a Internet',
                    style: theme.textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpace.s),
                  Text(
                    'Conéctese a una red Wi-Fi o active los datos móviles para continuar.',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
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
