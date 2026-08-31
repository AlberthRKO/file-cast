import 'package:file_cast/ui/core/adaptive/window_size_class.dart';
import 'package:flutter/widgets.dart';

typedef AdaptiveWidgetBuilder =
    Widget Function(
      BuildContext context,
      AppWindowSize window,
    );

class AdaptiveLayout extends StatelessWidget {
  const AdaptiveLayout({
    required this.builder,
    super.key,
  });

  final AdaptiveWidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return builder(
          context,
          AppWindowSize.fromConstraints(constraints),
        );
      },
    );
  }
}
