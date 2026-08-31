import 'package:file_cast/core/config/config.dart';
import 'package:file_cast/ui/core/adaptive/adaptive_layout.dart';
import 'package:file_cast/ui/core/navigation/app_route.dart';
import 'package:file_cast/ui/core/theme/brand_theme.dart';
import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:file_cast/ui/core/widgets/folder_background.dart';
import 'package:file_cast/ui/features/onboarding/started/view_models/started_view_model.dart';
import 'package:file_cast/ui/features/onboarding/started/widgets/started_layout.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class StartedRoute extends StatelessWidget {
  const StartedRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => StartedViewModel(appName: Config.appName),
      child: Consumer<StartedViewModel>(
        builder: (context, viewModel, _) => StartedView(
          viewModel: viewModel,
          onStart: () => context.pushNamed(AppRouteName.login),
        ),
      ),
    );
  }
}

class StartedView extends StatelessWidget {
  const StartedView({
    required this.viewModel,
    required this.onStart,
    super.key,
  });

  final StartedViewModel viewModel;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AdaptiveLayout(
        builder: (context, window) {
          final useWideComposition = window.isExpanded || window.isLarge;
          final brand = BrandTheme.of(context);

          return FolderBackground.stacked(
            frontColor: brand.folderFront,
            middleColor: brand.folderMiddle,
            backColor: brand.folderBack,
            highlightColor: brand.folderHighlight,
            compactHeight: window.hasCompactHeight,
            child: SafeArea(
              child: StartedLayout(
                content: viewModel.content,
                onStart: onStart,
                useWideComposition: useWideComposition,
                compactHeight: window.hasCompactHeight,
                maxWidth: window.isMedium
                    ? AppSize.formMaxWidth
                    : AppSize.contentMaxWidth,
              ),
            ),
          );
        },
      ),
    );
  }
}
