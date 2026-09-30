import 'package:file_cast/ui/core/theme/layout_tokens.dart';
import 'package:flutter/material.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

/// Shared wrapper for interactive sheets.
///
/// Keeping this entry point in `ui/core` makes all sheets use the same route
/// implementation while preserving each feature's content and callbacks.
Future<T?> showAppModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool expand = false,
  bool useSafeArea = false,
  bool isDismissible = true,
  bool enableDrag = true,
  Color? backgroundColor = Colors.transparent,
  double? maxWidth,
}) {
  return showMaterialModalBottomSheet<T>(
    context: context,
    expand: expand,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    backgroundColor: maxWidth == null ? backgroundColor : Colors.transparent,
    builder: (sheetContext) {
      final content = useSafeArea
          ? SafeArea(child: builder(sheetContext))
          : builder(sheetContext);
      if (maxWidth == null) return content;

      return Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth!),
          child: Material(
            color: backgroundColor ?? Colors.transparent,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.l),
            ),
            clipBehavior: Clip.antiAlias,
            child: content,
          ),
        ),
      );
    },
  );
}
